#!/usr/bin/env python3
"""Procedural texture factory for "S M Nazmuz Sakib is unemployed" (Godot 4.6).

Every texture is generated from code, so the game ships no third-party art. All surface maps tile
seamlessly (the noise is periodic) and follow Godot's conventions:

  <set>_albedo.png     sRGB colour (RGBA where the set has a cut-out, e.g. the steel grille)
  <set>_normal.png     tangent-space normal, OpenGL style (green = up), what Godot expects
  <set>_roughness.png  linear, 0 = mirror, 1 = chalk
  <set>_ao.png         linear ambient occlusion, 1 = open
  <set>_orm.png        packed for ORMMaterial3D and the surface shader: R = AO, G = roughness, B = metallic
  <set>_height.png     linear height, for height blending and parallax

Sets
  Surfaces (1024 px):  brick_weathered, asphalt_cracked, tin_corrugated_rust, tin_corrugated_painted,
                       concrete_moss, plaster_peeling, tile_rubber (from the Tower car park photos)
  Awnings (1024 px):   awning_red_white, awning_blue_yellow, awning_green_cream, tarp_blue, tarp_orange,
                       gamchha_check
  Cloth (512 px):      lungi_check_blue, lungi_check_green, lungi_check_maroon, panjabi_white, panjabi_sky,
                       shirt_check_blue, kameez_print_rose, kameez_print_teal
  Cut-outs (512 px):   grille_steel (RGBA)
  Decals (512 px):     decal_grime_streaks, decal_water_stain, decal_poster_torn (RGBA)
  Faces (1024x512):    twelve heads, each an equirectangular wrap for a SphereMesh (face at u = 0.5,
                       which is -Z, the direction Godot nodes look), plus a flat front portrait
  Shared:              grime_noise.png (R macro, G vertical streaks, B speckle, A cells) and
                       sky_smog_cover.png (2048x1024 panorama for ProceduralSkyMaterial.sky_cover)

Usage
  pip install pillow numpy
  python3 tools/generate_textures.py                  # everything at the default sizes
  python3 tools/generate_textures.py --size 2048      # sharper surfaces (4x the disk space)
  python3 tools/generate_textures.py --only brick faces --preview
Output goes to art/textures/ inside the project. A manifest.json lists every set with its real-world
tile size, which DhakaMaterials.gd uses for triplanar scale.

Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.
"""
import argparse
import json
import math
import pathlib
import sys
import time
import zlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "textures"


# =============================================================================================
# Periodic noise and image toolkit (numpy). Every function wraps at the tile edge.
# =============================================================================================

def _fade(t):
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def perlin(size, period, rng, h=None):
    """Tileable gradient noise, roughly in [-0.7, 0.7]. `period` lattice cells across the tile."""
    h = h or size
    ang = rng.uniform(0.0, 2.0 * np.pi, (period, period))
    gx, gy = np.cos(ang), np.sin(ang)
    cx = np.arange(size) * period / size
    cy = np.arange(h) * period / h
    x0 = np.floor(cx).astype(int)
    y0 = np.floor(cy).astype(int)
    fx, fy = cx - x0, cy - y0
    X0, Y0 = np.meshgrid(x0 % period, y0 % period)
    FX, FY = np.meshgrid(fx, fy)
    X1, Y1 = (X0 + 1) % period, (Y0 + 1) % period

    def corner(ix, iy, dx, dy):
        return gx[iy, ix] * dx + gy[iy, ix] * dy

    n00 = corner(X0, Y0, FX, FY)
    n10 = corner(X1, Y0, FX - 1.0, FY)
    n01 = corner(X0, Y1, FX, FY - 1.0)
    n11 = corner(X1, Y1, FX - 1.0, FY - 1.0)
    u, v = _fade(FX), _fade(FY)
    return (n00 * (1 - u) + n10 * u) * (1 - v) + (n01 * (1 - u) + n11 * u) * v


def fbm(size, period, octaves, rng, gain=0.5, h=None):
    """Fractal sum of tileable Perlin octaves, normalised to [0, 1]."""
    total = np.zeros((h or size, size))
    amp, norm = 1.0, 0.0
    for i in range(octaves):
        total += amp * perlin(size, period * (2 ** i), rng, h)
        norm += amp
        amp *= gain
    return norm01(total / norm)


def ridged(size, period, octaves, rng):
    """Ridged fractal: sharp crests, good for crinkles and cracks."""
    total = np.zeros((size, size))
    amp = 1.0
    for i in range(octaves):
        total += amp * (1.0 - np.abs(perlin(size, period * (2 ** i), rng) * 1.4))
        amp *= 0.5
    return norm01(total)


def worley(size, cells, rng, jitter=0.9):
    """Tileable cellular noise. Returns F1, F2 (in cell units) and the id of the nearest cell."""
    pts = rng.random((cells, cells, 2)) * jitter + (1.0 - jitter) * 0.5
    c = (np.arange(size) + 0.5) * cells / size
    ci = np.floor(c).astype(int)
    cf = c - ci
    CX, CY = np.meshgrid(ci, ci)
    FX, FY = np.meshgrid(cf, cf)
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    ids = np.zeros((size, size), dtype=np.int64)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            nx, ny = (CX + ox) % cells, (CY + oy) % cells
            d = np.hypot(pts[ny, nx, 0] + ox - FX, pts[ny, nx, 1] + oy - FY)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            ids = np.where(closer, ny * cells + nx, ids)
            f1 = np.where(closer, d, f1)
    return f1, f2, ids


def norm01(a, lo_pct=0.5, hi_pct=99.5):
    lo, hi = np.percentile(a, [lo_pct, hi_pct])
    return np.clip((a - lo) / max(hi - lo, 1e-6), 0.0, 1.0)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    if isinstance(t, np.ndarray) and np.ndim(a) + np.ndim(b) > 0 and t.ndim == 2:
        a = np.asarray(a, dtype=np.float64)
        b = np.asarray(b, dtype=np.float64)
        if a.ndim == 1 or b.ndim == 1 or (a.ndim == 3 or b.ndim == 3):
            t = t[..., None]
    return a + (b - a) * t


def blur(img, sigma_x, sigma_y=None):
    """Periodic Gaussian blur by FFT (wraps exactly, so tiling survives). Anisotropic if sigma_y given."""
    sigma_y = sigma_x if sigma_y is None else sigma_y
    if sigma_x <= 0 and sigma_y <= 0:
        return img
    if img.ndim == 3:
        return np.stack([blur(img[..., c], sigma_x, sigma_y) for c in range(img.shape[2])], -1)
    h, w = img.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2.0 * np.pi ** 2 * (sigma_x ** 2 * fx ** 2 + sigma_y ** 2 * fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(img) * g))


def sample_wrap(img, x, y):
    """Bilinear sample with wraparound. x, y are pixel coordinates (arrays)."""
    h, w = img.shape[:2]
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    x0 %= w
    y0 %= h
    x1, y1 = (x0 + 1) % w, (y0 + 1) % h
    if img.ndim == 3:
        fx, fy = fx[..., None], fy[..., None]
    return (img[y0, x0] * (1 - fx) + img[y0, x1] * fx) * (1 - fy) + (img[y1, x0] * (1 - fx) + img[y1, x1] * fx) * fy


def warp(img, dx, dy):
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    return sample_wrap(img, xx + dx, yy + dy)


def normal_from_height(height, strength):
    """OpenGL-style tangent normal (green up) from a height field, with wraparound."""
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    nx, ny, nz = -dx * strength, dy * strength, np.ones_like(height)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx * inv, ny * inv, nz * inv], -1) * 0.5 + 0.5


def ao_from_height(height, scale, strength=2.2):
    """Cavity occlusion: how far each pixel sits below its blurred surroundings, at three radii."""
    occ = np.zeros_like(height)
    for radius, weight in ((2.0, 0.45), (7.0, 0.35), (22.0, 0.2)):
        occ += weight * np.clip(blur(height, radius * scale) - height, 0.0, None)
    return np.clip(1.0 - occ * strength, 0.0, 1.0)


def rgb(*c):
    return np.array(c, dtype=np.float64)


def palette_pick(ids, colours, weights, rng):
    """One colour per cell id, chosen with weights. Returns an (H, W, 3) image."""
    n = int(ids.max()) + 1
    w = np.array(weights, dtype=np.float64)
    choice = rng.choice(len(colours), size=n, p=w / w.sum())
    jitter = rng.uniform(0.9, 1.1, size=(n, 1))
    table = np.array(colours)[choice] * jitter
    return table[ids]


def tint(img, colour, t):
    return lerp(img, np.broadcast_to(colour, img.shape), t)


def grey(img):
    return img[..., 0] * 0.3 + img[..., 1] * 0.59 + img[..., 2] * 0.11


def desaturate(img, t):
    g = grey(img)[..., None]
    return img + (g - img) * (t[..., None] if isinstance(t, np.ndarray) else t)


# =============================================================================================
# Writing maps
# =============================================================================================

class TextureSet:
    """Collects the maps of one material and writes them with the naming Godot code expects."""

    def __init__(self, name, folder, tile_m, notes, metallic_default=0.0):
        self.name, self.folder, self.tile_m, self.notes = name, folder, tile_m, notes
        self.metallic_default = metallic_default
        self.albedo = self.height = self.rough = self.ao = self.metal = self.normal = self.alpha = None

    def finish(self, normal_strength, scale=1.0, ao_strength=2.2):
        h = self.height
        if self.normal is None:
            self.normal = normal_from_height(h, normal_strength)
        if self.ao is None:
            self.ao = ao_from_height(h, scale, ao_strength)
        if self.metal is None:
            self.metal = np.full_like(h, self.metallic_default)
        return self

    def write(self, out, manifest):
        d = out / self.folder
        d.mkdir(parents=True, exist_ok=True)
        base = d / self.name
        if self.alpha is not None:
            save_rgba(np.dstack([self.albedo, self.alpha]), f"{base}_albedo.png")
        else:
            save_rgb(self.albedo, f"{base}_albedo.png")
        save_rgb(self.normal, f"{base}_normal.png")
        save_grey(self.rough, f"{base}_roughness.png")
        save_grey(self.ao, f"{base}_ao.png")
        save_grey(norm01(self.height, 0.0, 100.0), f"{base}_height.png")
        save_rgb(np.dstack([self.ao, self.rough, self.metal]), f"{base}_orm.png")
        manifest["sets"][self.name] = {
            "folder": self.folder, "tile_m": self.tile_m, "notes": self.notes,
            "size": int(self.height.shape[1]), "alpha": self.alpha is not None,
            "maps": ["albedo", "normal", "roughness", "ao", "orm", "height"],
        }
        print(f"  {self.folder}/{self.name}  ({self.height.shape[1]} px, tiles every {self.tile_m} m)")


def _u8(a):
    return np.uint8(np.clip(a, 0.0, 1.0) * 255.0 + 0.5)


def save_rgb(a, path):
    Image.fromarray(_u8(a), "RGB").save(path, optimize=True)


def save_rgba(a, path):
    Image.fromarray(_u8(a), "RGBA").save(path, optimize=True)


def save_grey(a, path):
    Image.fromarray(_u8(a), "L").save(path, optimize=True)


# =============================================================================================
# 1. Weathered red brick (Dhaka hand-moulded brick, partly rendered over)
# =============================================================================================

def tex_brick(size, rng):
    s = size / 1024.0
    cols, rows = 4, 14
    bw, bh = size / cols, size / rows
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    wob_x = (fbm(size, 6, 3, rng) - 0.5) * 6.0 * s
    wob_y = (fbm(size, 6, 3, rng) - 0.5) * 3.0 * s
    wx, wy = xx + wob_x, yy + wob_y
    row = np.floor(wy / bh).astype(int) % rows
    row_shift = rng.uniform(-0.06, 0.06, rows) * bw
    off = np.where(row % 2 == 1, bw * 0.5, 0.0) + row_shift[row]
    xo = wx + off
    col = np.floor(xo / bw).astype(int) % cols
    lx, ly = np.mod(xo, bw), np.mod(wy, bh)
    ids = row * cols + col
    mortar = 0.13 * bh
    edge = np.minimum(np.minimum(lx, bw - lx), np.minimum(ly, bh - ly)) - mortar * 0.5
    fine = fbm(size, 48, 3, rng)
    f1, _, _ = worley(size, 28, rng)
    chip = smoothstep(0.32, 0.12, f1) * smoothstep(9.0 * s, 2.0 * s, edge)
    edge_n = edge - (fine - 0.5) * 4.0 * s - chip * 6.0 * s
    brick = smoothstep(-0.6, 1.2, edge_n)
    bevel = np.clip(edge_n / (6.0 * s), 0.0, 1.0) ** 0.55

    # colours: hand-moulded red, some over-burnt, some pale
    reds = [rgb(0.61, 0.27, 0.18), rgb(0.67, 0.31, 0.2), rgb(0.55, 0.23, 0.16), rgb(0.71, 0.37, 0.24),
            rgb(0.46, 0.2, 0.14), rgb(0.33, 0.15, 0.11), rgb(0.74, 0.47, 0.31)]
    base = palette_pick(ids, reds, [5, 5, 4, 3, 2, 1, 1], rng)
    mid = fbm(size, 10, 4, rng)
    base = base * (0.84 + 0.3 * mid)[..., None]
    fw, _, _ = worley(size, 140, rng)
    pits = smoothstep(0.18, 0.05, fw)
    base = base * (1.0 - 0.25 * pits)[..., None]
    sand = rng.random((size, size)) > 0.985
    base = np.where(sand[..., None], base * 1.2, base)
    base = lerp(base, rgb(0.8, 0.5, 0.32), chip * 0.6)
    mortar_c = rgb(0.5, 0.48, 0.43) * (0.85 + 0.25 * fbm(size, 32, 3, rng))[..., None]
    alb = lerp(mortar_c, base, brick)

    height = brick * (0.55 + 0.45 * bevel) + (fine - 0.5) * 0.06 - pits * brick * 0.08
    height += (1.0 - brick) * (fbm(size, 64, 2, rng) * 0.08)

    # efflorescence (salt bloom) near the mortar
    salt = smoothstep(0.7, 0.88, fbm(size, 5, 4, rng)) * (1.0 - 0.6 * bevel)
    alb = lerp(alb, rgb(0.84, 0.82, 0.76), salt * 0.7)

    # old render clinging on in patches
    patch = smoothstep(0.72, 0.76, fbm(size, 3, 5, rng) + (fine - 0.5) * 0.08)
    plaster_c = rgb(0.68, 0.64, 0.58) * (0.85 + 0.2 * fbm(size, 24, 3, rng))[..., None]
    pf1, pf2, _ = worley(size, 18, rng)
    plaster_crack = smoothstep(0.035, 0.0, pf2 - pf1) * patch
    alb = lerp(alb, plaster_c, patch)
    alb = alb * (1.0 - 0.35 * plaster_crack)[..., None]
    height = lerp(height, 1.15 + (fine - 0.5) * 0.05, patch) - plaster_crack * 0.2

    # moss in the mortar, black soot streaks running down
    moss = smoothstep(0.58, 0.78, fbm(size, 7, 4, rng)) * (1.0 - brick) * (1.0 - patch)
    alb = lerp(alb, rgb(0.24, 0.31, 0.13) * (0.8 + 0.4 * fine)[..., None], moss * 0.9)
    height += moss * 0.12 * fine
    streak = smoothstep(0.55, 0.85, norm01(blur(rng.random((size, size)), 1.2 * s, 70.0 * s)))
    streak *= smoothstep(0.35, 0.65, fbm(size, 4, 2, rng))
    alb = alb * (1.0 - 0.32 * streak)[..., None]

    t = TextureSet("brick_weathered", "surfaces", 0.96, "Hand-moulded red brick, half-bond, salt bloom, old render, moss, soot runs")
    t.albedo = np.clip(alb, 0, 1)
    t.height = height
    t.rough = np.clip(0.8 + 0.08 * fine + 0.1 * (1 - brick) + 0.05 * salt - 0.08 * moss - 0.05 * streak, 0.35, 1.0)
    return t.finish(normal_strength=7.0, scale=s)


# =============================================================================================
# 2. Cracked asphalt (sun-faded Dhaka road, alligator cracking, oil, a repair patch)
# =============================================================================================

def tex_asphalt(size, rng):
    s = size / 1024.0
    f1, _, ids = worley(size, 120, rng, jitter=1.0)
    stone = smoothstep(0.46, 0.3, f1)
    tone = rng.uniform(0.22, 0.6, int(ids.max()) + 1)[ids]
    warm = rng.uniform(-0.03, 0.04, int(ids.max()) + 1)[ids]
    binder = 0.1 + 0.05 * fbm(size, 64, 3, rng)
    v = lerp(binder, tone, stone * 0.85)
    alb = np.dstack([v + warm, v + warm * 0.6, v - warm * 0.2])
    fine_f1, _, fine_ids = worley(size, 300, rng, jitter=1.0)
    grit = smoothstep(0.35, 0.15, fine_f1) * rng.uniform(-0.05, 0.08, int(fine_ids.max()) + 1)[fine_ids]
    alb += grit[..., None]
    height = stone * (0.5 + 0.5 * smoothstep(0.46, 0.0, f1)) * 0.5 + grit * 0.6

    # sun-bleached wear and tyre polish
    wear = fbm(size, 3, 5, rng)
    alb = lerp(alb, rgb(0.36, 0.35, 0.33), smoothstep(0.45, 0.9, wear) * 0.55)
    height = lerp(height, blur(height, 2.0 * s), smoothstep(0.5, 0.9, wear))

    # cracks: alligator network in patches plus long transverse cracks
    c1, c2, _ = worley(size, 9, rng)
    net = smoothstep(0.06, 0.0, c2 - c1) * smoothstep(0.45, 0.6, fbm(size, 3, 3, rng))
    l1, l2, _ = worley(size, 3, rng)
    long = smoothstep(0.03, 0.0, l2 - l1) * smoothstep(0.35, 0.5, fbm(size, 2, 3, rng))
    jag = fbm(size, 40, 2, rng)
    crack = np.clip(np.maximum(net, long) * smoothstep(0.2, 0.5, jag + 0.3) * 1.3, 0, 1)
    rim = np.clip(blur(crack, 2.0 * s) * 2.0 - crack, 0, 1)
    dust = smoothstep(0.5, 0.8, fbm(size, 20, 2, rng)) * crack
    alb = alb * (1.0 - 0.75 * crack)[..., None]
    alb = lerp(alb, rgb(0.42, 0.38, 0.3), dust * 0.8)
    alb = alb * (1.0 + 0.25 * rim)[..., None]
    height -= crack * 0.55
    height += rim * 0.05

    # oil stains and one dark repair patch
    oil = smoothstep(0.66, 0.8, fbm(size, 6, 4, rng))
    alb = alb * (1.0 - 0.45 * oil)[..., None]
    yy, xx = np.mgrid[0:size, 0:size]
    px, py = rng.integers(0, size, 2)
    pw, ph = int(size * rng.uniform(0.12, 0.2)), int(size * rng.uniform(0.1, 0.16))
    patch = ((((xx - px) % size) < pw) & (((yy - py) % size) < ph)).astype(np.float64)
    seam = np.clip(blur(patch, 1.0 * s) * (1 - patch) * 4.0 + patch * (1 - blur(patch, 1.0 * s)) * 4.0, 0, 1)
    fresh = 0.15 + 0.05 * fbm(size, 90, 2, rng)
    alb = lerp(alb, np.dstack([fresh, fresh, fresh * 1.04]), patch * 0.6)
    height = lerp(height, 0.3 + grit * 0.4, patch) - seam * 0.3

    t = TextureSet("asphalt_cracked", "surfaces", 4.0, "Sun-faded asphalt, exposed aggregate, alligator and long cracks, oil, a repair patch")
    t.albedo = np.clip(alb, 0, 1)
    t.height = height
    t.rough = np.clip(0.88 - 0.08 * stone + 0.07 * crack - 0.5 * oil - 0.06 * smoothstep(0.6, 0.95, wear) - 0.06 * patch, 0.25, 1.0)
    return t.finish(normal_strength=6.0, scale=s)


# =============================================================================================
# 3. Corrugated tin (galvanised, rusting; and a painted, peeling variant)
# =============================================================================================

def tex_tin(size, rng, painted):
    s = size / 1024.0
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    corr = 16
    pitch = size / corr
    phase = xx / pitch * 2.0 * np.pi
    profile = 0.5 + 0.5 * np.sin(phase)
    sheet_h = size / 2.0
    sy = np.mod(yy, sheet_h)
    overlap = smoothstep(14.0 * s, 10.0 * s, sy)
    seam_line = smoothstep(3.0 * s, 0.0, np.abs(sy - 12.0 * s))
    height = profile * 1.0 + overlap * 0.12 - seam_line * 0.1

    # nails on every crest along each seam, with rust bleeding down
    nails = np.zeros((size, size))
    for k in range(corr):
        cx = (k + 0.25) * pitch
        for sheet in range(2):
            cy = sheet * sheet_h + 22.0 * s
            d = np.hypot((xx - cx + size / 2) % size - size / 2, (yy - cy + size / 2) % size - size / 2)
            nails = np.maximum(nails, smoothstep(5.0 * s, 3.0 * s, d))
    height += nails * 0.25

    _, _, cells = worley(size, 48, rng)
    spangle = rng.uniform(-0.05, 0.05, int(cells.max()) + 1)[cells]
    zinc = rgb(0.5, 0.52, 0.54) + spangle[..., None]
    scratches = smoothstep(0.75, 0.95, norm01(blur(rng.random((size, size)), 40.0 * s, 0.6 * s)))
    zinc = zinc * (1.0 + 0.15 * scratches * profile)[..., None]

    rust_runs = np.clip(blur(nails, 1.5 * s, 50.0 * s) * 8.0, 0, 1)
    rust_runs = np.roll(rust_runs, int(30 * s), axis=0)
    rust = smoothstep(0.6, 0.8, fbm(size, 4, 5, rng) + 0.22 * fbm(size, 24, 3, rng) - 0.1)
    rust = np.clip(np.maximum(rust, rust_runs * 0.85) + (1 - profile) * 0.15 * rust, 0, 1)
    rust_deep = smoothstep(0.75, 0.95, fbm(size, 12, 4, rng)) * rust
    rust_c = lerp(rgb(0.6, 0.32, 0.14), rgb(0.42, 0.2, 0.09), fbm(size, 30, 3, rng))
    rust_c = lerp(rust_c, rgb(0.24, 0.12, 0.06), rust_deep)
    alb = lerp(zinc, rust_c, rust)
    height += rust * (fbm(size, 90, 2, rng) - 0.5) * 0.08
    metal = (1.0 - rust) * 0.75
    rough = lerp(0.42 + spangle * 2.0, 0.9, rust)

    if painted:
        colour = rgb(0.58, 0.19, 0.15) if rng.random() < 0.5 else rgb(0.17, 0.4, 0.4)
        fade = profile * 0.25 + 0.15 * fbm(size, 6, 3, rng)
        paint_c = lerp(colour, rgb(0.82, 0.78, 0.7), fade)
        keep = smoothstep(0.38, 0.42, fbm(size, 5, 5, rng) + 0.1 * fbm(size, 40, 2, rng))
        flake_edge = smoothstep(0.38, 0.4, fbm(size, 5, 5, rng)) - keep
        alb = lerp(alb, paint_c, keep)
        height += keep * 0.04 + np.clip(flake_edge, 0, 1) * 0.05
        metal = metal * (1.0 - keep)
        rough = lerp(rough, 0.62, keep)

    dirt = smoothstep(0.25, 0.0, profile) * fbm(size, 8, 3, rng)
    alb = alb * (1.0 - 0.35 * dirt)[..., None]
    rough = np.clip(rough + dirt * 0.2, 0.2, 1.0)

    name = "tin_corrugated_painted" if painted else "tin_corrugated_rust"
    t = TextureSet(name, "surfaces", 2.0, "Corrugated galvanised sheet, nailed seams, rust runs" + (", peeling paint" if painted else ""))
    t.albedo = np.clip(alb, 0, 1)
    t.height = height
    t.rough = rough
    t.metal = np.clip(metal, 0, 1)
    return t.finish(normal_strength=5.0, scale=s, ao_strength=1.4)


# =============================================================================================
# 4. Concrete with moss and grime (board-marked, tie holes, soot runs, black mould, moss)
# =============================================================================================

def tex_concrete(size, rng):
    s = size / 1024.0
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    big = fbm(size, 3, 5, rng)
    mid = fbm(size, 12, 4, rng)
    base = lerp(rgb(0.5, 0.5, 0.48), rgb(0.62, 0.61, 0.58), big)
    base = lerp(base, rgb(0.56, 0.55, 0.5), mid * 0.4)
    planks = 8
    ph = size / planks
    plank_id = np.floor(yy / ph).astype(int) % planks
    plank_shift = rng.uniform(-0.03, 0.03, planks)[plank_id]
    base = base * (1.0 + plank_shift)[..., None]
    seam = smoothstep(2.5 * s, 0.0, np.minimum(np.mod(yy, ph), ph - np.mod(yy, ph)))
    grain = norm01(blur(rng.random((size, size)), 25.0 * s, 0.8 * s))
    height = 0.5 + (mid - 0.5) * 0.12 + (grain - 0.5) * 0.04 - seam * 0.12

    holes = np.zeros((size, size))
    for r in range(planks):
        for c in range(2):
            hx = (c + 0.5) * size / 2 + (r % 2) * size / 4
            hy = (r + 0.5) * ph
            d = np.hypot((xx - hx + size / 2) % size - size / 2, (yy - hy + size / 2) % size - size / 2)
            holes = np.maximum(holes, smoothstep(9.0 * s, 6.0 * s, d))
    height -= holes * 0.3
    base = base * (1.0 - 0.35 * holes)[..., None]

    pf, _, _ = worley(size, 170, rng)
    pores = smoothstep(0.1, 0.03, pf)
    height -= pores * 0.15
    base = base * (1.0 - 0.3 * pores)[..., None]
    speck = rng.random((size, size))
    base = base * (1.0 + np.where(speck > 0.97, 0.12, 0.0) - np.where(speck < 0.02, 0.1, 0.0))[..., None]

    c1, c2, _ = worley(size, 5, rng)
    crack = smoothstep(0.02, 0.0, c2 - c1) * smoothstep(0.55, 0.65, fbm(size, 4, 3, rng))
    height -= crack * 0.25
    base = base * (1.0 - 0.45 * crack)[..., None]

    streak_src = rng.random((size, size)) * smoothstep(0.5, 0.75, fbm(size, 8, 2, rng))
    streak = smoothstep(0.08, 0.3, norm01(blur(streak_src, 1.5 * s, 80.0 * s)))
    soot = rgb(0.12, 0.11, 0.1)
    base = lerp(base, base * soot * 3.0, streak * 0.32)

    mould = smoothstep(0.74, 0.9, fbm(size, 6, 5, rng)) * (0.6 + 0.4 * crack + 0.3 * seam)
    base = lerp(base, rgb(0.1, 0.12, 0.09), np.clip(mould, 0, 1) * 0.7)

    cavity = 1.0 - ao_from_height(height, s, 3.0)
    moss_mask = smoothstep(0.62, 0.8, fbm(size, 4, 5, rng) * 0.8 + cavity * 1.2 + crack * 0.5 + seam * 0.25)
    fuzz = fbm(size, 128, 2, rng)
    moss_c = lerp(rgb(0.2, 0.28, 0.11), rgb(0.38, 0.45, 0.16), fuzz)
    base = lerp(base, moss_c, moss_mask)
    height += moss_mask * (0.06 + fuzz * 0.08)

    t = TextureSet("concrete_moss", "surfaces", 2.0, "Board-marked concrete, tie holes, pores, cracks, soot runs, black mould, moss in the low spots")
    t.albedo = np.clip(base, 0, 1)
    t.height = height
    t.rough = np.clip(0.9 + (mid - 0.5) * 0.06 - streak * 0.15 - moss_mask * 0.12 - mould * 0.05, 0.3, 1.0)
    return t.finish(normal_strength=6.0, scale=s)


# =============================================================================================
# 5. Painted plaster, peeling (off-white over grey render: the Tower's walls in the photos)
# =============================================================================================

def tex_plaster(size, rng, clean=False):
    # clean=True: freshly painted render for facades (Phase 2); otherwise light, local peeling
    s = size / 1024.0
    render = rgb(0.6, 0.59, 0.56) * (0.85 + 0.25 * fbm(size, 20, 3, rng))[..., None]
    paint = rgb(0.9, 0.89, 0.85) * (0.95 + 0.07 * fbm(size, 8, 4, rng))[..., None]
    orange = fbm(size, 90, 2, rng)
    peel_n = fbm(size, 5, 5, rng) + (fbm(size, 40, 3, rng) - 0.5) * 0.12
    th = 0.97 if clean else 0.8
    keep = smoothstep(th, th - 0.01, peel_n)
    curl = smoothstep(th - 0.02, th, peel_n) * smoothstep(th + 0.02, th, peel_n)
    deep = smoothstep(th + 0.13, th + 0.15, peel_n)
    alb = lerp(render, paint, keep)
    alb = lerp(alb, rgb(0.58, 0.29, 0.2), deep)
    alb = alb * (1.0 + 0.25 * curl)[..., None]
    height = 0.5 + keep * 0.08 + curl * 0.06 - deep * 0.15 + (orange - 0.5) * 0.03

    c1, c2, _ = worley(size, 7, rng)
    hair = smoothstep(0.008, 0.0, c2 - c1) * smoothstep(0.6, 0.85, fbm(size, 3, 3, rng)) * keep
    alb = alb * (1.0 - (0.03 if clean else 0.14) * hair)[..., None]
    height -= hair * 0.06

    damp = fbm(size, 3, 5, rng)
    tide = smoothstep(0.012, 0.0, np.abs(damp - 0.68)) + smoothstep(0.01, 0.0, np.abs(damp - 0.74)) * 0.6
    stain = smoothstep(0.72, 0.86, damp) * (0.15 if clean else 0.35)
    alb = lerp(alb, alb * rgb(0.88, 0.84, 0.74), stain)
    alb = alb * (1.0 - (0.04 if clean else 0.12) * np.clip(tide, 0, 1))[..., None]

    dots = (rng.random((size, size)) > 0.9997).astype(np.float64)
    dots = np.clip(blur(dots, 1.2 * s) * 12.0, 0, 1)
    alb = alb * (1.0 - 0.2 * dots)[..., None]

    t = TextureSet("plaster_clean" if clean else "plaster_peeling", "surfaces", 2.0, "Fresh painted render for facades" if clean else "Off-white paint over grey render, light local peeling, hairline cracks, faint damp marks (tint in the material for coloured walls)")
    t.albedo = np.clip(alb, 0, 1)
    t.height = height
    t.rough = np.clip(lerp(0.9, 0.72, keep) + stain * 0.05, 0.3, 1.0)
    return t.finish(normal_strength=5.0, scale=s)


# =============================================================================================
# 6. Rubber-pattern floor tiles (the red / green / grey car-park tiles in the Tower photos)
# =============================================================================================

def tex_tile_rubber(size, rng):
    s = size / 1024.0
    n = 4
    tw = size / n
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    tx, ty = np.floor(xx / tw).astype(int), np.floor(yy / tw).astype(int)
    lx, ly = np.mod(xx, tw), np.mod(yy, tw)
    grout_d = np.minimum(np.minimum(lx, tw - lx), np.minimum(ly, tw - ly))
    tile = smoothstep(3.0 * s, 6.0 * s, grout_d)
    colours = [rgb(0.55, 0.24, 0.2), rgb(0.33, 0.4, 0.35), rgb(0.47, 0.47, 0.45)]
    which = np.where((tx + ty) % 2 == 0, 0, 1)
    rare = rng.random((n, n)) < 0.18
    which = np.where(rare[ty % n, tx % n], 2, which)
    base = np.array(colours)[which] * rng.uniform(0.92, 1.08, (n, n, 1))[ty % n, tx % n]
    k = 8
    sx, syy = np.mod(lx, tw / k) / (tw / k), np.mod(ly, tw / k) / (tw / k)
    stud = smoothstep(0.36, 0.3, np.hypot(sx - 0.5, syy - 0.5))
    groove = smoothstep(0.06, 0.0, np.minimum(np.minimum(sx, 1 - sx), np.minimum(syy, 1 - syy)))
    height = tile * (0.6 + stud * 0.18 - groove * 0.1)
    wear = smoothstep(0.4, 0.85, fbm(size, 3, 4, rng))
    dirt = (1 - tile) + groove * 0.6 + (1 - stud) * 0.15
    alb = base * (0.9 + 0.15 * fbm(size, 30, 3, rng))[..., None]
    alb = lerp(alb, rgb(0.17, 0.16, 0.15), np.clip(dirt, 0, 1) * 0.55)
    alb = alb * (1.0 - 0.15 * wear)[..., None] * (1.0 + 0.1 * stud * (1 - wear))[..., None]
    t = TextureSet("tile_rubber", "surfaces", 1.2, "300 mm rubber-pattern tiles in red, green and grey, studded, worn in the traffic lanes")
    t.albedo = np.clip(alb, 0, 1)
    t.height = height
    t.rough = np.clip(0.78 - 0.3 * wear * tile + 0.15 * (1 - tile), 0.3, 1.0)
    return t.finish(normal_strength=5.0, scale=s)


# =============================================================================================
# 7. Awnings and tarps: canvas weave, stripes, checks, plastic tarp; sun fade, dirt, sag
# =============================================================================================

def _canvas(size, rng, period=4.0):
    s = size / 1024.0
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    p = period * s if period * s >= 2 else 2.0
    over = (np.floor(xx / p) + np.floor(yy / p)) % 2
    thread_x = 0.5 + 0.5 * np.sin(xx / p * np.pi)
    thread_y = 0.5 + 0.5 * np.sin(yy / p * np.pi)
    weave = np.where(over > 0, thread_x, thread_y)
    slub = blur(rng.random((size, size)), 6.0 * s, 0.6 * s) * 0.5 + blur(rng.random((size, size)), 0.6 * s, 6.0 * s) * 0.5
    return weave, norm01(slub)


def _finish_fabric(name, folder, tile_m, notes, colour, size, rng, plastic=False, seams=False, dirty=1.0):
    s = size / 1024.0
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    weave, slub = _canvas(size, rng, 3.0 if plastic else 4.0)
    sag = 0.5 + 0.5 * np.sin(yy / size * 2.0 * np.pi * 2.0 + (fbm(size, 2, 2, rng) - 0.5) * 3.0)
    wrinkle = ridged(size, 6, 4, rng) if plastic else fbm(size, 5, 4, rng)
    fade = smoothstep(0.3, 0.9, fbm(size, 2, 4, rng)) * (0.35 + 0.65 * dirty)
    alb = colour * (0.9 + 0.12 * slub)[..., None] * (0.95 + 0.08 * weave)[..., None]
    alb = lerp(alb, desaturate(alb, 0.6) * 1.18, fade * 0.55)
    dirt = smoothstep(0.72, 0.92, fbm(size, 7, 4, rng)) * dirty
    alb = lerp(alb, alb * rgb(0.62, 0.57, 0.48), dirt * 0.4)
    tide = smoothstep(0.008, 0.0, np.abs(fbm(size, 4, 4, rng) - 0.72)) * dirty
    alb = alb * (1.0 - 0.12 * tide)[..., None]
    height = sag * 0.35 + wrinkle * (0.35 if plastic else 0.15) + weave * (0.03 if plastic else 0.1)
    if seams:
        sy = np.mod(yy, size / 2.0)
        seam = smoothstep(10.0 * s, 6.0 * s, np.abs(sy - size / 4.0))
        stitch = seam * (np.mod(xx, 12.0 * s) < 6.0 * s) * smoothstep(1.5 * s, 0.0, np.abs(np.abs(sy - size / 4.0) - 5.0 * s))
        height += seam * 0.15 - stitch * 0.05
        alb = alb * (1.0 - 0.12 * seam + 0.1 * stitch)[..., None]
        grom = np.zeros((size, size))
        for k in range(4):
            gx = (k + 0.5) * size / 4
            d = np.hypot((xx - gx + size / 2) % size - size / 2, (sy - size / 4.0))
            grom = np.maximum(grom, smoothstep(9.0 * s, 7.0 * s, d) * smoothstep(3.0 * s, 5.0 * s, d))
        alb = lerp(alb, rgb(0.7, 0.68, 0.62), grom)
        height += grom * 0.3
    t = TextureSet(name, folder, tile_m, notes, metallic_default=0.0)
    t.albedo = np.clip(alb, 0, 1)
    t.height = height
    t.rough = np.clip((0.55 if plastic else 0.88) + 0.08 * dirt + (0.1 * fade if plastic else 0.0), 0.2, 1.0)
    return t.finish(normal_strength=3.0, scale=s, ao_strength=1.5)


def _stripes(size, widths, colours):
    xx = np.arange(size)[None, :].repeat(size, 0).astype(np.float64)
    total = sum(widths)
    pos = np.mod(xx / size * total, total)
    out = np.zeros((size, size, 3))
    acc = 0
    for w, c in zip(widths, colours):
        mask = (pos >= acc) & (pos < acc + w)
        out[mask] = c
        acc += w
    return out


def _check(size, warp_w, warp_c, weft_w, weft_c, twill=4):
    """Woven check: warp and weft stripes, twill interlace so the colours mix like real cloth."""
    yy, xx = np.mgrid[0:size, 0:size]
    warp = _stripes(size, warp_w, warp_c)
    weft = np.transpose(_stripes(size, weft_w, weft_c), (1, 0, 2))
    on_top = ((xx // 2 + yy // 2) % twill) < twill // 2
    return np.where(on_top[..., None], warp, weft)


def tex_awnings(size, rng):
    out = []
    red, white = rgb(0.7, 0.13, 0.12), rgb(0.88, 0.86, 0.8)
    out.append(_finish_fabric("awning_red_white", "awnings", 1.6, "Red and white canvas stripes, sun-faded",
                              _stripes(size, [3, 3], [red, white]), size, rng, dirty=0.6))
    blue, yellow = rgb(0.14, 0.27, 0.55), rgb(0.88, 0.72, 0.2)
    out.append(_finish_fabric("awning_blue_yellow", "awnings", 1.6, "Blue and yellow stripes with thin white pinstripes",
                              _stripes(size, [5, 1, 4, 1], [blue, white, yellow, white]), size, rng, dirty=0.6))
    green, cream = rgb(0.13, 0.4, 0.24), rgb(0.86, 0.82, 0.68)
    out.append(_finish_fabric("awning_green_cream", "awnings", 1.6, "Wide green and cream stripes with a red accent",
                              _stripes(size, [6, 1, 6, 1], [green, red, cream, red]), size, rng, dirty=0.6))
    out.append(_finish_fabric("tarp_blue", "awnings", 2.0, "Blue plastic tarpaulin: crinkles, seams, grommets",
                              np.broadcast_to(rgb(0.1, 0.32, 0.62), (size, size, 3)).copy(), size, rng, plastic=True, seams=True, dirty=0.5))
    out.append(_finish_fabric("tarp_orange", "awnings", 2.0, "Orange tarpaulin, faded",
                              np.broadcast_to(rgb(0.82, 0.4, 0.12), (size, size, 3)).copy(), size, rng, plastic=True, seams=True, dirty=0.5))
    gam = _check(size, [8, 2, 3, 2, 8, 6], [red, white, rgb(0.1, 0.45, 0.25), white, red, rgb(0.85, 0.75, 0.3)],
                 [8, 2, 3, 2, 8, 6], [red, white, rgb(0.1, 0.45, 0.25), white, red, rgb(0.85, 0.75, 0.3)])
    out.append(_finish_fabric("gamchha_check", "awnings", 0.8, "Gamchha-style red, green and white woven check", gam, size, rng, dirty=0.3))
    return out


# =============================================================================================
# 8. Clothing cloth (lungi checks, panjabi cotton, shirt check, kameez block prints)
# =============================================================================================

def _motif_layer(size, rng, ground, ink, accent, count):
    """Block print: teardrop (paisley-like) and dot motifs stamped on a wrapped grid."""
    ss = size * 2
    img = Image.new("RGB", (ss, ss), tuple(int(c * 255) for c in ground))
    d = ImageDraw.Draw(img)
    step = ss // count
    for gy in range(count):
        for gx in range(count):
            cx = gx * step + (step // 2 if gy % 2 else 0) + step // 2
            cy = gy * step + step // 2
            for ox in (-ss, 0, ss):
                for oy in (-ss, 0, ss):
                    x, y = cx + ox, cy + oy
                    r = step * 0.28
                    d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=tuple(int(c * 255) for c in ink))
                    d.polygon([(x + r * 0.7, y - r * 0.35), (x + r * 1.5, y - r * 1.1), (x + r * 0.95, y + r * 0.1)],
                              fill=tuple(int(c * 255) for c in ink))
                    d.ellipse([x - r * 0.45, y - r * 0.3, x + r * 0.45, y + r * 0.3], fill=tuple(int(c * 255) for c in accent))
                    for k in range(6):
                        a = k * math.pi / 3
                        dx, dy = math.cos(a) * r * 1.35 + step * 0.5, math.sin(a) * r * 1.35
                        d.ellipse([x + dx - r * 0.08, y + dy - r * 0.08, x + dx + r * 0.08, y + dy + r * 0.08],
                                  fill=tuple(int(c * 255) for c in accent))
    img = img.resize((size, size), Image.LANCZOS)
    return np.asarray(img).astype(np.float64) / 255.0


def tex_cloth(size, rng):
    out = []
    lungis = [("lungi_check_blue", [rgb(0.1, 0.18, 0.42), rgb(0.85, 0.85, 0.82), rgb(0.12, 0.3, 0.55)]),
              ("lungi_check_green", [rgb(0.08, 0.3, 0.2), rgb(0.75, 0.72, 0.6), rgb(0.5, 0.12, 0.12)]),
              ("lungi_check_maroon", [rgb(0.36, 0.08, 0.1), rgb(0.12, 0.1, 0.25), rgb(0.8, 0.7, 0.4)])]
    for name, (a, b, c) in lungis:
        img = _check(size, [10, 2, 10, 1, 4, 1], [a, b, a, c, a, c], [10, 2, 10, 1, 4, 1], [a, b, a, c, a, c])
        out.append(_finish_fabric(name, "cloth", 0.5, "Woven lungi check (twill), for Humanoid lower bodies", img, size, rng, dirty=0.0))
    for name, colour in (("panjabi_white", rgb(0.9, 0.89, 0.84)), ("panjabi_sky", rgb(0.62, 0.74, 0.86))):
        img = np.broadcast_to(colour, (size, size, 3)).copy()
        img *= (1.0 - 0.04 * _stripes(size, [30, 1], [rgb(0, 0, 0), rgb(1, 1, 1)])[..., 0:1])
        out.append(_finish_fabric(name, "cloth", 0.4, "Slub cotton panjabi cloth with a faint self-stripe", img, size, rng, dirty=0.0))
    img = _check(size, [6, 2, 2, 2], [rgb(0.22, 0.36, 0.62), rgb(0.9, 0.9, 0.88), rgb(0.5, 0.6, 0.78), rgb(0.9, 0.9, 0.88)],
                 [6, 2, 2, 2], [rgb(0.22, 0.36, 0.62), rgb(0.9, 0.9, 0.88), rgb(0.5, 0.6, 0.78), rgb(0.9, 0.9, 0.88)])
    out.append(_finish_fabric("shirt_check_blue", "cloth", 0.3, "Small blue shirt check", img, size, rng, dirty=0.0))
    for name, ground, ink, accent in (("kameez_print_rose", rgb(0.8, 0.42, 0.5), rgb(0.45, 0.12, 0.25), rgb(0.95, 0.85, 0.6)),
                                      ("kameez_print_teal", rgb(0.15, 0.45, 0.48), rgb(0.06, 0.2, 0.25), rgb(0.95, 0.75, 0.35))):
        img = _motif_layer(size, rng, ground, ink, accent, 4)
        out.append(_finish_fabric(name, "cloth", 0.4, "Block-printed kameez cloth", img, size, rng, dirty=0.0))
    return out


# =============================================================================================
# 9. Steel window grille (alpha cut-out) and decals
# =============================================================================================

def tex_grille(size, rng):
    s = size / 512.0
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    bars = 6
    bp = size / bars
    bar_d = np.abs(np.mod(xx, bp) - bp / 2)
    bar = smoothstep(7.0 * s, 5.0 * s, bar_d)
    band_d = np.minimum(np.abs(yy - size * 0.25), np.abs(yy - size * 0.75))
    band = smoothstep(9.0 * s, 7.0 * s, band_d)
    # diamonds between the bands
    lx, ly = np.mod(xx, bp) - bp / 2, np.mod(yy, size / 2) - size / 4
    diamond_d = np.abs(np.abs(lx) + np.abs(ly) * 0.75 - bp * 0.32)
    diamond = smoothstep(4.0 * s, 2.5 * s, diamond_d) * (np.abs(ly) < size * 0.2)
    metal = np.clip(np.maximum(np.maximum(bar, band), diamond), 0, 1)
    roundness = np.cos(np.clip(bar_d / (7.0 * s), 0, 1) * np.pi / 2) * bar
    height = metal * 0.6 + roundness * 0.4
    paint = rgb(0.2, 0.24, 0.22) * (0.85 + 0.25 * fbm(size, 16, 3, rng))[..., None]
    rust = smoothstep(0.6, 0.8, fbm(size, 8, 4, rng))
    alb = lerp(paint, rgb(0.45, 0.22, 0.1), rust)
    t = TextureSet("grille_steel", "cutouts", 1.0, "Painted steel window grille with diamond motif; alpha cut-out, use alpha scissor 0.5")
    t.albedo = np.clip(alb, 0, 1)
    t.alpha = metal
    t.height = height
    t.rough = np.clip(lerp(0.55, 0.85, rust), 0, 1)
    t.metal = (1 - rust) * 0.35
    return t.finish(normal_strength=6.0, scale=s, ao_strength=1.0)


def tex_decals(size, rng):
    s = size / 512.0
    out = []
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    edge = smoothstep(0.0, 0.15, xx / size) * smoothstep(1.0, 0.85, xx / size) * smoothstep(0.0, 0.08, yy / size) * smoothstep(1.0, 0.92, yy / size)

    # soot / grime streaks running down from a sill
    src = rng.random((size, size)) * smoothstep(0.2, 0.0, yy / size)
    streak = norm01(blur(src, 2.0 * s, 1.0 * s))
    streak = norm01(np.cumsum(streak, axis=0)) * smoothstep(1.0, 0.3, yy / size)
    streak *= smoothstep(0.35, 0.75, fbm(size, 6, 3, rng) + 0.3) * edge
    t = TextureSet("decal_grime_streaks", "decals", 2.0, "Soot and rain-free grime runs under a window sill (RGBA decal)")
    t.albedo = np.broadcast_to(rgb(0.08, 0.07, 0.06), (size, size, 3)).copy()
    t.alpha = np.clip(streak * 0.85, 0, 1)
    t.height = 1.0 - streak * 0.2
    t.rough = np.full((size, size), 0.8)
    out.append(t.finish(normal_strength=2.0, scale=s, ao_strength=0.5))

    # damp patch with tide lines
    r = np.hypot(xx - size / 2, yy - size / 2) / (size / 2) + (fbm(size, 4, 4, rng) - 0.5) * 0.5
    body = smoothstep(0.9, 0.55, r)
    tide = smoothstep(0.03, 0.0, np.abs(r - 0.88)) + smoothstep(0.025, 0.0, np.abs(r - 0.72)) * 0.6
    t = TextureSet("decal_water_stain", "decals", 1.5, "Damp patch with tide lines (RGBA decal)")
    t.albedo = np.broadcast_to(rgb(0.36, 0.3, 0.2), (size, size, 3)).copy()
    t.alpha = np.clip(body * 0.35 + tide * 0.6, 0, 1) * edge
    t.height = 1.0 - body * 0.05
    t.rough = np.full((size, size), 0.6)
    out.append(t.finish(normal_strength=1.0, scale=s, ao_strength=0.2))

    # torn poster: coloured blocks (stand-ins for print) with ripped edges
    img = Image.new("RGB", (size, size), (220, 205, 170))
    d = ImageDraw.Draw(img)
    cols = [(196, 40, 40), (30, 60, 140), (240, 190, 40), (20, 20, 20), (40, 120, 70)]
    d.rectangle([0, 0, size, size * 0.28], fill=cols[rng.integers(0, 5)])
    for k in range(7):
        y0 = size * (0.34 + k * 0.08)
        d.rectangle([size * 0.1, y0, size * rng.uniform(0.5, 0.9), y0 + size * 0.035], fill=cols[3])
    d.ellipse([size * 0.6, size * 0.05, size * 0.92, size * 0.37], fill=cols[2])
    paper = np.asarray(img).astype(np.float64) / 255.0
    tear = smoothstep(0.42, 0.5, fbm(size, 5, 5, rng) * 0.6 + edge * 0.6)
    fadeimg = lerp(paper, rgb(0.85, 0.82, 0.74), smoothstep(0.3, 0.9, fbm(size, 3, 3, rng)) * 0.5)
    t = TextureSet("decal_poster_torn", "decals", 0.8, "Torn election-style poster, colour blocks only (RGBA decal)")
    t.albedo = np.clip(fadeimg, 0, 1)
    t.alpha = tear
    t.height = 0.5 + tear * 0.1
    t.rough = np.full((size, size), 0.85)
    out.append(t.finish(normal_strength=2.0, scale=s, ao_strength=0.3))
    return out


# =============================================================================================
# 10. Shared: grime noise for the surface shader, and the smog sky cover panorama
# =============================================================================================

def tex_grime_noise(out, rng, manifest):
    size = 512
    r = fbm(size, 3, 5, rng)
    g = norm01(blur(rng.random((size, size)), 1.0, 40.0))
    b = rng.random((size, size)) * 0.5 + fbm(size, 64, 2, rng) * 0.5
    f1, _, _ = worley(size, 12, rng)
    a = norm01(f1)
    (out / "shared").mkdir(parents=True, exist_ok=True)
    save_rgba(np.dstack([r, g, b, a]), out / "shared" / "grime_noise.png")
    manifest["shared"]["grime_noise"] = "R macro variation, G vertical streaks, B speckle, A cells (512 px, linear)"
    print("  shared/grime_noise.png")


def tex_sky_cover(out, rng, manifest):
    w, h = 2048, 1024
    yy = np.arange(h)[:, None] / h
    clouds = fbm(w, 4, 6, rng, gain=0.55, h=h)
    wisps = norm01(blur(fbm(w, 8, 4, rng, h=h), 30.0, 3.0))
    above = smoothstep(0.52, 0.47, yy)
    band = np.exp(-((yy - 0.47) / 0.07) ** 2)
    density = np.clip(smoothstep(0.42, 0.85, clouds * 0.75 + wisps * 0.35) * above * (0.4 + 0.6 * smoothstep(0.1, 0.4, yy)), 0, 1)
    density = np.clip(density + band * 0.55 * (0.7 + 0.3 * clouds), 0, 1)
    colour = lerp(rgb(0.95, 0.9, 0.82), rgb(0.62, 0.58, 0.52), clouds)
    colour = lerp(colour, rgb(0.86, 0.74, 0.6), band)
    (out / "shared").mkdir(parents=True, exist_ok=True)
    save_rgba(np.dstack([colour, density]), out / "shared" / "sky_smog_cover.png")
    manifest["shared"]["sky_smog_cover"] = "2048x1024 panorama for ProceduralSkyMaterial.sky_cover: smog band on the horizon, broken haze above"
    print("  shared/sky_smog_cover.png")


# =============================================================================================
# 11. Faces: twelve people, drawn front-on, then wrapped onto a sphere (equirectangular)
# =============================================================================================

SKIN = {"wheat": rgb(0.78, 0.6, 0.47), "light_brown": rgb(0.69, 0.5, 0.37), "brown": rgb(0.6, 0.42, 0.3),
        "deep_brown": rgb(0.47, 0.32, 0.22), "dark": rgb(0.38, 0.25, 0.18),
        "sakib": rgb(0.64, 0.46, 0.37)}      # sampled from S M Nazmuz Sakib's own photo (Profile 4), studio light removed
HAIR = {"black": rgb(0.045, 0.04, 0.038), "brown_black": rgb(0.08, 0.06, 0.05), "grey": rgb(0.55, 0.54, 0.52),
        "white": rgb(0.82, 0.81, 0.78), "henna": rgb(0.32, 0.12, 0.06), "burgundy": rgb(0.36, 0.07, 0.08),
        "dark_brown": rgb(0.13, 0.08, 0.06)}

FACES = [
    # Sakib follows S M Nazmuz Sakib's own photo: curly black hair, full black beard and mustache, broad nose, full lips
    {"id": "sakib", "female": False, "age": 28, "skin": "sakib", "hair": "black", "facial": "beard", "brow": 1.15,
     "style": "curly", "under_eye": 0.45, "note": "Sakib: curly hair, full beard, tired eyes (from his own photo)"},
    {"id": "m_young_clean", "female": False, "age": 21, "skin": "brown", "hair": "black", "facial": "clean", "brow": 0.9, "style": "short"},
    {"id": "m_mustache", "female": False, "age": 38, "skin": "deep_brown", "hair": "black", "facial": "mustache", "brow": 1.1, "style": "short"},
    {"id": "m_beard_full", "female": False, "age": 45, "skin": "brown", "hair": "brown_black", "facial": "beard", "brow": 1.0, "style": "short"},
    {"id": "m_elder_white", "female": False, "age": 68, "skin": "light_brown", "hair": "white", "facial": "white_beard", "brow": 0.8,
     "style": "receding", "glasses": True, "lines": 1.0},
    {"id": "m_stubble_dark", "female": False, "age": 30, "skin": "dark", "hair": "black", "facial": "stubble", "brow": 1.15, "style": "crop"},
    {"id": "m_goon_scar", "female": False, "age": 33, "skin": "deep_brown", "hair": "black", "facial": "goatee", "brow": 1.2, "style": "crop",
     "scar": True},
    {"id": "m_henna_beard", "female": False, "age": 58, "skin": "brown", "hair": "grey", "facial": "henna_beard", "brow": 0.9,
     "style": "receding", "lines": 0.7},
    {"id": "m_curly_young", "female": False, "age": 22, "skin": "brown", "hair": "black", "facial": "clean", "brow": 1.0, "style": "curly"},
    {"id": "m_glasses_mid", "female": False, "age": 41, "skin": "light_brown", "hair": "black", "facial": "mustache", "brow": 1.0,
     "style": "side_part", "glasses": True, "lines": 0.3},
    {"id": "m_round_clean", "female": False, "age": 35, "skin": "wheat", "hair": "brown_black", "facial": "clean", "brow": 0.95, "style": "short"},
    {"id": "m_beard_trim", "female": False, "age": 29, "skin": "deep_brown", "hair": "black", "facial": "beard", "brow": 1.1, "style": "crop"},
    {"id": "f_young", "female": True, "age": 22, "skin": "light_brown", "hair": "black", "brow": 0.6, "style": "long_middle", "kajal": True},
    {"id": "f_nosepin", "female": True, "age": 29, "skin": "brown", "hair": "brown_black", "brow": 0.65, "style": "long_middle",
     "kajal": True, "nosepin": True},
    {"id": "f_wheat", "female": True, "age": 25, "skin": "wheat", "hair": "black", "brow": 0.55, "style": "long_side", "kajal": False},
    {"id": "f_elder", "female": True, "age": 62, "skin": "deep_brown", "hair": "grey", "brow": 0.5, "style": "bun", "glasses": True,
     "lines": 0.9},
    # original faces made from general Bangladeshi styling references (no individual's likeness copied)
    {"id": "f_lawyer_bun", "female": True, "age": 32, "skin": "brown", "hair": "black", "brow": 0.75, "style": "bun", "kajal": True,
     "nosepin": True, "lipstick": [0.42, 0.07, 0.13], "earrings": "gold_hoop"},
    {"id": "f_wavy_side", "female": True, "age": 27, "skin": "light_brown", "hair": "dark_brown", "brow": 0.65, "style": "long_side",
     "kajal": True, "nosepin": True, "lipstick": [0.6, 0.37, 0.36]},
    {"id": "f_soft_bun", "female": True, "age": 38, "skin": "light_brown", "hair": "black", "brow": 0.6, "style": "bun",
     "lipstick": [0.55, 0.2, 0.21], "earrings": "stud", "lines": 0.2},
    {"id": "f_cateye", "female": True, "age": 30, "skin": "wheat", "hair": "brown_black", "brow": 0.6, "style": "long_middle",
     "glasses": "cateye", "lipstick": [0.48, 0.12, 0.15], "earrings": "jhumka"},
    {"id": "f_straight_smile", "female": True, "age": 24, "skin": "wheat", "hair": "dark_brown", "brow": 0.7, "style": "long_middle",
     "kajal": True, "lipstick": [0.66, 0.4, 0.4]},
    {"id": "f_round_bindi", "female": True, "age": 28, "skin": "light_brown", "hair": "black", "brow": 0.6, "style": "bun", "kajal": True,
     "bindi": [0.6, 0.05, 0.08], "earrings": "jhumka", "lipstick": [0.6, 0.3, 0.32]},
    {"id": "f_matron_bindi", "female": True, "age": 50, "skin": "light_brown", "hair": "black", "brow": 0.7, "style": "bun", "kajal": "heavy",
     "bindi": [0.9, 0.25, 0.5], "earrings": "gold_hoop", "lipstick": [0.55, 0.3, 0.32], "lines": 0.4},
    {"id": "f_saree_elder2", "female": True, "age": 58, "skin": "brown", "hair": "grey", "brow": 0.55, "style": "bun",
     "earrings": "gold_hoop", "lipstick": [0.6, 0.3, 0.36], "lines": 0.6},
    {"id": "f_red_hair", "female": True, "age": 26, "skin": "wheat", "hair": "burgundy", "brow": 0.65, "style": "long_side", "kajal": True,
     "nosepin": True, "lipstick": [0.55, 0.25, 0.28], "earrings": "jhumka"},
    {"id": "f_bold_kajal", "female": True, "age": 34, "skin": "brown", "hair": "black", "brow": 0.75, "style": "long_side",
     "kajal": "heavy", "lipstick": [0.62, 0.1, 0.12], "earrings": "stud"},
    {"id": "f_flower_bun", "female": True, "age": 30, "skin": "brown", "hair": "black", "brow": 0.7, "style": "bun_flowers",
     "kajal": "heavy", "bindi": [0.55, 0.05, 0.1], "lipstick": [0.5, 0.25, 0.3], "earrings": "jhumka"},
]


class FaceCanvas:
    """Front view of the head: x, y in [-1, 1] as the viewer sees it (x right, y up)."""

    def __init__(self, res):
        self.res = res
        lin = (np.arange(res) + 0.5) / res * 2.0 - 1.0
        self.X, self.Y = np.meshgrid(lin, -lin)

    def ellipse(self, cx, cy, rx, ry, soft=0.012, angle=0.0):
        x, y = self.X - cx, self.Y - cy
        if angle:
            ca, sa = math.cos(angle), math.sin(angle)
            x, y = x * ca + y * sa, -x * sa + y * ca
        d = np.sqrt((x / rx) ** 2 + (y / ry) ** 2)
        return smoothstep(1.0 + soft / min(rx, ry), 1.0 - soft / min(rx, ry), d)

    def gauss(self, cx, cy, rx, ry):
        return np.exp(-(((self.X - cx) / rx) ** 2 + ((self.Y - cy) / ry) ** 2))

    def band_y(self, f, lo, hi, x0, x1, soft=0.01):
        """Mask between two curves y = lo(x) and y = hi(x) for x0 < x < x1."""
        X, Y = self.X, self.Y
        m = smoothstep(lo(X) - soft, lo(X) + soft, Y) * smoothstep(hi(X) + soft, hi(X) - soft, Y)
        return m * smoothstep(x0 - soft, x0 + soft, X) * smoothstep(x1 + soft, x1 - soft, X)


def _strokes(res, strokes, width, colour_alpha=255):
    """Hair strokes (eyebrows, lashes, beard) drawn with PIL at 2x and downsampled. Returns coverage [0, 1]."""
    ss = res * 2
    img = Image.new("L", (ss, ss), 0)
    d = ImageDraw.Draw(img)
    for (x0, y0, x1, y1, w) in strokes:
        d.line([((x0 + 1) / 2 * ss, (1 - y0) / 2 * ss), ((x1 + 1) / 2 * ss, (1 - y1) / 2 * ss)],
               fill=colour_alpha, width=max(1, int(w * width * ss)))
    img = img.resize((res, res), Image.LANCZOS)
    return np.asarray(img).astype(np.float64) / 255.0


# Proportions in front view, on the unit head (radius 1). Real heads: the eyes sit on the middle line,
# an eye is about a fifth of the head's width, the mouth is as wide as the pupils are apart.
EYE_X, EYE_Y, EYE_W, EYE_H = 0.37, 0.06, 0.175, 0.07
IRIS_R, PUPIL_R = 0.06, 0.025
BROW_Y, BROW_HALF = 0.26, 0.2
NOSE_TIP_Y, NOSTRIL_X, NOSTRIL_Y = -0.2, 0.085, -0.265
MOUTH_Y = -0.46
CHIN_Y = -0.78


def beard_top(x):
    """Upper edge of a beard: under the nose at the centre, rising along the cheeks to the sideburns."""
    return -0.43 + 0.36 * smoothstep(0.32, 0.97, np.abs(x))


def draw_face_front(spec, res, rng):
    """Paints the face (no scalp hair, no full beard) with its height and roughness, in front view."""
    c = FaceCanvas(res)
    X, Y = c.X, c.Y
    skin = SKIN[spec["skin"]]
    hair_c = HAIR[spec["hair"]]
    female = spec["female"]
    age = spec["age"]
    lines = spec.get("lines", 0.0)

    noise = fbm(res, 16, 4, rng)
    pores = fbm(res, 160, 2, rng)
    alb = np.broadcast_to(skin, (res, res, 3)).copy() * (0.965 + 0.05 * noise)[..., None] * (0.988 + 0.025 * pores)[..., None]
    height = np.zeros((res, res))
    rough = np.full((res, res), 0.55)

    # skin zones
    alb = lerp(alb, skin * 1.05, c.gauss(0, 0.42, 0.5, 0.22) * 0.6)
    blush = c.gauss(-0.48, -0.16, 0.22, 0.17) + c.gauss(0.48, -0.16, 0.22, 0.17)
    alb = lerp(alb, skin * rgb(1.07, 0.92, 0.9), blush * (0.5 if female else 0.3))
    alb = lerp(alb, skin * rgb(1.05, 0.92, 0.9), c.gauss(0, NOSE_TIP_Y, 0.09, 0.07) * 0.5)
    alb = lerp(alb, skin * 0.92, c.gauss(0, MOUTH_Y + 0.02, 0.34, 0.15) * 0.4)
    rough = rough - c.gauss(0, 0.38, 0.32, 0.2) * 0.12 - c.gauss(0, -0.08, 0.09, 0.22) * 0.1

    # bone structure for the normal map
    height += c.gauss(0, BROW_Y - 0.02, 0.6, 0.08) * 0.25
    height += (c.gauss(-0.55, -0.08, 0.22, 0.13) + c.gauss(0.55, -0.08, 0.22, 0.13)) * 0.22
    height -= (c.gauss(-EYE_X, EYE_Y + 0.02, 0.22, 0.12) + c.gauss(EYE_X, EYE_Y + 0.02, 0.22, 0.12)) * 0.3
    height += c.gauss(0, CHIN_Y + 0.08, 0.2, 0.12) * 0.28
    socket = c.gauss(-EYE_X, EYE_Y + 0.07, 0.2, 0.06) + c.gauss(EYE_X, EYE_Y + 0.07, 0.2, 0.06)
    alb = alb * (1.0 - 0.07 * socket)[..., None]

    # nose
    bridge = c.gauss(0, -0.05, 0.06, 0.22)
    tip = c.gauss(0, NOSE_TIP_Y, 0.09, 0.075)
    wings = c.gauss(-NOSTRIL_X - 0.02, NOSTRIL_Y + 0.03, 0.065, 0.05) + c.gauss(NOSTRIL_X + 0.02, NOSTRIL_Y + 0.03, 0.065, 0.05)
    height += bridge * 0.5 + tip * 0.6 + wings * 0.32
    side = c.gauss(-0.1, -0.08, 0.04, 0.18) + c.gauss(0.1, -0.08, 0.04, 0.18)
    alb = alb * (1.0 - 0.13 * side)[..., None]
    alb = lerp(alb, skin * 1.1, c.gauss(0, -0.07, 0.028, 0.14) * 0.35 + c.gauss(0, NOSE_TIP_Y + 0.02, 0.03, 0.025) * 0.3)
    nostrils = c.ellipse(-NOSTRIL_X * 0.72, NOSTRIL_Y, 0.042, 0.02, 0.01, 0.35) + c.ellipse(NOSTRIL_X * 0.72, NOSTRIL_Y, 0.042, 0.02, 0.01, -0.35)
    alb = lerp(alb, skin * 0.3, np.clip(nostrils, 0, 1) * 0.9)
    height -= nostrils * 0.35
    alar = np.zeros((res, res))
    for sx in (-1.0, 1.0):
        alar += np.clip(c.ellipse(sx * (NOSTRIL_X + 0.035), NOSTRIL_Y + 0.035, 0.055, 0.055, 0.02)
                        - c.ellipse(sx * (NOSTRIL_X + 0.025), NOSTRIL_Y + 0.045, 0.045, 0.047, 0.02), 0, 1)
    alb = alb * (1.0 - 0.25 * alar)[..., None]
    under_nose = c.gauss(0, NOSTRIL_Y - 0.04, 0.09, 0.02)
    alb = alb * (1.0 - 0.1 * under_nose)[..., None]

    # nasolabial folds and age lines
    fold = np.zeros((res, res))
    for sx in (-1.0, 1.0):
        fold += np.clip(c.ellipse(sx * 0.26, -0.36, 0.15, 0.19, 0.03) - c.ellipse(sx * 0.24, -0.37, 0.14, 0.18, 0.03), 0, 1)
    fold *= (Y < -0.24) * (np.abs(X) > 0.13)
    alb = alb * (1.0 - (0.1 + 0.14 * lines) * fold)[..., None]
    height -= fold * 0.1
    if lines > 0:
        for k in range(3):
            fy = 0.44 + k * 0.055
            wr = smoothstep(0.011, 0.0, np.abs(Y - fy - 0.03 * np.cos(X * 3.0))) * smoothstep(0.4, 0.22, np.abs(X))
            alb = alb * (1.0 - 0.1 * lines * wr)[..., None]
            height -= wr * 0.05 * lines
        for k in range(3):
            crow = smoothstep(0.008, 0.0, np.abs(Y - EYE_Y + 0.03 - k * 0.03 - (np.abs(X) - 0.56) * 0.35)) * (np.abs(X) > 0.56) * (np.abs(X) < 0.66)
            alb = alb * (1.0 - 0.1 * lines * crow)[..., None]

    # mouth
    mw = 0.24 if female else 0.26
    my = MOUTH_Y
    upper_top = lambda x: my + 0.055 * np.sqrt(np.clip(1 - (x / mw) ** 2, 0, 1)) - 0.014 * np.exp(-(x / 0.035) ** 2) + 0.01 * np.exp(-((np.abs(x) - 0.06) / 0.035) ** 2)
    mouth_line = lambda x: my + 0.006 * np.cos(x / mw * np.pi) - 0.004
    lower_bot = lambda x: my - (0.08 if female else 0.068) * np.sqrt(np.clip(1 - (x / (mw * 0.9)) ** 2, 0, 1))
    up = c.band_y(None, mouth_line, upper_top, -mw, mw, 0.008)
    lo = c.band_y(None, lower_bot, mouth_line, -mw * 0.9, mw * 0.9, 0.008)
    lip_c = lerp(skin, rgb(0.6, 0.27, 0.27) if female else rgb(0.48, 0.27, 0.23), 0.7 if female else 0.5)
    if spec.get("lipstick"):
        lip_c = lerp(lip_c, rgb(*spec["lipstick"]), 0.85)
    alb = lerp(alb, lip_c * 0.84, up)
    alb = lerp(alb, lip_c, lo)
    alb = lerp(alb, lip_c * 1.2, c.gauss(0, my - 0.035, 0.07, 0.014) * lo * 0.6)
    vermilion = smoothstep(0.006, 0.0, np.abs(Y - upper_top(X))) * smoothstep(mw, mw * 0.7, np.abs(X))
    alb = lerp(alb, skin * 1.08, vermilion * 0.35)
    line = smoothstep(0.007, 0.0, np.abs(Y - mouth_line(X))) * smoothstep(mw * 1.02, mw * 0.8, np.abs(X))
    alb = alb * (1.0 - 0.6 * line)[..., None]
    corners = c.gauss(-mw, my, 0.03, 0.022) + c.gauss(mw, my, 0.03, 0.022)
    alb = alb * (1.0 - 0.22 * corners)[..., None]
    height += up * 0.18 + lo * 0.26 - line * 0.15
    rough = rough - (up + lo) * 0.18
    height += (c.gauss(-0.03, -0.37, 0.014, 0.055) + c.gauss(0.03, -0.37, 0.014, 0.055)) * 0.08
    height -= c.gauss(0, -0.37, 0.018, 0.055) * 0.05
    height -= c.gauss(0, my - 0.12, 0.14, 0.035) * 0.08

    # eyes
    brow_amt = spec.get("brow", 1.0)
    for sx in (-1.0, 1.0):
        ex, ey = EYE_X * sx, EYE_Y
        a_up, a_lo = EYE_H * 1.05, EYE_H * 0.72
        r_up = (EYE_W ** 2 + a_up ** 2) / (2 * a_up)
        r_lo = (EYE_W ** 2 + a_lo ** 2) / (2 * a_lo)
        # the outer corner sits a touch higher than the inner one
        Yt = Y - 0.025 * (X - ex) / EYE_W * sx
        d_up = np.hypot(X - ex, Yt - (ey + a_up - r_up)) - r_up
        d_lo = np.hypot(X - ex, Yt - (ey - a_lo + r_lo)) - r_lo
        eye = smoothstep(0.004, -0.004, np.maximum(d_up, d_lo))
        alb = lerp(alb, rgb(0.87, 0.84, 0.8), eye)
        corner_dark = c.gauss(ex - EYE_W * 0.9, ey, 0.05, 0.04) + c.gauss(ex + EYE_W * 0.9, ey, 0.05, 0.04)
        alb = alb * (1.0 - 0.25 * eye * corner_dark)[..., None]
        caruncle = c.ellipse(ex - sx * (EYE_W - 0.02), ey - 0.005, 0.018, 0.014, 0.006) * eye
        alb = lerp(alb, rgb(0.72, 0.45, 0.42), caruncle * 0.8)
        ix, iy = ex - 0.006 * sx, ey + 0.002
        iris = c.ellipse(ix, iy, IRIS_R, IRIS_R, 0.006) * eye
        rr = np.hypot(X - ix, Y - iy) / IRIS_R
        rays = 0.5 + 0.5 * np.sin(np.arctan2(Y - iy, X - ix) * 40 + pores * 6)
        iris_c = lerp(rgb(0.33, 0.2, 0.11), rgb(0.12, 0.07, 0.04), smoothstep(0.25, 1.0, rr))
        iris_c = iris_c * (0.85 + 0.25 * rays)[..., None]
        limbal = smoothstep(0.82, 1.0, rr)
        alb = lerp(alb, iris_c * (1.0 - 0.45 * limbal)[..., None], iris)
        pupil = c.ellipse(ix, iy, PUPIL_R, PUPIL_R, 0.004) * eye
        alb = lerp(alb, rgb(0.015, 0.015, 0.015), pupil)
        lid_shadow = smoothstep(0.035, 0.0, -d_up) * eye
        alb = alb * (1.0 - 0.38 * lid_shadow)[..., None]
        catch = c.ellipse(ix + 0.022, iy + 0.02, 0.011, 0.011, 0.003) * eye
        alb = lerp(alb, rgb(0.98, 0.98, 0.96), catch * 0.9)
        rough = lerp(rough, 0.06, eye)
        height += eye * 0.12 + iris * 0.03
        span = np.abs(X - ex) < EYE_W * 1.06
        upper_line = smoothstep(0.011 if female else 0.009, 0.0, np.abs(d_up)) * (d_lo < 0.012) * span
        lower_line = smoothstep(0.005, 0.0, np.abs(d_lo)) * (np.abs(X - ex) < EYE_W * 0.95)
        alb = lerp(alb, hair_c * 0.7, upper_line * 0.95)
        alb = alb * (1.0 - 0.28 * lower_line)[..., None]
        if spec.get("kajal"):
            wx = (X - ex) * sx
            wing = smoothstep(0.01, 0.0, np.abs(Y - (ey + 0.03 + (wx - EYE_W) * 0.5))) * (wx > EYE_W * 0.9) * (wx < EYE_W * 1.35)
            heavy = 1.6 if spec.get("kajal") == "heavy" else 1.0
            alb = lerp(alb, rgb(0.03, 0.03, 0.03), np.clip((upper_line * 0.6 + wing + lower_line * 0.9) * heavy, 0, 1))
            if heavy > 1.0:
                smoky = c.gauss(ex, ey + 0.035, 0.13, 0.03)
                alb = lerp(alb, alb * rgb(0.62, 0.55, 0.55), np.clip(smoky, 0, 1) * 0.5)
        crease = smoothstep(0.007, 0.0, np.abs(d_up - 0.03)) * (np.abs(X - ex) < EYE_W * 0.85) * (Y > ey)
        alb = alb * (1.0 - 0.2 * crease)[..., None]
        height -= crease * 0.06
        under = c.gauss(ex, ey - 0.09, 0.14, 0.04) * (0.25 + spec.get("under_eye", 0.0) * 0.5 + age / 220.0)
        alb = lerp(alb, alb * rgb(0.8, 0.74, 0.77), np.clip(under, 0, 1))
        lash = []
        n_lash = 26 if female else 14
        for k in range(n_lash):
            t = k / (n_lash - 1)
            x0 = ex - EYE_W + t * EYE_W * 2
            y0 = ey + a_up * (1 - ((x0 - ex) / EYE_W) ** 2) * 0.96 + 0.025 * (x0 - ex) / EYE_W * sx
            ln = 0.03 if female else 0.018
            lash.append((x0, y0, x0 + (x0 - ex) * 0.22, y0 + ln, 0.7))
        alb = lerp(alb, rgb(0.03, 0.03, 0.03), _strokes(res, lash, 0.0035) * (0.85 if female else 0.5))

        # eyebrows: short hairs following an arch, thick at the inner end
        strokes = []
        for k in range(int(220 * brow_amt)):
            t = rng.random()
            tt = t * 2 - 1                      # -1 inner end ... +1 outer end (mirrored per side)
            bx = ex + tt * sx * BROW_HALF
            arch = BROW_Y + 0.045 * (1 - (tt - 0.15) ** 2) - 0.025 * max(tt, 0) ** 2
            thick = (0.028 if female else 0.042) * brow_amt * (1.0 - 0.55 * (tt + 1) / 2)
            by = arch + rng.uniform(-thick, thick) * 0.75
            ang = 0.45 + 0.6 * (tt + 1) / 2
            strokes.append((bx, by, bx + math.cos(ang) * 0.032 * sx, by + math.sin(ang) * 0.012 * (1 if tt < 0.3 else -0.6), rng.uniform(0.6, 1.0)))
        bcov = _strokes(res, strokes, 0.0035)
        alb = lerp(alb, hair_c * 0.9, np.clip(bcov * 1.25, 0, 1) * 0.92)
        height += bcov * 0.05

    # mustache and goatee (full beards and stubble are painted round the jaw in wrap_face)
    facial = "clean" if female else spec.get("facial", "clean")
    beard_c = {"white_beard": HAIR["white"], "henna_beard": HAIR["henna"]}.get(facial, hair_c)
    if facial in ("mustache", "beard", "henna_beard", "white_beard", "goatee"):
        ms = []
        for k in range(420):
            t = rng.random() * 2 - 1
            x = t * mw * 1.12
            y = float(upper_top(np.array([x]))[0]) + 0.01 + rng.uniform(0, 0.06) * (1 - 0.55 * abs(t))
            ms.append((x, y, x + t * 0.025, y - 0.035, rng.uniform(0.7, 1.0)))
        mcov = _strokes(res, ms, 0.004)
        alb = lerp(alb, beard_c, np.clip(mcov * 1.3, 0, 1) * 0.95)
        height += mcov * 0.08
    if facial == "goatee":
        gs = []
        for k in range(500):
            x = rng.normal(0, 0.07)
            y = my - 0.09 - abs(rng.normal(0, 0.1))
            gs.append((x, y, x + rng.normal(0, 0.01), y - 0.04, rng.uniform(0.7, 1.0)))
        gcov = _strokes(res, gs, 0.004) * (1 - lo)
        alb = lerp(alb, beard_c, np.clip(gcov * 1.3, 0, 1) * 0.95)
        height += gcov * 0.08

    if spec.get("scar"):
        scar = smoothstep(0.014, 0.0, np.abs((Y - BROW_Y + 0.05) - (X - EYE_X) * 1.7)) * (np.abs(X - EYE_X) < 0.11)
        alb = lerp(alb, skin * 1.28, scar * 0.85)
        height += scar * 0.05
    if spec.get("nosepin"):
        pin = c.ellipse(NOSTRIL_X + 0.03, NOSTRIL_Y + 0.04, 0.014, 0.014, 0.004)
        alb = lerp(alb, rgb(0.95, 0.78, 0.35), pin)
        rough = lerp(rough, 0.2, pin)
    if spec.get("bindi"):
        dot = c.ellipse(0.0, BROW_Y + 0.07, 0.024, 0.024, 0.005)
        alb = lerp(alb, rgb(*spec["bindi"]), dot)
        height += dot * 0.03
    if spec.get("glasses") == "cateye":
        frame = np.zeros((res, res))
        for sx in (-1.0, 1.0):
            r = np.hypot((X - EYE_X * sx) / 0.24, (Y - EYE_Y - 0.01) / 0.15)
            frame = np.maximum(frame, smoothstep(0.1, 0.0, np.abs(r - 1.0)))
            wing = smoothstep(0.02, 0.0, np.abs((Y - EYE_Y - 0.12) - (np.abs(X) - (EYE_X + 0.17)) * 0.9)) * (np.abs(X) > EYE_X + 0.12) * (np.abs(X) < EYE_X + 0.27) * (X * sx > 0)
            frame = np.maximum(frame, wing)
        frame = np.maximum(frame, smoothstep(0.014, 0.0, np.abs(Y - EYE_Y - 0.05)) * (np.abs(X) < 0.14))
        tort = 0.6 + 0.4 * fbm(res, 30, 2, rng)
        alb = lerp(alb, rgb(0.32, 0.15, 0.06) * tort[..., None], frame)
        rough = lerp(rough, 0.2, frame)
        height += frame * 0.08
    elif spec.get("glasses"):
        frame = np.zeros((res, res))
        for sx in (-1.0, 1.0):
            r = np.hypot((X - EYE_X * sx) / 0.23, (Y - EYE_Y) / 0.17)
            frame = np.maximum(frame, smoothstep(0.07, 0.0, np.abs(r - 1.0)))
        frame = np.maximum(frame, smoothstep(0.012, 0.0, np.abs(Y - EYE_Y - 0.06 - 0.03 * np.cos(X * 9))) * (np.abs(X) < 0.15))
        alb = lerp(alb, rgb(0.08, 0.07, 0.06), frame)
        rough = lerp(rough, 0.25, frame)
        height += frame * 0.08
    return alb, height, rough, (up, lo)


def wrap_face(spec, front, rng, w=1024, h=512):
    """Equirectangular head texture: u around (face at 0.5 = -Z), v top to bottom."""
    alb_f, hgt_f, rgh_f, (up_f, lo_f) = front
    res = alb_f.shape[0]
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    U, V = np.meshgrid(u, v)
    phi, theta = U * 2.0 * np.pi, V * np.pi
    PX, PY, PZ = np.sin(phi) * np.sin(theta), np.cos(theta), np.cos(phi) * np.sin(theta)
    skin = SKIN[spec["skin"]]
    hair_c = HAIR[spec["hair"]]
    female = spec["female"]

    base_noise = fbm(w, 16, 4, rng, h=h)
    alb = np.broadcast_to(skin, (h, w, 3)).copy() * (0.965 + 0.05 * base_noise)[..., None]
    height = np.zeros((h, w))
    rough = np.full((h, w), 0.58)

    # the front drawing; viewer-x is -X (the character's right appears on the viewer's left)
    xv, yv = -PX, PY
    col = (xv + 1.0) * 0.5 * res - 0.5
    row = (1.0 - yv) * 0.5 * res - 0.5
    wf = smoothstep(0.02, 0.4, -PZ)
    alb = lerp(alb, sample_wrap(alb_f, col, row), wf)
    height = lerp(height, sample_wrap(hgt_f, col, row), wf)
    rough = lerp(rough, sample_wrap(rgh_f, col, row), wf)
    lips = np.clip(sample_wrap(up_f + lo_f, col, row), 0, 1) * wf

    ang = np.arctan2(PX, -PZ)
    a = np.abs(ang)

    # ears
    for side in (-1.0, 1.0):
        da = (ang - side * np.pi / 2) / 0.17
        dy = (PY + 0.02) / 0.2
        ear = smoothstep(1.06, 0.94, np.hypot(da, dy))
        inner = smoothstep(0.75, 0.6, np.hypot(da * 1.25 + 0.15 * side, dy * 1.2))
        alb = lerp(alb, skin * rgb(1.04, 0.9, 0.86), ear * 0.6)
        alb = alb * (1.0 - 0.3 * inner * ear)[..., None]
        height += ear * 0.25 - inner * ear * 0.2

    # beards and stubble, painted in 3D so they follow the jaw round to the ears
    facial = "clean" if female else spec.get("facial", "clean")
    if facial in ("beard", "white_beard", "henna_beard", "stubble"):
        beard_c = {"white_beard": HAIR["white"], "henna_beard": HAIR["henna"]}.get(facial, hair_c)
        x_equiv = np.clip(np.sin(np.minimum(a, np.pi / 2)) + np.maximum(a - np.pi / 2, 0) * 0.3, 0, 1.2)
        top = np.where(a < 1.35, beard_top(x_equiv), 0.0)
        edge_n = (fbm(w, 60, 3, rng, h=h) - 0.5) * 0.05
        stubble = facial == "stubble"
        zone = smoothstep(top + 0.02, top - (0.1 if not stubble else 0.06), PY + edge_n)
        zone *= smoothstep(1.85, 1.55, a) * smoothstep(-0.97, -0.88, PY) * (1.0 - lips)
        strands = norm01(blur(rng.random((h, w)), 0.7, 2.5 if stubble else 4.0))
        clump = fbm(w, 30, 3, rng, h=h)
        if stubble:
            # a five o'clock shadow: a cool darkening of the skin plus sparse short hairs
            shadow_c = alb * rgb(0.78, 0.76, 0.8)
            alb = lerp(alb, shadow_c, zone * 0.55)
            dots = (rng.random((h, w)) > 0.82).astype(np.float64)
            cov = np.clip(zone * blur(dots, 0.5) * 0.9 * (0.7 + 0.3 * clump), 0, 1)
            colour = lerp(skin, beard_c, 0.75)
        else:
            dens = 0.95 * (0.75 + 0.25 * clump)
            cov = np.clip(zone * dens * (0.55 + 0.6 * strands), 0, 1)
            colour = beard_c * (0.8 + 0.4 * strands)[..., None]
        alb = lerp(alb, colour, cov)
        rough = lerp(rough, 0.72, zone * (0.4 if stubble else 0.9))
        height += zone * (0.03 if stubble else 0.12) * (0.6 + 0.4 * strands)

    # scalp hair
    style = spec.get("style", "short")
    knots_a = [0.0, 0.6, 1.0, 1.5, 2.2, np.pi]
    lines = {
        "short":       [0.6, 0.55, 0.38, 0.16, -0.35, -0.55],
        "crop":        [0.64, 0.58, 0.42, 0.2, -0.3, -0.5],
        "side_part":   [0.58, 0.54, 0.36, 0.15, -0.38, -0.58],
        "receding":    [0.74, 0.66, 0.42, 0.15, -0.35, -0.55],
        "long_middle": [0.56, 0.45, 0.16, -0.65, -1.0, -1.0],
        "long_side":   [0.52, 0.42, 0.12, -0.6, -1.0, -1.0],
        "bun":         [0.58, 0.48, 0.28, 0.05, -0.45, -0.6],
        "bun_flowers": [0.58, 0.48, 0.28, 0.05, -0.45, -0.6],
        "curly":       [0.54, 0.5, 0.34, 0.12, -0.32, -0.5],
    }[style]
    hairline = np.interp(a, knots_a, lines)
    if style == "side_part":
        hairline = hairline + 0.06 * smoothstep(0.0, 0.5, -ang) * smoothstep(0.9, 0.3, a)
    if style == "long_side":
        hairline = hairline - 0.14 * smoothstep(0.1, 0.5, ang) * smoothstep(1.0, 0.5, a)
    edge_noise = (fbm(w, 50, 3, rng, h=h) - 0.5) * 0.035
    hair = smoothstep(hairline - 0.012, hairline + 0.03, PY + edge_noise)
    if style == "receding":
        hair = hair * (1 - smoothstep(0.86, 0.96, PY) * (a < 1.3) * 0.55)
    strands = norm01(blur(rng.random((h, w)), 1.4, 10.0)) * 0.5 + fbm(w, 24, 3, rng, h=h) * 0.5
    if style == "curly":
        # tight curls: small bright-dark ringlets instead of combed strands, and a ragged hairline
        ring = np.abs(np.sin(fbm(w, 70, 2, rng, h=h) * 40.0))
        strands = np.clip(0.35 * strands + 0.65 * ring, 0, 1)
        hair = smoothstep(hairline - 0.03, hairline + 0.02, PY + edge_noise * 2.5)
    grey_hair = spec["hair"] in ("grey", "white")
    smooth_strands = norm01(blur(strands, 1.5, 4.0))
    hair_alb = hair_c * ((0.88 + 0.18 * smooth_strands) if grey_hair else (0.7 + 0.6 * strands))[..., None]
    if grey_hair:
        hair_alb = lerp(hair_alb, hair_c * 0.72, smoothstep(0.3, 0.1, smooth_strands) * 0.5)
    shine = smoothstep(0.6, 0.9, strands) * smoothstep(0.3, 0.8, PY) * (0.15 if not grey_hair else 0.05)
    hair_alb = hair_alb + shine[..., None]
    if style == "side_part":
        part = smoothstep(0.014, 0.0, np.abs(ang - 0.38)) * (PY > 0.6)
        hair = hair * (1 - part * 0.85)
    if style == "long_middle":
        part = smoothstep(0.012, 0.0, np.abs(ang)) * (PY > 0.5)
        hair = hair * (1 - part * 0.9)
    alb = lerp(alb, hair_alb, hair)
    height += hair * (0.15 + strands * 0.1)
    rough = lerp(rough, 0.62 - 0.15 * strands, hair)

    if style == "bun_flowers":
        # a string of white beli flowers round the bun at the back of the head
        fl = smoothstep(0.12, 0.08, np.hypot((a - np.pi) / 0.55, (PY - 0.1) / 0.09)) * (np.sin(ang * 60.0) > 0.2)
        alb = lerp(alb, rgb(0.95, 0.94, 0.88), fl * 0.9)
        height += fl * 0.2
    earrings = spec.get("earrings")
    if earrings:
        for side in (-1.0, 1.0):
            da = (ang - side * np.pi / 2) / 0.06
            dy = (PY + 0.2) / 0.035
            stud = smoothstep(1.0, 0.7, np.hypot(da, dy))
            alb = lerp(alb, rgb(0.92, 0.72, 0.3) if earrings != "stud" else rgb(0.95, 0.93, 0.88), stud)
            rough = lerp(rough, 0.15, stud)
            height += stud * 0.15

    shadow = smoothstep(0.07, 0.0, np.abs(PY - hairline + 0.035)) * (1 - hair)
    alb = alb * (1.0 - 0.1 * shadow)[..., None]
    neck = smoothstep(-0.7, -0.92, PY)
    alb = alb * (1.0 - 0.08 * neck)[..., None]

    # --- stylised-realism pass (Phase 2): blood flush, contour and highlight, pores, T-zone sheen ---
    fx, fy = xv, PY
    skin_w = (1.0 - hair) * wf

    def g(cx, cy, sx, sy, mirror=True):
        dx = (np.abs(fx) if mirror else fx) - cx
        return np.exp(-(dx / sx) ** 2 - ((fy - cy) / sy) ** 2)

    flush = 0.55 * g(0.45, -0.18, 0.17, 0.13) + 0.7 * g(0.0, -0.2, 0.07, 0.06, False) + 0.35 * g(0.0, -0.73, 0.12, 0.07, False)
    flush = np.clip(flush, 0, 1) * skin_w * (0.8 if female else 0.6)
    alb = lerp(alb, alb * rgb(1.07, 0.92, 0.9), flush * 0.55)
    under_eye = g(0.37, -0.045, 0.12, 0.035) * skin_w
    alb = lerp(alb, alb * rgb(0.9, 0.86, 0.9), under_eye * (0.18 + 0.004 * max(0, spec.get("age", 30) - 25)))
    contour = (0.7 * g(0.11, -0.1, 0.035, 0.09) + 0.6 * g(0.5, -0.32, 0.14, 0.06) + 0.6 * g(0.0, -0.585, 0.12, 0.025, False)
               + 0.5 * g(0.62, -0.62, 0.2, 0.12) + 0.4 * g(0.37, 0.12, 0.13, 0.03))
    alb = alb * (1.0 - 0.085 * np.clip(contour, 0, 1) * skin_w)[..., None]
    light = (0.8 * g(0.0, -0.02, 0.028, 0.16, False) + 0.6 * g(0.0, 0.45, 0.2, 0.12, False) + 0.5 * g(0.0, -0.385, 0.05, 0.02, False)
             + 0.5 * g(0.0, -0.74, 0.06, 0.04, False) + 0.4 * g(0.48, -0.06, 0.08, 0.05))
    alb = alb * (1.0 + 0.06 * np.clip(light, 0, 1) * skin_w)[..., None]
    pores = (fbm(w, 160, 2, rng, h=h) - 0.5)
    alb = alb * (1.0 + 0.035 * pores * skin_w)[..., None]
    height += pores * 0.018 * skin_w
    tzone = np.clip(g(0.0, 0.42, 0.22, 0.14, False) + g(0.0, -0.1, 0.07, 0.2, False), 0, 1) * skin_w
    rough = rough - 0.12 * tzone + 0.04 * pores * skin_w
    lip_sat = lips * 0.5
    alb = lerp(alb, alb * rgb(1.08, 0.9, 0.92), lip_sat)

    normal = normal_from_height(height, 6.0)
    return np.clip(alb, 0, 1), normal, np.clip(rough, 0.05, 1.0), height


def render_head_preview(alb, normal, yaw_deg, size=240, with_alpha=False):
    """Software render of the textured head (orthographic ellipsoid, key + fill + rim light)."""
    lin = (np.arange(size) + 0.5) / size * 2.0 - 1.0
    X, Y = np.meshgrid(lin, -lin)
    sx, sy = 0.92, 1.08
    r2 = (X / sx) ** 2 + (Y / sy) ** 2
    mask = r2 < 1.0
    z = -np.sqrt(np.clip(1.0 - r2, 0, 1))
    px, py, pz = -X / sx, Y / sy, z     # the camera looks down +Z, so image right is world -X
    yaw = math.radians(yaw_deg)
    lx = px * math.cos(yaw) + pz * math.sin(yaw)
    lz = -px * math.sin(yaw) + pz * math.cos(yaw)
    phi = np.mod(np.arctan2(lx, lz), 2 * np.pi)
    theta = np.arccos(np.clip(py, -1, 1))
    h, w = alb.shape[:2]
    col = phi / (2 * np.pi) * w - 0.5
    row = theta / np.pi * h - 0.5
    c = sample_wrap(alb, col, row)
    nt = sample_wrap(normal, col, row) * 2 - 1
    nrm = np.stack([px / sx, py / sy, pz * 1.0], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    up = np.array([0.0, 1.0, 0.0])
    tang = np.cross(up, nrm)
    tang /= np.maximum(np.linalg.norm(tang, axis=-1, keepdims=True), 1e-6)
    bit = np.cross(nrm, tang)
    n2 = nrm * nt[..., 2:3] + tang * nt[..., 0:1] + bit * nt[..., 1:2]
    n2 /= np.linalg.norm(n2, axis=-1, keepdims=True)
    key = np.array([0.45, 0.55, -0.7]); key /= np.linalg.norm(key)
    fill = np.array([-0.6, 0.1, -0.6]); fill /= np.linalg.norm(fill)
    lam = np.clip((n2 * key).sum(-1), 0, 1) * 1.0 + np.clip((n2 * fill).sum(-1), 0, 1) * 0.35 + 0.22
    rim = np.clip(1.0 - (-n2[..., 2]), 0, 1) ** 3 * 0.25
    out = np.clip(c * lam[..., None] + rim[..., None] * np.array([0.9, 0.85, 0.8]), 0, 1)
    if with_alpha:
        edge = np.clip((1.0 - r2) * size * 0.25, 0.0, 1.0)
        return np.dstack([out, edge * mask])
    bg = np.array([0.13, 0.14, 0.15])
    out = np.where(mask[..., None], out, bg)
    return out


def tex_faces(out, rng, manifest, preview_dir=None):
    folder = out / "faces"
    folder.mkdir(parents=True, exist_ok=True)
    entries = []
    previews = []
    for spec in FACES:
        frng = np.random.default_rng(zlib.crc32(spec["id"].encode()))
        front = draw_face_front(spec, 1024, frng)
        alb, nrm, rough, height = wrap_face(spec, front, frng)
        ao = ao_from_height(height, 0.5, 1.6)
        base = folder / f"face_{spec['id']}"
        save_rgb(alb, f"{base}_albedo.png")
        save_rgb(nrm, f"{base}_normal.png")
        save_grey(rough, f"{base}_roughness.png")
        save_grey(ao, f"{base}_ao.png")
        save_rgb(np.dstack([ao, rough, np.zeros_like(ao)]), f"{base}_orm.png")
        portrait = Image.fromarray(_u8(front[0])).resize((512, 512), Image.LANCZOS)
        portrait.save(f"{base}_front.png", optimize=True)
        lit = render_head_preview(alb, nrm, 14, size=768, with_alpha=True)
        Image.fromarray(_u8(lit), "RGBA").resize((384, 384), Image.LANCZOS).save(f"{base}_portrait.png", optimize=True)
        entries.append({"id": spec["id"], "female": spec["female"], "age": spec["age"],
                        "skin": [round(float(x), 3) for x in SKIN[spec["skin"]]],
                        "hair": [round(float(x), 3) for x in HAIR[spec["hair"]]],
                        "style": spec.get("style"), "facial": spec.get("facial", "clean"), "note": spec.get("note", ""),
                        "earrings": spec.get("earrings", ""), "glasses": bool(spec.get("glasses", False)), "bindi": bool(spec.get("bindi", False))})
        if preview_dir is not None:
            previews.append([render_head_preview(alb, nrm, a) for a in (0, 35, 90)])
        print(f"  faces/face_{spec['id']}")
    (folder / "faces.json").write_text(json.dumps({"faces": entries, "mapping": "equirectangular; u = 0.5 faces -Z; v = 0 top"}, indent=1))
    manifest["faces"] = [e["id"] for e in entries]
    return previews


# =============================================================================================
# Preview sheet
# =============================================================================================

def contact_sheet(out, names, path, thumb=200):
    tiles = []
    for folder, name in names:
        p = out / folder / f"{name}_albedo.png"
        n = out / folder / f"{name}_normal.png"
        if not p.exists():
            continue
        a = Image.open(p).convert("RGBA")
        bg = Image.new("RGBA", a.size, (40, 42, 44, 255))
        a = Image.alpha_composite(bg, a).convert("RGB").resize((thumb, thumb), Image.LANCZOS)
        two = Image.new("RGB", (thumb * 2, thumb))
        two.paste(Image.fromarray(np.tile(np.asarray(a), (1, 1, 1))), (0, 0))
        rep = Image.open(p).convert("RGB").resize((thumb // 2, thumb // 2), Image.LANCZOS)
        tiled = Image.new("RGB", (thumb, thumb))
        for i in range(2):
            for j in range(2):
                tiled.paste(rep, (i * thumb // 2, j * thumb // 2))
        two.paste(tiled, (thumb, 0))
        nn = Image.open(n).convert("RGB").resize((thumb // 3, thumb // 3), Image.LANCZOS)
        two.paste(nn, (thumb * 2 - thumb // 3, thumb - thumb // 3))
        tiles.append((name, two))
    cols = 4
    rows = math.ceil(len(tiles) / cols)
    sheet = Image.new("RGB", (cols * (thumb * 2 + 10) + 10, rows * (thumb + 34) + 10), (22, 23, 24))
    d = ImageDraw.Draw(sheet)
    for k, (name, img) in enumerate(tiles):
        x = 10 + (k % cols) * (thumb * 2 + 10)
        y = 10 + (k // cols) * (thumb + 34)
        sheet.paste(img, (x, y + 22))
        d.text((x, y + 4), name + "   (albedo | 2x2 tiling | normal)", fill=(230, 230, 225))
    sheet.save(path, quality=90)
    return path


# =============================================================================================
# Main
# =============================================================================================

GROUPS = ["brick", "asphalt", "tin", "concrete", "plaster", "tile", "awnings", "cloth", "grille", "decals", "shared", "faces"]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--size", type=int, default=1024, help="surface and awning size in pixels (power of two)")
    ap.add_argument("--cloth-size", type=int, default=512)
    ap.add_argument("--out", type=pathlib.Path, default=OUT)
    ap.add_argument("--seed", type=int, default=20261119)
    ap.add_argument("--only", nargs="*", choices=GROUPS, help="generate only these groups")
    ap.add_argument("--preview", action="store_true", help="also write preview sheets to art/textures/_preview")
    args = ap.parse_args()
    groups = args.only or GROUPS
    out = args.out
    out.mkdir(parents=True, exist_ok=True)
    mpath = out / "manifest.json"
    manifest = json.loads(mpath.read_text()) if mpath.exists() else {}
    manifest.setdefault("sets", {})
    manifest.setdefault("shared", {})
    manifest["conventions"] = {"normal": "OpenGL (green up), Godot default", "orm": "R ambient occlusion, G roughness, B metallic",
                               "albedo": "sRGB", "other maps": "linear"}
    rng = np.random.default_rng(args.seed)
    t0 = time.time()
    preview = out / "_preview" if args.preview else None
    if preview:
        preview.mkdir(parents=True, exist_ok=True)
    print("Generating textures into", out)
    S, C = args.size, args.cloth_size
    jobs = {
        "brick": lambda: [tex_brick(S, rng)],
        "asphalt": lambda: [tex_asphalt(S, rng)],
        "tin": lambda: [tex_tin(S, rng, False), tex_tin(S, rng, True)],
        "concrete": lambda: [tex_concrete(S, rng)],
        "plaster": lambda: [tex_plaster(S, rng), tex_plaster(S, rng, clean=True)],
        "tile": lambda: [tex_tile_rubber(S, rng)],
        "awnings": lambda: tex_awnings(S, rng),
        "cloth": lambda: tex_cloth(C, rng),
        "grille": lambda: [tex_grille(C, rng)],
        "decals": lambda: tex_decals(C, rng),
    }
    for g in groups:
        if g in jobs:
            for t in jobs[g]():
                t.write(out, manifest)
    if "shared" in groups:
        tex_grime_noise(out, rng, manifest)
        tex_sky_cover(out, rng, manifest)
    face_previews = []
    if "faces" in groups:
        face_previews = tex_faces(out, rng, manifest, preview)
    mpath.write_text(json.dumps(manifest, indent=1))
    if preview:
        names = [(v["folder"], k) for k, v in manifest["sets"].items()]
        contact_sheet(out, names, preview / "textures_sheet.jpg")
        if face_previews:
            tile = 240
            sheet = Image.new("RGB", (len(face_previews) // 2 * (tile * 3 + 12) + 12, 2 * (tile + 12) + 12), (22, 23, 24))
            for k, views in enumerate(face_previews):
                x = 12 + (k % (len(face_previews) // 2)) * (tile * 3 + 12)
                y = 12 + (k // (len(face_previews) // 2)) * (tile + 12)
                for j, v in enumerate(views):
                    sheet.paste(Image.fromarray(_u8(v)), (x + j * tile, y))
            sheet.save(preview / "faces_turnaround.jpg", quality=92)
        print("Previews in", preview)
    print(f"Done in {time.time() - t0:.0f} s")


if __name__ == "__main__":
    sys.exit(main())
