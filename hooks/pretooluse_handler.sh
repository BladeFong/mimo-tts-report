#!/bin/bash
# PreToolUse hook: 记录工具信息到状态文件
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
STATE_FILE="${PLUGIN_ROOT}/state.yaml"

# 未启用则跳过
[ ! -f "/dev/shm/mimo-tts-report-enabled" ] && exit 0

INPUT=$(cat - 2>/dev/null || exit 0)

echo "$INPUT" | python3 -c "
import sys, json, yaml

data = json.load(sys.stdin)
tool_name = data.get('tool_name', '')
tool_input = data.get('tool_input', {})

# 读取现有的 task_subject
task_subject = ''
try:
    with open('$STATE_FILE', 'r') as f:
        existing = yaml.safe_load(f) or {}
    task_subject = existing.get('task_subject', '')
except:
    pass

# 写入状态文件
lines = []
lines.append(f'pending_tool: \"{tool_name}\"')

if tool_name == 'AskUserQuestion':
    questions = tool_input.get('questions', [])
    if questions:
        q = questions[0]
        lines.append(f'pending_question: \"{q.get(\"question\", \"\")}\"')
        options = [opt.get('label', '') for opt in q.get('options', [])]
        lines.append(f'pending_options: {json.dumps(options, ensure_ascii=False)}')
else:
    cmd = tool_input.get('command', '')
    if cmd:
        lines.append(f'pending_input: \"{cmd[:200]}\"')

lines.append(f'task_subject: \"{task_subject}\"')

with open('$STATE_FILE', 'w') as f:
    f.write('\n'.join(lines) + '\n')
" 2>/dev/null
