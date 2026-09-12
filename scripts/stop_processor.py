#!/usr/bin/env python3
"""Stop hook 处理器：从 stdin 读取 last_assistant_message 与 session_id 并播报"""
import sys, json, subprocess, os

PLUGIN_ROOT = os.environ.get('PLUGIN_ROOT', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPORT_SCRIPT = os.path.join(PLUGIN_ROOT, 'scripts', 'report.sh')
PREANNOUNCE_SCRIPT = os.path.join(PLUGIN_ROOT, 'scripts', 'preannounce.sh')
sys.path.insert(0, PLUGIN_ROOT)

from scripts.text_processor import summarize_with_llm

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

session_id = data.get('session_id') or data.get('conversationId') or os.environ.get('CLAUDE_SESSION_ID') or os.environ.get('CONVERSATION_ID') or ''
last_text = data.get('last_assistant_message', '')

# 取消当前会话可能挂起的预报
subprocess.run(['bash', PREANNOUNCE_SCRIPT, 'cancel', session_id], capture_output=True)

if not last_text:
    subprocess.run(['bash', REPORT_SCRIPT, 'cleanup', session_id], capture_output=True)
    sys.exit(0)

# 智能总结或清洗文本
last_text = summarize_with_llm(last_text)

if last_text:
    subprocess.run(['bash', REPORT_SCRIPT, 'speak', last_text, session_id], capture_output=True)
else:
    subprocess.run(['bash', REPORT_SCRIPT, 'cleanup', session_id], capture_output=True)

