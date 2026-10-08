# LanguageTool 项目问题分析与优化方案

> 分析日期：2026-10-07  
> 范围：仓库全量代码与工程结构  
> 目标：梳理现存问题、不合理设计与优化点，并给出可落地的解决方案（**本文不包含代码改动**）

---

## 1. 项目概览

LanguageTool 是一款 macOS 本地化辅助工具：读取 iOS（`.xcstrings` / `.strings`）、Flutter（`.arb`）、Electron（`.json`）源文件，调用 AI 平台批量翻译，再按平台规范写出本地化文件。

当前主流程：

```
ContentView → TransferView → TransferViewModel
  → LocalizationConversionService
    → 平台解析器（JsonUtils / StringsFileParser / ARB / Electron）
    → AIServiceV2.batchTranslate* → NetworkClient → Provider
  → 写出目标文件
```

AI 层已完成一次较合理的重构（`AIServiceV2` + `AIProviderRegistry` + Keychain），方向正确。当前风险主要集中在：**批量翻译协议脆弱、解析路径不统一、工程卫生差、零自动化测试**。

---

## 2. 问题总览（按优先级）

| 优先级 | 数量 | 典型影响 |
|--------|------|----------|
| P0 严重 | 4 | 错误翻译映射、成功显示为失败、工程无法正确打开 |
| P1 高 | 7 | 功能残缺、构建不稳定、安全面扩大 |
| P2 中 | 11 | 体验差、可维护性差、部分功能不可靠 |
| P3 低 | 6 | 代码味道、文档滞后、次要 UX |

建议推进顺序：**正确性 → 工程卫生 → 安全 → 测试 → 功能收尾/性能**。

---

## 3. P0 — 严重问题

### 3.1 批量翻译分隔符协议脆弱

**位置：** `LanguageTool/Network/AIServiceV2.swift`（`batchTranslate` / `parseBatchTranslationResponse`）

**现象：**

- 将多条文案用 `|||` 拼接后交给模型，再按 `|||` 拆分。
- 拆分后过滤空段（`.filter { !$0.isEmpty }`），一旦模型多/少分隔符、插入解释文字、或某段译为空串，会出现：
  - 抛出 `invalidResponse`，或
  - **更危险：键与译文错位但流程仍“成功”**。
- 无按 token/条数分块，大词表易触达上下文上限或响应被截断。

**解决方案：**

1. 改用结构化输出：JSON 数组或 `{ "key": "译文" }` 映射，按索引/键做 1:1 校验。
2. 固定分块（如每批 20–50 条），失败只重试该块。
3. 禁止过滤空段造成位移；空译文显式标记为 `needs_review`。
4. 短期内若保留 `|||`，至少：严格校验段数 == 输入数，不等则整批失败并重试。

---

### 3.2 成功结果在 UI 上被当成失败

**位置：** `LanguageTool/Views/TransferView.swift`（约 362–368 行）

**现象：**

- UI 用 `conversionResult.hasPrefix("✅")` 判断成功样式。
- 实际成功文案多为英文本地化串，如 `"Conversion successful!"`、`"Successfully generated..."`，**不含 ✅**。
- 失败文案常带 `"❌ ..."`。结果是：转换成功时结果区仍显示红色叉号（虽可能仍出现成功操作按钮）。

**解决方案：**

1. UI 完全依赖 `executionResult.success`（或引入 `enum ConversionOutcome { case success(String); case failure(String) }`）。
2. 禁止用 emoji / 字符串前缀表达业务状态。
3. 统一各 Handler 的返回类型为结构化结果，而不是裸 `String`。

---

### 3.3 双 Xcode 工程，其中一个已损坏

**位置：**

- 可用：`LanguageTool.xcodeproj`
- 损坏：`L18nTools.xcodeproj`（无 `project.pbxproj`，仅残留 workspace/userdata）

**现象：** 贡献者打开错误工程会直接失败；README 也未明确“以哪个工程为准”。

**解决方案：**

1. 删除 `L18nTools.xcodeproj`，或在文档中明确废弃。
2. README / README-zh 写明：请打开 `LanguageTool.xcodeproj`。

---

### 3.4 根目录孤儿依赖与真实依赖不一致

**位置：**

- 根目录 `Package.resolved`：钉住 CoreXLSX / XMLCoder / ZIPFoundation（**应用未使用**）
- `.build/`：仍有上述包的 checkout
- 真实依赖：`LanguageTool.xcodeproj` → SPM `swift-syntax`（**branch = main**）
- 根目录空文件 `Info.plist`（1 字节）；真实配置在 `LanguageTool/Info.plist`

**解决方案：**

1. 删除根目录 `Package.resolved`、空 `Info.plist`，清理无用 `.build`。
2. 将 `swift-syntax` 钉到稳定版本 tag（不要 `main`）。
3. 核对 `.gitignore`：`Package.resolved` 忽略规则与已跟踪文件冲突，统一策略。

---

## 4. P1 — 高优先级

### 4.1 `TranslationManager` 的 xcstrings 模型与 Apple 格式不符

**位置：** `LanguageTool/Models/TranslationManager.swift`（`parseXCStrings`）

**现象：**

- 从可选字段 `entry.source.stringUnit` 读源文。
- 真实 String Catalog（如仓库内 `Localizable.xcstrings`）源文通常在 `localizations[sourceLanguage]`。
- 主转换路径 `JsonUtils.extractValuesFromXCStrings` 已正确处理；**Master / reload 路径未对齐**。

**影响：** `LocalizationMasterView` 经常看不到源文或条目不完整。

**解决方案：**

1. 统一只保留一套解析实现（以 `JsonUtils` 逻辑为准）。
2. 删除或改写 `TranslationManager` 内错误 Codable 模型。
3. 用真实 xcstrings 样例做单测覆盖两种结构（`source` 字段 vs `localizations[sourceLanguage]`）。

---

### 4.2 无自动化测试

**现象：**

- 无 XCTest / Swift Testing target。
- 仅有手动脚本 `scripts/p0_mapping_check.swift`。

**解决方案：**

1. 新增 `LanguageToolTests` target。
2. 优先覆盖：xcstrings 提取/生成、`.strings` 解析、batch 响应解析、ARB/Electron 键序对齐、Keychain 迁移。
3. 将 `p0_mapping_check` 思路迁入 CI 可跑的单元测试。

---

### 4.3 `swift-syntax` 跟踪 `main` 且功能未接入 UI

**位置：** `project.pbxproj`；`LanguageTool/StringScannerCore/Core.swift`

**现象：** 依赖重、构建可能随 upstream 变动；扫描能力未接到主界面。

**解决方案（二选一）：**

- A：版本钉死，并把扫描做成独立可选 target / 菜单功能。  
- B：若短期内不做扫描，从 App target 移除依赖，减小体积与构建风险。

---

### 4.4 ATS 完全放开

**位置：** `LanguageTool/Info.plist` — `NSAllowsArbitraryLoads = true`

**现象：** 当前 AI 端点均为 HTTPS，无需全局任意加载。

**解决方案：** 删除该开关；若确有例外域名，再按域名白名单配置。

---

### 4.5 Gemini API Key 放在 Query String

**位置：** `AIServiceV2.buildHTTPConfig`（queryParameter 认证）

**现象：** Key 出现在 URL 中，易进入代理日志、崩溃报告、系统诊断。DEBUG 日志虽有脱敏，但 URL 本身仍携带密钥。

**解决方案：**

1. 优先改用 Header 认证（若 Gemini 端点支持）。
2. 必须用 query 时：严禁打印原始 URL；注意 URL 编码。
3. 统一审计所有 Provider 的密钥传递方式。

---

### 4.6 Provider 注册职责分裂

**位置：**

- `AIProviderRegistry.setupDefaultProviders()` 为空实现
- 真正注册在 `AIServiceV2.setupDefaultProviders()`
- App 启动靠 `_ = AIServiceV2.shared` 触发

**现象：** 初始化顺序一变，Settings 可能读到空注册表。

**解决方案：** 注册只发生在 Registry 初始化；`AIServiceV2` 仅消费配置。去掉“靠副作用初始化”的隐式依赖。

---

### 4.7 `AIProviderConfig.model` 形同虚设

**现象：** 注册时写了 `model`，各 Provider 的 RequestBuilder 仍硬编码模型名；改配置不生效。

**解决方案：** 构建请求时从 config 注入 `model`；Settings 可提供模型覆盖（可选高级项）。

---

## 5. P2 — 中优先级

### 5.1 死代码与遗留模块

| 项 | 路径 | 建议 |
|----|------|------|
| Demo 页 | `Views/DeepseekDemo.swift` | 删除或移入 Debug-only |
| DeepSeek 专用壳 | `Models/AppSettings.swift` | 删除，统一走 `AIProviderManager` |
| 近重复提取函数 | `JsonUtils.extractChineseKeys*` | 合并为一个 API |
| 未使用写文件助手 | `LocalizationJSONGenerator` 部分方法 | 删除或接入 |
| 未使用变量 | `LocalizationMasterView.remainingTrials` | 删除 |
| 空 SwiftData Schema | `LanguageToolApp.swift` | 不用则移除 ModelContainer / fatalError |
| 未接线扫描器 | `StringScannerCore` | 接线或剥离 |
| 注释掉的 New Window | `TransferView.swift` | 恢复或删 TODO |

---

### 5.2 仓库内本地化文件混乱

**现象：**

- 跟踪中的 `Localizable.xcstrings`
- 本地还存在 `Localizable1/2/_副本.xcstrings`（已在 gitignore，但仍占磁盘、易改错）

**解决方案：** 只保留一份正式 catalog；删除备份副本；文档说明编辑入口。

---

### 5.3 CSV 导出 BOM 无效

**位置：** `TransferViewModel` 导出逻辑

**现象：** 先写 BOM，再用 atomic UTF-8 写入覆盖，BOM 丢失。

**解决方案：** 一次写入 `Data(bom) + utf8Body`。

---

### 5.4 应用内语言切换不可靠

**位置：** `LocalizationManager` + String Catalog

**现象：** 通过改 `AppleLanguages` 切换语言，对 String Catalog 常需重启才生效；Master 视图还有硬编码中文文案。

**解决方案：**

1. 明确“改语言后需重启”，或改用自建字符串表即时刷新。
2. Master 视图全部走 `.localized`。

---

### 5.5 目标语言提示词不一致

**现象：** 有的路径传 `"Japanese"`，有的传 `"ja"`，翻译质量与术语一致性不稳定。

**解决方案：** 统一传「语言代码 + 本地化全名」（例如 `ja (Japanese)`），各平台共用同一 prompt 模板。

---

### 5.6 网络重试无退避

**位置：** `NetworkClient`

**现象：** 429 / 5xx 立即重试，易加剧限流。

**解决方案：** 指数退避 + jitter；对 429 尊重 `Retry-After`（若有）。

---

### 5.7 `@StateObject` 包裹共享单例

**位置：** `SettingsView`

**现象：** 对 `AIProviderManager.shared` 使用 `@StateObject` 不符合 SwiftUI 生命周期约定。

**解决方案：** 改为 `@ObservedObject` 或通过 `EnvironmentObject` / 依赖注入传入。

---

### 5.8 错误被吞掉，部分失败像成功

**现象：**

- `TranslationManager.parseInputFile` 任意错误返回 `[]`
- 批量某语言失败时可能留下空串 / `needs_review` 并继续，用户难以察觉

**解决方案：** 向上抛出或汇总 `PartialFailure` 报告（成功 N / 失败 M / 待审 K）；UI 明确展示。

---

### 5.9 Localization Master 功能不完整

**现象：** 「立即翻译」多在内存更新；「同步到源文件」更像文件字节拷贝，易丢编辑。

**解决方案：**

- 短期：在 UI 标明「实验性 / 未完成」，或从主入口隐藏。
- 中期：定义明确的写回 xcstrings 协议（按 key merge localization），并加确认与备份。

---

### 5.10 术语表过于简陋

**位置：** `UserDefaults` 字符串 `translationGlossary`

**解决方案：** 结构化词条（源→目标）、长度限制、按语言可选；注入 prompt 前做校验。

---

### 5.11 长任务无法取消

**现象：** 大批量翻译无取消；Master 里串行 await 可能卡 UI。

**解决方案：** 使用 `Task` 取消令牌；转换按钮变为「取消」；分语言并发但限制并发度（如 2–3）。

---

## 6. P3 — 低优先级

1. **强制解包 / fatalError：** `TranslationManager` 正则 `Range(...)!`、空 SwiftData 容器 `fatalError` — 改为安全失败。
2. **生产环境 print 过多：** 可能泄露用户文案；改分级日志（os.Logger），Release 默认关闭正文。
3. **`Language.id = UUID()`：** `Identifiable` 不稳定；建议 `id == code`。
4. **阿拉伯语归入 `.african`：** 分类修正为中东/闪米特语系等更合理标签。
5. **文档滞后：** `AI_ARCHITECTURE_REFACTORING.md` 仍描述旧删除列表与空 Registry；与 Kimi/GLM 现状不同步 — 归档或更新。
6. **`.gitignore` 重复条目：** 清理重复的 Localizable 备份规则。

---

## 7. 安全现状小结

| 项 | 状态 | 动作 |
|----|------|------|
| API Key 存 Keychain | 良好 | 保持；继续完成迁移路径测试 |
| 源码硬编码密钥 | 未发现 | 保持审查 |
| DEBUG 请求脱敏 | 较好 | 保持 |
| ATS 任意加载 | 偏弱 | 关闭 |
| Gemini Key 在 URL | 偏弱 | 改 Header 或禁日志 |
| 沙盒权限 | 合理 | 保持 user-selected files + network |

---

## 8. 架构与可维护性优化

### 8.1 平台转换逻辑重复

iOS / Flutter / Electron 四套 Handler 各自拼 prompt、调 batch、写文件，行为略有漂移。

**方案：** 抽一层 `TranslationPipeline`：

```
Parse → Chunk → Translate → Validate → Write
```

平台只实现 `Parser` + `Writer`；翻译与校验共用。

### 8.2 依赖注入替代单例丛林

`AIServiceV2.shared`、`AIProviderManager.shared`、`NetworkClient.shared`、`LocalizationManager.shared` 增加了测试难度。

**方案：** 协议 + 构造注入；App 入口组装一次；测试用 Fake Provider。

### 8.3 结果类型统一

用 `Result` / 自定义 enum 贯通 Service → ViewModel → View，消灭「用字符串前缀表示状态」。

### 8.4 性能方向（正确性之后）

1. 分块 + 有限并发翻译多语言。
2. `skipExisting` 增量合并已有，但避免每次整文件重走 AI。
3. 缓存 HTTP 配置；评估移除未用 SwiftSyntax 以减小体积。

---

## 9. 建议实施路线图（仍不写代码）

### 阶段 A：正确性急救（1–2 天量级）

- [x] 批量翻译改为结构化输出 + 分块 + 段数校验  
- [x] UI 成功/失败改用 `success` 标志  
- [x] 统一 xcstrings 解析（Master 与主流程）  

**成功标准：** 大词表试跑无错位；成功转换显示绿色；Master 能正确显示源文。

### 阶段 B：工程卫生（0.5–1 天）

- [x] 删除/废弃 `L18nTools.xcodeproj`、根 `Package.resolved`、空 `Info.plist`、Demo/死代码  
- [x] 钉死或移除 `swift-syntax`  
- [x] 清理备份 xcstrings  
- [x] 更新 README 打开方式  

**成功标准：** 干净 clone 后只打开一个工程即可构建。

### 阶段 C：安全与韧性（1 天）

- [x] 关闭 ATS 任意加载  
- [x] Gemini 密钥离开 URL（或强化）  
- [x] 网络退避重试  
- [x] 部分失败汇总展示  

### 阶段 D：测试与 CI（1–2 天）

- [x] 建立测试 target（`Package.swift` + `swift test`）  
- [x] 覆盖解析 / batch / 术语表逻辑  
- [ ] 可选：GitHub Actions `xcodebuild test`（未做，非阻塞）  

### 阶段 E：产品收尾（按需）

- [x] Localization Master 标为 Experimental 并重新入口暴露  
- [x] 移除 String Scanner + swift-syntax  
- [x] 术语表结构化（`GlossaryStore`）  
- [x] 取消长任务 + 语言并发限流  
- [x] 移除空 SwiftData  

> Localization Master 改造见 [`docs/LOCALIZATION_MASTER_ANALYSIS.md`](docs/LOCALIZATION_MASTER_ANALYSIS.md)（阶段 1→3 已完成：写回闭环、表格 UI、主从布局/筛选/关窗脏检查/转换后审阅）。

---

## 10. 结论

项目在 **AI Provider 可扩展架构与 Keychain 密钥管理** 上已经走在正确方向。当前真正影响用户与贡献者的，是：

1. **批量翻译协议不可靠**（可能静默错译）  
2. **成功态 UI 判断错误**  
3. **解析实现双轨不一致**  
4. **工程/依赖脏乱 + 零测试**  

建议先做阶段 A–B，再进入安全与测试；Master / Scanner 等半成品功能在未完成前应降权或隐藏，避免扩大问题面。

---

## 附录：关键文件索引

| 主题 | 文件 |
|------|------|
| 批量翻译 | `LanguageTool/Network/AIServiceV2.swift` |
| 网络层 | `LanguageTool/Network/NetworkClient.swift` |
| Provider 配置 | `LanguageTool/Network/AIProviderConfig.swift` |
| 主转换入口 | `LanguageTool/Utilities/LocalizationConversionService.swift` |
| xcstrings（正确路径） | `LanguageTool/Utilities/JsonUtils.swift` |
| xcstrings（错误路径） | `LanguageTool/Models/TranslationManager.swift` |
| 结果 UI | `LanguageTool/Views/TransferView.swift` |
| ViewModel | `LanguageTool/ViewModels/TransferViewModel.swift` |
| 设置 | `LanguageTool/Views/SettingsView.swift` |
| App 入口 | `LanguageTool/LanguageToolApp.swift` |
| ATS | `LanguageTool/Info.plist` |
| 架构说明（部分过时） | `AI_ARCHITECTURE_REFACTORING.md` |
