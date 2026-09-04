#!/bin/bash
# 预播报脚本
# 用法: preannounce.sh "文字" [延迟秒数] — 后台延迟播报
#       preannounce.sh cancel           — 取消预播报

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER="/dev/shm/tts_preannounce.marker"

cancel_preannounce() {
    if [ -f "$MARKER" ]; then
        local pid
        pid=$(cat "$MARKER" 2>/dev/null || true)
        rm -f "$MARKER" 2>/dev/null || true
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            pkill -P "$pid" 2>/dev/null || true
            kill "$pid" 2>/dev/null || true
        fi
    fi
}

# 取消模式
if [ "${1:-}" = "cancel" ]; then
    cancel_preannounce
    exit 0
fi

TEXT="${1:-正在处理，请稍候……}"
DELAY="${2:-30}"

# 先取消上一次可能存在的预播报
cancel_preannounce

# 后台延时子进程，脱离当前管道并记录 PID
(
    sleep "$DELAY"
    if [ -f "$MARKER" ]; then
        rm -f "$MARKER" 2>/dev/null || true
        "$SCRIPT_DIR/tts.sh" "$TEXT" "" "用平静温和的语气"
    fi
) </dev/null >/dev/null 2>&1 &

echo $! > "$MARKER"
