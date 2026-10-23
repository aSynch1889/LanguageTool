# LocaleDesk SEO Round 2 Design

**Status**: Implemented  
**Date**: 2026-10-23  
**Site**: https://localedesk.cc  
**Priority**: English / Google (UI i18n zh still supported)  
**Depends on**: Technical SEO foundation (2026-10-22), now live

## Goal

Small dual track: **1–2 crawlable content pages** + **site hygiene** (canonical host, internal links, richer alts / FAQ schema). No blog, no `/en` path split, no Baidu-specific work.

## Approach

**Approach 1 (approved):** Static HTML pages + Cloudflare Dashboard Redirect Rule for `www` → apex. No Worker `fetch` logic.

---

## 1. New pages

### 1.1 `/faq/`

| Item | Spec |
|------|------|
| Path | `website/public/faq/index.html` |
| Purpose | Capture question-style queries; consolidate FAQs that today sit only under Docs |
| Shell | Same nav / footer / fonts / `site.css` as Docs |
| Language | Default English HTML + `data-i18n` keys in `en.json` / `zh.json` |
| Canonical | `https://localedesk.cc/faq/` |
| Schema | JSON-LD `@type: FAQPage` with the same Q&A as visible content (English strings in schema; matches default crawl language) |

**FAQ topics (6–8, English source of truth):**

1. What is LocaleDesk?  
2. Which formats are supported? (`.xcstrings` / `.strings` / `.arb` / Electron `.json`)  
3. Do I need an API key? (BYOK — not sold by LocaleDesk)  
4. Do I need Xcode?  
5. Does it run fully on my Mac?  
6. macOS version requirements  
7. How is this different from editing spreadsheets / String Catalog alone?  
8. Where do I download it? (App Store CTA)

Docs page may keep a short FAQ section or link “See all FAQs → `/faq/`” to avoid duplicate thin blocks (prefer link-out if Docs FAQ is nearly identical).

### 1.2 `/xcstrings/`

| Item | Spec |
|------|------|
| Path | `website/public/xcstrings/index.html` |
| Purpose | Long-tail page for “xcstrings / String Catalog batch translate / localize on Mac” |
| Structure | H1 + short definition → how LocaleDesk helps (Convert / Review) → who it’s for → CTA (App Store) + link to Docs + FAQ |
| Length | ~400–700 English words equivalent via short sections (not a blog essay) |
| Canonical | `https://localedesk.cc/xcstrings/` |
| Schema | Optional `SoftwareApplication` or omit (homepage already has app schema). Prefer **no duplicate** app schema; page-level OG only. |
| Internal links | → `/`, `/docs/`, `/faq/`, App Store |

Copy tone: developer-clear, no keyword stuffing; natural use of *xcstrings*, *String Catalog*, *iOS localization*, *batch translate*.

---

## 2. Technical hygiene

### 2.1 Sitemap

Update `website/public/sitemap.xml`:

- Add `https://localedesk.cc/faq/` (`priority` 0.7, `changefreq` monthly)  
- Add `https://localedesk.cc/xcstrings/` (`priority` 0.8, `changefreq` monthly)  
- Bump `lastmod` on touched URLs to deploy date  

### 2.2 Head / social

Each new page: `title`, `meta description`, `canonical`, `og:*`, `twitter:*` (same pattern as Docs/Privacy).  
`og:image`: reuse `https://localedesk.cc/assets/img/hero-convert.png`.

### 2.3 i18n meta overwrite fix (required)

Today `i18n.js` always applies `meta.title` / `meta.description` from the shared JSON, which **clobbers** page-specific `<title>` / description on Docs (and would break FAQ / xcstrings SEO).

**Fix:** Only apply document title + meta description when `<html data-i18n-meta="home">` (homepage). Other pages keep static head tags; body copy still uses `data-i18n`.

Alternatively: page-scoped keys (`faq.meta.title`) selected via `data-page="faq"` — acceptable if cleaner; **minimum bar** is “non-home pages must not inherit home meta.”

### 2.4 Internal links

| Location | Change |
|----------|--------|
| Nav (all pages) | Add link **FAQ** → `/faq/` (or put FAQ only in footer if nav feels crowded — prefer **footer + Docs cross-link**; add nav FAQ if space OK) |
| Footer | Links: Docs · FAQ · Privacy · (optional) xcstrings as “String Catalog” text only on home/docs |
| Home | In Multi-platform / capabilities copy or a one-line under cap3: link to `/xcstrings/` |
| Docs | Link to `/faq/` and `/xcstrings/` where formats are mentioned |

**Decision for nav:** Footer always has FAQ; primary nav adds FAQ next to Docs (5 chars — OK).

### 2.5 Image alt text

Strengthen existing alts (en defaults in HTML; zh via optional `data-i18n-alt` only if already easy — else English alts are enough for Google):

- Hero: mention Convert + localization files / platforms  
- Review: mention review table / missing strings  

No new screenshots required this round.

### 2.6 www → apex 301

| Item | Spec |
|------|------|
| Rule | `https://www.localedesk.cc/*` → `https://localedesk.cc/$1` (301) |
| Where | Cloudflare Dashboard → **Rules** → **Redirect Rules** (or Single Redirects) for zone `localedesk.cc` |
| Code | **Not** in Worker; document steps in this spec + short note under `docs/localedesk-site-setup/` or README snippet |
| Keep | `wrangler.toml` may still list `www` custom domain so the hostname resolves for the redirect to fire; if CF recommends otherwise, apex-only + redirect at edge is fine |

After rule is live: verify `curl -I https://www.localedesk.cc/` → `301` + `Location: https://localedesk.cc/`.

**Operator (user):** create the Redirect Rule once; agent documents exact clicks and verifies if credentials allow, else user confirms.

---

## 3. Out of scope

- Blog / `/blog/`  
- Separate `/flutter-arb/` page (later)  
- Baidu / CN search engines  
- Path-based `/en/` `/zh/` URLs or `hreflang`  
- Performance pass (fonts subset, image compression) — Round 3 candidate  
- Changing App Store product URL slug / ASC metadata  

---

## 4. Deploy & GSC

1. Deploy `website/` via existing `npm run deploy`.  
2. In GSC: submit/refresh sitemap; URL Inspection optional for `/faq/` and `/xcstrings/`.  
3. Request indexing on the two new URLs after Live test OK.

---

## 5. Success criteria

- [ ] `/faq/` and `/xcstrings/` return 200 on production with unique titles/descriptions  
- [ ] Sitemap lists both; robots still points at sitemap  
- [ ] FAQPage JSON-LD present and valid (no mismatch with visible Qs)  
- [ ] Non-home pages no longer get homepage `<title>` from i18n  
- [ ] Footer (+ nav) link to FAQ; home/docs link to xcstrings  
- [ ] www→apex 301 documented; live if user/agent applied rule  
- [ ] Design + implementation committed on `dev`  

---

## 6. Spec self-review

| Check | Result |
|-------|--------|
| Placeholders | None intentional; App Store URL remains existing `languagetool` slug |
| Contradictions | Nav “FAQ vs footer-only” resolved: **both** |
| Ambiguity | www rule is Dashboard-owned — called out |
| Scope | No blog/arb/perf — YAGNI held |
| Existing overlap | Docs FAQ → link to `/faq/` to reduce duplication |
