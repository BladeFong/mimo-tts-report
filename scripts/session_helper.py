#!/usr/bin/env python3
"""Python 会话辅助工具：推导并返回当前会话专属的 /dev/shm 内存目录"""
import os
import re
import sys

BASE_SESSIONS_DIR = "/dev/shm/mimo-tts-sessions"


def resolve_session_id(explicit_id=None):
    if explicit_id:
        return str(explicit_id).strip()

    for key in ('ANTIGRAVITY_CONVERSATION_ID', 'CLAUDE_SESSION_ID', 'CLAUDE_CONVERSATION_ID', 'CONVERSATION_ID'):
        val = os.environ.get(key)
        if val:
            return val.strip()

    try:
        tty_name = os.ttyname(sys.stdin.fileno())
        if tty_name:
            return f"tty_{tty_name.replace('/', '_')}"
    except Exception:
        pass

    return f"pid_{os.getppid()}"


def get_session_dir(explicit_id=None):
    sid = resolve_session_id(explicit_id)
    sid = re.sub(r'[^a-zA-Z0-9_-]', '', sid)
    if not sid:
        sid = "default"
    path = os.path.join(BASE_SESSIONS_DIR, sid)
    os.makedirs(path, exist_ok=True)
    return path


if __name__ == '__main__':
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    print(get_session_dir(arg))
