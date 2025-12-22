//
//  PermissionSetupView.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI
import AppKit

struct PermissionSetupView: View {
    @State private var hasPermission = false
    @State private var isChecking = false
    @State private var checkTimer: Timer?
    let onPermissionGranted: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // 图标
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            // 标题
            Text("需要文件访问权限")
                .font(.title)
                .fontWeight(.bold)
            
            // 说明文字
            VStack(alignment: .leading, spacing: 12) {
                Text("为了能够打开和访问文件，MyGo 需要以下权限：")
                    .font(.body)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        Text("完全磁盘访问权限 - 用于访问和打开文件")
                            .font(.body)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        Text("文件和文件夹访问权限 - 用于浏览和搜索文件")
                            .font(.body)
                    }
                }
                .padding(.leading, 20)
            }
            .frame(maxWidth: 500)
            
            // 操作步骤
            VStack(alignment: .leading, spacing: 12) {
                Text("请按照以下步骤设置权限：")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    StepView(number: 1, text: "点击下方的\"打开系统设置\"按钮")
                    StepView(number: 2, text: "在系统设置中找到\"完全磁盘访问权限\"")
                    StepView(number: 3, text: "找到并勾选\"MyGo\"应用")
                    StepView(number: 4, text: "返回此窗口，点击\"检查权限\"按钮")
                }
            }
            .frame(maxWidth: 500)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // 按钮
            HStack(spacing: 16) {
                Button(action: {
                    PermissionManager.shared.openFullDiskAccessSettings()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("打开系统设置")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    checkPermission()
                }) {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("检查权限")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.bordered)
                .disabled(isChecking)
            }
            
            if hasPermission {
                Text("✓ 权限已授予")
                    .foregroundColor(.green)
                    .font(.headline)
            }
        }
        .padding(40)
        .frame(width: 600, height: 700)
        .onAppear {
            // 自动检查一次权限
            checkPermission()
            // 启动定时器，定期检查权限
            startPeriodicCheck()
        }
        .onDisappear {
            // 停止定时器
            checkTimer?.invalidate()
            checkTimer = nil
        }
        .onChange(of: hasPermission) { oldValue, newValue in
            if newValue {
                // 停止定时器
                checkTimer?.invalidate()
                checkTimer = nil
                // 延迟一下再触发回调，让用户看到成功提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onPermissionGranted()
                }
            }
        }
    }
    
    private func startPeriodicCheck() {
        // 每2秒检查一次权限
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if !hasPermission {
                checkPermission()
            }
        }
    }
    
    private func checkPermission() {
        isChecking = true
        
        // 延迟检查，给用户时间设置权限
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let hasFileAccess = PermissionManager.shared.checkFileAccessPermission()
            let hasFullDiskAccess = PermissionManager.shared.checkFullDiskAccessPermission()
            
            // 至少需要文件访问权限
            hasPermission = hasFileAccess || hasFullDiskAccess
            isChecking = false
        }
    }
}

struct StepView: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(text)
                .font(.body)
        }
    }
}

