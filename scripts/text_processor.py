#!/usr/bin/env python3
"""文本处理工具：清理文本用于 TTS 播报"""
import re

def clean_for_tts(text):
    """清理文本用于 TTS 播报"""
    if not text:
        return ""

    # 过滤代码块，保留行内代码内容
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = text.replace('`', '')
    # 下划线和连字符替换为空格
    text = text.replace('_', ' ')
    text = text.replace('-', ' ')
    # 中英文/数字之间的空格去掉（避免 TTS 停顿）
    text = re.sub(r'([一-鿿])\s+([a-zA-Z0-9])', r'\1\2', text)
    text = re.sub(r'([a-zA-Z0-9])\s+([一-鿿])', r'\1\2', text)
    # 清理多余空白
    text = re.sub(r'\n\s*\n', '\n', text).strip()
    # 截断
    if len(text) > 200:
        text = text[:200] + '……'
    return text
