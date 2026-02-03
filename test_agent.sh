#!/usr/bin/env bash
#
# test_agent.sh - 测试 AI Agent 的基本功能
#

set -e

echo "=== AI Agent 功能测试 ==="
echo ""

# 检查环境
if [[ -z "$OPENAI_API_KEY" ]]; then
    echo "❌ 错误: 请设置 OPENAI_API_KEY 环境变量"
    echo "   export OPENAI_API_KEY='sk-your-key'"
    exit 1
fi

echo "✅ OpenAI API Key: ${OPENAI_API_KEY:0:10}..."
echo ""

# 测试 jq
if ! command -v jq &> /dev/null; then
    echo "❌ 错误: 未安装 jq"
    echo "   sudo apt-get install jq"
    exit 1
fi
echo "✅ jq 已安装: $(jq --version)"

# 测试 curl
if ! command -v curl &> /dev/null; then
    echo "❌ 错误: 未安装 curl"
    exit 1
fi
echo "✅ curl 已安装: $(curl --version | head -1)"
echo ""

# 测试 API 连接
echo "📡 测试 OpenAI API 连接..."
if curl -s -f $OPENAI_BASE_URL/models \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" > /dev/null; then
    echo "✅ API 连接成功"
else
    echo "❌ API 连接失败，请检查网络或 API Key"
    exit 1
fi
echo ""

# 检查技能文件
echo "📚 检查技能系统..."
if [[ -d "skills" ]]; then
    skill_count=$(find skills -name "SKILL.md" | wc -l)
    echo "✅ 找到 $skill_count 个技能"
    find skills -name "SKILL.md" | while read -r skill; do
        name=$(grep "^name:" "$skill" | cut -d: -f2 | xargs)
        echo "   - $name"
    done
else
    echo "⚠️  警告: skills 目录不存在"
fi
echo ""

# 创建测试文件
echo "📝 创建测试文件..."
echo "Hello from test script" > test_input.txt
echo "✅ 测试文件创建成功"
echo ""

echo "=== 所有检查通过! ==="
echo ""
echo "运行 agent:"
echo "  ./claude_code.sh"
echo ""
echo "或者测试单个命令:"
echo '  echo "创建一个 hello.py 文件" | ./claude_code.sh'
