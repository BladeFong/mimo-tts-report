#!/bin/bash
# 配置脚本
# 用法: setup.sh enable                — 检查配置状态 + 空跑授权
#       setup.sh init KEY               — 播放音色样本（调 tts.sh）
#       setup.sh save KEY VOICE [STYLE] — 保存配置

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SKILL_DIR/config.env"

ACTION="${1:-}"

case "$ACTION" in
    enable)
        # 设置所有脚本执行权限
        chmod +x "$SCRIPT_DIR"/*.sh
        chmod +x "$SKILL_DIR/hooks"/*.sh 2>/dev/null || true
        [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
        ENGINE="${TTS_ENGINE:-edge}"
        if [ "$ENGINE" = "edge" ] || [ -n "${TTS_API_KEY:-}" ]; then
            # 写入启用标记（内存）
            touch "/dev/shm/mimo-tts-report-enabled"
            echo "READY=true"
            echo "ENGINE=$ENGINE"
            echo "VOICE=${TTS_VOICE:-云希}"
        else
            echo "NEED_INIT=true"
        fi
        ;;
    init)
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE"
            ENGINE="${TTS_ENGINE:-edge}"
            if [ "$ENGINE" = "edge" ] || [ -n "${TTS_API_KEY:-}" ]; then
                echo "ALREADY_CONFIGURED=true"
                echo "ENGINE=$ENGINE"
                echo "VOICE=${TTS_VOICE:-云希}"
                exit 0
            fi
        fi
        ARG2="${2:-}"
        if [ "$ARG2" = "edge" ] || [ -z "$ARG2" ]; then
            export TTS_ENGINE="edge"
        else
            export TTS_API_KEY="$ARG2"
            export TTS_ENGINE="${3:-mimo}"
        fi
        # 从 tts.sh 获取音色列表
        VOICES_STR=$("$SCRIPT_DIR/tts.sh" voices)
        read -ra VOICES <<< "$VOICES_STR"
        for VOICE in "${VOICES[@]}"; do
            "$SCRIPT_DIR/tts.sh" "这是${VOICE}音色的测试" "$VOICE" "用平静温和的语气"
        done
        echo "SAMPLES_PLAYED=true"
        echo "VOICES=$VOICES_STR"
        ;;
    save)
        ARG2="${2:-}"
        ARG3="${3:-}"
        ARG4="${4:-}"
        ARG5="${5:-}"

        if [ "$ARG2" = "edge" ]; then
            ENGINE="edge"
            API_KEY=""
            VOICE="${ARG3:-云希}"
            STYLE="${ARG4:-用平静温和的语气简要汇报}"
        elif [ "$ARG2" = "mimo" ]; then
            ENGINE="mimo"
            API_KEY="$ARG3"
            VOICE="${ARG4:-茉莉}"
            STYLE="${ARG5:-用平静温和的语气简要汇报}"
        else
            API_KEY="$ARG2"
            VOICE="${ARG3:-茉莉}"
            STYLE="${ARG4:-用平静温和的语气简要汇报}"
            ENGINE="${ARG5:-}"
            if [ -z "$ENGINE" ]; then
                if [ -n "$API_KEY" ]; then
                    ENGINE="mimo"
                else
                    ENGINE="edge"
                    VOICE="${ARG3:-云希}"
                fi
            fi
        fi

        PERSIST="false"
        CHAT="false"
        SUMMARY_EN="true"
        SUMMARY_URL="https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        SUMMARY_KEY=""
        SUMMARY_MOD="gemini-2.0-flash-lite"
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE"
            PERSIST="${MODE_PERSIST:-false}"
            CHAT="${CHAT_MODE:-false}"
            SUMMARY_EN="${SUMMARY_ENABLED:-true}"
            SUMMARY_URL="${SUMMARY_BASE_URL:-https://generativelanguage.googleapis.com/v1beta/openai/chat/completions}"
            SUMMARY_KEY="${SUMMARY_API_KEY:-}"
            SUMMARY_MOD="${SUMMARY_MODEL:-gemini-2.0-flash-lite}"
        fi

        cat > "$CONFIG_FILE" << EOF
# TTS 配置
TTS_ENGINE=$ENGINE
TTS_API_KEY=$API_KEY
TTS_VOICE=$VOICE
TTS_STYLE=$STYLE

# 插件状态（MODE_PERSIST=true 时无需手动 /enable，chat 模式持久化保存）
MODE_PERSIST=$PERSIST
CHAT_MODE=$CHAT

# 智能总结配置 (可选，默认使用 Google Gemini 免费模型)
SUMMARY_ENABLED=$SUMMARY_EN
SUMMARY_BASE_URL=$SUMMARY_URL
SUMMARY_API_KEY=$SUMMARY_KEY
SUMMARY_MODEL=$SUMMARY_MOD
EOF
        echo "CONFIG_SAVED=$CONFIG_FILE"
        ;;
esac
