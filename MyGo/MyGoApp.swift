//
//  MyGoApp.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI
import Combine
import AppKit

@main
struct MyGoApp: App {
    @StateObject private var indexManager = FileIndexManager()
    @StateObject private var appState = AppState()
    @StateObject private var permissionChecker = PermissionChecker()
    
    init() {
        let startTime = Date()
        Logger.shared.log("=== 应用启动开始 ===", level: .debug)
        // 快捷键功能暂时移除，后续再开发
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("MyGoApp init 完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
    }
    
    var body: some Scene {
        let startTime = Date()
        Logger.shared.log("MyGoApp body 开始构建", level: .debug)
        
        let windowSize = PreferencesManager.shared.getWindowSize()
        Logger.shared.log("读取窗口大小: \(String(format: "%.0f", windowSize.width))x\(String(format: "%.0f", windowSize.height))", level: .debug)
        
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("MyGoApp body 构建完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
        
        return WindowGroup {
            RootView()
                .environmentObject(indexManager)
                .environmentObject(appState)
                .environmentObject(permissionChecker)
        }
        .windowStyle(.automatic)
        .defaultSize(
            width: permissionChecker.hasPermission ? windowSize.width : 600,
            height: permissionChecker.hasPermission ? windowSize.height : 700
        )
        .commands {
            CommandGroup(replacing: .newItem) {}

            // 将设置和重新索引都移到应用菜单中
            CommandGroup(replacing: .appSettings) {
                Button("设置...") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)

                Divider()

                Button("重新索引") {
                    if indexManager.isIndexing {
                        indexManager.stopIndexing()
                    } else {
                        indexManager.startIndexing()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(indexManager.isIndexing)
            }
        }
    }
}

/// 应用状态管理
class AppState: ObservableObject {
    @Published var showSettings = false
}

/// 权限检查器
class PermissionChecker: ObservableObject {
    @Published var hasPermission = false
    
    init() {
        let startTime = Date()
        Logger.shared.log("PermissionChecker init 开始", level: .debug)
        checkPermission()
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("PermissionChecker init 完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
    }
    
    func checkPermission() {
        let startTime = Date()
        Logger.shared.log("开始检查权限", level: .debug)
        
        // 检查文件访问权限
        let hasFileAccess = PermissionManager.shared.checkFileAccessPermission()
        Logger.shared.log("文件访问权限: \(hasFileAccess)", level: .debug)
        
        let hasFullDiskAccess = PermissionManager.shared.checkFullDiskAccessPermission()
        Logger.shared.log("完整磁盘访问权限: \(hasFullDiskAccess)", level: .debug)
        
        // 至少需要文件访问权限
        hasPermission = hasFileAccess || hasFullDiskAccess
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("权限检查完成，结果: \(hasPermission)，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
    }
}

/// 根视图 - 根据权限显示不同内容
struct RootView: View {
    @EnvironmentObject var permissionChecker: PermissionChecker
    
    var body: some View {
        Group {
            if permissionChecker.hasPermission {
                ContentView()
            } else {
                PermissionSetupView {
                    permissionChecker.checkPermission()
                }
            }
        }
        .onAppear {
            let appearStartTime = Date()
            Logger.shared.log("RootView onAppear 开始", level: .debug)
            permissionChecker.checkPermission()
            let elapsed = Date().timeIntervalSince(appearStartTime)
            Logger.shared.log("RootView onAppear 完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
        }
    }
}
