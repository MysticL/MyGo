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

    /// 显示主窗口：激活应用 → 还原/前置已有窗口 → 否则重新打开
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = findMainWindow() {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else {
            // 主窗口已关闭，用已捕获的 openWindow 动作重新打开
            openMainWindow?(id: "main")
            // 新窗口异步创建，下一轮 runloop 再确保其前置
            DispatchQueue.main.async {
                if let window = self.findMainWindow() {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    /// 查找主窗口：按 identifier 匹配，排除设置窗口等
    private func findMainWindow() -> NSWindow? {
        NSApp.windows.first { $0.identifier == Self.mainWindowIdentifier && $0.contentView != nil }
    }
}
