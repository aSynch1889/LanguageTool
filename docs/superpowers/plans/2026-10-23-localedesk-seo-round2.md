# LocaleDesk SEO Round 2 Implementation Plan

> **For agentic workers:** Implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ship `/faq/` + `/xcstrings/`, fix i18n meta clobber, strengthen internal links/alts, update sitemap, document www→apex Redirect Rule.

**Architecture:** Static HTML under `website/public/` matching Docs shell; shared `i18n` JSON keys; Cloudflare Dashboard owns www 301.

**Tech Stack:** HTML, CSS, vanilla JS, Workers Static Assets, Wrangler.

## Global Constraints

- English crawl priority; zh via existing i18n body strings
- No blog / arb page / Worker fetch redirect
- App Store URL unchanged (`languagetool` slug)
- Brand green `#34C759`

---

### Task 1: Fix i18n meta + nav/footer keys

**Files:** `website/public/assets/js/i18n.js`, `website/public/i18n/en.json`, `website/public/i18n/zh.json`, `website/public/index.html` (`data-i18n-meta="home"`)

- [ ] Gate title/description apply on `html[data-i18n-meta="home"]`
- [ ] Add `nav.faq`, `faq.*`, `xcstrings.*`, home cross-link strings

### Task 2: Create `/faq/` and `/xcstrings/`

**Files:** `website/public/faq/index.html`, `website/public/xcstrings/index.html`

- [ ] Full SEO head + FAQPage JSON-LD on FAQ
- [ ] Body + i18n keys; CTA + internal links

### Task 3: Wire site-wide links, alts, docs, sitemap

**Files:** all page HTML footers/navs, home alts, docs FAQ teaser, `sitemap.xml`

- [ ] Nav FAQ + footer Docs·FAQ·Privacy
- [ ] Docs link to full FAQ + xcstrings
- [ ] Sitemap entries + lastmod

### Task 4: Document www redirect + deploy

**Files:** `docs/localedesk-site-setup/` note or spec appendix; deploy `website/`

- [ ] Document Cloudflare Redirect Rule steps
- [ ] `npm run deploy`; spot-check URLs
- [ ] Mark spec Implemented
