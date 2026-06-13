#!/bin/bash
# UserPromptSubmit hook: 记录开始时间戳
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
REPORT_SCRIPT="${PLUGIN_ROOT}/scripts/report.sh"

# 未启用则跳过
[ ! -f "/dev/shm/mimo-tts-report-enabled" ] && exit 0

# 记录时间戳
bash "$REPORT_SCRIPT" prepare
