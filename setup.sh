#!/usr/bin/env bash
################################################################################
# setup.sh - 快速安装和配置 Shell AI Agent
#
# 使用: ./setup.sh
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║   Shell AI Agent - 安装向导               ║
║   基于 OpenAI API                         ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# =============================================================================
# 1. 检查依赖
# =============================================================================

log_info "步骤 1/5: 检查系统依赖..."

check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 已安装"
        return 0
    else
        log_error "$1 未安装"
        return 1
    fi
}

MISSING_DEPS=0

if ! check_command "curl"; then
    log_warn "请安装 curl: sudo apt-get install curl"
    MISSING_DEPS=1
fi

if ! check_command "jq"; then
    log_warn "请安装 jq"
    echo "  Ubuntu/Debian: sudo apt-get install jq"
    echo "  macOS: brew install jq"
    echo "  或访问: https://stedolan.github.io/jq/download/"
    MISSING_DEPS=1
fi

if [[ $MISSING_DEPS -eq 1 ]]; then
    log_error "请先安装缺失的依赖，然后重新运行此脚本"
    exit 1
fi

# =============================================================================
# 2. 创建目录结构
# =============================================================================

log_info "步骤 2/5: 创建目录结构..."

mkdir -p skills/pdf
mkdir -p skills/git
mkdir -p skills/code-review

log_success "目录结构创建完成"

# =============================================================================
# 3. 设置可执行权限
# =============================================================================

log_info "步骤 3/5: 设置脚本权限..."

if [[ -f "claude_code.sh" ]]; then
    chmod +x claude_code.sh
    log_success "claude_code.sh 已设置为可执行"
else
    log_warn "claude_code.sh 未找到，跳过"
fi

# =============================================================================
# 4. 配置 API 密钥
# =============================================================================

log_info "步骤 4/5: 配置 API 密钥..."

if [[ -f ".env" ]]; then
    log_warn ".env 文件已存在，跳过配置"
    source .env
else
    if [[ -f ".env.example" ]]; then
        cp .env.example .env
        log_success "已创建 .env 文件"
    else
        cat > .env << 'EOF'
OPENAI_API_KEY=
OPENAI_BASE_URL=https://api.openai.com/v1
MODEL=gpt-4o
EOF
        log_success "已创建默认 .env 文件"
    fi

    echo ""
    log_info "请编辑 .env 文件并填入你的 OpenAI API 密钥"
    log_info "获取密钥: https://platform.openai.com/api-keys"
    echo ""

    read -p "是否现在输入 API 密钥? (y/N): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "请输入 OpenAI API 密钥: " api_key
        sed -i.bak "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$api_key|" .env
        rm -f .env.bak
        log_success "API 密钥已保存到 .env"
        source .env
    fi
fi

# =============================================================================
# 5. 验证配置
# =============================================================================

log_info "步骤 5/5: 验证配置..."

if [[ -z "$OPENAI_API_KEY" ]]; then
    log_warn "API 密钥未设置"
    log_warn "请编辑 .env 文件并设置 OPENAI_API_KEY"
else
    log_success "API 密钥已配置"

    # 测试 API 连接
    log_info "测试 API 连接..."
    log_info "使用模型: ${MODEL:-gpt-4o}"

    TEST_RESPONSE=$(curl -s -w "\n%{http_code}" \
        "${OPENAI_BASE_URL:-https://api.openai.com/v1}/chat/completions" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${MODEL:-gpt-4o}\",
            \"max_tokens\": 10,
            \"messages\": [{\"role\": \"user\", \"content\": \"Hi\"}]
        }" 2>&1)

    HTTP_CODE=$(echo "$TEST_RESPONSE" | tail -n1)

    if [[ "$HTTP_CODE" == "200" ]]; then
        log_success "API 连接测试成功！"
    else
        log_error "API 连接测试失败 (HTTP $HTTP_CODE)"
        log_warn "请检查你的 API 密钥是否正确"
    fi
fi

# =============================================================================
# 安装完成
# =============================================================================

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║   安装完成！                              ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

log_info "下一步操作:"
echo "  1. 确保 .env 文件中的 API 密钥已正确设置"
echo "  2. 运行 agent: ./claude_code.sh"
echo "  3. 阅读文档: cat README.md"
echo ""

log_info "示例命令:"
echo "  You: list all files in the current directory"
echo "  You: create a file hello.txt with 'Hello World'"
echo "  You: load the pdf skill and show me how to extract text"
echo ""

log_info "Skills 目录:"
echo "  skills/pdf/           - PDF 处理"
echo "  skills/git/           - Git 操作（需要创建 SKILL.md）"
echo "  skills/code-review/   - 代码审查（需要创建 SKILL.md）"
echo ""

# 询问是否立即运行
read -p "是否立即启动 Agent? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -f "claude_code.sh" ]]; then
        source .env
        exec ./claude_code.sh
    else
        log_error "claude_code.sh 未找到"
        exit 1
    fi
fi

log_success "设置完成！"
