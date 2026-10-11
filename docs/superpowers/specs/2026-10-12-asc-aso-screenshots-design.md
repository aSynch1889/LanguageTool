# ASC ASO Marketing Screenshots Design

**Status**: Implemented  
**Date**: 2026-10-12  
**App**: LanguageTool (macOS)  
**Target**: App Store Connect version 1.2.0 Mac screenshots

## Decisions

| Topic | Choice |
|-------|--------|
| Settings / API Key shot | **Excluded** (Guideline 3.1.1 sensitivity) |
| Locales produced | **en-US, zh-Hans, zh-Hant** from native UI captures |
| Other ASC locales | **Reuse en-US** set at upload time |
| Shot count / mix | **3 per locale**: captioned Convert, captioned Review, clean full-window |
| Visual approach | **Light caption bar** (not split poster, not device bezel) |

## Canvas & Format

- Size: **2880 × 1800** px (ASC Mac 16:10; sharpest accepted size)
- Format: **PNG**, RGB, flattened (no alpha)
- Brand accent: `#34C759`
- Background: near-white / light gray with a very subtle green wash
- Avoid: purple gradients, heavy multi-layer shadows, fake UI, “unlock/Pro/paid” copy

## Source Assets

Located under `docs/iamges/` (existing folder name):

| Locale folder | Convert | Review | Settings (do not use) |
|---------------|---------|--------|------------------------|
| `英语` | `…00-18-21.png` | `…00-18-27.png` | `…00-19-41.png` |
| `简体中文` | `…00-17-52.png` | `…00-18-00.png` | `…00-18-07.png` |
| `繁体中文` | `…00-18-51.png` | `…00-18-57.png` | `…00-19-07.png` |

Source window captures are ~1800×1304 (not 16:10). Marketing frames will letterbox/scale them onto the 2880×1800 canvas.

## Layout

### Shots 1 & 2 (captioned)

- Top ~18%: headline (+ optional short subhead)
- Bottom ~78%: real app window, rounded corners, light drop shadow, generous padding
- Headline: keyword-forward, feature-true, no API/payment language

### Shot 3 (clean)

- Convert window only, slightly larger, centered
- No marketing headline
- Same background treatment for series consistency

## Copy

| Locale | Shot 1 (Convert) | Shot 2 (Review) | Optional subhead |
|--------|------------------|-----------------|------------------|
| en-US | Batch localize iOS, Flutter & Electron | Review translations before you ship | Skip existing strings · Export & sync |
| zh-Hans | 批量本地化 iOS / Flutter / Electron | 导出前审阅与校对译文 | 跳过已有翻译 · 导出同步 |
| zh-Hant | 批量本地化 iOS / Flutter / Electron | 匯出前審閱與校對譯文 | 跳過既有翻譯 · 匯出同步 |

## Output Paths

```
metadata/screenshots/mac/2880x1800/
  en-US/
    01-convert.png
    02-review.png
    03-clean.png
  zh-Hans/
    01-convert.png
    02-review.png
    03-clean.png
  zh-Hant/
    01-convert.png
    02-review.png
    03-clean.png
```

Upload note: for de-DE, es-ES, fr-FR, it, ja, ko, pt-BR, th, tr, reuse `en-US/` files unless localized UI captures are added later.

## Compliance Notes

- Guideline **2.3.3**: framed UI must be the real shipping app (source screenshots only).
- Guideline **3.1.1**: do not feature Settings/API Key or “unlock with key” messaging in store art.
- Captions describe localization workflow only.

## Out of Scope

- App Preview video
- iPhone/iPad sizes (Mac app)
- Generating fake multilingual UI for the other 9 ASC locales
- Pushing screenshots to ASC via CLI (user uploads)

## Implementation Plan (after spec approval)

1. Build a deterministic compositor (Python/Pillow or similar) — preferred over freeform image gen for exact 2880×1800 and crisp text.
2. Render 9 PNGs into the output paths above.
3. Verify dimensions with `sips` / `file`.
4. Spot-check visual quality; adjust padding/type if needed.
