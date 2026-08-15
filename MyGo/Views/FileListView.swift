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

    /// 排序指纹：点击列头只会调整比较器顺序与方向，据此生成稳定字符串以触发缓存重算
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
            // 原生 NSTableView：真实文件路径拖拽 + 原生选中/双击/右键菜单/列持久化/无限滚动
            FileTableRepresentable(
                files: visibleFiles,
                selectedFileID: $selectedFileID,
                sortOrder: $sortOrder,
                onDoubleClick: { file in onFileAction(file, .open) },
                onReachBottom: { visibleCount += 500 },
                onFileAction: onFileAction
            )

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
}

/// 原生 NSTableView 封装：真实文件路径拖拽、原生选中/双击/右键菜单/列宽持久化/无限滚动。
/// 为什么不用 SwiftUI Table：SwiftUI 的 .onDrag/.draggable 会把文件改写成
/// `com.apple.SwiftUI.Drag-*` 临时副本（路径框拿到临时路径、Finder 移动也不是真移动），
/// 且其 dataSource 由 SwiftUI 独占、无法安全挂接原生拖拽；改用 NSTableView 后
/// `pasteboardWriterForRow` 直接把真实路径写进粘贴板。
private struct FileTableRepresentable: NSViewRepresentable {
    var files: [FileItem]
    @Binding var selectedFileID: String?
    @Binding var sortOrder: [KeyPathComparator<FileItem>]
    var onDoubleClick: (FileItem) -> Void
    var onReachBottom: () -> Void
    var onFileAction: (FileItem, FileListView.FileAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let tableView = FileTableView()
        tableView.dataSource = coordinator
        tableView.delegate = coordinator
        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = false
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        // 五列（含排序描述符，点击列头会触发 sortDescriptorsDidChange 回写 sortOrder）
        let specs: [(id: String, title: String, min: CGFloat, ideal: CGFloat, key: String)] = [
            ("name", "名称", 200, 400, "name"),
            ("path", "路径", 200, 600, "directoryPath"),
            ("extension", "文件格式", 40, 50, "sortableExtension"),
            ("size", "大小", 40, 50, "size"),
            ("modified", "修改日期", 150, 150, "sortableModifiedDate")
        ]
        for spec in specs {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(spec.id))
            column.title = spec.title
            column.minWidth = spec.min
            column.width = spec.ideal
            column.resizingMask = [.userResizingMask, .autoresizingMask]
            column.sortDescriptorPrototype = NSSortDescriptor(key: spec.key, ascending: true)
            tableView.addTableColumn(column)
        }

        // 列宽/列顺序持久化
        tableView.autosaveName = "MyGoFileListTable"
        tableView.autosaveTableColumns = true

        // 双击打开（AppKit 原生，不会吞掉单选）
        tableView.target = coordinator
        tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))

        // 原生拖拽：真实文件路径，拖到外部默认移动、Option 复制（与 Finder 一致）
        tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        tableView.setDraggingSourceOperationMask([], forLocal: true)

        // 右键菜单（按行构建）
        tableView.menuProvider = { [weak coordinator] row in coordinator?.contextMenu(for: row) }

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        coordinator.attachScrollObserver(to: scrollView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        let coordinator = context.coordinator
        let filesChanged = coordinator.files != files
        coordinator.files = files
        coordinator.selectedIDBinding = $selectedFileID
        coordinator.sortOrderBinding = $sortOrder
        coordinator.onDoubleClick = onDoubleClick
        coordinator.onReachBottom = onReachBottom
        coordinator.onFileAction = onFileAction

        // 文件未变时跳过 reload，避免滚动/选中被打断
        guard filesChanged else { return }
        tableView.reloadData()
        // 恢复/清理选中态
        if let id = selectedFileID, let index = files.firstIndex(where: { $0.id == id }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else {
            tableView.deselectAll(nil)
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var files: [FileItem] = []
        var selectedIDBinding: Binding<String?>?
        var sortOrderBinding: Binding<[KeyPathComparator<FileItem>]>?
        var onDoubleClick: (FileItem) -> Void = { _ in }
        var onReachBottom: () -> Void = {}
        var onFileAction: (FileItem, FileListView.FileAction) -> Void = { _, _ in }

        private var scrollObserver: NSObjectProtocol?
        private weak var observedScrollView: NSScrollView?

        deinit {
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        // MARK: - 数据源

        func numberOfRows(in tableView: NSTableView) -> Int {
            files.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn, row >= 0, row < files.count else { return nil }
            let identifier = tableColumn.identifier
            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
                ?? Self.makeNewCell(identifier: identifier)
            Self.configureCell(cell, identifier: identifier, file: files[row])
            return cell
        }

        /// 拖拽某行：把真实文件路径写进粘贴板（Finder 才能真移动/复制，路径框读到真实路径）
        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard row >= 0, row < files.count else { return nil }
            let file = files[row]
            let item = NSPasteboardItem()
            item.setPropertyList([file.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
            item.setString(file.url.absoluteString, forType: .fileURL)
            item.setString(file.url.absoluteString, forType: .URL)
            return item
        }

        // MARK: - 选中

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            let row = tableView.selectedRow
            if row >= 0, row < files.count {
                selectedIDBinding?.wrappedValue = files[row].id
            } else {
                selectedIDBinding?.wrappedValue = nil
            }
        }

        // MARK: - 排序（dataSource 回调，点击列头时触发，回写 sortOrder 交给 SwiftUI 侧重排）

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            let newOrder = tableView.sortDescriptors.compactMap { Self.comparator(for: $0) }
            if newOrder != sortOrderBinding?.wrappedValue {
                sortOrderBinding?.wrappedValue = newOrder
            }
        }

        private static func comparator(for descriptor: NSSortDescriptor) -> KeyPathComparator<FileItem>? {
            let order: SortOrder = descriptor.ascending ? .forward : .reverse
            switch descriptor.key {
            case "name": return KeyPathComparator(\FileItem.name, order: order)
            case "directoryPath": return KeyPathComparator(\FileItem.directoryPath, order: order)
            case "sortableExtension": return KeyPathComparator(\FileItem.sortableExtension, order: order)
            case "size": return KeyPathComparator(\FileItem.size, order: order)
            case "sortableModifiedDate": return KeyPathComparator(\FileItem.sortableModifiedDate, order: order)
            default: return nil
            }
        }

        // MARK: - 双击

        @objc func handleDoubleClick(_ sender: Any) {
            guard let tableView = sender as? NSTableView else { return }
            let row = tableView.clickedRow
            guard row >= 0 && row < files.count else { return }
            onDoubleClick(files[row])
        }

        // MARK: - 右键菜单

        func contextMenu(for row: Int) -> NSMenu? {
            guard row >= 0, row < files.count else { return nil }
            return makeContextMenu(for: files[row])
        }

        private func makeContextMenu(for file: FileItem) -> NSMenu {
            let menu = NSMenu()
            addMenuItem("打开", .open, file, to: menu)
            addMenuItem("在 Finder 中显示", .reveal, file, to: menu)
            addMenuItem("在终端中打开", .openInTerminal, file, to: menu)
            menu.addItem(.separator())
            addMenuItem("复制路径", .copy, file, to: menu)
            addMenuItem(file.isDirectory ? "复制文件夹到..." : "复制文件到...", .copyTo, file, to: menu)
            addMenuItem("移动...", .move, file, to: menu)
            menu.addItem(.separator())
            addMenuItem("移动到废纸篓", .delete, file, to: menu)
            return menu
        }

        private func addMenuItem(_ title: String, _ action: FileListView.FileAction, _ file: FileItem, to menu: NSMenu) {
            let item = NSMenuItem(title: title, action: #selector(handleMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = MenuPayload(file: file, action: action)
            menu.addItem(item)
        }

        @objc func handleMenuAction(_ sender: NSMenuItem) {
            guard let payload = sender.representedObject as? MenuPayload else { return }
            onFileAction(payload.file, payload.action)
        }

        private final class MenuPayload: NSObject {
            let file: FileItem
            let action: FileListView.FileAction
            init(file: FileItem, action: FileListView.FileAction) {
                self.file = file
                self.action = action
                super.init()
            }
        }

        // MARK: - 单元格

        private static func makeNewCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cell.textField = textField
            cell.addSubview(textField)
            if identifier.rawValue == "name" {
                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                cell.imageView = imageView
                cell.addSubview(imageView)
                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            } else {
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            }
            return cell
        }

        private static func configureCell(_ cell: NSTableCellView, identifier: NSUserInterfaceItemIdentifier, file: FileItem) {
            guard let textField = cell.textField else { return }
            switch identifier.rawValue {
            case "name":
                cell.imageView?.image = NSImage(systemSymbolName: file.isDirectory ? "folder.fill" : "doc.fill", accessibilityDescription: nil)
                cell.imageView?.contentTintColor = file.isDirectory ? .systemBlue : .secondaryLabelColor
                textField.stringValue = file.name
                textField.font = .systemFont(ofSize: 13)
                textField.textColor = .labelColor
                textField.alignment = .left
            case "path":
                textField.stringValue = file.shortenedDirectoryPath
                textField.font = .systemFont(ofSize: 12)
                textField.textColor = .secondaryLabelColor
                textField.alignment = .left
            case "extension":
                textField.stringValue = file.fileExtension?.uppercased() ?? "--"
                textField.font = .systemFont(ofSize: 12)
                textField.textColor = .secondaryLabelColor
                textField.alignment = .right
            case "size":
                textField.stringValue = file.formattedSize
                textField.font = .systemFont(ofSize: 12)
                textField.textColor = .secondaryLabelColor
                textField.alignment = .right
            case "modified":
                textField.stringValue = file.formattedModifiedDate
                textField.font = .systemFont(ofSize: 12)
                textField.textColor = .secondaryLabelColor
                textField.alignment = .left
            default:
                break
            }
        }

        // MARK: - 无限滚动

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
    }
}

/// 带按行右键菜单的 NSTableView
private final class FileTableView: NSTableView {
    var menuProvider: ((Int) -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        guard row >= 0 else { return nil }
        return menuProvider?(row)
    }
}
