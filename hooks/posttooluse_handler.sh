#!/bin/bash
# PostToolUse hook: 取消预播报，清空 pending 状态
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
STATE_FILE="${PLUGIN_ROOT}/state.yaml"
PREANNOUNCE_SCRIPT="${PLUGIN_ROOT}/scripts/preannounce.sh"

# 未启用则跳过
[ ! -f "/dev/shm/mimo-tts-report-enabled" ] && exit 0

# 取消预播报
bash "$PREANNOUNCE_SCRIPT" cancel 2>/dev/null

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
" 2>/dev/null
