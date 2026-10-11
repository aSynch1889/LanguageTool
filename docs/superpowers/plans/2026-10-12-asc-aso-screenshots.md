# ASC ASO Screenshots Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Produce 9 Mac App Store marketing PNGs at 2880×1800 from existing UI captures (en-US, zh-Hans, zh-Hant × convert/review/clean).

**Architecture:** One Pillow compositor script reads locale copy + source paths from the approved spec, paints a light green-wash background, optional caption, and a centered rounded app window with soft shadow.

**Tech Stack:** Python 3, Pillow, system CJK fonts (Hiragino Sans GB / Arial Unicode).

---

### Task 1: Compositor script

**Files:**
- Create: `scripts/compose_asc_screenshots.py`

**Steps:**
1. Implement canvas 2880×1800, brand `#34C759`, captioned + clean modes.
2. Wire source paths under `docs/iamges/{英语,简体中文,繁体中文}/`.
3. Write outputs to `metadata/screenshots/mac/2880x1800/{locale}/`.
4. Run script; verify all 9 files are exactly 2880×1800.

### Task 2: Visual spot-check

**Steps:**
1. Open/inspect generated PNGs for clipping, contrast, padding.
2. Tweak font sizes/margins in script if needed; re-run.
3. Update design spec status to Implemented.
