# LanguageTool Marketing Website Design

**Status**: Approved  
**Date**: 2026-10-12  
**Deploy**: Cloudflare Workers + Static Assets (`*.workers.dev`)

## Goals

- Product marketing homepage + light docs/help
- zh/en bilingual (browser default + manual toggle)
- Strong UI/UX; App Store as sole primary CTA (no GitHub for now)

## Decisions

| Topic | Choice |
|-------|--------|
| Scope | Marketing home + docs + privacy |
| Stack | Static HTML/CSS/JS in `website/` |
| Hosting | Workers Static Assets → workers.dev |
| CTA | Mac App Store only |
| Locales | `zh` / `en`, `?lang=` + `localStorage` |

## Information Architecture

| Path | Purpose |
|------|---------|
| `/` | Hero, capabilities, workflow, closing CTA |
| `/docs/` | Requirements, getting started, FAQ |
| `/privacy/` | Short privacy policy for ASC / users |

## Homepage Sections

1. **Hero** — Brand name as hero signal; one headline; one supporting line; App Store CTA; dominant product screenshot (reuse ASC marketing art).
2. **Capabilities** — Convert / Review / Multi-platform (one job each).
3. **Workflow** — Platform → languages → convert → review/export.
4. **Closing CTA** — App Store again.

Out of scope on home: stats strips, card grids, API-key “unlock” messaging, GitHub links.

## Docs Content (short)

- System requirements (macOS 13+)
- Get from Mac App Store
- Three-step getting started
- FAQ: skip existing, review, formats
- Phrase AI as “connect your own translation service” (3.1.1-aware)

## Visual Direction

- Brand green `#34C759`
- Soft green-tinted atmosphere (not flat white, not purple gradients)
- Expressive display type + clear body face (avoid Inter/Roboto/Arial/system stacks)
- Motions: hero fade/rise; workflow step reveal; light lang-switch transition
- Responsive desktop + mobile; full-bleed hero treatment on small screens

## Technical Layout

```
website/
  index.html
  docs/index.html
  privacy/index.html
  assets/css/site.css
  assets/js/i18n.js
  assets/js/site.js
  assets/img/          # screenshots / icon
  i18n/en.json
  i18n/zh.json
  wrangler.toml
  package.json         # optional scripts for deploy
```

## Deployment

- `wrangler deploy` (or equivalent) from `website/`
- Custom domain later; not required for v1
- App Store URL: placeholder or search link until official `apps.apple.com` URL confirmed

## Success Criteria

- [ ] Home reads as one branded composition in first viewport
- [ ] zh/en toggle works and persists
- [ ] Docs + privacy reachable from nav
- [ ] Live on Cloudflare workers.dev
- [ ] No GitHub CTA; no API unlock framing
