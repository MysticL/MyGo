# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).








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
