#!/bin/bash
# Notification hook: permission_prompt 时调用预播报
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PLUGIN_ROOT}/config.env"
STATE_FILE="${PLUGIN_ROOT}/state.yaml"
PREANNOUNCE_SCRIPT="${PLUGIN_ROOT}/scripts/preannounce.sh"

# 未启用则跳过
[ ! -f "/dev/shm/mimo-tts-report-enabled" ] && exit 0

INPUT=$(cat - 2>/dev/null || exit 0)

echo "$INPUT" | python3 -c "
import sys, json, yaml, subprocess

data = json.load(sys.stdin)
notif_type = data.get('notification_type', '')

if notif_type != 'permission_prompt':
    sys.exit(0)

# 读取状态文件
try:
    with open('$STATE_FILE', 'r') as f:
        state = yaml.safe_load(f) or {}
except:
    state = {}

tool = state.get('pending_tool', '')
question = state.get('pending_question', '')
options = state.get('pending_options', [])
message = data.get('message', '')

# 已知消息翻译（仅中文系统）
import os
lang = os.environ.get('LANG', '')
is_chinese = lang.startswith('zh')

TRANSLATIONS = {
    'Claude needs your permission': 'Claude 需要你的授权',
}

# 构建播报内容
if tool == 'AskUserQuestion' and question:
    opts = '、'.join(options) if options else ''
    text = f'{question} 选项：{opts}' if opts else question
elif message:
    text = TRANSLATIONS.get(message, message) if is_chinese else message
else:
    sys.exit(0)

# 调用预播报（延迟30秒）
subprocess.run(['bash', '$PREANNOUNCE_SCRIPT', text], capture_output=True)
" 2>/dev/null &
