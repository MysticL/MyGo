//
//  SearchQueryParser.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation

/// 搜索查询解析器
struct SearchQueryParser {
    /// 解析后的搜索条件
    struct ParsedQuery {
        var searchTerms: [String] = []
        var operators: [SearchOperator] = []
        var modifiers: SearchModifiers = SearchModifiers()
        var pathConstraints: [String] = []
        var useRegex: Bool = false
        var caseSensitive: Bool = false
        var matchPath: Bool = false  // 默认不匹配路径，只匹配文件名
        var fileOnly: Bool = false
        var folderOnly: Bool = false
    }
    
    /// 搜索操作符
    enum SearchOperator {
        case and
        case or
        case not
    }
    
    /// 搜索修饰符
    struct SearchModifiers {
        var caseSensitive: Bool = false
        var matchPath: Bool = false  // 默认不匹配路径，只匹配文件名
        var fileOnly: Bool = false
        var folderOnly: Bool = false
        var useRegex: Bool = false
    }
    
    /// 解析搜索查询
    static func parse(_ query: String) -> ParsedQuery {
        var parsed = ParsedQuery()
        var currentQuery = query.trimmingCharacters(in: .whitespaces)
        
        // 解析修饰符
        parsed = parseModifiers(&currentQuery, into: parsed)
        
        // 解析路径约束
        parsed = parsePathConstraints(&currentQuery, into: parsed)
        
        // 解析引号内的词组
        var terms: [String] = []
        var operators: [SearchOperator] = []
        var inQuotes = false
        var currentTerm = ""
        var i = currentQuery.startIndex
        
        while i < currentQuery.endIndex {
            let char = currentQuery[i]
            
            if char == "\"" {
                if inQuotes {
                    // 结束引号
                    if !currentTerm.isEmpty {
                        terms.append(currentTerm)
                        currentTerm = ""
                    }
                    inQuotes = false
                } else {
                    // 开始引号
                    if !currentTerm.isEmpty {
                        terms.append(currentTerm)
                        currentTerm = ""
                    }
                    inQuotes = true
                }
            } else if !inQuotes {
                // 解析操作符
                if char == "|" {
                    if !currentTerm.isEmpty {
                        terms.append(currentTerm.trimmingCharacters(in: .whitespaces))
                        currentTerm = ""
                    }
                    operators.append(.or)
                } else if char == "!" && (i == currentQuery.startIndex || currentQuery[currentQuery.index(before: i)].isWhitespace) {
                    // NOT 操作符（前面是空格或开头）
                    if !currentTerm.isEmpty {
                        terms.append(currentTerm.trimmingCharacters(in: .whitespaces))
                        currentTerm = ""
                    }
                    operators.append(.not)
                } else if char.isWhitespace {
                    // 空格表示 AND
                    if !currentTerm.isEmpty {
                        terms.append(currentTerm.trimmingCharacters(in: .whitespaces))
                        currentTerm = ""
                        operators.append(.and)
                    }
                } else {
                    currentTerm.append(char)
                }
            } else {
                // 引号内的内容
                currentTerm.append(char)
            }
            
            i = currentQuery.index(after: i)
        }
        
        // 添加最后一个词
        if !currentTerm.isEmpty {
            terms.append(currentTerm.trimmingCharacters(in: .whitespaces))
        }
        
        // 清理空词
        parsed.searchTerms = terms.filter { !$0.isEmpty }
        parsed.operators = operators
        
        return parsed
    }
    
    /// 解析修饰符
    private static func parseModifiers(_ query: inout String, into parsed: ParsedQuery) -> ParsedQuery {
        var result = parsed
        let patterns: [(String, (inout ParsedQuery) -> Void)] = [
            ("case:", { $0.caseSensitive = true; $0.modifiers.caseSensitive = true }),
            ("nocase:", { $0.caseSensitive = false; $0.modifiers.caseSensitive = false }),
            ("path:", { $0.matchPath = true; $0.modifiers.matchPath = true }),
            ("nopath:", { $0.matchPath = false; $0.modifiers.matchPath = false }),
            ("file:", { $0.fileOnly = true; $0.modifiers.fileOnly = true }),
            ("files:", { $0.fileOnly = true; $0.modifiers.fileOnly = true }),
            ("folder:", { $0.folderOnly = true; $0.modifiers.folderOnly = true }),
            ("folders:", { $0.folderOnly = true; $0.modifiers.folderOnly = true }),
            ("nofileonly:", { $0.fileOnly = false; $0.modifiers.fileOnly = false }),
            ("nofolderonly:", { $0.folderOnly = false; $0.modifiers.folderOnly = false }),
            ("regex:", { $0.useRegex = true; $0.modifiers.useRegex = true }),
            ("noregex:", { $0.useRegex = false; $0.modifiers.useRegex = false })
        ]
        
        for (pattern, action) in patterns {
            if let range = query.range(of: pattern, options: [.caseInsensitive]) {
                action(&result)
                // 移除修饰符从查询中
                let endIndex = query.index(range.upperBound, offsetBy: 0, limitedBy: query.endIndex) ?? query.endIndex
                query.removeSubrange(range.lowerBound..<endIndex)
            }
        }
        
        return result
    }
    
    /// 解析路径约束
    private static func parsePathConstraints(_ query: inout String, into parsed: ParsedQuery) -> ParsedQuery {
        var result = parsed
        
        // 匹配路径模式，如 d:\downloads\ 或 /Users/username/ 或 ~/Documents/
        let pathPattern = #"([a-zA-Z]:\\[^\s|!]*\\?|/[^\s|!]*/|~/[^\s|!]*/?)"#
        if let regex = try? NSRegularExpression(pattern: pathPattern) {
            let matches = regex.matches(in: query, range: NSRange(query.startIndex..., in: query))
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: query) {
                    var path = String(query[range]).trimmingCharacters(in: .whitespaces)
                    // 处理 macOS 路径
                    if path.hasPrefix("~/") {
                        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                        path = path.replacingOccurrences(of: "~", with: homeDir)
                    }
                    result.pathConstraints.append(path)
                    query.removeSubrange(range)
                }
            }
        }
        
        return result
    }
}

