//
//  FileIndexManager.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation
import Combine

/// 文件索引管理器
class FileIndexManager: ObservableObject {
    @Published var isIndexing = false
    @Published var indexedCount = 0
    
    private var indexingTask: Task<Void, Never>?
    private let indexQueue = DispatchQueue(label: "com.mygo.index", attributes: .concurrent)
    private var fileSystemWatcher: FileSystemWatcher?
    private let databaseManager = DatabaseManager.shared
    
    /// 开始索引
    func startIndexing() {
        guard !isIndexing else { return }
        
        isIndexing = true
        indexedCount = 0
        
        indexingTask = Task {
            await performIndexing()
        }
    }
    
    /// 停止索引
    func stopIndexing() {
        indexingTask?.cancel()
        indexingTask = nil
        isIndexing = false
    }
    
    /// 执行索引
    private func performIndexing() async {
        // 从数据库获取索引目录列表
        let directories = databaseManager.getIndexDirectories()
        
        guard !directories.isEmpty else {
            await MainActor.run {
                self.isIndexing = false
            }
            return
        }
        
        // 清空旧索引（可选，也可以增量更新）
        // databaseManager.clearFileIndex()
        
        var totalCount = 0
        
        for directoryPath in directories {
            guard !Task.isCancelled else { break }
            
            let url = URL(fileURLWithPath: directoryPath)
            
            // 索引目录
            let count = await indexDirectory(at: url)
            totalCount += count
            
            await MainActor.run {
                self.indexedCount = totalCount
            }
        }
        
        await MainActor.run {
            self.isIndexing = false
        }
        
        // 启动文件系统监控
        startFileSystemWatcher()
    }
    
    /// 索引目录
    private func indexDirectory(at url: URL) async -> Int {
        return await withCheckedContinuation { continuation in
            // 在同步上下文中收集所有 URL
            let urls = collectFileURLs(from: url)
            
            Task { @MainActor in
                var count = 0
                
                // 在主线程上处理收集到的 URL
                for fileURL in urls {
                    guard !Task.isCancelled else { break }
                    
                    // 跳过系统目录
                    if fileURL.path.contains("/Library/") && 
                       (fileURL.path.contains("/Caches/") || 
                        fileURL.path.contains("/Application Support/")) {
                        continue
                    }
                    
                    let item = FileItem(url: fileURL)
                    // 保存到数据库
                    self.databaseManager.insertOrUpdateFile(item)
                    count += 1
                    
                    // 每1000个文件更新一次进度
                    if count % 1000 == 0 {
                        self.indexedCount += 1000
                    }
                }
                
                continuation.resume(returning: count)
            }
        }
    }
    
    /// 在同步上下文中收集文件 URL
    private func collectFileURLs(from url: URL) -> [URL] {
        var urls: [URL] = []
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .creationDateKey,
                .contentModificationDateKey,
                .contentAccessDateKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, error in
                // 跳过无权限访问的文件
                return true
            }
        ) else {
            return urls
        }
        
        // 在同步上下文中收集所有 URL
        for case let fileURL as URL in enumerator {
            urls.append(fileURL)
        }
        
        return urls
    }
    
    /// 启动文件系统监控
    private func startFileSystemWatcher() {
        fileSystemWatcher = FileSystemWatcher { [weak self] url, event in
            self?.handleFileSystemEvent(url: url, event: event)
        }
        fileSystemWatcher?.start()
    }
    
    /// 处理文件系统事件
    private func handleFileSystemEvent(url: URL, event: FileSystemEvent) {
        Task { @MainActor in
            switch event {
            case .created, .renamed:
                let item = FileItem(url: url)
                databaseManager.insertOrUpdateFile(item)
            case .deleted:
                databaseManager.deleteFile(path: url.path)
            case .modified:
                let item = FileItem(url: url)
                databaseManager.insertOrUpdateFile(item)
            }
        }
    }
    
    deinit {
        stopIndexing()
        fileSystemWatcher?.stop()
    }
}

/// 文件系统事件类型
enum FileSystemEvent {
    case created
    case deleted
    case modified
    case renamed
}

/// 文件系统监控器（简化版 - 使用定时刷新）
class FileSystemWatcher {
    private var timer: Timer?
    private let callback: (URL, FileSystemEvent) -> Void
    private var lastCheckTime: Date = Date()
    
    init(callback: @escaping (URL, FileSystemEvent) -> Void) {
        self.callback = callback
    }
    
    func start() {
        guard timer == nil else { return }
        
        // 每5秒检查一次文件系统变化
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        // 这是一个简化实现，实际应用中可以使用 FSEvents API
        // 这里我们只记录检查时间，实际的文件变化检测由索引管理器在重新索引时处理
        lastCheckTime = Date()
    }
}

