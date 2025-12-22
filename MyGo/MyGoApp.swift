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
        // 快捷键功能暂时移除，后续再开发
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(indexManager)
                .environmentObject(appState)
                .environmentObject(permissionChecker)
        }
        .windowStyle(.automatic)
        .defaultSize(
            width: permissionChecker.hasPermission ? PreferencesManager.shared.getWindowSize().width : 600,
            height: permissionChecker.hasPermission ? PreferencesManager.shared.getWindowSize().height : 700
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
        checkPermission()
    }
    
    func checkPermission() {
        // 检查文件访问权限
        let hasFileAccess = PermissionManager.shared.checkFileAccessPermission()
        let hasFullDiskAccess = PermissionManager.shared.checkFullDiskAccessPermission()
        
        // 至少需要文件访问权限
        hasPermission = hasFileAccess || hasFullDiskAccess
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
            permissionChecker.checkPermission()
        }
    }
}
