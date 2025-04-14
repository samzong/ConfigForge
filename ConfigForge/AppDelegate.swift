//
//  AppDelegate.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 立即初始化终端服务并检查权限
        Task { @MainActor in
            // 触发权限检查
            _ = TerminalLauncherService.shared
            // 检查首次启动
            await checkFirstLaunch()
        }
    }
    
    // 检查是否是首次启动应用
    @MainActor
    private func checkFirstLaunch() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        
        if isFirstLaunch {
            print("📱 检测到首次启动应用")
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            
            // 显示欢迎提示，并预先说明权限需求
            Task { @MainActor in
                // 等待1秒
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await self.showWelcomeAndPermissionsInfo()
            }
        } else {
            // 非首次启动，检查权限状态
            Task {
                // 检查终端自动化权限
                await self.checkTerminalPermissions()
            }
        }
    }
    
    // 显示欢迎和权限信息
    @MainActor
    private func showWelcomeAndPermissionsInfo() {
        let alert = NSAlert()
        alert.messageText = "欢迎使用 ConfigForge"
        alert.informativeText = """
        感谢您使用 ConfigForge 来管理您的 SSH 和 Kubernetes 配置！
        
        为了提供完整的功能，应用需要以下权限：
        
        • 自动化权限：用于启动终端并执行SSH连接
        • 文件访问权限：用于读取和写入SSH和Kubernetes配置文件
        
        在使用相关功能时，系统会提示您授予这些权限。
        """
        alert.addButton(withTitle: "开始使用")
        alert.addButton(withTitle: "查看权限详情")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // 用户点击了"查看权限详情"
            Task { @MainActor in
                await self.showPermissionsDetails()
            }
        }
    }
    
    // 显示详细的权限信息
    @MainActor
    private func showPermissionsDetails() {
        let alert = NSAlert()
        alert.messageText = "权限详情"
        alert.informativeText = """
        ConfigForge 需要以下权限才能正常工作：
        
        1. 自动化权限
        • 允许 ConfigForge 控制 Terminal.app 或 iTerm.app
        • 用于自动启动终端并执行SSH连接
        • 可在系统设置 > 隐私与安全性 > 自动化中配置
        
        2. 文件访问权限
        • 访问 ~/.ssh/ 目录：读取和保存SSH配置
        • 访问 ~/.kube/ 目录：读取和保存Kubernetes配置
        
        您可以随时在系统设置中查看和调整这些权限。
        """
        alert.addButton(withTitle: "了解了")
        alert.runModal()
    }
    
    // 检查终端自动化权限
    @MainActor
    private func checkTerminalPermissions() async {
        let terminalService = TerminalLauncherService.shared
        
        // 获取已安装的终端应用
        let installedTerminals = await terminalService.getInstalledTerminalApps()
        
        // 如果有已安装的终端应用，检查权限
        if !installedTerminals.isEmpty {
            // 检查所有终端应用的权限
            for terminal in installedTerminals {
                let hasPermission = await terminalService.checkAppleScriptPermission(for: terminal)
                if !hasPermission {
                    print("📱 检测到缺少\(terminal.name)的自动化权限，尝试请求")
                    await terminalService.requestTerminalAutomationPermission(terminal: terminal)
                } else {
                    print("📱 \(terminal.name)的自动化权限正常")
                }
            }
            
            // 权限检查完成后执行诊断
            let diagnostics = await terminalService.getAutomationDiagnostics()
            print("📱 权限诊断结果:\n\(diagnostics)")
        }
    }
}
