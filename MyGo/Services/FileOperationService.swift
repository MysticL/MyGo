//
//  FileOperationService.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation
import AppKit

/// 文件操作服务
class FileOperationService {
    static let shared = FileOperationService()
    
    private init() {}
    
    /// 打开文件
    func openFile(_ item: FileItem) {
        if item.isDirectory {
            NSWorkspace.shared.open(item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }
    
    /// 在 Finder 中显示
    func revealInFinder(_ item: FileItem) {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }
    
    /// 复制文件路径
    func copyPath(_ item: FileItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.path, forType: .string)
    }
    
    /// 复制文件
    func copyFile(_ item: FileItem, to destination: URL) throws {
        try FileManager.default.copyItem(at: item.url, to: destination)
    }
    
    /// 移动文件
    func moveFile(_ item: FileItem, to destination: URL) throws {
        try FileManager.default.moveItem(at: item.url, to: destination)
    }
    
    /// 删除文件
    func deleteFile(_ item: FileItem) throws {
        try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
    }
    
    /// 显示移动对话框
    func showMoveDialog(for item: FileItem, completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "移动"
        panel.message = "选择目标文件夹"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                completion(url)
            } else {
                completion(nil)
            }
        }
    }
    
    /// 显示复制对话框
    func showCopyDialog(for item: FileItem, completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "复制"
        panel.message = "选择目标文件夹"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                completion(url)
            } else {
                completion(nil)
            }
        }
    }
}

