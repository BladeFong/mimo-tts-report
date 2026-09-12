#!/bin/bash
# PostToolUse hook: 取消预播报，清空 pending 状态（单会话内存隔离）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PREANNOUNCE_SCRIPT="${PLUGIN_ROOT}/scripts/preannounce.sh"

# 未启用则跳过
[ ! -f "/dev/shm/mimo-tts-report-enabled" ] && exit 0

INPUT=$(cat - 2>/dev/null || exit 0)
[ -z "$INPUT" ] && exit 0

SESSION_ID=$(echo "$INPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('session_id', ''))" 2>/dev/null || echo "")
SESSION_DIR=$("$PLUGIN_ROOT/scripts/session_helper.sh" get_dir "$SESSION_ID")
STATE_FILE="${SESSION_DIR}/state.yaml"

# 取消当前会话预播报
bash "$PREANNOUNCE_SCRIPT" cancel "$SESSION_ID" 2>/dev/null || true

# 清空 pending 状态，保留 task_subject
python3 -c "
import yaml

try:
    with open('$STATE_FILE', 'r') as f:
        data = yaml.safe_load(f) or {}
except:
    data = {}

task_subject = data.get('task_subject', '')

lines = []
lines.append('pending_tool: \"\"')
lines.append('pending_input: \"\"')
lines.append('pending_question: \"\"')
lines.append('pending_options: []')
lines.append(f'task_subject: \"{task_subject}\"')

with open('$STATE_FILE', 'w') as f:
    f.write('\n'.join(lines) + '\n')
" 2>/dev/null || true
