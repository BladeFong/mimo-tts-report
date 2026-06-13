---
name: mimo-tts-report:init
description: 首次配置 mimo-tts-report：验证 API key、选择音色
user-invocable: true
---

初始化 mimo-tts-report 插件配置。

步骤：
1. 先执行 enable 流程（参考 enable.md）
2. 如果输出 `READY=true`，告知用户已配置，无需重复 init
3. 如果输出 `NEED_INIT=true`，继续以下步骤：
   a. 检测服务器类型：`echo "$ANTHROPIC_BASE_URL" | grep -q "token-plan-cn.xiaomimimo.com" && echo "token-plan" || echo "other"`
   b. 根据服务器类型决定 key 来源：
      - token-plan → 询问用户是否使用当前 ANTHROPIC_AUTH_TOKEN
      - other → 让用户提供 key
   c. 验证 key：调用 TTS API 测试
   d. 播放音色样本：`bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh init $KEY`
   e. 从输出获取音色列表（VOICES=...），用 AskUserQuestion 让用户选音色
   f. 保存配置：`bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh save $KEY $VOICE`
   g. 告知用户配置完成
