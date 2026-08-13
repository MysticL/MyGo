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

    var sortedFiles: [FileItem] {
        files.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            Table(sortedFiles, selection: $selectedFileID, sortOrder: $sortOrder) {
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
                }
                .width(min: 200, ideal: 600)

                // 文件格式列 - 可排序，右对齐
                TableColumn("文件格式", value: \.sortableExtension) { file in
                    Text(file.fileExtension?.uppercased() ?? "--")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .width(min: 40, ideal: 50)

                // 大小列 - 可排序，右对齐
                TableColumn("大小", value: \.size) { file in
                    Text(file.formattedSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .width(min: 40, ideal: 50)

                // 修改日期列 - 可排序
                TableColumn("修改日期", value: \.sortableModifiedDate) { file in
                    Text(file.formattedModifiedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .width(min: 150, ideal: 150)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            // 使用基于选中的上下文菜单 + 双击主操作：
            // 避免在单元格上挂 onTapGesture 而吞掉单选高亮。
            .contextMenu(
                forSelectionType: String.self,
                menu: { selection in
                    selectionMenu(for: selection)
                },
                primaryAction: { selection in
                    // 双击打开
                    for file in files where selection.contains(file.id) {
                        onFileAction(file, .open)
                    }
                }
            )
            .background(TableColumnAutosave())

            Divider()

            // 底部状态栏
            HStack {
                Text("\(files.count) 个结果")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    @ViewBuilder
    private func selectionMenu(for selection: Set<String>) -> some View {
        let selected = files.filter { selection.contains($0.id) }
        if selected.isEmpty {
            EmptyView()
        } else if selected.count == 1, let item = selected.first {
            if item.isDirectory {
                folderMenu(for: item)
            } else {
                fileMenu(for: item)
            }
        } else {
            Button("复制路径 (\(selected.count) 项)") {
                for file in selected { onFileAction(file, .copy) }
            }
            Divider()
            Button("移动到废纸篓 (\(selected.count) 项)") {
                for file in selected { onFileAction(file, .delete) }
            }
        }
    }

    @ViewBuilder
    private func fileMenu(for file: FileItem) -> some View {
        Button("打开") { onFileAction(file, .open) }
        Button("在 Finder 中显示") { onFileAction(file, .reveal) }
        Button("在终端中打开") { onFileAction(file, .openInTerminal) }
        Divider()
        Button("复制路径") { onFileAction(file, .copy) }
        Button("复制文件到...") { onFileAction(file, .copyTo) }
        Button("移动...") { onFileAction(file, .move) }
        Divider()
        Button("移动到废纸篓") { onFileAction(file, .delete) }
    }

    @ViewBuilder
    private func folderMenu(for folder: FileItem) -> some View {
        Button("打开") { onFileAction(folder, .open) }
        Button("在 Finder 中显示") { onFileAction(folder, .reveal) }
        Button("在终端中打开") { onFileAction(folder, .openInTerminal) }
        Divider()
        Button("复制路径") { onFileAction(folder, .copy) }
        Button("复制文件夹到...") { onFileAction(folder, .copyTo) }
        Button("移动...") { onFileAction(folder, .move) }
        Divider()
        Button("移动到废纸篓") { onFileAction(folder, .delete) }
    }
}

/// 借助 NSTableView 的 autosave 机制持久化列宽与列顺序。
/// 替代原先基于轮询定时器 + 递归查找 + 手动读写的复杂实现。
private struct TableColumnAutosave: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = false
        // 等待视图进入窗口层级后再定位 NSTableView
        DispatchQueue.main.async {
            Self.configure(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // SwiftUI 可能在更新时重建 NSTableView，重新应用以确保持久化生效
        DispatchQueue.main.async {
            Self.configure(nsView)
        }
    }

    private static func configure(_ view: NSView) {
        guard let window = view.window, let contentView = window.contentView else { return }
        guard let tableView = findTableView(in: contentView) else { return }

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
}
