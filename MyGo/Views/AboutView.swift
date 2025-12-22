//
//  AboutView.swift
//  MyGo
//
//  Created by MY Liu on 11/28/25.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标和名称
            VStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                
                Text("MyGo")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Version 1.0 (1)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)
            
            Divider()
                .padding(.horizontal, 40)
            
            // 应用描述
            VStack(spacing: 12) {
                Text("高效的文件搜索工具")
                    .font(.system(size: 16, weight: .medium))
                
                Text("MyGo是一款专为macOS设计的轻量级文件搜索工具，提供快速、准确的文件定位服务。通过智能索引和强大的搜索功能，帮助您在海量文件中快速找到所需内容。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 400)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            
            // 功能特性
            VStack(alignment: .leading, spacing: 8) {
                Text("主要功能：")
                    .font(.system(size: 13, weight: .semibold))
                
                VStack(alignment: .leading, spacing: 6) {
                    FeatureRow(icon: "magnifyingglass", text: "实时搜索与高级查询语法")
                    FeatureRow(icon: "doc.text", text: "支持正则表达式搜索")
                    FeatureRow(icon: "folder", text: "智能文件索引与实时监控")
                    FeatureRow(icon: "slider.horizontal.3", text: "多维度文件筛选")
                    FeatureRow(icon: "bolt", text: "高性能索引算法")
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            
            Spacer()
            
            // 版权信息
            Text("Copyright © 2025 MY Liu. All rights reserved.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    AboutView()
}

