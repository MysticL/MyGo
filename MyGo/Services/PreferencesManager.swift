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
    static let shared = PreferencesManager()

    private let windowWidthKey = "com.mygo.windowWidth"
    private let windowHeightKey = "com.mygo.windowHeight"
    private let columnWidthsKey = "com.mygo.columnWidths"
    private let columnWidthsVersionKey = "com.mygo.columnWidthsVersion"
    private let currentColumnWidthsVersion = 2  // 版本2：扩展名和大小列默认宽度减半

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
    }
    
    /// 获取列宽
    func getColumnWidths() -> [String: CGFloat] {
        let savedVersion = UserDefaults.standard.integer(forKey: columnWidthsVersionKey)

        // 如果版本不匹配，重置列宽设置
        if savedVersion != currentColumnWidthsVersion {
            resetColumnWidths()
            UserDefaults.standard.set(currentColumnWidthsVersion, forKey: columnWidthsVersionKey)
            return [:]  // 返回空字典，让调用方使用默认值
        }

        guard let dict = UserDefaults.standard.dictionary(forKey: columnWidthsKey) as? [String: Double] else {
            return [:]
        }
        return dict.mapValues { CGFloat($0) }
    }

    /// 重置列宽设置（恢复默认值）
    func resetColumnWidths() {
        UserDefaults.standard.removeObject(forKey: columnWidthsKey)
    }
}

