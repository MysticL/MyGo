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
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 主内容区域
            VStack(spacing: 0) {
                // 搜索栏（包含筛选按钮）
                SearchBarView(
                    searchText: $searchText,
                    showFilter: $showFilter,
                    onSearch: performSearch
                )
                .padding()
                
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
                        performSearch()
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
            // 检查是否有索引目录，如果有则自动开始索引
            let directories = DatabaseManager.shared.getIndexDirectories()
            if !directories.isEmpty && !indexManager.isIndexing {
                indexManager.startIndexing()
            }
        }
        .onDisappear {
            saveWindowSize()
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
    
    /// 执行搜索
    private func performSearch() {
        // 使用筛选器中的设置（包括 useRegex）
        searchService.search(
            query: searchText,
            filter: showFilter ? filter : nil,
            useRegex: filter.useRegex
        )
    }
    
    /// 处理文件操作
    private func handleFileAction(_ item: FileItem, action: FileListView.FileAction) {
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
