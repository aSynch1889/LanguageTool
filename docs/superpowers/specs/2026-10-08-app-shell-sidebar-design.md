# 设计：单窗口侧栏整合（方案 A）

> 日期：2026-10-08  
> 状态：已确认（§1–§3）  
> 目标：消除主窗口「转换」与 Localization Master「审阅」的产品割裂，并暴露设置 / 语言 / 外观快捷入口

---

## 1. 背景与问题

当前应用是：

- **主窗口**：`WindowGroup` → `ContentView` → `TransferView`（向导式批量转换）
- **审阅**：`TransferViewModel` 手写 `NSWindow` 打开 `LocalizationMasterView`
- **设置**：仅系统 Settings 场景（⌘, / 菜单），无主界面入口
- **语言 / 深色**：仅 Settings 内；Master 窗口不统一应用 `preferredColorScheme`

结果：普通用户难找设置；转换与审阅像两个产品；主窗交互偏长卡片流。

用户确认采用 **方案 A：单窗口 + 侧栏**。

---

## 2. 目标与非目标

### 目标

1. 单一主壳：`NavigationSplitView`（或等价侧栏）承载「转换」「审阅」
2. 转换成功或用户选择「在审阅中打开」→ **切侧栏并载入文档**，默认不再弹独立 Master 窗
3. 工具栏暴露：设置、界面语言、外观（浅色 / 深色 / 跟随系统）
4. 侧栏「设置…」与工具栏 ⚙ 均打开系统 Settings
5. 主壳统一外观；转换与审阅共用

### 非目标（首版不做）

- 重做转换页视觉（压扁卡片可作为后续小步）
- 默认「在新窗口打开审阅」（可作为后续可选进阶）
- 把完整 Settings（API Key / Glossary）内嵌进侧栏 Detail
- 改 AI 翻译管线或 Master 表格内核（仅迁入壳子与入口）

---

## 3. 信息架构

```text
┌──────────────┬─────────────────────────────────────┐
│ 转换          │  Detail                             │
│ 审阅          │  · sidebar == .transfer → Transfer  │
│              │  · sidebar == .review   → Master    │
│ ──────────── │                                     │
│ 设置…         │  （触发 openSettings，不占 Detail）   │
└──────────────┴─────────────────────────────────────┘
工具栏右侧：⚙ 设置 · 语言菜单 · 外观菜单
```

| 侧栏 | Detail | 备注 |
|------|--------|------|
| 转换 | 现有 Transfer 流程 | 默认首页 |
| 审阅 | Localization Master | 无文档时空态 |
| 设置… | 无 | 打开系统 Settings 窗口 |

---

## 4. 导航与跨页行为

1. **转换成功** → `sidebar = .review`，并向审阅 VM 载入 **输出路径（优先）** 或源路径  
2. **转换页「在审阅中打开 / 查看」** → 同上，**禁止**再走默认 `NSWindow` Master  
3. **审阅空态** → 「去转换」（`sidebar = .transfer`）与「打开文件…」  
4. **脏文档**：切走审阅或关主窗前沿用现有未保存确认  
5. **窗口尺寸**：默认建议约 `1000×700`（可微调）；可保留 `.hiddenTitleBar` 或改为标准标题栏+工具栏（实现时选一种，优先工具栏可用性）

---

## 5. 工具栏与外观

| 控件 | 行为 |
|------|------|
| ⚙ | `openSettings()` / `SettingsLink` |
| 语言 | 写入 `appLanguage`，列表与 Settings 一致；可保留「可能需重启」提示 |
| 外观 | **浅色 / 深色 / 跟随系统** |

存储：新增 `appearanceMode`（如 `system` | `light` | `dark`），迁移旧 `isDarkMode`（`true`→`dark`，`false`→`system` 或 `light`，实现时选定一种并写清）。主壳 `.preferredColorScheme` 绑定该模式。

完整 API / Glossary / 通知仍在 `SettingsView`。

---

## 6. 组件与职责

| 组件 | 职责 |
|------|------|
| `AppShellView`（新） | `NavigationSplitView` + toolbar；持有侧栏选中态 |
| `AppShellViewModel`（新，可选） | `sidebar`、`pendingReviewURL` / platform 交接 |
| `ContentView` | 改为嵌入 Shell，或被 Shell 取代为根 |
| `TransferView` / `TransferViewModel` | 保留转换逻辑；打开审阅改为回调/通知壳层；移除默认 `NSWindow` Master |
| `LocalizationMasterView` / VM | 作为审阅 Detail；适配无独立窗口 chrome |
| `LanguageToolApp` | 根为 Shell；Settings 场景保留；`defaultSize` 调整 |

数据流（转换 → 审阅）：

```text
Transfer 完成
  → Shell 收到 (url, platform)
  → sidebar = .review
  → Master VM load(url)
```

---

## 7. 文案与入口替换

| 旧 | 新 |
|----|----|
| Localization Master（新窗口） | 在审阅中打开 |
| Review in Master | 在审阅中查看 |
| 仅菜单 Settings | 工具栏 ⚙ + 侧栏「设置…」 |

---

## 8. 测试与验收

- [ ] 冷启动进入「转换」
- [ ] 转换成功自动进入「审阅」且能看到结果文件内容
- [ ] 「在审阅中打开」不创建第二窗
- [ ] ⚙ 与侧栏设置打开 Settings
- [ ] 工具栏切换语言写入 `appLanguage`
- [ ] 外观三态立即作用于主窗（转换+审阅）
- [ ] 审阅 dirty 时切换/关闭有确认
- [ ] 现有逻辑单测（`swift test`）仍通过

---

## 9. 实施顺序（供后续 plan）

1. Shell + 侧栏路由空壳，Detail 先嵌现有 Transfer  
2. 审阅页迁入 Detail；拆除默认 `NSWindow`  
3. 转换 → 审阅交接  
4. 工具栏：设置 / 语言 / 外观三态  
5. 空态、文案、默认窗口尺寸、回归  

---

## 10. 已确认决策

- 方案 **A**（单窗口侧栏）  
- 设置保持 **系统 Settings 窗**，不内嵌 Detail  
- 外观含 **跟随系统**  
- 首版 **不做** 默认多窗审阅；转换页大改版可后置  
