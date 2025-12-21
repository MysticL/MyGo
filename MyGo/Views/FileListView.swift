//
//  FileListView.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI

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
    @State private var selectedFileID: UUID?
    @State private var columnWidths: [String: CGFloat] = [:]
    var onFileAction: (FileItem, FileAction) -> Void
    
    enum FileAction {
        case open
        case reveal
        case copy
        case move
        case delete
    }
    
    // 根据排序顺序对文件进行排序
    var sortedFiles: [FileItem] {
        files.sorted(using: sortOrder)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 表格视图
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
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onFileAction(file, .open)
                    }
                    .contextMenu {
                        Button("打开") {
                            onFileAction(file, .open)
                        }
                        Button("在 Finder 中显示") {
                            onFileAction(file, .reveal)
                        }
                        Divider()
                        Button("复制路径") {
                            onFileAction(file, .copy)
                        }
                        Divider()
                        Button("移动到废纸篓") {
                            onFileAction(file, .delete)
                        }
                    }
                }
                .width(min: 200, ideal: getColumnWidth("名称", defaultWidth: 300))
                
                // 路径列 - 可排序（只显示目录路径）
                TableColumn("路径", value: \.directoryPath) { file in
                    Text(file.directoryPath)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            onFileAction(file, .open)
                        }
                }
                .width(min: 200, ideal: getColumnWidth("路径", defaultWidth: 400))
                
                // 扩展名列 - 可排序，右对齐
                TableColumn("扩展名", value: \.sortableExtension) { file in
                    Text(file.fileExtension?.uppercased() ?? "--")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            onFileAction(file, .open)
                        }
                }
                .width(min: 40, ideal: getColumnWidth("扩展名", defaultWidth: 50))
                
                // 大小列 - 可排序
                TableColumn("大小", value: \.size) { file in
                    Text(file.formattedSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            onFileAction(file, .open)
                        }
                }
                .width(min: 40, ideal: getColumnWidth("大小", defaultWidth: 50))
                
                // 修改日期列 - 可排序
                TableColumn("修改日期", value: \.sortableModifiedDate) { file in
                    Text(file.formattedModifiedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            onFileAction(file, .open)
                        }
                }
                .width(min: 150, ideal: getColumnWidth("修改日期", defaultWidth: 180))
            }
            .id("table-\(columnWidths.values.sorted().reduce(0, +))") // 当列宽改变时强制重新创建 Table
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .background(TableViewColumnWidthTracker(onWidthChange: { columnName, width in
                columnWidths[columnName] = width
                PreferencesManager.shared.saveColumnWidths(columnWidths)
            }))
            .onAppear {
                loadColumnWidths()
            }
            .onChange(of: sortOrder) { oldValue, newValue in
                // 当排序改变时，保持当前的列宽设置（通过 id 强制重新创建 Table）
            }
            .onChange(of: files.count) { oldValue, newValue in
                // 当文件列表变化时（搜索），保持当前的列宽设置（通过 id 强制重新创建 Table）
            }
            
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
    
    /// 获取列宽（从保存的设置或默认值）
    private func getColumnWidth(_ columnName: String, defaultWidth: CGFloat) -> CGFloat {
        if let savedWidth = columnWidths[columnName], savedWidth > 0 {
            return savedWidth
        }
        return defaultWidth
    }
    
    /// 加载列宽
    private func loadColumnWidths() {
        columnWidths = PreferencesManager.shared.getColumnWidths()
        // 如果没有保存的设置，使用默认值
        if columnWidths.isEmpty {
            columnWidths = [
                "名称": 300,
                "路径": 400,
                "扩展名": 50,  // 新的默认值
                "大小": 50,    // 新的默认值
                "修改日期": 180
            ]
            PreferencesManager.shared.saveColumnWidths(columnWidths)
        }
    }
    
}

/// 表格列宽跟踪器
struct TableViewColumnWidthTracker: NSViewRepresentable {
    var onWidthChange: (String, CGFloat) -> Void
    
    class Coordinator: NSObject {
        var onWidthChange: (String, CGFloat) -> Void
        var columnNames = ["名称", "路径", "扩展名", "大小", "修改日期"]
        var observers: [NSKeyValueObservation] = []
        var setupTableViews: Set<UnsafeMutableRawPointer> = []
        var pendingSaves: [String: Timer] = [:] // 防抖定时器
        
        init(onWidthChange: @escaping (String, CGFloat) -> Void) {
            self.onWidthChange = onWidthChange
            super.init()
        }
        
        deinit {
            observers.forEach { $0.invalidate() }
            pendingSaves.values.forEach { $0.invalidate() }
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onWidthChange: onWidthChange)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = false
        
        // 立即尝试查找 TableView（可能在窗口显示前就存在）
        DispatchQueue.main.async {
            context.coordinator.setupColumnWidthTracking()
        }
        
        // 延迟查找 TableView，确保它已经创建
        // 使用多次尝试确保找到 TableView，但使用更短的延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            context.coordinator.setupColumnWidthTracking()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.setupColumnWidthTracking()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            context.coordinator.setupColumnWidthTracking()
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // 当视图更新时（包括数据变化），立即尝试设置列宽
        DispatchQueue.main.async {
            context.coordinator.setupColumnWidthTracking()
        }
        // 使用多个延迟确保 TableView 已完全更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            context.coordinator.setupColumnWidthTracking()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            context.coordinator.setupColumnWidthTracking()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            context.coordinator.setupColumnWidthTracking()
        }
        // 再增加一个延迟，确保所有渲染完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            context.coordinator.setupColumnWidthTracking()
        }
    }
}

extension TableViewColumnWidthTracker.Coordinator {
    func setupColumnWidthTracking() {
        // 查找所有窗口中的 NSTableView 并设置监听器
        for window in NSApplication.shared.windows {
            if let contentView = window.contentView {
                findAndSetupTableView(in: contentView)
            }
        }
    }
    
    func findAndSetupTableView(in view: NSView) {
        // 检查是否是 NSScrollView 包含 NSTableView
        guard let scrollView = view as? NSScrollView,
              let tableView = scrollView.documentView as? NSTableView else {
            // 如果不是 NSTableView，递归查找子视图
            for subview in view.subviews {
                findAndSetupTableView(in: subview)
            }
            return
        }

        let tableViewPointer = Unmanaged.passUnretained(tableView).toOpaque()

        // 检查是否已经设置过这个 TableView
        let isNewSetup = !setupTableViews.contains(tableViewPointer)

        if !isNewSetup {
            // 已经设置过监听器
            return
        }

        // 标记为已设置
        setupTableViews.insert(tableViewPointer)

        // 启用列调整大小和重新排序
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = true

        // 设置列标题对齐方式
        for (index, column) in tableView.tableColumns.enumerated() {
            if index < self.columnNames.count {
                let columnName = self.columnNames[index]
                let headerCell = column.headerCell
                // 扩展名列和大小列标题右对齐
                if columnName == "扩展名" || columnName == "大小" {
                    headerCell.alignment = .right
                } else {
                    headerCell.alignment = .left
                }
            }
        }

        // 只使用 NotificationCenter 监听列调整通知（避免与 KVO 重复）
        NotificationCenter.default.addObserver(
            forName: NSTableView.columnDidResizeNotification,
            object: tableView,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let notificationTableView = notification.object as? NSTableView,
                  let userInfo = notification.userInfo,
                  let column = userInfo["NSTableColumn"] as? NSTableColumn,
                  let columnIndex = notificationTableView.tableColumns.firstIndex(of: column),
                  columnIndex < self.columnNames.count else {
                return
            }
            let columnName = self.columnNames[columnIndex]
            let width = column.width

            // 使用防抖机制，避免频繁保存
            self.pendingSaves[columnName]?.invalidate()
            let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.onWidthChange(columnName, width)
                self.pendingSaves.removeValue(forKey: columnName)
            }
            self.pendingSaves[columnName] = timer
        }
    }
    
}
