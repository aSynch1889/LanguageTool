# AI 网关 / 统一入口预设

LanguageTool 通过 OpenAI-Compatible 契约接入多家服务。除直连厂商外，可使用统一网关一次 Key 访问多模型。

## 内置预设

| 显示名 | Provider ID | 默认 Base URL | 默认 Model | 说明 |
|--------|-------------|---------------|------------|------|
| OpenRouter | `openrouter` | `https://openrouter.ai/api/v1/chat/completions` | `openai/gpt-4o-mini` | 统一网关，模型名形如 `vendor/model` |
| OpenAI Compatible | `openai_compatible` | `https://api.openai.com/v1/chat/completions` | `gpt-4o-mini` | 任意兼容端点（OneAPI / LiteLLM / 自建代理 / Ollama） |

## OpenRouter 用法

1. 在 [OpenRouter](https://openrouter.ai/) 创建 API Key。
2. 设置 → AI 服务 选择 **OpenRouter**，粘贴 Key。
3. 按需修改 **Model**（如 `anthropic/claude-3.5-sonnet`、`google/gemini-2.0-flash-001`、`deepseek/deepseek-chat`）。
4. 点击 **Test Connection** 验证。

可选：将 Fallback 设为 DeepSeek / Kimi 等直连 Provider，网关故障时自动降级（需已配置对应 Key）。

## 自建 LiteLLM / OneAPI

1. 选择 **OpenAI Compatible**。
2. Base URL 填网关的 chat completions 地址，例如：
   - `http://127.0.0.1:4000/v1/chat/completions`
   - `https://your-company-proxy.example/v1/chat/completions`
3. Model 填网关侧注册的模型名。
4. API Key 填网关要求的令牌。

## 本地 Ollama

1. 启动 Ollama，并确认 OpenAI 兼容接口可用。
2. 选择 **OpenAI Compatible**。
3. Base URL：`http://127.0.0.1:11434/v1/chat/completions`
4. Model：本地模型名（如 `llama3.2`）。
5. API Key 可填任意非空占位（部分本地服务仍校验 Header 存在）。

## 任务级指标

批量翻译结束后，控制台会打印一行 metrics，例如：

```text
Translation metrics: texts=120 cache=40 network=80 fallback=1 duration=12.35s provider=aliyun route=largeBatchUsesMT
```

`TranslationStatistics.summary` 也会附带 `cache` / `fallback` / 耗时，便于 UI 展示。
