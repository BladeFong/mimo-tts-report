---
name: mimo-tts-report:enable
description: 启用 mimo-tts-report 语音播报插件。
user-invocable: true
---

启用 mimo-tts-report 插件。

步骤：
1. 执行 `bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh enable`
2. 根据输出处理：
   - `READY=true` → 告知用户插件已启用
   - `NEED_INIT=true` → 引导用户执行 `/mimo-tts-report:init`
