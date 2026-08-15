//
//  WindowActivationManager.swift
//  MyGo
//
//  Created by MY Liu on 08/13/26.
//

import AppKit
import SwiftUI

/// 窗口激活管理器：负责「显示 / 重新打开」主窗口
@MainActor
final class WindowActivationManager {
    static let shared = WindowActivationManager()
    private init() {}

    /// 主窗口的窗口标识符（与 WindowSizeTracker 中设置的一致，用于区分设置窗口等）
    static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("MyGoMainWindow")

    /// 用于重新打开已关闭主窗口的动作（在 RootView.onAppear 中注入）
    var openMainWindow: OpenWindowAction?

    /// 全局快捷键入口：应用在前台时新建窗口（系统标签偏好时合并为标签页）；
    /// 在后台时仅将应用切到前台，不新建窗口。
    func handleHotKeyPressed() {
        // 必须先读 isActive 再调用 activate（activate 会同步翻转它）
        if NSApp.isActive {
            openNewMainWindow()
        } else {
            // 激活应用并把所有窗口拉到当前 Space（macOS 14 协作式激活，无需 ignoringOtherApps）
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            if let window = findMainWindow() {
                front(window)
            } else {
                // 所有主窗口都已关闭，重新打开一个
                openNewMainWindow()
            }
        }
    }

    /// 新建一个主窗口并前置（供前台热键 / ⌘N / Dock 菜单调用）
    func openNewMainWindow() {
        NSApp.activate()
        let before = NSApp.windows
        openMainWindow?(id: "main")
        // 新窗口（或标签页）异步创建，下一轮 runloop 再确保其前置
        DispatchQueue.main.async {
            // 用身份 diff 找出真正新建的窗口；标签合并时没有新 NSWindow 对象，
            // 回退到 findMainWindow（SwiftUI 会自动选中新增的标签页）
            let newWindow = NSApp.windows.first { window in
                !before.contains(where: { $0 === window })
            } ?? self.findMainWindow()
            if let newWindow {
                self.front(newWindow)
            }
        }
    }

    /// 查找主窗口：按 identifier 匹配，排除设置窗口等
    private func findMainWindow() -> NSWindow? {
        NSApp.windows.first { $0.identifier == Self.mainWindowIdentifier && $0.contentView != nil }
    }

    /// 还原并前置窗口
    private func front(_ window: NSWindow) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }
}
