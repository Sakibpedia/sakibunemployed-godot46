#!/usr/bin/env python3
"""Writes the game's SVG interface kit to art/ui/ (raw .svg files that Godot imports as textures).

Look: "Jatrabari dusk glass". Dark, semi-transparent glass plates with chamfered corners (from
rickshaw-art panel shapes), marigold and rickshaw-pink accents, alpana petals (the rice-paste floor
art), nakshi kantha running stitches, and the matra: the horizontal headline that every Bengali word
hangs from, used as the top rule of panels meant to carry Bengali text.

Godot's SVG importer (ThorVG) handles everything used here: paths, gradients, opacity and dashes.
There are deliberately no filters, <pattern>, <use> or CSS, so what you see in a browser is what
Godot rasterises. Text is never baked in: the game draws all words (Bangla and English) on top.

Files and suggested Godot use (StyleBoxTexture margins are left, top, right, bottom in px):
  exam_panel_bg.svg           1600x900  StyleBoxTexture, margins 64, 150, 64, 90
  exam_option_*.svg           1200x96   normal / hover / pressed-correct / wrong / struck; margins 110, 24, 40, 24
  exam_timer_ring.svg         160x160   TextureProgressBar under; exam_timer_fill.svg as progress (radial fill)
  bengali_text_backdrop.svg   1200x200  margins 40, 60, 40, 30
  bengali_title_plate.svg     900x160   title cartouche
  hud_bar_frame / track / fill_*.svg 360x28  TextureProgressBar over / under / progress
  hud_health_plate.svg, hud_ammo_plate.svg, ammo_round_full / empty.svg
  marker_objective.svg, marker_distance_plate.svg, marker_enemy.svg, marker_gatekeeper.svg
  dialogue_box_bg.svg, portrait_frame.svg, toast_plate.svg, objective_plate.svg, clock_plate.svg,
  prompt_key.svg, crosshair.svg, notebook_frame.svg, icon_*.svg
Run: python3 tools/generate_ui_svgs.py [--preview]   (preview needs rsvg-convert)
Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.
"""
import math
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "ui"

INK = "#0B1417"
GLASS_TOP = "#18303A"
GLASS_BOT = "#0B171B"
MARIGOLD = "#F2A93B"
PINK = "#E5487F"
RED = "#E5483C"
GREEN = "#3FBF7F"
TEAL = "#2EC4B6"
PAPER = "#F3EAD7"
WHITE = "#FFFFFF"


def svg(w, h, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
            f'<defs>\n{defs}</defs>\n{body}</svg>\n')


def lin(id_, stops, x1=0, y1=0, x2=0, y2=1):
    s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
    return f'<linearGradient id="{id_}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>\n'


def rad(id_, stops, cx=0.5, cy=0.5, r=0.5):
    s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
    return f'<radialGradient id="{id_}" cx="{cx}" cy="{cy}" r="{r}">{s}</radialGradient>\n'


def chamfer(x, y, w, h, c1, c2=None):
    """Plate with the top-left and bottom-right corners cut (rickshaw panel shape)."""
    c2 = c1 if c2 is None else c2
    return (f"M{x + c1},{y} L{x + w},{y} L{x + w},{y + h - c2} L{x + w - c2},{y + h} "
            f"L{x},{y + h} L{x},{y + c1} Z")


def glass(x, y, w, h, c, gid="glass", stroke=MARIGOLD, stroke_op=0.55, fill_op=0.78):
    p = chamfer(x, y, w, h, c)
    inner = chamfer(x + 3, y + 3, w - 6, h - 6, max(c - 2, 0))
    return (f'<path d="{p}" fill="url(#{gid})" fill-opacity="{fill_op}"/>\n'
            f'<path d="{inner}" fill="none" stroke="{WHITE}" stroke-opacity="0.10" stroke-width="1.5"/>\n'
            f'<path d="{p}" fill="none" stroke="{stroke}" stroke-opacity="{stroke_op}" stroke-width="2"/>\n')


def glass_defs(gid="glass"):
    return lin(gid, [(0, GLASS_TOP, 1), (1, GLASS_BOT, 1)])


def stitches(x1, y1, x2, y2, colour=MARIGOLD, op=0.6, w=2, dash="10 7"):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{colour}" stroke-opacity="{op}" stroke-width="{w}" stroke-dasharray="{dash}" stroke-linecap="round"/>\n'


def petal_flower(cx, cy, r, colour=MARIGOLD, centre=PINK, op=0.9, petals=8):
    out = ""
    for k in range(petals):
        a = 360.0 * k / petals
        out += (f'<ellipse cx="{cx}" cy="{cy - r * 0.62:.2f}" rx="{r * 0.26:.2f}" ry="{r * 0.5:.2f}" fill="{colour}" '
                f'fill-opacity="{op}" transform="rotate({a:.1f} {cx} {cy})"/>\n')
    out += f'<circle cx="{cx}" cy="{cy}" r="{r * 0.28:.2f}" fill="{centre}" fill-opacity="{op}"/>\n'
    out += f'<circle cx="{cx}" cy="{cy}" r="{r * 0.1:.2f}" fill="{PAPER}" fill-opacity="{op}"/>\n'
    return out


def alpana_band(x, y, w, h, colour=MARIGOLD, op=0.55):
    """A running alpana border: flowers joined by a vine of dots and leaf pairs."""
    n = max(3, int(w // (h * 1.6)))
    step = w / n
    out = f'<line x1="{x}" y1="{y + h / 2}" x2="{x + w}" y2="{y + h / 2}" stroke="{colour}" stroke-opacity="{op * 0.6}" stroke-width="1.5"/>\n'
    for k in range(n):
        cx = x + step * (k + 0.5)
        out += petal_flower(round(cx, 1), y + h / 2, h * 0.42, colour, PINK, op)
        for side in (-1, 1):
            lx = cx + side * step * 0.32
            out += (f'<ellipse cx="{lx:.1f}" cy="{y + h / 2 - h * 0.12:.1f}" rx="{h * 0.16:.1f}" ry="{h * 0.07:.1f}" fill="{colour}" '
                    f'fill-opacity="{op * 0.8}" transform="rotate({-25 * side} {lx:.1f} {y + h / 2})"/>\n')
            out += (f'<ellipse cx="{lx:.1f}" cy="{y + h / 2 + h * 0.12:.1f}" rx="{h * 0.16:.1f}" ry="{h * 0.07:.1f}" fill="{colour}" '
                    f'fill-opacity="{op * 0.8}" transform="rotate({25 * side} {lx:.1f} {y + h / 2})"/>\n')
            out += f'<circle cx="{cx + side * step * 0.48:.1f}" cy="{y + h / 2}" r="{h * 0.06:.1f}" fill="{colour}" fill-opacity="{op}"/>\n'
    return out


def matra(x, y, w, thick=5, colour=MARIGOLD, op=0.9, drops=True):
    """The Bengali headline stroke, with small hanging drops like the stems of letters."""
    out = f'<rect x="{x}" y="{y}" width="{w}" height="{thick}" rx="{thick / 2}" fill="{colour}" fill-opacity="{op}"/>\n'
    if drops:
        n = int(w // 46)
        for k in range(1, n):
            dx = x + k * w / n
            hgt = 10 + (k * 7) % 12
            out += f'<path d="M{dx - 3:.1f},{y + thick} L{dx + 3:.1f},{y + thick} L{dx:.1f},{y + thick + hgt}Z" fill="{colour}" fill-opacity="{op * 0.6}"/>\n'
    return out


def corner_ornament(x, y, s, flip_x=1, flip_y=1, colour=MARIGOLD, op=0.8):
    t = f'translate({x} {y}) scale({flip_x} {flip_y})'
    return (f'<g transform="{t}">'
            f'<path d="M0,0 L{s},0 L{s * 0.82},{s * 0.12} L{s * 0.12},{s * 0.12} L{s * 0.12},{s * 0.82} L0,{s}Z" fill="{colour}" fill-opacity="{op}"/>'
            f'<circle cx="{s * 0.3}" cy="{s * 0.3}" r="{s * 0.09}" fill="{PINK}" fill-opacity="{op}"/>'
            f'<circle cx="{s * 0.55}" cy="{s * 0.24}" r="{s * 0.04}" fill="{colour}" fill-opacity="{op}"/>'
            f'<circle cx="{s * 0.24}" cy="{s * 0.55}" r="{s * 0.04}" fill="{colour}" fill-opacity="{op}"/>'
            f'</g>\n')


def question_mark(cx, cy, s, colour):
    return (f'<path d="M{cx - s * 0.32},{cy - s * 0.28} C{cx - s * 0.32},{cy - s * 0.62} {cx + s * 0.34},{cy - s * 0.66} {cx + s * 0.34},{cy - s * 0.26} '
            f'C{cx + s * 0.34},{cy - s * 0.02} {cx},{cy + s * 0.02} {cx},{cy + s * 0.22}" fill="none" stroke="{colour}" '
            f'stroke-width="{s * 0.16}" stroke-linecap="round"/>\n'
            f'<circle cx="{cx}" cy="{cy + s * 0.48}" r="{s * 0.1}" fill="{colour}"/>\n')


def check(cx, cy, s, colour):
    return (f'<path d="M{cx - s * 0.45},{cy} L{cx - s * 0.12},{cy + s * 0.32} L{cx + s * 0.48},{cy - s * 0.34}" fill="none" '
            f'stroke="{colour}" stroke-width="{s * 0.16}" stroke-linecap="round" stroke-linejoin="round"/>\n')


def cross(cx, cy, s, colour):
    return (f'<path d="M{cx - s * 0.36},{cy - s * 0.36} L{cx + s * 0.36},{cy + s * 0.36} M{cx + s * 0.36},{cy - s * 0.36} '
            f'L{cx - s * 0.36},{cy + s * 0.36}" stroke="{colour}" stroke-width="{s * 0.16}" stroke-linecap="round"/>\n')


# --- Icons --------------------------------------------------------------------------------

def icon_files():
    files = {}
    files["icon_health.svg"] = svg(64, 64, f'<circle cx="32" cy="32" r="28" fill="{INK}" fill-opacity="0.6" stroke="{GREEN}" stroke-width="3"/>\n'
                                          f'<path d="M26,14 H38 V26 H50 V38 H38 V50 H26 V38 H14 V26 H26 Z" fill="{GREEN}"/>\n')
    files["icon_ammo.svg"] = svg(64, 64, "".join(
        f'<path d="M{14 + k * 13},52 V26 C{14 + k * 13},18 {19 + k * 13},12 {20.5 + k * 13},12 C{22 + k * 13},12 {27 + k * 13},18 {27 + k * 13},26 V52 Z" '
        f'fill="{MARIGOLD}" stroke="{INK}" stroke-width="1.5"/>\n<rect x="{14 + k * 13}" y="44" width="13" height="8" fill="#B07A2A"/>\n' for k in range(3)))
    files["icon_alert_eye.svg"] = svg(64, 64, f'<path d="M4,32 C16,12 48,12 60,32 C48,52 16,52 4,32 Z" fill="{INK}" fill-opacity="0.6" stroke="{WHITE}" stroke-width="3"/>\n'
                                             f'<circle cx="32" cy="32" r="11" fill="{WHITE}"/>\n<circle cx="32" cy="32" r="5" fill="{INK}"/>\n')
    files["icon_token.svg"] = svg(64, 64, f'<path d="M32,16 C24,10 12,10 6,13 V52 C12,49 24,49 32,55 C40,49 52,49 58,52 V13 C52,10 40,10 32,16 Z" fill="{PAPER}" stroke="{MARIGOLD}" stroke-width="3"/>\n'
                                         f'<line x1="32" y1="16" x2="32" y2="55" stroke="{MARIGOLD}" stroke-width="3"/>\n'
                                         + "".join(f'<line x1="12" y1="{22 + k * 7}" x2="26" y2="{21 + k * 7}" stroke="#7A6A50" stroke-width="2"/>\n'
                                                   f'<line x1="38" y1="{21 + k * 7}" x2="52" y2="{22 + k * 7}" stroke="#7A6A50" stroke-width="2"/>\n' for k in range(4)))
    files["icon_battery.svg"] = svg(64, 64, f'<rect x="8" y="18" width="42" height="28" rx="5" fill="{INK}" fill-opacity="0.6" stroke="{TEAL}" stroke-width="3"/>\n'
                                           f'<rect x="51" y="26" width="6" height="12" rx="2" fill="{TEAL}"/>\n'
                                           + "".join(f'<rect x="{13 + k * 11}" y="23" width="8" height="18" rx="2" fill="{TEAL}"/>\n' for k in range(3)))
    files["icon_cash.svg"] = svg(64, 64, f'<rect x="6" y="16" width="52" height="32" rx="4" fill="#4C8A57" stroke="{PAPER}" stroke-width="2.5"/>\n'
                                        f'<circle cx="32" cy="32" r="9" fill="none" stroke="{PAPER}" stroke-width="2.5"/>\n'
                                        f'<circle cx="13" cy="23" r="3" fill="{PAPER}"/><circle cx="51" cy="41" r="3" fill="{PAPER}"/>\n')
    return files


# --- HUD -----------------------------------------------------------------------------------

def hud_files():
    f = {}
    w, h = 360, 28
    f["hud_bar_track.svg"] = svg(w, h, f'<path d="{chamfer(0, 0, w, h, 8)}" fill="{INK}" fill-opacity="0.65"/>\n'
                                       + "".join(f'<rect x="{6 + k * 34.8:.1f}" y="6" width="31" height="16" fill="{WHITE}" fill-opacity="0.06"/>\n' for k in range(10)))
    for name, a, b in (("health", GREEN, "#9BE07A"), ("alert", MARIGOLD, RED), ("timer", TEAL, MARIGOLD)):
        defs = lin("g", [(0, a, 1), (1, b, 1)], 0, 0, 1, 0) + lin("shine", [(0, WHITE, 0.35), (0.5, WHITE, 0.0)])
        body = "".join(f'<rect x="{6 + k * 34.8:.1f}" y="6" width="31" height="16" fill="url(#g)"/>\n' for k in range(10))
        body += f'<rect x="6" y="6" width="{w - 12}" height="8" fill="url(#shine)"/>\n'
        f[f"hud_bar_fill_{name}.svg"] = svg(w, h, body, defs)
    f["hud_bar_frame.svg"] = svg(w, h, f'<path d="{chamfer(1, 1, w - 2, h - 2, 8)}" fill="none" stroke="{MARIGOLD}" stroke-opacity="0.8" stroke-width="2"/>\n'
                                       f'<path d="M{w - 30},{h - 1} L{w - 9},{h - 1}" stroke="{PINK}" stroke-width="3"/>\n')
    defs = glass_defs()
    f["hud_health_plate.svg"] = svg(460, 80, glass(0, 0, 460, 80, 18, stroke_op=0.45, fill_op=0.7)
                                    + f'<circle cx="44" cy="40" r="26" fill="{INK}" fill-opacity="0.6" stroke="{GREEN}" stroke-width="3"/>\n'
                                    + f'<path d="M39,24 H49 V35 H60 V45 H49 V56 H39 V45 H28 V35 H39 Z" fill="{GREEN}"/>\n'
                                    + stitches(84, 70, 440, 70, MARIGOLD, 0.4, 1.5, "6 6"), defs)
    rounds = "".join(f'<path d="M{102 + k * 22},62 V30 C{102 + k * 22},22 {108 + k * 22},16 {110 + k * 22},16 C{112 + k * 22},16 {118 + k * 22},22 {118 + k * 22},30 V62 Z" '
                     f'fill="{MARIGOLD}" fill-opacity="0.9"/>\n<rect x="{102 + k * 22}" y="54" width="16" height="8" fill="#9A6A22"/>\n' for k in range(12))
    f["hud_ammo_plate.svg"] = svg(380, 80, glass(0, 0, 380, 80, 18, stroke_op=0.45, fill_op=0.7) + rounds
                                  + f'<path d="M24,22 h52 v36 h-52 z" fill="{INK}" fill-opacity="0.7" stroke="{MARIGOLD}" stroke-width="2"/>\n'
                                  + f'<path d="M32,30 h36 M32,40 h36 M32,50 h24" stroke="{MARIGOLD}" stroke-opacity="0.7" stroke-width="3"/>\n', defs)
    f["ammo_round_full.svg"] = svg(18, 48, f'<path d="M1,46 V14 C1,6 7,1 9,1 C11,1 17,6 17,14 V46 Z" fill="{MARIGOLD}"/>\n<rect x="1" y="38" width="16" height="8" fill="#9A6A22"/>\n')
    f["ammo_round_empty.svg"] = svg(18, 48, f'<path d="M1,46 V14 C1,6 7,1 9,1 C11,1 17,6 17,14 V46 Z" fill="none" stroke="{WHITE}" stroke-opacity="0.35" stroke-width="2"/>\n')

    # objective marker: a diamond in rings, with a pointer underneath
    md = rad("halo", [(0, MARIGOLD, 0.45), (1, MARIGOLD, 0.0)])
    f["marker_objective.svg"] = svg(96, 120, f'<circle cx="48" cy="44" r="44" fill="url(#halo)"/>\n'
                                    f'<circle cx="48" cy="44" r="30" fill="none" stroke="{MARIGOLD}" stroke-opacity="0.5" stroke-width="2" stroke-dasharray="6 5"/>\n'
                                    f'<path d="M48,18 L74,44 L48,70 L22,44 Z" fill="{INK}" fill-opacity="0.75" stroke="{MARIGOLD}" stroke-width="4"/>\n'
                                    f'<path d="M48,32 L60,44 L48,56 L36,44 Z" fill="{MARIGOLD}"/>\n'
                                    f'<path d="M36,92 L48,110 L60,92" fill="none" stroke="{MARIGOLD}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>\n', md)
    f["marker_distance_plate.svg"] = svg(132, 40, glass(0, 0, 132, 40, 10, stroke_op=0.6, fill_op=0.75), glass_defs())
    er = rad("pulse", [(0.55, RED, 0.0), (0.75, RED, 0.45), (1, RED, 0.0)])
    f["marker_enemy.svg"] = svg(64, 64, f'<circle cx="32" cy="32" r="30" fill="url(#pulse)"/>\n'
                                f'<path d="M14,18 L50,18 L32,48 Z" fill="{RED}" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>\n'
                                f'<rect x="30" y="23" width="4" height="13" rx="2" fill="{INK}"/><circle cx="32" cy="41" r="2.4" fill="{INK}"/>\n', er)
    f["marker_gatekeeper.svg"] = svg(72, 88, f'<path d="M8,6 H64 a6,6 0 0 1 6,6 V54 a6,6 0 0 1 -6,6 H44 L36,80 L28,60 H8 a6,6 0 0 1 -6,-6 V12 a6,6 0 0 1 6,-6 Z" '
                                     f'fill="{INK}" fill-opacity="0.8" stroke="{MARIGOLD}" stroke-width="3"/>\n' + question_mark(36, 30, 40, MARIGOLD))
    f["crosshair.svg"] = svg(64, 64, "".join(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="1.5" fill="{WHITE}" fill-opacity="0.85" stroke="{INK}" stroke-opacity="0.5" stroke-width="1"/>\n'
                                             for x, y, w, h in ((30, 8, 4, 16), (30, 40, 4, 16), (8, 30, 16, 4), (40, 30, 16, 4)))
                             + f'<circle cx="32" cy="32" r="2.2" fill="{MARIGOLD}"/>\n')
    f["prompt_key.svg"] = svg(64, 64, f'<rect x="4" y="8" width="56" height="52" rx="10" fill="#5A4E3A"/>\n'
                              f'<rect x="4" y="2" width="56" height="52" rx="10" fill="url(#key)" stroke="{INK}" stroke-width="2"/>\n',
                              lin("key", [(0, "#F7F1E4", 1), (1, "#CDBF9F", 1)]))
    f["toast_plate.svg"] = svg(460, 72, glass(0, 0, 460, 72, 14, stroke_op=0.4, fill_op=0.72)
                               + f'<rect x="0" y="14" width="5" height="44" fill="{MARIGOLD}"/>\n', glass_defs())
    f["objective_plate.svg"] = svg(680, 64, glass(0, 0, 680, 64, 16, stroke_op=0.5, fill_op=0.7)
                                   + f'<path d="M22,32 L32,22 L42,32 L32,42 Z" fill="{MARIGOLD}"/>\n' + stitches(56, 54, 660, 54, MARIGOLD, 0.35, 1.5, "5 6"), glass_defs())
    f["clock_plate.svg"] = svg(200, 72, glass(0, 0, 200, 72, 16, stroke_op=0.5, fill_op=0.72)
                               + f'<circle cx="36" cy="36" r="18" fill="none" stroke="{MARIGOLD}" stroke-width="3"/>\n'
                               + f'<path d="M36,24 V36 L45,41" stroke="{MARIGOLD}" stroke-width="3" fill="none" stroke-linecap="round"/>\n', glass_defs())
    return f


# --- Exam panel ------------------------------------------------------------------------------

def exam_files():
    f = {}
    W, H = 1600, 900
    defs = glass_defs() + lin("head", [(0, "#22404A", 1), (1, "#12252B", 1)]) + lin("sheen", [(0, WHITE, 0.08), (0.4, WHITE, 0.0)])
    body = glass(0, 0, W, H, 48, stroke_op=0.6, fill_op=0.86)
    body += f'<path d="{chamfer(0, 0, W, 140, 48, 0)}" fill="url(#head)" fill-opacity="0.95"/>\n'
    body += f'<rect x="0" y="0" width="{W}" height="{H * 0.45}" fill="url(#sheen)"/>\n'
    body += alpana_band(150, 18, W - 300, 44, MARIGOLD, 0.6)
    body += matra(64, 118, W - 128, 6, MARIGOLD, 0.95, drops=True)
    body += f'<circle cx="{W - 110}" cy="76" r="54" fill="{INK}" fill-opacity="0.75" stroke="{MARIGOLD}" stroke-opacity="0.7" stroke-width="3"/>\n'
    body += "".join(f'<line x1="{W - 110 + 46 * math.sin(a):.1f}" y1="{76 - 46 * math.cos(a):.1f}" x2="{W - 110 + 52 * math.sin(a):.1f}" '
                    f'y2="{76 - 52 * math.cos(a):.1f}" stroke="{PAPER}" stroke-opacity="0.6" stroke-width="2"/>\n' for a in [k * math.pi / 6 for k in range(12)])
    body += corner_ornament(14, 160, 46, 1, 1)
    body += corner_ornament(W - 14, H - 14, 46, -1, -1)
    body += corner_ornament(W - 14, 160, 46, -1, 1, op=0.5)
    body += corner_ornament(14, H - 14, 46, 1, -1, op=0.5)
    body += stitches(70, H - 56, W - 70, H - 56, MARIGOLD, 0.45)
    body += stitches(70, H - 46, W - 70, H - 46, PINK, 0.35, 1.5, "4 9")
    body += f'<path d="{chamfer(64, H - 104, 520, 34, 8)}" fill="{PAPER}" fill-opacity="0.12" stroke="{PAPER}" stroke-opacity="0.35" stroke-width="1.5"/>\n'
    body += f'<rect x="64" y="170" width="{W - 128}" height="200" rx="6" fill="{WHITE}" fill-opacity="0.035"/>\n'
    f["exam_panel_bg.svg"] = svg(W, H, body, defs)

    w, h = 1200, 96
    states = {
        "normal": (GLASS_TOP, MARIGOLD, 0.45, MARIGOLD, ""),
        "hover": ("#24505C", MARIGOLD, 0.95, MARIGOLD, ""),
        "correct": ("#1E5A3E", GREEN, 1.0, GREEN, "check"),
        "wrong": ("#5E2228", RED, 1.0, RED, "cross"),
        "struck": ("#1A2326", "#7D8A8C", 0.35, "#7D8A8C", "strike"),
    }
    for name, (fill, stroke, sop, badge, mark) in states.items():
        d = lin("opt", [(0, fill, 0.92), (1, GLASS_BOT, 0.85)], 0, 0, 1, 0)
        b = f'<path d="{chamfer(0, 0, w, h, 22)}" fill="url(#opt)"/>\n'
        b += f'<path d="{chamfer(1.5, 1.5, w - 3, h - 3, 21)}" fill="none" stroke="{stroke}" stroke-opacity="{sop}" stroke-width="3"/>\n'
        b += f'<circle cx="56" cy="{h / 2}" r="30" fill="{INK}" fill-opacity="0.75" stroke="{badge}" stroke-width="3"/>\n'
        b += matra(34, h / 2 - 15, 44, 3, badge, 0.9, drops=False)
        b += stitches(100, h - 12, w - 40, h - 12, stroke, 0.25 if name != "struck" else 0.1, 1.5, "5 7")
        if mark == "check":
            b += check(w - 60, h / 2, 40, GREEN)
        elif mark == "cross":
            b += cross(w - 60, h / 2, 40, RED)
        elif mark == "strike":
            b += f'<line x1="110" y1="{h / 2}" x2="{w - 40}" y2="{h / 2}" stroke="#9AA6A8" stroke-opacity="0.6" stroke-width="3"/>\n'
        f[f"exam_option_{name}.svg"] = svg(w, h, b, d)

    ring = f'<circle cx="80" cy="80" r="70" fill="{INK}" fill-opacity="0.7"/>\n<circle cx="80" cy="80" r="58" fill="none" stroke="{WHITE}" stroke-opacity="0.12" stroke-width="12"/>\n'
    ring += "".join(f'<line x1="{80 + 66 * math.sin(a):.1f}" y1="{80 - 66 * math.cos(a):.1f}" x2="{80 + (72 if k % 5 == 0 else 69) * math.sin(a):.1f}" '
                    f'y2="{80 - (72 if k % 5 == 0 else 69) * math.cos(a):.1f}" stroke="{PAPER}" stroke-opacity="{0.8 if k % 5 == 0 else 0.4}" stroke-width="2"/>\n'
                    for k, a in [(k, k * math.pi / 30) for k in range(60)])
    f["exam_timer_ring.svg"] = svg(160, 160, ring)
    fd = lin("tf", [(0, TEAL, 1), (0.6, MARIGOLD, 1), (1, RED, 1)], 0, 0, 1, 1)
    f["exam_timer_fill.svg"] = svg(160, 160, f'<circle cx="80" cy="80" r="58" fill="none" stroke="url(#tf)" stroke-width="12"/>\n', fd)
    return f


# --- Bengali typography backdrops, dialogue, notebook ---------------------------------------

def text_files():
    f = {}
    W, H = 1200, 200
    defs = lin("paper", [(0, "#1B2A2E", 0.88), (1, "#0E181B", 0.8)]) + lin("fadeL", [(0, MARIGOLD, 0.0), (0.15, MARIGOLD, 0.9), (0.85, MARIGOLD, 0.9), (1, MARIGOLD, 0.0)], 0, 0, 1, 0)
    b = f'<path d="{chamfer(0, 0, W, H, 28)}" fill="url(#paper)"/>\n'
    b += f'<rect x="40" y="44" width="{W - 80}" height="6" rx="3" fill="url(#fadeL)"/>\n'
    for k in range(1, 24):
        x = 40 + k * (W - 80) / 24
        b += f'<path d="M{x - 3:.1f},50 L{x + 3:.1f},50 L{x:.1f},{58 + (k * 5) % 10}Z" fill="{MARIGOLD}" fill-opacity="0.45"/>\n'
    b += "".join(f'<line x1="40" y1="{y}" x2="{W - 40}" y2="{y}" stroke="{WHITE}" stroke-opacity="0.05" stroke-width="1.5"/>\n' for y in (110, 160))
    b += stitches(20, 12, W - 40, 12, MARIGOLD, 0.45, 2, "9 7") + stitches(40, H - 12, W - 20, H - 12, PINK, 0.35, 2, "9 7")
    b += petal_flower(22, H / 2, 16, MARIGOLD, PINK, 0.7) + petal_flower(W - 22, H / 2, 16, MARIGOLD, PINK, 0.7)
    f["bengali_text_backdrop.svg"] = svg(W, H, b, defs)

    W, H = 900, 160
    defs = lin("plate", [(0, "#7A1E3A", 0.95), (1, "#3D0F1E", 0.95)]) + lin("rim", [(0, MARIGOLD, 1), (1, "#C9781F", 1)])
    scallop = "".join(f'<circle cx="{40 + k * 41.0:.1f}" cy="12" r="11" fill="url(#rim)"/>\n<circle cx="{40 + k * 41.0:.1f}" cy="{H - 12}" r="11" fill="url(#rim)"/>\n' for k in range(21))
    b = scallop
    b += f'<path d="M60,12 H{W - 60} C{W - 20},12 {W - 6},40 {W - 6},80 C{W - 6},120 {W - 20},{H - 12} {W - 60},{H - 12} H60 C20,{H - 12} 6,120 6,80 C6,40 20,12 60,12 Z" fill="url(#plate)" stroke="url(#rim)" stroke-width="6"/>\n'
    b += matra(110, 50, W - 220, 6, MARIGOLD, 0.95, drops=True)
    b += petal_flower(70, 80, 34, MARIGOLD, TEAL, 0.95, 10) + petal_flower(W - 70, 80, 34, MARIGOLD, TEAL, 0.95, 10)
    b += stitches(120, H - 34, W - 120, H - 34, PAPER, 0.5, 2, "8 6")
    f["bengali_title_plate.svg"] = svg(W, H, b, defs)

    W, H = 1100, 280
    defs = glass_defs()
    b = glass(0, 0, W, H, 32, stroke_op=0.5, fill_op=0.82)
    b += matra(250, 58, W - 300, 5, MARIGOLD, 0.9, drops=True)
    b += f'<path d="{chamfer(250, 18, 330, 30, 8)}" fill="{MARIGOLD}" fill-opacity="0.18" stroke="{MARIGOLD}" stroke-opacity="0.6" stroke-width="1.5"/>\n'
    b += stitches(250, H - 22, W - 40, H - 22, MARIGOLD, 0.35, 1.5, "6 7")
    b += f'<path d="M{W - 70},{H - 60} l14,14 l14,-14" fill="none" stroke="{MARIGOLD}" stroke-width="4" stroke-linecap="round"/>\n'
    f["dialogue_box_bg.svg"] = svg(W, H, b, defs)

    S = 220
    defs = lin("pf", [(0, MARIGOLD, 1), (1, PINK, 1)], 0, 0, 1, 1)
    b = f'<path d="{chamfer(4, 4, S - 8, S - 8, 30)}" fill="{INK}" fill-opacity="0.6" stroke="url(#pf)" stroke-width="8"/>\n'
    b += corner_ornament(S - 8, S - 8, 40, -1, -1, MARIGOLD, 0.9)
    b += "".join(f'<circle cx="{18 + k * 18}" cy="10" r="2.5" fill="{PAPER}" fill-opacity="0.6"/>\n' for k in range(5))
    f["portrait_frame.svg"] = svg(S, S, b, defs)

    W, H = 560, 380
    defs = lin("pg", [(0, "#F4ECDA", 1), (1, "#E5D8BC", 1)])
    b = f'<rect x="20" y="10" width="{W - 30}" height="{H - 20}" rx="10" fill="#3B2C22"/>\n'
    b += f'<rect x="34" y="18" width="{W - 52}" height="{H - 36}" rx="6" fill="url(#pg)"/>\n'
    b += "".join(f'<line x1="70" y1="{y}" x2="{W - 30}" y2="{y}" stroke="#8FB3C8" stroke-opacity="0.7" stroke-width="1.5"/>\n' for y in range(70, H - 20, 28))
    b += f'<line x1="100" y1="22" x2="100" y2="{H - 22}" stroke="{RED}" stroke-opacity="0.6" stroke-width="2"/>\n'
    b += "".join(f'<ellipse cx="34" cy="{40 + k * 30}" rx="16" ry="7" fill="none" stroke="#8A8F94" stroke-width="4"/>\n' for k in range(11))
    b += f'<path d="M{W - 70},18 v60 l12,-10 l12,10 v-60 z" fill="{PINK}" fill-opacity="0.85"/>\n'
    f["notebook_frame.svg"] = svg(W, H, b, defs)
    return f


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    files = {}
    for group in (icon_files, hud_files, exam_files, text_files):
        files.update(group())
    for name, text in files.items():
        (OUT / name).write_text(text, encoding="utf-8")
    print(f"Wrote {len(files)} SVG files to {OUT}")
    if "--preview" in sys.argv and shutil.which("rsvg-convert"):
        prev = OUT / "_preview"
        prev.mkdir(exist_ok=True)
        for name in files:
            subprocess.run(["rsvg-convert", str(OUT / name), "-o", str(prev / name.replace(".svg", ".png"))], check=True)
        print("PNG previews in", prev)


if __name__ == "__main__":
    main()
