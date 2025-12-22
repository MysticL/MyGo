//
//  TestFileOpen.swift
//  测试文件打开功能
//

import Foundation
import AppKit
import ApplicationServices

let testFilePath = "/Users/b-60060526/Documents/02 Project/00 其他项目/04 X3409&3412初期评估文件/02 Simulation/0_45 Thick mount Simulation Results.pdf"

print("=== 文件打开测试 ===")
print("测试文件路径: \(testFilePath)")
print()

// 检查文件是否存在
let fileManager = FileManager.default
if !fileManager.fileExists(atPath: testFilePath) {
    print("❌ 错误: 文件不存在")
    exit(1)
}
print("✓ 文件存在")
print()

// 创建 URL
let fileURL = URL(fileURLWithPath: testFilePath)
print("文件 URL: \(fileURL)")
print("文件 URL 绝对路径: \(fileURL.path)")
print()

// 方法1: Launch Services API (LSOpenCFURLRef)
print("--- 方法1: Launch Services API (LSOpenCFURLRef) ---")
let urlCF = fileURL as CFURL
let result1 = LSOpenCFURLRef(urlCF, nil)
if result1 == noErr {
    print("✓ 成功: Launch Services API 返回 noErr")
} else {
    print("❌ 失败: Launch Services API 返回错误代码: \(result1)")
    if let errorString = SecCopyErrorMessageString(result1, nil) {
        print("   错误描述: \(errorString)")
    }
}
print()

// 方法2: NSWorkspace.shared.open
print("--- 方法2: NSWorkspace.shared.open ---")
let success2 = NSWorkspace.shared.open(fileURL)
if success2 {
    print("✓ 成功: NSWorkspace.shared.open 返回 true")
} else {
    print("❌ 失败: NSWorkspace.shared.open 返回 false")
}
print()

// 方法3: NSWorkspace.shared.openApplication (使用默认应用)
print("--- 方法3: NSWorkspace.shared.openApplication (使用默认应用) ---")
let config = NSWorkspace.OpenConfiguration()
config.activates = true
NSWorkspace.shared.openApplication(at: fileURL, configuration: config) { app, error in
    if let error = error {
        print("❌ 失败: openApplication 错误: \(error.localizedDescription)")
    } else if let app = app {
        print("✓ 成功: openApplication 打开了应用: \(app.localizedName ?? "未知")")
    } else {
        print("⚠️  警告: openApplication 完成，但没有返回应用信息")
    }
}
// 等待一下让异步操作完成
Thread.sleep(forTimeInterval: 1.0)
print()

// 方法4: 命令行 open 命令
print("--- 方法4: 命令行 open 命令 ---")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
process.arguments = [testFilePath]

let errorPipe = Pipe()
process.standardError = errorPipe
process.standardOutput = nil

do {
    try process.run()
    print("✓ 进程已启动，进程ID: \(process.processIdentifier)")
    
    process.waitUntilExit()
    let exitStatus = process.terminationStatus
    
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
        print("   错误输出: \(errorString.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    
    if exitStatus == 0 {
        print("✓ 成功: 命令行 open 命令退出状态: 0")
    } else {
        print("❌ 失败: 命令行 open 命令退出状态: \(exitStatus)")
    }
} catch {
    print("❌ 失败: 无法启动进程: \(error.localizedDescription)")
}
print()

// 方法5: activateFileViewerSelectingURLs
print("--- 方法5: activateFileViewerSelectingURLs (在 Finder 中选中) ---")
NSWorkspace.shared.activateFileViewerSelecting([fileURL])
print("✓ 已调用: activateFileViewerSelectingURLs（在 Finder 中选中文件）")
print()

// 方法6: 检查文件资源值
print("--- 方法6: 检查文件资源值 ---")
do {
    let resourceValues = try fileURL.resourceValues(forKeys: [
        .isReadableKey,
        .isWritableKey,
        .isExecutableKey,
        .fileSizeKey,
        .contentTypeKey
    ])
    
    print("   可读: \(resourceValues.isReadable ?? false)")
    print("   可写: \(resourceValues.isWritable ?? false)")
    print("   可执行: \(resourceValues.isExecutable ?? false)")
    if let size = resourceValues.fileSize {
        print("   文件大小: \(size) 字节")
    }
    if let contentType = resourceValues.contentType {
        print("   内容类型: \(contentType)")
    }
} catch {
    print("❌ 失败: 无法获取资源值: \(error.localizedDescription)")
}
print()

// 方法7: 检查默认应用
print("--- 方法7: 检查默认应用 ---")
if let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: fileURL) {
    print("✓ 默认应用: \(defaultAppURL.lastPathComponent)")
    print("   应用路径: \(defaultAppURL.path)")
} else {
    print("❌ 无法确定默认应用")
}
print()

print("=== 测试完成 ===")

