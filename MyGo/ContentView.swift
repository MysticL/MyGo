//
//  ContentView.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var indexManager: FileIndexManager
    @EnvironmentObject var appState: AppState
    @StateObject private var searchService = SearchService()
    
    @State private var searchText = ""
    @State private var showFilter = false
    @State private var filter = SearchFilter()
    @State private var sortOption = SortOption.name
    @State private var ascending = true
    @State private var searchDebounceTimer: Timer?
    @State private var selectedWhitelist: PathKeywordList?
    @State private var selectedBlacklist: PathKeywordList?
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 主内容区域
            VStack(spacing: 0) {
                // 搜索栏（包含筛选按钮）
                SearchBarView(
                    searchText: $searchText,
                    showFilter: $showFilter,
                    selectedWhitelist: $selectedWhitelist,
                    selectedBlacklist: $selectedBlacklist,
                    onSearch: {
                        // 立即执行搜索（用于提交或清除按钮）
                        performSearchImmediately()
                    }
                )
                .padding()
                .onChange(of: searchText) { oldValue, newValue in
                    // 防抖：延迟搜索，避免输入时卡顿
                    searchDebounceTimer?.invalidate()
                    searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                        performSearch()
                    }
                }
                .onChange(of: selectedWhitelist) { oldValue, newValue in
                    performSearchImmediately()
                }
                .onChange(of: selectedBlacklist) { oldValue, newValue in
                    performSearchImmediately()
                }
                
                Divider()
                
                // 文件列表
                FileListView(
                    files: $searchService.searchResults,
                    onFileAction: handleFileAction
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 右侧筛选面板（弹窗）
            if showFilter {
                FilterView(filter: $filter, isPresented: $showFilter)
                    .onChange(of: filter) {
                        performSearchImmediately()
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: -4, y: 0)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(WindowSizeTracker())
        .onChange(of: appState.showSettings) {
            // 当设置窗口关闭时保存窗口大小
            saveWindowSize()
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView(indexManager: indexManager)
        }
        .onAppear {
            let startTime = Date()
            Logger.shared.log("ContentView onAppear 开始", level: .debug)
            
            // 检查是否有索引目录，如果有则自动开始索引
            let getDirStart = Date()
            let directories = DatabaseManager.shared.getIndexDirectories()
            let getDirElapsed = Date().timeIntervalSince(getDirStart)
            Logger.shared.log("获取索引目录列表完成，数量: \(directories.count)，耗时: \(String(format: "%.3f", getDirElapsed))秒", level: .debug)
            
            if !directories.isEmpty && !indexManager.isIndexing {
                Logger.shared.log("自动开始索引，目录数: \(directories.count)", level: .debug)
                indexManager.startIndexing()
            } else {
                Logger.shared.log("跳过自动索引（目录为空或正在索引中）", level: .debug)
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            Logger.shared.log("ContentView onAppear 完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
        }
        .onDisappear {
            saveWindowSize()
            // 清理防抖定时器
            searchDebounceTimer?.invalidate()
            searchDebounceTimer = nil
        }
    }
    
    /// 保存窗口大小
    private func saveWindowSize() {
        if let window = NSApplication.shared.windows.first(where: { $0.isMainWindow }) {
            let frame = window.frame
            PreferencesManager.shared.saveWindowSize(
                width: frame.width,
                height: frame.height
            )
        }
    }
    
    /// 执行搜索（带防抖）
    private func performSearch() {
        Logger.shared.log("搜索行为: 执行搜索（防抖触发）", level: .debug)
        // 使用筛选器中的设置（包括 useRegex）
        searchService.search(
            query: searchText,
            filter: showFilter ? filter : nil,
            useRegex: filter.useRegex,
            whitelist: selectedWhitelist,
            blacklist: selectedBlacklist
        )
    }
    
    /// 立即执行搜索（用于提交或清除按钮）
    private func performSearchImmediately() {
        Logger.shared.log("搜索行为: 立即执行搜索（用户触发）", level: .info)
        // 取消防抖定时器
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = nil
        // 立即执行搜索
        performSearch()
    }
    
    /// 处理文件操作
    private func handleFileAction(_ item: FileItem, action: FileListView.FileAction) {
        Logger.shared.log("处理文件操作: \(action) - \(item.name)", level: .info)
        switch action {
        case .open:
            FileOperationService.shared.openFile(item)
        case .reveal:
            FileOperationService.shared.revealInFinder(item)
        case .copy:
            FileOperationService.shared.copyPath(item)
        case .move:
            FileOperationService.shared.showMoveDialog(for: item) { destination in
                if let destination = destination {
                    do {
                        try FileOperationService.shared.moveFile(item, to: destination.appendingPathComponent(item.name))
                    } catch {
                        print("移动文件失败: \(error)")
                    }
                }
            }
        case .delete:
            do {
                try FileOperationService.shared.deleteFile(item)
                // 从数据库索引中移除
                DatabaseManager.shared.deleteFile(path: item.path)
            } catch {
                print("删除文件失败: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
