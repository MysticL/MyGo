//
//  SearchBarView.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var showFilter: Bool
    @Binding var selectedWhitelist: PathKeywordList?
    @Binding var selectedBlacklist: PathKeywordList?
    @FocusState private var isFocused: Bool
    var onSearch: () -> Void
    
    @State private var whitelists: [PathKeywordList] = []
    @State private var blacklists: [PathKeywordList] = []
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索文件...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    // 提交时立即搜索
                    onSearch()
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    onSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // 路径白名单下拉框
            Picker("路径白名单", selection: $selectedWhitelist) {
                Text("无").tag(nil as PathKeywordList?)
                ForEach(whitelists) { list in
                    Text(list.name).tag(list as PathKeywordList?)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .onChange(of: selectedWhitelist) { oldValue, newValue in
                onSearch()
            }
            
            // 路径黑名单下拉框
            Picker("路径黑名单", selection: $selectedBlacklist) {
                Text("无").tag(nil as PathKeywordList?)
                ForEach(blacklists) { list in
                    Text(list.name).tag(list as PathKeywordList?)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .onChange(of: selectedBlacklist) { oldValue, newValue in
                onSearch()
            }
            
            // 搜索语法提示
            Menu {
                Text("搜索语法:")
                    .font(.headline)
                Divider()
                Text("空格: AND (与)")
                Text("| : OR (或)")
                Text("! : NOT (非)")
                Text("\"\" : 词组搜索")
                Divider()
                Text("提示: 修饰符选项可在筛选器中设置")
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("搜索语法帮助")
            
            // 筛选按钮
            Button(action: {
                showFilter.toggle()
            }) {
                Image(systemName: showFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .foregroundColor(showFilter ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("筛选")
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            isFocused = true
            loadLists()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PathKeywordListsUpdated"))) { _ in
            loadLists()
        }
    }
    
    private func loadLists() {
        whitelists = PreferencesManager.shared.getPathWhitelists()
        blacklists = PreferencesManager.shared.getPathBlacklists()
    }
}

