# AI 网关 / 统一入口预设

LanguageTool 通过 OpenAI-Compatible 契约接入多家服务。除直连厂商外，可使用统一网关一次 Key 访问多模型。

## 内置预设（精简后）

设置里默认只保留 4 项：

| 显示名 | Provider ID | 默认 Base URL | 默认 Model | 说明 |
|--------|-------------|---------------|------------|------|
| Aliyun | `aliyun` | DashScope compatible-mode | `qwen-mt-turbo` | 专用翻译 MT，大批量路由会优先使用 |
| Google Gemini | `gemini` | Gemini `generateContent` | `gemini-1.5-flash` | 非 OpenAI 协议，需单独保留 |
| OpenAI Compatible | `openai_compatible` | `https://api.openai.com/v1/chat/completions` | `gpt-4o-mini` | 任意兼容端点（DeepSeek / Kimi / GLM / OneAPI / LiteLLM / Ollama） |
| OpenRouter | `openrouter` | `https://openrouter.ai/api/v1/chat/completions` | `openai/gpt-4o-mini` | 统一网关，模型名形如 `vendor/model` |

原 DeepSeek / Kimi / GLM 固定入口已移除；若本地仍选中它们，会自动迁移到 **OpenAI Compatible**，并尽量带上原 Base URL、Model 与 API Key。

### 用 OpenAI Compatible 复刻旧厂商

| 原厂商 | Base URL（可填文档中的根地址，应用会自动补全 `/chat/completions`） | 建议 Model |
|--------|----------|------------|
| DeepSeek | `https://api.deepseek.com` 或 `https://api.deepseek.com/chat/completions` | `deepseek-flash`（或 `deepseek-v4-pro`） |
| Kimi (Moonshot) | `https://api.moonshot.cn/v1` 或完整 `…/chat/completions` | `moonshot-v1-8k` / `moonshot-v1-32k` |
| GLM | `https://open.bigmodel.cn/api/paas/v4` 或完整路径 | `glm-4.5` |

> 注意：文档里的 `base_url`（如 DeepSeek 的 `https://api.deepseek.com`）是给 OpenAI SDK 用的根地址；本应用若收到根地址会自动补全为 `…/chat/completions`。Model **不会**固定为 `gpt-4o-mini`——那只是 OpenAI Compatible 条目的占位默认值；填写已知厂商 Base URL 后会按厂商建议模型更新。

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
