//
//  FileOperationService.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation
import AppKit
import ApplicationServices

/// 文件操作服务
class FileOperationService {
    static let shared = FileOperationService()
    
    private init() {}
    
    /// 打开文件
    func openFile(_ item: FileItem) {
        Logger.shared.log("开始打开文件: \(item.name) (路径: \(item.path))", level: .info)
        
        // 先检查文件是否存在
        guard FileManager.default.fileExists(atPath: item.path) else {
            Logger.shared.log("文件不存在: \(item.path)", level: .error)
            showErrorAlert(title: "文件不存在", message: "无法找到文件 \"\(item.name)\"。")
            return
        }
        
        Logger.shared.log("文件存在，开始尝试打开", level: .info)
        
        // 方法1: 使用 Launch Services API (LSOpenCFURLRef) - 最可靠的方法
        Logger.shared.log("尝试方法1: 使用 Launch Services API (LSOpenCFURLRef)", level: .debug)
        let urlCF = item.url as CFURL
        let result = LSOpenCFURLRef(urlCF, nil)
        if result == noErr {
            Logger.shared.log("方法1成功: Launch Services API", level: .info)
            return
        }
        Logger.shared.log("方法1失败: Launch Services API 返回错误代码: \(result)", level: .warning)
        
        // 方法2: 尝试使用 NSWorkspace.open (标准方法)
        Logger.shared.log("尝试方法2: 使用 NSWorkspace.shared.open", level: .debug)
        let success = NSWorkspace.shared.open(item.url)
        
        if success {
            Logger.shared.log("方法2成功: NSWorkspace.shared.open", level: .info)
            return
        }
        Logger.shared.log("方法2失败: NSWorkspace.shared.open 返回 false", level: .warning)
        
        // 方法3: 使用 activateFileViewerSelectingURLs（在 Finder 中显示并选中文件）
        // 这个方法会打开 Finder 并选中文件，用户可以在 Finder 中双击打开
        if !item.isDirectory {
            Logger.shared.log("尝试方法3: 使用 activateFileViewerSelectingURLs", level: .debug)
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
            Logger.shared.log("方法3已调用: activateFileViewerSelectingURLs（已在 Finder 中选中文件）", level: .info)
            // 这个方法会打开 Finder，用户可以在 Finder 中双击打开文件
            return
        }
        
        // 方法4: 对于目录，尝试在 Finder 中显示
        if item.isDirectory {
            Logger.shared.log("尝试方法4: 在 Finder 中显示目录", level: .debug)
            let selectSuccess = NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            if selectSuccess {
                Logger.shared.log("方法4成功: 在 Finder 中显示目录", level: .info)
                return
            }
            Logger.shared.log("方法4失败: 在 Finder 中显示目录", level: .warning)
        }
        
        // 方法5: 尝试使用命令行 open 命令（备用方法）
        // 注意：即使有完全磁盘访问权限，命令行 open 也可能失败（错误 -54）
        Logger.shared.log("尝试方法5: 使用命令行 open 命令", level: .debug)
        _ = openFileWithCommand(item.path) // 异步执行，不等待结果
        
        // 如果所有方法都失败，显示错误提示
        Logger.shared.log("所有打开文件的方法都失败: \(item.name)", level: .error)
        showPermissionAlert(for: item)
    }
    
    /// 使用命令行 open 命令打开文件（最可靠的方法）
    /// 这个方法会使用系统的默认应用打开文件，通常能绕过权限限制
    private func openFileWithCommand(_ path: String) -> Bool {
        Logger.shared.log("执行命令行: /usr/bin/open \"\(path)\"", level: .debug)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        // 路径已经作为参数传递，不需要额外引号（Process 会自动处理）
        process.arguments = [path]
        
        // 创建管道来捕获错误输出
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = nil
        
        // 设置环境变量（如果需要）
        let environment = ProcessInfo.processInfo.environment
        process.environment = environment
        
        do {
            try process.run()
            Logger.shared.log("命令行进程已启动，进程ID: \(process.processIdentifier)", level: .debug)
            
            // 异步等待进程完成并检查结果
            DispatchQueue.global().async {
                process.waitUntilExit()
                let exitStatus = process.terminationStatus
                
                // 读取错误输出
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                var errorString = ""
                if let errorStr = String(data: errorData, encoding: .utf8), !errorStr.isEmpty {
                    errorString = errorStr.trimmingCharacters(in: .whitespacesAndNewlines)
                    Logger.shared.log("命令行错误输出: \(errorString)", level: .error)
                }
                
                if exitStatus == 0 {
                    Logger.shared.log("命令行 open 命令执行成功，退出状态: 0", level: .info)
                } else {
                    Logger.shared.log("命令行 open 命令失败，退出状态: \(exitStatus)", level: .error)
                    // 错误 -54 通常表示权限问题，即使有完全磁盘访问权限也可能出现
                    if exitStatus == 1 && errorString.contains("-54") {
                        Logger.shared.log("检测到错误 -54: 这通常表示权限问题，即使已授予完全磁盘访问权限", level: .error)
                    }
                }
            }
            
            // 不等待进程完成，open 命令会立即返回
            // 如果进程能启动，就认为成功
            return true
        } catch {
            Logger.shared.log("无法使用命令行打开文件: \(error.localizedDescription)", level: .error)
            Logger.shared.log("错误详情: \(error)", level: .error)
            return false
        }
    }
    
    /// 显示权限提示
    private func showPermissionAlert(for item: FileItem) {
        Logger.shared.log("显示权限提示对话框: \(item.name)", level: .warning)
        
        let alert = NSAlert()
        alert.messageText = "无法打开文件"
        let logPath = Logger.shared.getLogFilePath()
        alert.informativeText = "应用没有权限打开 \"\(item.name)\"。\n\n请前往系统设置 > 隐私与安全性 > 完全磁盘访问权限，并确保 MyGo 已启用。\n\n如果已经启用权限，请尝试重启应用。\n\n日志文件位置: \(logPath)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "打开日志文件")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Logger.shared.log("用户选择打开系统设置", level: .info)
            PermissionManager.shared.openFullDiskAccessSettings()
        } else if response == .alertSecondButtonReturn {
            Logger.shared.log("用户选择打开日志文件", level: .info)
            NSWorkspace.shared.open(Logger.shared.getLogFileURL())
        }
    }
    
    /// 显示错误提示
    private func showErrorAlert(title: String, message: String) {
        Logger.shared.log("显示错误提示: \(title) - \(message)", level: .error)
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
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

