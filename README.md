# Shell AI Agent with OpenAI API

基于 Shell 脚本实现的 AI Agent，使用 OpenAI API 调用。

## 特性

- ✅ **Skills 机制**: 从 SKILL.md 文件加载领域知识
- ✅ **工具调用**: bash, read_file, write_file, edit_file
- ✅ **Todo 管理**: 跟踪多步骤任务
- ✅ **OpenAI API**: 使用 gpt-4o 或其他 OpenAI 模型
- ✅ **轻量级**: 纯 Shell 实现，无需 Python

## 依赖

```bash
# Ubuntu/Debian
sudo apt-get install jq curl

# macOS
brew install jq curl
```

## 配置

1. 设置 OpenAI API Key:

```bash
export OPENAI_API_KEY="sk-your-api-key-here"
```

2. (可选) 自定义配置:

```bash
# 使用不同的模型
export MODEL="gpt-4o-mini"

# 使用自定义 API 端点
export OPENAI_BASE_URL="https://your-api-endpoint.com/v1"
```

## 使用方法

```bash
# 赋予执行权限
chmod +x claude_code.sh

# 运行 agent
./claude_code.sh
```

## 示例对话

```
You: 创建一个 hello.py 文件，打印 "Hello World"

[INFO] Tool: write_file
  → Wrote 54 bytes to hello.py...

我已经创建了 hello.py 文件，内容如下：
- 导入必要的模块
- 定义 main 函数打印 "Hello World"
- 使用 if __name__ == "__main__" 执行

You: 运行这个文件

[INFO] Tool: bash
  → Hello World...

成功运行！输出结果是 "Hello World"
```

## Skills 系统

### 创建新技能

1. 在 `skills/` 目录下创建技能文件夹:

```bash
mkdir -p skills/my-skill
```

2. 创建 `SKILL.md` 文件:

```markdown
---
name: my-skill
description: 这个技能的简短描述，用于触发条件
---

# My Skill

## 使用方法

详细的使用说明...

## 示例

\`\`\`bash
example command
\`\`\`

## 注意事项

- 注意点 1
- 注意点 2
```

3. (可选) 添加资源文件:

```
skills/my-skill/
├── SKILL.md
├── scripts/          # 辅助脚本
│   └── helper.sh
├── references/       # 参考文档
│   └── spec.md
└── assets/          # 模板文件
    └── template.txt
```

### 使用技能

Agent 会自动在合适的时机加载技能：

```
You: 帮我处理这个 PDF 文件

[INFO] Tool: Skill
  → Skill loaded (1234 chars)...

[INFO] Tool: bash
  → pdftotext output...
```

## 工具说明

### bash
执行 shell 命令。

```json
{
  "command": "ls -la"
}
```

### read_file
读取文件内容。

```json
{
  "path": "example.txt",
  "limit": 100  // 可选，限制行数
}
```

### write_file
写入文件。

```json
{
  "path": "output.txt",
  "content": "Hello World"
}
```

### edit_file
替换文件中的文本。

```json
{
  "path": "script.py",
  "old_text": "old value",
  "new_text": "new value"
}
```

### Skill
加载技能。

```json
{
  "skill": "pdf"
}
```

### TodoWrite
更新任务列表。

```json
{
  "items": [
    {
      "content": "任务描述",
      "status": "pending",  // pending | in_progress | completed
      "activeForm": "正在做什么"
    }
  ]
}
```

## 安全特性

- ✅ 路径验证：所有文件操作限制在工作目录内
- ✅ 命令过滤：阻止危险命令（rm -rf /, sudo, shutdown）
- ✅ 超时保护：命令执行最多 60 秒
- ✅ 输出限制：工具输出限制在 50KB 以内

## 故障排除

# 检查 API Key 是否设置
echo $OPENAI_API_KEY
echo $OPENAI_BASE_URL

# 测试 API 连接
curl -s $OPENAI_BASE_URL/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY" | jq .

### jq 解析错误

确保 API 返回的是有效 JSON：

```bash
# 启用调试模式
set -x
./claude_code.sh
```

### 技能未加载

检查 SKILL.md 格式：

```bash
# 验证 frontmatter
head -10 skills/pdf/SKILL.md
```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License
