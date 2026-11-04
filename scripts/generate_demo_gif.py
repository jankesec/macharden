#!/usr/bin/env python3
"""Regenerate assets/demo.gif: a terminal audit followed by a tour of the HTML dashboard.

All data comes from scripts/demo_fixture.sh (synthetic); nothing audits the machine that runs
this script. Requirements: vhs, ffmpeg, Google Chrome (or CHROME_BIN) and Pillow.
Run it through `make demo`, which also refreshes the static images.
"""

import os
import re
import shutil
import sys
import tempfile

from PIL import Image, ImageStat

from demo_lib import (ADDRESS, CANVAS_H, CANVAS_W, CONTENT_H, REPO_ROOT, browser_frame, chrome_binary,
                      ease_in_out, fail, make_dashboard_html, page_metrics, require_tools, run,
                      screenshots_parallel)

TAPE = os.path.join(REPO_ROOT, "assets", "demo.tape")
OUT_GIF = os.path.join(REPO_ROOT, "assets", "demo.gif")
FPS = 7
MAX_MB = 4.0
PALETTE_SIZES = (128, 96, 64)  # tried in this order until the GIF fits MAX_MB (VHS timing varies a little per run)
SCROLL_STEPS = 7


def mean_luma(image):
    """Average brightness (0-255) of an image."""
    return ImageStat.Stat(image.convert("L")).mean[0]


def record_terminal(workdir):
    """Record assets/demo.tape with VHS and return the path of the mp4."""
    out = os.path.join(workdir, "terminal.mp4")
    with open(TAPE, encoding="utf-8") as handle:
        tape = handle.read()
    tape, count = re.subn(r"(?m)^Output .*$", f'Output "{out}"', tape, count=1)
    if count != 1:
        fail("assets/demo.tape needs an Output line")
    tape_path = os.path.join(workdir, "terminal.tape")
    with open(tape_path, "w", encoding="utf-8") as handle:
        handle.write(tape)
    run(["vhs", tape_path], cwd=REPO_ROOT, env=dict(os.environ, MACHAR_DEMO_DELAY="0.02"))
    if not os.path.isfile(out):
        fail("VHS did not produce the terminal clip")
    return out


def dashboard_frames(workdir, html_path, chrome):
    """Capture the dashboard states and return [(PIL image, seconds, caption, theme)] in tour order."""
    metrics = page_metrics(chrome, html_path, workdir)
    target_y = max(metrics["checks_y"] - 230, 0)  # show the tab and filter row above the list
    captures = {  # name -> (javascript run after load, window height)
        "overview": ("window.scrollTo(0,0);", CONTENT_H),
        "playbook": ("openPlaybookModal();", CONTENT_H),
        "turkish": ("toggleLanguage();", CONTENT_H),
        "light": ("toggleTheme();", CONTENT_H),
        "tall": ("", metrics["page_h"]),
        "tall_filtered": ("filterCategory('secrets', false);", metrics["page_h"]),
    }
    paths = screenshots_parallel([
        dict(chrome=chrome, html_path=html_path, out_png=os.path.join(workdir, f"{name}.png"),
             width=CANVAS_W, height=height, script=script)
        for name, (script, height) in captures.items()])
    shots = {name: Image.open(path) for name, path in zip(captures, paths)}
    dark, light = mean_luma(shots["overview"]), mean_luma(shots["light"])
    if dark > 60 or light < 200:  # a capture that is neither fully dark nor fully light was taken mid-change
        fail(f"the theme captures are not in their final state (dark {dark:.0f}, light {light:.0f}); run make demo again")

    def window(image, y):
        y = min(y, image.height - CONTENT_H)
        return image.crop((0, y, CANVAS_W, y + CONTENT_H))

    frames = [(shots["overview"], 1.6, "One self-contained HTML file. No network, no CDN.", "dark")]
    for index in range(1, SCROLL_STEPS + 1):
        last = index == SCROLL_STEPS
        frames.append((window(shots["tall"], round(target_y * ease_in_out(index / SCROLL_STEPS))),
                       1.4 if last else 0.1,
                       "Every finding carries CIS, NIST and MITRE references." if last else None, "dark"))
    frames += [
        (window(shots["tall_filtered"], target_y), 1.5, "Filter by domain, status or severity.", "dark"),
        (shots["playbook"], 1.8, "Review, copy or download the remediation playbook.", "dark"),
        (shots["turkish"], 1.3, "English and Turkish with one key (L).", "dark"),
        (shots["light"], 1.3, "Dark and light themes (T).", "light"),
    ]
    return frames


def build_dashboard_clip(workdir, html_path, chrome):
    """Wrap the dashboard states in a browser window and return the path of their mp4."""
    concat = os.path.join(workdir, "dashboard.txt")
    framed = None
    with open(concat, "w", encoding="utf-8") as handle:
        for index, (image, seconds, caption, theme) in enumerate(dashboard_frames(workdir, html_path, chrome)):
            framed = os.path.join(workdir, f"framed_{index:02d}.png")
            browser_frame(image, ADDRESS, theme, caption).convert("RGB").save(framed)
            handle.write(f"file '{framed}'\nduration {seconds}\n")
        handle.write(f"file '{framed}'\n")  # the concat demuxer needs the last file repeated
    out = os.path.join(workdir, "dashboard.mp4")
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", concat,
         "-vf", f"fps={FPS},format=yuv420p", "-c:v", "libx264", "-crf", "12", out])
    return out


def assemble_gif(terminal_mp4, dashboard_mp4, workdir, colors):
    """Join both clips into one palette-optimized GIF with at most `colors` colors; return its path."""
    gif = os.path.join(workdir, f"demo_{colors}.gif")
    graph = (
        f"[0:v]fps={FPS},scale={CANVAS_W}:{CANVAS_H}:flags=lanczos,setsar=1[a];"
        f"[1:v]fps={FPS},scale={CANVAS_W}:{CANVAS_H}:flags=lanczos,setsar=1[b];"
        "[a][b]concat=n=2:v=1:a=0,split[s0][s1];"
        f"[s0]palettegen=max_colors={colors}:stats_mode=diff[p];"
        "[s1][p]paletteuse=dither=none:diff_mode=rectangle"
    )
    run(["ffmpeg", "-y", "-i", terminal_mp4, "-i", dashboard_mp4, "-filter_complex", graph, "-loop", "0", gif])
    return gif


def main():
    require_tools("vhs", "ffmpeg")
    chrome = chrome_binary()
    with tempfile.TemporaryDirectory(prefix="macharden-demo-") as workdir:
        print("[1/4] Rendering the synthetic dashboard")
        html_path = make_dashboard_html(workdir)
        print("[2/4] Recording the terminal with VHS")
        terminal_mp4 = record_terminal(workdir)
        print("[3/4] Capturing the dashboard tour with Chrome")
        dashboard_mp4 = build_dashboard_clip(workdir, html_path, chrome)
        print("[4/4] Assembling the GIF")
        for colors in PALETTE_SIZES:
            gif = assemble_gif(terminal_mp4, dashboard_mp4, workdir, colors)
            if os.path.getsize(gif) / (1024 * 1024) <= MAX_MB:
                break
        shutil.move(gif, OUT_GIF)
    size_mb = os.path.getsize(OUT_GIF) / (1024 * 1024)
    print(f"wrote {os.path.relpath(OUT_GIF, REPO_ROOT)} ({size_mb:.2f} MB, up to {colors} colors)")
    if size_mb > MAX_MB:
        print(f"warning: larger than {MAX_MB:.0f} MB even with {colors} colors; lower FPS in {os.path.basename(__file__)}",
              file=sys.stderr)


if __name__ == "__main__":
    main()
