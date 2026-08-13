# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MyGo is a macOS file-search and management app built with SwiftUI. It indexes user-chosen directories into a local SQLite database, then searches that index with real-time, debounced results plus advanced filtering and file operations (open/reveal/copy/move/delete). Deployment target is macOS 14.0, Swift 5.0, Xcode project only — no SPM/CocoaPods dependencies and no test targets. All user-facing UI strings and code comments are in Chinese; keep new UI text consistent with that.

## Build & Run

- Open in Xcode: `open MyGo.xcodeproj` (scheme `MyGo`), then ⌘R.
- Build from the CLI: `xcodebuild -project MyGo.xcodeproj -scheme MyGo build`
- There is no lint step and no test target configured.

## Versioning & Changelog

Version numbers live in `MyGo.xcodeproj/project.pbxproj` (`MARKETING_VERSION` semver, `CURRENT_PROJECT_VERSION` build number). Bump them and prepend a `CHANGELOG.md` entry together via the automation script:

```
python3 scripts/update_version.py "Description of the change" [--type major|minor|patch]
```

The script rewrites both version keys in project.pbxproj and inserts a Keep-a-Changelog entry dated today under a `### Changed` heading. Run it when finishing a change that should be released.

## Architecture

Data flow: `ContentView` → `SearchService` → `SearchQueryParser` + `DatabaseManager` → SQLite. Indexing: `FileIndexManager` → `DatabaseManager`.

### App entry & permission gate
`MyGoApp.swift` (`@main`) creates three `ObservableObject`s injected as environment objects into the root view: `FileIndexManager`, `AppState`, `PermissionChecker`. `RootView` shows `ContentView` when `PermissionChecker.hasPermission` is true, otherwise `PermissionSetupView`. The app requires Full Disk Access — App Sandbox is off and `MyGo/MyGo.entitlements` sets `com.apple.security.files.all`. The global hotkey (⌘⌃F) is registered in `MyGoApp.init` via `HotKeyManager`.

### View layer
- `ContentView` orchestrates the main screen: `SearchBarView` (top), `FileListView` (results), `FilterView` (right-side panel). It owns search state (`searchText`, `filter`, selected whitelist/blacklist), a 0.5s debounce `Timer` that triggers `SearchService.search`, and restore/save of UI state through `PreferencesManager`.
- `FileListView` renders `FileItem`s and reports actions via `FileListView.FileAction` (open/reveal/copy/move/delete); `ContentView.handleFileAction` delegates to `FileOperationService` and updates the DB index for destructive ops.

### Service layer (singletons except `SearchService`)
- **`DatabaseManager`** — SQLite3 via the C API; DB at `~/Library/Application Support/MyGo/index.db`. Thread safety via a serial `DispatchQueue` (`dbQueue`); inserts/deletes are `async`, reads and batch operations are `sync`. Tables: `file_index` and `index_directories`. **Search is implemented here, not in `SearchService`**: `searchFiles` builds parameterized SQL (LIKE with `ESCAPE`, extension/size/date filters, `LIMIT 10000`), then post-filters in memory for regex, case-sensitivity, NOT terms, whitelist/blacklist, and finally drops any row whose file no longer exists on disk (`fileExists`). `insertOrUpdateFiles` batches inserts inside a transaction.
- **`FileIndexManager`** — drives indexing with Swift Concurrency: `Task` + `withCheckedContinuation` + `Task.detached`. `collectFileURLs` and batch DB inserts are `nonisolated` and run on background threads; progress hops to the main actor. After indexing it calls `cleanupDeletedFiles()` and starts a `FileSystemWatcher`. **Note: `FileSystemWatcher` is a stub** — a 5-second timer that only records a timestamp and does not actually detect file changes. Stale-index cleanup relies on `cleanupDeletedFiles()` and the search-time `fileExists` check, not on live watching.
- **`SearchService`** — owns `searchResults` + `searchHistory` (50 max, UserDefaults). Parses the query, applies `SearchFilter` modifier flags (which override the parser's), calls `DatabaseManager.searchFiles`, and records history.
- **`SearchQueryParser`** — tokenizes query syntax: `path:` path constraints, case/regex/file/folder modifiers (`case:`, `nocase:`, `path:`, `nopath:`, `file:`, `folder:`, `regex:`, ...), quoted phrases, AND (space), OR (`|`), NOT (`!`). Produces a `ParsedQuery` (terms + operators + modifiers).
- **`PreferencesManager`** — all UserDefaults persistence: window/column sizes, path whitelists/blacklists (JSON-encoded `PathKeywordList`), selected list IDs, `SearchFilter`, and log settings. Column widths are versioned — bump `currentColumnWidthsVersion` to force a reset to defaults.
- **`FileOperationService`** — open/reveal/copy/move/delete. `openFile` uses a 5-tier fallback chain (Launch Services → `NSWorkspace.open` → reveal-in-Finder → `selectFile` → `/usr/bin/open`).
- **`Logger`** — writes to console + OSLog + a daily file at `Application Support/MyGo/logs/app-<date>.log`. **Disabled by default**: every call no-ops unless logging is enabled in Settings (`PreferencesManager.getLogEnabled()`, default `false`). Don't rely on log output appearing unless the user has toggled it on.
- **`HotKeyManager`** — Carbon global hotkey via `RegisterEventHotKey` / `InstallEventHandler`. It passes the handler function pointer directly to the Carbon event system rather than a deprecated UPP (this was an explicit fix — don't revert to `NewEventHandlerUPP`).

### Models
- `FileItem` — immutable struct built from a `URL` (reads `resourceValues`), with formatting/sorting helpers.
- `PathKeywordList` — whitelist/blacklist keyword lists matched against full paths.
- `SearchFilter` — Codable with custom coding (`Set<String>` ↔ `[String]` for file extensions); has both an in-memory `matches(_:)` and the DB-query counterparts.

## Conventions
- UI strings and comments are in Chinese; match the existing style.
- When the filter panel is open, `SearchFilter` modifier flags override the query parser's flags (applied in `SearchService.search`).
- Destructive file operations must remove/re-add the DB index entry (see `ContentView.handleFileAction`).
