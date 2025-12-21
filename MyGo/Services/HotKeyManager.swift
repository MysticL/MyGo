//
//  HotKeyManager.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation
import AppKit
import Carbon

// 全局事件处理器函数
private func hotKeyEventHandler(nextHandler: EventHandlerCallRef?, theEvent: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    
    var hotKeyID = EventHotKeyID()
    let err = GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    
    if err == noErr && hotKeyID.id == manager.hotKeyID.id {
        DispatchQueue.main.async {
            manager.onHotKeyPressed?()
        }
        return noErr
    }
    
    return OSStatus(eventNotHandledErr)
}

/// 快捷键管理器
class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    fileprivate var hotKeyID: EventHotKeyID = {
        var id = EventHotKeyID()
        id.signature = FourCharCode(0x4D79476F) // "MyGo"
        id.id = 1
        return id
    }()
    private var eventHandler: EventHandlerRef?
    
    var onHotKeyPressed: (() -> Void)?
    
    private init() {
        setupEventHandler()
    }
    
    deinit {
        unregisterHotKey()
    }
    
    /// 设置事件处理器
    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let userData = Unmanaged.passUnretained(self).toOpaque()
        // 直接使用函数指针
        let eventHandlerUPP = NewEventHandlerUPP(hotKeyEventHandler)
        InstallEventHandler(GetApplicationEventTarget(), eventHandlerUPP, 1, &eventSpec, userData, &eventHandler)
    }
    
    /// 注册快捷键
    func registerHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        unregisterHotKey()
        
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            self.hotKeyRef = hotKeyRef
            return true
        }
        
        return false
    }
    
    /// 取消注册快捷键
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
    
    /// 从字符串转换为键码
    static func keyCodeFromString(_ string: String) -> UInt32? {
        let keyMap: [String: UInt32] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
            "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35,
            "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
            "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
            "f9": 101, "f10": 109, "f11": 103, "f12": 111,
            "space": 49, "return": 36, "tab": 48, "escape": 53,
            "up": 126, "down": 125, "left": 123, "right": 124
        ]
        
        return keyMap[string.lowercased()]
    }
    
    /// 从修饰符字符串转换为修饰符标志
    static func modifiersFromString(_ string: String) -> UInt32 {
        var modifiers: UInt32 = 0
        let lowercased = string.lowercased()
        
        if lowercased.contains("command") || lowercased.contains("cmd") {
            modifiers |= UInt32(cmdKey)
        }
        if lowercased.contains("control") || lowercased.contains("ctrl") {
            modifiers |= UInt32(controlKey)
        }
        if lowercased.contains("option") || lowercased.contains("alt") {
            modifiers |= UInt32(optionKey)
        }
        if lowercased.contains("shift") {
            modifiers |= UInt32(shiftKey)
        }
        
        return modifiers
    }
    
    /// 从键码转换为字符串
    static func stringFromKeyCode(_ keyCode: UInt32) -> String {
        let keyMap: [UInt32: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
            34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
            12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
            16: "Y", 6: "Z",
            29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
            49: "Space", 36: "Return", 48: "Tab", 53: "Escape",
            126: "↑", 125: "↓", 123: "←", 124: "→"
        ]
        
        return keyMap[keyCode] ?? "?"
    }
    
    /// 从修饰符标志转换为字符串
    static func stringFromModifiers(_ modifiers: UInt32) -> String {
        var parts: [String] = []
        
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }
        
        return parts.joined()
    }
}

