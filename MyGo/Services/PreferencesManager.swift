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
    private let columnWidthsKey = "com.mygo.columnWidths"
    private let columnWidthsVersionKey = "com.mygo.columnWidthsVersion"
    private let currentColumnWidthsVersion = 5  // 版本5：强制重置列宽，确保名称列400px正确应用
    private let pathWhitelistsKey = "com.mygo.pathWhitelists"
    private let pathBlacklistsKey = "com.mygo.pathBlacklists"
    private let logEnabledKey = "com.mygo.logEnabled"
    private let logLevelKey = "com.mygo.logLevel"

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
    
    /// 保存列宽
    func saveColumnWidths(_ widths: [String: CGFloat]) {
        let dict = widths.mapValues { $0 }
        UserDefaults.standard.set(dict, forKey: columnWidthsKey)
        Logger.shared.log("列宽已保存: \(widths.map { "\($0.key)=\(String(format: "%.1f", $0.value))" }.joined(separator: ", "))", level: .info)
    }
    
    /// 获取列宽
    func getColumnWidths() -> [String: CGFloat] {
        let savedVersion = UserDefaults.standard.integer(forKey: columnWidthsVersionKey)

        // 如果版本不匹配，重置列宽设置
        if savedVersion != currentColumnWidthsVersion {
            Logger.shared.log("列宽版本不匹配 (保存版本: \(savedVersion), 当前版本: \(currentColumnWidthsVersion))，重置列宽设置", level: .info)
            resetColumnWidths()
            UserDefaults.standard.set(currentColumnWidthsVersion, forKey: columnWidthsVersionKey)
            return [:]  // 返回空字典，让调用方使用默认值
        }

        guard let dict = UserDefaults.standard.dictionary(forKey: columnWidthsKey) as? [String: Double] else {
            Logger.shared.log("列宽读取: 未找到保存的列宽设置，返回空字典", level: .info)
            return [:]
        }
        let widths = dict.mapValues { CGFloat($0) }
        Logger.shared.log("列宽已读取: \(widths.map { "\($0.key)=\(String(format: "%.1f", $0.value))" }.joined(separator: ", "))", level: .info)
        return widths
    }

    /// 重置列宽设置（恢复默认值）
    func resetColumnWidths() {
        UserDefaults.standard.removeObject(forKey: columnWidthsKey)
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

