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

