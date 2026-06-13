---
name: mimo-tts-report:chat
description: 切换交流模式：开启后每次回复都语音播报（适合语音输入法用户）
user-invocable: true
---

切换 mimo-tts-report 交流模式。

步骤：
1. 先执行 enable 流程（参考 enable.md）
2. 如果 `NEED_INIT=true`，提示用户先执行 `/mimo-tts-report:init`
3. 如果 `READY=true`，检查当前模式：`[ -f /dev/shm/mimo-tts-chat-mode ] && echo "开启" || echo "关闭"`
4. 切换模式：
   - 当前开启 → 关闭：`rm -f /dev/shm/mimo-tts-chat-mode`
   - 当前关闭 → 开启：`touch /dev/shm/mimo-tts-chat-mode`
5. 告知用户当前状态
