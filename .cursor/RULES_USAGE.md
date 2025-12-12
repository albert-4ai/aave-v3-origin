# Cursor Rules 使用指南

## 📋 概述

本文档说明如何在 Cursor IDE 中让项目规则（Rules）生效。

## 🎯 Rules 文件位置

Cursor 支持两种方式配置项目规则：

### 方式 1: `.cursorrules` 文件（推荐，向后兼容）✅

**位置**: 项目根目录下的 `.cursorrules` 文件

**优点**:
- 简单直接，一个文件包含所有规则
- 向后兼容旧版本 Cursor
- 易于版本控制和分享

**当前状态**: ✅ 已创建在项目根目录

### 方式 2: `.cursor/rules/` 目录（新方式）

**位置**: `.cursor/rules/` 目录下的规则文件

**优点**:
- 可以创建多个规则文件，按模块组织
- 支持更精细的控制（通过 globs 匹配特定文件）
- 支持 frontmatter 配置

**当前状态**: ✅ 已存在 `.cursor/rules/rules` 文件

## ✅ 如何验证 Rules 是否生效

### 方法 1: 检查 Cursor 设置

1. 打开 Cursor
2. 按 `Ctrl+,` (Windows/Linux) 或 `Cmd+,` (Mac) 打开设置
3. 搜索 "rules" 或 "AI rules"
4. 查看是否显示项目规则已加载

### 方法 2: 测试 AI 助手

1. 在 Cursor 中打开一个 Solidity 文件
2. 使用 `Ctrl+L` (Windows/Linux) 或 `Cmd+L` (Mac) 打开 AI 聊天
3. 询问 AI 关于项目规范的问题，例如：
   - "这个项目的 Solidity 代码风格是什么？"
   - "如何编写符合项目规范的函数？"
4. 如果 AI 的回答符合 `.cursorrules` 文件中的规范，说明 rules 已生效

### 方法 3: 使用 @rules 引用

在 AI 聊天中，可以使用 `@rules` 来引用规则文件：

```
@rules 请帮我检查这段代码是否符合项目规范
```

## 🔧 如何让 Rules 生效

### 步骤 1: 确保文件存在

检查以下文件是否存在：
- ✅ `.cursorrules` (项目根目录)
- ✅ `.cursor/rules/rules` (已存在)

### 步骤 2: 重启 Cursor

有时需要重启 Cursor 才能加载新的规则文件：
1. 完全关闭 Cursor
2. 重新打开项目
3. 规则应该会自动加载

### 步骤 3: 检查文件格式

确保 `.cursorrules` 文件：
- ✅ 使用 UTF-8 编码
- ✅ 使用 Markdown 格式
- ✅ 文件没有语法错误

### 步骤 4: 验证规则加载

在 Cursor 中：
1. 打开命令面板 (`Ctrl+Shift+P` 或 `Cmd+Shift+P`)
2. 输入 "Cursor: Reload Rules" (如果有此命令)
3. 或者重启 Cursor

## 📝 规则文件优先级

如果同时存在多个规则文件，优先级如下：

1. **`.cursor/rules/` 目录中的规则** (如果支持)
2. **`.cursorrules` 文件** (项目根目录)
3. **全局规则** (Cursor 设置中的全局规则)

**建议**: 使用 `.cursorrules` 文件，因为它最简单且兼容性最好。

## 🚀 快速开始

### 1. 使用现有的 Rules

当前项目已经配置好规则文件：
- `.cursorrules` - 项目根目录（推荐使用）
- `.cursor/rules/rules` - 规则目录

### 2. 测试 Rules 是否生效

打开任意 Solidity 文件，使用 AI 助手：
```
请帮我写一个符合项目规范的 supply 函数
```

AI 应该会：
- 使用项目的命名约定
- 遵循安全最佳实践
- 添加适当的注释和事件
- 考虑 Gas 优化

### 3. 更新 Rules

如果需要更新规则：
1. 编辑 `.cursorrules` 文件
2. 保存文件
3. 重启 Cursor（或等待自动重新加载）

## 💡 常见问题

### Q: Rules 文件修改后没有生效？

**A**: 尝试以下方法：
1. 重启 Cursor
2. 检查文件格式是否正确
3. 确保文件在正确的位置（项目根目录）
4. 检查文件编码是否为 UTF-8

### Q: 如何知道 Rules 是否被加载？

**A**: 
1. 在 AI 聊天中询问项目规范
2. 如果 AI 的回答符合规则文件内容，说明已加载
3. 使用 `@rules` 引用规则文件

### Q: 可以同时使用多个规则文件吗？

**A**: 
- `.cursorrules` 文件：一个文件包含所有规则（推荐）
- `.cursor/rules/` 目录：可以创建多个文件，但需要正确配置 frontmatter

### Q: Rules 文件太大怎么办？

**A**: 
- 可以拆分成多个文件放在 `.cursor/rules/` 目录
- 或者保持一个文件，使用清晰的章节组织

## 📚 参考资源

- [Cursor 官方文档](https://cursor.sh/docs)
- [Cursor Rules 最佳实践](https://cursor.sh/docs/rules)

## ✨ 当前配置状态

- ✅ `.cursorrules` 文件已创建（项目根目录）
- ✅ `.cursor/rules/rules` 文件已存在
- ✅ 规则内容完整，包含项目规范、安全实践、测试要求等

**下一步**: 重启 Cursor，然后测试 AI 助手是否遵循这些规则。

