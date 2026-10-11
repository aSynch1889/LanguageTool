#!/usr/bin/env python3
"""Compose Mac App Store marketing screenshots at 2880x1800.

Source captures: docs/iamges/{英语,简体中文,繁体中文}/
Output: metadata/screenshots/mac/2880x1800/{en-US,zh-Hans,zh-Hant}/
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "docs/iamges"
OUT = ROOT / "metadata/screenshots/mac/2880x1800"

W, H = 2880, 1800
BRAND = (52, 199, 89)  # #34C759

LOCALES = {
    "en-US": {
        "folder": "英语",
        "convert": "Snipaste_2026-10-12_00-18-21.png",
        "review": "Snipaste_2026-10-12_00-18-27.png",
        "h1_convert": "Batch localize iOS, Flutter & Electron",
        "h1_review": "Review translations before you ship",
        "sub": "Skip existing strings · Export & sync",
    },
    "zh-Hans": {
        "folder": "简体中文",
        "convert": "Snipaste_2026-10-12_00-17-52.png",
        "review": "Snipaste_2026-10-12_00-18-00.png",
        "h1_convert": "批量本地化 iOS / Flutter / Electron",
        "h1_review": "导出前审阅与校对译文",
        "sub": "跳过已有翻译 · 导出同步",
    },
    "zh-Hant": {
        "folder": "繁体中文",
        "convert": "Snipaste_2026-10-12_00-18-51.png",
        "review": "Snipaste_2026-10-12_00-18-57.png",
        "h1_convert": "批量本地化 iOS / Flutter / Electron",
        "h1_review": "匯出前審閱與校對譯文",
        "sub": "跳過既有翻譯 · 匯出同步",
    },
}

FONT_CANDIDATES = [
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/Library/Fonts/Arial Unicode.ttf",
]


def load_font(size: int, index: int = 0) -> ImageFont.ImageFont:
    for path in FONT_CANDIDATES:
        p = Path(path)
        if not p.exists():
            continue
        try:
            if p.suffix.lower() == ".ttc":
                return ImageFont.truetype(str(p), size=size, index=index)
            return ImageFont.truetype(str(p), size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def make_background() -> Image.Image:
    img = Image.new("RGB", (W, H), (248, 250, 249))
    draw = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        r = int(245 + (236 - 245) * t)
        g = int(250 + (242 - 250) * t)
        b = int(247 + (240 - 247) * t)
        if y < H * 0.35:
            u = 1 - (y / (H * 0.35))
            r = int(r * (1 - 0.04 * u) + BRAND[0] * 0.04 * u)
            g = int(g * (1 - 0.06 * u) + BRAND[1] * 0.06 * u)
            b = int(b * (1 - 0.04 * u) + BRAND[2] * 0.04 * u)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse([W - 900, -400, W + 200, 700], fill=(*BRAND, 28))
    od.ellipse([-300, H - 700, 700, H + 200], fill=(52, 199, 89, 18))
    return Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")


def rounded_window(src: Image.Image, max_w: int, max_h: int, radius: int = 28) -> Image.Image:
    src = src.convert("RGBA")
    scale = min(max_w / src.width, max_h / src.height)
    nw, nh = int(src.width * scale), int(src.height * scale)
    src = src.resize((nw, nh), Image.Resampling.LANCZOS)

    mask = Image.new("L", (nw, nh), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, nw - 1, nh - 1], radius=radius, fill=255)
    out = Image.new("RGBA", (nw, nh), (0, 0, 0, 0))
    out.paste(src, (0, 0))
    out.putalpha(mask)

    border = Image.new("RGBA", (nw, nh), (0, 0, 0, 0))
    bd = ImageDraw.Draw(border)
    bd.rounded_rectangle([0, 0, nw - 1, nh - 1], radius=radius, outline=(0, 0, 0, 28), width=2)
    return Image.alpha_composite(out, border)


def add_shadow(
    card: Image.Image,
    blur: int = 36,
    offset: tuple[int, int] = (0, 18),
    opacity: int = 70,
) -> Image.Image:
    pad = blur * 2 + abs(offset[0]) + abs(offset[1]) + 8
    canvas = Image.new("RGBA", (card.width + pad * 2, card.height + pad * 2), (0, 0, 0, 0))
    alpha = card.split()[-1]
    sh = Image.new("RGBA", card.size, (20, 30, 25, opacity))
    sh.putalpha(alpha.point(lambda a: min(255, int(a * opacity / 255))))
    canvas.paste(sh, (pad + offset[0], pad + offset[1]), sh)
    canvas = canvas.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(card, (pad, pad), card)
    return canvas


def text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def draw_caption(base: Image.Image, title: str, sub: str) -> None:
    layer = base.convert("RGBA")
    draw = ImageDraw.Draw(layer)
    title_font = load_font(72, index=1)
    sub_font = load_font(36, index=0)

    title_w, title_h = text_size(draw, title, title_font)
    sub_w, _ = text_size(draw, sub, sub_font)

    cx = W // 2
    title_y = 96
    bar_w, bar_h = 72, 8
    draw.rounded_rectangle(
        [cx - bar_w // 2, title_y - 28, cx + bar_w // 2, title_y - 28 + bar_h],
        radius=4,
        fill=(*BRAND, 255),
    )
    draw.text((cx - title_w // 2, title_y), title, font=title_font, fill=(28, 32, 30, 255))
    draw.text((cx - sub_w // 2, title_y + title_h + 18), sub, font=sub_font, fill=(90, 98, 94, 255))
    base.paste(layer.convert("RGB"))


def compose(
    src_path: Path,
    out_path: Path,
    title: str | None,
    sub: str | None,
    clean: bool,
) -> None:
    bg = make_background()
    caption_band = 0 if clean else 260

    max_w = int(W * (0.88 if clean else 0.86))
    max_h = int((H - caption_band - 80) * (0.96 if clean else 0.92))

    src = Image.open(src_path)
    card = rounded_window(src, max_w=max_w, max_h=max_h, radius=30)
    shadowed = add_shadow(card, blur=40, offset=(0, 22), opacity=80)

    if clean:
        x = (W - shadowed.width) // 2
        y = (H - shadowed.height) // 2
    else:
        x = (W - shadowed.width) // 2
        y = caption_band + (H - caption_band - shadowed.height) // 2 - 10

    canvas = bg.convert("RGBA")
    canvas.paste(shadowed, (x, y), shadowed)
    final = canvas.convert("RGB")

    if not clean and title and sub:
        draw_caption(final, title, sub)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    final.save(out_path, format="PNG", optimize=True)
    print(f"wrote {out_path.relative_to(ROOT)} ({final.size[0]}x{final.size[1]})")


def main() -> None:
    for locale, cfg in LOCALES.items():
        folder = SRC / cfg["folder"]
        convert = folder / cfg["convert"]
        review = folder / cfg["review"]
        if not convert.exists():
            raise FileNotFoundError(convert)
        if not review.exists():
            raise FileNotFoundError(review)
        base = OUT / locale
        compose(convert, base / "01-convert.png", cfg["h1_convert"], cfg["sub"], clean=False)
        compose(review, base / "02-review.png", cfg["h1_review"], cfg["sub"], clean=False)
        compose(convert, base / "03-clean.png", None, None, clean=True)


if __name__ == "__main__":
    main()
