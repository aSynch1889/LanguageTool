# AI 翻译服务方案分析

> 日期：2026-10-08  
> 范围：对照成熟本地化 / LLM 应用，评估 LanguageTool 当前 AI 翻译架构并提出演进建议  
> 依据：源码（`AIServiceV2`、`AIProviderRegistry`、Providers、Settings）、现有 `AI_ARCHITECTURE_REFACTORING.md`、业界 2025–2026 多 Provider 路由实践

---

## 1. 结论摘要

当前方案**并不“完全过时”**：已完成一轮配置驱动重构（Registry + Provider 插件 + Keychain + 基础 Fallback），比早期硬编码多服务实现更清晰。

但相对成熟产品（Lingo.dev、Localazy AI、Phrase、Crowdin AI、以及 OpenRouter / LiteLLM / AI Gateway 一类统一接入层），仍有明显代差，主要体现在：

| 维度 | 当前状态 | 成熟方案常见水平 |
|------|----------|------------------|
| Provider 接入 | 5 家国产/区域向 LLM，手写 Request/Response | OpenAI-Compatible 统一契约 + 少量特例适配 |
| 模型选择 | 每个 Provider 写死一个 model | 用户可选模型 / 按任务路由模型 |
| 自定义端点 | 无 | Base URL + API Key（兼容代理 / 私有部署 / Ollama） |
| 容错 | 单级 Fallback + HTTP 重试 | Fallback 链、熔断、仅对瞬时错误切换 |
| 翻译质量管线 | Prompt + JSON 批处理 + 术语表 hint | NMT/专用翻译模型 + LLM 润色、术语强制、质量评分 |
| 可观测性 | DEBUG 日志 | Token/成本/延迟/失败率、按 Provider 归因 |
| 设置 UX | 仅当前 Provider 填 Key | 多 Key 管理、连通性测试、用量提示 |

**推荐方向（一句话）**：保留现有 Registry 分层，把“通用 Chat Completions”收敛为 **OpenAI-Compatible 适配器**，补齐 **自定义端点 / 模型选择 / 智能 Fallback / 结构化输出与缓存**，而不是引入重型 LangChain 或全面重写。

---

## 2. 现状盘点

### 2.1 架构（已具备的优点）

```
SettingsView
    → AIProviderManager（选主/备 Provider、Keychain 存 Key）
    → AIServiceV2（translate / batchTranslate / skipExisting）
        → AIProviderRegistry（注册 DeepSeek / Gemini / Aliyun / Kimi / GLM）
        → NetworkClient（URLSession、429/5xx 重试、退避）
        → *RequestBuilder / *ResponseParser
```

**做得对的地方：**

1. **配置驱动扩展**：新增 Provider 主要是实现 Builder/Parser + `register`，Settings 自动出现在列表里。
2. **密钥进 Keychain**，并有 UserDefaults → Keychain 迁移逻辑。
3. **批量翻译协议**：JSON 数组 + chunk（默认 40）+ `|||` 遗留兼容，比纯自由文本更稳。
4. **跳过已有译文**（`batchTranslateWithExisting`）适合本地化增量场景。
5. **术语表**注入 prompt（`GlossaryStore`），有基础术语意识。
6. **一层 Fallback**：主 Provider 失败时可切备用。

### 2.2 设置层现状（与截图一致）

API 设置仅暴露：

- **AI 服务**：主 Provider（如 Kimi）
- **Fallback AI Service**：单备用或 None
- **当前 Provider 的 API Key**：SecureField，一次只编辑一个 Provider

缺少：模型名、Base URL、连通性测试、备用 Key 同屏编辑、温度/结构化输出等参数。

### 2.3 已注册 Provider

| ID | 模型（硬编码） | 协议特点 |
|----|----------------|----------|
| deepseek | `deepseek-chat` | OpenAI 兼容 Chat Completions |
| kimi | `moonshot-v1-8k` | OpenAI 兼容 |
| glm | `glm-4.5` | OpenAI 兼容 + thinking |
| aliyun | `qwen-mt-turbo` | 兼容模式 + `translation_options`（专用翻译模型） |
| gemini | `gemini-1.5-flash` | Google 原生 `generateContent`（非 OpenAI 形态） |

**未接入**：OpenAI、Anthropic Claude、Groq、OpenRouter、本地 Ollama 等。

### 2.4 翻译调用路径要点

- 单条：system prompt「翻译成 X，只返回结果」。
- 批量：`BatchTranslationParser.buildPrompt` 要求「只返回 JSON string 数组」。
- Aliyun 走专用 `translation_options`（`source_lang` / `target_lang`），其余走通用 Chat。
- 无流式、无代理配置、无结果缓存、无质量回写。

---

## 3. 相对成熟应用的差距

对照成熟本地化工具与 2026 年常见多 Provider LLM 实践，差距可归为六类。

### 3.1 「按厂商写适配器」成本偏高

DeepSeek / Kimi / GLM 实质都是 **OpenAI Chat Completions 变体**，却各自维护一套 Builder/Parser。成熟做法是：

- **一个 `OpenAICompatibleProvider`**：`baseURL` + `apiKey` + `model` + 可选 header 差异；
- 仅对真正不同的协议写特例（Gemini 原生、阿里云 MT 的 `translation_options`）。

收益：少维护 3～4 份近似代码；用户可自行指向任意兼容网关（OpenRouter、OneAPI、自建 LiteLLM、公司代理）。

### 3.2 缺少「自定义端点 + 模型可选」

成熟桌面/开发者工具（Cursor、Continue、Chatbox、各类翻译 CLI）几乎都支持：

- Base URL（含本地 `http://127.0.0.1:11434/v1`）
- Model 下拉或自由输入
- 可选 Organization / 额外 Headers

本项目模型写死在 Registry，**换模型要改代码发版**，对「Kimi 已升级上下文/新模型」「Gemini 2.x」等场景响应慢。截图中用户只能选服务商，无法选 `moonshot-v1-32k` 或更新模型。

### 3.3 Fallback 偏「有开关、缺策略」

当前逻辑：主失败 → 若有备用且 Key 非空 → 再试一次；HTTP 层另有最多 2 次重试。

成熟方案通常还区分：

| 错误类型 | 建议行为 |
|----------|----------|
| 429 / 5xx / 超时 / 网络 | 应 Fallback / 重试 |
| 401 / 400 / Prompt 解析失败 | **不应**盲目换 Provider（同样会失败或浪费配额） |
| 延迟过高 | 熔断或超时切备用 |
| Fallback 链 | 有序多候选，而非仅一个 |

另外：Settings 只编辑当前 Provider 的 Key，备用 Provider 的 Key 需先切换再填，**易导致「开了 Fallback 但备用无 Key」**。

### 3.4 翻译管线仍偏「通用 Chat，而非翻译产品」

成熟本地化产品常见分层：

1. **专用 MT / 翻译模型**（如 Qwen-MT、DeepL、Google Translate）做高吞吐基线；
2. **LLM** 做语境、语气、占位符保护、术语强制；
3. **术语表硬约束**（不仅是 prompt hint）；
4. **占位符 / ICU / HTML / `.xcstrings` 变量** 校验；
5. **缓存**：相同源文 + 目标语 + glossary hash → 直接命中；
6. **可选人工审校队列**。

本项目批量路径对所有 Provider 几乎同一套 Chat Prompt；Aliyun 的 MT 能力是亮点，但未上升为「路由策略」（例如：大批量默认 MT，短文案/营销文用更强 LLM）。

### 3.5 结构化输出与可靠性

当前依赖模型「听话返回 JSON」。成熟做法常见：

- Provider 支持则用 **JSON Schema / response_format**；
- 解析失败时 **同 Provider 降级重试**（更严 prompt / 更小 chunk），再 Fallback；
- 校验：条数、空串比例、占位符守恒（`%@`、`{name}` 等）。

`chunkSize = 40` 固定，未按模型上下文或历史失败率自适应。

### 3.6 可观测性与成本

成熟多 Provider 应用会记录：Provider、Model、latency、tokens（若可得）、是否 Fallback、失败原因。便于调默认 Provider、控成本、排障。当前主要是 DEBUG 脱敏日志，对「本地化大批量任务」不够。

---

## 4. 成熟方案对照（可借鉴的产品形态）

| 参考类型 | 代表思路 | 对本项目的启示 |
|----------|----------|----------------|
| 统一 LLM 网关 | OpenRouter、LiteLLM、Vercel AI Gateway | App 内可对接网关，或自建「兼容层」；Fallback / 计费外置 |
| 开发者 AI 客户端 | Cursor、Continue、Chatbox | Base URL + Model + Key 三件套是标配 |
| 本地化 SaaS | Crowdin / Phrase / Localazy AI | 术语强制、TM（翻译记忆）、批量任务、质量检查 |
| 开源 i18n AI | Lingo.dev 等 | 文件格式感知 + CI 友好；Provider 可插拔 |
| 专用翻译 API | DeepL、Google Cloud Translation、阿里云 MT | 低成本大批量；LLM 做后处理 |

**对本项目定位的判断**：LanguageTool 是 **本地 macOS 本地化工具（BYOK）**，不宜做成云端翻译平台，也不宜引入重型 Agent 框架。目标应是：

> **桌面端「可配置、可容错、翻译质量可控」的 BYOK 翻译引擎。**

---

## 5. 可选演进方案（2～3 条）

### 方案 A：渐进增强（推荐）

**做法：**

1. 抽出 `OpenAICompatibleAdapter`，DeepSeek / Kimi / GLM（及未来 OpenAI）走同一路径。
2. Provider 配置增加可覆盖字段：`baseURL`、`model`（UserDefaults 覆盖默认值）。
3. Settings：主/备 Provider 均可编辑 Key；增加「测试连接」；可选「自定义 OpenAI 兼容」条目。
4. Fallback：仅对瞬时错误切换；解析失败先缩小 chunk 重试。
5. 增加简单翻译缓存（源文 hash + 目标语 + glossary 版本）。
6. 占位符校验作为 post-check。

**优点：** 改动面可控，与现有 Registry 兼容，立刻提升扩展性与 UX。  
**缺点：** 短期内仍无云端路由/统一计费。  
**适合：** 当前产品阶段。

### 方案 B：内置对接统一网关

**做法：** 默认支持 OpenRouter / 自建 LiteLLM 一类入口，用户填一个 Key 即可用多模型；本地仍保留直连国内 Provider。

**优点：** 模型生态一步到位，Fallback 可部分交给网关。  
**缺点：** 依赖第三方、国内网络与合规需评估；用户心智从「选 Kimi」变成「选网关模型名」。  
**适合：** 面向全球开发者、可接受额外账号体系时。

### 方案 C：双引擎路由（MT + LLM）

**做法：** 大批量 / 简单文案 → Aliyun MT / DeepL；需语境或失败重试 → LLM；术语冲突走 LLM 强制。

**优点：** 成本与质量平衡最好，最接近专业本地化产品。  
**缺点：** 路由规则与评测成本更高，设置更复杂。  
**适合：** 方案 A 落地后的第二阶段。

---

## 6. 推荐落地路线（若后续实施）

建议按优先级分阶段，避免一次大爆炸：

### 完成情况总览（2026-10-08）

| 阶段 | 状态 | Commit | 说明 |
|------|------|--------|------|
| 阶段 1 | ✅ 已完成并 push | `ba079fd` | OpenAI-Compatible 统一层 + Model/Base URL + 自定义 Provider + 测试连接 |
| 阶段 2 | ✅ 已完成并 push | `189abb9` | 错误分类、两级 Fallback 链、降 chunk 重试、备用 Key 同屏 |
| 阶段 3 | ✅ 已完成并 push | `06c8416` | 翻译记忆缓存、占位符/术语校验、大批量 MT 路由 |
| 阶段 4 | ✅ 已完成并 push | `ea8fd0c` | 任务级 metrics、OpenRouter 预设、`docs/AI_GATEWAY_PRESETS.md` |

验证：`swift test` 全绿（42 tests）。分支：`dev`。

### 阶段 1：统一兼容层 + 可配置模型/端点

**状态：✅ 已完成（2026-10-08，`ba079fd`）**

- OpenAI-Compatible 合并重复 Provider 适配器 → `OpenAICompatibleCodec` + `OpenAICompatibleProvider`；DeepSeek/Kimi/GLM/Aliyun 共用
- Settings 支持 model、可选 baseURL → `ProviderEndpointOverrides` + Settings 字段
- 自定义「OpenAI Compatible」Provider → Registry `openai_compatible`
- 测试连接按钮 → `AIServiceV2.testConnection()` + Settings UI

**成功标准：** 用户不改代码即可切 `moonshot-v1-32k` / 指向公司代理；新增兼容厂商无需新 Swift 文件（或仅注册一行配置）。✅

### 阶段 2：可靠 Fallback + 解析韧性

**状态：✅ 已完成（2026-10-08，`189abb9`）**

- 错误分类（瞬时 vs 配置/内容）→ `AIErrorClassifier`
- Fallback 链（≥2）或有序候选 → 主 + Fallback + Fallback 2
- JSON 解析失败 → 降 chunk / 重试 → 再 Fallback → `translateChunkWithResilience`
- 备用 Provider Key 与主 Key 同屏管理 → `providersNeedingVisibleKeys()`

**成功标准：** 主 Provider 429 时自动切备用且不误切 401；批量任务因偶发非 JSON 响应的失败率明显下降。✅（分类逻辑与降块重试已落地）

### 阶段 3：翻译产品质量

**状态：✅ 已完成（2026-10-08，`06c8416`）**

- 翻译记忆 / 结果缓存 → `TranslationMemoryCache`（源文 + 目标语 + glossary fingerprint）
- 占位符与 ICU 校验 → `PlaceholderValidator`（`%@` / `{var}` 等）
- 术语表从「hint」升级为校验或二次修正 → `GlossaryEnforcer`
- 可选：短文案走 LLM、长列表走 MT 的简单路由 → `TranslationRouter`（≥40 且 Aliyun 可用时优先 MT）

**成功标准：** 重复翻译不重复扣费；`%@` / `{var}` 破坏可被检出。✅

### 阶段 4（可选）：可观测与网关

**状态：✅ 已完成（2026-10-08，`ea8fd0c`）**

- 任务级统计（耗时、条数、Fallback 次数）→ `TranslationTaskMetrics` + `TranslationStatistics` 扩展 + 控制台 metrics 行
- 可选 OpenRouter 等统一入口文档与预设 → Registry `openrouter` + `docs/AI_GATEWAY_PRESETS.md` + README 更新

---

## 7. 明确不建议的方向

1. **引入 LangChain / 重型 Agent SDK**：对本项目的「批量字符串翻译」过重，Swift 生态亦不匹配。
2. **放弃 BYOK、改为强制中心化代理**：改变产品信任模型与合规边界，除非明确要做 SaaS。
3. **为每个新模型继续复制一份 Provider 文件**：技术债会持续累积。
4. **无差别对所有错误 Fallback**：浪费配额并掩盖配置错误。

---

## 8. 与现有文档的关系

- `AI_ARCHITECTURE_REFACTORING.md`：描述已完成的 Registry 重构，方向正确，应作为演进基线而非推倒重来。
- 本文：评估「下一跳」应解决的产品与架构代差，**不替代**重构文档。
- 落地执行：第 6 节四阶段已于 2026-10-08 在 `dev` 分支完成并 push；网关说明见 `docs/AI_GATEWAY_PRESETS.md`。

---

## 9. 附录：关键代码入口

| 路径 | 说明 |
|------|------|
| `LanguageTool/Network/AIServiceV2.swift` | 翻译门面、Fallback |
| `LanguageTool/Network/AIProviderConfig.swift` | Registry / Manager |
| `LanguageTool/Network/NetworkClient.swift` | HTTP 重试 |
| `LanguageTool/Network/Providers/*.swift` | 各厂商适配 |
| `LanguageTool/Utilities/BatchTranslationParser.swift` | 批量 Prompt / 解析 |
| `LanguageTool/Views/SettingsView.swift` | API 设置 UI |
| `LanguageTool/Utilities/KeychainService.swift` | Key 存储 |

---

## 10. 总结

当前方案的核心问题不是「没有架构」，而是 **停在「多厂商直连 Chat」这一代**：扩展靠复制适配器、模型写死、Fallback 与翻译质量管线偏薄。

更贴合成熟应用、又适合本仓库的路径是 **方案 A → 阶段 1～3**：以 OpenAI-Compatible 为轴心增强可配置性与容错，再补缓存与格式校验；在需要时再考虑网关（方案 B）或 MT+LLM 路由（方案 C）。

这样可以把「设置里选一个 Kimi、贴一个 Key」升级为「可选模型/端点、可靠降级、可验证的本地化翻译引擎」，而无需推翻现有 `AIServiceV2` 分层。
