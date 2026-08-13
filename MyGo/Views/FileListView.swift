//
//  FileListView.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI
import AppKit

enum SortOption: String, CaseIterable {
    case name = "名称"
    case path = "路径"
    case size = "大小"
    case modified = "修改日期"
}

struct FileListView: View {
    @Binding var files: [FileItem]
    @State private var sortOrder = [
        KeyPathComparator(\FileItem.name),
        KeyPathComparator(\FileItem.directoryPath),
        KeyPathComparator(\FileItem.sortableExtension),
        KeyPathComparator(\FileItem.size),
        KeyPathComparator(\FileItem.sortableModifiedDate)
    ]
    @State private var selectedFileID: String?
    @State private var sortedCache: [FileItem] = []
    @State private var visibleCount = 500
    var onFileAction: (FileItem, FileAction) -> Void

    enum FileAction {
        case open
        case reveal
        case copy
        case copyTo
        case move
        case openInTerminal
        case delete
    }

    /// 排序指纹：SwiftUI 点击列头只会调整比较器顺序与方向，据此生成稳定字符串以触发缓存重算
    private var sortToken: String {
        sortOrder.map { $0.order == .forward ? "f" : "r" }.joined()
    }

    /// 当前显示的窗口（排序缓存的前 visibleCount 条）
    private var visibleFiles: [FileItem] {
        Array(sortedCache.prefix(visibleCount))
    }

    /// 重算排序缓存（只在数据或排序变化时调用，避免每次 body 重算都重排大数组）
    private func recomputeSorted() {
        sortedCache = files.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            Table(visibleFiles, selection: $selectedFileID, sortOrder: $sortOrder) {
                // 名称列 - 可排序
                TableColumn("名称", value: \.name) { file in
                    HStack(spacing: 6) {
                        Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundColor(file.isDirectory ? .blue : .secondary)
                            .frame(width: 16)
                        Text(file.name)
                            .font(.system(size: 13))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .contextMenu {
                        itemMenu(for: file)
                    }
                }
                .width(min: 200, ideal: 400)

                // 路径列 - 可排序（只显示目录路径，默认去掉前两级）
                TableColumn("路径", value: \.directoryPath) { file in
                    Text(file.shortenedDirectoryPath)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .contextMenu {
                            itemMenu(for: file)
                        }
                }
                .width(min: 200, ideal: 600)

                // 文件格式列 - 可排序，右对齐
                TableColumn("文件格式", value: \.sortableExtension) { file in
                    Text(file.fileExtension?.uppercased() ?? "--")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                        .contextMenu {
                            itemMenu(for: file)
                        }
                }
                .width(min: 40, ideal: 50)

                // 大小列 - 可排序，右对齐
                TableColumn("大小", value: \.size) { file in
                    Text(file.formattedSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                        .contextMenu {
                            itemMenu(for: file)
                        }
                }
                .width(min: 40, ideal: 50)

                // 修改日期列 - 可排序
                TableColumn("修改日期", value: \.sortableModifiedDate) { file in
                    Text(file.formattedModifiedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .contextMenu {
                            itemMenu(for: file)
                        }
                }
                .width(min: 150, ideal: 150)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            // 双击打开走 NSTableView.doubleAction（AppKit 原生），不干扰单选；列宽走 autosave。
            // onReachBottom 滚动到底部时自动加载更多（无限滚动）。
            .background(TableColumnAutosave(
                files: visibleFiles,
                onDoubleClick: { file in onFileAction(file, .open) },
                onReachBottom: { visibleCount += 500 }
            ))

            Divider()

            // 底部状态栏
            HStack {
                if visibleCount < sortedCache.count {
                    Text("已显示 \(visibleCount) / \(files.count) 个结果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(files.count) 个结果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear { recomputeSorted() }
        .onChange(of: files) { _, _ in
            visibleCount = 500
            recomputeSorted()
        }
        .onChange(of: sortToken) { _, _ in
            recomputeSorted()
        }
    }

    /// 文件/文件夹的右键菜单
    @ViewBuilder
    private func itemMenu(for file: FileItem) -> some View {
        Button("打开") { onFileAction(file, .open) }
        Button("在 Finder 中显示") { onFileAction(file, .reveal) }
        Button("在终端中打开") { onFileAction(file, .openInTerminal) }
        Divider()
        Button("复制路径") { onFileAction(file, .copy) }
        Button(file.isDirectory ? "复制文件夹到..." : "复制文件到...") { onFileAction(file, .copyTo) }
        Button("移动...") { onFileAction(file, .move) }
        Divider()
        Button("移动到废纸篓") { onFileAction(file, .delete) }
    }
}

/// 借助 NSTableView 的能力：
/// - `doubleAction` 实现双击打开（AppKit 原生，不影响单选）
/// - `autosaveName`/`autosaveTableColumns` 持久化列宽与列顺序
/// - 监听滚动到底部，实现无限滚动（自动加载更多）
private struct TableColumnAutosave: NSViewRepresentable {
    var files: [FileItem]
    var onDoubleClick: (FileItem) -> Void
    var onReachBottom: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(files: files, onDoubleClick: onDoubleClick, onReachBottom: onReachBottom)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = false
        // 等待视图进入窗口层级后再定位 NSTableView
        DispatchQueue.main.async {
            Self.configure(view, context: context)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.files = files
        context.coordinator.onDoubleClick = onDoubleClick
        context.coordinator.onReachBottom = onReachBottom
        DispatchQueue.main.async {
            Self.configure(nsView, context: context)
        }
    }

    private static func configure(_ view: NSView, context: Context) {
        guard let window = view.window, let contentView = window.contentView else { return }
        guard let tableView = findTableView(in: contentView) else { return }

        // 双击打开（AppKit 原生，不会吞掉单选）
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))

        // 滚动到底部自动加载更多（幂等挂接）
        if let scrollView = tableView.enclosingScrollView {
            context.coordinator.attachScrollObserver(to: scrollView)
        }

        // 列宽/列顺序持久化（幂等，避免每次更新重复触发 autosave 恢复）
        if tableView.autosaveName == "MyGoFileListTable" && tableView.autosaveTableColumns {
            return
        }
        tableView.autosaveName = "MyGoFileListTable"
        tableView.autosaveTableColumns = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
    }

    private static func findTableView(in view: NSView) -> NSTableView? {
        if let scrollView = view as? NSScrollView,
           let tableView = scrollView.documentView as? NSTableView {
            return tableView
        }
        for subview in view.subviews {
            if let tableView = findTableView(in: subview) {
                return tableView
            }
        }
        return nil
    }

    final class Coordinator: NSObject {
        var files: [FileItem]
        var onDoubleClick: (FileItem) -> Void
        var onReachBottom: () -> Void

        private var scrollObserver: NSObjectProtocol?
        private weak var observedScrollView: NSScrollView?

        init(files: [FileItem], onDoubleClick: @escaping (FileItem) -> Void, onReachBottom: @escaping () -> Void) {
            self.files = files
            self.onDoubleClick = onDoubleClick
            self.onReachBottom = onReachBottom
        }

        deinit {
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        /// 挂接滚动监听（幂等），滚到底部附近时触发加载更多
        func attachScrollObserver(to scrollView: NSScrollView) {
            guard observedScrollView !== scrollView else { return }
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
                scrollObserver = nil
            }
            observedScrollView = scrollView
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.checkReachBottom(scrollView)
            }
        }

        /// 距文档底部不足阈值时触发加载更多
        private func checkReachBottom(_ scrollView: NSScrollView) {
            guard let documentView = scrollView.documentView else { return }
            let clipView = scrollView.contentView
            let visibleRect = clipView.bounds
            let distanceToBottom = documentView.frame.height - (visibleRect.origin.y + visibleRect.height)
            if distanceToBottom < 200 {
                onReachBottom()
            }
        }

        @objc func handleDoubleClick(_ sender: Any) {
            guard let tableView = sender as? NSTableView else { return }
            let row = tableView.clickedRow
            guard row >= 0 && row < files.count else { return }
            onDoubleClick(files[row])
        }
    }
}
