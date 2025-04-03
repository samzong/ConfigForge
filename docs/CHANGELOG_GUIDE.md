# ConfigForge 更新日志指南

本文档说明了ConfigForge项目如何使用GitHub Changelog Generator自动生成和维护CHANGELOG.md文件。

## 工作原理

ConfigForge使用[GitHub Changelog Generator](https://github.com/github-changelog-generator/github-changelog-generator)工具根据GitHub上的标签、问题和合并的Pull Request自动生成CHANGELOG.md文件。

主要工作流程：

1. 当创建新的版本标签（如 `v1.0.0`）并推送到GitHub时，GitHub Actions自动触发发布工作流
2. 发布工作流自动生成CHANGELOG.md并将其作为发布说明和附件
3. 开发人员也可以在本地使用Make命令生成更新日志

## 配置文件

项目使用 `.github_changelog_generator` 文件配置Changelog生成器：

```
user=samzong
project=ConfigForge
future-release=v0.1.0         # 将来的版本号(需在发布前更新)
header-label=# 更新日志
unreleased-label=## [未发布]
bug-labels=bug,Bug,问题       # 视为bug的标签
enhancement-labels=enhancement,Enhancement,feature,功能,优化  # 视为功能的标签
exclude-labels=wontfix,duplicate,question,invalid,doc       # 排除的标签
exclude-tags-regex=v0\.0\.[0-9]  # 排除的标签正则表达式
add-sections={"优化":{"prefix":"### 优化","labels":["优化","improvement"]},"文档":{"prefix":"### 文档","labels":["文档","documentation"]}}  # 自定义章节
since-tag=v0.0.1             # 从哪个标签开始生成
```

## 如何使用

### 在本地生成更新日志

1. 安装GitHub Changelog Generator：
   ```bash
   gem install github_changelog_generator
   ```

2. 设置GitHub Token (用于API访问)：
   ```bash
   export GITHUB_TOKEN=your_token_here
   ```

3. 生成更新日志：
   ```bash
   # 生成当前版本的更新日志(使用.github_changelog_generator中的future-release)
   make changelog
   
   # 生成特定版本的更新日志
   make changelog NEXT_VERSION=v1.1.0
   ```

### 发布新版本

1. 更新 `.github_changelog_generator` 文件中的 `future-release` 值为新版本号(如v1.1.0)

2. 创建并推送新标签：
   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

3. GitHub Actions将自动生成CHANGELOG.md并创建发布

## 最佳实践

1. **Issue标签**：确保所有Issue和PR使用适当的标签（如bug、enhancement等）
   
2. **Commit消息**：使用[约定式提交](https://www.conventionalcommits.org/zh-hans/v1.0.0/)格式：
   ```
   <类型>[可选的作用域]: <描述>
   ```
   类型包括：feat, fix, docs, style, refactor, perf, test, chore等

3. **版本发布前**：
   - 更新 `.github_changelog_generator` 中的 `future-release` 值
   - 在本地生成CHANGELOG.md预览检查
   - 确保所有Issue已关闭并正确标记 