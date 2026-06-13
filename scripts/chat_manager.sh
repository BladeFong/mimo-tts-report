#!/bin/bash
# Chat 模式管理脚本
# 用法: chat_manager.sh status   — 返回当前状态（开启/关闭）
#       chat_manager.sh toggle   — 切换模式

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PLUGIN_ROOT}/config.env"

source "$CONFIG_FILE"

ACTION="${1:-}"

# 根据 MODE_PERSIST 决定读写方式
if [ "${MODE_PERSIST:-false}" = "true" ]; then
    # 文件配置方式
    case "$ACTION" in
        status)
            grep -q "CHAT_MODE=true" "$CONFIG_FILE" && echo "开启" || echo "关闭"
            ;;
        toggle)
            if grep -q "CHAT_MODE=true" "$CONFIG_FILE"; then
                sed -i 's/CHAT_MODE=true/CHAT_MODE=false/' "$CONFIG_FILE"
                echo "关闭"
            else
                sed -i 's/CHAT_MODE=false/CHAT_MODE=true/' "$CONFIG_FILE"
                echo "开启"
            fi
            ;;
    esac
else
    # 内存文件方式
    case "$ACTION" in
        status)
            [ -f /dev/shm/mimo-tts-chat-mode ] && echo "开启" || echo "关闭"
            ;;
        toggle)
            if [ -f /dev/shm/mimo-tts-chat-mode ]; then
                rm -f /dev/shm/mimo-tts-chat-mode
                echo "关闭"
            else
                touch /dev/shm/mimo-tts-chat-mode
                echo "开启"
            fi
            ;;
    esac
fi
