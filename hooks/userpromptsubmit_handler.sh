#!/bin/bash
# UserPromptSubmit hook: 记录当前会话开始时间
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

[ ! -f "/dev/shm/mimo-tts-report-enabled" ] && exit 0

INPUT=$(cat - 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('session_id', ''))" 2>/dev/null || echo "")

bash "${PLUGIN_ROOT}/scripts/preannounce.sh" cancel "$SESSION_ID" 2>/dev/null || true
bash "${PLUGIN_ROOT}/scripts/tts.sh" stop 2>/dev/null || true
bash "${PLUGIN_ROOT}/scripts/report.sh" prepare "$SESSION_ID" 2>/dev/null || true
