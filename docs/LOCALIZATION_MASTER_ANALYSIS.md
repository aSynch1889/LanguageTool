# Localization Master 问题分析与改造方案

> 分析日期：2026-10-08  
> 状态：阶段 1→2 实施中  
> 相关文件：`LocalizationMasterView.swift`、`TransferViewModel.swift`

---

## 1. 结论

Localization Master **功能不完整**（约 30%），目前是「能打开浏览」的实验壳，不是可用的本地化编辑器。表格难看主要来自 AppKit 用法与数据闭环缺失，而不只是缺皮肤。

---

## 2. 功能完整度

| 能力 | 现状 | 问题 |
|------|------|------|
| 打开并解析源文件 | 部分可用 | 窗口使用独立 `TransferViewModel`，语言选择等状态不同步 |
| 表格浏览 / 搜索 | 弱可用 | 能显示；搜索后整表 `reloadData`，体验差 |
| 勾选行翻译 | 半成品 | 「勾选」同时控制是否可编辑，语义混乱 |
| 立即翻译 | 仅内存 | 不写盘；失败只 print；可能把源语言当目标语言翻 |
| 同步到源文件 | 基本错误 | 把 `outputPath` 整文件覆盖到 `inputPath`，**不写表格编辑** |
| 导出 CSV | 与表格脱节 | 读 `outputPath` 文件，不是内存 `translationItems` |
| 新增语言 | 仅内存 | 无法持久化 |
| 保存 / 写回 | 缺失 | 无 xcstrings/arb/json merge 写回 |
| 进度 / 取消 / 脏标记 | 缺失 | 关窗丢改动无提示 |

核心断裂链：

```
表格编辑 → 只改内存 TranslationItem
     ↓
「同步到源文件」→ 忽略内存，复制 output 盖掉 input
「导出」→ 忽略内存，读 output 文件
「立即翻译」→ 只改内存，不落盘
```

---

## 3. 表格 UI 问题根因

位置：`LocalizationMasterView.swift` 中 `NSTableViewRepresentable`

1. **无 cell reuse**：`viewFor` 每次新建 `NSTextField` / `NSButton`
2. **每次 `updateNSView` 都 `reloadData()`**：丢滚动位置、焦点、编辑态，闪烁
3. **裸 TextField**：无边框、不换行、单行截断
4. **未选中行 `alpha=0.5`**：像坏掉/禁用，而非「未参与批量翻译」
5. **复选框语义混乱**：既表示批量范围又锁编辑
6. **源/目标列无区分**；Key 列不冻结；多语言列被压扁
7. **壳层简陋**：长警告条 + 平铺按钮 + 与主界面风格割裂
8. **死代码**：`selection`、`bindingFor*` 等未接到表格
9. **`TranslationItem.id = UUID()`**：reload 后身份不稳定

---

## 4. 架构问题

1. Master 复用 `TransferViewModel`，职责过重  
2. 缺少 `LocalizationDocument`（路径、格式、sourceLanguage、items、dirty、write/merge）  
3. 写回协议未定义：应按 key merge，不能整文件字节拷贝  

---

## 5. 实施路线（阶段 1→2）

### 阶段 1：功能闭环

- [ ] `LocalizationDocument` / Master 专用 VM  
- [ ] 保存写回（xcstrings merge 优先；ARB/JSON）  
- [ ] 同步 = 保存到源路径（或先保存再确认）  
- [ ] 导出 CSV 基于内存 items  
- [ ] 立即翻译：排除源语言；进度/取消  
- [ ] `TranslationItem.id = key`  
- [ ] 复选框只表示批量翻译范围，不锁编辑  

### 阶段 2：表格 UI

- [ ] `makeView(withIdentifier:)` 复用  
- [ ] 禁止编辑中整表 reload；列变化才重建列  
- [ ] 多行文本、源列只读弱背景、目标可编  
- [ ] 空译文标记；更清晰的工具栏/状态条  
- [ ] 清理死代码与冗长 Experimental 文案  

### 阶段 3（可选，本期不做）

- 主从布局、筛选（缺译/已改）、关窗脏检查、与主转换流程深度打通  

---

## 6. 验收标准

1. 编辑表格 → 保存 → 重新打开，内容一致  
2. 导出 CSV 反映当前表格内容  
3. 立即翻译只更新目标语言，且可取消  
4. 表格编辑时不闪烁、不丢焦点；源/目标列可辨  
5. 相关改动以中文 commit 分段 push  
