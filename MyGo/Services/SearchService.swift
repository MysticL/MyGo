//
//  SearchService.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation
import Combine

/// 搜索服务
class SearchService: ObservableObject {
    @Published var searchHistory: [String] = []
    @Published var searchResults: [FileItem] = []
    
    private let maxHistoryCount = 50
    private let historyKey = "com.mygo.searchHistory"
    private let databaseManager = DatabaseManager.shared
    
    init() {
        let startTime = Date()
        Logger.shared.log("SearchService init 开始", level: .debug)
        loadSearchHistory()
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("SearchService init 完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
    }
    
    /// 执行搜索
    func search(query: String, filter: SearchFilter? = nil, useRegex: Bool = false, whitelist: PathKeywordList? = nil, blacklist: PathKeywordList? = nil) {
        guard !query.isEmpty else {
            Logger.shared.log("搜索行为: 查询为空，清空结果", level: .info)
            searchResults = []
            return
        }
        
        // 解析搜索查询
        var parsed = SearchQueryParser.parse(query)
        
        // 应用筛选器中的修饰符选项（优先级高于搜索框中的设置）
        if let filter = filter {
            parsed.fileOnly = filter.fileOnly
            parsed.folderOnly = filter.folderOnly
            parsed.caseSensitive = filter.caseSensitive
            parsed.matchPath = filter.matchPath
            parsed.useRegex = filter.useRegex
            parsed.modifiers.fileOnly = filter.fileOnly
            parsed.modifiers.folderOnly = filter.folderOnly
            parsed.modifiers.caseSensitive = filter.caseSensitive
            parsed.modifiers.matchPath = filter.matchPath
            parsed.modifiers.useRegex = filter.useRegex
        } else {
            // 如果没有筛选器，使用搜索框中的正则表达式设置
            if useRegex {
                parsed.useRegex = true
                parsed.modifiers.useRegex = true
            }
        }
        
        // 构建搜索参数日志
        var searchParams: [String] = ["查询: \"\(query)\""]
        if let filter = filter {
            searchParams.append("筛选器: 文件=\(filter.fileOnly), 文件夹=\(filter.folderOnly), 区分大小写=\(filter.caseSensitive), 匹配路径=\(filter.matchPath), 正则=\(filter.useRegex)")
        }
        if let whitelist = whitelist {
            searchParams.append("白名单: \(whitelist.name)")
        }
        if let blacklist = blacklist {
            searchParams.append("黑名单: \(blacklist.name)")
        }
        Logger.shared.log("搜索行为: \(searchParams.joined(separator: ", "))", level: .info)
        
        // 从数据库搜索
        let results = databaseManager.searchFiles(parsedQuery: parsed, filter: filter, whitelist: whitelist, blacklist: blacklist)
        searchResults = results
        
        Logger.shared.log("搜索行为: 找到 \(results.count) 个结果", level: .info)
        
        // 保存搜索历史
        if !query.isEmpty {
            addToHistory(query)
        }
    }
    
    /// 添加到搜索历史
    private func addToHistory(_ query: String) {
        // 移除重复项
        searchHistory.removeAll { $0 == query }
        // 添加到开头
        searchHistory.insert(query, at: 0)
        // 限制历史记录数量
        if searchHistory.count > maxHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxHistoryCount))
        }
        saveSearchHistory()
    }
    
    /// 保存搜索历史
    private func saveSearchHistory() {
        UserDefaults.standard.set(searchHistory, forKey: historyKey)
    }
    
    /// 加载搜索历史
    private func loadSearchHistory() {
        let startTime = Date()
        Logger.shared.log("开始加载搜索历史", level: .debug)
        searchHistory = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("搜索历史加载完成，数量: \(searchHistory.count)，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
    }
    
    /// 清除搜索历史
    func clearHistory() {
        searchHistory = []
        saveSearchHistory()
    }
}

