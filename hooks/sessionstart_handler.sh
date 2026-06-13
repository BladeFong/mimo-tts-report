#!/bin/bash
# SessionStart hook: 根据配置自动启用插件
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PLUGIN_ROOT}/config.env"

# 清除内存标记
rm -f /dev/shm/mimo-tts-report-enabled
rm -f /dev/shm/mimo-tts-chat-mode

# 读取配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"

    # 自动启用
    if [ "${MODE_PERSIST:-false}" = "true" ] && [ -n "${TTS_API_KEY:-}" ]; then
        touch /dev/shm/mimo-tts-report-enabled
    fi
fi
