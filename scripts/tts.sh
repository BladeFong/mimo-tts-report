#!/bin/bash
# 纯 TTS 播放（支持 MiMo 与 Edge-TTS 双引擎）
# 用法: tts.sh voices                — 返回支持的音色列表
#       tts.sh "文字" [VOICE] [STYLE] — 播放语音
#       tts.sh stop                  — 停止正在播放的语音

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

[ -f "$SKILL_DIR/config.env" ] && source "$SKILL_DIR/config.env"

# 确定引擎：优先使用配置，若配置为 mimo 但没有 API_KEY 则自动降级到 edge
ENGINE="${TTS_ENGINE:-edge}"
if [ "$ENGINE" = "mimo" ] && [ -z "${TTS_API_KEY:-}" ]; then
    ENGINE="edge"
fi

# 音色列表子命令
if [ "${1:-}" = "voices" ]; then
    if [ "$ENGINE" = "mimo" ]; then
        echo "冰糖 茉莉 苏打 白桦"
    else
        echo "云希 晓晓 云健 晓伊 云扬"
    fi
    exit 0
fi

WIN_PID_FILE="/dev/shm/mimo_tts_win.pid"
WSL_PID_FILE="/dev/shm/mimo_tts_wsl.pid"

# 停止播放子命令 / 播放前打断前序音频
stop_current_playback() {
    # 1. 中断正在进行的 WSL 合成进程
    if [ -f "$WSL_PID_FILE" ]; then
        OLD_WSL_PID=$(cat "$WSL_PID_FILE" 2>/dev/null || true)
        if [ -n "$OLD_WSL_PID" ] && kill -0 "$OLD_WSL_PID" 2>/dev/null; then
            pkill -P "$OLD_WSL_PID" 2>/dev/null || true
            kill -9 "$OLD_WSL_PID" 2>/dev/null || true
        fi
        rm -f "$WSL_PID_FILE" 2>/dev/null || true
    fi

    # 2. 强制终止 Windows 独立播放进程
    if [ -f "$WIN_PID_FILE" ]; then
        OLD_WIN_PID=$(cat "$WIN_PID_FILE" 2>/dev/null || true)
        if [ -n "$OLD_WIN_PID" ]; then
            taskkill.exe /F /PID "$OLD_WIN_PID" 2>/dev/null || /mnt/c/WINDOWS/system32/taskkill.exe /F /PID "$OLD_WIN_PID" 2>/dev/null || true
        fi
        rm -f "$WIN_PID_FILE" 2>/dev/null || true
    fi
}

if [ "${1:-}" = "stop" ]; then
    stop_current_playback
    exit 0
fi

TEXT="${1:-}"
[ -z "$TEXT" ] && exit 0

# 下划线替换为空格
TEXT="${TEXT//_/ }"

DEFAULT_VOICE="云希"
[ "$ENGINE" = "mimo" ] && DEFAULT_VOICE="茉莉"

VOICE="${2:-${TTS_VOICE:-$DEFAULT_VOICE}}"
STYLE="${3:-${TTS_STYLE:-用平静温和的语气简要汇报}}"

# 播放前先中断旧音频
stop_current_playback

if [ "$ENGINE" = "edge" ]; then
    # --- Edge-TTS 引擎 (免费免 Key，交由 Windows 后台完全独立播放) ---
    python3 -c "
import asyncio, sys, os, time, base64, subprocess, edge_tts

VOICE_MAP = {
    '云希': 'zh-CN-YunxiNeural',
    '晓晓': 'zh-CN-XiaoxiaoNeural',
    '云健': 'zh-CN-YunjianNeural',
    '晓伊': 'zh-CN-XiaoyiNeural',
    '云扬': 'zh-CN-YunyangNeural'
}

text = sys.argv[1]
raw_voice = sys.argv[2]
voice = VOICE_MAP.get(raw_voice, raw_voice if raw_voice.startswith('zh-CN') else 'zh-CN-YunxiNeural')
temp_mp3 = f'/dev/shm/mimo_tts_{int(time.time())}_{os.getpid()}.mp3'

async def synthesize():
    comm = edge_tts.Communicate(text, voice)
    await comm.save(temp_mp3)

try:
    asyncio.run(synthesize())
    if not os.path.exists(temp_mp3):
        sys.exit(0)

    try:
        win_path = subprocess.check_output(['wslpath', '-w', temp_mp3]).decode().strip()
    except Exception:
        distro = os.environ.get('WSL_DISTRO_NAME', 'Ubuntu-24.04')
        win_path = f'\\\\\\\\wsl.localhost\\\\{distro}{temp_mp3}'

    ps_inner = f'''
Add-Type -MemberDefinition '[DllImport(\"winmm.dll\")] public static extern int mciSendString(string a, string b, int c, IntPtr d);' -Name MciPlayer -Namespace Win32 -ErrorAction SilentlyContinue
[Win32.MciPlayer]::mciSendString('close all', \$null, 0, [IntPtr]::Zero)
[Win32.MciPlayer]::mciSendString('open \"{win_path}\" type mpegvideo alias mp3file', \$null, 0, [IntPtr]::Zero)
[Win32.MciPlayer]::mciSendString('play mp3file wait', \$null, 0, [IntPtr]::Zero)
[Win32.MciPlayer]::mciSendString('close mp3file', \$null, 0, [IntPtr]::Zero)
Remove-Item '{win_path}' -Force -ErrorAction SilentlyContinue
'''
    b64_inner = base64.b64encode(ps_inner.encode('utf-16le')).decode('ascii')
    ps_cmd = f'[Console]::WriteLine((Start-Process powershell.exe -ArgumentList \"-NoProfile -NonInteractive -EncodedCommand {b64_inner}\" -WindowStyle Hidden -PassThru).Id)'
    cmd = ['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', ps_cmd]
    try:
        win_pid = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode().strip()
        if win_pid:
            with open('/dev/shm/mimo_tts_win.pid', 'w') as f:
                f.write(win_pid)
    except Exception:
        pass
except Exception:
    if os.path.exists(temp_mp3):
        try: os.remove(temp_mp3)
        except: pass
" "$TEXT" "$VOICE" </dev/null >/dev/null 2>&1 &
    echo $! > "$WSL_PID_FILE"

else
    # --- MiMo TTS 引擎 (小米 API，交由 Windows 后台完全独立播放) ---
    MIMO_URL="${TTS_BASE_URL:-https://token-plan-cn.xiaomimimo.com/v1/chat/completions}"
    python3 -c "
import sys, os, time, json, base64, struct, subprocess, urllib.request

api_key = sys.argv[1]
text = sys.argv[2]
voice = sys.argv[3]
style = sys.argv[4]
mimo_url = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else 'https://token-plan-cn.xiaomimimo.com/v1/chat/completions'

if not api_key:
    sys.exit(0)

payload = json.dumps({
    'model': 'mimo-v2.5-tts',
    'messages': [
        {'role': 'user', 'content': style},
        {'role': 'assistant', 'content': text}
    ],
    'audio': {'format': 'wav', 'voice': voice}
}, ensure_ascii=False).encode('utf-8')

req = urllib.request.Request(
    mimo_url,
    data=payload,
    headers={'api-key': api_key, 'Content-Type': 'application/json'}
)

try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        res_data = json.loads(resp.read().decode('utf-8'))
        audio_b64 = res_data['choices'][0]['message']['audio']['data']
        wav_bytes = bytearray(base64.b64decode(audio_b64))

        # 前置 200ms 静音优化
        sr = struct.unpack_from('<I', wav_bytes, 24)[0]
        silence_samples = sr * 200 // 1000
        wav_bytes[44:44] = b'\x00' * (silence_samples * 2)
        data_size = len(wav_bytes) - 44
        struct.pack_into('<I', wav_bytes, 4, len(wav_bytes) - 8)
        struct.pack_into('<I', wav_bytes, 40, data_size)

        temp_wav = f'/dev/shm/mimo_tts_{int(time.time())}_{os.getpid()}.wav'
        with open(temp_wav, 'wb') as f:
            f.write(wav_bytes)

        try:
            win_path = subprocess.check_output(['wslpath', '-w', temp_wav]).decode().strip()
        except Exception:
            distro = os.environ.get('WSL_DISTRO_NAME', 'Ubuntu-24.04')
            win_path = f'\\\\\\\\wsl.localhost\\\\{distro}{temp_wav}'

        ps_inner = f'''
\$sp = New-Object System.Media.SoundPlayer('{win_path}')
\$sp.PlaySync()
\$sp.Dispose()
Remove-Item '{win_path}' -Force -ErrorAction SilentlyContinue
'''
        b64_inner = base64.b64encode(ps_inner.encode('utf-16le')).decode('ascii')
        ps_cmd = f'[Console]::WriteLine((Start-Process powershell.exe -ArgumentList \"-NoProfile -NonInteractive -EncodedCommand {b64_inner}\" -WindowStyle Hidden -PassThru).Id)'
        cmd = ['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', ps_cmd]
        try:
            win_pid = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode().strip()
            if win_pid:
                with open('/dev/shm/mimo_tts_win.pid', 'w') as f:
                    f.write(win_pid)
        except Exception:
            pass
except Exception:
    pass
" "${TTS_API_KEY:-}" "$TEXT" "$VOICE" "$STYLE" "$MIMO_URL" </dev/null >/dev/null 2>&1 &
    echo $! > "$WSL_PID_FILE"
fi
