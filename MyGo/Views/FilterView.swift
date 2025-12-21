//
//  FilterView.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI

struct FilterView: View {
    @Binding var filter: SearchFilter
    @Binding var isPresented: Bool
    @State private var fileExtensionsText = ""
    @State private var minSizeText = ""
    @State private var maxSizeText = ""
    @State private var showDateFilter = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text("筛选器")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 搜索选项
                    VStack(alignment: .leading, spacing: 8) {
                        Text("搜索选项")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Toggle("仅文件", isOn: $filter.fileOnly)
                            .onChange(of: filter.fileOnly) { oldValue, newValue in
                                if newValue {
                                    filter.folderOnly = false
                                }
                            }
                        
                        Toggle("仅文件夹", isOn: $filter.folderOnly)
                            .onChange(of: filter.folderOnly) { oldValue, newValue in
                                if newValue {
                                    filter.fileOnly = false
                                }
                            }
                        
                        Toggle("大小写敏感", isOn: $filter.caseSensitive)
                        
                        Toggle("匹配路径", isOn: $filter.matchPath)
                            .help("启用后，搜索会匹配完整路径，而不仅仅是文件名")
                        
                        Toggle("使用正则表达式", isOn: $filter.useRegex)
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // 文件类型过滤
                    VStack(alignment: .leading, spacing: 4) {
                        Text("文件类型（用逗号分隔，如：jpg,mp4,pdf）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("例如: jpg, mp4, pdf", text: $fileExtensionsText)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: fileExtensionsText) { oldValue, newValue in
                                let extensions = newValue
                                    .split(separator: ",")
                                    .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                                    .filter { !$0.isEmpty }
                                filter.fileExtensions = extensions.isEmpty ? nil : Set(extensions)
                            }
                    }
                    
                    // 文件大小过滤
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最小大小（MB）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0", text: $minSizeText)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: minSizeText) { oldValue, newValue in
                                    if let mb = Double(newValue), mb > 0 {
                                        filter.minSize = Int64(mb * 1024 * 1024)
                                    } else {
                                        filter.minSize = nil
                                    }
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最大大小（MB）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("无限制", text: $maxSizeText)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: maxSizeText) { oldValue, newValue in
                                    if let mb = Double(newValue), mb > 0 {
                                        filter.maxSize = Int64(mb * 1024 * 1024)
                                    } else {
                                        filter.maxSize = nil
                                    }
                                }
                        }
                    }
                    
                    // 日期过滤
                    Toggle("启用日期过滤", isOn: $showDateFilter)
                    
                    if showDateFilter {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("日期类型", selection: $filter.dateType) {
                                Text("创建日期").tag(SearchFilter.DateFilterType.created)
                                Text("修改日期").tag(SearchFilter.DateFilterType.modified)
                                Text("访问日期").tag(SearchFilter.DateFilterType.accessed)
                            }
                            .pickerStyle(.segmented)
                            
                            DatePicker("开始日期", selection: Binding(
                                get: { filter.minDate ?? Date() },
                                set: { filter.minDate = $0 }
                            ), displayedComponents: [.date])
                            
                            DatePicker("结束日期", selection: Binding(
                                get: { filter.maxDate ?? Date() },
                                set: { filter.maxDate = $0 }
                            ), displayedComponents: [.date])
                        }
                    }
                    
                    Divider()
                    
                    // 清除过滤器
                    Button("清除所有过滤器") {
                        filter = SearchFilter()
                        fileExtensionsText = ""
                        minSizeText = ""
                        maxSizeText = ""
                        showDateFilter = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .frame(width: 320)
    }
}

