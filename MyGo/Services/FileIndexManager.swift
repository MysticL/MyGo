//
//  FileIndexManager.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation
import Combine
import CoreServices

/// 文件索引管理器
class FileIndexManager: ObservableObject {
    @Published var isIndexing = false
    @Published var indexedCount = 0
    
    private var indexingTask: Task<Void, Never>?
    private let indexQueue = DispatchQueue(label: "com.mygo.index", attributes: .concurrent)
    private var fileSystemWatcher: FileSystemWatcher?
    private let databaseManager = DatabaseManager.shared
    
    init() {
        Logger.shared.log("FileIndexManager init 完成", level: .debug)
    }
    
    /// 开始索引
    func startIndexing() {
        guard !isIndexing else {
            Logger.shared.log("索引已在进行中，跳过", level: .debug)
            return
        }
        
        let startTime = Date()
        Logger.shared.log("开始索引", level: .debug)
        
        isIndexing = true
        indexedCount = 0
        
        indexingTask = Task {
            await performIndexing()
            let elapsed = Date().timeIntervalSince(startTime)
            Logger.shared.log("索引任务完成，总耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
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
        
        // 清理已删除的文件
        databaseManager.cleanupDeletedFiles()

        // 清理不在任何启用索引目录下的文件（目录被移除后残留的记录）
        databaseManager.removeFilesOutsideIndexedDirectories()

        // 启动文件系统监控
        startFileSystemWatcher()
    }
    
    /// 索引目录
    private func indexDirectory(at url: URL) async -> Int {
        return await withCheckedContinuation { continuation in
            // 在后台线程执行索引任务
            Task.detached(priority: .utility) { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: 0)
                    return
                }
                
                let startTime = Date()
                Logger.shared.log("开始收集文件 URL: \(url.path)", level: .debug)
                
                // 在后台线程收集所有 URL（非 actor 隔离方法）
                let urls = self.collectFileURLs(from: url)
                
                let collectElapsed = Date().timeIntervalSince(startTime)
                Logger.shared.log("文件 URL 收集完成，数量: \(urls.count)，耗时: \(String(format: "%.3f", collectElapsed))秒", level: .debug)
                
                // 在后台线程处理文件并批量插入数据库
                var count = 0
                var batchItems: [FileItem] = []
                let batchSize = 100  // 每批处理 100 个文件
                
                for fileURL in urls {
                    guard !Task.isCancelled else { break }
                    
                    // 跳过系统目录
                    if fileURL.path.contains("/Library/") && 
                       (fileURL.path.contains("/Caches/") || 
                        fileURL.path.contains("/Application Support/")) {
                        continue
                    }
                    
                    // FileItem 初始化在后台线程执行
                    let item = FileItem(url: fileURL)
                    batchItems.append(item)
                    count += 1
                    
                    // 批量插入数据库
                    if batchItems.count >= batchSize {
                        // 在后台线程批量插入
                        let itemsToInsert = batchItems
                        self.databaseManager.insertOrUpdateFiles(itemsToInsert)
                        batchItems.removeAll()
                        
                        // 每批更新一次进度（切换到主线程）
                        await MainActor.run {
                            self.indexedCount += batchSize
                        }
                    }
                }
                
                // 插入剩余的文件
                if !batchItems.isEmpty {
                    let itemsToInsert = batchItems
                    self.databaseManager.insertOrUpdateFiles(itemsToInsert)
                    let remainingCount = batchItems.count
                    await MainActor.run {
                        self.indexedCount += remainingCount
                    }
                }
                
                let processElapsed = Date().timeIntervalSince(startTime)
                Logger.shared.log("目录索引完成，处理了 \(count) 个文件，耗时: \(String(format: "%.3f", processElapsed))秒", level: .debug)
                
                continuation.resume(returning: count)
            }
        }
    }
    
    /// 在同步上下文中收集文件 URL（非 actor 隔离，可在后台线程调用）
    nonisolated private func collectFileURLs(from url: URL) -> [URL] {
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
        fileSystemWatcher?.stop()
        fileSystemWatcher = FileSystemWatcher { [weak self] url, event in
            self?.handleFileSystemEvent(url: url, event: event)
        }
        fileSystemWatcher?.start()
    }

    /// 重启文件系统监控（索引目录变化后调用）
    func restartFileSystemWatcher() {
        fileSystemWatcher?.stop()
        fileSystemWatcher = nil
        startFileSystemWatcher()
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

/// 文件系统监控器（使用 FSEvents 实时监控文件变化）
class FileSystemWatcher {
    private var stream: FSEventStreamRef?
    private let callback: (URL, FileSystemEvent) -> Void
    private let queue = DispatchQueue(label: "com.mygo.fsevents", qos: .utility)

    init(callback: @escaping (URL, FileSystemEvent) -> Void) {
        self.callback = callback
    }

    deinit {
        stop()
    }

    func start() {
        stop()

        let paths = DatabaseManager.shared.getIndexDirectories()
        guard !paths.isEmpty else {
            Logger.shared.log("没有索引目录，跳过文件系统监控", level: .debug)
            return
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
            | FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer)

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (_, info, numEvents, eventPaths, eventFlags, _) in
                guard let info = info else { return }
                let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(info).takeUnretainedValue()
                let pathPointers = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                for i in 0..<numEvents {
                    guard let cString = pathPointers[i] else { continue }
                    let path = String(cString: cString)
                    let url = URL(fileURLWithPath: path)
                    watcher.handleEvent(url: url, flags: eventFlags[i])
                }
            },
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            Logger.shared.log("创建 FSEventStream 失败", level: .error)
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        Logger.shared.log("文件系统监控已启动，监控 \(paths.count) 个目录", level: .info)
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func handleEvent(url: URL, flags: FSEventStreamEventFlags) {
        // 忽略隐藏文件（如 .DS_Store）
        if url.lastPathComponent.hasPrefix(".") {
            return
        }

        var event: FileSystemEvent?
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
            event = .created
        } else if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 {
            event = .deleted
        } else if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0 {
            event = .renamed
        } else if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0
                    || flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod) != 0 {
            event = .modified
        }

        if let event = event {
            callback(url, event)
        }
    }
}

