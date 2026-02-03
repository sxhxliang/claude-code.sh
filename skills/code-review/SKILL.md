---
name: code-review
description: 代码审查，检查代码质量、安全问题、最佳实践和改进建议
---

# 代码审查技能

## 功能概述

此技能用于执行代码审查：

- 代码质量检查
- 安全漏洞识别
- 最佳实践建议
- 性能优化建议
- 可读性和维护性评估

## 审查清单

### 1. 代码正确性
- [ ] 逻辑是否正确
- [ ] 边界条件是否处理
- [ ] 错误处理是否完善
- [ ] 是否有潜在的空指针/未定义

### 2. 安全性
- [ ] 输入验证和清理
- [ ] SQL 注入防护
- [ ] XSS 防护
- [ ] 敏感数据处理
- [ ] 权限检查

### 3. 性能
- [ ] 避免不必要的循环
- [ ] 数据库查询优化
- [ ] 内存使用合理
- [ ] 避免重复计算

### 4. 可读性
- [ ] 命名清晰有意义
- [ ] 函数长度适中
- [ ] 注释必要且准确
- [ ] 代码结构清晰

### 5. 最佳实践
- [ ] 遵循语言规范
- [ ] DRY 原则
- [ ] 单一职责原则
- [ ] 适当的抽象层次

## 审查流程

### 步骤 1: 了解上下文
```bash
# 查看变更文件
git diff --name-only HEAD~1

# 查看具体变更
git diff HEAD~1

# 查看提交信息
git log -1
```

### 步骤 2: 阅读代码
使用 `read_file` 工具读取相关文件，理解：
- 变更的目的
- 影响的范围
- 依赖关系

### 步骤 3: 检查问题
按审查清单逐项检查，记录发现的问题。

### 步骤 4: 提供反馈
输出格式：

```markdown
## 代码审查报告

### 概述
[变更摘要和总体评价]

### 问题 (需要修复)
1. **[严重程度]** 文件:行号 - 问题描述
   - 建议: 修复方案

### 建议 (可选改进)
1. 文件:行号 - 改进建议

### 亮点
- 做得好的地方

### 结论
[APPROVE / REQUEST_CHANGES / COMMENT]
```

## 常见问题模式

### JavaScript/TypeScript
```javascript
// 问题: 未处理 Promise 错误
fetchData().then(data => process(data))

// 建议:
fetchData()
  .then(data => process(data))
  .catch(err => handleError(err))
```

### Python
```python
# 问题: 可变默认参数
def add_item(item, items=[]):
    items.append(item)
    return items

# 建议:
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items
```

### Shell
```bash
# 问题: 未引用变量
rm -rf $DIR/*

# 建议:
rm -rf "${DIR:?}"/*
```

## 严重程度定义

- **Critical**: 安全漏洞、数据丢失风险
- **Major**: 功能错误、性能严重问题
- **Minor**: 代码风格、小优化
- **Info**: 建议、最佳实践

## 注意事项

- 保持客观和建设性
- 解释问题原因，不只是指出问题
- 提供具体的改进建议
- 区分必须修复和可选改进
