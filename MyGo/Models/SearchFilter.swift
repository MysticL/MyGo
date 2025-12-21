//
//  SearchFilter.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation

/// 搜索过滤器
struct SearchFilter: Equatable {
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
    
    enum DateFilterType: Equatable {
        case created
        case modified
        case accessed
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

