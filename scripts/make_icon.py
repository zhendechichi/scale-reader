#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate a simple AppIcon (1024x1024 PNG) for ScaleReader.

Run before `xcodegen generate` / building:
    python3 scripts/make_icon.py
Requires Pillow (pip install pillow).
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "ScaleReader",
    "Assets.xcassets",
    "AppIcon.appiconset",
    "AppIcon.png",
)


def lerp(a, b, t):
    return int(a + (b - a) * t)


def main():
    size = 1024
    img = Image.new("RGB", (size, size))
    px = img.load()
    top = (36, 99, 150)      # deep blue
    bottom = (23, 201, 190)  # teal
    for y in range(size):
        t = y / (size - 1)
        r, g, b = lerp(top[0], bottom[0], t), lerp(top[1], bottom[1], t), lerp(top[2], bottom[2], t)
        for x in range(size):
            px[x, y] = (r, g, b)

    # 半透明白色圆角方块，模拟"屏幕"
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    radius = 150
    pad = 210
    d.rounded_rectangle(
        [pad, 360, size - pad, 720], radius=radius, fill=(255, 255, 255, 235)
    )
    # 屏幕上的"刻度"线
    for x0, x1, y in [(330, 480, 470), (330, 560, 545), (330, 500, 620)]:
        w = 34
        d.rounded_rectangle([x0, y - w // 2, x1, y + w // 2], radius=w // 2,
                            fill=(36, 99, 150, 255))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, "PNG")
    print(f"icon written: {OUT} ({os.path.getsize(OUT)} bytes)")


if __name__ == "__main__":
    main()
