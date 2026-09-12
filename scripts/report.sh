#!/bin/bash
# TTS 工作流（单会话内存隔离）
# 用法: report.sh prepare [SESSION_ID]               — 记录当前会话开始时间
#       report.sh cleanup [SESSION_ID]               — 清理当前会话时间戳与标题
#       report.sh sample VOICE                       — 播放示例
#       report.sh speak "文字" [SESSION_ID]          — 检查耗时后播报

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

[ -f "$PLUGIN_ROOT/config.env" ] && source "$PLUGIN_ROOT/config.env"

ACTION="${1:-}"

case "$ACTION" in
    prepare)
        SESSION_ID="${2:-}"
        SESSION_DIR=$("$SCRIPT_DIR/session_helper.sh" get_dir "$SESSION_ID")
        echo $(date +%s) > "${SESSION_DIR}/start_time"
        ;;
    cleanup)
        SESSION_ID="${2:-}"
        SESSION_DIR=$("$SCRIPT_DIR/session_helper.sh" get_dir "$SESSION_ID")
        rm -f "${SESSION_DIR}/start_time" "${SESSION_DIR}/task_subject"
        ;;
    sample)
        VOICE="${2:-云希}"
        "$SCRIPT_DIR/tts.sh" "这是${VOICE}音色的测试" "$VOICE" "用平静温和的语气"
        ;;
    speak)
        TEXT="${2:-}"
        SESSION_ID="${3:-}"
        [ -z "$TEXT" ] && exit 0

        SESSION_DIR=$("$SCRIPT_DIR/session_helper.sh" get_dir "$SESSION_ID")
        TIMESTAMP_FILE="${SESSION_DIR}/start_time"
        SUBJECT_FILE="${SESSION_DIR}/task_subject"

        # 没有时间戳不播报
        if [ ! -f "$TIMESTAMP_FILE" ]; then
            exit 0
        fi

        START_TIME=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo $(date +%s))
        NOW=$(date +%s)
        ELAPSED=$((NOW - START_TIME))

        # 检查当前会话的交流模式
        CHAT_STATUS=$("$SCRIPT_DIR/chat_manager.sh" status "$SESSION_ID")
        if [ "$CHAT_STATUS" != "开启" ] && [ "$ELAPSED" -lt 180 ]; then
            "$SCRIPT_DIR/report.sh" cleanup "$SESSION_ID"
            exit 0
        fi

        # 读取当前会话的 task_subject
        TASK_SUBJECT=""
        if [ -f "$SUBJECT_FILE" ]; then
            TASK_SUBJECT=$(cat "$SUBJECT_FILE" 2>/dev/null || echo "")
        fi

        # 组合播报内容
        if [ -n "$TASK_SUBJECT" ]; then
            BROADCAST_TEXT="${TASK_SUBJECT}完成。${TEXT}"
        else
            BROADCAST_TEXT="$TEXT"
        fi

        # 触发底层播放
        "$SCRIPT_DIR/tts.sh" "$BROADCAST_TEXT" "" "用稍快但不急促的语气简要汇报"
        # 播报完清理当前会话标记
        "$SCRIPT_DIR/report.sh" cleanup "$SESSION_ID"
        ;;
esac
