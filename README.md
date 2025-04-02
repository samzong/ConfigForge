# ConfigForge

<p align="center">
  <img src="Resources/logo.png" alt="ConfigForge Logo" width="200">
</p>

<p align="center">
  <b>简洁高效的 macOS SSH 配置管理工具</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2010.15%2B-brightgreen" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6.1-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License">
</p>

## 简介

ConfigForge 是一款专为 macOS 用户设计的开源 SSH 配置管理工具，提供简洁直观的图形界面来管理 `~/.ssh/config` 文件。使用 ConfigForge，您可以轻松查看、搜索、编辑和管理 SSH 配置，避免直接编辑文本文件的繁琐和错误风险。

作为一个完全开源的项目，ConfigForge 尊重用户的隐私和自由，所有代码公开透明，确保您的 SSH 配置安全可靠。

## 主要功能

- **直观的图形界面**：清晰展示所有 SSH 配置条目
- **快速搜索与排序**：轻松定位特定的 SSH 连接配置
- **便捷编辑**：通过表单界面编辑 SSH 配置，无需手动输入复杂语法
- **基础语法高亮**：提高配置文件的可读性
- **备份与恢复**：安全备份和恢复 SSH 配置文件
- **通用二进制**：同时支持 Intel 和 Apple Silicon 芯片的 Mac 设备

## 系统要求

- macOS 10.15 Catalina 或更高版本
- 支持 Intel 和 Apple Silicon (M系列) 芯片架构

## 安装

```bash
# 安装方法将在第一个发布版本提供
```

## 使用方法

1. 启动 ConfigForge 应用程序
2. 应用会自动加载您的 `~/.ssh/config` 文件内容
3. 使用左侧列表浏览和搜索 SSH 配置条目
4. 选择一个条目查看详细配置，或添加新条目
5. 编辑配置并保存更改

## 权限说明

ConfigForge 需要访问您的 `~/.ssh/config` 文件才能正常工作。在首次运行时，可能会请求文件访问权限。所有操作都在本地进行，不会发送任何数据到外部服务器。

## 开发者指南

如果您对开发感兴趣，请查看 [DEVELOPMENT.md](DEVELOPMENT.md) 文件，其中包含完整的技术架构、组件设计和开发指南。

## 贡献

欢迎贡献代码、报告问题或提出功能建议！请参照以下步骤：

1. Fork 这个仓库
2. 创建您的功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启一个 Pull Request

## 许可证

本项目采用 MIT 许可证 - 详情请参见 [LICENSE](LICENSE) 文件。

## 鸣谢

- 感谢所有开源项目贡献者
- [Swift](https://swift.org/) 和 [SwiftUI](https://developer.apple.com/xcode/swiftui/) 团队
- 所有为项目提供反馈和建议的用户 