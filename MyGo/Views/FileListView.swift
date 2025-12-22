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
    
    // 统一的默认列宽定义
    private static let defaultColumnWidths: [String: CGFloat] = [
        "名称": 400,
        "路径": 600,
        "文件格式": 50,
        "大小": 50,
        "修改日期": 150
    ]
    
    @State private var columnWidths: [String: CGFloat] = Self.defaultColumnWidths
    @State private var columnWidthsApplied = false
    @State private var columnWidthCheckTimer: Timer?
    @State private var isCheckingColumnWidths = false
    @State private var isApplyingColumnWidths = false  // 标记是否正在应用列宽，防止重复应用
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
                        Logger.shared.log("双击文件: \(file.name) (路径: \(file.path))", level: .info)
                        onFileAction(file, .open)
                    }
                    .contextMenu {
                        Button("打开") {
                            Logger.shared.log("右键菜单打开文件: \(file.name)", level: .info)
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
                .width(min: 200, ideal: getColumnWidth("名称", defaultWidth: Self.defaultColumnWidths["名称"] ?? 400))
                
                // 路径列 - 可排序（只显示目录路径，默认去掉前两级）
                TableColumn("路径", value: \.directoryPath) { file in
                    Text(file.shortenedDirectoryPath)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            onFileAction(file, .open)
                        }
                }
                .width(min: 200, ideal: getColumnWidth("路径", defaultWidth: Self.defaultColumnWidths["路径"] ?? 600))
                
                // 文件格式列 - 可排序，右对齐
                TableColumn("文件格式", value: \.sortableExtension) { file in
                    Text(file.fileExtension?.uppercased() ?? "--")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            onFileAction(file, .open)
                        }
                }
                .width(min: 40, ideal: getColumnWidth("文件格式", defaultWidth: Self.defaultColumnWidths["文件格式"] ?? 50))
                
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
                .width(min: 40, ideal: getColumnWidth("大小", defaultWidth: Self.defaultColumnWidths["大小"] ?? 50))
                
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
                .width(min: 150, ideal: getColumnWidth("修改日期", defaultWidth: Self.defaultColumnWidths["修改日期"] ?? 150))
            }
            .id("table-\(columnWidths.values.sorted().reduce(0, +))-\(sortOrder.map { "\($0.order == .forward ? "↑" : "↓")\($0.keyPath)" }.joined(separator: ","))-\(files.count)") // 当列宽、排序或文件数量改变时强制重新创建 Table
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .opacity(columnWidthsApplied ? 1.0 : 0.0)
            .background(TableViewColumnWidthTracker(
                columnWidths: columnWidths,
                onColumnWidthsApplied: {
                    Logger.shared.log("列宽已应用: \(columnWidths.map { "\($0.key)=\(String(format: "%.1f", $0.value))" }.joined(separator: ", "))", level: .info)
                    withAnimation(.easeOut(duration: 0.1)) {
                        columnWidthsApplied = true
                    }
                }
            ))
            .onAppear {
                let startTime = Date()
                Logger.shared.log("FileListView onAppear 开始", level: .debug)
                
                let loadStart = Date()
                loadColumnWidths()
                let loadElapsed = Date().timeIntervalSince(loadStart)
                Logger.shared.log("列宽加载完成，耗时: \(String(format: "%.3f", loadElapsed))秒", level: .debug)
                
                columnWidthsApplied = false
                startColumnWidthCheckTimer()
                
                let elapsed = Date().timeIntervalSince(startTime)
                Logger.shared.log("FileListView onAppear 完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
            }
            .onDisappear {
                stopColumnWidthCheckTimer()
            }
            .onChange(of: sortOrder) { oldValue, newValue in
                let oldSort = oldValue.map { "\($0.order == .forward ? "↑" : "↓")\($0.keyPath)" }.joined(separator: ", ")
                let newSort = newValue.map { "\($0.order == .forward ? "↑" : "↓")\($0.keyPath)" }.joined(separator: ", ")
                Logger.shared.log("排序行为: \(oldSort) -> \(newSort)", level: .info)
                
                // 排序时：只重新加载列宽，不检测变动（因为 TableView 可能正在自动调整）
                isApplyingColumnWidths = true
                loadColumnWidths()
                columnWidthsApplied = false
                
                // 延迟重置标志，避免在排序过程中检测列宽变动
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isApplyingColumnWidths = false
                }
            }
            .onChange(of: files.count) { oldValue, newValue in
                Logger.shared.log("文件列表变化: \(oldValue) -> \(newValue)", level: .info)
                
                // 搜索时：只重新加载列宽，不检测变动（因为 TableView 可能正在自动调整）
                isApplyingColumnWidths = true
                loadColumnWidths()
                columnWidthsApplied = false
                
                // 延迟重置标志，避免在搜索过程中检测列宽变动
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isApplyingColumnWidths = false
                }
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
    /// 优先使用状态变量，如果状态变量中没有，则从 PreferencesManager 读取
    private func getColumnWidth(_ columnName: String, defaultWidth: CGFloat) -> CGFloat {
        // 优先使用状态变量
        if let savedWidth = columnWidths[columnName], savedWidth > 0 {
            return savedWidth
        }
        // 如果状态变量中没有，尝试从 PreferencesManager 读取（用于 Table 创建时的初始值）
        let loadedWidths = PreferencesManager.shared.getColumnWidths()
        if let savedWidth = loadedWidths[columnName], savedWidth > 0 {
            return savedWidth
        }
        return defaultWidth
    }
    
    /// 加载列宽
    private func loadColumnWidths() {
        let startTime = Date()
        Logger.shared.log("开始加载列宽", level: .debug)
        let loadStart = Date()
        let loadedWidths = PreferencesManager.shared.getColumnWidths()
        let loadElapsed = Date().timeIntervalSince(loadStart)
        Logger.shared.log("从 PreferencesManager 读取列宽完成，耗时: \(String(format: "%.3f", loadElapsed))秒", level: .debug)
        
        // 使用统一的默认值定义
        // 确保所有必需的列都有值（如果字典为空或缺少某些列，使用默认值）
        var needsSave = false
        var finalWidths: [String: CGFloat] = loadedWidths
        for (columnName, defaultWidth) in Self.defaultColumnWidths {
            if finalWidths[columnName] == nil || finalWidths[columnName] == 0 {
                finalWidths[columnName] = defaultWidth
                needsSave = true
                Logger.shared.log("列宽使用默认值: \(columnName)=\(String(format: "%.1f", defaultWidth))", level: .debug)
            }
        }
        
        // 更新状态变量
        columnWidths = finalWidths
        
        // 输出当前列宽变量的值
        Logger.shared.log("列宽状态变量已更新: \(columnWidths.map { "\($0.key)=\(String(format: "%.1f", $0.value))" }.sorted().joined(separator: ", "))", level: .debug)
        
        // 如果有更新，保存到偏好设置
        if needsSave {
            let saveStart = Date()
            PreferencesManager.shared.saveColumnWidths(columnWidths)
            let saveElapsed = Date().timeIntervalSince(saveStart)
            Logger.shared.log("列宽保存完成，耗时: \(String(format: "%.3f", saveElapsed))秒", level: .debug)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("列宽加载完成，总耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
    }
    
    /// 启动列宽检测定时器（每0.5秒检测一次）
    private func startColumnWidthCheckTimer() {
        stopColumnWidthCheckTimer()
        columnWidthCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkAndSaveColumnWidths()
        }
    }
    
    /// 停止列宽检测定时器
    private func stopColumnWidthCheckTimer() {
        columnWidthCheckTimer?.invalidate()
        columnWidthCheckTimer = nil
    }
    
    /// 检测列宽变动并保存（只在一个地方保存列宽）
    /// - Parameter completion: 检测并保存完成后的回调
    private func checkAndSaveColumnWidths(completion: (() -> Void)? = nil) {
        guard !isCheckingColumnWidths else {
            completion?()
            return
        }
        
        // 如果正在应用列宽（排序/搜索时），不检测变动
        guard !isApplyingColumnWidths else {
            Logger.shared.log("正在应用列宽，跳过检测", level: .debug)
            completion?()
            return
        }
        
        isCheckingColumnWidths = true
        
        // 获取当前 TableView 的实际列宽
        var currentWidths: [String: CGFloat] = [:]
        let columnNames = ["名称", "路径", "文件格式", "大小", "修改日期"]
        
        // 查找 TableView 并读取当前列宽
        for window in NSApplication.shared.windows {
            if let contentView = window.contentView {
                if let tableView = findTableView(in: contentView) {
                    for (index, column) in tableView.tableColumns.enumerated() {
                        if index < columnNames.count {
                            let columnName = columnNames[index]
                            currentWidths[columnName] = column.width
                        }
                    }
                    break
                }
            }
        }
        
        // 检查是否有变动
        var hasChanges = false
        var updatedWidths = columnWidths
        
        for (columnName, currentWidth) in currentWidths {
            let savedWidth = columnWidths[columnName] ?? 0
            if abs(currentWidth - savedWidth) > 0.1 {
                hasChanges = true
                updatedWidths[columnName] = currentWidth
                Logger.shared.log("列宽变动检测: \(columnName) \(String(format: "%.1f", savedWidth)) -> \(String(format: "%.1f", currentWidth))", level: .info)
            }
        }
        
        if hasChanges {
            // 更新状态变量
            columnWidths = updatedWidths
            
            // 保存到偏好设置（只在一个地方保存）
            Logger.shared.log("保存列宽: \(updatedWidths.map { "\($0.key)=\(String(format: "%.1f", $0.value))" }.sorted().joined(separator: ", "))", level: .info)
            PreferencesManager.shared.saveColumnWidths(updatedWidths)
            
            // 检查是否已更新完毕
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.verifyColumnWidthsApplied(updatedWidths) {
                    self.isCheckingColumnWidths = false
                    completion?()
                }
            }
        } else {
            isCheckingColumnWidths = false
            completion?()
        }
    }
    
    /// 验证列宽是否已应用完毕
    private func verifyColumnWidthsApplied(_ expectedWidths: [String: CGFloat], completion: @escaping () -> Void) {
        let columnNames = ["名称", "路径", "文件格式", "大小", "修改日期"]
        var allApplied = true
        
        for window in NSApplication.shared.windows {
            if let contentView = window.contentView {
                if let tableView = findTableView(in: contentView) {
                    for (index, column) in tableView.tableColumns.enumerated() {
                        if index < columnNames.count {
                            let columnName = columnNames[index]
                            if let expectedWidth = expectedWidths[columnName] {
                                let actualWidth = column.width
                                if abs(actualWidth - expectedWidth) > 0.1 {
                                    allApplied = false
                                    Logger.shared.log("列宽验证: \(columnName) 未完全应用 (期望: \(String(format: "%.1f", expectedWidth)), 实际: \(String(format: "%.1f", actualWidth)))", level: .info)
                                }
                            }
                        }
                    }
                    break
                }
            }
        }
        
        if allApplied {
            Logger.shared.log("列宽验证: 所有列宽已应用完毕", level: .info)
        }
        
        completion()
    }
    
    /// 查找 TableView
    private func findTableView(in view: NSView) -> NSTableView? {
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

/// 表格列宽跟踪器（仅用于应用列宽，不再监听列宽变化）
struct TableViewColumnWidthTracker: NSViewRepresentable {
    var columnWidths: [String: CGFloat]
    var onColumnWidthsApplied: (() -> Void)?
    
    class Coordinator: NSObject {
        var columnWidths: [String: CGFloat] = [:]
        var onColumnWidthsApplied: (() -> Void)?
        var columnNames = ["名称", "路径", "文件格式", "大小", "修改日期"]
        var setupTableViews: Set<UnsafeMutableRawPointer> = []
        var hasNotifiedApplied = false
        
        init(columnWidths: [String: CGFloat], onColumnWidthsApplied: (() -> Void)?) {
            self.columnWidths = columnWidths
            self.onColumnWidthsApplied = onColumnWidthsApplied
            super.init()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(columnWidths: columnWidths, onColumnWidthsApplied: onColumnWidthsApplied)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = false
        
        // 延迟查找 TableView，确保它已经创建
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.setupColumnWidthTracking()
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // 检查列宽是否真的改变了
        let oldWidths = context.coordinator.columnWidths
        let widthsChanged = oldWidths != columnWidths
        
        // 更新列宽数据
        context.coordinator.columnWidths = columnWidths
        context.coordinator.onColumnWidthsApplied = onColumnWidthsApplied
        
        // 只有当列宽真正改变时才重新应用
        if widthsChanged {
            Logger.shared.log("TableViewColumnWidthTracker 更新: 列宽已改变", level: .debug)
            // 重置通知状态，因为视图更新了
            context.coordinator.hasNotifiedApplied = false
            
            // 当视图更新时，延迟设置列宽，确保 TableView 已完全更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                context.coordinator.setupColumnWidthTracking()
            }
        } else {
            Logger.shared.log("TableViewColumnWidthTracker 更新: 列宽未改变，跳过应用", level: .debug)
        }
    }
}

extension TableViewColumnWidthTracker.Coordinator {
    private static var lastAppliedWidths: [String: CGFloat] = [:]
    private static var lastApplyTime: Date?
    
    func setupColumnWidthTracking() {
        let startTime = Date()
        Logger.shared.log("开始设置列宽跟踪", level: .debug)
        
        // 防抖：如果最近 0.1 秒内已经应用过相同的列宽，跳过
        if let lastTime = Self.lastApplyTime,
           Date().timeIntervalSince(lastTime) < 0.1,
           Self.lastAppliedWidths == columnWidths {
            Logger.shared.log("列宽跟踪：最近已应用相同列宽，跳过", level: .debug)
            return
        }
        
        // 查找所有窗口中的 NSTableView 并应用列宽
        for window in NSApplication.shared.windows {
            if let contentView = window.contentView {
                findAndSetupTableView(in: contentView)
            }
        }
        
        // 记录本次应用的列宽和时间
        Self.lastAppliedWidths = columnWidths
        Self.lastApplyTime = Date()
        
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("列宽跟踪设置完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
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

        let startTime = Date()
        Logger.shared.log("找到 TableView，开始应用列宽", level: .debug)

        let tableViewPointer = Unmanaged.passUnretained(tableView).toOpaque()

        // 检查是否已经设置过这个 TableView
        let isNewSetup = !setupTableViews.contains(tableViewPointer)

        // 启用列调整大小和重新排序
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = true

        // 设置列标题对齐方式和列宽
        var allWidthsApplied = true
        var appliedCount = 0
        
        for (index, column) in tableView.tableColumns.enumerated() {
            if index < self.columnNames.count {
                let columnName = self.columnNames[index]
                let headerCell = column.headerCell
                // 文件格式列和大小列标题右对齐
                if columnName == "文件格式" || columnName == "大小" {
                    headerCell.alignment = .right
                } else {
                    headerCell.alignment = .left
                }
                
                // 应用保存的列宽
                if let savedWidth = self.columnWidths[columnName], savedWidth > 0 {
                    let currentWidth = column.width
                    // 只有当宽度差异超过阈值时才应用
                    if abs(currentWidth - savedWidth) > 0.1 {
                        column.width = savedWidth
                        appliedCount += 1
                        Logger.shared.log("列宽应用: \(columnName) \(String(format: "%.1f", currentWidth)) -> \(String(format: "%.1f", savedWidth))", level: .debug)
                    }
                } else {
                    allWidthsApplied = false
                }
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("列宽应用完成，应用了 \(appliedCount) 列，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
        
        // 如果所有列宽都已应用，且尚未通知，则通知视图
        if allWidthsApplied && !self.hasNotifiedApplied {
            self.hasNotifiedApplied = true
            Logger.shared.log("所有列宽已应用，通知视图", level: .debug)
            DispatchQueue.main.async {
                self.onColumnWidthsApplied?()
            }
        }

        // 标记为已设置
        if isNewSetup {
            setupTableViews.insert(tableViewPointer)
        }
    }
    
}
