# ConfigForge 开发文档

## 1. 项目概述

ConfigForge 是一个专为 macOS 用户设计的开源 SSH 配置管理工具，旨在提供简洁直观的图形界面来管理 `~/.ssh/config` 文件。该应用程序使用 SwiftUI 构建，为用户提供现代化的 macOS 原生体验，使用户能够更高效、更安全地管理他们的 SSH 配置。

作为一个完全开源的项目，ConfigForge 尊重用户的隐私和自由，所有代码公开透明，社区贡献者可以审查和改进。应用发布通过 Homebrew ，不会上架到 MacOS 的 App store.

本文档详细描述了 ConfigForge 的技术架构、组件设计及开发指南，为开发人员提供清晰的实施路径。

## 2. 技术栈

### 2.1 开发环境

- **操作系统**: macOS 15.4 Sequoia
- **IDE**: Xcode 16.3
- **构建工具**: Swift Package Manager (SPM)

### 2.2 主要框架和语言

- **编程语言**: Swift 6.1
- **UI 框架**: SwiftUI 6.1
- **应用程序架构**: MVVM (Model-View-ViewModel)
- **文件处理**: Foundation Framework
- **持久化存储**: FileManager, UserDefaults
- **测试框架**: XCTest
- **版本控制**: Git

## 3. 系统架构

### 3.1 架构概览

ConfigForge 采用 MVVM (Model-View-ViewModel) 架构模式，确保业务逻辑和 UI 的分离，提高代码的可测试性和可维护性。

```
┌────────────┐    ┌────────────┐    ┌────────────┐
│            │    │            │    │            │
│   Model    │◄───┤  ViewModel │◄───┤    View    │
│            │    │            │    │            │
└────────────┘    └────────────┘    └────────────┘
       ▲                 ▲                 ▲
       │                 │                 │
       └──────┬──────────┘                 │
              │                            │
       ┌──────▼──────┐             ┌───────▼─────┐
       │             │             │             │
       │  Services   │             │   SwiftUI   │
       │             │             │             │
       └─────────────┘             └─────────────┘
```

### 3.2 核心组件

1. **模型层 (Model)**:
   - 定义数据结构和业务规则
   - 表示 SSH 配置条目的结构

2. **视图层 (View)**:
   - 使用 SwiftUI 构建用户界面
   - 响应用户交互
   - 显示 ViewModel 提供的数据

3. **视图模型层 (ViewModel)**:
   - 处理视图的业务逻辑
   - 在视图和模型之间进行协调
   - 管理 UI 状态

4. **服务层 (Services)**:
   - 处理文件读写操作
   - 提供配置解析和验证功能
   - 实现备份和恢复逻辑

## 4. 模块设计

### 4.1 SSH 配置模型模块

负责定义和管理 SSH 配置的数据模型。

```swift
// SSHConfigEntry.swift
struct SSHConfigEntry: Identifiable {
    let id = UUID()
    var host: String
    var properties: [String: String]
    
    // 计算属性用于直接访问常用配置
    var hostname: String? { properties["HostName"] }
    var user: String? { properties["User"] }
    var port: String? { properties["Port"] }
    var identityFile: String? { properties["IdentityFile"] }
}
```

### 4.2 文件管理模块

负责与文件系统交互，读取和写入 SSH 配置文件。

```swift
// SSHConfigFileManager.swift
class SSHConfigFileManager {
    func readConfigFile() -> Result<String, Error>
    func writeConfigFile(content: String) -> Result<Void, Error>
    func backupConfigFile(to destination: URL) -> Result<URL, Error>
    func restoreConfigFile(from source: URL) -> Result<Void, Error>
}
```

### 4.3 配置解析模块

负责解析和格式化 SSH 配置文件内容。

```swift
// SSHConfigParser.swift
class SSHConfigParser {
    func parseConfig(content: String) -> [SSHConfigEntry]
    func formatConfig(entries: [SSHConfigEntry]) -> String
    func validateEntry(entry: SSHConfigEntry, existingEntries: [SSHConfigEntry]) -> Bool
}
```

### 4.4 视图模型模块

管理应用程序的状态和业务逻辑。

```swift
// SSHConfigViewModel.swift
class SSHConfigViewModel: ObservableObject {
    @Published var entries: [SSHConfigEntry] = []
    @Published var searchText: String = ""
    @Published var selectedEntry: SSHConfigEntry?
    @Published var isEditing: Bool = false
    
    // 过滤后的条目列表
    var filteredEntries: [SSHConfigEntry] {
        if searchText.isEmpty {
            return entries.sorted { $0.host < $1.host }
        } else {
            return entries.filter { $0.host.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.host < $1.host }
        }
    }
    
    func loadConfig()
    func saveConfig()
    func addEntry(host: String, properties: [String: String])
    func updateEntry(id: UUID, host: String, properties: [String: String])
    func deleteEntry(id: UUID)
    func backupConfig(to destination: URL?)
    func restoreConfig(from source: URL?)
}
```

### 4.5 用户界面模块

使用 SwiftUI 实现的视图层组件。

#### 4.5.1 主视图

```swift
// ContentView.swift
struct ContentView: View {
    @StateObject private var viewModel = SSHConfigViewModel()
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏：条目列表
            EntryListView(viewModel: viewModel)
        } detail: {
            // 详情视图：编辑器
            if let selectedEntry = viewModel.selectedEntry {
                EntryEditorView(viewModel: viewModel, entry: selectedEntry)
            } else {
                EmptyEditorView()
            }
        }
        .toolbar {
            // 工具栏：添加、备份、恢复等操作
            ToolbarItems(viewModel: viewModel)
        }
    }
}
```

#### 4.5.2 列表视图

```swift
// EntryListView.swift
struct EntryListView: View {
    @ObservedObject var viewModel: SSHConfigViewModel
    
    var body: some View {
        List(viewModel.filteredEntries, selection: $viewModel.selectedEntry) { entry in
            Text(entry.host)
                .contextMenu {
                    Button("删除", role: .destructive) {
                        // 确认删除操作
                    }
                }
        }
        .searchable(text: $viewModel.searchText, prompt: "搜索 Host")
    }
}
```

#### 4.5.3 编辑器视图

```swift
// EntryEditorView.swift
struct EntryEditorView: View {
    @ObservedObject var viewModel: SSHConfigViewModel
    var entry: SSHConfigEntry
    @State private var editedHost: String
    @State private var editedProperties: [String: String]
    
    var body: some View {
        VStack(alignment: .leading) {
            // 编辑器控件
            EditorControls(isEditing: $viewModel.isEditing)
            
            // 主机名称编辑
            HostEditor(host: $editedHost, isEditing: viewModel.isEditing)
            
            // 属性编辑
            PropertiesEditor(properties: $editedProperties, isEditing: viewModel.isEditing)
            
            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItem {
                Button(viewModel.isEditing ? "保存" : "编辑") {
                    if viewModel.isEditing {
                        // 保存编辑
                        viewModel.updateEntry(id: entry.id, host: editedHost, properties: editedProperties)
                    }
                    viewModel.isEditing.toggle()
                }
            }
        }
    }
}
```

## 5. 数据流

### 5.1 加载配置流程

1. 应用程序启动时，`SSHConfigViewModel` 调用 `loadConfig()`
2. `loadConfig()` 通过 `SSHConfigFileManager` 读取 `~/.ssh/config` 文件
3. 读取的内容传递给 `SSHConfigParser` 进行解析
4. 解析后的 `[SSHConfigEntry]` 保存到 `SSHConfigViewModel.entries`
5. `ContentView` 通过 `@StateObject` 观察 `SSHConfigViewModel` 的变化并更新 UI

### 5.2 保存配置流程

1. 用户编辑完成并点击"保存"
2. `EntryEditorView` 调用 `viewModel.updateEntry()`
3. `updateEntry()` 更新 `ViewModel` 中的 `entries` 数组
4. `ViewModel` 调用 `saveConfig()` 方法
5. `saveConfig()` 使用 `SSHConfigParser` 将 `entries` 格式化为文本
6. 格式化后的文本通过 `SSHConfigFileManager` 写入到 `~/.ssh/config` 文件

## 6. 开发环境设置

### 6.1 环境要求

- macOS 15.4 Sequoia（开发环境）
- Xcode 16.3（开发工具）
- ConfigForge 支持 macOS 10.15 Catalina 及以上版本
- 原生支持 Intel 和 Apple Silicon (M系列) 芯片架构

### 6.2 开发环境配置步骤

1. 克隆仓库:
   ```bash
   git clone https://github.com/samzong/ConfigForge.git
   cd ConfigForge
   ```

2. 打开项目:
   ```bash
   open ConfigForge.xcodeproj
   ```

3. 构建和运行:
   - 选择 "My Mac" 作为运行目标
   - 点击运行按钮或使用 ⌘+R 快捷键

### 6.3 开发工作流

1. 从 `main` 分支创建功能分支:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. 开发和测试功能

3. 提交更改:
   ```bash
   git add .
   git commit -m "Add feature: your feature description"
   ```

4. 推送到远程仓库:
   ```bash
   git push origin feature/your-feature-name
   ```

## 测试策略

### 单元测试

使用 XCTest 框架为核心组件编写单元测试:

- **模型测试**: 验证 `SSHConfigEntry` 的行为
- **服务测试**: 测试 `SSHConfigFileManager` 和 `SSHConfigParser` 的功能
- **视图模型测试**: 确保 `SSHConfigViewModel` 正确处理业务逻辑

### UI 测试

使用 XCTest 的 UI 测试功能:

- 测试基本的用户流程
- 验证 UI 组件的行为和交互
- 确保正确显示错误信息和状态

## 代码规范

- 遵循 Swift API 设计指南
- 使用 SwiftLint 保持代码风格一致
- 为所有公共 API 提供文档注释


- [Swift 官方文档](https://swift.org/documentation/)
- [SwiftUI 官方文档](https://developer.apple.com/documentation/swiftui)
- [Human Interface Guidelines for macOS](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SSH 配置文件格式](https://man.openbsd.org/ssh_config.5)

## 13. 常见问题解答

### 13.1 开发问题

**Q: 如何处理文件访问权限问题?**  
A: 应用需要获取对 `~/.ssh/config` 文件的读写权限。在macOS上，这可能需要请求"完全磁盘访问权限"。应用应该检测权限问题并向用户提供明确的指导。

**Q: 如何确保并发安全?**  
A: 使用 Swift 的并发模型和actor系统确保文件操作的线程安全。在MVP版本中，我们将使用同步操作，但设计应允许未来的异步实现。

### 13.2 用户问题

**Q: 应用程序如何处理格式错误的配置文件?**  
A: 应用将尝试解析文件，即使存在格式问题。无法解析的行将保持原样，并在UI中标记为"无法解析"。应用会警告用户，但不会拒绝加载文件。

**Q: 是否支持多个SSH配置文件?**  
A: MVP版本仅支持 `~/.ssh/config` 文件。多配置文件支持计划在未来版本中实现。

## 14. 版本控制与更新日志

### 14.1 版本规范

项目使用[语义化版本控制](https://semver.org/lang/zh-CN/)，格式为 `X.Y.Z`：

- **X**: 主要版本号，不兼容的API变更
- **Y**: 次要版本号，向后兼容的功能性新增
- **Z**: 修订号，向后兼容的问题修正

### 14.2 生成更新日志

项目使用 [GitHub Changelog Generator](https://github.com/github-changelog-generator/github-changelog-generator) 自动生成更新日志。

开发者需要在本地安装此工具：

```bash
gem install github_changelog_generator
```

#### 生成更新日志步骤：

1. 设置 GitHub Token 环境变量：
   ```bash
   export GITHUB_TOKEN=your_github_token
   ```

2. 生成更新日志：
   ```bash
   # 生成下一个版本的更新日志
   make changelog NEXT_VERSION=vX.Y.Z
   
   # 或者生成到最新标签的更新日志
   make changelog
   ```

### 14.3 贡献指南

1. 提交信息应遵循[约定式提交](https://www.conventionalcommits.org/zh-hans/v1.0.0/)规范：
   ```
   <类型>[可选的作用域]: <描述>
   
   [可选的正文]
   
   [可选的页脚]
   ```

   类型包括：
   - **feat**: 新功能
   - **fix**: 修复问题
   - **docs**: 文档更改
   - **style**: 格式变动（不影响代码运行）
   - **refactor**: 重构
   - **perf**: 性能优化
   - **test**: 添加测试
   - **chore**: 构建过程或工具变动

2. 在打标签前请更新 `.github_changelog_generator` 文件中的 `future-release` 参数。

3. 创建版本标签后，GitHub Actions 会自动生成更新日志并将其包含在发布中。

## 15. 附录

### 15.1 相关技术版本信息

- **macOS**: 15.4 Sequoia (开发环境)
- **Xcode**: 16.3 (包含Swift 6.1和macOS 15.4 SDK)
- **Swift**: 6.1
- **SwiftUI**: 6.1
- **Foundation Framework**: 实用程序框架，包含在macOS系统中
- **兼容性**: 支持 macOS 10.15 Catalina 及更高版本
- **架构支持**: Universal Binary (同时支持 Intel x86_64 和 Apple Silicon arm64 架构)
