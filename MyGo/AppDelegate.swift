//
//  AppDelegate.swift
//  MyGo
//
//  Created by MY Liu on 08/15/26.
//

import AppKit
import SwiftUI

/// 应用代理：提供 Dock 图标右键菜单
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(title: "新建窗口", action: #selector(openNewWindow), keyEquivalent: "")
        // 必须显式设置 target，否则 Dock 菜单的 action 无法沿 responder 链送达
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func openNewWindow() {
        WindowActivationManager.shared.openNewMainWindow()
    }
}
