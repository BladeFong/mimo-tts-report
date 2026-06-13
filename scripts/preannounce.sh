#!/bin/bash
# 预播报脚本
# 用法: preannounce.sh "文字"    — 后台延迟30秒后播报
#       preannounce.sh cancel    — 取消预播报

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER="/dev/shm/tts_preannounce.marker"

# 取消模式
if [ "${1:-}" = "cancel" ]; then
    rm -f "$MARKER"
    exit 0
fi

TEXT="${1:-正在处理，请稍候……}"

# 写标记
echo "$$" > "$MARKER"

# 延迟 30 秒
sleep 30

# 检查标记（可能已被取消）
if [ ! -f "$MARKER" ]; then
    exit 0
fi
rm -f "$MARKER"

# 播报
"$SCRIPT_DIR/tts.sh" "$TEXT" "" "用平静温和的语气"
