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
    
    init() {
        // 快捷键功能暂时移除，后续再开发
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(indexManager)
                .environmentObject(appState)
        }
        .windowStyle(.automatic)
        .defaultSize(
            width: PreferencesManager.shared.getWindowSize().width,
            height: PreferencesManager.shared.getWindowSize().height
        )
        .commands {
            CommandGroup(replacing: .newItem) {}
            
            // MyGo 菜单
            CommandMenu("MyGo") {
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
                
                Divider()
                
                Button("关于 MyGo") {
                    // 可以添加关于对话框
                }
            }
        }
    }
}

/// 应用状态管理
class AppState: ObservableObject {
    @Published var showSettings = false
}
