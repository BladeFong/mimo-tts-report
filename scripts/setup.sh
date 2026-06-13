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
        if [ -f "$CONFIG_FILE" ] && grep -q "TTS_API_KEY=.\+" "$CONFIG_FILE"; then
            source "$CONFIG_FILE"
            # 写入启用标记（内存）
            touch "/dev/shm/mimo-tts-report-enabled"
            echo "READY=true"
            echo "VOICE=$TTS_VOICE"
        else
            echo "NEED_INIT=true"
        fi
        ;;
    init)
        if [ -f "$CONFIG_FILE" ] && grep -q "TTS_API_KEY=.\+" "$CONFIG_FILE"; then
            source "$CONFIG_FILE"
            echo "ALREADY_CONFIGURED=true"
            echo "VOICE=$TTS_VOICE"
            exit 0
        fi
        API_KEY="${2:-}"
        [ -z "$API_KEY" ] && exit 1
        export TTS_API_KEY="$API_KEY"
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
        API_KEY="${2:-}"
        VOICE="${3:-茉莉}"
        STYLE="${4:-用平静温和的语气简要汇报}"
        [ -z "$API_KEY" ] && exit 1
        cat > "$CONFIG_FILE" << EOF
# TTS 配置
TTS_API_KEY=$API_KEY
TTS_VOICE=$VOICE
TTS_STYLE=$STYLE
EOF
        echo "CONFIG_SAVED=$CONFIG_FILE"
        ;;
esac
