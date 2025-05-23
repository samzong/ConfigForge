# Kubernetes 配置管理提案

### 当前设计问题

当前的 Kubernetes 配置管理设计将配置分割为单个 `.kube/config` 文件中的集群、用户和上下文。这种方法带来了几个挑战：

- `.kube/config` 文件随着众多条目变得难以管理
- 维护单个组件（集群、用户、上下文）很麻烦
- 大多数 kubeconfig 文件都是作为完整的 YAML 文档分发的，使得当前的分段方法不直观
- 没有明确的方法来管理多个环境或项目

## 解决方案

我们建议转向基于文件的管理方法，其中：

- 完整的 kubeconfig 文件单独存储在专用目录 (`~/.kube/configs/`) 中
- ConfigForge 通过覆盖主 `~/.kube/config` 文件来管理这些配置之间的切换
- 在发现过程中执行基本的文件验证
- 简单的备份机制 (`~/.kube/config.bak`) 保存先前的配置

这种方法旨在简化处理多个完整 kubeconfig 文件的用户的管理，减少手动编辑主 `~/.kube/config` 的需求。

## 设计目标

- **简化配置管理**：消除手动编辑 `.kube/config` 文件的需求
- **改善组织**：提供直观的方式来分类和查找配置
- **增强用户体验**：使配置切换无缝和可视化

## 用户界面设计

### 配置列表

侧边栏列出发现的 Kubernetes 配置，包括活动配置和来自 `configs/` 目录的文件。

**主要功能：**

- 显示活动的 `~/.kube/config`（明确标记）
- 列出 `~/.kube/configs/` 中的所有文件
- 指示验证状态（例如，标记无效/无法解析的文件）
- 提供一个"添加"按钮，在 `~/.kube/configs/` 中创建新的空配置文件
- 包含用于文件管理和激活的上下文菜单操作
- 如果未找到配置，则显示空状态消息

### 配置编辑器

显示所选配置文件（活动 `config` 或 `configs/` 中的文件）的内容。默认为只读模式。

**主要功能：**

- **默认只读**：默认情况下在不可编辑的查看器中显示 YAML 内容
- **语法高亮**：查看器和编辑器都必须支持 YAML 语法高亮
- **显式编辑模式**："编辑"按钮切换到可编辑的文本区域
- **保存/取消**：在编辑模式下，"保存"将更改写回文件，"取消"放弃更改
- **处理损坏的文件**：允许查看并尝试编辑甚至标记为无效/损坏的文件

## 架构概述

### 系统组件

```
┌─────────────────┐      ┌─────────────────┐
│                 │      │                 │
│  配置库         │◄────►│ 配置切换器      │
│ (`~/.kube/configs/`)│      │ (包括备份)      │
│  配置库         │◄────►│ 配置切换器      │
│ (`~/.kube/configs/`)│      │ (包括备份)      │
│                 │      │                 │
└────────┬────────┘      └────────┬────────┘
         │                        │
         │                        │
         ▼                        ▼
┌─────────────────┐      ┌─────────────────┐
│                 │      │                 │
│  文件系统       │      │  活动配置       │
│  服务           │      │ (`~/.kube/config`)│
│ (读/写/列表)    │      │                 │
│  文件系统       │      │  活动配置       │
│  服务           │      │ (`~/.kube/config`)│
│ (读/写/列表)    │      │                 │
│                 │      │                 │
└─────────────────┘      └─────────────────┘
```

### 组件描述

1. **配置库**：存储单个 kubeconfig 文件的 `~/.kube/configs/` 目录
2. **配置切换器**：处理激活所选配置的过程:
   - 备份当前 `~/.kube/config` 到 `~/.kube/config.bak`
   - 将所选配置从 `~/.kube/configs/` 复制到 `~/.kube/config`
3. **文件系统服务**：处理底层文件操作和基本验证
4. **活动配置**：`~/.kube/config` 文件，由 ConfigForge 管理

## 文件组织结构

```
~/.kube/
├── config                 # 活动配置文件，由 ConfigForge 管理
├── config.bak             # 先前活动配置文件的备份
└── configs/               # 包含单个 kubeconfig 文件的目录
├── config                 # 活动配置文件，由 ConfigForge 管理
├── config.bak             # 先前活动配置文件的备份
└── configs/               # 包含单个 kubeconfig 文件的目录
    ├── prod-cluster-a.yaml
    ├── dev-cluster-b.yaml
    └── staging-cluster-c.yaml
```
