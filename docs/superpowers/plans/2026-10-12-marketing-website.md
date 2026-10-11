# LanguageTool Marketing Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship a bilingual marketing + docs static site on Cloudflare Workers Static Assets.

**Architecture:** Pure static HTML/CSS/JS under `website/`, i18n via JSON, product screenshots from ASC assets. Deploy with Wrangler assets-only Worker.

**Tech Stack:** HTML, CSS, vanilla JS, Cloudflare Workers Static Assets, Wrangler.

## Global Constraints

- No GitHub CTA
- App Store primary CTA only
- Brand green `#34C759`
- Avoid Inter/Roboto/Arial/system stacks; avoid purple AI-slop theme
- Phrase AI as connect-your-own-service (no unlock framing)

---

### Task 1: Scaffold website + assets

**Files:**
- Create: `website/wrangler.toml`, `website/package.json`, HTML pages, CSS/JS, i18n JSON
- Copy: hero screenshots into `website/assets/img/`

### Task 2: Polish UI + verify locally

**Steps:**
- `wrangler dev` or open static files; check home/docs/privacy + lang switch

### Task 3: Deploy to workers.dev

**Steps:**
- `npx wrangler deploy` from `website/`
- Report live URL
