//
//  WindowTabTitleBridge.swift
//  MyGo
//
//  Created by MY Liu on 08/15/26.
//

import SwiftUI
import AppKit

/// 把搜索词写入当前窗口标签页的标题。
///
/// 与窗口标题栏分离：标题栏由窗口默认标题固定为应用名「MyGo」，
/// 每个标签页在标签条上各自显示自己的搜索词。
struct WindowTabTitleBridge: NSViewRepresentable {
    var tabTitle: String

    func makeNSView(context: Context) -> NSView {
        TabTitleBridgeView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? TabTitleBridgeView)?.apply(tabTitle)
    }
}

/// 负责把标题写入 `window.tab.title` 的 NSView
final class TabTitleBridgeView: NSView {
    private var lastTitle: String?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 窗口变为可用时补一次，覆盖「首个窗口稍后才形成标签组」或视图延迟挂载的情况
        if let lastTitle, let window {
            window.tab.title = lastTitle
        }
    }

    func apply(_ title: String) {
        lastTitle = title
        guard let window else { return }
        window.tab.title = title
    }
}
