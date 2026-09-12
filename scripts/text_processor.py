#!/usr/bin/env python3
"""文本处理工具：清理文本与智能总结用于 TTS 播报"""
import re
import os
import sys
import json
import urllib.request


def load_plugin_config():
    """读取 config.env 配置文件"""
    config = {}
    plugin_root = os.environ.get('PLUGIN_ROOT')
    if not plugin_root:
        plugin_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    env_file = os.path.join(plugin_root, 'config.env')
    if os.path.exists(env_file):
        try:
            with open(env_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        k, v = line.split('=', 1)
                        config[k.strip()] = v.strip().strip('\'"')
        except Exception:
            pass
    return config


def clean_for_tts(text, max_len=500):
    """清理文本用于 TTS 播报：剥离 Markdown 语法、特殊符号与 URL，保留自然朗读标点"""
    if not text:
        return ""

    # 1. 过滤多行代码块与 HTML 标签/注释
    text = re.sub(r'```[\s\S]*?```', '', text)
    text = re.sub(r'<!--[\s\S]*?-->', '', text)
    text = re.sub(r'<[^>]+>', '', text)

    # 2. 过滤 Markdown 表格语法行与排版对齐符
    text = re.sub(r'(?m)^\s*\|.*\|.*$', '', text)
    text = re.sub(r':?-{2,}:?', '', text)

    # 3. 过滤图片引用与 Markdown 链接（提取纯文本标题，剥离 URL）
    text = re.sub(r'!\[.*?\]\(.*?\)', '', text)
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    text = re.sub(r'https?://\S+|file://\S+', '', text)

    # 4. 过滤数学公式
    text = re.sub(r'\$\$[\s\S]*?\$\$', '', text)
    text = re.sub(r'\$([^\$]+)\$', r'\1', text)

    # 5. 去除 Markdown 标题符号 (#, ##, ###) 和分割线 (---, ***, ___)
    text = re.sub(r'(?m)^\s*#{1,6}\s*', '', text)
    text = re.sub(r'(?m)^\s*[-*_]{3,}\s*$', '', text)

    # 6. 去除引用符 (>) 与无序列表标号 (-, *, +)
    text = re.sub(r'(?m)^\s*>\s*', '', text)
    text = re.sub(r'(?m)^\s*[-*+]\s+', '', text)

    # 7. 去除粗体、斜体、删除线 (**, *, __, ~~) 与行内代码反引号
    text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)
    text = re.sub(r'\*([^*]+)\*', r'\1', text)
    text = re.sub(r'__([^_]+)__', r'\1', text)
    text = re.sub(r'~~([^~]+)~~', r'\1', text)
    text = text.replace('`', '')
    text = text.replace('|', ' ')

    # 8. 过滤孤立特殊机械符号（保留自然朗读标点：，。！？、；：,.!?:）
    text = re.sub(r'[#*~_^\<\>\{\}\\\\]', ' ', text)

    # 9. 消除中英文/数字粘连产生的多余空格，并将换行平滑转为自然停顿
    text = re.sub(r'([一-鿿])\s+([a-zA-Z0-9])', r'\1\2', text)
    text = re.sub(r'([a-zA-Z0-9])\s+([一-鿿])', r'\1\2', text)
    text = re.sub(r'\n+', '，', text)
    text = re.sub(r'\s+', ' ', text).strip()

    # 10. 标点符号规范化（清理首尾与连续多余逗号）
    text = re.sub(r'[，,]{2,}', '，', text)
    text = re.sub(r'^[，,：:\s]+', '', text)
    text = re.sub(r'[，,、\s]+$', '。', text)

    # 11. 智能断句截断（优先在句末强标点处截断，作为离线安全兜底）
    if len(text) > max_len:
        truncated = text[:max_len]
        # 第一优先级：完整句末标点（。！？）
        last_strong_punct = max(
            truncated.rfind('。'),
            truncated.rfind('！'),
            truncated.rfind('？')
        )
        if last_strong_punct > int(max_len * 0.6):
            text = truncated[:last_strong_punct + 1]
        else:
            # 第二优先级：分句标点（；，）
            last_weak_punct = max(
                truncated.rfind('；'),
                truncated.rfind('，')
            )
            if last_weak_punct > int(max_len * 0.75):
                text = truncated[:last_weak_punct] + '。'
            else:
                text = truncated + '……'

    return text


def summarize_with_llm(text):
    """使用轻量 LLM 总结文本为口语化播报；未启用或失败时平滑降级到 clean_for_tts"""
    if not text:
        return ""

    cfg = load_plugin_config()
    enabled = cfg.get('SUMMARY_ENABLED', 'true').lower() in ('true', '1')
    api_key = os.environ.get('SUMMARY_API_KEY') or cfg.get('SUMMARY_API_KEY', '').strip()
    base_url = cfg.get('SUMMARY_BASE_URL', 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions')
    model = cfg.get('SUMMARY_MODEL', 'gemini-flash-lite-latest')

    # 若未启用总结或未配置 Key，直接走基础清洗
    if not enabled or not api_key:
        return clean_for_tts(text)

    # 若文本原本就很短（≤80字），无需额外调用模型总结
    cleaned_original = clean_for_tts(text)
    if len(cleaned_original) <= 80:
        return cleaned_original

    system_prompt = (
        "你是一个专业的语音播报助手。请将给定的AI助手回复提炼为适合自然语音播报的口语化简报。\n"
        "要求：\n"
        "1. 重点提炼核心结论、已完成的工作或需要用户确认的关键问题，着墨重点表达；\n"
        "2. 语言口语化、自然流畅，尽量精炼，期望长度在 50~100 字左右（最高不超过 150 字），确保语句自然完整闭合；\n"
        "3. 直接输出纯文本，严禁包含任何 Markdown 标记（如 #、*、链接、代码块等）或排版符号。"
    )

    models_to_try = [model]
    if model != 'gemini-flash-lite-latest' and 'gemini' in model:
        models_to_try.append('gemini-flash-lite-latest')

    for m in models_to_try:
        payload = json.dumps({
            "model": m,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": text[:4000]}
            ],
            "max_tokens": 200,
            "temperature": 0.3
        }).encode('utf-8')

        req = urllib.request.Request(
            base_url,
            data=payload,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            }
        )

        try:
            with urllib.request.urlopen(req, timeout=3.5) as resp:
                res_data = json.loads(resp.read().decode('utf-8'))
                summary = res_data['choices'][0]['message']['content'].strip()
                if summary:
                    return clean_for_tts(summary, max_len=300)
        except Exception:
            continue

    return clean_for_tts(text)


if __name__ == '__main__':
    # CLI 测试入口
    if len(sys.argv) > 1:
        input_text = " ".join(sys.argv[1:])
    else:
        input_text = sys.stdin.read()
    print(summarize_with_llm(input_text))
