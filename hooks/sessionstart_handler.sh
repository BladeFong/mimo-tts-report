#!/bin/bash
# SessionStart hook: 清除启用标记和交流模式
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# 清除启用标记
rm -f /dev/shm/mimo-tts-report-enabled

# 清除交流模式
rm -f /dev/shm/mimo-tts-chat-mode
