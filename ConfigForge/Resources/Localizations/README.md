# ConfigForge 本地化开发指南

本项目使用 SwiftGen 进行本地化字符串的结构化管理，提供类型安全的本地化访问。

## 添加新字符串

1. 在对应语言的 `Localizable.strings` 文件中添加新的键值对：
   ```swift
   // ConfigForge/Resources/Localizations/zh.lproj/Localizable.strings
   "your.new.key" = "你的新字符串";
   
   // ConfigForge/Resources/Localizations/en.lproj/Localizable.strings
   "your.new.key" = "Your new string";
   ```

2. 运行 SwiftGen 重新生成代码：
   ```bash
   swiftgen
   ```
   或使用 Make 命令：
   ```bash
   make swiftgen
   ```

3. 使用生成的类型安全 API 访问本地化字符串：
   ```swift
   // 普通文本
   Text(L10n.Your.New.key)
   
   // 带参数的文本
   Text(L10n.Message.welcome("John"))
   ```

## 最佳实践

1. **组织结构**：使用点号分隔的命名空间组织字符串，例如 `section.subsection.key`

2. **参数化字符串**：对于可变内容，使用参数而不是字符串拼接：
   ```swift
   // 在 Localizable.strings 中
   "user.greeting" = "欢迎回来, %@!";
   
   // 在代码中使用
   Text(L10n.User.greeting(userName))
   ```

3. **遵循层次结构**：在添加新字符串时，尊重现有的分层结构，使生成的代码保持一致性

4. **注释**：在 Localizable.strings 文件中为复杂的字符串添加注释，说明它们的用途或特殊格式要求

5. **避免硬编码字符串**：永远不要直接在代码中写入硬编码的显示字符串，始终使用本地化键

## 迁移指南

我们正在从自定义的 `.cfLocalized` 扩展迁移到 SwiftGen 生成的类型安全 API。如果你在项目中发现使用 `.cfLocalized` 的地方，请将其替换为相应的 `L10n` 类型：

```swift
// 旧方式
Text("app.save".cfLocalized)

// 新方式
Text(L10n.App.save)

// 旧方式（带参数）
Text("kubernetes.cluster.edit".cfLocalized(with: cluster.name))

// 新方式（带参数）
Text(L10n.Kubernetes.Cluster.edit(cluster.name))
```

## 注意事项

- 在修改 Localizable.strings 文件后，必须运行 SwiftGen 重新生成代码
- 生成的代码位于 `ConfigForge/Generated/Strings.swift`
- 新增的本地化字符串必须同时添加到所有语言文件中，以避免缺失翻译 