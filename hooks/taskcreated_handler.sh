#!/bin/bash
# TaskCreated hook: 记录开始时间戳和任务主题
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
TIMESTAMP_FILE="${PLUGIN_ROOT}/start_time"
STATE_FILE="${PLUGIN_ROOT}/state.yaml"

# 未启用则跳过
[ ! -f "/dev/shm/mimo-tts-report-enabled" ] && exit 0

# 记录当前时间戳
echo $(date +%s) > "$TIMESTAMP_FILE"

# 从 stdin 读取任务信息并保存到 state.yaml
INPUT=$(cat - 2>/dev/null || echo "{}")
echo "$INPUT" | python3 -c "
import sys, json

data = json.load(sys.stdin)
subject = data.get('task_subject', '')

# 更新 state.yaml
lines = []
lines.append('pending_tool: \"\"')
lines.append('pending_input: \"\"')
lines.append('pending_question: \"\"')
lines.append('pending_options: []')
lines.append(f'task_subject: \"{subject}\"')

with open('$STATE_FILE', 'w') as f:
    f.write('\n'.join(lines) + '\n')
" 2>/dev/null
