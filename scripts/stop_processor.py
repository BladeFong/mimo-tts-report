#!/usr/bin/env python3
"""Stop hook 处理器：从 stdin 读取 last_assistant_message 并播报"""
import sys, json, subprocess
import os

PLUGIN_ROOT = os.environ.get('PLUGIN_ROOT', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPORT_SCRIPT = os.path.join(PLUGIN_ROOT, 'scripts', 'report.sh')
sys.path.insert(0, PLUGIN_ROOT)

from scripts.text_processor import summarize_with_llm

data = json.load(sys.stdin)
last_text = data.get('last_assistant_message', '')

if not last_text:
    subprocess.run(['bash', REPORT_SCRIPT, 'cleanup'], capture_output=True)
    sys.exit(0)

# 智能总结或清洗文本
last_text = summarize_with_llm(last_text)

if last_text:
    subprocess.run(['bash', REPORT_SCRIPT, 'speak', last_text], capture_output=True)
else:
    subprocess.run(['bash', REPORT_SCRIPT, 'cleanup'], capture_output=True)
