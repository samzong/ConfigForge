# ConfigForge UI 统一改造计划

本文档详细列出了将 Kubernetes 界面与 SSH 界面进行统一的改造计划，确保两个界面在视觉和交互上保持一致，同时保留各自的功能特性。

## 总体目标

将 Kubernetes UI 改造为与 SSH UI 保持一致的风格，包括搜索框、操作按钮、颜色等元素，使整个应用看起来更加统一，同时确保所有现有功能不受影响。

## 需要修改的内容

### 5. ConfigEditorView.swift 调整

- [x] 确保 Kubernetes 编辑区域的布局与 SSH 编辑区域保持一致
- [x] 统一编辑区域的边距、颜色和交互

```swift
struct EmptyConfigView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.secondary)
            
            Text("没有选择配置文件")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("请从左侧选择一个配置文件，或创建一个新的配置。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

### 7. 颜色和视觉样式统一

- [x] 确保两个界面使用相同的颜色方案
- [x] 统一按钮的样式和交互效果
- [x] 统一列表项选中状态的视觉效果

## 额外改进

1. **列表选择逻辑统一**：确保 Kubernetes 配置文件列表与 SSH 主机列表使用相同的选择逻辑 - [x]
2. **拖放操作**：如果 SSH 界面支持拖放操作，Kubernetes 界面也应该实现类似功能 - [ ]
3. **键盘快捷键**：确保两个界面支持相同的键盘快捷键和导航方式 - [ ]

## 剩余任务

1. ~~完成 ConfigEditorView.swift 的调整，确保与 SSH 编辑区域保持一致~~ [已完成]
2. 实现拖放操作（如果 SSH 界面支持）
3. 确保两个界面支持相同的键盘快捷键
4. 执行测试计划中的各项测试

完成上述改造后，Kubernetes 界面将与 SSH 界面保持一致的视觉风格和交互体验，同时保留其所有功能特性，使整个应用更加统一和专业。