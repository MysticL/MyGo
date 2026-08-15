//
//  WindowSizeTracker.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI
import AppKit

struct WindowSizeTracker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = false

        DispatchQueue.main.async {
            // 给主窗口打上标识，供 WindowActivationManager 区分主窗口与设置窗口等
            view.window?.identifier = WindowActivationManager.mainWindowIdentifier
            trackWindowSize()
        }

        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    private func trackWindowSize() {
        for window in NSApplication.shared.windows {
            if window.windowController != nil,
               window.contentView != nil {
                // 保存窗口大小
                let frame = window.frame
                PreferencesManager.shared.saveWindowSize(
                    width: frame.width,
                    height: frame.height
                )
            }
        }
    }
}

