//
//  PathKeywordList.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation

/// 路径关键词列表
struct PathKeywordList: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var keywords: [String]
    
    init(id: UUID = UUID(), name: String, keywords: [String] = []) {
        self.id = id
        self.name = name
        self.keywords = keywords
    }
    
    /// 检查路径是否匹配白名单（路径必须包含所有关键词）
    func matchesWhitelist(_ path: String) -> Bool {
        guard !keywords.isEmpty else { return true }
        let lowercasedPath = path.lowercased()
        return keywords.allSatisfy { keyword in
            lowercasedPath.contains(keyword.lowercased())
        }
    }
    
    /// 检查路径是否匹配黑名单（路径不能包含任何关键词）
    func matchesBlacklist(_ path: String) -> Bool {
        guard !keywords.isEmpty else { return true }
        let lowercasedPath = path.lowercased()
        return !keywords.contains { keyword in
            lowercasedPath.contains(keyword.lowercased())
        }
    }
}

