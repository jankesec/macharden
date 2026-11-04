"""Shared helpers for the demo asset generators (generate_demo_gif.py, generate_static_assets.py).

Everything rendered here comes from scripts/demo_fixture.sh (synthetic data); nothing inspects
the machine that produces the assets.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("error: Pillow is required (pip install pillow)")

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURE = os.path.join(REPO_ROOT, "scripts", "demo_fixture.sh")
DEFAULT_CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ADDRESS = "file:///Users/demo/report.html"

# The terminal clip (VHS) and the browser clip (Chrome) share one canvas.
CANVAS_W, CANVAS_H = 1200, 840
BAR_H = 44
CONTENT_H = CANVAS_H - BAR_H

PALETTES = {
    "dark": {"bg": (0, 0, 0), "bar": (18, 18, 20), "pill": (34, 34, 37), "text": (160, 160, 166)},
    "light": {"bg": (242, 242, 243), "bar": (232, 232, 234), "pill": (247, 247, 248), "text": (110, 110, 116)},
}


def fail(message):
    sys.exit(f"error: {message}")


def require_tools(*tools):
    hints = {"vhs": "brew install vhs", "ffmpeg": "brew install ffmpeg"}
    for tool in tools:
        if shutil.which(tool) is None:
            fail(f"'{tool}' not found on PATH ({hints.get(tool, 'install it first')})")


def chrome_binary():
    path = os.environ.get("CHROME_BIN", DEFAULT_CHROME)
    if not os.access(path, os.X_OK):
        fail(f"Google Chrome not found at '{path}' (set CHROME_BIN to a Chrome or Chromium binary)")
    return path


def run(cmd, **kwargs):
    """subprocess.run with captured output and a readable error."""
    result = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
    if result.returncode != 0:
        fail(f"command failed ({result.returncode}): {' '.join(map(str, cmd))}\n{result.stderr.strip()}")
    return result


def make_dashboard_html(workdir):
    """Render the synthetic dashboard with the real report generator and sanity-check it."""
    path = os.path.join(workdir, "dashboard.html")
    run([FIXTURE, "html", path], cwd=REPO_ROOT)
    if not os.path.isfile(path):
        fail("demo_fixture.sh did not write the dashboard")
    with open(path, encoding="utf-8") as handle:
        page = handle.read()
    if '"total_checks": 54' not in page:
        fail("the dashboard does not cover 54 checks; is lib/ in sync with the registry?")
    return path


_fonts = {}


def font(size):
    """A TrueType UI font when macOS provides one, otherwise Pillow's built-in font."""
    if size not in _fonts:
        for candidate in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc",
                          "/Library/Fonts/Arial.ttf"):
            try:
                _fonts[size] = ImageFont.truetype(candidate, size)
                break
            except OSError:
                continue
        else:
            _fonts[size] = ImageFont.load_default(size)
    return _fonts[size]


def screenshot(chrome, html_path, out_png, width, height, script="", scale=1):
    """Render html_path to out_png with headless Chrome.

    `script` (JavaScript) runs once the DOM is ready, so a state such as an open modal or an
    active filter can be captured. Without a script the page is rendered in place, which keeps
    relative image paths (the social preview card) working.
    """
    page_path = html_path
    if script:
        with open(html_path, encoding="utf-8") as handle:
            page = handle.read()
        # The empty timer keeps Chrome's virtual clock running, so CSS transitions started by the
        # script (theme switch, modal fade) have finished when the screenshot is taken.
        hook = ("<script>window.addEventListener('DOMContentLoaded', function () {"
                "setTimeout(function () {" + script + "}, 300); setTimeout(function () {}, 1800); });</script>")
        page_path = out_png[:-4] + ".html"
        with open(page_path, "w", encoding="utf-8") as handle:
            handle.write(page.replace("</body>", hook + "</body>"))
    profile = tempfile.mkdtemp(prefix="chrome-profile-", dir=os.path.dirname(out_png))
    run([
        chrome, "--headless", "--disable-gpu", "--hide-scrollbars",
        f"--user-data-dir={profile}",
        f"--screenshot={out_png}",
        f"--window-size={width},{height}",
        f"--force-device-scale-factor={scale}",
        "--virtual-time-budget=2500",
        f"file://{page_path}",
    ])
    if not os.path.isfile(out_png):
        fail(f"Chrome did not produce {out_png}")
    return out_png


def screenshots_parallel(jobs, workers=4):
    """jobs: list of keyword-argument dicts for screenshot(); returns the PNG paths in order."""
    with ThreadPoolExecutor(max_workers=workers) as pool:
        return list(pool.map(lambda job: screenshot(**job), jobs))


def page_metrics(chrome, html_path, workdir):
    """Where #checksContainer starts and how tall the dashboard is, read from a headless DOM dump.

    A headless screenshot of a scrolled page can come out black (the newly exposed area is not
    rasterized yet), so scrolling is simulated by cropping one tall screenshot instead.
    """
    with open(html_path, encoding="utf-8") as handle:
        page = handle.read()
    hook = ("<script>window.addEventListener('DOMContentLoaded',function(){setTimeout(function(){"
            "var r=document.documentElement;"
            "r.setAttribute('data-checks-y',String(Math.round(document.getElementById('checksContainer')"
            ".getBoundingClientRect().top+window.scrollY)));"
            "r.setAttribute('data-page-h',String(document.documentElement.scrollHeight));},300);});</script>")
    probe = os.path.join(workdir, "metrics.html")
    with open(probe, "w", encoding="utf-8") as handle:
        handle.write(page.replace("</body>", hook + "</body>"))
    profile = tempfile.mkdtemp(prefix="chrome-profile-", dir=workdir)
    dom = run([chrome, "--headless", "--disable-gpu", f"--user-data-dir={profile}", "--window-size=1200,800",
               "--virtual-time-budget=2500", "--dump-dom", f"file://{probe}"]).stdout
    checks_y = re.search(r'data-checks-y="(\d+)"', dom)
    page_h = re.search(r'data-page-h="(\d+)"', dom)
    if not checks_y or not page_h:
        fail("could not measure the dashboard layout (is #checksContainer still in the report?)")
    return {"checks_y": int(checks_y.group(1)), "page_h": min(int(page_h.group(1)), 16000)}


def add_caption(image, text, scale=1):
    """A small pill near the bottom centre that says what the viewer is looking at."""
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    caption_font = font(18 * scale)
    text_w = draw.textlength(text, font=caption_font)
    pad_x, pad_y = 20 * scale, 11 * scale
    box_w, box_h = int(text_w) + pad_x * 2, 18 * scale + pad_y * 2
    x = (image.width - box_w) // 2
    y = image.height - box_h - 28 * scale
    draw.rounded_rectangle([(x, y), (x + box_w, y + box_h)], radius=box_h // 2, fill=(15, 15, 25, 215))
    draw.text((x + pad_x, y + pad_y - scale), text, fill=(235, 238, 250, 255), font=caption_font)
    return Image.alpha_composite(image, overlay)


def browser_frame(content, address, theme="dark", caption=None, scale=1):
    """Wrap a Chrome screenshot in a macOS-style window with traffic lights and an address pill."""
    palette = PALETTES[theme]
    shot = (content if isinstance(content, Image.Image) else Image.open(content)).convert("RGBA")
    bar = BAR_H * scale
    canvas = Image.new("RGBA", (shot.width, shot.height + bar), palette["bg"] + (255,))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle([(0, 0), (shot.width, bar)], fill=palette["bar"])
    for index, color in enumerate(((255, 95, 86), (255, 189, 46), (39, 201, 63))):
        x = (18 + index * 20) * scale
        draw.ellipse([(x, 16 * scale), (x + 12 * scale, 28 * scale)], fill=color)
    pill_w = 520 * scale
    pill_x = (shot.width - pill_w) // 2
    draw.rounded_rectangle([(pill_x, 8 * scale), (pill_x + pill_w, 36 * scale)], radius=7 * scale, fill=palette["pill"])
    label_font = font(13 * scale)
    text_w = draw.textlength(address, font=label_font)
    draw.text(((shot.width - text_w) / 2, 14 * scale), address, fill=palette["text"], font=label_font)
    canvas.paste(shot, (0, bar))
    if caption:
        canvas = add_caption(canvas, caption, scale)
    return canvas


def ease_in_out(t):
    return t * t * (3 - 2 * t)
