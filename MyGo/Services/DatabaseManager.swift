//
//  DatabaseManager.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation
import SQLite3

/// 数据库管理器
class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbPath: String
    /// 数据库操作队列（确保线程安全）
    private let dbQueue = DispatchQueue(label: "com.mygo.database", qos: .utility)
    
    private init() {
        let startTime = Date()
        Logger.shared.log("DatabaseManager init 开始", level: .debug)
        
        // 数据库文件路径
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolderURL = appSupportURL.appendingPathComponent("MyGo", isDirectory: true)
        
        Logger.shared.log("应用支持目录: \(appFolderURL.path)", level: .debug)
        
        // 创建应用支持目录
        let createDirStart = Date()
        try? fileManager.createDirectory(at: appFolderURL, withIntermediateDirectories: true)
        let createDirElapsed = Date().timeIntervalSince(createDirStart)
        Logger.shared.log("创建应用支持目录完成，耗时: \(String(format: "%.3f", createDirElapsed))秒", level: .debug)
        
        dbPath = appFolderURL.appendingPathComponent("index.db").path
        Logger.shared.log("数据库路径: \(dbPath)", level: .debug)
        
        openDatabase()
        
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("DatabaseManager init 完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
    }
    
    /// 打开数据库
    private func openDatabase() {
        let startTime = Date()
        Logger.shared.log("开始打开数据库", level: .debug)
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            Logger.shared.log("无法打开数据库: \(dbPath)", level: .error)
            return
        }
        
        let openElapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("数据库打开完成，耗时: \(String(format: "%.3f", openElapsed))秒", level: .debug)
        
        createTables()
    }
    
    /// 创建表
    private func createTables() {
        let startTime = Date()
        Logger.shared.log("开始创建数据库表", level: .debug)
        
        // 创建文件索引表
        let createFileIndexTable = """
        CREATE TABLE IF NOT EXISTS file_index (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            size INTEGER NOT NULL,
            is_directory INTEGER NOT NULL,
            created_date REAL,
            modified_date REAL,
            accessed_date REAL,
            file_extension TEXT,
            indexed_at REAL NOT NULL
        );
        """
        
        // 创建索引目录表
        let createIndexDirectoryTable = """
        CREATE TABLE IF NOT EXISTS index_directories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT UNIQUE NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 1,
            added_at REAL NOT NULL
        );
        """
        
        // 创建索引以提高搜索性能
        let createIndexes = """
        CREATE INDEX IF NOT EXISTS idx_name ON file_index(name);
        CREATE INDEX IF NOT EXISTS idx_path ON file_index(path);
        CREATE INDEX IF NOT EXISTS idx_extension ON file_index(file_extension);
        CREATE INDEX IF NOT EXISTS idx_size ON file_index(size);
        CREATE INDEX IF NOT EXISTS idx_modified_date ON file_index(modified_date);
        """
        
        if sqlite3_exec(db, createFileIndexTable, nil, nil, nil) != SQLITE_OK {
            Logger.shared.log("创建文件索引表失败", level: .error)
        } else {
            Logger.shared.log("创建文件索引表成功", level: .debug)
        }
        
        if sqlite3_exec(db, createIndexDirectoryTable, nil, nil, nil) != SQLITE_OK {
            Logger.shared.log("创建索引目录表失败", level: .error)
        } else {
            Logger.shared.log("创建索引目录表成功", level: .debug)
        }
        
        if sqlite3_exec(db, createIndexes, nil, nil, nil) != SQLITE_OK {
            Logger.shared.log("创建索引失败", level: .error)
        } else {
            Logger.shared.log("创建索引成功", level: .debug)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("数据库表创建完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
    }
    
    /// 清空文件索引
    func clearFileIndex() {
        dbQueue.sync { [weak self] in
            guard let self = self else { return }
            let deleteSQL = "DELETE FROM file_index;"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("清空文件索引成功")
                }
            }
            sqlite3_finalize(statement)
        }
    }
    
    /// 插入或更新文件索引（线程安全）
    func insertOrUpdateFile(_ item: FileItem) {
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            
            let insertSQL = """
            INSERT OR REPLACE INTO file_index 
            (path, name, size, is_directory, created_date, modified_date, accessed_date, file_extension, indexed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (item.path as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (item.name as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(statement, 3, Int64(item.size))
                sqlite3_bind_int(statement, 4, item.isDirectory ? 1 : 0)
                
                if let createdDate = item.createdDate {
                    sqlite3_bind_double(statement, 5, createdDate.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 5)
                }
                
                if let modifiedDate = item.modifiedDate {
                    sqlite3_bind_double(statement, 6, modifiedDate.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 6)
                }
                
                if let accessedDate = item.accessedDate {
                    sqlite3_bind_double(statement, 7, accessedDate.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 7)
                }
                
                if let fileExt = item.fileExtension {
                    sqlite3_bind_text(statement, 8, (fileExt as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(statement, 8)
                }
                
                sqlite3_bind_double(statement, 9, Date().timeIntervalSince1970)
                
                if sqlite3_step(statement) != SQLITE_DONE {
                    if let errorMsg = sqlite3_errmsg(self.db) {
                        Logger.shared.log("插入文件索引失败: \(String(cString: errorMsg))", level: .error)
                    } else {
                        Logger.shared.log("插入文件索引失败", level: .error)
                    }
                }
            }
            sqlite3_finalize(statement)
        }
    }
    
    /// 批量插入或更新文件（优化性能，使用事务，同步执行，非 actor 隔离）
    nonisolated func insertOrUpdateFiles(_ items: [FileItem]) {
        guard !items.isEmpty else { return }
        
        // 使用同步方式确保批量插入完成
        dbQueue.sync { [weak self] in
            guard let self = self else { return }
            
            let insertSQL = """
            INSERT OR REPLACE INTO file_index 
            (path, name, size, is_directory, created_date, modified_date, accessed_date, file_extension, indexed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(self.db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
                Logger.shared.log("准备批量插入语句失败", level: .error)
                return
            }
            
            // 开始事务
            sqlite3_exec(self.db, "BEGIN TRANSACTION", nil, nil, nil)
            
            let indexedAt = Date().timeIntervalSince1970
            
            for item in items {
                sqlite3_reset(statement)
                
                sqlite3_bind_text(statement, 1, (item.path as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (item.name as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(statement, 3, Int64(item.size))
                sqlite3_bind_int(statement, 4, item.isDirectory ? 1 : 0)
                
                if let createdDate = item.createdDate {
                    sqlite3_bind_double(statement, 5, createdDate.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 5)
                }
                
                if let modifiedDate = item.modifiedDate {
                    sqlite3_bind_double(statement, 6, modifiedDate.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 6)
                }
                
                if let accessedDate = item.accessedDate {
                    sqlite3_bind_double(statement, 7, accessedDate.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 7)
                }
                
                if let fileExt = item.fileExtension {
                    sqlite3_bind_text(statement, 8, (fileExt as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(statement, 8)
                }
                
                sqlite3_bind_double(statement, 9, indexedAt)
                
                if sqlite3_step(statement) != SQLITE_DONE {
                    if let errorMsg = sqlite3_errmsg(self.db) {
                        Logger.shared.log("批量插入文件失败: \(item.path) - \(String(cString: errorMsg))", level: .error)
                    }
                }
            }
            
            sqlite3_finalize(statement)
            
            // 提交事务
            if sqlite3_exec(self.db, "COMMIT", nil, nil, nil) != SQLITE_OK {
                Logger.shared.log("提交事务失败", level: .error)
            }
        }
    }
    
    /// 删除文件索引
    func deleteFile(path: String) {
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            let deleteSQL = "DELETE FROM file_index WHERE path = ?;"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }
    
    /// 搜索文件（旧版本兼容）
    func searchFiles(query: String, useRegex: Bool, filter: SearchFilter?) -> [FileItem] {
        var parsed = SearchQueryParser.parse(query)
        parsed.useRegex = useRegex
        parsed.modifiers.useRegex = useRegex
        return searchFiles(parsedQuery: parsed, filter: filter)
    }
    
    /// 搜索文件（使用解析后的查询）
    func searchFiles(parsedQuery: SearchQueryParser.ParsedQuery, filter: SearchFilter?, whitelist: PathKeywordList? = nil, blacklist: PathKeywordList? = nil) -> [FileItem] {
        return dbQueue.sync { [weak self] in
            guard let self = self else { return [FileItem]() }
            var results: [FileItem] = []
            var searchSQL = "SELECT path, name, size, is_directory, created_date, modified_date, accessed_date, file_extension FROM file_index WHERE 1=1"
            var conditions: [String] = []
            var parameters: [String] = []
        
        // 应用路径约束
        if !parsedQuery.pathConstraints.isEmpty {
            var pathConditions: [String] = []
            for path in parsedQuery.pathConstraints {
                pathConditions.append("path LIKE ?")
                parameters.append("\(path)%")
            }
            if !pathConditions.isEmpty {
                conditions.append("(\(pathConditions.joined(separator: " OR ")))")
            }
        }
        
        // 应用文件类型修饰符
        if parsedQuery.fileOnly {
            conditions.append("is_directory = 0")
        }
        if parsedQuery.folderOnly {
            conditions.append("is_directory = 1")
        }
        
        // 构建搜索词条件
        if !parsedQuery.searchTerms.isEmpty {
            var termConditions: [String] = []
            
            for term in parsedQuery.searchTerms {
                // 默认只搜索文件名，除非明确使用 path: 修饰符
                if parsedQuery.useRegex {
                    // 正则表达式搜索 - 先使用 LIKE 预过滤
                    let escapedTerm = term.replacingOccurrences(of: "%", with: "\\%")
                    if parsedQuery.matchPath {
                        // 如果使用 path: 修饰符，搜索文件名和路径
                        termConditions.append("(name LIKE ? OR path LIKE ?)")
                        parameters.append("%\(escapedTerm)%")
                        parameters.append("%\(escapedTerm)%")
                    } else {
                        // 默认只搜索文件名
                        termConditions.append("name LIKE ?")
                        parameters.append("%\(escapedTerm)%")
                    }
                } else {
                    // 通配符和普通搜索
                    let pattern = term
                        .replacingOccurrences(of: ".", with: "\\.")
                        .replacingOccurrences(of: "*", with: "%")
                        .replacingOccurrences(of: "?", with: "_")
                        .replacingOccurrences(of: "%", with: "\\%")
                        .replacingOccurrences(of: "_", with: "\\_")
                    
                    if parsedQuery.matchPath {
                        // 如果使用 path: 修饰符，搜索文件名和路径
                        termConditions.append("(name LIKE ? ESCAPE '\\' OR path LIKE ? ESCAPE '\\')")
                        parameters.append("%\(pattern)%")
                        parameters.append("%\(pattern)%")
                    } else {
                        // 默认只搜索文件名（不搜索路径，避免匹配到子文件）
                        termConditions.append("name LIKE ? ESCAPE '\\'")
                        parameters.append("%\(pattern)%")
                    }
                }
            }
            
            // 应用操作符逻辑
            if !termConditions.isEmpty {
                if parsedQuery.operators.contains(.or) {
                    // 如果有 OR 操作符，使用 OR 连接
                    conditions.append("(\(termConditions.joined(separator: " OR ")))")
                } else {
                    // 默认使用 AND 连接
                    conditions.append("(\(termConditions.joined(separator: " AND ")))")
                }
            }
        }
        
        // 应用过滤器
        if let filter = filter {
            if let extensions = filter.fileExtensions, !extensions.isEmpty {
                let placeholders = extensions.map { _ in "?" }.joined(separator: ",")
                conditions.append("file_extension IN (\(placeholders))")
                for ext in extensions {
                    parameters.append(ext)
                }
            }
            
            if let minSize = filter.minSize {
                conditions.append("size >= ?")
                parameters.append(String(minSize))
            }
            
            if let maxSize = filter.maxSize {
                conditions.append("size <= ?")
                parameters.append(String(maxSize))
            }
            
            if let minDate = filter.minDate {
                conditions.append("modified_date >= ?")
                parameters.append(String(minDate.timeIntervalSince1970))
            }
            
            if let maxDate = filter.maxDate {
                conditions.append("modified_date <= ?")
                parameters.append(String(maxDate.timeIntervalSince1970))
            }
        }
        
        if !conditions.isEmpty {
            searchSQL += " AND " + conditions.joined(separator: " AND ")
        }
        
        searchSQL += " LIMIT 10000;"
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(self.db, searchSQL, -1, &statement, nil) == SQLITE_OK {
            // 绑定参数
            for (index, param) in parameters.enumerated() {
                if let doubleValue = Double(param) {
                    sqlite3_bind_double(statement, Int32(index + 1), doubleValue)
                } else {
                    sqlite3_bind_text(statement, Int32(index + 1), (param as NSString).utf8String, -1, nil)
                }
            }
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let pathCString = sqlite3_column_text(statement, 0) {
                    let path = String(cString: pathCString)
                    let url = URL(fileURLWithPath: path)
                    let item = FileItem(url: url)
                    results.append(item)
                }
            }
        }
        sqlite3_finalize(statement)
        
        // 处理 NOT 操作符和正则表达式
        if !parsedQuery.searchTerms.isEmpty {
            // 处理 NOT 操作符
            var notTerms: [String] = []
            var termIndex = 0
            for (_, op) in parsedQuery.operators.enumerated() {
                if op == .not {
                    if termIndex < parsedQuery.searchTerms.count {
                        notTerms.append(parsedQuery.searchTerms[termIndex])
                    }
                }
                if op != .not {
                    termIndex += 1
                }
            }
            
            // 过滤掉 NOT 项
            if !notTerms.isEmpty {
                results = results.filter { item in
                    for notTerm in notTerms {
                        let searchText = parsedQuery.matchPath ? item.path : item.name
                        if parsedQuery.caseSensitive {
                            if searchText.contains(notTerm) {
                                return false
                            }
                        } else {
                            if searchText.localizedCaseInsensitiveContains(notTerm) {
                                return false
                            }
                        }
                    }
                    return true
                }
            }
            
            // 如果使用正则表达式，在内存中进一步过滤
            if parsedQuery.useRegex {
                for term in parsedQuery.searchTerms {
                    if let regex = try? NSRegularExpression(
                        pattern: term,
                        options: parsedQuery.caseSensitive ? [] : [.caseInsensitive]
                    ) {
                        results = results.filter { item in
                            let searchText = parsedQuery.matchPath ? item.path : item.name
                            let range = NSRange(searchText.startIndex..., in: searchText)
                            return regex.firstMatch(in: searchText, range: range) != nil
                        }
                    }
                }
            } else if parsedQuery.caseSensitive {
                // 大小写敏感搜索
                results = results.filter { item in
                    for term in parsedQuery.searchTerms {
                        let searchText = parsedQuery.matchPath ? item.path : item.name
                        if !searchText.contains(term) {
                            return false
                        }
                    }
                    return true
                }
            }
        }
        
        // 应用路径关键词筛选（白名单和黑名单）
        if let whitelist = whitelist, !whitelist.keywords.isEmpty {
            results = results.filter { item in
                whitelist.matchesWhitelist(item.path)
            }
        }
        
        if let blacklist = blacklist, !blacklist.keywords.isEmpty {
            results = results.filter { item in
                blacklist.matchesBlacklist(item.path)
            }
        }
        
        return results
        }
    }
    
    /// 添加索引目录
    func addIndexDirectory(path: String) -> Bool {
        return dbQueue.sync { [weak self] in
            guard let self = self else { return false }
            let insertSQL = "INSERT OR IGNORE INTO index_directories (path, enabled, added_at) VALUES (?, 1, ?);"
            var statement: OpaquePointer?
            var success = false
            
            if sqlite3_prepare_v2(self.db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)
                sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    success = true
                }
            }
            sqlite3_finalize(statement)
            return success
        }
    }
    
    /// 删除索引目录
    func removeIndexDirectory(path: String) {
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            let deleteSQL = "DELETE FROM index_directories WHERE path = ?;"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }
    
    /// 获取所有索引目录
    func getIndexDirectories() -> [String] {
        return dbQueue.sync { [weak self] in
            guard let self = self else { return [String]() }
            let startTime = Date()
            Logger.shared.log("开始获取索引目录列表", level: .debug)
            
            var directories: [String] = []
            let selectSQL = "SELECT path FROM index_directories WHERE enabled = 1 ORDER BY added_at;"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, selectSQL, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let pathCString = sqlite3_column_text(statement, 0) {
                        directories.append(String(cString: pathCString))
                    }
                }
            }
            sqlite3_finalize(statement)
            
            let elapsed = Date().timeIntervalSince(startTime)
            Logger.shared.log("获取索引目录列表完成，数量: \(directories.count)，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
            
            return directories
        }
    }
    
    /// 获取索引文件总数
    func getIndexedFileCount() -> Int {
        return dbQueue.sync { [weak self] in
            guard let self = self else { return 0 }
            let countSQL = "SELECT COUNT(*) FROM file_index;"
            var statement: OpaquePointer?
            var count = 0
            
            if sqlite3_prepare_v2(self.db, countSQL, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(statement, 0))
                }
            }
            sqlite3_finalize(statement)
            return count
        }
    }
    
    deinit {
        // 等待所有数据库操作完成后再关闭
        dbQueue.sync { [weak self] in
            guard let self = self else { return }
            sqlite3_close(self.db)
        }
    }
}

