//
//  Logger.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import Foundation
import OSLog

/// 日志管理器
class Logger {
    static let shared = Logger()
    
    private let logFileURL: URL
    private let fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.mygo.logger", qos: .utility)
    private let osLogger = OSLog(subsystem: "com.mygo", category: "MyGo")
    
    private init() {
        // 日志文件路径：应用支持目录/MyGo/logs/app.log
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logsDirectory = appSupportURL.appendingPathComponent("MyGo/logs", isDirectory: true)
        
        // 创建日志目录
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        // 日志文件路径
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        logFileURL = logsDirectory.appendingPathComponent("app-\(dateString).log")
        
        // 创建或打开日志文件
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        // 打开文件句柄用于追加写入
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()
        
        // 写入启动日志
        log("应用启动", level: .info)
    }
    
    deinit {
        fileHandle?.closeFile()
    }
    
    /// 记录日志
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)\n"
        
        // 同时输出到控制台和文件
        print(logMessage, terminator: "")
        
        // 使用 OSLog 记录（系统日志）
        let osLogType: OSLogType
        switch level {
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .warning:
            osLogType = .default
        case .error:
            osLogType = .error
        }
        os_log("%{public}@", log: osLogger, type: osLogType, message)
        
        // 写入文件
        queue.async { [weak self] in
            guard let self = self, let fileHandle = self.fileHandle else { return }
            if let data = logMessage.data(using: .utf8) {
                fileHandle.write(data)
                fileHandle.synchronizeFile()
            }
        }
    }
    
    /// 获取日志文件路径
    func getLogFileURL() -> URL {
        return logFileURL
    }
    
    /// 获取日志文件路径（字符串）
    func getLogFilePath() -> String {
        return logFileURL.path
    }
    
    /// 清空日志文件
    func clearLog() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? "".write(to: self.logFileURL, atomically: true, encoding: .utf8)
            self.fileHandle?.seekToEndOfFile()
        }
    }
}

/// 日志级别
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

