//
//  PreferencesManager.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation
import SwiftUI

/// 偏好设置管理器
class PreferencesManager {
    nonisolated static let shared = PreferencesManager()

    private let windowWidthKey = "com.mygo.windowWidth"
    private let windowHeightKey = "com.mygo.windowHeight"
    private let pathWhitelistsKey = "com.mygo.pathWhitelists"
    private let pathBlacklistsKey = "com.mygo.pathBlacklists"
    private let selectedWhitelistIdKey = "com.mygo.selectedWhitelistId"
    private let selectedBlacklistIdKey = "com.mygo.selectedBlacklistId"
    private let searchFilterKey = "com.mygo.searchFilter"
    private let logEnabledKey = "com.mygo.logEnabled"
    private let logLevelKey = "com.mygo.logLevel"
    private let hotKeyKeyCodeKey = "com.mygo.hotKeyKeyCode"
    private let hotKeyModifiersKey = "com.mygo.hotKeyModifiers"

    /// 默认快捷键：⌘⌃F（键码 3；Carbon 修饰符 cmdKey|controlKey = 0x1100）
    private let defaultHotKeyKeyCode: Int = 3
    private let defaultHotKeyModifiers: Int = 0x1100

    private init() {}
    
    /// 保存窗口大小
    func saveWindowSize(width: CGFloat, height: CGFloat) {
        UserDefaults.standard.set(width, forKey: windowWidthKey)
        UserDefaults.standard.set(height, forKey: windowHeightKey)
    }
    
    /// 获取窗口大小
    func getWindowSize() -> (width: CGFloat, height: CGFloat) {
        let width = UserDefaults.standard.double(forKey: windowWidthKey)
        let height = UserDefaults.standard.double(forKey: windowHeightKey)
        
        // 如果未保存过，返回默认值
        if width == 0 || height == 0 {
            return (1000, 700)
        }
        
        return (width, height)
    }
    
    // MARK: - 路径关键词列表管理
    
    /// 保存路径白名单列表
    func savePathWhitelists(_ lists: [PathKeywordList]) {
        if let encoded = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(encoded, forKey: pathWhitelistsKey)
        }
    }
    
    /// 获取路径白名单列表
    func getPathWhitelists() -> [PathKeywordList] {
        guard let data = UserDefaults.standard.data(forKey: pathWhitelistsKey),
              let lists = try? JSONDecoder().decode([PathKeywordList].self, from: data) else {
            return []
        }
        return lists
    }
    
    /// 保存路径黑名单列表
    func savePathBlacklists(_ lists: [PathKeywordList]) {
        if let encoded = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(encoded, forKey: pathBlacklistsKey)
        }
    }
    
    /// 获取路径黑名单列表
    func getPathBlacklists() -> [PathKeywordList] {
        guard let data = UserDefaults.standard.data(forKey: pathBlacklistsKey),
              let lists = try? JSONDecoder().decode([PathKeywordList].self, from: data) else {
            return []
        }
        return lists
    }
    
    // MARK: - 选中的黑白名单管理
    
    /// 保存选中的白名单ID
    func saveSelectedWhitelistId(_ id: UUID?) {
        if let id = id {
            UserDefaults.standard.set(id.uuidString, forKey: selectedWhitelistIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedWhitelistIdKey)
        }
    }
    
    /// 获取选中的白名单ID
    func getSelectedWhitelistId() -> UUID? {
        guard let idString = UserDefaults.standard.string(forKey: selectedWhitelistIdKey),
              let id = UUID(uuidString: idString) else {
            return nil
        }
        return id
    }
    
    /// 保存选中的黑名单ID
    func saveSelectedBlacklistId(_ id: UUID?) {
        if let id = id {
            UserDefaults.standard.set(id.uuidString, forKey: selectedBlacklistIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedBlacklistIdKey)
        }
    }
    
    /// 获取选中的黑名单ID
    func getSelectedBlacklistId() -> UUID? {
        guard let idString = UserDefaults.standard.string(forKey: selectedBlacklistIdKey),
              let id = UUID(uuidString: idString) else {
            return nil
        }
        return id
    }
    
    // MARK: - 搜索过滤器管理
    
    /// 保存搜索过滤器
    func saveSearchFilter(_ filter: SearchFilter) {
        if let encoded = try? JSONEncoder().encode(filter) {
            UserDefaults.standard.set(encoded, forKey: searchFilterKey)
        }
    }
    
    /// 获取搜索过滤器
    func getSearchFilter() -> SearchFilter? {
        guard let data = UserDefaults.standard.data(forKey: searchFilterKey),
              let filter = try? JSONDecoder().decode(SearchFilter.self, from: data) else {
            return nil
        }
        return filter
    }

    // MARK: - 全局快捷键管理

    /// 保存全局快捷键
    func saveHotKey(keyCode: UInt32, modifiers: UInt32) {
        UserDefaults.standard.set(Int(keyCode), forKey: hotKeyKeyCodeKey)
        UserDefaults.standard.set(Int(modifiers), forKey: hotKeyModifiersKey)
    }

    /// 获取全局快捷键（默认 ⌘⌃F；显式清除后返回 (0, 0) 表示未设置）
    func getHotKey() -> (keyCode: UInt32, modifiers: UInt32) {
        guard let keyCode = UserDefaults.standard.object(forKey: hotKeyKeyCodeKey) as? Int,
              let modifiers = UserDefaults.standard.object(forKey: hotKeyModifiersKey) as? Int else {
            return (UInt32(defaultHotKeyKeyCode), UInt32(defaultHotKeyModifiers))
        }
        return (UInt32(keyCode), UInt32(modifiers))
    }

    // MARK: - 日志设置管理
    
    /// 保存日志开关状态
    func saveLogEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: logEnabledKey)
    }
    
    /// 获取日志开关状态（默认关闭，非 actor 隔离）
    nonisolated func getLogEnabled() -> Bool {
        // 如果从未设置过，返回 false（默认关闭）
        if UserDefaults.standard.object(forKey: logEnabledKey) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: logEnabledKey)
    }
    
    /// 保存日志等级
    func saveLogLevel(_ level: LogLevel) {
        UserDefaults.standard.set(level.rawValue, forKey: logLevelKey)
    }
    
    /// 获取日志等级（默认 debug，非 actor 隔离）
    nonisolated func getLogLevel() -> LogLevel {
        guard let levelString = UserDefaults.standard.string(forKey: logLevelKey),
              let level = LogLevel(rawValue: levelString) else {
            return .debug  // 默认等级为最详细的DEBUG
        }
        return level
    }
}

