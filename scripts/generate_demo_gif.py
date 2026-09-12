#!/usr/bin/env python3
"""
scripts/generate_demo_gif.py
Automated high-fidelity demo generator for macharden.
Combines:
  1. Enriched terminal CLI audit execution (recorded with VHS)
  2. Liquid Glass HTML5 interactive dashboard walkthrough (rendered via headless Chrome & PIL)
Privacy boundary:
  Uses scripts/demo_fixture.sh only; it never audits the generating Mac.
Outputs:
  assets/demo.gif (1200x800, optimized 192-color palette)
"""

import os
import shutil
import subprocess
import tempfile
from PIL import Image, ImageDraw

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TMP_DIR = tempfile.mkdtemp(prefix="macharden-demo-")

W, H = 1200, 800
BAR_H = 44
CONTENT_H = H - BAR_H

def generate_report_html():
    print("[*] Generating a deterministic report with synthetic audit data...")
    report_file = os.path.join(TMP_DIR, "demo_report.html")
    subprocess.run(
        [os.path.join(REPO_ROOT, "scripts", "demo_fixture.sh"), "html", report_file],
        cwd=REPO_ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=True,
    )
    return report_file

def capture_html_frames(report_html_path):
    print("[*] Capturing interactive HTML dashboard keyframes via Google Chrome...")
    with open(report_html_path, "r", encoding="utf-8") as f:
        base_html = f.read()

    states = [
        ("frame1_overview", ""),
        ("frame2_checks", "<script>window.addEventListener('DOMContentLoaded', () => { setTimeout(() => { window.scrollTo({top: 540, behavior: 'instant'}); }, 400); });</script>"),
        ("frame3_secrets", "<script>window.addEventListener('DOMContentLoaded', () => { setTimeout(() => { filterCategory('secrets'); }, 400); });</script>"),
        ("frame4_playbook", "<script>window.addEventListener('DOMContentLoaded', () => { setTimeout(() => { openPlaybookModal(); }, 400); });</script>"),
        ("frame5_light", "<script>window.addEventListener('DOMContentLoaded', () => { setTimeout(() => { toggleTheme(); }, 400); });</script>")
    ]

    chrome_bin = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    browser_frames = []

    for name, inject in states:
        tmp_html = os.path.join(TMP_DIR, f"{name}.html")
        with open(tmp_html, "w", encoding="utf-8") as f:
            f.write(base_html.replace("</body>", inject + "</body>"))

        raw_shot = os.path.join(TMP_DIR, f"raw_{name}.png")
        cmd = [
            chrome_bin,
            "--headless",
            "--disable-gpu",
            f"--screenshot={raw_shot}",
            f"--window-size={W},{CONTENT_H}",
            "--virtual-time-budget=1200",
            f"file://{tmp_html}"
        ]
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)

        # Composite macOS Browser Window
        is_light = (name == "frame5_light")
        bg_color = (240, 242, 245, 255) if is_light else (24, 24, 37, 255)
        header_color = (225, 228, 234) if is_light else (30, 30, 46)
        pill_color = (245, 246, 248) if is_light else (17, 17, 27)
        text_color = (108, 115, 130) if is_light else (166, 173, 200)

        canvas = Image.new("RGBA", (W, H), bg_color)
        draw = ImageDraw.Draw(canvas)

        # Title bar
        draw.rectangle([(0, 0), (W, BAR_H)], fill=header_color)

        # Traffic lights
        draw.ellipse([(18, 16), (30, 28)], fill=(255, 95, 86))
        draw.ellipse([(38, 16), (50, 28)], fill=(255, 189, 46))
        draw.ellipse([(58, 16), (70, 28)], fill=(39, 201, 63))

        # URL pill
        pill_w = 460
        pill_x = (W - pill_w) // 2
        draw.rounded_rectangle([(pill_x, 8), (pill_x + pill_w, 36)], radius=6, fill=pill_color)

        # Padlock icon
        lock_x = pill_x + 16
        draw.rectangle([(lock_x, 20), (lock_x + 8, 27)], fill=text_color)
        draw.arc([(lock_x + 1, 14), (lock_x + 7, 22)], 180, 0, fill=text_color, width=2)

        # URL text
        draw.text((lock_x + 16, 14), "https://security.local/macharden/report.html", fill=text_color)

        # Paste webview
        if os.path.exists(raw_shot):
            shot_img = Image.open(raw_shot).convert("RGBA")
            if shot_img.size != (W, CONTENT_H):
                shot_img = shot_img.resize((W, CONTENT_H), Image.Resampling.LANCZOS)
            canvas.paste(shot_img, (0, BAR_H))

        out_frame = os.path.join(TMP_DIR, f"browser_{name}.png")
        canvas.save(out_frame)
        browser_frames.append(out_frame)

    return browser_frames

def render_html_clip(frames):
    print("[*] Rendering HTML dashboard video clip with ffmpeg...")
    concat_txt = os.path.join(TMP_DIR, "html_concat.txt")
    with open(concat_txt, "w") as f:
        f.write(f"file '{frames[0]}'\nduration 2.2\n")
        f.write(f"file '{frames[1]}'\nduration 1.8\n")
        f.write(f"file '{frames[2]}'\nduration 1.8\n")
        f.write(f"file '{frames[3]}'\nduration 2.2\n")
        f.write(f"file '{frames[4]}'\nduration 1.6\n")
        f.write(f"file '{frames[4]}'\n")

    html_mp4 = os.path.join(TMP_DIR, "html_clip.mp4")
    cmd = [
        "ffmpeg", "-y",
        "-f", "concat", "-safe", "0", "-i", concat_txt,
        "-vf", "scale=1200:800:flags=lanczos,setsar=1,fps=12,format=yuv420p",
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        html_mp4
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
    return html_mp4

def render_term_clip():
    print("[*] Recording terminal session with VHS...")
    tape_content = f"""Output "{os.path.join(TMP_DIR, 'term_clip.mp4')}"

Set Shell "zsh"
Set FontSize 15
Set Width 1200
Set Height 800
Set Padding 24
Set WindowBar Colorful
Set Theme "Catppuccin Mocha"
Set LineHeight 1.2
Set TypingSpeed 24ms
Set CursorBlink true

Hide
Type "export PS1='%F{{cyan}}audit-demo@demo-mac%f %F{{magenta}}~/macharden%f %# '; alias macharden='./scripts/demo_fixture.sh'; clear"
Enter
Sleep 600ms
Show

Sleep 600ms
Type "macharden --check HARD-01,HARD-02,HARD-18,NET-01,NET-10,SEC-03"
Sleep 240ms
Enter
Sleep 5.2s
"""
    tape_file = os.path.join(TMP_DIR, "terminal.tape")
    with open(tape_file, "w") as f:
        f.write(tape_content)

    env = os.environ.copy()
    env["MACHAR_DEMO_DELAY"] = "1"
    subprocess.run(
        ["vhs", tape_file], cwd=REPO_ROOT, env=env,
        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True,
    )
    return os.path.join(TMP_DIR, "term_clip.mp4")

def combine_into_gif(term_mp4, html_mp4, output_gif):
    print(f"[*] Combining terminal and dashboard clips into {output_gif}...")
    filter_complex = (
        "[0:v]fps=12,scale=1200:800:flags=lanczos,setsar=1[v0];"
        "[1:v]fps=12,scale=1200:800:flags=lanczos,setsar=1[v1];"
        "[v0][v1]concat=n=2:v=1:a=0,split[s0][s1];"
        "[s0]palettegen=max_colors=192:stats_mode=diff:reserve_transparent=0[p];"
        "[s1][p]paletteuse=dither=bayer:bayer_scale=2:diff_mode=rectangle"
    )
    cmd = [
        "ffmpeg", "-y",
        "-i", term_mp4,
        "-i", html_mp4,
        "-filter_complex", filter_complex,
        output_gif
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
    size_mb = os.path.getsize(output_gif) / (1024 * 1024)
    print(f"[✔] Successfully generated {output_gif} ({size_mb:.2f} MB)")

if __name__ == "__main__":
    try:
        rep = generate_report_html()
        frames = capture_html_frames(rep)
        html_clip = render_html_clip(frames)
        term_clip = render_term_clip()
        final_gif = os.path.join(REPO_ROOT, "assets", "demo.gif")
        combine_into_gif(term_clip, html_clip, final_gif)
    finally:
        shutil.rmtree(TMP_DIR, ignore_errors=True)
