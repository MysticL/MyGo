//
//  SearchFilter.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation

/// 搜索过滤器
struct SearchFilter: Equatable, Codable {
    var fileExtensions: Set<String>?
    var minSize: Int64?
    var maxSize: Int64?
    var minDate: Date?
    var maxDate: Date?
    var dateType: DateFilterType = .modified
    
    // 修饰符选项
    var fileOnly: Bool = false
    var folderOnly: Bool = false
    var caseSensitive: Bool = false
    var matchPath: Bool = false
    var useRegex: Bool = false
    
    enum DateFilterType: String, Equatable, Codable {
        case created
        case modified
        case accessed
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case fileExtensions
        case minSize
        case maxSize
        case minDate
        case maxDate
        case dateType
        case fileOnly
        case folderOnly
        case caseSensitive
        case matchPath
        case useRegex
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 文件扩展名：从数组解码为 Set
        if let extensionsArray = try? container.decodeIfPresent([String].self, forKey: .fileExtensions) {
            fileExtensions = Set(extensionsArray)
        } else {
            fileExtensions = nil
        }
        
        minSize = try container.decodeIfPresent(Int64.self, forKey: .minSize)
        maxSize = try container.decodeIfPresent(Int64.self, forKey: .maxSize)
        minDate = try container.decodeIfPresent(Date.self, forKey: .minDate)
        maxDate = try container.decodeIfPresent(Date.self, forKey: .maxDate)
        dateType = try container.decodeIfPresent(DateFilterType.self, forKey: .dateType) ?? .modified
        
        fileOnly = try container.decodeIfPresent(Bool.self, forKey: .fileOnly) ?? false
        folderOnly = try container.decodeIfPresent(Bool.self, forKey: .folderOnly) ?? false
        caseSensitive = try container.decodeIfPresent(Bool.self, forKey: .caseSensitive) ?? false
        matchPath = try container.decodeIfPresent(Bool.self, forKey: .matchPath) ?? false
        useRegex = try container.decodeIfPresent(Bool.self, forKey: .useRegex) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // 文件扩展名：从 Set 编码为数组
        if let extensions = fileExtensions {
            try container.encode(Array(extensions), forKey: .fileExtensions)
        } else {
            try container.encodeNil(forKey: .fileExtensions)
        }
        
        try container.encodeIfPresent(minSize, forKey: .minSize)
        try container.encodeIfPresent(maxSize, forKey: .maxSize)
        try container.encodeIfPresent(minDate, forKey: .minDate)
        try container.encodeIfPresent(maxDate, forKey: .maxDate)
        try container.encode(dateType, forKey: .dateType)
        try container.encode(fileOnly, forKey: .fileOnly)
        try container.encode(folderOnly, forKey: .folderOnly)
        try container.encode(caseSensitive, forKey: .caseSensitive)
        try container.encode(matchPath, forKey: .matchPath)
        try container.encode(useRegex, forKey: .useRegex)
    }
    
    init() {
        // 默认初始化
    }
    
    func matches(_ item: FileItem) -> Bool {
        // 文件扩展名过滤
        if let extensions = fileExtensions, !extensions.isEmpty {
            guard let itemExtension = item.fileExtension,
                  extensions.contains(itemExtension) else {
                return false
            }
        }
        
        // 文件大小过滤
        if let min = minSize, item.size < min {
            return false
        }
        if let max = maxSize, item.size > max {
            return false
        }
        
        // 日期过滤
        let dateToCheck: Date?
        switch dateType {
        case .created:
            dateToCheck = item.createdDate
        case .modified:
            dateToCheck = item.modifiedDate
        case .accessed:
            dateToCheck = item.accessedDate
        }
        
        if let minDate = minDate, let date = dateToCheck, date < minDate {
            return false
        }
        if let maxDate = maxDate, let date = dateToCheck, date > maxDate {
            return false
        }
        
        return true
    }
}

