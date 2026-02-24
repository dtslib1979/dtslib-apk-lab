#!/usr/bin/env python3
"""
Parksy Liner Engine — Photo → Sketch Pipeline
XDoG edge detection + shade extraction + fixed canvas output

Dependencies: numpy (pkg install python-numpy), Pillow (pkg install python-pillow)
No OpenCV required.

Output per image:
  {name}_line_rgba.png       — 선화 (transparent BG)
  {name}_shade_rgba.png      — 음영 (transparent BG)
  {name}_combo_for_notes.png — Samsung Notes용 합성 (white BG)
  {name}_preview_debug.png   — 4-panel 디버그 프리뷰
  {name}_prompt.json         — AI 스타일링 프롬프트 메타
"""

import sys
import os
import json
import time
from datetime import datetime

try:
    import numpy as np
except ImportError:
    print("[ERROR] numpy 필요: pkg install python-numpy")
    sys.exit(1)

try:
    from PIL import Image, ImageFilter
except ImportError:
    print("[ERROR] Pillow 필요: pkg install python-pillow")
    sys.exit(1)

# ═══════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════

CANVAS_W = 2160
CANVAS_H = 3060

LINE_COLOR = (0xC3, 0xC3, 0xC3)     # #C3C3C3
LINE_ALPHA_MIN = int(255 * 0.70)     # 178
LINE_ALPHA_MAX = int(255 * 0.85)     # 216

SHADE_COLOR = (0xC8, 0xC8, 0xC8)    # #C8C8C8
SHADE_ALPHA_MIN = int(255 * 0.25)    # 63
SHADE_ALPHA_MAX = int(255 * 0.45)    # 114

# XDoG parameters
XDOG_SIGMA = 0.5
XDOG_K = 1.6
XDOG_P = 20.0
XDOG_EPSILON = 0.01
XDOG_PHI = 10.0


# ═══════════════════════════════════════════════════
# Image I/O via Pillow
# ═══════════════════════════════════════════════════

def read_image(path):
    """Read image → RGB numpy array (H, W, 3) uint8."""
    img = Image.open(path).convert('RGB')
    return np.array(img)


def write_rgba_png(path, rgba_array):
    """RGBA numpy (H,W,4) uint8 → PNG."""
    Image.fromarray(rgba_array, 'RGBA').save(path)


def write_rgb_png(path, rgb_array):
    """RGB numpy (H,W,3) uint8 → PNG."""
    Image.fromarray(rgb_array, 'RGB').save(path)


def to_gray(rgb):
    """RGB uint8 → grayscale float64 [0,1]."""
    return np.dot(rgb.astype(np.float64), [0.2989, 0.5870, 0.1140]) / 255.0


# ═══════════════════════════════════════════════════
# Gaussian blur (separable, numpy-only)
# ═══════════════════════════════════════════════════

def _make_kernel_1d(sigma):
    """1D Gaussian kernel."""
    radius = int(np.ceil(sigma * 3))
    if radius < 1:
        radius = 1
    x = np.arange(-radius, radius + 1, dtype=np.float64)
    k = np.exp(-x ** 2 / (2.0 * sigma ** 2))
    return k / k.sum()


def gaussian_blur(img, sigma):
    """Separable Gaussian blur on 2D float64 array."""
    if sigma < 0.3:
        return img.copy()
    k = _make_kernel_1d(sigma)
    pad = len(k) // 2
    # Horizontal pass
    padded = np.pad(img, ((0, 0), (pad, pad)), mode='reflect')
    h_out = np.zeros_like(img)
    for i in range(len(k)):
        h_out += padded[:, i:i + img.shape[1]] * k[i]
    # Vertical pass
    padded = np.pad(h_out, ((pad, pad), (0, 0)), mode='reflect')
    v_out = np.zeros_like(img)
    for i in range(len(k)):
        v_out += padded[i:i + img.shape[0], :] * k[i]
    return v_out


# ═══════════════════════════════════════════════════
# XDoG Edge Detection
# ═══════════════════════════════════════════════════

def xdog_edge(gray, sigma=XDOG_SIGMA, k=XDOG_K,
              epsilon=XDOG_EPSILON, phi=XDOG_PHI):
    """
    eXtended Difference of Gaussians.
    Returns float64 [0,1]: 0 = strong edge, 1 = background.
    """
    g1 = gaussian_blur(gray, sigma)
    g2 = gaussian_blur(gray, sigma * k)
    dog = g1 - g2

    result = np.where(
        dog >= epsilon,
        1.0,
        1.0 + np.tanh(phi * (dog - epsilon))
    )
    return np.clip(result, 0.0, 1.0)


# ═══════════════════════════════════════════════════
# Shade extraction
# ═══════════════════════════════════════════════════

def extract_shade(gray):
    """
    Tonal shade map from grayscale.
    Returns float64 [0,1]: higher = darker area.
    """
    shade = 1.0 - gray
    shade = gaussian_blur(shade, 8.0)

    smin, smax = shade.min(), shade.max()
    if smax - smin > 0.01:
        shade = (shade - smin) / (smax - smin)
    else:
        shade = np.zeros_like(shade)

    shade[shade < 0.2] = 0.0
    return shade


# ═══════════════════════════════════════════════════
# Letterbox fit to fixed canvas
# ═══════════════════════════════════════════════════

def letterbox_fit(pil_img, tw=CANVAS_W, th=CANVAS_H):
    """
    Pillow Image → resized + padded to (tw, th). Returns (PIL Image, scale, ox, oy).
    """
    w, h = pil_img.size
    scale = min(tw / w, th / h)
    nw, nh = int(w * scale), int(h * scale)
    resized = pil_img.resize((nw, nh), Image.LANCZOS)

    canvas = Image.new('RGB', (tw, th), (0, 0, 0))
    ox = (tw - nw) // 2
    oy = (th - nh) // 2
    canvas.paste(resized, (ox, oy))
    return canvas, scale, ox, oy


# ═══════════════════════════════════════════════════
# Build output layers
# ═══════════════════════════════════════════════════

def build_line_rgba(edge_map):
    """Edge map (0=edge,1=bg) → RGBA uint8."""
    h, w = edge_map.shape
    strength = 1.0 - edge_map  # 1=strong edge
    mask = strength > 0.1

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[mask, 0] = LINE_COLOR[0]
    rgba[mask, 1] = LINE_COLOR[1]
    rgba[mask, 2] = LINE_COLOR[2]

    alpha = strength * (LINE_ALPHA_MAX - LINE_ALPHA_MIN) + LINE_ALPHA_MIN
    alpha *= mask
    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    return rgba


def build_shade_rgba(shade_map):
    """Shade map → RGBA uint8."""
    h, w = shade_map.shape
    mask = shade_map > 0.05

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[mask, 0] = SHADE_COLOR[0]
    rgba[mask, 1] = SHADE_COLOR[1]
    rgba[mask, 2] = SHADE_COLOR[2]

    alpha = shade_map * (SHADE_ALPHA_MAX - SHADE_ALPHA_MIN) + SHADE_ALPHA_MIN * mask
    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    return rgba


def build_combo(line_rgba, shade_rgba):
    """Line + shade composited on white background → RGB uint8."""
    h, w = line_rgba.shape[:2]
    out = np.full((h, w, 3), 255, dtype=np.float32)

    # Shade first
    sa = shade_rgba[:, :, 3:4].astype(np.float32) / 255.0
    out = out * (1.0 - sa) + shade_rgba[:, :, :3].astype(np.float32) * sa

    # Lines on top
    la = line_rgba[:, :, 3:4].astype(np.float32) / 255.0
    out = out * (1.0 - la) + line_rgba[:, :, :3].astype(np.float32) * la

    return np.clip(out, 0, 255).astype(np.uint8)


def build_preview(original_np, line_rgba, shade_rgba, combo):
    """4-panel: original | line-on-white | shade-on-white | combo. Returns RGB uint8."""
    h, w = original_np.shape[:2]
    qw, qh = w // 2, h // 2

    def _resize(arr, mode):
        return np.array(Image.fromarray(arr, mode).resize((qw, qh), Image.LANCZOS))

    orig_q = _resize(original_np, 'RGB')
    combo_q = _resize(combo, 'RGB')

    # Line on white
    lr = _resize(line_rgba, 'RGBA')
    la = lr[:, :, 3:4].astype(np.float32) / 255.0
    line_vis = np.full((qh, qw, 3), 255, dtype=np.float32)
    line_vis = line_vis * (1 - la) + lr[:, :, :3].astype(np.float32) * la
    line_vis = np.clip(line_vis, 0, 255).astype(np.uint8)

    # Shade on white
    sr = _resize(shade_rgba, 'RGBA')
    sa = sr[:, :, 3:4].astype(np.float32) / 255.0
    shade_vis = np.full((qh, qw, 3), 255, dtype=np.float32)
    shade_vis = shade_vis * (1 - sa) + sr[:, :, :3].astype(np.float32) * sa
    shade_vis = np.clip(shade_vis, 0, 255).astype(np.uint8)

    top = np.hstack([orig_q, line_vis])
    bot = np.hstack([shade_vis, combo_q])
    return np.vstack([top, bot])


# ═══════════════════════════════════════════════════
# Prompt JSON
# ═══════════════════════════════════════════════════

def build_prompt_json(input_path, name_noext, processing_time):
    return {
        "version": "1.0.0",
        "engine": "parksy-liner",
        "source": {"filename": os.path.basename(input_path)},
        "canvas": {"width": CANVAS_W, "height": CANVAS_H},
        "outputs": {
            "line": f"{name_noext}_line_rgba.png",
            "shade": f"{name_noext}_shade_rgba.png",
            "combo": f"{name_noext}_combo_for_notes.png",
            "preview": f"{name_noext}_preview_debug.png",
        },
        "parameters": {
            "xdog_sigma": XDOG_SIGMA, "xdog_k": XDOG_K,
            "xdog_epsilon": XDOG_EPSILON, "xdog_phi": XDOG_PHI,
            "line_color": "#C3C3C3", "shade_color": "#C8C8C8",
        },
        "processing": {
            "time_seconds": round(processing_time, 3),
            "timestamp": datetime.now().isoformat(),
        },
        "prompt_template": (
            f"A detailed pencil sketch drawn with light gray lines (#C3C3C3) "
            f"on white paper, with subtle gray shading (#C8C8C8). "
            f"Hand-drawn artistic style. Canvas {CANVAS_W}x{CANVAS_H}px."
        ),
    }


# ═══════════════════════════════════════════════════
# Main Pipeline
# ═══════════════════════════════════════════════════

def process(input_path, output_dir=None):
    if not os.path.isfile(input_path):
        print(f"[ERROR] File not found: {input_path}")
        sys.exit(1)

    if output_dir is None:
        output_dir = os.path.dirname(os.path.abspath(input_path)) or '.'
    os.makedirs(output_dir, exist_ok=True)

    name_noext = os.path.splitext(os.path.basename(input_path))[0]
    t0 = time.time()

    # 1. Read
    print(f"[1/7] Reading: {input_path}")
    pil_img = Image.open(input_path).convert('RGB')
    print(f"  Original: {pil_img.size[0]}x{pil_img.size[1]}")

    # 2. Letterbox
    print(f"[2/7] Letterbox → {CANVAS_W}x{CANVAS_H}")
    canvas_pil, scale, ox, oy = letterbox_fit(pil_img)
    canvas_np = np.array(canvas_pil)
    print(f"  Scale: {scale:.3f}, Offset: ({ox}, {oy})")

    # 3. Smooth (Pillow bilateral approximation: median + slight blur)
    print("[3/7] Smoothing...")
    smooth_pil = canvas_pil.filter(ImageFilter.MedianFilter(3))
    smooth_np = np.array(smooth_pil)

    # 4. XDoG
    print("[4/7] XDoG edge detection...")
    gray = to_gray(smooth_np)
    edge_map = xdog_edge(gray)

    # 5. Shade
    print("[5/7] Shade extraction...")
    shade_map = extract_shade(gray)

    # 6. Build layers
    print("[6/7] Building layers...")
    line_rgba = build_line_rgba(edge_map)
    shade_rgba = build_shade_rgba(shade_map)
    combo = build_combo(line_rgba, shade_rgba)
    preview = build_preview(canvas_np, line_rgba, shade_rgba, combo)

    t_proc = time.time() - t0

    # 7. Write
    print("[7/7] Writing files...")
    paths = {}

    p = os.path.join(output_dir, f"{name_noext}_line_rgba.png")
    write_rgba_png(p, line_rgba)
    paths['line'] = p
    print(f"  → {p}")

    p = os.path.join(output_dir, f"{name_noext}_shade_rgba.png")
    write_rgba_png(p, shade_rgba)
    paths['shade'] = p
    print(f"  → {p}")

    p = os.path.join(output_dir, f"{name_noext}_combo_for_notes.png")
    write_rgb_png(p, combo)
    paths['combo'] = p
    print(f"  → {p}")

    p = os.path.join(output_dir, f"{name_noext}_preview_debug.png")
    write_rgb_png(p, preview)
    paths['preview'] = p
    print(f"  → {p}")

    p = os.path.join(output_dir, f"{name_noext}_prompt.json")
    with open(p, 'w', encoding='utf-8') as f:
        json.dump(build_prompt_json(input_path, name_noext, t_proc), f, indent=2, ensure_ascii=False)
    paths['prompt'] = p
    print(f"  → {p}")

    t_total = time.time() - t0
    print(f"\n[DONE] Process: {t_proc:.2f}s | Total: {t_total:.2f}s | Files: {len(paths)}")
    return paths


# ═══════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ('--help', '-h'):
        print("""Parksy Liner Engine — Photo → Sketch

Usage: python liner_engine.py <image> [output_dir]

Output:
  {name}_line_rgba.png        Line art (transparent BG)
  {name}_shade_rgba.png       Shade (transparent BG)
  {name}_combo_for_notes.png  Combined (white BG, Samsung Notes)
  {name}_preview_debug.png    4-panel debug
  {name}_prompt.json          AI prompt metadata""")
        sys.exit(0)

    process(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)


if __name__ == '__main__':
    main()
