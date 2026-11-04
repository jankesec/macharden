#!/usr/bin/env python3
"""Regenerate assets/dashboard.png and assets/social-preview.png from the synthetic fixture.

The dashboard screenshot is wrapped in a browser window; the social preview card
(scripts/social_preview.html, 1280x640) embeds that screenshot. Requirements: Google Chrome
(or CHROME_BIN) and Pillow. Run it through `make demo`, which also refreshes the GIF.
"""

import os
import tempfile

from PIL import Image

from demo_lib import ADDRESS, REPO_ROOT, browser_frame, chrome_binary, make_dashboard_html, screenshot

DASHBOARD_PNG = os.path.join(REPO_ROOT, "assets", "dashboard.png")
SOCIAL_PNG = os.path.join(REPO_ROOT, "assets", "social-preview.png")
SOCIAL_TEMPLATE = os.path.join(REPO_ROOT, "scripts", "social_preview.html")
WINDOW_W, WINDOW_H = 1400, 960  # CSS pixels; the page ends right after the remediation banner
SCALE = 2
OUT_W = 1800
MAX_BYTES = 600_000


def save_png(image, path):
    """Save an optimized PNG; fall back to a 256-color palette when the file is too large."""
    rgb = image.convert("RGB")
    rgb.save(path, optimize=True)
    if os.path.getsize(path) > MAX_BYTES:
        rgb.quantize(colors=256, method=Image.Quantize.MEDIANCUT,
                     dither=Image.Dither.FLOYDSTEINBERG).save(path, optimize=True)


def main():
    chrome = chrome_binary()
    with tempfile.TemporaryDirectory(prefix="macharden-static-") as workdir:
        html_path = make_dashboard_html(workdir)
        raw = screenshot(chrome, html_path, os.path.join(workdir, "dashboard_raw.png"), WINDOW_W, WINDOW_H,
                         script="window.scrollTo(0,0);", scale=SCALE)
        framed = browser_frame(raw, ADDRESS, "dark", None, SCALE)
        framed = framed.resize((OUT_W, round(framed.height * OUT_W / framed.width)), Image.Resampling.LANCZOS)
        save_png(framed, DASHBOARD_PNG)  # the social card embeds this file, so it is written first
        card = screenshot(chrome, SOCIAL_TEMPLATE, os.path.join(workdir, "social_raw.png"), 1280, 640)
        save_png(Image.open(card), SOCIAL_PNG)
    for path in (DASHBOARD_PNG, SOCIAL_PNG):
        print(f"wrote {os.path.relpath(path, REPO_ROOT)} ({os.path.getsize(path) / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
