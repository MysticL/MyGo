//
//  SettingsView.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indexManager: FileIndexManager
    
    init(indexManager: FileIndexManager = FileIndexManager()) {
        self._indexManager = ObservedObject(wrappedValue: indexManager)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭")
                
                Text("设置")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // 内容区域
            TabView {
                IndexSettingsView(indexManager: indexManager)
                    .tabItem {
                        Label("索引设置", systemImage: "folder")
                    }
                
                PathKeywordSettingsView()
                    .tabItem {
                        Label("路径关键词", systemImage: "list.bullet")
                    }
                
                LogSettingsView()
                    .tabItem {
                        Label("日志", systemImage: "doc.text")
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 600)
    }
}

struct IndexSettingsView: View {
    @State private var indexDirectories: [String] = []
    @State private var showAddDirectoryDialog = false
    @State private var selectedDirectory: String?
    @ObservedObject var indexManager: FileIndexManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 工具栏
            HStack {
                Spacer()
                
                Button(action: {
                    showAddDirectoryDialog = true
                }) {
                    Image(systemName: "plus")
                    Text("添加目录")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    indexManager.startIndexing()
                }) {
                    Image(systemName: "arrow.clockwise")
                    Text("重新索引")
                }
                .buttonStyle(.bordered)
                .disabled(indexManager.isIndexing)
            }
            .padding()
            
            Divider()
            
            // 索引目录列表
            if indexDirectories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("还没有添加索引目录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击右上角的\"添加目录\"按钮来添加需要索引的目录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(indexDirectories, id: \.self) { directory in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text((directory as NSString).lastPathComponent)
                                    .font(.headline)
                                Text(directory)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                removeDirectory(directory)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDirectory = directory
                        }
                    }
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // 统计信息
            HStack {
                Text("已索引文件数: \(DatabaseManager.shared.getIndexedFileCount())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadDirectories()
        }
        .sheet(isPresented: $showAddDirectoryDialog) {
            AddDirectoryView { directory in
                addDirectory(directory)
            }
        }
    }
    
    /// 加载目录列表
    private func loadDirectories() {
        indexDirectories = DatabaseManager.shared.getIndexDirectories()
    }
    
    /// 添加目录
    private func addDirectory(_ path: String) {
        if DatabaseManager.shared.addIndexDirectory(path: path) {
            loadDirectories()
            // 自动开始索引新添加的目录
            indexManager.startIndexing()
        }
    }
    
    /// 删除目录
    private func removeDirectory(_ path: String) {
        DatabaseManager.shared.removeIndexDirectory(path: path)
        loadDirectories()
    }
}

struct AddDirectoryView: View {
    @Environment(\.dismiss) var dismiss
    var onAdd: (String) -> Void
    
    @State private var selectedPath: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择要索引的目录")
                .font(.headline)
            
            HStack {
                TextField("目录路径", text: $selectedPath)
                    .textFieldStyle(.roundedBorder)
                
                Button("浏览...") {
                    selectDirectory()
                }
            }
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("添加") {
                    if !selectedPath.isEmpty {
                        onAdd(selectedPath)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPath.isEmpty)
            }
        }
        .padding()
        .frame(width: 500)
    }
    
    /// 选择目录
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择要索引的目录"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                selectedPath = url.path
            }
        }
    }
}

// MARK: - 路径关键词设置视图
struct PathKeywordSettingsView: View {
    @State private var whitelists: [PathKeywordList] = []
    @State private var blacklists: [PathKeywordList] = []
    @State private var showAddWhitelistDialog = false
    @State private var showAddBlacklistDialog = false
    @State private var editingWhitelist: PathKeywordList?
    @State private var editingBlacklist: PathKeywordList?
    
    var body: some View {
        HStack(spacing: 0) {
            // 白名单设置
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("路径白名单")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        showAddWhitelistDialog = true
                    }) {
                        Image(systemName: "plus")
                        Text("添加")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                Divider()
                
                if whitelists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("还没有添加白名单")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("点击右上角的\"添加\"按钮来创建白名单")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(whitelists) { list in
                            PathKeywordListItemView(
                                list: list,
                                onEdit: {
                                    editingWhitelist = list
                                },
                                onDelete: {
                                    deleteWhitelist(list)
                                }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // 黑名单设置
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("路径黑名单")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        showAddBlacklistDialog = true
                    }) {
                        Image(systemName: "plus")
                        Text("添加")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                Divider()
                
                if blacklists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("还没有添加黑名单")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("点击右上角的\"添加\"按钮来创建黑名单")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(blacklists) { list in
                            PathKeywordListItemView(
                                list: list,
                                onEdit: {
                                    editingBlacklist = list
                                },
                                onDelete: {
                                    deleteBlacklist(list)
                                }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            loadLists()
        }
        .sheet(isPresented: $showAddWhitelistDialog) {
            EditPathKeywordListView(
                list: nil,
                isWhitelist: true,
                onSave: { list in
                    addWhitelist(list)
                }
            )
        }
        .sheet(isPresented: $showAddBlacklistDialog) {
            EditPathKeywordListView(
                list: nil,
                isWhitelist: false,
                onSave: { list in
                    addBlacklist(list)
                }
            )
        }
        .sheet(item: $editingWhitelist) { list in
            EditPathKeywordListView(
                list: list,
                isWhitelist: true,
                onSave: { updatedList in
                    updateWhitelist(updatedList)
                }
            )
        }
        .sheet(item: $editingBlacklist) { list in
            EditPathKeywordListView(
                list: list,
                isWhitelist: false,
                onSave: { updatedList in
                    updateBlacklist(updatedList)
                }
            )
        }
    }
    
    private func loadLists() {
        whitelists = PreferencesManager.shared.getPathWhitelists()
        blacklists = PreferencesManager.shared.getPathBlacklists()
    }
    
    private func addWhitelist(_ list: PathKeywordList) {
        whitelists.append(list)
        PreferencesManager.shared.savePathWhitelists(whitelists)
        NotificationCenter.default.post(name: NSNotification.Name("PathKeywordListsUpdated"), object: nil)
    }
    
    private func updateWhitelist(_ list: PathKeywordList) {
        if let index = whitelists.firstIndex(where: { $0.id == list.id }) {
            whitelists[index] = list
            PreferencesManager.shared.savePathWhitelists(whitelists)
            NotificationCenter.default.post(name: NSNotification.Name("PathKeywordListsUpdated"), object: nil)
        }
        editingWhitelist = nil
    }
    
    private func deleteWhitelist(_ list: PathKeywordList) {
        whitelists.removeAll { $0.id == list.id }
        PreferencesManager.shared.savePathWhitelists(whitelists)
        NotificationCenter.default.post(name: NSNotification.Name("PathKeywordListsUpdated"), object: nil)
    }
    
    private func addBlacklist(_ list: PathKeywordList) {
        blacklists.append(list)
        PreferencesManager.shared.savePathBlacklists(blacklists)
        NotificationCenter.default.post(name: NSNotification.Name("PathKeywordListsUpdated"), object: nil)
    }
    
    private func updateBlacklist(_ list: PathKeywordList) {
        if let index = blacklists.firstIndex(where: { $0.id == list.id }) {
            blacklists[index] = list
            PreferencesManager.shared.savePathBlacklists(blacklists)
            NotificationCenter.default.post(name: NSNotification.Name("PathKeywordListsUpdated"), object: nil)
        }
        editingBlacklist = nil
    }
    
    private func deleteBlacklist(_ list: PathKeywordList) {
        blacklists.removeAll { $0.id == list.id }
        PreferencesManager.shared.savePathBlacklists(blacklists)
        NotificationCenter.default.post(name: NSNotification.Name("PathKeywordListsUpdated"), object: nil)
    }
}

// MARK: - 路径关键词列表项视图
struct PathKeywordListItemView: View {
    let list: PathKeywordList
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
                if list.keywords.isEmpty {
                    Text("无关键词")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(list.keywords.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("编辑")
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("删除")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 编辑路径关键词列表视图
struct EditPathKeywordListView: View {
    @Environment(\.dismiss) var dismiss
    let list: PathKeywordList?
    let isWhitelist: Bool
    let onSave: (PathKeywordList) -> Void
    
    @State private var name: String = ""
    @State private var keywords: [String] = [""]
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isWhitelist ? "编辑路径白名单" : "编辑路径黑名单")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("名称")
                    .font(.subheadline)
                TextField("列表名称", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("关键词")
                        .font(.subheadline)
                    Spacer()
                    Button(action: {
                        keywords.append("")
                    }) {
                        Image(systemName: "plus")
                        Text("添加关键词")
                    }
                    .buttonStyle(.bordered)
                }
                
                ForEach(keywords.indices, id: \.self) { index in
                    HStack {
                        TextField("关键词", text: Binding(
                            get: { keywords[index] },
                            set: { keywords[index] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button(action: {
                            keywords.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(keywords.count <= 1)
                    }
                }
            }
            
            if isWhitelist {
                Text("白名单：路径必须包含所有关键词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("黑名单：路径不能包含任何关键词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("保存") {
                    let filteredKeywords = keywords.filter { !$0.isEmpty }
                    let newList = PathKeywordList(
                        id: list?.id ?? UUID(),
                        name: name,
                        keywords: filteredKeywords
                    )
                    onSave(newList)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 500)
        .onAppear {
            if let list = list {
                name = list.name
                keywords = list.keywords.isEmpty ? [""] : list.keywords
            }
        }
    }
}

// MARK: - 日志设置视图
struct LogSettingsView: View {
    @State private var logPath: String = ""
    @State private var logEnabled: Bool = false
    @State private var logLevel: LogLevel = .info
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("日志设置")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            Divider()
            
            // 日志开关和日志等级（并排显示）
            HStack(alignment: .top, spacing: 20) {
                // 日志开关
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("启用日志", isOn: $logEnabled)
                        .font(.headline)
                        .onChange(of: logEnabled) { oldValue, newValue in
                            PreferencesManager.shared.saveLogEnabled(newValue)
                        }
                    
                    Text("启用后，应用会记录运行信息到日志文件。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 日志等级
                VStack(alignment: .leading, spacing: 12) {
                    Text("日志等级")
                        .font(.headline)
                    
                    Picker("", selection: $logLevel) {
                        Text("调试 (DEBUG)").tag(LogLevel.debug)
                        Text("信息 (INFO)").tag(LogLevel.info)
                        Text("警告 (WARNING)").tag(LogLevel.warning)
                        Text("错误 (ERROR)").tag(LogLevel.error)
                    }
                    .pickerStyle(.segmented)
                    .disabled(!logEnabled)
                    .onChange(of: logLevel) { oldValue, newValue in
                        PreferencesManager.shared.saveLogLevel(newValue)
                    }
                    
                    Text("只记录所选等级及以上的日志。例如选择\"信息\"时，会记录信息、警告和错误日志。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            
            Divider()
            
            // 日志文件位置
            VStack(alignment: .leading, spacing: 12) {
                Text("日志文件位置")
                    .font(.headline)
                
                HStack {
                    Text(logPath.isEmpty ? "加载中..." : logPath)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    
                    Spacer()
                    
                    Button(action: {
                        openLogFile()
                    }) {
                        Image(systemName: "folder")
                        Text("打开日志文件")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!logEnabled)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
            
            Divider()
            
            HStack {
                Button(action: {
                    Logger.shared.clearLog()
                }) {
                    Image(systemName: "trash")
                    Text("清空日志")
                }
                .buttonStyle(.bordered)
                .disabled(!logEnabled)
                
                Spacer()
            }
            .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        logPath = Logger.shared.getLogFilePath()
        logEnabled = PreferencesManager.shared.getLogEnabled()
        logLevel = PreferencesManager.shared.getLogLevel()
    }
    
    private func openLogFile() {
        let url = Logger.shared.getLogFileURL()
        NSWorkspace.shared.open(url)
    }
}

