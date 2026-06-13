#!/bin/bash
# TTS 工作流
# 用法: report.sh prepare              — 记录开始时间
#       report.sh cleanup              — 清理时间戳和任务标题
#       report.sh sample VOICE          — 播放示例（调 tts.sh）
#       report.sh speak "文字"           — 检查耗时后播报（调 tts.sh）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
TIMESTAMP_FILE="${PLUGIN_ROOT}/start_time"
STATE_FILE="${PLUGIN_ROOT}/state.yaml"

[ -f "$PLUGIN_ROOT/config.env" ] && source "$PLUGIN_ROOT/config.env"

ACTION="${1:-}"

case "$ACTION" in
    prepare)
        echo $(date +%s) > "$TIMESTAMP_FILE"
        ;;
    cleanup)
        rm -f "$TIMESTAMP_FILE"
        python3 -c "
import yaml
try:
    with open('$STATE_FILE', 'r') as f:
        data = yaml.safe_load(f) or {}
except:
    data = {}
data['task_subject'] = ''
with open('$STATE_FILE', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
" 2>/dev/null || true
        ;;
    sample)
        VOICE="${2:-茉莉}"
        "$SCRIPT_DIR/tts.sh" "这是${VOICE}音色的测试" "$VOICE" "用平静温和的语气"
        ;;
    speak)
        TEXT="${2:-}"
        [ -z "$TEXT" ] && exit 0
        # 没有时间戳不播报
        if [ ! -f "$TIMESTAMP_FILE" ]; then
            exit 0
        fi
        START_TIME=$(cat "$TIMESTAMP_FILE")
        NOW=$(date +%s)
        ELAPSED=$((NOW - START_TIME))
        # 交流模式跳过时间检查
        if [ ! -f "/dev/shm/mimo-tts-chat-mode" ] && [ "$ELAPSED" -lt 180 ]; then
            "$SCRIPT_DIR/report.sh" cleanup
            exit 0
        fi
        # 读取 task_subject 作为前缀
        TASK_SUBJECT=""
        if [ -f "$STATE_FILE" ]; then
            TASK_SUBJECT=$(python3 -c "
import yaml
with open('$STATE_FILE') as f:
    data = yaml.safe_load(f) or {}
print(data.get('task_subject', ''))
" 2>/dev/null || echo "")
        fi
        # 组合播报内容
        if [ -n "$TASK_SUBJECT" ]; then
            BROADCAST_TEXT="${TASK_SUBJECT}完成。${TEXT}"
        else
            BROADCAST_TEXT="$TEXT"
        fi
        # 播报（稍快但不急促的语速）
        "$SCRIPT_DIR/tts.sh" "$BROADCAST_TEXT" "" "用稍快但不急促的语气简要汇报"
        # 播报完清理
        "$SCRIPT_DIR/report.sh" cleanup
        ;;
esac
