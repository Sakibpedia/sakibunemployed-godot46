#!/usr/bin/env python3
"""Open-world layout for "S M Nazmuz Sakib is unemployed": Jatrabari, Kajla, Sontek, Dania, Jurain.

Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

Writes Data/World/city.json (read by scripts/world/CityData.gd and ProceduralDhaka.gd) and a map
preview docs/img/city_map.png.

The layout follows the reference photo inventory (Data/Reference/photo_inventory.json):
  * N1 (Dhaka-Chattogram highway) runs north-west to south-east; Sontek lies north of it, Dania south.
  * The Mayor Hanif flyover comes in over Jatrabari and lands with ramps at Kajla.
  * N8 runs south from Jatrabari through Jurain; the Dhaka-Demra road (R110) runs north-east.
  * Sontek's lane grid: Sontek Main Rd, School Rd, Rd Number 2, Sontek Mohammadi Rd 2, Road No. 3,
    Mosjid Rd 1-2, Masjid Rd, Isha Kha Rd, Road No. 7, Titumir Rd; a pond north of Mosjid Rd 1.
  * The anchor 9-storey building (the Tower): roof about 32 x 35 m with two light wells, School Rd on
    its west edge and Sontek Main Rd to the north-east.
  * Dania College and Adarsha High School south of N1.
  * Neighbours 6-10 storeys, 1.5-3 m gaps between buildings, lanes about 6 m wide with 2-3 storey
    shops, balconies 1.2 m deep, round roof tanks about 2.5 m, roof rooms, laundry, pierced parapets.
World axes: x east, z south, metres from the north-west corner (Godot: -Z is north).

Usage:  python3 tools/make_city.py [--seed N] [--no-preview]
"""
import argparse
import json
import math
import random
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Data" / "World" / "city.json"
PREVIEW = ROOT / "docs" / "img" / "city_map.png"
W, H = 1400.0, 1100.0
CELL = 2.0

JATRABARI = (260.0, 260.0)
N1_END = (1400.0, 1000.0)
N8_END = (170.0, 1100.0)
R110_END = (1400.0, 60.0)
GULISTAN = (0.0, 110.0)
RAIL = [(0.0, 640.0), (600.0, 1100.0)]


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def mul(a, s):
    return (a[0] * s, a[1] * s)


def norm(a):
    l = math.hypot(a[0], a[1]) or 1.0
    return (a[0] / l, a[1] / l)


def lerp2(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def seg_dist(p, a, b):
    ab = sub(b, a)
    ap = sub(p, a)
    l2 = ab[0] ** 2 + ab[1] ** 2
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, (ap[0] * ab[0] + ap[1] * ab[1]) / l2))
    q = add(a, mul(ab, t))
    return math.hypot(p[0] - q[0], p[1] - q[1]), t


def side_of(p, a, b):
    """>0 left of a->b (in x-right, z-down image space this is 'north-east' of N1), <0 right."""
    return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])


def line_z_at_x(a, b, x):
    if b[0] == a[0]:
        return a[1]
    return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])


def line_x_at_z(a, b, z):
    if b[1] == a[1]:
        return a[0]
    return a[0] + (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1])


def district_at(p):
    x, z = p
    if math.hypot(x - JATRABARI[0], z - JATRABARI[1]) < 185 or (x < 470 and z < 400):
        return "jatrabari"
    n1z = line_z_at_x(JATRABARI, N1_END, x) if x >= JATRABARI[0] else -1e9
    north_of_n1 = z < n1z
    d_n1, t_n1 = seg_dist(p, JATRABARI, N1_END)
    if d_n1 < 75 and 0.22 < t_n1 < 0.5:
        return "kajla"
    if x >= JATRABARI[0] and north_of_n1:
        return "sontek"
    n8x = line_x_at_z(JATRABARI, N8_END, z) if z >= JATRABARI[1] else -1e9
    if x < n8x + 260 or x < 470:
        return "jurain"
    return "dania"


DISTRICTS = [
    {"id": "jatrabari", "name": {"bn": "যাত্রাবাড়ী", "en": "Jatrabari"}, "style": "commercial", "power_group": 0},
    {"id": "kajla", "name": {"bn": "কাজলা", "en": "Kajla"}, "style": "commercial", "power_group": 1},
    {"id": "sontek", "name": {"bn": "সোনটেক", "en": "Sontek"}, "style": "apartments", "power_group": 2},
    {"id": "dania", "name": {"bn": "দনিয়া", "en": "Dania"}, "style": "apartments", "power_group": 3},
    {"id": "jurain", "name": {"bn": "জুরাইন", "en": "Jurain"}, "style": "old", "power_group": 4},
]

PALETTE = {
    "apartments": [(0.92, 0.91, 0.87), (0.95, 0.9, 0.82), (0.93, 0.74, 0.72), (0.94, 0.66, 0.6), (0.72, 0.84, 0.9),
                   (0.78, 0.88, 0.78), (0.86, 0.86, 0.84), (0.96, 0.86, 0.66), (0.9, 0.8, 0.86)],
    "commercial": [(0.86, 0.86, 0.84), (0.78, 0.8, 0.82), (0.92, 0.9, 0.86), (0.7, 0.74, 0.78), (0.9, 0.84, 0.74)],
    "old": [(0.8, 0.76, 0.68), (0.74, 0.7, 0.64), (0.86, 0.8, 0.7), (0.7, 0.62, 0.56), (0.82, 0.84, 0.78), (0.78, 0.7, 0.62)],
}
ACCENTS = [(0.6, 0.12, 0.12), (0.72, 0.2, 0.18), (0.18, 0.32, 0.6), (0.2, 0.45, 0.62), (0.5, 0.16, 0.3), (0.35, 0.35, 0.38)]

SHOP_PREFIX = [("মায়ের দোয়া", "Mayer Doa"), ("বিসমিল্লাহ", "Bismillah"), ("নিউ জননী", "New Jononi"), ("ভাই ভাই", "Bhai Bhai"),
               ("সততা", "Sotota"), ("আল-মদিনা", "Al-Madina"), ("রহমানিয়া", "Rahmania"), ("জনতা", "Janata"),
               ("শাপলা", "Shapla"), ("ফাতেমা", "Fatema"), ("লাকি", "Lucky"), ("স্মার্ট", "Smart"), ("সোনালী", "Sonali"),
               ("আদর্শ", "Adarsha"), ("নূর", "Noor"), ("বাবার দোয়া", "Babar Doa"), ("মা", "Maa"), ("হাজী", "Haji"),
               ("দনিয়া", "Dania"), ("সোনটেক", "Sontek"), ("কাজলা", "Kajla"), ("জুরাইন", "Jurain")]
SHOP_KIND = {
    "grocery": ("স্টোর", "Store"), "phone": ("টেলিকম", "Telecom"), "pharmacy": ("ফার্মেসী", "Pharmacy"),
    "hotel": ("হোটেল অ্যান্ড রেস্টুরেন্ট", "Hotel & Restaurant"), "tailor": ("টেইলার্স", "Tailors"),
    "photocopy": ("ফটোকপি", "Photocopy"), "cyber": ("সাইবার ক্যাফে", "Cyber Cafe"), "sweets": ("সুইটস", "Sweets"),
    "hardware": ("হার্ডওয়্যার", "Hardware"), "books": ("লাইব্রেরি", "Library (books)"), "tea": ("টি স্টল", "Tea Stall"),
    "salon": ("সেলুন", "Salon"), "coaching": ("কোচিং সেন্টার", "Coaching Centre"),
}
SONTEK_ROADS = ["Sontek Main Rd", "School Rd", "Rd Number 2", "Sontek Mohammadi Rd 2", "Road No. 3", "Mosjid Rd 1",
                "Mosjid Rd 2", "Masjid Rd", "Isha Kha Rd", "Road No. 7", "Titumir Rd"]
SONTEK_ROADS_BN = ["সোনটেক মেইন রোড", "স্কুল রোড", "রোড নম্বর ২", "সোনটেক মোহাম্মদী রোড ২", "রোড নং ৩", "মসজিদ রোড ১",
                   "মসজিদ রোড ২", "মসজিদ রোড", "ঈসা খাঁ রোড", "রোড নং ৭", "তিতুমীর রোড"]


class Grid:
    def __init__(self):
        self.nx = int(W / CELL)
        self.nz = int(H / CELL)
        self.occ = np.zeros((self.nz, self.nx), dtype=np.uint8)   # 0 free, 1 road, 2 building, 3 reserved

    def mark_segment(self, a, b, half, val):
        x0 = max(0, int((min(a[0], b[0]) - half) / CELL))
        x1 = min(self.nx - 1, int((max(a[0], b[0]) + half) / CELL) + 1)
        z0 = max(0, int((min(a[1], b[1]) - half) / CELL))
        z1 = min(self.nz - 1, int((max(a[1], b[1]) + half) / CELL) + 1)
        if x1 < x0 or z1 < z0:
            return
        xs = (np.arange(x0, x1 + 1) + 0.5) * CELL
        zs = (np.arange(z0, z1 + 1) + 0.5) * CELL
        X, Z = np.meshgrid(xs, zs)
        ab = np.array(sub(b, a))
        l2 = float(ab @ ab) or 1.0
        t = np.clip(((X - a[0]) * ab[0] + (Z - a[1]) * ab[1]) / l2, 0, 1)
        d = np.hypot(X - (a[0] + ab[0] * t), Z - (a[1] + ab[1] * t))
        sl = self.occ[z0:z1 + 1, x0:x1 + 1]
        sl[(d <= half) & (sl == 0)] = val

    def rect_cells(self, cx, cz, w, d, rot):
        c, s = math.cos(rot), math.sin(rot)
        us = np.arange(-w / 2 + 0.5, w / 2, 1.0)
        vs = np.arange(-d / 2 + 0.5, d / 2, 1.0)
        U, V = np.meshgrid(us, vs)
        X = cx + U * c - V * s
        Z = cz + U * s + V * c
        ix = (X / CELL).astype(int)
        iz = (Z / CELL).astype(int)
        return ix, iz

    def rect_free(self, cx, cz, w, d, rot, margin=0.0):
        ix, iz = self.rect_cells(cx, cz, w + margin * 2, d + margin * 2, rot)
        if ix.min() < 0 or iz.min() < 0 or ix.max() >= self.nx or iz.max() >= self.nz:
            return False
        return not self.occ[iz, ix].any()

    def mark_rect(self, cx, cz, w, d, rot, val=2):
        ix, iz = self.rect_cells(cx, cz, w, d, rot)
        ok = (ix >= 0) & (iz >= 0) & (ix < self.nx) & (iz < self.nz)
        self.occ[iz[ok], ix[ok]] = val


class City:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.seed = seed
        self.grid = Grid()
        self.roads = []
        self.buildings = []
        self.lamps = []
        self.poles = []
        self.trees = []
        self.props = []
        self.posters = []
        self.pois = []
        self.safe = []
        self.ponds = []
        self.flyovers = []
        self.rail = []
        self.graves = []
        self.landmark_rects = []

    # --- roads ----------------------------------------------------------------------------------
    def road(self, rid, name, kind, width, pts, sidewalk=None):
        r = {"id": rid, "name": name, "kind": kind, "width": width, "points": [[round(p[0], 2), round(p[1], 2)] for p in pts],
             "sidewalk": sidewalk if sidewalk is not None else (2.5 if kind in ("highway", "main") else 0.0)}
        self.roads.append(r)
        for a, b in zip(pts, pts[1:]):
            self.grid.mark_segment(a, b, width / 2 + r["sidewalk"] + 0.6, 1)
        return r

    def highways(self):
        self.road("n1", {"bn": "ঢাকা–চট্টগ্রাম মহাসড়ক (এন১)", "en": "Dhaka-Chattogram Highway (N1)"}, "highway", 28.0, [JATRABARI, N1_END], 3.0)
        self.road("n8", {"bn": "ঢাকা–মাওয়া মহাসড়ক (এন৮)", "en": "Dhaka-Mawa Highway (N8)"}, "highway", 20.0, [JATRABARI, N8_END], 2.5)
        self.road("r110", {"bn": "ঢাকা–ডেমরা সড়ক", "en": "Dhaka-Demra Road (R110)"}, "highway", 18.0, [JATRABARI, R110_END], 2.5)
        self.road("gulistan", {"bn": "গুলিস্তান রোড", "en": "Gulistan Road"}, "highway", 22.0, [JATRABARI, GULISTAN], 2.5)
        # Mayor Hanif flyover: over Gulistan Road, through the Jatrabari crossing, down onto N1 at Kajla
        kajla_land = lerp2(JATRABARI, N1_END, 0.33)
        fly = [GULISTAN, JATRABARI, kajla_land]
        self.flyovers.append({"id": "hanif_flyover", "name": {"bn": "মেয়র হানিফ ফ্লাইওভার", "en": "Mayor Hanif Flyover"},
                              "points": [[round(p[0], 2), round(p[1], 2)] for p in fly], "width": 16.0, "height": 9.0,
                              "ramp_length": 140.0})
        self.rail.append({"points": [list(RAIL[0]), list(RAIL[1])]})
        self.grid.mark_segment(RAIL[0], RAIL[1], 5.0, 1)

    def local_grid(self, district, origin, angle, spacing_u, spacing_v, span, kind_main_every=3, names=None, names_bn=None):
        """Lanes in a rotated grid. u along `angle`, v perpendicular. Keeps the parts inside `district`."""
        u = (math.cos(angle), math.sin(angle))
        v = (-math.sin(angle), math.cos(angle))
        lanes = []
        n = 0
        for axis in (0, 1):
            d_dir = u if axis == 0 else v
            o_dir = v if axis == 0 else u
            spacing = spacing_v if axis == 0 else spacing_u
            for k in range(-int(span / spacing), int(span / spacing) + 1):
                off = k * spacing + self.rng.uniform(-6, 6)
                base = add(origin, mul(o_dir, off))
                pts = [add(base, mul(d_dir, s)) for s in np.arange(-span, span, 4.0)]
                run = []
                for p in pts:
                    inside = 4 < p[0] < W - 4 and 4 < p[1] < H - 4 and district_at(p) == district
                    if inside:
                        run.append(p)
                    else:
                        if len(run) > 8:
                            lanes.append((run[0], run[-1], k % kind_main_every == 0))
                        run = []
                if len(run) > 8:
                    lanes.append((run[0], run[-1], k % kind_main_every == 0))
        for a, b, main in lanes:
            n += 1
            if names and n <= len(names):
                nm = {"bn": names_bn[n - 1], "en": names[n - 1]}
            else:
                nm = {"bn": "%s লেন %d" % (district_bn(district), n), "en": "%s Lane %d" % (district.capitalize(), n)}
            width = 9.0 if main else self.rng.choice([5.5, 6.0, 6.5])
            self.road("%s_%d" % (district, n), nm, "main" if main else "lane", width, [a, b], 1.6 if main else 0.0)

    # --- buildings ---------------------------------------------------------------------------------
    def landmark(self, lid, name, cx, cz, w, d, rot, floors, style, extra=None):
        b = {"id": lid, "x": round(cx, 2), "z": round(cz, 2), "w": w, "d": d, "rot": round(rot, 4), "floors": floors,
             "storey": 3.2, "style": style, "color": [0.9, 0.89, 0.85], "accent": [0.6, 0.14, 0.14], "shop": "", "sign": None,
             "district": district_at((cx, cz)), "roof": {"tank": True, "room": True, "garden": False, "laundry": False, "dish": True},
             "balconies": style in ("apartment", "tower"), "stripe": -1, "landmark": lid, "enterable": False, "name": name, "front": True}
        if extra:
            b.update(extra)
        self.grid.mark_rect(cx, cz, w + 2, d + 2, rot, 3)
        self.buildings.append(b)
        return b

    def place_landmarks(self):
        a_n1 = math.atan2(N1_END[1] - JATRABARI[1], N1_END[0] - JATRABARI[0])
        # Sontek: the Tower, between School Rd and Sontek Main Rd (photos p1-p5)
        t = self.landmark("tower", {"bn": "টাওয়ার (সোনটেক)", "en": "The Tower, Sontek"}, 905, 382, 35, 32, a_n1, 9, "tower",
                          {"color": [0.9, 0.9, 0.88], "accent": [0.62, 0.62, 0.64], "enterable": True,
                           "roof": {"tank": True, "room": True, "garden": True, "laundry": True, "dish": True},
                           "light_wells": 2, "parking": True})
        self.poi("tower_gate", {"bn": "টাওয়ারের গেট", "en": "Tower gate"}, *self.front_of(t, 3.0), "gate", "tower")
        self.poi("tower_roof", {"bn": "টাওয়ারের ছাদ", "en": "Tower roof"}, t["x"], t["z"], "roof", "tower", y=9 * 3.2 + 0.2)
        self.safe.append({"id": "tower_lobby", "rect": rect_of(t, 0.6), "kind": "home"})
        # pond north of Mosjid Rd 1
        self.ponds.append({"id": "sontek_pond", "rect": [800, 270, 858, 312]})
        self.grid.mark_rect(829, 291, 62, 46, 0.0, 3)
        self.poi("pond", {"bn": "সোনটেকের পুকুর", "en": "Sontek pond"}, 829, 318, "pond", "")
        # mosque on Masjid Rd
        m = self.landmark("mosque", {"bn": "মসজিদ", "en": "Mosque"}, 760, 352, 22, 18, a_n1, 2, "mosque",
                          {"color": [0.94, 0.94, 0.9], "accent": [0.2, 0.5, 0.36], "roof": {"tank": False, "room": False, "garden": False, "laundry": False, "dish": False}})
        self.poi("mosque", {"bn": "মসজিদ", "en": "Mosque"}, *self.front_of(m, 3.0), "mosque", "mosque")
        self.safe.append({"id": "mosque", "rect": rect_of(m, 0.5), "kind": "mosque"})
        # cyber cafe (job applications) in Sontek
        c = self.landmark("cyber", {"bn": "স্মার্ট সাইবার ক্যাফে", "en": "Smart Cyber Cafe"}, 1010, 300, 14, 16, a_n1, 5, "shophouse",
                          {"shop": "cyber", "sign": {"bn": "স্মার্ট সাইবার ক্যাফে", "en": "Smart Cyber Cafe"}, "enterable": True})
        self.poi("cyber_cafe", {"bn": "সাইবার ক্যাফে", "en": "Cyber cafe"}, *self.front_of(c, 3.0), "jobs", "cyber")
        # Kajla: Shortcut Coaching and Kajla Superstore on N1
        kj = lerp2(JATRABARI, N1_END, 0.4)
        off = mul((math.sin(a_n1), -math.cos(a_n1)), 36)
        cc = add(kj, off)
        co = self.landmark("coaching", {"bn": "শর্টকাট কোচিং", "en": "Shortcut Coaching"}, cc[0], cc[1], 24, 20, a_n1, 7, "commercial",
                           {"shop": "coaching", "sign": {"bn": "শর্টকাট কোচিং সেন্টার — বিসিএস গ্যারান্টি!", "en": "Shortcut Coaching Centre - BCS guaranteed!"},
                            "enterable": True, "color": [0.84, 0.86, 0.9], "accent": [0.8, 0.2, 0.3]})
        self.poi("coaching", {"bn": "শর্টকাট কোচিং", "en": "Shortcut Coaching"}, *self.front_of(co, 3.0), "coaching", "coaching")
        self.safe.append({"id": "coaching_class", "rect": rect_of(co, 0.6), "kind": "shop"})
        ks = add(lerp2(JATRABARI, N1_END, 0.36), mul((math.sin(a_n1), -math.cos(a_n1)), 30))
        su = self.landmark("superstore", {"bn": "কাজলা সুপারস্টোর", "en": "Kajla Superstore"}, ks[0], ks[1], 16, 14, a_n1, 4, "shophouse",
                           {"shop": "grocery", "sign": {"bn": "কাজলা সুপারস্টোর", "en": "Kajla Superstore"}, "enterable": True})
        self.poi("superstore", {"bn": "কাজলা সুপারস্টোর", "en": "Kajla Superstore"}, *self.front_of(su, 3.0), "shop", "superstore")
        self.poi("tea_flyover", {"bn": "ফ্লাইওভারের নিচের চায়ের দোকান", "en": "Tea stall under the flyover"},
                 *add(lerp2(JATRABARI, N1_END, 0.3), mul((math.sin(a_n1), -math.cos(a_n1)), -22)), "tea", "")
        # Dania College campus and Adarsha High School, south of N1
        dc = self.landmark("dania_college", {"bn": "দনিয়া কলেজ", "en": "Dania College"}, 1040, 830, 72, 18, a_n1, 4, "college",
                           {"color": [0.86, 0.62, 0.52], "accent": [0.95, 0.94, 0.9], "enterable": True,
                            "roof": {"tank": True, "room": False, "garden": False, "laundry": False, "dish": False}})
        self.grid.mark_rect(1040, 868, 90, 60, a_n1, 3)     # the college field in front
        self.landmark_rects.append(("college_field", 1040, 868, 84, 52, a_n1))
        self.poi("dania_college", {"bn": "দনিয়া কলেজের গেট", "en": "Dania College gate"}, *self.front_of(dc, 30.0), "college", "dania_college")
        self.poi("exam_hall", {"bn": "দনিয়া কলেজ পরীক্ষার হল", "en": "Dania College exam hall"}, dc["x"], dc["z"], "exam", "dania_college")
        self.safe.append({"id": "college", "rect": rect_of(dc, 0.5), "kind": "college"})
        dc2 = self.landmark("college_admin", {"bn": "কলেজ অফিস", "en": "College office"}, 980, 780, 30, 14, a_n1 + math.pi / 2, 3, "college",
                            {"color": [0.86, 0.62, 0.52], "accent": [0.95, 0.94, 0.9], "enterable": True})
        self.poi("college_office", {"bn": "কলেজ অফিস", "en": "College office"}, *self.front_of(dc2, 3.0), "office", "college_admin")
        sc = self.landmark("adarsha_school", {"bn": "আদর্শ উচ্চ বিদ্যালয়", "en": "Adarsha High School"}, 1180, 930, 50, 14, a_n1, 3, "college",
                           {"color": [0.9, 0.86, 0.66], "accent": [0.2, 0.4, 0.3]})
        self.poi("school", {"bn": "আদর্শ উচ্চ বিদ্যালয়", "en": "Adarsha High School"}, *self.front_of(sc, 4.0), "school", "adarsha_school")
        lib = self.landmark("library", {"bn": "পাঠাগার ও স্টাডি রুম", "en": "Public library and study room"}, 900, 760, 18, 14, a_n1, 3, "shophouse",
                            {"shop": "books", "sign": {"bn": "গণপাঠাগার ও স্টাডি রুম", "en": "Public Library & Study Room"}, "enterable": True})
        self.poi("library", {"bn": "পাঠাগার", "en": "Library"}, *self.front_of(lib, 3.0), "library", "library")
        self.safe.append({"id": "library", "rect": rect_of(lib, 0.6), "kind": "shop"})
        # Jatrabari: bus stand, market, police station, lawyer's chamber, clinic
        self.grid.mark_rect(330, 205, 70, 40, 0.0, 3)
        self.landmark_rects.append(("bus_stand", 330, 205, 66, 36, 0.0))
        self.poi("bus_stand", {"bn": "যাত্রাবাড়ী বাসস্ট্যান্ড", "en": "Jatrabari bus stand"}, 330, 228, "bus", "")
        ps = self.landmark("police_station", {"bn": "থানা", "en": "Police station"}, 185, 340, 26, 18, math.radians(96), 3, "commercial",
                           {"color": [0.84, 0.76, 0.62], "accent": [0.6, 0.2, 0.16], "sign": {"bn": "থানা", "en": "Police Station"}, "enterable": True})
        self.poi("police_station", {"bn": "থানা", "en": "Police station"}, *self.front_of(ps, 3.0), "police", "police_station")
        lw = self.landmark("lawyer", {"bn": "আইনজীবীর চেম্বার", "en": "Lawyer's chamber"}, 395, 320, 16, 14, 0.0, 6, "commercial",
                           {"shop": "books", "sign": {"bn": "অ্যাডভোকেট চেম্বার — আইন পরামর্শ", "en": "Advocate's Chamber - Legal Advice"}, "enterable": True})
        self.poi("lawyer", {"bn": "আইনজীবীর চেম্বার", "en": "Lawyer's chamber"}, *self.front_of(lw, 3.0), "bar", "lawyer")
        self.safe.append({"id": "lawyer", "rect": rect_of(lw, 0.6), "kind": "shop"})
        cl = self.landmark("clinic", {"bn": "জনতা ক্লিনিক", "en": "Janata Clinic"}, 140, 230, 20, 16, 0.0, 5, "commercial",
                           {"sign": {"bn": "জনতা ক্লিনিক ও ডায়াগনস্টিক", "en": "Janata Clinic & Diagnostic"}, "enterable": True})
        self.poi("clinic", {"bn": "জনতা ক্লিনিক", "en": "Janata Clinic"}, *self.front_of(cl, 3.0), "clinic", "clinic")
        self.safe.append({"id": "clinic", "rect": rect_of(cl, 0.6), "kind": "shop"})
        self.grid.mark_rect(150, 160, 50, 34, 0.0, 3)
        self.landmark_rects.append(("bazar", 150, 160, 46, 30, 0.0))
        self.poi("bazar", {"bn": "যাত্রাবাড়ী কাঁচাবাজার", "en": "Jatrabari kitchen market"}, 150, 180, "market", "")
        # Jurain: Sakib's mess (safehouse), the graveyard, the rail gate
        a_n8 = math.atan2(N8_END[1] - JATRABARI[1], N8_END[0] - JATRABARI[0])
        mp = add(lerp2(JATRABARI, N8_END, 0.42), mul((math.sin(a_n8), -math.cos(a_n8)), 44))
        me = self.landmark("mess", {"bn": "সাকিবের মেস", "en": "Sakib's mess"}, mp[0], mp[1], 14, 16, a_n8, 4, "old",
                           {"color": [0.82, 0.78, 0.68], "accent": [0.4, 0.4, 0.42], "enterable": True,
                            "roof": {"tank": True, "room": False, "garden": False, "laundry": True, "dish": False}})
        self.poi("mess", {"bn": "সাকিবের মেস", "en": "Sakib's mess"}, *self.front_of(me, 2.5), "home", "mess")
        self.safe.append({"id": "mess", "rect": rect_of(me, 0.4), "kind": "home"})
        gy = (390.0, 800.0)
        self.grid.mark_rect(gy[0], gy[1], 170, 120, 0.12, 3)
        self.landmark_rects.append(("graveyard", gy[0], gy[1], 166, 116, 0.12))
        self.poi("graveyard", {"bn": "জুরাইন কবরস্থান", "en": "Jurain Graveyard"}, gy[0] - 70, gy[1] - 66, "graveyard", "")
        self.poi("graveyard_shed", {"bn": "কবরস্থানের কেয়ারটেকারের ঘর", "en": "Graveyard caretaker's shed"}, gy[0] + 62, gy[1] + 40, "shed", "")
        for i in range(260):
            gx = gy[0] + self.rng.uniform(-76, 76)
            gz = gy[1] + self.rng.uniform(-52, 52)
            self.graves.append([round(gx, 2), round(gz, 2), round(0.12 + self.rng.uniform(-0.15, 0.15), 3)])
        rg = intersect(JATRABARI, N8_END, RAIL[0], RAIL[1])
        self.poi("rail_gate", {"bn": "জুরাইন রেলগেট", "en": "Jurain rail gate"}, rg[0] + 14, rg[1] - 10, "rail", "")
        self.poi("jatrabari_crossing", {"bn": "যাত্রাবাড়ী চৌরাস্তা", "en": "Jatrabari crossing"}, JATRABARI[0] + 18, JATRABARI[1] + 24, "crossing", "")
        self.spawn = list(self.front_of(me, 4.0))

    def front_of(self, b, dist):
        rot = b["rot"]
        # the front faces +v (south-west of the long side): local +Z
        fx = b["x"] - math.sin(rot) * (b["d"] / 2 + dist)
        fz = b["z"] + math.cos(rot) * (b["d"] / 2 + dist)
        return round(fx, 2), round(fz, 2)

    def poi(self, pid, name, x, z, kind, building, y=None):
        p = {"id": pid, "name": name, "x": round(x, 2), "z": round(z, 2), "kind": kind, "building": building}
        if y is not None:
            p["y"] = y
        self.pois.append(p)

    def fill_lots(self):
        """Buildings along both sides of every lane and road, then a second row behind."""
        order = sorted(self.roads, key=lambda r: {"highway": 0, "main": 1, "lane": 2}.get(r["kind"], 3))
        for r in order:
            pts = r["points"]
            for a, b in zip(pts, pts[1:]):
                a = tuple(a)
                b = tuple(b)
                d = norm(sub(b, a))
                n = (-d[1], d[0])
                length = math.hypot(b[0] - a[0], b[1] - a[1])
                rot = math.atan2(d[1], d[0])
                for side in (-1, 1):
                    for row in (0,):
                        s = self.rng.uniform(2, 8)
                        while s < length - 6:
                            p = lerp2(a, b, s / length)
                            dist_name = district_at(p)
                            style, floors, frontage, depth = self.lot_style(dist_name, r["kind"], row)
                            setback = r["width"] / 2 + r["sidewalk"] + 2.4 + depth / 2 + row * (depth + self.rng.uniform(2.0, 4.0))
                            if row > 0:
                                setback += 18.0 * (row - 1)
                            c = add(p, mul(n, side * setback))
                            c = add(c, mul(d, frontage / 2))
                            gap = self.rng.uniform(1.5, 3.0)
                            b_rot = rot if side < 0 else rot + math.pi   # front faces the road
                            if district_at(c) == dist_name and self.grid.rect_free(c[0], c[1], frontage, depth, rot, 0.6):
                                self.add_building(c, frontage, depth, b_rot, floors, style, dist_name, r, row == 0)
                                self.grid.mark_rect(c[0], c[1], frontage, depth, rot, 2)
                            s += frontage + gap

    def infill(self):
        """Fill every block densely, aligned to the district grid, 1.5-2 m gaps (as in the photos)."""
        a_n1 = math.atan2(N1_END[1] - JATRABARI[1], N1_END[0] - JATRABARI[0])
        a_n8 = math.atan2(N8_END[1] - JATRABARI[1], N8_END[0] - JATRABARI[0])
        frames = {"sontek": a_n1, "dania": a_n1, "kajla": a_n1, "jatrabari": 0.35, "jurain": a_n8}
        rng = self.rng
        step = 6.0
        for j in np.arange(4, H - 4, step):
            for i in np.arange(4, W - 4, step):
                c = (i + rng.uniform(-2, 2), j + rng.uniform(-2, 2))
                gx, gz = int(c[0] / CELL), int(c[1] / CELL)
                if self.grid.occ[gz, gx] != 0:
                    continue
                dist_name = district_at(c)
                ang = frames[dist_name]
                if rng.random() < 0.04:
                    continue          # an empty plot or a building site now and then
                for attempt in range(4):
                    style, floors, frontage, depth = self.lot_style(dist_name, "lane", 1 if attempt < 2 else 2)
                    if attempt >= 2:
                        frontage *= 0.7
                        depth *= 0.7
                    if self.grid.rect_free(c[0], c[1], frontage, depth, ang, 0.8):
                        rot = self.facing(c, frontage, depth, ang)
                        front = rot is not None
                        if rot is None:
                            rot = ang + (math.pi if rng.random() < 0.5 else 0.0)
                        self.add_building(c, frontage, depth, rot, floors, style, dist_name, None, front)
                        self.grid.mark_rect(c[0], c[1], frontage, depth, ang, 2)
                        break

    def facing(self, c, w, d, ang):
        """The rotation whose front (+local Z) looks onto a road within 5 m, or None."""
        for rot in (ang, ang + math.pi):
            fx = c[0] - math.sin(rot) * (d / 2 + 4.0)
            fz = c[1] + math.cos(rot) * (d / 2 + 4.0)
            gx, gz = int(fx / CELL), int(fz / CELL)
            if 0 <= gx < self.grid.nx and 0 <= gz < self.grid.nz and self.grid.occ[gz, gx] == 1:
                return rot
        return None

    def poster_pass(self):
        rng = self.rng
        front = [b for b in self.buildings if b.get("front") and b["style"] != "shack" and not b["landmark"]]
        rng.shuffle(front)
        for b in front[:150]:
            self.add_poster(b, b["district"])
        for lm in ("coaching", "superstore", "cyber", "library", "dania_college", "mess"):
            for b in self.buildings:
                if b["id"] == lm:
                    for _ in range(3 if lm == "coaching" else 1):
                        self.add_poster(b, b["district"], "leak" if lm == "coaching" and rng.random() < 0.4 else None)

    def lot_style(self, district, road_kind, row):
        rng = self.rng
        if road_kind == "highway" and row == 0 and district != "jurain":
            return "commercial", rng.randint(6, 12), rng.uniform(16, 26), rng.uniform(14, 22)
        if district in ("sontek", "dania"):
            if row == 0 and road_kind in ("main", "lane") and rng.random() < 0.3:
                return "shophouse", rng.randint(2, 4), rng.uniform(8, 13), rng.uniform(10, 14)
            return "apartment", rng.randint(6, 10), rng.uniform(13, 22), rng.uniform(14, 24)
        if district in ("kajla", "jatrabari"):
            if road_kind == "highway" and row == 0:
                return "commercial", rng.randint(6, 12), rng.uniform(16, 26), rng.uniform(14, 22)
            return ("shophouse" if rng.random() < 0.5 else "apartment"), rng.randint(3, 8), rng.uniform(10, 18), rng.uniform(12, 18)
        # jurain
        if rng.random() < 0.18 and row > 0:
            return "shack", 1, rng.uniform(5, 8), rng.uniform(5, 8)
        return ("shophouse" if row == 0 and rng.random() < 0.4 else "old"), rng.randint(2, 5), rng.uniform(8, 14), rng.uniform(10, 16)

    def add_building(self, c, w, d, rot, floors, style, district, road, frontline):
        rng = self.rng
        pal = PALETTE["old" if style in ("old", "shack") else ("commercial" if style == "commercial" else "apartments")]
        col = rng.choice(pal)
        jitter = [max(0, min(1, x + rng.uniform(-0.03, 0.03))) for x in col]
        shop = ""
        sign = None
        if frontline and style in ("shophouse", "commercial", "apartment") and rng.random() < (0.85 if style != "apartment" else 0.35):
            shop = rng.choice(list(SHOP_KIND.keys()))
            pre = rng.choice(SHOP_PREFIX)
            kind_bn, kind_en = SHOP_KIND[shop]
            sign = {"bn": "%s %s" % (pre[0], kind_bn), "en": "%s %s" % (pre[1], kind_en)}
        bid = "b%04d" % (len(self.buildings) + 1)
        b = {"id": bid, "x": round(c[0], 2), "z": round(c[1], 2), "w": round(w, 2), "d": round(d, 2), "rot": round(rot, 4),
             "floors": floors, "storey": 3.0 if style != "shack" else 2.6, "style": style,
             "color": [round(x, 3) for x in jitter], "accent": list(rng.choice(ACCENTS)), "shop": shop, "sign": sign,
             "district": district,
             "roof": {"tank": style != "shack" and rng.random() < 0.85, "room": style in ("apartment", "commercial") and rng.random() < 0.6,
                      "garden": style == "apartment" and rng.random() < 0.3, "laundry": style in ("apartment", "old") and rng.random() < 0.45,
                      "dish": rng.random() < 0.35},
             "balconies": style == "apartment" or (style == "old" and rng.random() < 0.4),
             "stripe": rng.randint(0, 3) if style == "apartment" and rng.random() < 0.55 else -1,
             "landmark": "", "enterable": False, "front": bool(frontline)}
        if not frontline:
            b["shop"] = ""
            b["sign"] = None
        self.buildings.append(b)

    def add_poster(self, b, district, kind=None):
        rng = self.rng
        kinds = ["coaching"] * 6 + ["circular"] * 3 + ["job"] * 3 + ["bar"] * 2 + ["leak"] * 3 + ["notice"] * 1
        if kind is None:
            kind = rng.choice(kinds)
            if district == "jurain" and rng.random() < 0.3:
                kind = "notice"
        rot = b["rot"]
        # on the front face, beside the shop shutter
        u = rng.uniform(-0.35, 0.35) * b["w"]
        nx, nz = -math.sin(rot), math.cos(rot)
        px = b["x"] + math.cos(rot) * u + nx * (b["d"] / 2 + 0.03)
        pz = b["z"] + math.sin(rot) * u + nz * (b["d"] / 2 + 0.03)
        self.posters.append({"id": "poster_%03d" % (len(self.posters) + 1), "x": round(px, 2), "y": round(rng.uniform(1.7, 2.3), 2),
                             "z": round(pz, 2), "nx": round(nx, 4), "nz": round(nz, 4), "kind": kind, "district": district,
                             "variant": rng.randint(0, 5)})

    # --- street furniture ------------------------------------------------------------------------
    def furniture(self):
        rng = self.rng
        for r in self.roads:
            pts = r["points"]
            for a, b in zip(pts, pts[1:]):
                a = tuple(a)
                b = tuple(b)
                d = norm(sub(b, a))
                n = (-d[1], d[0])
                length = math.hypot(b[0] - a[0], b[1] - a[1])
                edge = r["width"] / 2 + r["sidewalk"] * 0.5 + 0.4
                lamp_step = 30.0 if r["kind"] == "highway" else 26.0
                s = rng.uniform(4, 12)
                side = 1
                while s < length - 4:
                    p = add(lerp2(a, b, s / length), mul(n, side * edge))
                    self.lamps.append([round(p[0], 2), round(p[1], 2), district_at(p)])
                    side = -side if r["kind"] != "highway" else side
                    s += lamp_step
                if r["kind"] != "highway":
                    chain = []
                    s = 3.0
                    while s < length - 2:
                        p = add(lerp2(a, b, s / length), mul(n, -(edge + 0.2)))
                        chain.append([round(p[0], 2), round(p[1], 2)])
                        s += rng.uniform(22, 30)
                    if len(chain) >= 2:
                        self.poles.append(chain)
                # props along the road
                s = rng.uniform(10, 40)
                while s < length - 8:
                    p = lerp2(a, b, s / length)
                    kind = rng.choice(["tea_stall", "fruit_cart", "rickshaw_stand", "garbage", "bench", "garbage", "tea_stall", "rickshaw_stand"])
                    off = edge + (1.6 if kind in ("tea_stall", "fruit_cart") else 0.8)
                    q = add(p, mul(n, rng.choice([-1, 1]) * off))
                    if self.grid.occ[int(q[1] / CELL) % self.grid.nz, int(q[0] / CELL) % self.grid.nx] != 2:
                        self.props.append({"kind": kind, "x": round(q[0], 2), "z": round(q[1], 2), "rot": round(math.atan2(d[1], d[0]), 3)})
                    s += rng.uniform(40, 90)
                # a banner across busy lanes
                if r["kind"] == "main" and rng.random() < 0.5:
                    p = lerp2(a, b, rng.uniform(0.3, 0.7))
                    self.props.append({"kind": "banner", "x": round(p[0], 2), "z": round(p[1], 2), "rot": round(math.atan2(d[1], d[0]), 3),
                                       "width": r["width"] + 2})
        # trees: college field edge, graveyard, pond, highway median, random gaps
        for name, cx, cz, w, d, rot in self.landmark_rects:
            if name in ("college_field", "graveyard"):
                for i in range(26 if name == "graveyard" else 18):
                    u = rng.uniform(-w / 2, w / 2)
                    v = rng.choice([-d / 2, d / 2]) * rng.uniform(0.85, 1.0) if rng.random() < 0.6 else rng.uniform(-d / 2, d / 2)
                    x = cx + u * math.cos(rot) - v * math.sin(rot)
                    z = cz + u * math.sin(rot) + v * math.cos(rot)
                    self.trees.append([round(x, 2), round(z, 2), round(rng.uniform(2.5, 4.5), 2)])
        for i in range(10):
            ang = rng.uniform(0, math.tau)
            self.trees.append([round(829 + math.cos(ang) * 36, 2), round(291 + math.sin(ang) * 27, 2), round(rng.uniform(2.5, 4.0), 2)])
        for t in np.arange(0.36, 0.98, 0.035):
            p = lerp2(JATRABARI, N1_END, t)
            self.trees.append([round(p[0], 2), round(p[1], 2), 2.2])
        tries = 0
        while len(self.trees) < 380 and tries < 4000:
            tries += 1
            x, z = rng.uniform(10, W - 10), rng.uniform(10, H - 10)
            if self.grid.rect_free(x, z, 4, 4, 0.0):
                self.trees.append([round(x, 2), round(z, 2), round(rng.uniform(2.0, 4.0), 2)])
                self.grid.mark_rect(x, z, 3, 3, 0.0, 3)

    # --- navigation data ----------------------------------------------------------------------------
    def ped_graph(self):
        nodes = []
        edges = set()
        for r in self.roads:
            pts = r["points"]
            off = r["width"] / 2 + (r["sidewalk"] * 0.5 if r["sidewalk"] > 0 else -1.0)
            for a, b in zip(pts, pts[1:]):
                a = tuple(a)
                b = tuple(b)
                d = norm(sub(b, a))
                n = (-d[1], d[0])
                length = math.hypot(b[0] - a[0], b[1] - a[1])
                for side in (-1, 1):
                    prev = None
                    steps = max(2, int(length / 12.0))
                    for i in range(steps + 1):
                        p = add(lerp2(a, b, i / steps), mul(n, side * off))
                        if not (2 < p[0] < W - 2 and 2 < p[1] < H - 2):
                            prev = None
                            continue
                        nodes.append([round(p[0], 2), round(p[1], 2)])
                        idx = len(nodes) - 1
                        if prev is not None:
                            edges.add((prev, idx))
                        prev = idx
        arr = np.array(nodes)
        # join nearby nodes of different streets (junctions and crossings)
        for i in range(len(nodes)):
            dd = np.hypot(arr[:, 0] - arr[i, 0], arr[:, 1] - arr[i, 1])
            near = np.where((dd < 9.0) & (dd > 0.1))[0]
            for j in near[:4]:
                if i < j:
                    edges.add((i, int(j)))
        return nodes, sorted(edges)

    def traffic_lanes(self):
        lanes = []
        for r in self.roads:
            if r["kind"] == "alley":
                continue
            pts = [tuple(p) for p in r["points"]]
            off = r["width"] / 4.0 if r["kind"] != "highway" else r["width"] / 4.0 + 1.0
            speed = {"highway": 13.0, "main": 8.0, "lane": 5.5}.get(r["kind"], 5.0)
            for direction in (1, -1):
                seq = pts if direction == 1 else list(reversed(pts))
                out = []
                for a, b in zip(seq, seq[1:]):
                    d = norm(sub(b, a))
                    n = (d[1], -d[0])          # drive on the left (Bangladesh)
                    out.append(add(a, mul(n, off)))
                    out.append(add(b, mul(n, off)))
                lanes.append({"road": r["id"], "points": [[round(p[0], 2), round(p[1], 2)] for p in out], "speed": speed})
        # connections: lanes whose start is near another lane's end
        starts = np.array([l["points"][0] for l in lanes])
        for l in lanes:
            e = l["points"][-1]
            dd = np.hypot(starts[:, 0] - e[0], starts[:, 1] - e[1])
            l["next"] = [int(i) for i in np.where(dd < 22.0)[0] if lanes[int(i)]["road"] != l["road"]][:6]
        return lanes

    def build(self):
        self.highways()
        self.place_landmarks()
        a_n1 = math.atan2(N1_END[1] - JATRABARI[1], N1_END[0] - JATRABARI[0])
        a_n8 = math.atan2(N8_END[1] - JATRABARI[1], N8_END[0] - JATRABARI[0])
        self.local_grid("sontek", (880, 360), a_n1, 64.0, 72.0, 700, 3, SONTEK_ROADS, SONTEK_ROADS_BN)
        self.local_grid("dania", (1000, 800), a_n1, 70.0, 78.0, 600, 3)
        self.local_grid("kajla", (650, 520), a_n1, 58.0, 300.0, 300, 2)
        self.local_grid("jurain", (230, 760), a_n8, 62.0, 66.0, 600, 3)
        self.local_grid("jatrabari", (260, 260), 0.35, 60.0, 60.0, 260, 2)
        self.fill_lots()
        self.infill()
        self.poster_pass()
        self.furniture()
        nodes, edges = self.ped_graph()
        lanes = self.traffic_lanes()
        return {
            "version": 2, "seed": self.seed, "size": [W, H], "generator": "tools/make_city.py",
            "districts": DISTRICTS, "roads": self.roads, "flyovers": self.flyovers, "rail": self.rail,
            "buildings": self.buildings, "ponds": self.ponds, "trees": self.trees, "lamps": self.lamps, "poles": self.poles,
            "posters": self.posters, "props": self.props, "graves": self.graves,
            "landmark_areas": [{"id": n, "x": cx, "z": cz, "w": w, "d": d, "rot": round(rot, 4)} for n, cx, cz, w, d, rot in self.landmark_rects],
            "ped_nodes": nodes, "ped_edges": [list(e) for e in edges], "lanes": lanes, "pois": self.pois, "safe_zones": self.safe,
            "spawn": self.spawn,
            "district_raster": district_raster(),
        }


def district_raster(cell=10):
    """District index per 10 m cell, row by row from the north-west corner (CityData.district_at)."""
    ids = [d["id"] for d in DISTRICTS]
    w, h = int(W / cell), int(H / cell)
    rows = []
    for j in range(h):
        rows.append("".join(str(ids.index(district_at(((i + 0.5) * cell, (j + 0.5) * cell)))) for i in range(w)))
    return {"cell": cell, "w": w, "h": h, "data": "".join(rows)}


def district_bn(d):
    return {"sontek": "সোনটেক", "dania": "দনিয়া", "jurain": "জুরাইন", "kajla": "কাজলা", "jatrabari": "যাত্রাবাড়ী"}.get(d, d)


def rect_of(b, inset):
    """Axis-aligned bounds of a building, shrunk by `inset` metres (used for indoor safe zones)."""
    c, s = abs(math.cos(b["rot"])), abs(math.sin(b["rot"]))
    hw = (b["w"] * c + b["d"] * s) / 2 - inset
    hd = (b["w"] * s + b["d"] * c) / 2 - inset
    return [round(b["x"] - hw, 2), round(b["z"] - hd, 2), round(b["x"] + hw, 2), round(b["z"] + hd, 2)]


def intersect(a, b, c, d):
    x1, y1 = a
    x2, y2 = b
    x3, y3 = c
    x4, y4 = d
    den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
    return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))


def preview(city, path):
    from PIL import Image, ImageDraw
    s = 1.0
    img = Image.new("RGB", (int(W * s), int(H * s)), (58, 62, 52))
    dr = ImageDraw.Draw(img)
    tint = {"jatrabari": (70, 66, 62), "kajla": (72, 64, 58), "sontek": (60, 68, 60), "dania": (64, 66, 72), "jurain": (68, 62, 54)}
    step = 10
    for x in range(0, int(W), step):
        for z in range(0, int(H), step):
            dr.rectangle([x * s, z * s, (x + step) * s, (z + step) * s], fill=tint[district_at((x + 5, z + 5))])
    for p in city["ponds"]:
        r = p["rect"]
        dr.ellipse([r[0] * s, r[1] * s, r[2] * s, r[3] * s], fill=(50, 90, 110))
    for a in city["landmark_areas"]:
        poly = rect_poly(a["x"], a["z"], a["w"], a["d"], a["rot"])
        dr.polygon([(x * s, z * s) for x, z in poly], fill=(70, 96, 58) if a["id"] in ("college_field", "graveyard") else (90, 86, 80))
    for g in city["graves"]:
        dr.rectangle([g[0] * s - 1, g[1] * s - 1, g[0] * s + 1, g[1] * s + 1], fill=(200, 200, 190))
    for r in city["roads"]:
        col = {"highway": (40, 40, 44), "main": (66, 66, 70), "lane": (84, 82, 80)}[r["kind"]]
        pts = [(p[0] * s, p[1] * s) for p in r["points"]]
        dr.line(pts, fill=col, width=max(2, int((r["width"] + 2 * r["sidewalk"]) * s)))
    for rl in city["rail"]:
        pts = [(p[0] * s, p[1] * s) for p in rl["points"]]
        dr.line(pts, fill=(110, 90, 70), width=5)
    for f in city["flyovers"]:
        pts = [(p[0] * s, p[1] * s) for p in f["points"]]
        dr.line(pts, fill=(150, 150, 156), width=int(f["width"] * s))
    for b in city["buildings"]:
        poly = rect_poly(b["x"], b["z"], b["w"], b["d"], b["rot"])
        c = tuple(int(v * 255 * (0.55 + 0.045 * min(b["floors"], 10))) for v in b["color"])
        if b["landmark"]:
            c = (240, 170, 60)
        dr.polygon([(x * s, z * s) for x, z in poly], fill=c, outline=(30, 30, 30))
    for t in city["trees"]:
        dr.ellipse([(t[0] - t[2]) * s, (t[1] - t[2]) * s, (t[0] + t[2]) * s, (t[1] + t[2]) * s], fill=(52, 110, 54))
    for p in city["posters"]:
        dr.rectangle([p["x"] * s - 2, p["z"] * s - 2, p["x"] * s + 2, p["z"] * s + 2], fill=(229, 72, 127))
    for p in city["pois"]:
        dr.ellipse([p["x"] * s - 5, p["z"] * s - 5, p["x"] * s + 5, p["z"] * s + 5], fill=(242, 169, 59), outline=(0, 0, 0))
        dr.text((p["x"] * s + 7, p["z"] * s - 6), p["name"]["en"], fill=(255, 255, 255))
    sp = city["spawn"]
    dr.ellipse([sp[0] - 7, sp[1] - 7, sp[0] + 7, sp[1] + 7], outline=(46, 196, 182), width=3)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def rect_poly(cx, cz, w, d, rot):
    c, s = math.cos(rot), math.sin(rot)
    out = []
    for u, v in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)):
        out.append((cx + u * c - v * s, cz + u * s + v * c))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=20261119)
    ap.add_argument("--no-preview", action="store_true")
    args = ap.parse_args()
    city = City(args.seed).build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(city, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    counts = {k: len(v) for k, v in city.items() if isinstance(v, list)}
    print("Wrote %s (%.1f MB)" % (OUT.relative_to(ROOT), OUT.stat().st_size / 1e6))
    print(counts)
    by = {}
    for b in city["buildings"]:
        by[b["district"]] = by.get(b["district"], 0) + 1
    print("buildings by district:", by)
    if not args.no_preview:
        preview(city, PREVIEW)
        print("Preview:", PREVIEW.relative_to(ROOT))


if __name__ == "__main__":
    main()
