#!/bin/bash
# 预播报脚本（单会话内存隔离）
# 用法: preannounce.sh "文字" [延迟秒数] [SESSION_ID] — 后台延迟播报
#       preannounce.sh cancel [SESSION_ID]          — 取消当前会话预播报

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "${1:-}" = "cancel" ]; then
    SESSION_ID="${2:-}"
    SESSION_DIR=$("$SCRIPT_DIR/session_helper.sh" get_dir "$SESSION_ID")
    MARKER="${SESSION_DIR}/preannounce.marker"
    if [ -f "$MARKER" ]; then
        pid=$(cat "$MARKER" 2>/dev/null || true)
        rm -f "$MARKER" 2>/dev/null || true
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            pkill -P "$pid" 2>/dev/null || true
            kill "$pid" 2>/dev/null || true
        fi
    fi
    exit 0
fi

TEXT="${1:-正在处理，请稍候……}"
DELAY="${2:-30}"
SESSION_ID="${3:-}"

SESSION_DIR=$("$SCRIPT_DIR/session_helper.sh" get_dir "$SESSION_ID")
MARKER="${SESSION_DIR}/preannounce.marker"

# 先取消当前会话上一次可能存在的预播报
if [ -f "$MARKER" ]; then
    old_pid=$(cat "$MARKER" 2>/dev/null || true)
    rm -f "$MARKER" 2>/dev/null || true
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        pkill -P "$old_pid" 2>/dev/null || true
        kill "$old_pid" 2>/dev/null || true
    fi
fi

(
    sleep "$DELAY"
    if [ -f "$MARKER" ]; then
        rm -f "$MARKER" 2>/dev/null || true
        "$SCRIPT_DIR/tts.sh" "$TEXT" "" "用平静温和的语气"
    fi
) </dev/null >/dev/null 2>&1 &

echo $! > "$MARKER"
