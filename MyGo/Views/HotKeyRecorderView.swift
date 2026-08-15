//
//  HotKeyRecorderView.swift
//  MyGo
//
//  Created by MY Liu on 08/13/26.
//

import SwiftUI
import AppKit
import Carbon

/// 快捷键录制控件：点击后进入录制状态，捕获下一个按键组合
struct HotKeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: UInt32          // Carbon 键码
    @Binding var modifiers: UInt32        // Carbon 修饰符标志
    @Binding var isRecording: Bool
    /// 提交回调：返回 false 表示注册失败（快捷键被占用）
    var onCommit: (UInt32, UInt32) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onStartRecording = { [weak coordinator = context.coordinator] in
            coordinator?.startRecording()
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        context.coordinator.parent = self
        nsView.isRecording = isRecording
        nsView.comboText = (keyCode == 0 && modifiers == 0)
            ? "无"
            : HotKeyManager.stringFromModifiers(modifiers) + HotKeyManager.stringFromKeyCode(keyCode)
    }

    final class Coordinator: NSObject {
        var parent: HotKeyRecorderView
        private var monitor: Any?

        /// 仅修饰键的键码，按下时忽略（等待真正的组合键）
        private static let modifierOnlyKeyCodes: Set<UInt32> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64]

        init(_ parent: HotKeyRecorderView) {
            self.parent = parent
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        @objc func startRecording() {
            guard monitor == nil else { return }
            parent.isRecording = true
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyDown(event)
            }
        }

        private func stopRecording() {
            parent.isRecording = false
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        /// 处理按键事件，返回 nil 表示消费该事件
        private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
            let keyCode = UInt32(event.keyCode)
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Escape 取消
            if keyCode == 53 {
                stopRecording()
                return nil
            }

            // Delete / Backspace 清除
            if keyCode == 51 || keyCode == 117 {
                parent.keyCode = 0
                parent.modifiers = 0
                _ = parent.onCommit(0, 0)
                stopRecording()
                return nil
            }

            // 纯修饰键按下，忽略
            if Self.modifierOnlyKeyCodes.contains(keyCode) {
                return nil
            }

            // 需至少一个修饰键
            let carbon = Self.carbonModifiers(from: flags)
            guard carbon != 0 else {
                return nil
            }

            let ok = parent.onCommit(keyCode, carbon)
            if ok {
                parent.keyCode = keyCode
                parent.modifiers = carbon
            }
            stopRecording()
            return nil
        }

        /// NSModifierFlags → Carbon 修饰符
        static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var modifiers: UInt32 = 0
            if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
            if flags.contains(.control) { modifiers |= UInt32(controlKey) }
            if flags.contains(.option) { modifiers |= UInt32(optionKey) }
            if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
            return modifiers
        }
    }
}

/// 自定义录制控件视图：居中显示当前组合键，点击进入录制
final class RecorderNSView: NSView {
    private let label = NSTextField(labelWithString: "")
    var onStartRecording: (() -> Void)?

    var isRecording: Bool = false {
        didSet { updateAppearance() }
    }
    var comboText: String = "无" {
        didSet { updateAppearance() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
        ])

        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        updateAppearance()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 150, height: 24)
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onStartRecording?()
    }

    private func updateAppearance() {
        label.stringValue = isRecording ? "请按下新快捷键…" : comboText
        layer?.borderColor = isRecording
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.cgColor
    }
}
