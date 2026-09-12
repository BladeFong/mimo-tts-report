#!/bin/bash
# TaskCreated hook: 记录开始时间戳和任务主题（单会话内存隔离）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# 未启用则跳过
[ ! -f "/dev/shm/mimo-tts-report-enabled" ] && exit 0

INPUT=$(cat - 2>/dev/null || echo "{}")
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('session_id', ''))" 2>/dev/null || echo "")

SESSION_DIR=$("$PLUGIN_ROOT/scripts/session_helper.sh" get_dir "$SESSION_ID")
echo $(date +%s) > "${SESSION_DIR}/start_time"

echo "$INPUT" | python3 -c "
import sys, json

data = json.load(sys.stdin)
subject = data.get('task_subject', '')
if subject:
    with open('${SESSION_DIR}/task_subject', 'w') as f:
        f.write(subject)
" 2>/dev/null || true
