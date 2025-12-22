//
//  PermissionManager.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation
import AppKit

/// 权限管理器
class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {}
    
    /// 检查文件访问权限
    func checkFileAccessPermission() -> Bool {
        // 尝试访问用户主目录来测试权限
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let testPath = homeDirectory.appendingPathComponent("Documents")
        
        // 检查是否可以读取目录内容
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: testPath.path)
            // 检查是否可以访问文件资源值（这需要实际的文件访问权限）
            let testURL = testPath
            let resourceValues = try? testURL.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey])
            return resourceValues?.isReadable == true
        } catch {
            // 如果无法访问，可能是权限问题
            return false
        }
    }
    
    /// 检查完全磁盘访问权限（通过访问受保护的系统目录）
    func checkFullDiskAccessPermission() -> Bool {
        // 尝试访问受保护的系统目录来测试完全磁盘访问权限
        // 这些目录需要完全磁盘访问权限才能访问
        let protectedPaths = [
            "/Library/Application Support",
            "/System/Library"
        ]
        
        for path in protectedPaths {
            // 检查是否可以访问（不仅仅是可读，还要能打开）
            if !FileManager.default.isReadableFile(atPath: path) {
                return false
            }
        }
        
        return true
    }
    
    /// 检查是否有权限打开指定文件
    func checkCanOpenFile(at url: URL) -> Bool {
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        
        // 尝试获取文件资源值来测试权限
        // 这需要实际的文件访问权限，而不仅仅是路径存在
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .isDirectoryKey,
                .isReadableKey,
                .isWritableKey
            ])
            
            // 至少需要可读权限
            return resourceValues.isReadable == true
        } catch {
            // 如果无法获取资源值，可能是权限问题
            return false
        }
    }
    
    /// 检查是否有权限访问指定路径
    func checkAccessPermission(for path: String) -> Bool {
        return FileManager.default.isReadableFile(atPath: path)
    }
    
    /// 打开系统偏好设置中的隐私与安全性页面
    func openPrivacySettings() {
        // 打开系统设置的隐私与安全性页面
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// 打开系统偏好设置中的完全磁盘访问权限页面
    func openFullDiskAccessSettings() {
        // 打开系统设置的完全磁盘访问权限页面
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

