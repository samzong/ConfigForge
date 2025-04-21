# ConfigForge

<p align="center">
  <img src="ConfigForge/Assets.xcassets/Logo.imageset/logo.png" alt="ConfigForge Logo" width="200">
</p>

<p align="center">
  <b>简洁高效的 macOS 配置管理工具</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2010.15%2B-brightgreen" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6.1-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License">
</p>

## 简介

ConfigForge 是一款专为 macOS 用户设计的开源配置管理工具，支持 SSH 配置和 Kubernetes 配置的可视化管理。提供简洁直观的图形界面来管理 `~/.ssh/config` 和 `~/.kube/config` 文件，让您轻松查看、搜索、编辑和管理各类配置，避免直接编辑文本文件的繁琐和错误风险。

![screenshot](screenshot.png)

作为一个完全开源的项目，ConfigForge 尊重用户的隐私和自由，所有代码公开透明，确保您的配置安全可靠。

## 主要功能

### SSH 配置管理

- **直观的图形界面**：清晰展示所有 SSH 配置条目
- **快速搜索与排序**：轻松定位特定的 SSH 连接配置
- **便捷编辑**：通过表单界面编辑 SSH 配置，无需手动输入复杂语法
- **基础语法高亮**：提高配置文件的可读性
- **一键打开终端**：提供快捷的方式一键连接到目标 SSH 主机

### Kubernetes 配置管理

- **完整 Kubeconfig 支持**：可视化管理 Kubernetes 配置文件
- **Context 管理**：创建、编辑、删除 Context 以及设置当前活跃的 Context
- **Cluster 管理**：管理集群配置，包括服务器地址和证书信息
- **User 管理**：管理用户认证信息，支持 Token 和证书认证
- **跨对象关联**：在 Context 中方便地关联和管理 Cluster 和 User

### 命令行工具 (CLI)

- **SSH 操作**：在终端中列出、连接 SSH 主机
- **Kubernetes 管理**：快速查看和切换 Kubernetes 上下文
- **与桌面应用无缝集成**：CLI 与桌面应用程序共享配置
- **易于使用**：简洁的命令结构，内置帮助信息

### 通用功能

- **备份与恢复**：安全备份和恢复配置文件
- **通用二进制**：同时支持 Intel 和 Apple Silicon 芯片的 Mac 设备
- **国际化支持**：提供中文和英文界面

## 系统要求

- macOS 10.15 Catalina 或更高版本
- 支持 Intel 和 Apple Silicon (M 系列) 芯片架构

## 安装

### 使用 Homebrew 安装（推荐）

```bash
brew tap samzong/tap
brew install configforge
```

通过 Homebrew 安装后，桌面应用将安装到 Applications 文件夹，CLI 工具 `cf` 会自动添加到您的 PATH 中。

### 手动安装

1. 从 [Releases](https://github.com/samzong/ConfigForge/releases) 页面下载最新的 DMG 文件
2. 打开 DMG 文件并将 ConfigForge 应用拖动到 Applications 文件夹
3. 首次运行时，系统可能会提示"无法验证开发者"，请在系统偏好设置中允许运行

要手动安装 CLI 工具，请运行以下命令：

```bash
sudo ln -sf /Applications/ConfigForge.app/Contents/Resources/bin/cf /usr/local/bin/cf
```

## 使用方法

### SSH 配置管理 (GUI)

1. 启动 ConfigForge 应用程序
2. 在顶部选择器中选择 "SSH" 模式（默认）
3. 应用会自动加载您的 `~/.ssh/config` 文件内容
4. 使用左侧列表浏览和搜索 SSH 配置条目
5. 选择一个条目查看详细配置，或添加新条目
6. 编辑配置并保存更改

### Kubernetes 配置管理 (GUI)

1. 启动 ConfigForge 应用程序
2. 在顶部选择器中切换到 "Kubernetes" 模式
3. 应用会自动加载您的 `~/.kube/config` 文件内容
4. 使用次级选择器在 "Contexts"、"Clusters" 和 "Users" 之间切换
5. 使用左侧列表浏览、搜索对应的配置条目
6. 选择一个条目查看详细信息，或添加新条目
7. 右键点击 Context 可以将其设置为当前活跃的 Context

### 命令行工具 (CLI)

安装 ConfigForge 后，您可以使用 `cf` 命令行工具：

```bash
# 列出所有 SSH 主机
cf ssh list

# 连接到指定的 SSH 主机
cf ssh connect dev-server

# 列出所有 Kubernetes 上下文
cf kube list

# 切换到指定的 Kubernetes 上下文
cf kube context production

# 显示当前 Kubernetes 上下文
cf kube current

# 查看帮助
cf help
```

详细的 CLI 使用说明请参考 [CLI/README.md](CLI/README.md)。

## 权限说明

ConfigForge 需要访问您的 `~/.ssh/config` 和 `~/.kube/config` 文件才能正常工作。在首次运行时，可能会请求文件访问权限。所有操作都在本地进行，不会发送任何数据到外部服务器。

## 更新日志

查看 [CHANGELOG.md](CHANGELOG.md) 以了解所有版本的更新详情。

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
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser) 用于 CLI 开发
- 所有为项目提供反馈和建议的用户
