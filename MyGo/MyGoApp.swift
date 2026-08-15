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
    @StateObject private var permissionChecker = PermissionChecker()
    
    init() {
        let startTime = Date()
        Logger.shared.log("=== 应用启动开始 ===", level: .debug)
        
        // 设置全局快捷键回调
        HotKeyManager.shared.onHotKeyPressed = {
            WindowActivationManager.shared.showMainWindow()
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.log("MyGoApp init 完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
    }
    
    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environmentObject(indexManager)
                .environmentObject(permissionChecker)
        }
        .windowStyle(.automatic)
        .defaultSize(
            width: permissionChecker.hasPermission ? PreferencesManager.shared.getWindowSize().width : 600,
            height: permissionChecker.hasPermission ? PreferencesManager.shared.getWindowSize().height : 700
        )
        .commands {
            CommandGroup(replacing: .newItem) {}

            // 「设置…」由原生 Settings scene 自动提供，这里只保留「重新索引」
            CommandGroup(after: .appSettings) {
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

        Settings {
            SettingsView(indexManager: indexManager)
        }
    }
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
    @Environment(\.openWindow) private var openWindow

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
            // 注入重新打开主窗口的动作，供全局快捷键在窗口被关闭后重开使用
            WindowActivationManager.shared.openMainWindow = openWindow
            permissionChecker.checkPermission()
            let elapsed = Date().timeIntervalSince(appearStartTime)
            Logger.shared.log("RootView onAppear 完成，耗时: \(String(format: "%.3f", elapsed))秒", level: .debug)
        }
    }
}
