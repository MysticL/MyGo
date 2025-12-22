//
//  FileItem.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation

/// 文件项模型
struct FileItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    let createdDate: Date?
    let modifiedDate: Date?
    let accessedDate: Date?
    let fileExtension: String?
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.path = url.path
        
        let resourceValues = try? url.resourceValues(forKeys: [
            .fileSizeKey,
            .isDirectoryKey,
            .creationDateKey,
            .contentModificationDateKey,
            .contentAccessDateKey
        ])
        
        self.size = Int64(resourceValues?.fileSize ?? 0)
        self.isDirectory = resourceValues?.isDirectory ?? false
        self.createdDate = resourceValues?.creationDate
        self.modifiedDate = resourceValues?.contentModificationDate
        self.accessedDate = resourceValues?.contentAccessDate
        self.fileExtension = url.pathExtension.isEmpty ? nil : url.pathExtension.lowercased()
    }
    
    /// 格式化文件大小
    var formattedSize: String {
        if isDirectory {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// 格式化修改日期
    var formattedModifiedDate: String {
        guard let date = modifiedDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// 用于排序的修改日期（时间戳）
    var sortableModifiedDate: TimeInterval {
        modifiedDate?.timeIntervalSince1970 ?? 0
    }
    
    /// 获取文件所在目录路径（不包含文件名）
    var directoryPath: String {
        return url.deletingLastPathComponent().path
    }
    
    /// 获取缩短的目录路径（去掉前两级目录）
    var shortenedDirectoryPath: String {
        let fullPath = directoryPath
        
        // 处理以 / 开头的绝对路径
        if fullPath.hasPrefix("/") {
            let pathWithoutLeadingSlash = String(fullPath.dropFirst())
            let components = pathWithoutLeadingSlash.split(separator: "/", omittingEmptySubsequences: true)
            
            // 如果路径组件少于2个，返回原路径
            guard components.count > 2 else {
                return fullPath
            }
            
            // 去掉前两级目录（索引0和1）
            // 例如：Users/b-60060526/Documents/... -> Documents/...
            let remainingComponents = Array(components.dropFirst(2))
            
            // 重新组合路径，确保以 / 开头
            if remainingComponents.isEmpty {
                return "/"
            }
            return "/" + remainingComponents.joined(separator: "/")
        } else {
            // 相对路径，直接处理
            let components = fullPath.split(separator: "/", omittingEmptySubsequences: true)
            guard components.count > 2 else {
                return fullPath
            }
            let remainingComponents = Array(components.dropFirst(2))
            return remainingComponents.joined(separator: "/")
        }
    }
    
    /// 用于排序的扩展名（空字符串用于无扩展名的文件）
    var sortableExtension: String {
        return fileExtension ?? ""
    }
}

