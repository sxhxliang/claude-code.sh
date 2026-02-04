#!/usr/bin/env bash
#
# claude_code.sh - Nano Claude Code with Skills (Shell版本)
# 使用 OpenAI API (gpt-4o)
#
# 核心功能:
# - Skills 机制: 从 SKILL.md 加载领域知识
# - Todo 管理: 跟踪多步骤任务
# - 工具调用: bash, read_file, write_file, edit_file

set -euo pipefail

# =============================================================================
# 配置
# =============================================================================

WORKDIR="$(pwd)"
SKILLS_DIR="${WORKDIR}/skills"
HISTORY_FILE="./agent_history.json"
TODO_FILE="./agent_todos.json"
CONTINUE_SESSION=false

# OpenAI 配置
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
MODEL="${MODEL:-gpt-4o}"

# 颜色输出
COLOR_RESET='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'

# 交互式编辑配置 (设为 true 启用编辑器确认)
INTERACTIVE_EDIT="${INTERACTIVE_EDIT:-true}"
# 优先使用的编辑器 (按顺序尝试: $EDITOR, vim, nano, vi)
PREFERRED_EDITOR="${EDITOR:-}"

# =============================================================================
# 工具函数
# =============================================================================

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[✓]${COLOR_RESET} $*" >&2
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# 检测可用的编辑器
detect_editor() {
    if [[ -n "$PREFERRED_EDITOR" ]] && command -v "$PREFERRED_EDITOR" >/dev/null 2>&1; then
        echo "$PREFERRED_EDITOR"
        return
    fi

    for editor in vim nano vi; do
        if command -v "$editor" >/dev/null 2>&1; then
            echo "$editor"
            return
        fi
    done

    echo ""
}

# 在编辑器中打开文件等待用户确认
# 参数: $1 = 文件路径, $2 = 操作描述
open_in_editor() {
    local file="$1"
    local description="${2:-Review file}"

    local editor=$(detect_editor)

    if [[ -z "$editor" ]]; then
        log_warn "未找到可用编辑器，跳过交互式确认"
        return 0
    fi

    # 检查是否有可用的终端
    if [[ ! -t 0 ]] && [[ ! -e /dev/tty ]]; then
        log_warn "无可用终端，跳过交互式确认"
        return 0
    fi

    log_info "=== $description ==="
    log_info "正在打开编辑器: $editor"
    log_info "保存并退出编辑器后继续..."
    echo ""

    # 打开编辑器并等待退出 (强制连接到终端)
    "$editor" "$file" < /dev/tty > /dev/tty 2>&1

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_warn "编辑器退出码: $exit_code"
    fi

    return $exit_code
}

# 检查依赖
check_dependencies() {
    local missing=()
    
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        log_error "请安装: sudo apt-get install ${missing[*]}"
        exit 1
    fi
    
    if [[ -z "$OPENAI_API_KEY" ]]; then
        log_error "请设置 OPENAI_API_KEY 环境变量"
        exit 1
    fi
}

# JSON 转义
json_escape() {
    local input="$1"
    printf '%s' "$input" | jq -Rs .
}

# =============================================================================
# Skills 加载器
# =============================================================================

# 加载所有技能的元数据
load_skills_metadata() {
    local skills_json="[]"
    
    if [[ ! -d "$SKILLS_DIR" ]]; then
        echo "$skills_json"
        return
    fi
    
    for skill_dir in "$SKILLS_DIR"/*/ ; do
        [[ -d "$skill_dir" ]] || continue
        
        local skill_md="${skill_dir}SKILL.md"
        [[ -f "$skill_md" ]] || continue
        
        # 提取 YAML frontmatter
        local frontmatter=$(awk '/^---$/{flag=!flag;next}flag' "$skill_md")
        local name=$(echo "$frontmatter" | grep '^name:' | cut -d: -f2- | xargs)
        local desc=$(echo "$frontmatter" | grep '^description:' | cut -d: -f2- | xargs)
        
        if [[ -n "$name" && -n "$desc" ]]; then
            local skill_obj=$(jq -n \
                --arg name "$name" \
                --arg desc "$desc" \
                --arg path "$skill_md" \
                --arg dir "$skill_dir" \
                '{name: $name, description: $desc, path: $path, dir: $dir}')
            
            skills_json=$(echo "$skills_json" | jq --argjson obj "$skill_obj" '. += [$obj]')
        fi
    done
    
    echo "$skills_json"
}

# 获取技能描述列表
get_skills_descriptions() {
    local skills_json="$1"
    local count=$(echo "$skills_json" | jq 'length')
    
    if [[ $count -eq 0 ]]; then
        echo "(no skills available)"
        return
    fi
    
    echo "$skills_json" | jq -r '.[] | "- \(.name): \(.description)"'
}

# 加载技能内容
load_skill_content() {
    local skill_name="$1"
    local skills_json="$2"
    
    local skill=$(echo "$skills_json" | jq --arg name "$skill_name" '.[] | select(.name == $name)')
    
    if [[ -z "$skill" ]]; then
        local available=$(echo "$skills_json" | jq -r '.[].name' | tr '\n' ', ' | sed 's/,$//')
        echo "Error: Unknown skill '$skill_name'. Available: ${available:-none}"
        return
    fi
    
    local skill_path=$(echo "$skill" | jq -r '.path')
    local skill_dir=$(echo "$skill" | jq -r '.dir')
    
    # 提取 markdown body (frontmatter 之后的内容)
    local body=$(awk '/^---$/{ if(++count==2) flag=1; next } flag' "$skill_path")
    
    # 构建输出
    local output="# Skill: ${skill_name}\n\n${body}"
    
    # 列出可用资源
    local resources=""
    for folder in scripts references assets; do
        local folder_path="${skill_dir}${folder}"
        if [[ -d "$folder_path" ]]; then
            local files=$(ls -1 "$folder_path" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
            if [[ -n "$files" ]]; then
                resources="${resources}\n- ${folder^}: ${files}"
            fi
        fi
    done
    
    if [[ -n "$resources" ]]; then
        output="${output}\n\n**Available resources in ${skill_dir}:**${resources}"
    fi
    
    echo -e "<skill-loaded name=\"${skill_name}\">\n${output}\n</skill-loaded>\n\nFollow the instructions in the skill above to complete the user's task."
}

# =============================================================================
# Todo 管理
# =============================================================================

init_todos() {
    echo '[]' > "$TODO_FILE"
}

update_todos() {
    local items_json="$1"
    
    # 验证并保存
    local validated=$(echo "$items_json" | jq 'map(select(.content and .status and .activeForm)) | .[:20]')
    
    # 检查只有一个 in_progress
    local in_progress_count=$(echo "$validated" | jq '[.[] | select(.status == "in_progress")] | length')
    if [[ $in_progress_count -gt 1 ]]; then
        echo "Error: Only one task can be in_progress"
        return 1
    fi
    
    echo "$validated" > "$TODO_FILE"
    render_todos
}

render_todos() {
    local todos=$(cat "$TODO_FILE")
    local count=$(echo "$todos" | jq 'length')
    
    if [[ $count -eq 0 ]]; then
        echo "No todos."
        return
    fi
    
    local output=""
    while IFS= read -r line; do
        output="${output}${line}\n"
    done < <(echo "$todos" | jq -r '.[] | 
        (if .status == "completed" then "[x]" 
         elif .status == "in_progress" then "[>]" 
         else "[ ]" end) + " " + .content')
    
    local done_count=$(echo "$todos" | jq '[.[] | select(.status == "completed")] | length')
    echo -e "${output}(${done_count}/${count} done)"
}

# =============================================================================
# 工具执行
# =============================================================================

safe_path() {
    local path="$1"
    local abs_path=$(realpath -m "$WORKDIR/$path" 2>/dev/null || echo "$WORKDIR/$path")
    
    # 检查是否在工作目录内
    if [[ ! "$abs_path" == "$WORKDIR"* ]]; then
        echo "Error: Path escapes workspace: $path"
        return 1
    fi
    
    echo "$abs_path"
}

tool_bash() {
    local command="$1"
    
    # 安全检查
    if [[ "$command" =~ (rm[[:space:]]+-rf[[:space:]]+/|sudo|shutdown) ]]; then
        echo "Error: Dangerous command"
        return
    fi
    
    local output
    output=$(cd "$WORKDIR" && timeout 60s bash -c "$command" 2>&1 || echo "Error: Command failed")
    
    # 限制输出长度
    echo "$output" | head -c 50000
    
    [[ -n "$output" ]] || echo "(no output)"
}

tool_read_file() {
    local path="$1"
    local limit="${2:-0}"
    
    local safe_path
    safe_path=$(safe_path "$path") || { echo "$safe_path"; return; }
    
    if [[ ! -f "$safe_path" ]]; then
        echo "Error: File not found: $path"
        return
    fi
    
    local content
    if [[ $limit -gt 0 ]]; then
        content=$(head -n "$limit" "$safe_path")
    else
        content=$(cat "$safe_path")
    fi
    
    echo "$content" | head -c 50000
}

tool_write_file() {
    local path="$1"
    local content="$2"

    local safe_path
    safe_path=$(safe_path "$path") || { echo "$safe_path"; return; }

    mkdir -p "$(dirname "$safe_path")"

    if [[ "$INTERACTIVE_EDIT" == "true" ]]; then
        # 交互式模式：先写入临时文件，让用户确认
        local tmp_file=$(mktemp)
        # 重命名以保留扩展名 (便于编辑器语法高亮)
        local ext="${path##*.}"
        if [[ -n "$ext" && "$ext" != "$path" ]]; then
            mv "$tmp_file" "${tmp_file}.${ext}"
            tmp_file="${tmp_file}.${ext}"
        fi
        echo "$content" > "$tmp_file"

        log_info "AI 准备写入文件: $path"
        log_info "内容预览 (前10行):"
        head -10 "$tmp_file" | sed 's/^/  /' >&2
        echo "  ..." >&2

        open_in_editor "$tmp_file" "确认写入: $path"

        # 用户确认后移动文件
        mv "$tmp_file" "$safe_path"
        local size=$(wc -c < "$safe_path" | tr -d ' ')
        echo "Wrote $size bytes to $path (confirmed)"
    else
        # 非交互式模式：直接写入
        echo "$content" > "$safe_path"
        local size=${#content}
        echo "Wrote $size bytes to $path"
    fi
}

tool_edit_file() {
    local path="$1"
    local old_text="$2"
    local new_text="$3"

    local safe_path
    safe_path=$(safe_path "$path") || { echo "$safe_path"; return; }

    if [[ ! -f "$safe_path" ]]; then
        echo "Error: File not found: $path"
        return
    fi

    local content=$(cat "$safe_path")

    if [[ ! "$content" =~ "$old_text" ]]; then
        echo "Error: Text not found in $path"
        return
    fi

    # 执行替换
    local new_content="${content/$old_text/$new_text}"

    if [[ "$INTERACTIVE_EDIT" == "true" ]]; then
        # 交互式模式：让用户确认替换结果
        local tmp_file=$(mktemp)
        # 重命名以保留扩展名
        local ext="${path##*.}"
        if [[ -n "$ext" && "$ext" != "$path" ]]; then
            mv "$tmp_file" "${tmp_file}.${ext}"
            tmp_file="${tmp_file}.${ext}"
        fi
        echo "$new_content" > "$tmp_file"

        log_info "AI 准备编辑文件: $path"
        log_info "替换: \"$(echo "$old_text" | head -c 50)...\" -> \"$(echo "$new_text" | head -c 50)...\""

        open_in_editor "$tmp_file" "确认编辑: $path"

        # 用户确认后覆盖原文件
        mv "$tmp_file" "$safe_path"
        echo "Edited $path (confirmed)"
    else
        # 非交互式模式：直接替换
        echo "$new_content" > "$safe_path"
        echo "Edited $path"
    fi
}

tool_skill() {
    local skill_name="$1"
    local skills_json="$2"
    
    load_skill_content "$skill_name" "$skills_json"
}

tool_todo_write() {
    local items_json="$1"
    update_todos "$items_json"
}

# =============================================================================
# OpenAI API 调用
# =============================================================================

call_openai_api() {
    local system_prompt="$1"
    local messages_json="$2"
    local tools_json="$3"

    # Build system message and prepend to messages array
    local full_messages
    full_messages=$(printf '%s' "$messages_json" | jq --arg sys "$system_prompt" \
        '[{role: "system", content: $sys}] + .')

    # Use temp files to avoid shell quoting issues
    local tmp_messages=$(mktemp)
    local tmp_tools=$(mktemp)

    printf '%s' "$full_messages" > "$tmp_messages"
    printf '%s' "$tools_json" > "$tmp_tools"

    local request_body
    request_body=$(jq -n \
        --arg model "$MODEL" \
        --slurpfile messages "$tmp_messages" \
        --slurpfile tools "$tmp_tools" \
        -f /dev/stdin <<'JQFILTER'
{model: $model, messages: $messages[0], tools: $tools[0], max_tokens: 4000}
JQFILTER
    )

    rm -f "$tmp_messages" "$tmp_tools"
    
    local response
    response=$(curl -s -X POST "$OPENAI_BASE_URL/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "$request_body")
    
    # 检查错误
    local error=$(echo "$response" | jq -r '.error.message // empty')
    if [[ -n "$error" ]]; then
        log_error "API Error: $error"
        echo "$response"
        return 1
    fi
    
    echo "$response"
}

# =============================================================================
# 工具定义
# =============================================================================

get_tools_definitions() {
    cat <<'EOF'
[
  {
    "type": "function",
    "function": {
      "name": "bash",
      "description": "执行 shell 命令",
      "parameters": {
        "type": "object",
        "properties": {
          "command": {"type": "string", "description": "要执行的 shell 命令"}
        },
        "required": ["command"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "read_file",
      "description": "读取文件内容",
      "parameters": {
        "type": "object",
        "properties": {
          "path": {"type": "string", "description": "文件路径"},
          "limit": {"type": "integer", "description": "限制读取行数(可选)"}
        },
        "required": ["path"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "write_file",
      "description": "写入文件",
      "parameters": {
        "type": "object",
        "properties": {
          "path": {"type": "string", "description": "文件路径"},
          "content": {"type": "string", "description": "文件内容"}
        },
        "required": ["path", "content"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "edit_file",
      "description": "替换文件中的文本",
      "parameters": {
        "type": "object",
        "properties": {
          "path": {"type": "string", "description": "文件路径"},
          "old_text": {"type": "string", "description": "要替换的文本"},
          "new_text": {"type": "string", "description": "新文本"}
        },
        "required": ["path", "old_text", "new_text"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "Skill",
      "description": "加载技能以获取专业知识",
      "parameters": {
        "type": "object",
        "properties": {
          "skill": {"type": "string", "description": "技能名称"}
        },
        "required": ["skill"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "TodoWrite",
      "description": "更新任务列表",
      "parameters": {
        "type": "object",
        "properties": {
          "items": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "content": {"type": "string"},
                "status": {"type": "string", "enum": ["pending", "in_progress", "completed"]},
                "activeForm": {"type": "string"}
              },
              "required": ["content", "status", "activeForm"]
            }
          }
        },
        "required": ["items"]
      }
    }
  }
]
EOF
}

# =============================================================================
# Agent 循环
# =============================================================================

agent_loop() {
    local skills_json="$1"
    local messages_json="$2"
    
    # 构建系统提示
    local skills_desc=$(get_skills_descriptions "$skills_json")
    local system_prompt="You are Claude Code, an interactive CLI tool coding agent at ${WORKDIR}.

Loop: plan -> act with tools -> report.

**Skills available** (invoke with Skill tool when task matches):
${skills_desc}

Rules:
- Use Skill tool IMMEDIATELY when a task matches a skill description
- Use TodoWrite to track multi-step work
- Prefer tools over prose. Act, don't just explain.
- After finishing, summarize what changed."
    
    local tools_json=$(get_tools_definitions)
    local iteration=0
    local max_iterations=20
    
    while [[ $iteration -lt $max_iterations ]]; do
        ((iteration++))
        
        # 调用 API
        local response
        response=$(call_openai_api "$system_prompt" "$messages_json" "$tools_json") || return 1
        
        local finish_reason=$(echo "$response" | jq -r '.choices[0].finish_reason')
        local message=$(echo "$response" | jq '.choices[0].message')
        
        # 提取文本内容
        local content=$(echo "$message" | jq -r '.content // empty')
        if [[ -n "$content" ]]; then
            echo "$content" >&2
        fi
        
        # 检查是否需要调用工具
        local tool_calls=$(echo "$message" | jq '.tool_calls // []')
        local has_tools=$(echo "$tool_calls" | jq 'length > 0')

        if [[ "$has_tools" == "false" || "$finish_reason" != "tool_calls" ]]; then
            # 对话结束 - 添加 assistant 消息
            local assistant_content=$(echo "$message" | jq -r '.content // ""')
            messages_json=$(printf '%s' "$messages_json" | jq --arg content "$assistant_content" \
                '. += [{role: "assistant", content: $content}]')
            break
        fi

        # 执行工具调用
        local tool_results="[]"

        while IFS= read -r tool_call; do
            local tool_id=$(echo "$tool_call" | jq -r '.id')
            local tool_name=$(echo "$tool_call" | jq -r '.function.name')
            local tool_args=$(echo "$tool_call" | jq -r '.function.arguments')

            log_info "Tool: $tool_name"

            local result=""
            case "$tool_name" in
                bash)
                    local cmd=$(echo "$tool_args" | jq -r '.command')
                    result=$(tool_bash "$cmd")
                    ;;
                read_file)
                    local path=$(echo "$tool_args" | jq -r '.path')
                    local limit=$(echo "$tool_args" | jq -r '.limit // 0')
                    result=$(tool_read_file "$path" "$limit")
                    ;;
                write_file)
                    local path=$(echo "$tool_args" | jq -r '.path')
                    local content=$(echo "$tool_args" | jq -r '.content')
                    result=$(tool_write_file "$path" "$content")
                    ;;
                edit_file)
                    local path=$(echo "$tool_args" | jq -r '.path')
                    local old=$(echo "$tool_args" | jq -r '.old_text')
                    local new=$(echo "$tool_args" | jq -r '.new_text')
                    result=$(tool_edit_file "$path" "$old" "$new")
                    ;;
                Skill)
                    local skill=$(echo "$tool_args" | jq -r '.skill')
                    result=$(tool_skill "$skill" "$skills_json")
                    ;;
                TodoWrite)
                    local items=$(echo "$tool_args" | jq '.items')
                    result=$(tool_todo_write "$items")
                    ;;
                *)
                    result="Error: Unknown tool: $tool_name"
                    ;;
            esac

            # 显示结果预览
            local preview=$(echo "$result" | head -c 200)
            echo "  → ${preview}..." >&2

            # 添加到结果列表
            tool_results=$(printf '%s' "$tool_results" | jq \
                --arg id "$tool_id" \
                --arg content "$result" \
                '. += [{tool_call_id: $id, role: "tool", content: $content}]')
        done < <(echo "$tool_calls" | jq -c '.[]')

        # 更新消息历史 - 添加 assistant 消息（带 tool_calls）
        local tmp_msg=$(mktemp)
        printf '%s' "$message" > "$tmp_msg"
        messages_json=$(printf '%s' "$messages_json" | jq --slurpfile msg "$tmp_msg" \
            '. += [{role: "assistant", content: ($msg[0].content // ""), tool_calls: ($msg[0].tool_calls // [])}]')
        rm -f "$tmp_msg"

        # 添加工具结果
        local tmp_results=$(mktemp)
        printf '%s' "$tool_results" > "$tmp_results"
        messages_json=$(printf '%s' "$messages_json" | jq --slurpfile results "$tmp_results" \
            '. + $results[0]')
        rm -f "$tmp_results"

    done
    
    echo "$messages_json"
}

# =============================================================================
# 主 REPL
# =============================================================================

main() {
    check_dependencies
    
    log_info "Nano Claude Code v4 (Shell + OpenAI) - $WORKDIR"
    log_info "Base URL: $OPENAI_BASE_URL"
    log_info "Model: $MODEL"
    
    # 加载技能
    local skills_json
    skills_json=$(load_skills_metadata)
    local skills_count=$(echo "$skills_json" | jq 'length')
    local skills_list=$(echo "$skills_json" | jq -r '.[].name' | tr '\n' ', ' | sed 's/,$//')
    
    log_info "Skills: ${skills_list:-none} ($skills_count loaded)"
    echo ""
    
    # 初始化
    init_todos
    if [[ "$CONTINUE_SESSION" == true && -f "$HISTORY_FILE" ]]; then
        local msg_count=$(jq 'length' "$HISTORY_FILE" 2>/dev/null || echo 0)
        log_info "Continuing session from $HISTORY_FILE ($msg_count messages)"
    else
        echo '[]' > "$HISTORY_FILE"
    fi
    
    while true; do
        echo -ne "${COLOR_GREEN}You:${COLOR_RESET} "
        read -r user_input
        
        [[ -z "$user_input" ]] && continue
        [[ "$user_input" =~ ^(exit|quit|q)$ ]] && break
        
        # 添加用户消息
        local messages=$(cat "$HISTORY_FILE")
        messages=$(printf '%s' "$messages" | jq --arg content "$user_input" '. += [{role: "user", content: $content}]')
        
        echo ""
        log_info "Processing..."
        echo ""
        
        # 运行 agent
        messages=$(agent_loop "$skills_json" "$messages")
        
        # 保存历史
        echo "$messages" > "$HISTORY_FILE"
        
        echo ""
    done
    
    log_success "Goodbye!"
}

# =============================================================================
# 入口
# =============================================================================

show_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -c, --continue [FILE]  继续之前的会话 (默认: $HISTORY_FILE)
  -h, --help             显示帮助信息

Environment Variables:
  INTERACTIVE_EDIT=true|false  是否启用交互式编辑确认 (默认: true)
  EDITOR=vim|nano|...          指定编辑器 (默认: 自动检测)

Examples:
  $(basename "$0")                         # 新会话，启用交互式确认
  $(basename "$0") -c                      # 继续默认会话
  INTERACTIVE_EDIT=false $(basename "$0")  # 禁用交互式确认
  EDITOR=nano $(basename "$0")             # 使用 nano 编辑器
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--continue)
                CONTINUE_SESSION=true
                # 检查下一个参数是否是文件路径（不是另一个选项）
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    HISTORY_FILE="$2"
                    shift
                fi
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi
