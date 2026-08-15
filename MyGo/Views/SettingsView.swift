//
//  SettingsView.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var indexManager: FileIndexManager

    init(indexManager: FileIndexManager = FileIndexManager()) {
        self._indexManager = ObservedObject(wrappedValue: indexManager)
    }

    var body: some View {
        TabView {
            IndexSettingsView(indexManager: indexManager)
                .tabItem {
                    Label("索引", systemImage: "folder")
                }

            PathKeywordSettingsView()
                .tabItem {
                    Label("路径关键词", systemImage: "list.bullet")
                }

            HotKeySettingsView()
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }

            LogSettingsView()
                .tabItem {
                    Label("日志", systemImage: "doc.text")
                }
        }
        .frame(width: 480, height: 420)
    }
}

struct IndexSettingsView: View {
    @State private var indexDirectories: [String] = []
    @State private var showAddDirectoryDialog = false
    @ObservedObject var indexManager: FileIndexManager

    var body: some View {
        List {
            Section {
                if indexDirectories.isEmpty {
                    Text("还没有添加索引目录")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(indexDirectories, id: \.self) { directory in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text((directory as NSString).lastPathComponent)
                                Text(directory)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button {
                                removeDirectory(directory)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("移除")
                        }
                    }
                }

                Button {
                    showAddDirectoryDialog = true
                } label: {
                    Label("添加目录…", systemImage: "plus")
                }
            } header: {
                Text("索引目录")
            }

            Section {
                HStack(spacing: 12) {
                    Button {
                        indexManager.startIndexing()
                    } label: {
                        Label("重新索引", systemImage: "arrow.clockwise")
                    }
                    .disabled(indexManager.isIndexing)

                    if indexManager.isIndexing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } header: {
                Text("维护")
            }

            Section {
                LabeledContent("已索引文件数", value: "\(DatabaseManager.shared.getIndexedFileCount())")
            } header: {
                Text("统计")
            }
        }
        .listStyle(.inset)
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
        // 删除该目录下已索引的文件记录，并重启文件监控
        DatabaseManager.shared.removeFilesOutsideIndexedDirectories()
        indexManager.restartFileSystemWatcher()
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
        List {
            Section {
                if whitelists.isEmpty {
                    Text("还没有添加白名单")
                        .foregroundColor(.secondary)
                } else {
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
                    .onMove { source, destination in
                        moveWhitelist(from: source, to: destination)
                    }
                }

                Button {
                    showAddWhitelistDialog = true
                } label: {
                    Label("添加白名单…", systemImage: "plus")
                }
            } header: {
                Text("路径白名单")
            } footer: {
                Text("路径必须包含列表中的全部关键词，可拖动调整顺序")
                    .foregroundColor(.secondary)
            }

            Section {
                if blacklists.isEmpty {
                    Text("还没有添加黑名单")
                        .foregroundColor(.secondary)
                } else {
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
                    .onMove { source, destination in
                        moveBlacklist(from: source, to: destination)
                    }
                }

                Button {
                    showAddBlacklistDialog = true
                } label: {
                    Label("添加黑名单…", systemImage: "plus")
                }
            } header: {
                Text("路径黑名单")
            } footer: {
                Text("路径不能包含列表中的任何关键词，可拖动调整顺序")
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.inset)
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

    private func moveWhitelist(from source: IndexSet, to destination: Int) {
        whitelists.move(fromOffsets: source, toOffset: destination)
        PreferencesManager.shared.savePathWhitelists(whitelists)
        NotificationCenter.default.post(name: NSNotification.Name("PathKeywordListsUpdated"), object: nil)
    }

    private func moveBlacklist(from source: IndexSet, to destination: Int) {
        blacklists.move(fromOffsets: source, toOffset: destination)
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

// MARK: - 快捷键设置视图
struct HotKeySettingsView: View {
    @State private var keyCode: UInt32
    @State private var modifiers: UInt32
    @State private var isRecording = false
    @State private var showConflict = false

    init() {
        let combo = PreferencesManager.shared.getHotKey()
        _keyCode = State(initialValue: combo.keyCode)
        _modifiers = State(initialValue: combo.modifiers)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("显示主窗口") {
                    HStack(spacing: 8) {
                        HotKeyRecorderView(
                            keyCode: $keyCode,
                            modifiers: $modifiers,
                            isRecording: $isRecording,
                            onCommit: { newKeyCode, newModifiers in
                                let ok = HotKeyManager.shared.updateHotKey(keyCode: newKeyCode, modifiers: newModifiers)
                                if ok {
                                    PreferencesManager.shared.saveHotKey(keyCode: newKeyCode, modifiers: newModifiers)
                                    showConflict = false
                                } else {
                                    showConflict = true
                                }
                                return ok
                            }
                        )

                        if showConflict {
                            Text("快捷键已被其他应用占用")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            } header: {
                Text("全局快捷键")
            } footer: {
                Text("应用在前台时按快捷键新建窗口（系统标签偏好时合并为标签页），在后台时显示主窗口；点击后输入新组合，按 Delete 清除，按 Escape 取消。")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 日志设置视图
struct LogSettingsView: View {
    @State private var logPath: String = ""
    @State private var logEnabled: Bool = false
    @State private var logLevel: LogLevel = .info
    
    var body: some View {
        Form {
            Section {
                Toggle("启用日志", isOn: $logEnabled)
                    .onChange(of: logEnabled) { _, newValue in
                        PreferencesManager.shared.saveLogEnabled(newValue)
                    }
            } header: {
                Text("日志")
            } footer: {
                Text("启用后，应用会记录运行信息到日志文件。")
                    .foregroundColor(.secondary)
            }

            Section {
                Picker("日志等级", selection: $logLevel) {
                    Text("调试 (DEBUG)").tag(LogLevel.debug)
                    Text("信息 (INFO)").tag(LogLevel.info)
                    Text("警告 (WARNING)").tag(LogLevel.warning)
                    Text("错误 (ERROR)").tag(LogLevel.error)
                }
                .pickerStyle(.menu)
                .disabled(!logEnabled)
                .onChange(of: logLevel) { _, newValue in
                    PreferencesManager.shared.saveLogLevel(newValue)
                }
            } header: {
                Text("日志等级")
            } footer: {
                Text("只记录所选等级及以上的日志。")
                    .foregroundColor(.secondary)
            }

            Section {
                HStack {
                    Text(logPath.isEmpty ? "加载中..." : logPath)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }

                HStack(spacing: 12) {
                    Button {
                        openLogFile()
                    } label: {
                        Label("打开日志文件", systemImage: "folder")
                    }
                    .disabled(!logEnabled)

                    Button {
                        Logger.shared.clearLog()
                    } label: {
                        Label("清空日志", systemImage: "trash")
                    }
                    .disabled(!logEnabled)
                }
            } header: {
                Text("日志文件")
            }
        }
        .formStyle(.grouped)
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
