#!/bin/bash
# 纯 TTS 播放
# 用法: tts.sh voices                — 返回支持的音色列表
#       tts.sh "文字" VOICE STYLE    — 播放语音

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

[ -f "$SKILL_DIR/config.env" ] && source "$SKILL_DIR/config.env"

# 音色列表子命令
if [ "${1:-}" = "voices" ]; then
    echo "冰糖 茉莉 苏打 白桦"
    exit 0
fi

# 停止播放子命令
if [ "${1:-}" = "stop" ]; then
    PID_FILE="/dev/shm/mimo_tts_player.pid"
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            pkill -P "$OLD_PID" 2>/dev/null || true
            kill "$OLD_PID" 2>/dev/null || true
        fi
        rm -f "$PID_FILE" 2>/dev/null
    fi
    exit 0
fi

TEXT="${1:-}"
VOICE="${2:-${TTS_VOICE:-茉莉}}"
STYLE="${3:-${TTS_STYLE:-用平静温和的语气简要汇报}}"

[ -z "$TEXT" ] && exit 0

# 下划线替换为空格
TEXT="${TEXT//_/ }"

API_KEY="${TTS_API_KEY:-}"
[ -z "$API_KEY" ] && exit 0

# 不再截断，由调用方控制长度

AUDIO_B64=$(curl -s --max-time 15 'https://token-plan-cn.xiaomimimo.com/v1/chat/completions' \
  --header "api-key: $API_KEY" \
  --header 'Content-Type: application/json' \
  --data "$(python3 -c "
import json
print(json.dumps({
    'model': 'mimo-v2.5-tts',
    'messages': [
        {'role': 'user', 'content': $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$STYLE")},
        {'role': 'assistant', 'content': $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$TEXT")}
    ],
    'audio': {'format': 'wav', 'voice': $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$VOICE")}
}, ensure_ascii=False))
")" | python3 -c "
import sys, json
d = json.load(sys.stdin)
try:
    print(d['choices'][0]['message']['audio']['data'])
except:
    sys.exit(1)
" 2>/dev/null)

[ -z "$AUDIO_B64" ] && exit 0

PID_FILE="/dev/shm/mimo_tts_player.pid"

# 中断当前正在播放的音频（如有）
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        pkill -P "$OLD_PID" 2>/dev/null || true
        kill "$OLD_PID" 2>/dev/null || true
    fi
    rm -f "$PID_FILE" 2>/dev/null
fi

MODIFIED_B64=$(python3 -c "
import base64, struct, sys
data = bytearray(base64.b64decode(sys.stdin.read()))
sr = struct.unpack_from('<I', data, 24)[0]
silence_samples = sr * 200 // 1000
data[44:44] = b'\x00' * (silence_samples * 2)
data_size = len(data) - 44
struct.pack_into('<I', data, 4, len(data) - 8)
struct.pack_into('<I', data, 40, data_size)
sys.stdout.write(base64.b64encode(data).decode('ascii'))
" <<< "$AUDIO_B64")

[ -z "$MODIFIED_B64" ] && exit 0

# 后台纯内存播放，不写磁盘临时文件，PlaySync 播完子进程自动退出
(
    echo "$MODIFIED_B64" | powershell.exe -NoProfile -NonInteractive -Command "
    \$b64 = [Console]::In.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace(\$b64)) {
        \$bytes = [System.Convert]::FromBase64String(\$b64.Trim())
        \$ms = New-Object System.IO.MemoryStream(,\$bytes)
        \$sp = New-Object System.Media.SoundPlayer(\$ms)
        \$sp.PlaySync()
        \$sp.Dispose()
        \$ms.Dispose()
    }
    " 2>/dev/null
    rm -f "$PID_FILE" 2>/dev/null
) </dev/null >/dev/null 2>&1 &
echo $! > "$PID_FILE"
