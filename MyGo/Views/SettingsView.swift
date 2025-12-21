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
            IndexSettingsView(indexManager: indexManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 500)
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

