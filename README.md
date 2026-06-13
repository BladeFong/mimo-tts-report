# MiMo TTS Report

Claude Code 语音播报插件，使用 MiMo TTS API 完成任务后自动语音汇报。

## 功能

- 任务完成后自动语音播报结果
- 交流模式：每次回复都语音播报（适合语音输入法用户）
- 权限确认前 30 秒预播报提醒
- 支持多种音色：冰糖、茉莉、苏打、白桦

## 安装

```bash
/plugin install mimo-tts-report
```

## 配置

1. 启用插件：
   ```
   /mimo-tts-report:enable
   ```

2. 首次配置（验证 API key、选择音色）：
   ```
   /mimo-tts-report:init
   ```

3. （可选）开启交流模式：
   ```
   /mimo-tts-report:chat
   ```

## 配置文件

编辑 `config.env`：

```bash
TTS_API_KEY=your-api-key-here
TTS_VOICE=茉莉
TTS_STYLE=用平静温和的语气简要汇报
```

## 工作原理

插件通过 Claude Code hooks 在以下时机触发：

- **SessionStart**：清除会话状态
- **UserPromptSubmit**：记录任务开始时间
- **TaskCreated**：记录任务标题
- **Stop**：任务完成后播报结果（耗时 > 3 分钟）
- **Notification**：权限确认前预播报

## 自定义 TTS

可替换 `scripts/tts.sh` 接入其他 TTS 引擎或本地模型（如 edge-tts、pyttsx3 等）。

**注意**：`TTS_API_KEY` 必须配置（使用本地模型时可填任意字符串占位）。

tts.sh 接口：
- `tts.sh voices` - 返回支持的音色列表
- `tts.sh "文本" [音色] [风格]` - 播放语音

## License

MIT
