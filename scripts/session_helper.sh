#!/bin/bash
# 会话辅助工具：推导并返回当前会话专属的 /dev/shm 内存目录
set -euo pipefail

BASE_SESSIONS_DIR="/dev/shm/mimo-tts-sessions"

resolve_session_id() {
    local explicit_id="${1:-}"
    if [ -n "$explicit_id" ]; then
        echo "$explicit_id"
        return 0
    fi

    # 环境变量（兼容 Antigravity、Claude Code、Codex 及通用环境）
    local env_id="${ANTIGRAVITY_CONVERSATION_ID:-${CLAUDE_SESSION_ID:-${CLAUDE_CONVERSATION_ID:-${CONVERSATION_ID:-}}}}"
    if [ -n "$env_id" ]; then
        echo "$env_id"
        return 0
    fi

    # TTY 设备标识
    local tty_str
    tty_str=$(tty 2>/dev/null || true)
    if [ -n "$tty_str" ] && [ "$tty_str" != "not a tty" ]; then
        echo "tty_${tty_str//\//_}"
        return 0
    fi

    # 进程组 fallback
    echo "pgrp_$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ' || echo 'default')"
}

get_session_dir() {
    local sid
    sid=$(resolve_session_id "${1:-}")
    # 清理非法字符
    sid=$(echo "$sid" | tr -cd 'a-zA-Z0-9_-')
    [ -z "$sid" ] && sid="default"

    local dir="${BASE_SESSIONS_DIR}/${sid}"
    mkdir -p "$dir"
    echo "$dir"
}

case "${1:-}" in
    get_dir)
        get_session_dir "${2:-}"
        ;;
    get_id)
        resolve_session_id "${2:-}"
        ;;
    *)
        get_session_dir "${1:-}"
        ;;
esac
