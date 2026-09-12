#!/bin/bash
# Chat 模式管理脚本（单会话内存隔离）
# 用法: chat_manager.sh status [SESSION_ID]  — 返回当前会话状态（开启/关闭）
#       chat_manager.sh toggle [SESSION_ID]  — 切换当前会话模式

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTION="${1:-status}"
SESSION_ID="${2:-}"

SESSION_DIR=$("$SCRIPT_DIR/session_helper.sh" get_dir "$SESSION_ID")
CHAT_FILE="${SESSION_DIR}/chat_mode"

case "$ACTION" in
    status)
        [ -f "$CHAT_FILE" ] && echo "开启" || echo "关闭"
        ;;
    toggle)
        if [ -f "$CHAT_FILE" ]; then
            rm -f "$CHAT_FILE"
            echo "关闭"
        else
            touch "$CHAT_FILE"
            echo "开启"
        fi
        ;;
esac
