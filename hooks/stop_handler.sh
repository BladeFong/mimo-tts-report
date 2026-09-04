#!/bin/bash
# Stop hook: 从 stdin 读 last_assistant_message，调 report.sh speak 播报
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# 未启用则跳过
[ ! -f "/dev/shm/mimo-tts-report-enabled" ] && exit 0

# 取消可能悬挂的预播报
bash "$PLUGIN_ROOT/scripts/preannounce.sh" cancel 2>/dev/null

export PLUGIN_ROOT
cat - | python3 "$PLUGIN_ROOT/scripts/stop_processor.py" 2>/dev/null &
