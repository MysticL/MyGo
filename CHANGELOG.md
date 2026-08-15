# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).



## [1.7.1] - 2026-08-15
### Changed
- 窗口标题栏保持 MyGo，标签页标题单独显示搜索词
## [1.7.0] - 2026-08-15
### Changed
- 全局快捷键前台新建窗口、后台仅置前；Dock 菜单与 ⌘N 新建窗口；窗口标题随搜索词实时更新
## [1.6.1] - 2026-08-15
### Changed
- 搜索结果支持拖拽移动/复制（文件列表重写为原生 NSTableView，真实文件路径拖拽）
## [1.6.0] - 2026-08-13
### Changed
- 原生全局快捷键显示主窗口（可自定义，默认⌘⌃F）
## [1.5.0] - 2026-08-13
### Changed
- 设置界面改为原生设置窗口，路径白名单/黑名单支持拖动排序
## [1.4.0] - 2026-08-13
### Changed
- 搜索排序与筛选基于完整结果集（移除 10000 条上限，滚动到底部自动加载更多）
## [1.3.1] - 2026-08-13
### Changed
- 修复列表行选中，双击改用 NSTableView doubleAction 处理
## [1.3.0] - 2026-08-13
### Changed
- 修复搜索通配符/NOT 逻辑与文件身份稳定性，改用 FSEvents 实时监控，完善文件/文件夹右键菜单并修复选中高亮
## [1.2.9] - 2026-03-06
### Changed
- Bumped deployment target to macOS 14.0 to support modern SwiftUI APIs and fixed event handler UPP usage
## [1.2.8] - 2026-03-06
### Changed
- Fixed build errors: removed NewEventHandlerUPP and fixed MACOSX_DEPLOYMENT_TARGET
## [1.2.7] - 2026-03-06
### Changed
- Implemented global hotkey Cmd+Ctrl+F to bring app to front
## [1.2.6] - 2026-03-06
### Changed
- Fixed Settings UI visual glitch by unifying background color
## [1.2.5] - 2026-03-06
### Changed
- Fixed Settings UI layout to eliminate gray strips by ensuring content fills available space
## [1.2.4] - 2026-03-06 (Build 260001)
### Changed
- Beautified Settings UI with unified background and cleaner list styles
## [1.2.3] - 2025-12-23
### Added
- Initial changelog entry.
