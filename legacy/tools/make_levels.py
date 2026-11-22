#!/usr/bin/env python3
"""Builds Data/Levels/L01.json ... L20.json for "S M Nazmuz Sakib is unemployed".

Each level is drawn on a grid (cell = 2 m, storey = 3.2 m) with the legend LevelBuilder.gd reads,
then checked before it is written:
  * every row has the same width and every character is one the builder knows;
  * stairs have open space above them and a floor to land on;
  * from the start, every objective target can be reached on foot (gates count as open,
    lifts, rides and bypasses count as links);
  * every gate has a definition, every gate set exists in the question bank, every "opens"
    names a real gate group, and every career person exists in the scenarios.
Run from anywhere:  python3 tools/make_levels.py        (add --check to validate only)
Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.
"""
import json
import pathlib
import sys
from collections import deque

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Data" / "Levels"
CUSTOM = "123456789AFHIJKMNOQSUV"
MARKS = "@EXYZPC"
KNOWN = set(" #|.f,=-BbRWT+tnkcruopwmgxyqhdlz%><^vDGL") | set(MARKS) | set(CUSTOM)
BLOCKED = set("#|BbRWTtnkcruwmgxqhd+")
RAMPS = {">": (1, 0), "<": (-1, 0), "v": (0, 1), "^": (0, -1)}
PRAYERS = {"05:00": "Fajr", "13:15": "Zuhr", "16:30": "Asr", "17:50": "Maghrib", "19:30": "Isha"}
ROOF_DOOR = "K"


# --- Map drawing -------------------------------------------------------------------------

class Map:
    def __init__(self, w, h, nf=1):
        self.w, self.h, self.nf = w, h, nf
        self.g = [[[" "] * w for _ in range(h)] for _ in range(nf)]

    def get(self, f, x, y):
        if 0 <= f < self.nf and 0 <= x < self.w and 0 <= y < self.h:
            return self.g[f][y][x]
        return " "

    def put(self, f, x, y, ch):
        assert 0 <= f < self.nf and 0 <= x < self.w and 0 <= y < self.h, ("off map", f, x, y, ch)
        self.g[f][y][x] = ch

    def fill(self, f, x1, y1, x2, y2, ch):
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                self.put(f, x, y, ch)

    def room(self, f, x1, y1, x2, y2, inside=".", wall="#"):
        self.fill(f, x1, y1, x2, y2, wall)
        self.fill(f, x1 + 1, y1 + 1, x2 - 1, y2 - 1, inside)

    def many(self, f, ch, cells):
        for x, y in cells:
            self.put(f, x, y, ch)

    def rows(self, f):
        return ["".join(r).rstrip() or " " for r in self.g[f]]

    def find(self, ch):
        return [(f, x, y) for f in range(self.nf) for y in range(self.h) for x in range(self.w) if self.g[f][y][x] == ch]


def frame(m, ch="B"):
    m.fill(0, 0, 0, m.w - 1, 0, ch)
    m.fill(0, 0, m.h - 1, m.w - 1, m.h - 1, ch)
    m.fill(0, 0, 0, 0, m.h - 1, ch)
    m.fill(0, m.w - 1, 0, m.w - 1, m.h - 1, ch)


def street(m, y, x1, x2):
    """Pavement, two road rows, pavement."""
    m.fill(0, x1, y, x2, y, "-")
    m.fill(0, x1, y + 1, x2, y + 2, "=")
    m.fill(0, x1, y + 3, x2, y + 3, "-")


def parapet(m, f, x1, y1, x2, y2):
    for (a, b, c, d) in ((x1, y1, x2, y1), (x1, y2, x2, y2), (x1, y1, x1, y2), (x2, y1, x2, y2)):
        m.fill(f, a, b, c, d, "|")


def roof_block(m, x1, y1, x2, y2, rf):
    """A solid building whose flat roof is walkable on floor rf."""
    m.fill(0, x1, y1, x2, y2, "R")
    m.fill(rf, x1, y1, x2, y2, ",")
    parapet(m, rf, x1, y1, x2, y2)


def plank(m, rf, cells, openings):
    m.many(rf, "%", cells)
    m.many(rf, ",", openings)


def ramp(m, f, x, y, ch, n=4):
    """A stair ramp of n cells on floor f; clears the cells above it and makes sure it lands on floor."""
    dx, dy = RAMPS[ch]
    for i in range(n):
        m.put(f, x + dx * i, y + dy * i, ch)
        m.put(f + 1, x + dx * i, y + dy * i, " ")
    lx, ly = x + dx * n, y + dy * n
    if m.get(f + 1, lx, ly) in (" ", "#"):
        m.put(f + 1, lx, ly, ".")


def stairs(m, x0, y0, f0, f1):
    """6 x 2 stair core at x0..x0+5, y0..y0+1 from floor f0 up to floor f1 (switchback)."""
    for f in range(f0, f1 + 1):
        k = f - f0
        m.fill(f, x0, y0, x0 + 5, y0 + 1, ".")
        if f > f0:
            row = y0 if (k - 1) % 2 == 0 else y0 + 1
            m.fill(f, x0 + 1, row, x0 + 4, row, " ")
        if f < f1:
            if k % 2 == 0:
                m.fill(f, x0 + 1, y0, x0 + 4, y0, ">")
            else:
                m.fill(f, x0 + 1, y0 + 1, x0 + 4, y0 + 1, "<")


def tower(m, floors, roof):
    """The Tower: 22 x 12 cells at x 2..23, y 2..13, switchback stairs in the north-west corner,
    lift at the east end of the corridor, three flats a floor, a lobby on the ground floor.
    Returns the top floor index. The roof (if any) is floor `floors`."""
    top = floors if roof else floors - 1
    for f in range(floors):
        m.fill(f, 2, 2, 23, 13, "#")
        m.fill(f, 3, 3, 22, 12, ".")
        m.fill(f, 9, 2, 9, 5, "#")
        m.fill(f, 2, 5, 23, 5, "#")
        m.put(f, 16, 5, "D")
        if f > 0:
            m.fill(f, 2, 7, 23, 7, "#")
            for x in (5, 12, 19):
                m.put(f, x, 7, "D")
            m.fill(f, 9, 7, 9, 13, "#")
            m.fill(f, 16, 7, 16, 13, "#")
        m.put(f, 22, 6, "L")
    m.put(0, 12, 13, "D")
    if roof:
        f = floors
        m.fill(f, 2, 2, 23, 13, ",")
        parapet(m, f, 2, 2, 23, 13)
        m.fill(f, 2, 2, 9, 2, "#")
        m.fill(f, 2, 2, 2, 5, "#")
        m.fill(f, 9, 2, 9, 5, "#")
        m.fill(f, 2, 5, 9, 5, "#")
    stairs(m, 3, 3, 0, top)
    for k in range(top + 1):
        x = 3 if k % 2 == 0 else 8
        m.put(k, x, 5, ROOF_DOOR if (roof and k == top) else "D")
    return top


def core_door(k):
    """Where the Tower's stair core opens on floor k."""
    return (3, 5) if k % 2 == 0 else (8, 5)


def compound_and_street(m, gate):
    m.fill(0, 2, 14, 2, 17, "#")
    m.fill(0, 23, 14, 23, 17, "#")
    m.fill(0, 2, 17, 23, 17, "#")
    m.put(0, 12, 17, "G" if gate else " ")
    m.put(0, 13, 17, "G" if gate else " ")
    street(m, 18, 1, m.w - 2)
    m.fill(0, 1, 22, m.w - 2, 22, "b")


# --- Gates ---------------------------------------------------------------------------------

def file_gate(gid, **extra):
    d = json.loads((ROOT / "Data" / "Gates" / f"{gid}.json").read_text(encoding="utf-8"))
    d.update(extra)
    return d


def gate(keeper, size=5, sets=("G",), pass_points=None, category="door", compose=None, timer=0, depth=3, **extra):
    d = {"gatekeeper": keeper, "category": category, "size": size,
         "pass_points": pass_points if pass_points is not None else (3.0 if size <= 5 else 7.0),
         "draw": {"sets": list(sets)}, "chain": {"max_depth": depth, "recovered_points": 0.5}}
    if compose:
        d["compose"] = [{"sets": list(s), "count": c} for s, c in compose]
    if timer:
        d["timer_s"] = timer
    d.update(extra)
    return d


def gate_groups(m):
    """Gate groups in the order LevelBuilder numbers them: floors, then rows, then columns."""
    groups = {}
    n = 0
    for f in range(m.nf):
        for y in range(m.h):
            for x in range(m.w):
                if m.get(f, x, y) == "G" and m.get(f, x - 1, y) != "G" and m.get(f, x, y - 1) != "G":
                    groups[(f, x, y)] = "gate%d" % n
                    n += 1
    return groups


def gate_key(m, f, x, y):
    groups = gate_groups(m)
    while m.get(f, x - 1, y) == "G":
        x -= 1
    while m.get(f, x, y - 1) == "G":
        y -= 1
    return groups[(f, x, y)]


# --- Levels ---------------------------------------------------------------------------------

def lvl(n, title, chapter, brief, m, legend, objectives, gates, **kw):
    d = {"level": n, "title": title, "chapter": chapter, "brief": brief,
         "floors": [m.rows(f) for f in range(m.nf)], "legend": legend, "objectives": objectives,
         "gates": gates, "prayers": PRAYERS}
    d.update(kw)
    d["_map"] = m
    return d


def L01():
    m = Map(38, 24, 2)
    frame(m)
    tower(m, 2, False)
    compound_and_street(m, True)
    # lobby and meter room
    m.put(0, 11, 3, "2")
    m.many(0, "m", [(21, 3), (22, 3)])
    m.put(0, 14, 9, "3")
    m.many(0, "Y", [(8, 10), (18, 10)])
    m.many(0, "P", [(5, 8), (20, 8), (12, 11), (14, 6)])
    m.many(0, "p", [(3, 12), (22, 12)])
    m.put(0, 7, 12, "n")
    # Sakib's flat (room A, first floor)
    m.put(1, 4, 11, "@")
    m.put(1, 7, 9, "1")
    m.many(1, "t", [(6, 9)])
    m.many(1, "p", [(3, 8)])
    m.put(1, 8, 12, "x")
    # compound
    m.put(0, 4, 15, "g")
    m.many(0, "x", [(20, 15), (21, 15)])
    m.put(0, 3, 16, "6")
    m.put(0, 14, 16, "4")
    m.put(0, 3, 18, "7")
    # School Road and the open ground east
    m.put(0, 27, 18, "k")
    m.put(0, 28, 18, "5")
    m.put(0, 36, 19, "E")
    m.many(0, "C", [(20, 18), (31, 21), (10, 21)])
    m.put(0, 8, 20, "r")
    m.put(0, 18, 20, "r")
    m.put(0, 23, 19, "c")
    m.many(0, "T", [(26, 4), (33, 4), (30, 14), (35, 9)])
    m.put(0, 29, 9, "k")
    m.put(0, 28, 11, "n")
    m.many(0, "b", [(32, 6), (33, 6), (32, 7), (33, 7)])
    legend = {
        "1": {"type": "pickup", "key": "admit_card", "label": "Take your admit card",
              "toast": "Admit card: roll 1042, Dania College centre. It still smells of the printer."},
        "2": {"type": "utility", "key": "lights", "label": "Pull the lobby light breaker", "utility": "lights"},
        "3": {"type": "career", "person": "Tanvir", "lines": ["Bhai! Exam today? The syndicate boys are in the lobby again.", "Before you go... can I ask you something?"]},
        "4": {"type": "gatekeeper", "name": "Doorman", "gate": "L01_doorman", "look": "doorman",
              "intro": "Nobody leaves this compound during the syndicate's hours without answering me. Five questions. Three right and the gate opens."},
        "5": {"type": "gatekeeper", "name": "Kajla Superstore clerk", "gate": "L01_pen", "look": "shopkeeper",
              "intro": "A pen for the exam? Prove you know what you're buying."},
        "6": {"type": "bypass", "key": "parking_wall", "label": "Climb the parking wall (noisy)", "to": "7", "gate": "L01_doorman", "noise": 64,
              "toast": "You haul yourself over the wall and drop onto School Road. Someone heard that."},
        "7": {"type": "spot"},
    }
    objectives = [
        {"type": "pickup", "key": "admit_card", "text": "Take your admit card from the desk"},
        {"type": "talk", "person": "Tanvir", "text": "Go down to the lobby and talk to Tanvir"},
        {"type": "utility", "key": "lights", "text": "Cut the lobby lights in the meter room (in the dark they see half as far)"},
        {"type": "gate", "gate": "L01_doorman", "text": "Get past the doorman at the compound gate: answer him, pay him, or climb the parking wall"},
        {"type": "gate", "gate": "L01_pen", "text": "Buy an exam pen at Kajla Superstore"},
        {"type": "reach", "marker": "E", "text": "Walk east along School Road to Dania College"},
    ]
    gates = {"L01_doorman": file_gate("L01_doorman", opens=gate_key(m, 0, 12, 17)), "L01_pen": file_gate("L01_pen")}
    return lvl(1, "The admit card", "Chapter 1 · The Tower", "Exam day in Jatrabari. Sakib's admit card is on his desk on the first floor of the Tower. The syndicate's boys own the lobby and the doorman owns the gate.",
               m, legend, objectives, gates, start_hour=9.0, palette="tower", sector="tower_ground", crowd=40,
               last_wish_cap=1, lw_share=0.35, player_yaw=0, intro=["Exam day. The admit card is on my desk.", "The syndicate has men in the lobby again. Stay out of their sight, or cut the lights."])


def L02():
    m = Map(40, 26, 1)
    frame(m)
    m.fill(0, 1, 1, 38, 24, "b")
    m.fill(0, 1, 11, 38, 12, " ")
    m.fill(0, 1, 4, 38, 4, " ")
    m.fill(0, 8, 1, 9, 10, " ")
    m.fill(0, 20, 1, 21, 24, " ")
    m.fill(0, 31, 1, 32, 10, " ")
    m.fill(0, 1, 19, 21, 20, " ")
    m.fill(0, 8, 19, 9, 24, " ")
    # tea stall yard
    m.fill(0, 11, 13, 18, 17, ",")
    m.many(0, "k", [(12, 14), (17, 14)])
    m.many(0, "n", [(12, 16), (14, 16)])
    m.put(0, 14, 14, "1")
    m.put(0, 16, 16, "2")
    # checkpoint across the lane
    m.many(0, "G", [(20, 14), (21, 14)])
    m.put(0, 21, 13, "3")
    # safehouse
    m.room(0, 22, 16, 29, 22)
    m.many(0, "G", [(22, 19), (22, 20)])
    m.put(0, 21, 18, "4")
    m.put(0, 26, 18, "5")
    m.many(0, "x", [(28, 21), (27, 21)])
    m.put(0, 24, 21, "t")
    # rickshaw at the south-west lane end; the ride goes to the yard by the bus road
    m.put(0, 8, 23, "6")
    m.put(0, 9, 23, "r")
    m.fill(0, 34, 21, 37, 23, " ")
    m.put(0, 35, 22, "E")
    # people and the syndicate
    m.put(0, 2, 11, "@")
    m.many(0, "X", [(25, 11), (14, 4)])
    m.many(0, "Y", [(20, 8), (33, 11)])
    m.many(0, "P", [(5, 11), (29, 11), (20, 6), (9, 4), (36, 4), (31, 8)])
    m.many(0, "C", [(5, 4), (27, 4), (12, 12), (37, 12)])
    m.many(0, "l", [(3, 4), (24, 4)])
    legend = {
        "1": {"type": "gatekeeper", "name": "Babul's tea board", "gate": "L02_teaboard", "look": "shopkeeper",
              "intro": "Babul taps the chalk board: one question a day, ৳100 if you get it. Miss it and you buy the tea."},
        "2": {"type": "career", "person": "Mitu", "lines": ["Bhai, you're the one who sits every exam, aren't you?"]},
        "3": {"type": "gatekeeper", "name": "Checkpoint boss", "gate": "L02_checkpoint", "look": "goon",
              "intro": "This lane is ours today. You want through, you answer like a candidate."},
        "4": {"type": "gatekeeper", "name": "Safehouse auntie", "gate": "L02_safehouse",
              "intro": "If you're really a student you'll know your Bangla. Five questions, then the door."},
        "5": {"type": "pickup", "key": "supplies", "label": "Take the medical kit and the map", "give": {"medical": 2, "ammo": 12},
              "toast": "Two bandages, a box of rounds, and a hand-drawn map of the lanes."},
        "6": {"type": "driver", "name": "Rickshaw puller", "gate": "L02_rickshaw", "key": "rickshaw", "to": "E", "minutes": 20,
              "text": "The rickshaw rattles out of the lanes onto the bus road."},
    }
    objectives = [
        {"type": "gate", "gate": "L02_teaboard", "text": "Try the question board at Babul's tea stall"},
        {"type": "talk", "person": "Mitu", "text": "Talk to Mitu at the tea stall"},
        {"type": "gate", "gate": "L02_checkpoint", "text": "Get through the syndicate checkpoint south of the main lane"},
        {"type": "gate", "gate": "L02_safehouse", "text": "Get into the safehouse"},
        {"type": "pickup", "key": "supplies", "text": "Take the supplies"},
        {"type": "ride", "key": "rickshaw", "text": "Take the rickshaw out of the lanes"},
    ]
    gates = {
        "L02_teaboard": gate("Babul", size=1, sets=("P6",), pass_points=1.0, category="board", depth=0, no_bribe=True,
                             story_gate=True, level_on_pass=["resource:taka:100"]),
        "L02_checkpoint": gate("checkpoint boss", opens=gate_key(m, 0, 20, 14), bribe=250),
        "L02_safehouse": gate("safehouse auntie", sets=("SP",), opens=gate_key(m, 0, 22, 19), no_bribe=True),
        "L02_rickshaw": file_gate("L02_rickshaw"),
    }
    return lvl(2, "The lanes", "Chapter 1 · Jurain", "The road to the college is watched, so Sakib cuts through the Jurain lanes: a tea stall, a syndicate checkpoint and a safehouse that only opens for people who know their Bangla.",
               m, legend, objectives, gates, start_hour=10.0, palette="street", sector="lanes_school_rd", crowd=35,
               last_wish_cap=1, lw_share=0.35, player_yaw=-90)


def L03():
    m = Map(44, 26, 1)
    frame(m)
    m.fill(0, 1, 1, 42, 1, "b")
    m.fill(0, 1, 2, 42, 7, ",")
    m.fill(0, 1, 8, 42, 8, "#")
    m.many(0, "G", [(21, 8), (22, 8)])
    for x in (8, 20, 32):
        m.put(0, x, 4, "u")
    m.put(0, 20, 6, "3")
    m.put(0, 33, 6, "5")
    m.many(0, "X", [(12, 6), (27, 3)])
    m.many(0, "P", [(4, 6), (16, 6), (28, 6), (39, 6)])
    m.many(0, "n", [(14, 2), (26, 2)])
    street(m, 9, 1, 42)
    m.fill(0, 1, 11, 42, 12, "=")
    m.fill(0, 1, 13, 42, 13, "=")
    m.fill(0, 1, 14, 42, 14, "-")
    m.put(0, 20, 9, "2")
    m.put(0, 30, 14, "k")
    m.put(0, 31, 14, "1")
    m.many(0, "c", [(10, 11), (26, 12)])
    m.many(0, "r", [(16, 13), (36, 12)])
    m.many(0, "Y", [(14, 9), (36, 14)])
    m.many(0, "P", [(6, 9), (30, 9), (10, 14), (40, 9)])
    # south side: shops, a CNG stand, and the road out (reached only by CNG)
    m.fill(0, 1, 15, 42, 24, "b")
    m.fill(0, 1, 15, 30, 16, " ")
    m.fill(0, 2, 17, 5, 20, ",")
    m.put(0, 3, 18, "6")
    m.put(0, 4, 19, "r")
    m.fill(0, 34, 19, 41, 23, " ")
    m.put(0, 38, 21, "E")
    m.put(0, 2, 9, "@")
    m.many(0, "C", [(8, 9), (25, 14), (18, 15), (40, 14)])
    legend = {
        "1": {"type": "gatekeeper", "name": "Pharmacist", "gate": "L03_pharmacy", "look": "shopkeeper",
              "intro": "Bandages and painkillers? Tell me what you're buying first. I don't sell to fools."},
        "2": {"type": "gatekeeper", "name": "Ticket counter man", "gate": "L03_ticket", "look": "guard",
              "intro": "Platform's closed to anyone without a ticket. Or a brain. Five questions."},
        "3": {"type": "career", "person": "Rasel", "lines": ["Oi, student bhai! You read a lot. Tell me something."]},
        "5": {"type": "task", "key": "tag", "label": "Slip the tracker under the courier bus", "noise": 40,
              "toast": "The tracker clicks onto the chassis. Shirin's friends can follow the bus now."},
        "6": {"type": "driver", "name": "CNG driver", "gate": "L03_cng", "key": "cng", "to": "E", "minutes": 25,
              "text": "The CNG weaves through the traffic and drops you by the college road."},
    }
    objectives = [
        {"type": "gate", "gate": "L03_pharmacy", "text": "Buy bandages at the pharmacy kiosk on the south pavement"},
        {"type": "gate", "gate": "L03_ticket", "text": "Get onto the bus platform past the ticket counter"},
        {"type": "talk", "person": "Rasel", "text": "Talk to Rasel, the conductor's helper"},
        {"type": "task", "key": "tag", "text": "Put a tracker on the courier bus (the east bay)"},
        {"type": "ride", "key": "cng", "text": "Take a CNG from the stand on the south side"},
    ]
    gates = {
        "L03_pharmacy": gate("pharmacist", sets=("MAT-MED",), category="purchase", level_on_pass=["resource:medical:2"]),
        "L03_ticket": gate("ticket counter man", opens=gate_key(m, 0, 21, 8), bribe=200),
        "L03_cng": gate("CNG driver", category="ride", compose=[(("VEH-CNG",), 3), (("RS",), 2)]),
    }
    return lvl(3, "Kajla bus station", "Chapter 1 · The highway", "The question papers travel by bus. Sakib needs a tracker on the courier bus at Kajla, and a CNG out before the syndicate's men work out who he is.",
               m, legend, objectives, gates, start_hour=11.5, palette="street", sector="kajla_bus_station", crowd=60,
               last_wish_cap=2, lw_share=0.35, player_yaw=-90)


def L04():
    m = Map(44, 30, 1)
    frame(m)
    m.room(0, 2, 2, 41, 27, inside=",")
    m.fill(0, 21, 27, 22, 27, " ")
    m.fill(0, 1, 28, 42, 28, "-")
    # admin building with the record room
    m.room(0, 4, 4, 16, 12)
    m.put(0, 10, 12, "D")
    m.fill(0, 9, 4, 9, 12, "#")
    m.put(0, 9, 8, "G")
    m.put(0, 6, 8, "5")
    m.many(0, "t", [(6, 6), (7, 10)])
    m.put(0, 12, 7, "4")
    m.many(0, "t", [(13, 6)])
    m.many(0, "p", [(15, 5), (15, 11)])
    # library against the east wall, back door to the street outside
    m.room(0, 30, 4, 41, 12)
    m.put(0, 35, 12, "D")
    m.put(0, 41, 8, "G")
    m.put(0, 37, 8, "6")
    m.many(0, "t", [(32, 6), (32, 9), (34, 6), (34, 9)])
    m.fill(0, 42, 1, 42, 27, " ")
    m.put(0, 42, 10, "E")
    # the field and the Shaheed Minar
    m.put(0, 21, 8, "h")
    m.put(0, 21, 10, "3")
    m.many(0, "T", [(5, 16), (10, 22), (34, 17), (38, 23), (26, 15)])
    m.many(0, "n", [(16, 15), (27, 20)])
    m.many(0, "7", [(20, 25), (23, 25)])
    m.many(0, "C", [(18, 12), (24, 13), (14, 20), (30, 22)])
    m.put(0, 22, 26, "@")
    m.many(0, "P", [(12, 18), (30, 18), (21, 21)])
    legend = {
        "3": {"type": "career", "person": "Nusrat", "lines": ["You're the one who keeps failing BCS on purpose, aren't you? Joking. Sit."]},
        "4": {"type": "gatekeeper", "name": "Principal", "gate": "L04_principal", "look": "teacher",
              "intro": "The record room? For a former student of this college... ten questions. Seven right."},
        "5": {"type": "pickup", "key": "ledger", "label": "Take the admissions ledger",
              "toast": "The ledger: forty admit cards issued to names nobody has seen in class."},
        "6": {"type": "gatekeeper", "name": "Librarian", "gate": "L04_librarian", "look": "teacher",
              "intro": "The back door is for readers. Prove you are one."},
        "7": {"type": "spot"},
    }
    objectives = [
        {"type": "talk", "person": "Nusrat", "text": "Find Nusrat at the Shaheed Minar"},
        {"type": "survive", "seconds": 45, "text": "The syndicate's boys storm the meeting: hold out",
         "waves": [{"at": 0, "marker": "7", "role": "goon", "count": 3, "text": "Goons pour in through the main gate."},
                   {"at": 18, "marker": "7", "role": "gunman", "count": 2, "text": "Two of them are armed."}]},
        {"type": "gate", "gate": "L04_principal", "text": "Get the principal to open the record room"},
        {"type": "pickup", "key": "ledger", "text": "Take the admissions ledger from the record room"},
        {"type": "gate", "gate": "L04_librarian", "text": "Get the librarian to open the library's back door"},
        {"type": "reach", "marker": "E", "text": "Leave by the library's back door"},
    ]
    record = gate_key(m, 0, 9, 8)
    gates = {
        "L04_principal": file_gate("L04_principal", opens=record),
        "L04_librarian": gate("librarian", sets=("SP",), opens=gate_key(m, 0, 41, 8)),
    }
    return lvl(4, "Dania College", "Chapter 1 · Dania College", "Nusrat is calling a students' meeting at the Shaheed Minar about the fake admit cards. The proof is in the admissions ledger, locked in the principal's record room.",
               m, legend, objectives, gates, start_hour=12.0, palette="green", sector="dania_college", crowd=0,
               last_wish_cap=2, lw_share=0.35, player_yaw=0, aliases={"record_room": record})


def L05():
    m = Map(38, 24, 4)
    frame(m)
    tower(m, 4, False)
    compound_and_street(m, False)
    m.put(0, 3, 5, "G")
    m.put(0, 4, 6, "5")
    m.put(0, 14, 9, "3")
    m.many(0, "Y", [(10, 9), (19, 11)])
    m.many(0, "P", [(6, 10), (20, 8), (12, 11)])
    m.many(0, "m", [(21, 3), (22, 3)])
    m.put(0, 4, 15, "g")
    m.put(0, 5, 15, "4")
    m.put(0, 30, 7, "k")
    m.put(0, 30, 9, "1")
    m.put(0, 32, 8, "2")
    m.many(0, "x", [(28, 7), (28, 8)])
    for f, x in ((1, 10), (2, 15), (3, 6)):
        m.put(f, x, 6, "X")
        m.put(f, 4 if x > 12 else 20, 6, "P")
        m.put(f, 13, 6, "P")
    m.put(3, 12, 10, "9")
    m.put(0, 30, 19, "@")
    m.many(0, "C", [(8, 19), (26, 21), (33, 12)])
    m.many(0, "T", [(26, 3), (35, 14)])
    legend = {
        "1": {"type": "career", "person": "Habib", "lines": ["Batteries, bhai? Every load-shedding I sell out."]},
        "2": {"type": "gatekeeper", "name": "Habib's apprentice", "gate": "L05_battery",
              "intro": "Before I sell you anything with acid in it, tell me how it works."},
        "3": {"type": "callback", "person": "Tanvir",
              "grateful": ["utility:generator", "done:utility:generator", "utility:cctv", "reveal:30"],
              "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "4": {"type": "utility", "key": "generator", "label": "Pull the generator's fuel line", "utility": "generator"},
        "5": {"type": "gatekeeper", "name": "Doorman", "gate": "L05_doorman", "look": "doorman",
              "intro": "The stairs are closed. Ten questions today, seven right. The syndicate pays me to be strict."},
        "9": {"type": "spot"},
    }
    objectives = [
        {"type": "talk", "person": "Habib", "text": "Talk to Habib at his battery stall"},
        {"type": "gate", "gate": "L05_battery", "text": "Buy batteries for your phone (the notebook's lookouts need them)"},
        {"type": "talk", "person": "Tanvir", "text": "Find Tanvir in the Tower lobby"},
        {"type": "utility", "key": "generator", "text": "Sabotage the generator in the compound: the lift and the lights die"},
        {"type": "gate", "gate": "L05_doorman", "text": "Get the doorman to unlock the stairs"},
        {"type": "reach", "marker": "9", "text": "Climb to the fourth floor corridor"},
    ]
    gates = {
        "L05_battery": gate("Habib's apprentice", sets=("MAT-BAT",), category="purchase", level_on_pass=["resource:batteries:2"]),
        "L05_doorman": gate("doorman", size=10, opens=gate_key(m, 0, 3, 5), bribe=500),
    }
    return lvl(5, "Load-shedding", "Chapter 2 · The Tower", "The syndicate runs its paper operation from the Tower's upper floors. The mains are off, the generator keeps their lift and lights going, and the doorman keeps the stairs.",
               m, legend, objectives, gates, start_hour=13.0, palette="tower", sector="tower_street", crowd=35,
               last_wish_cap=2, lw_share=0.35, player_yaw=90, on_start=["utility:power"])


def L06():
    m = Map(38, 24, 5)
    frame(m)
    tower(m, 5, False)
    compound_and_street(m, False)
    gx, gy = core_door(3)
    m.put(3, gx, gy, "G")
    m.put(3, gx + 1, gy + 1, "2")
    m.put(3, 12, 6, "@")
    m.put(3, 12, 10, "1")
    m.put(3, 20, 9, "3")
    m.put(3, 17, 6, "Y")
    m.many(3, "P", [(15, 6), (21, 6)])
    m.put(4, 19, 7, "G")
    m.put(4, 18, 6, "5")
    m.put(4, 5, 10, "4")
    m.many(4, "X", [(18, 10), (21, 9), (20, 12)])
    m.many(4, "6", [(18, 12), (21, 11)])
    m.put(4, 12, 6, "9")
    m.put(4, 4, 6, "Y")
    m.many(4, "P", [(10, 6), (20, 6)])
    m.many(0, "Y", [(10, 9)])
    legend = {
        "1": {"type": "callback", "person": "Mitu", "grateful": ["reveal:45", "resource:medical:1"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "2": {"type": "gatekeeper", "name": "Stair guard", "gate": "L06_stairs", "look": "goon",
              "intro": "Fifth floor's closed. Five questions, or you take the lift... oh wait, there's no power."},
        "3": {"type": "gatekeeper", "name": "Night guard (sells diesel)", "gate": "L06_fuel", "look": "guard",
              "intro": "Diesel for the generator? I know my fuel. Do you?"},
        "4": {"type": "career", "person": "Rina Apa", "lines": ["Sakib! I taught you Bangla in class six. Sit, sit."]},
        "5": {"type": "gatekeeper", "name": "Rina Apa's old student", "gate": "L06_p1",
              "intro": "The family is behind this door, with their captors. If you're who Rina Apa says, you'll know these."},
        "6": {"type": "civilian", "name": "Hostage", "cower": True, "static": True},
        "9": {"type": "spot"},
    }
    objectives = [
        {"type": "talk", "person": "Mitu", "text": "Mitu is visiting Rina Apa's students on this floor: talk to her"},
        {"type": "reach", "marker": "9", "text": "Get to the fifth floor: answer the stair guard, or buy diesel so the lift runs"},
        {"type": "talk", "person": "Rina Apa", "text": "Find Rina Apa"},
        {"type": "gate", "gate": "L06_p1", "text": "Win the trust of the man guarding the hostages' door"},
        {"type": "eliminate", "tag": "captor", "count": 3, "text": "Free the family: take down the three captors"},
    ]
    gates = {
        "L06_stairs": gate("stair guard", opens=gate_key(m, 3, gx, gy), bribe=300),
        "L06_fuel": gate("night guard", sets=("MAT-FUEL",), category="purchase", level_on_pass=["restore:generator", "toast:The generator coughs back to life. The lift works."]),
        "L06_p1": gate("Rina Apa's old student", sets=("P1",), size=3, pass_points=2.0, opens=gate_key(m, 4, 19, 7), no_bribe=True),
    }
    return lvl(6, "The fifth floor", "Chapter 2 · The Tower", "A family on the fifth floor refused to store the syndicate's papers. Now they're hostages in their own flat.",
               m, legend, objectives, gates, start_hour=14.0, palette="tower", sector="tower_floor5", crowd=0,
               last_wish_cap=2, lw_share=0.35, player_yaw=0, marker_tags={"X": "captor"}, on_start=["utility:power", "utility:generator"])


def L07():
    m = Map(38, 24, 4)
    frame(m)
    top = tower(m, 3, True)
    compound_and_street(m, False)
    m.put(0, 3, 5, "G")
    m.put(0, 4, 6, "2")
    m.put(0, 18, 15, "1")
    m.put(0, 20, 15, "c")
    m.many(0, "Y", [(10, 9), (18, 9)])
    m.many(0, "P", [(5, 11), (20, 11), (12, 8)])
    m.put(1, 12, 10, "3")
    m.many(1, "x", [(10, 9), (14, 11), (13, 9)])
    m.put(1, 20, 10, "4")
    m.put(2, 5, 10, "4")
    m.put(2, 20, 3, "4")
    m.many(2, "x", [(18, 3), (19, 4), (4, 11)])
    m.put(1, 15, 6, "X")
    m.put(2, 6, 6, "X")
    m.many(1, "P", [(4, 6), (20, 6)])
    m.many(2, "P", [(12, 6), (21, 6)])
    rx, ry = core_door(top)
    m.put(top, rx, ry, "G")
    m.put(top, rx - 1, ry - 1, "5")
    m.put(2, 21, 12, "6")
    m.put(top, 15, 9, "9")
    m.many(top, "w", [(19, 4), (21, 4)])
    m.put(0, 6, 19, "@")
    m.many(0, "C", [(16, 19), (30, 21)])
    legend = {
        "1": {"type": "callback", "person": "Rasel", "grateful": ["reveal:45", "resource:ammo:12"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "2": {"type": "gatekeeper", "name": "Stair guard", "gate": "L07_stairs", "look": "goon",
              "intro": "Upstairs is packing day. Nobody goes up unless they can answer."},
        "3": {"type": "career", "person": "Sohel", "lines": ["Shh. I pack the papers for them. I hate it, bhai."]},
        "4": {"type": "pickup", "key": "paper", "label": "Take a bundle of leaked papers", "toast": "A bundle of tomorrow's question papers, still warm from the press."},
        "5": {"type": "gatekeeper", "name": "Roof watchman", "gate": "L07_roof", "look": "guard",
              "intro": "The roof is mine until six. Ten questions, seven right, and you can have it."},
        "6": {"type": "bypass", "key": "canopy", "label": "Climb out over the canopy to the roof (noisy)", "to": "9", "gate": "L07_roof", "noise": 66,
              "toast": "Tin sheets groan under you, then you're over the parapet."},
        "9": {"type": "spot"},
    }
    objectives = [
        {"type": "talk", "person": "Rasel", "text": "Rasel is parked in the compound: talk to him"},
        {"type": "gate", "gate": "L07_stairs", "text": "Get past the stair guard"},
        {"type": "talk", "person": "Sohel", "text": "Find Sohel among the paper packers on the first floor"},
        {"type": "pickup", "key": "paper", "count": 3, "text": "Steal the leaked paper stock"},
        {"type": "gate", "gate": "L07_roof", "text": "Get onto the roof before 17:30: answer the roof watchman, or climb the canopy from the second floor"},
        {"type": "reach", "marker": "9", "text": "Step out onto the roof"},
    ]
    gates = {
        "L07_stairs": gate("stair guard", opens=gate_key(m, 0, 3, 5), bribe=300),
        "L07_roof": gate("roof watchman", size=10, opens=gate_key(m, top, rx, ry), bribe=600),
    }
    return lvl(7, "Paper stock", "Chapter 2 · The Tower", "Tomorrow's papers are being packed on the Tower's upper floors. Steal enough to prove it, then get to the roof before the watchman locks it.",
               m, legend, objectives, gates, start_hour=15.0, palette="tower", sector="tower_floor7", crowd=25,
               last_wish_cap=2, lw_share=0.35, player_yaw=90, roof_floor=top, deadline_hour=17.5,
               deadline_text="Half past five: the watchman has locked the roof and the papers are gone.")


def L08():
    m = Map(46, 28, 4)
    frame(m)
    rf = 3
    tower(m, 3, True)
    m.fill(0, 2, 14, 2, 17, "#")
    m.fill(0, 23, 14, 23, 17, "#")
    m.fill(0, 2, 17, 23, 17, "#")
    m.fill(0, 12, 17, 13, 17, " ")
    street(m, 22, 1, 44)
    m.fill(0, 1, 26, 44, 26, "b")
    roof_block(m, 26, 2, 33, 9, rf)
    roof_block(m, 36, 2, 43, 9, rf)
    roof_block(m, 26, 12, 33, 19, rf)
    roof_block(m, 36, 12, 43, 19, rf)
    plank(m, rf, [(24, 6), (25, 6)], [(23, 6), (26, 6)])
    plank(m, rf, [(34, 5), (35, 5)], [(33, 5), (36, 5)])
    plank(m, rf, [(29, 10), (29, 11)], [(29, 9), (29, 12)])
    plank(m, rf, [(40, 10), (40, 11)], [(40, 9), (40, 12)])
    plank(m, rf, [(34, 16), (35, 16)], [(33, 16), (36, 16)])
    # the water-tank gate on roof B
    m.fill(rf, 39, 3, 39, 8, "#")
    m.many(rf, "G", [(39, 5), (39, 6)])
    m.put(rf, 38, 4, "5")
    # roof features
    m.put(rf, 14, 9, "1")
    m.put(rf, 30, 4, "2")
    m.many(rf, "p", [(28, 3), (31, 3), (28, 7)])
    m.many(rf, "3", [(31, 8), (30, 17), (37, 8)])
    m.put(rf, 39, 15, "4")
    m.put(rf, 41, 14, "z")
    m.many(rf, "w", [(41, 4), (27, 13)])
    m.put(rf, 28, 5, "l")
    m.put(rf, 42, 18, "7")
    m.many(rf, "Z", [(32, 13), (42, 13)])
    m.put(rf, 18, 10, "Y")
    m.many(rf, "P", [(6, 10), (20, 8), (14, 12)])
    m.put(rf, 27, 18, "X")
    m.many(rf, "P", [(31, 14), (28, 18)])
    m.put(rf, 12, 8, "@")
    m.fill(0, 44, 1, 44, 21, " ")
    m.put(0, 44, 20, "8")
    m.put(0, 40, 24, "E")
    m.many(0, "C", [(10, 23), (30, 25)])
    m.many(0, "Y", [(14, 9)])
    legend = {
        "1": {"type": "gatekeeper", "name": "Kite seller", "gate": "L08_kite",
              "intro": "A fighter kite for a grown man? Fine. But these lines cross live wires. Tell me you know what that means."},
        "2": {"type": "career", "person": "Farzana", "lines": ["Careful of my chillies. You look like you need advice more than I do. Or do I?"]},
        "3": {"type": "task", "key": "relay", "label": "Set up Shirin's signal relay", "toast": "The relay blinks green."},
        "4": {"type": "task", "key": "kite", "label": "Fly the red kite: the signal", "toast": "The red kite climbs over Jatrabari. Every roof that matters sees it."},
        "5": {"type": "gatekeeper", "name": "Water-tank man", "gate": "L08_tank",
              "intro": "This side of the roof is the syndicate's lookout. My tanks, my questions."},
        "7": {"type": "bypass", "key": "drainpipe", "label": "Slide down the drainpipe (noisy)", "to": "8", "noise": 60,
              "toast": "You hit the lane hard, but you're down."},
        "8": {"type": "spot"},
    }
    objectives = [
        {"type": "gate", "gate": "L08_kite", "text": "Buy a fighter kite from the kite seller on the Tower roof"},
        {"type": "talk", "person": "Farzana", "text": "Cross the plank and talk to Farzana in her roof garden"},
        {"type": "task", "key": "relay", "count": 3, "text": "Set up three signal relays across the roofs"},
        {"type": "gate", "gate": "L08_tank", "text": "Get past the water-tank man on the east roof"},
        {"type": "task", "key": "kite", "text": "Fly the kite from the far roof"},
        {"type": "reach", "marker": "E", "text": "Get down to the street: the Tower's roof door locks at 6 PM (or slide down the drainpipe)"},
    ]
    gates = {
        "L08_kite": gate("kite seller", sets=("LW-SHOCK",), category="purchase"),
        "L08_tank": gate("water-tank man", opens=gate_key(m, rf, 39, 5), bribe=300),
    }
    return lvl(8, "Kites over Jatrabari", "Chapter 3 · The roofs", "Shirin's network needs signal relays on the roofs and a kite in the sky. The roof doors lock at 6 PM, and after six the syndicate puts snipers on the water tanks.",
               m, legend, objectives, gates, start_hour=15.5, palette="street", sector="tower_roof", crowd=30, roof_rule=True,
               snipers_after_6=True, last_wish_cap=2, lw_share=0.35, player_yaw=-90, roof_floor=rf,
               legend_roof_door=True)


def L09():
    m = Map(40, 28, 1)
    frame(m)
    m.fill(0, 1, 1, 38, 1, "b")
    street(m, 2, 1, 38)
    m.room(0, 2, 6, 37, 25, inside=",")
    m.many(0, "G", [(19, 6), (20, 6)])
    m.put(0, 21, 5, "1")
    for y in range(8, 25, 2):
        for x in list(range(4, 17, 3)) + list(range(23, 36, 3)):
            if not (14 <= y <= 16):
                m.put(0, x, y, "+")
    m.many(0, "T", [(5, 15), (13, 15), (27, 15), (35, 15), (17, 21)])
    m.room(0, 30, 19, 36, 24)
    m.put(0, 30, 22, "D")
    m.put(0, 28, 22, "2")
    m.put(0, 12, 14, "3")
    m.many(0, "4", [(10, 15), (14, 16), (24, 14), (26, 16)])
    m.put(0, 25, 12, "5")
    m.fill(0, 19, 25, 20, 25, " ")
    m.put(0, 20, 26, "E")
    m.many(0, "Y", [(8, 10), (31, 9)])
    m.many(0, "P", [(19, 10), (19, 20), (8, 21), (31, 16)])
    m.put(0, 8, 3, "X")
    m.many(0, "P", [(16, 3), (30, 3)])
    m.put(0, 2, 3, "@")
    m.many(0, "C", [(12, 2), (34, 5)])
    legend = {
        "1": {"type": "gatekeeper", "name": "Caretaker", "gate": "L09_caretaker", "look": "imam",
              "intro": "A funeral today. I only let in people who know their faith from their facts."},
        "2": {"type": "career", "person": "Jahid", "lines": ["My father keeps these graves. I'm supposed to keep them after him."]},
        "3": {"type": "callback", "person": "Nusrat", "grateful": ["reveal:45", "tokens:1"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "4": {"type": "civilian", "name": "Mourner", "static": True},
        "5": {"type": "courier", "name": "Mourner in a white panjabi", "key": "papers", "look": "teacher",
              "found": "Under the panjabi: a sealed envelope of question papers."},
    }
    objectives = [
        {"type": "gate", "gate": "L09_caretaker", "text": "Get the caretaker to open the graveyard gate"},
        {"type": "talk", "person": "Jahid", "text": "Talk to Jahid by the caretaker's hut"},
        {"type": "talk", "person": "Nusrat", "text": "Nusrat is among the mourners: talk to her"},
        {"type": "search", "key": "papers", "text": "Find the courier hiding among the mourners and search him"},
        {"type": "reach", "marker": "E", "text": "Leave by the back gate"},
    ]
    gates = {"L09_caretaker": gate("caretaker", opens=gate_key(m, 0, 19, 6), no_bribe=True)}
    return lvl(9, "Jurain graveyard", "Chapter 3 · Jurain", "A courier is carrying papers through a funeral at the Jurain graveyard, hidden among the mourners.",
               m, legend, objectives, gates, start_hour=9.5, palette="green", sector="jurain_kabarsthan", crowd=0,
               last_wish_cap=2, lw_share=0.35, player_yaw=-90)


def L10():
    m = Map(44, 26, 1)
    frame(m)
    m.fill(0, 1, 1, 42, 10, "b")
    m.room(0, 4, 2, 21, 10, inside=",")
    m.room(0, 6, 2, 19, 6)
    m.many(0, "D", [(12, 6), (13, 6)])
    m.many(0, "n", [(9, 4), (16, 4)])
    m.put(0, 5, 8, "d")
    m.many(0, "G", [(12, 10), (13, 10)])
    street(m, 11, 1, 42)
    m.put(0, 14, 11, "1")
    m.fill(0, 1, 15, 42, 15, " ")
    m.fill(0, 1, 16, 42, 24, "b")
    m.room(0, 24, 16, 38, 23)
    m.put(0, 31, 16, "G")
    m.put(0, 32, 15, "4")
    m.many(0, "t", [(27, 18), (30, 18), (34, 18), (27, 21), (30, 21)])
    m.many(0, "X", [(26, 20), (33, 19), (36, 21)])
    m.many(0, "P", [(28, 17), (36, 18), (32, 22)])
    m.put(0, 28, 15, "2")
    m.put(0, 36, 11, "k")
    m.put(0, 37, 11, "3")
    m.many(0, "k", [(24, 11), (6, 14)])
    m.many(0, "c", [(20, 13), (33, 12)])
    m.many(0, "r", [(9, 13), (27, 12)])
    m.many(0, "Y", [(22, 11), (8, 14)])
    m.many(0, "P", [(4, 11), (30, 14), (40, 11)])
    m.many(0, "C", [(16, 14), (25, 14), (39, 14), (10, 11)])
    m.put(0, 2, 13, "@")
    legend = {
        "1": {"type": "gatekeeper", "name": "Imam", "gate": "L10_imam", "look": "imam",
              "intro": "Climb my minaret to spy on a madrasa? Ten questions first. Seven."},
        "2": {"type": "career", "person": "Kamal", "lines": ["I teach the boys their letters and their prayers. Is that enough, these days?"]},
        "3": {"type": "callback", "person": "Habib", "grateful": ["resource:batteries:2", "reveal:30"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "4": {"type": "gatekeeper", "name": "Madrasa principal", "gate": "L10_madrasa", "look": "imam",
              "intro": "Strangers in my madrasa during lessons? Show me you've studied."},
    }
    objectives = [
        {"type": "talk", "person": "Kamal", "text": "Talk to Kamal outside the madrasa"},
        {"type": "talk", "person": "Habib", "text": "Habib is selling batteries on Masjid Road: talk to him"},
        {"type": "gate", "gate": "L10_imam", "text": "Ask the imam to let you up the minaret (you'll see the madrasa yard)"},
        {"type": "gate", "gate": "L10_madrasa", "text": "Get the madrasa principal to open the door"},
        {"type": "eliminate", "tag": "saboteur", "count": 3, "text": "Stop the three saboteurs cutting the loudspeaker line"},
    ]
    gates = {
        "L10_imam": gate("imam", size=10, opens=gate_key(m, 0, 12, 10), no_bribe=True, level_on_pass=["reveal:60", "toast:From the minaret you can see every man in the madrasa yard."]),
        "L10_madrasa": gate("madrasa principal", sets=("SP",), opens=gate_key(m, 0, 31, 16), no_bribe=True),
    }
    return lvl(10, "Masjid Road", "Chapter 3 · Masjid Road", "Before Zuhr the syndicate will cut the minaret's loudspeaker line, so nobody can call the neighbourhood out when the papers move.",
               m, legend, objectives, gates, start_hour=11.0, palette="street", sector="masjid_rd", crowd=55,
               last_wish_cap=2, lw_share=0.35, player_yaw=-90, marker_tags={"X": "saboteur"})


def L11():
    m = Map(44, 30, 1)
    frame(m)
    m.fill(0, 1, 1, 42, 15, "b")
    m.room(0, 2, 2, 22, 14, inside=",")
    m.room(0, 4, 3, 20, 8)
    m.many(0, "D", [(8, 8), (16, 8)])
    m.many(0, "t", [(6, 5), (9, 5), (12, 5), (15, 5), (18, 5)])
    m.room(0, 4, 10, 10, 13)
    m.put(0, 10, 11, "G")
    m.put(0, 11, 12, "2")
    m.put(0, 6, 12, "5")
    m.many(0, "G", [(12, 14), (13, 14)])
    m.fill(0, 1, 15, 42, 15, " ")
    m.put(0, 14, 15, "1")
    street(m, 16, 1, 42)
    m.put(0, 26, 17, "3")
    m.put(0, 30, 16, "4")
    m.many(0, "6", [(24, 17), (25, 18), (27, 18), (28, 17), (31, 16), (29, 16)])
    m.fill(0, 1, 20, 42, 28, " ")
    m.fill(0, 1, 26, 30, 28, "b")
    m.put(0, 36, 21, "u")
    m.put(0, 36, 23, "7")
    m.room(0, 34, 25, 42, 28, inside=",")
    m.fill(0, 34, 25, 36, 25, ",")
    m.put(0, 39, 26, "h")
    m.put(0, 39, 27, "9")
    m.many(0, "T", [(6, 22), (14, 24), (22, 21)])
    m.many(0, "X", [(10, 18), (33, 19), (20, 22), (38, 23)])
    m.many(0, "P", [(4, 17), (40, 18), (16, 22), (28, 23)])
    m.put(0, 2, 18, "@")
    legend = {
        "1": {"type": "gatekeeper", "name": "Headmaster", "gate": "L11_headmaster", "look": "teacher",
              "intro": "School's closed for the procession. Ten questions and I'll believe you're a teacher."},
        "2": {"type": "gatekeeper", "name": "Bangla teacher", "gate": "L11_bangla", "look": "teacher",
              "intro": "The storeroom? Recite me your literature first."},
        "3": {"type": "career", "person": "Shirin", "lines": ["I'm writing about the leak. Will anyone print it?"]},
        "4": {"type": "callback", "person": "Rina Apa", "grateful": ["calm", "reveal:45"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "5": {"type": "task", "key": "sleep", "label": "Sleep in the storeroom until dawn", "skip_to": 5.5,
              "toast": "You wake to the azan. It is the morning of the 21st."},
        "6": {"type": "civilian", "name": "Marcher", "static": True},
        "7": {"type": "task", "key": "soundtruck", "label": "Pull the plug on the syndicate's sound truck", "noise": 50,
              "toast": "The truck's speakers die mid-slogan."},
        "9": {"type": "spot"},
    }
    objectives = [
        {"type": "talk", "person": "Shirin", "text": "Talk to Shirin in the procession"},
        {"type": "talk", "person": "Rina Apa", "text": "Rina Apa is walking with her study circle: talk to her"},
        {"type": "gate", "gate": "L11_headmaster", "text": "Get the headmaster to let you into the school"},
        {"type": "gate", "gate": "L11_bangla", "text": "Get the Bangla teacher to open the storeroom"},
        {"type": "task", "key": "sleep", "text": "Hide in the storeroom until dawn"},
        {"type": "task", "key": "soundtruck", "text": "Silence the syndicate's sound truck"},
        {"type": "eliminate", "tag": "attacker", "count": 4, "text": "Stop the men sent to break up the dawn march"},
        {"type": "reach", "marker": "9", "text": "Reach the Shaheed Minar"},
    ]
    gates = {
        "L11_headmaster": gate("headmaster", size=10, opens=gate_key(m, 0, 12, 14), bribe=500),
        "L11_bangla": gate("Bangla teacher", sets=("SP",), opens=gate_key(m, 0, 10, 11), no_bribe=True),
    }
    return lvl(11, "Before dawn", "Chapter 4 · Shonir Akhra", "Tomorrow at dawn the neighbourhood marches to the Shaheed Minar. Tonight the syndicate plans to break it up. Sakib has to be there first.",
               m, legend, objectives, gates, start_hour=14.0, palette="street", sector="shonir_akhra", crowd=45,
               last_wish_cap=2, lw_share=0.35, player_yaw=-90, marker_tags={"X": "attacker"})


def L12():
    m = Map(40, 26, 1)
    frame(m)
    m.fill(0, 1, 1, 38, 2, "b")
    m.room(0, 4, 3, 35, 19)
    m.put(0, 19, 19, "D")
    m.fill(0, 4, 13, 35, 13, "#")
    m.many(0, "G", [(19, 13), (20, 13)])
    m.put(0, 21, 14, "1")
    m.many(0, "n", [(7, 16), (10, 16), (28, 16), (31, 16)])
    m.put(0, 8, 15, "2")
    m.many(0, "p", [(5, 18), (34, 18)])
    m.room(0, 5, 3, 13, 9)
    m.put(0, 9, 9, "D")
    m.put(0, 8, 6, "5")
    m.put(0, 11, 5, "t")
    m.room(0, 14, 3, 24, 9)
    m.put(0, 19, 9, "D")
    m.room(0, 26, 3, 35, 9)
    m.put(0, 26, 6, "G")
    m.put(0, 31, 6, "4")
    m.many(0, "x", [(33, 4), (33, 8), (29, 4)])
    m.put(0, 25, 7, "6")
    m.put(0, 28, 7, "7")
    m.many(0, "t", [(16, 5), (19, 5), (22, 5), (16, 7), (19, 7)])
    m.put(0, 20, 11, "3")
    m.put(0, 35, 11, "D")
    m.fill(0, 36, 3, 38, 24, " ")
    m.put(0, 37, 11, "E")
    m.many(0, "X", [(10, 11), (30, 11), (24, 12)])
    m.many(0, "P", [(6, 11), (14, 11), (33, 11)])
    m.put(0, 26, 15, "Y")
    m.many(0, "P", [(14, 16), (30, 17)])
    street(m, 20, 1, 35)
    m.put(0, 5, 21, "@")
    m.many(0, "C", [(12, 20), (28, 23)])
    legend = {
        "1": {"type": "gatekeeper", "name": "Receptionist", "gate": "L12_reception",
              "intro": "Shortcut Coaching, guaranteed results! Enrolment test: five questions."},
        "2": {"type": "career", "person": "Arif", "lines": ["I paid them for the leak, bhai. Forty thousand. Was I stupid?"]},
        "3": {"type": "callback", "person": "Sohel", "grateful": ["open:server", "toast:Sohel slips you the server-room key."],
              "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "4": {"type": "pickup", "key": "server", "label": "Pull the drive from the leak server", "toast": "The drive with every leaked paper and every buyer's name."},
        "5": {"type": "boss", "name": "Kibria", "gate": "L12_kibria", "look": "boss",
              "intro": "Kibria smiles. 'A candidate! Let's see what the honest way taught you. Ten questions, and two are law.'"},
        "6": {"type": "bypass", "key": "lockpick", "label": "Force the server-room lock (loud)", "to": "7", "noise": 72,
              "toast": "The lock gives with a crack that echoes down the corridor."},
        "7": {"type": "spot"},
    }
    objectives = [
        {"type": "talk", "person": "Arif", "text": "Talk to Arif in the waiting area"},
        {"type": "gate", "gate": "L12_reception", "text": "Get past the receptionist"},
        {"type": "talk", "person": "Sohel", "text": "Sohel guards the corridor now: talk to him"},
        {"type": "pickup", "key": "server", "text": "Take the drive from the server room"},
        {"type": "gate", "gate": "L12_kibria", "text": "Face Kibria in his office"},
        {"type": "reach", "marker": "E", "text": "Out by the fire escape"},
    ]
    server = gate_key(m, 0, 26, 6)
    gates = {
        "L12_reception": gate("receptionist", opens=gate_key(m, 0, 19, 13), bribe=400),
        "L12_kibria": gate("Kibria", size=10, compose=[(("G",), 8), (("BAR",), 2)], category="duel", no_bribe=True, story_gate=True),
    }
    return lvl(12, "Shortcut Coaching", "Chapter 4 · Kajla Road", "Kibria's coaching centre sells the leak with a money-back guarantee. The server holds every buyer's name.",
               m, legend, objectives, gates, start_hour=16.0, palette="street", sector="kajla_rd", crowd=20,
               last_wish_cap=2, lw_share=0.35, player_yaw=0, aliases={"server": server})


def L13():
    m = Map(48, 26, 1)
    frame(m)
    m.fill(0, 1, 1, 46, 1, "b")
    m.fill(0, 1, 2, 46, 8, ",")
    m.fill(0, 22, 2, 46, 7, "b")
    m.many(0, "m", [(8, 4), (12, 4), (16, 4)])
    m.put(0, 6, 7, "k")
    m.put(0, 10, 6, "1")
    m.put(0, 15, 6, "2")
    m.put(0, 16, 7, "r")
    street(m, 9, 1, 46)
    m.fill(0, 1, 11, 46, 13, "=")
    m.fill(0, 1, 13, 46, 13, "=")
    m.fill(0, 1, 14, 46, 14, "-")
    m.put(0, 30, 8, "5")
    m.fill(0, 1, 15, 46, 24, "b")
    m.fill(0, 1, 15, 32, 16, " ")
    m.put(0, 6, 16, "c")
    m.put(0, 8, 15, "3")
    m.put(0, 22, 15, "k")
    m.put(0, 23, 16, "4")
    m.fill(0, 36, 17, 45, 23, " ")
    m.put(0, 40, 19, "u")
    m.put(0, 44, 22, "6")
    m.put(0, 37, 22, "8")
    m.many(0, "X", [(37, 18), (44, 18), (41, 22)])
    m.many(0, "P", [(39, 21), (43, 20)])
    m.many(0, "Y", [(18, 9), (34, 14)])
    m.many(0, "P", [(6, 9), (28, 14), (42, 9)])
    m.many(0, "c", [(12, 12), (36, 11)])
    m.put(0, 26, 13, "r")
    m.put(0, 2, 10, "@")
    m.many(0, "C", [(20, 14), (12, 9)])
    legend = {
        "1": {"type": "gatekeeper", "name": "Pump attendant", "gate": "L13_fuel", "look": "guard",
              "intro": "Fuel at dawn? First tell me you won't blow us all up."},
        "2": {"type": "career", "person": "Babu", "lines": ["My CNG eats half of what I earn. The other half goes to the owner."]},
        "3": {"type": "callback", "person": "Jahid", "grateful": ["reveal:60"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "4": {"type": "callback", "person": "Mitu", "grateful": ["reveal:45", "resource:medical:1"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "5": {"type": "driver", "name": "Motorbike rider", "gate": "L13_bike", "key": "bike", "to": "8", "minutes": 15,
              "text": "The bike screams down the N1 and cuts off the paper van in the service yard."},
        "6": {"type": "pickup", "key": "papers", "label": "Take the boxes of papers from the van", "toast": "Six sealed boxes. Tomorrow's exam, every subject."},
        "8": {"type": "spot"},
    }
    objectives = [
        {"type": "gate", "gate": "L13_fuel", "text": "Buy fuel from the pump attendant"},
        {"type": "talk", "person": "Babu", "text": "Talk to Babu by his CNG"},
        {"type": "talk", "person": "Jahid", "text": "Jahid has parked the graveyard pickup on the south side: talk to him"},
        {"type": "talk", "person": "Mitu", "text": "Mitu is at the tea stall: talk to her"},
        {"type": "ride", "key": "bike", "text": "Catch the paper van: ride with the motorbike rider"},
        {"type": "eliminate", "tag": "van", "count": 3, "text": "Take down the van crew"},
        {"type": "pickup", "key": "papers", "text": "Seize the papers"},
    ]
    gates = {
        "L13_fuel": gate("pump attendant", sets=("MAT-FUEL",), category="purchase"),
        "L13_bike": gate("motorbike rider", category="ride", compose=[(("VEH-MOTORBIKE",), 3), (("RS",), 2)], no_bribe=True),
    }
    return lvl(13, "The paper van", "Chapter 4 · The N1", "At dawn the papers leave Jatrabari in a white van. Sakib has one chance on the highway.",
               m, legend, objectives, gates, start_hour=6.0, palette="street", sector="n1_frontage", crowd=30,
               last_wish_cap=2, lw_share=0.35, player_yaw=-90, marker_tags={"X": "van"})


def L14():
    m = Map(40, 26, 1)
    frame(m)
    m.fill(0, 1, 1, 38, 2, "b")
    m.room(0, 3, 3, 36, 20)
    m.fill(0, 3, 15, 36, 15, "#")
    m.many(0, "G", [(19, 15), (20, 15)])
    m.put(0, 21, 16, "2")
    for y in range(6, 14, 2):
        for x in range(6, 34, 3):
            m.put(0, x, y, "t")
    m.put(0, 13, 7, "3")
    m.put(0, 25, 11, "4")
    m.many(0, "6", [(7, 7), (10, 9), (16, 7), (19, 11), (22, 9), (28, 7), (31, 11), (10, 13)])
    m.room(0, 29, 16, 36, 20)
    m.put(0, 29, 18, "D")
    m.put(0, 33, 18, "1")
    m.put(0, 19, 20, "D")
    m.put(0, 36, 8, "D")
    m.fill(0, 37, 3, 38, 22, " ")
    m.put(0, 38, 8, "E")
    m.put(0, 34, 5, "X")
    m.many(0, "P", [(5, 5), (34, 13)])
    m.many(0, "Y", [(10, 18), (26, 22)])
    m.many(0, "P", [(6, 17), (24, 18), (12, 23), (32, 23)])
    m.put(0, 5, 23, "@")
    m.many(0, "C", [(15, 22), (22, 23)])
    legend = {
        "1": {"type": "callback", "person": "Farzana", "grateful": ["tokens:1", "toast:Farzana signs you in as a first-aid volunteer."],
              "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "2": {"type": "gatekeeper", "name": "Invigilator", "gate": "L14_invigilator", "look": "teacher",
              "intro": "Candidate? Then you won't mind a little warm-up. Twenty seconds a question."},
        "3": {"type": "career", "person": "Lipi", "sit": True, "lines": ["(whispering) The boy at the back has the answers. Everyone knows."]},
        "4": {"type": "courier", "name": "Candidate at the back", "key": "leak", "sit": True, "static": True,
              "found": "In his pencil box: the answer key for today's paper."},
        "6": {"type": "civilian", "name": "Candidate", "sit": True, "static": True},
    }
    objectives = [
        {"type": "talk", "person": "Farzana", "text": "Farzana is on first-aid duty: talk to her"},
        {"type": "gate", "gate": "L14_invigilator", "text": "Get into the exam hall past the invigilator"},
        {"type": "talk", "person": "Lipi", "text": "Talk to Lipi at her desk"},
        {"type": "search", "key": "leak", "text": "Find the candidate with the leak and take it"},
        {"type": "reach", "marker": "E", "text": "Out by the hall's side door"},
    ]
    gates = {"L14_invigilator": file_gate("L14_invigilator", opens=gate_key(m, 0, 19, 15))}
    return lvl(14, "The exam hall", "Chapter 5 · Dania College", "The leaked papers are already inside the exam hall. Someone at the back has the answer key.",
               m, legend, objectives, gates, start_hour=9.0, palette="street", sector="dania_college_exam", crowd=0,
               last_wish_cap=1, lw_share=0.35, player_yaw=0)


def L15():
    m = Map(40, 28, 1)
    frame(m)
    m.fill(0, 1, 1, 38, 2, "b")
    m.room(0, 3, 3, 36, 23)
    m.fill(0, 3, 17, 36, 17, "#")
    m.many(0, "G", [(19, 17), (20, 17)])
    m.put(0, 21, 18, "1")
    m.many(0, "n", [(8, 20), (12, 20), (27, 20), (31, 20)])
    m.fill(0, 3, 13, 36, 13, "#")
    for x1, x2, door in ((3, 12, 8), (12, 20, 16), (20, 27, 24), (27, 36, 31)):
        m.fill(0, x1, 3, x1, 13, "#")
        m.fill(0, x2, 3, x2, 13, "#")
        m.put(0, door, 13, "D")
    m.put(0, 8, 8, "2")
    m.many(0, "t", [(6, 6), (10, 6)])
    m.put(0, 16, 8, "3")
    m.put(0, 24, 7, "4")
    m.many(0, "x", [(22, 5), (26, 5), (22, 10)])
    m.put(0, 31, 6, "5")
    m.many(0, "n", [(29, 9), (33, 9), (29, 11), (33, 11)])
    m.put(0, 19, 23, "D")
    m.put(0, 36, 15, "D")
    m.fill(0, 37, 3, 38, 26, " ")
    m.put(0, 38, 15, "E")
    m.many(0, "Y", [(10, 21), (28, 15)])
    m.put(0, 12, 15, "X")
    m.many(0, "P", [(6, 15), (33, 15), (5, 19), (34, 21)])
    m.put(0, 19, 25, "@")
    m.many(0, "C", [(14, 19), (25, 21), (10, 25)])
    legend = {
        "1": {"type": "gatekeeper", "name": "Court clerk", "gate": "L15_clerk", "look": "lawyer",
              "intro": "Everyone wants the inner corridor today. Five questions, or a fee."},
        "2": {"type": "career", "person": "Masud", "lines": ["Legal aid doesn't pay, bhai. But somebody has to do it."]},
        "3": {"type": "callback", "person": "Kamal", "grateful": ["tokens:1", "toast:Kamal will testify. In the trial, a study token strikes two wrong options."],
              "mixed": ["resource:ammo:6"], "bitter": ["pass_plus:L15_trial:1", "toast:Kamal gave false evidence. The trial's pass mark rises by one."]},
        "4": {"type": "pickup", "key": "recorder", "label": "Take the voice recorder from evidence", "toast": "Kibria's voice, naming prices for papers."},
        "5": {"type": "gatekeeper", "name": "Judge", "gate": "L15_trial", "look": "lawyer",
              "intro": "Rumi's bail hearing. Ten questions of law, thirty seconds each. Seven, and she walks."},
    }
    objectives = [
        {"type": "gate", "gate": "L15_clerk", "text": "Get the clerk to let you into the inner corridor"},
        {"type": "talk", "person": "Masud", "text": "Talk to Masud at the legal-aid office"},
        {"type": "talk", "person": "Kamal", "text": "Kamal is waiting to testify: talk to him"},
        {"type": "pickup", "key": "recorder", "text": "Take the recorder from the evidence room"},
        {"type": "gate", "gate": "L15_trial", "text": "Rumi's trial: argue it in front of the judge"},
        {"type": "reach", "marker": "E", "text": "Leave by the back door"},
    ]
    gates = {
        "L15_clerk": gate("court clerk", opens=gate_key(m, 0, 19, 17), bribe=300),
        "L15_trial": file_gate("L15_trial", story_gate=True, no_bribe=True),
    }
    return lvl(15, "Rumi's trial", "Chapter 5 · Jatrabari court", "Rumi, who printed the first story about the leak, is in the dock on a fake charge. Win the trial and she walks; lose and she's moved to the syndicate's armoury.",
               m, legend, objectives, gates, start_hour=10.5, palette="street", sector="jatrabari_legal_aid", crowd=0,
               last_wish_cap=1, lw_share=0.35, player_yaw=0)


def L16():
    m = Map(46, 28, 1)
    frame(m)
    m.fill(0, 1, 1, 44, 1, "b")
    m.fill(0, 1, 2, 44, 10, ",")
    m.fill(0, 30, 2, 44, 6, "b")
    m.fill(0, 1, 11, 44, 16, "W")
    m.many(0, "o", [(18, 11), (22, 11)])
    m.put(0, 10, 9, "1")
    m.put(0, 16, 8, "2")
    m.put(0, 20, 10, "3")
    m.many(0, "T", [(4, 5), (12, 4), (26, 3)])
    m.put(0, 8, 4, "k")
    m.put(0, 5, 8, "Y")
    m.many(0, "P", [(14, 6), (26, 9)])
    m.fill(0, 1, 17, 44, 26, ",")
    m.room(0, 24, 18, 42, 25, inside=",")
    m.many(0, "G", [(30, 18), (31, 18)])
    m.put(0, 32, 17, "4")
    m.room(0, 26, 20, 40, 24)
    m.put(0, 33, 20, "D")
    m.many(0, "g", [(29, 22), (36, 22)])
    m.many(0, "6", [(30, 23), (37, 23)])
    m.many(0, "x", [(27, 21), (39, 21)])
    m.many(0, "Y", [(28, 19), (39, 19)])
    m.many(0, "P", [(26, 19), (41, 23)])
    m.many(0, "X", [(16, 20), (36, 17)])
    m.many(0, "P", [(10, 21), (22, 19), (42, 17)])
    m.put(0, 12, 18, "8")
    m.put(0, 4, 24, "E")
    m.many(0, "T", [(8, 22), (18, 24)])
    m.put(0, 3, 3, "@")
    m.many(0, "C", [(9, 6), (22, 5), (14, 10)])
    legend = {
        "1": {"type": "career", "person": "Imran", "lines": ["Baba says the river is all I need. Is it?"]},
        "2": {"type": "callback", "person": "Shirin", "grateful": ["waive_gates:1", "toast:Shirin's story ran. The boatman reads it and waves you aboard."],
              "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "3": {"type": "driver", "name": "Boatman", "gate": "L16_boatman", "key": "boat", "to": "8", "minutes": 20,
              "text": "The boat noses across the brown water to the press bank."},
        "4": {"type": "gatekeeper", "name": "Press guard", "gate": "L16_pressguard", "look": "guard",
              "intro": "Delivery? Prove you can read what you're delivering."},
        "6": {"type": "task", "key": "press", "label": "Jam the press rollers", "noise": 58, "toast": "Grinding, then silence."},
        "8": {"type": "spot"},
    }
    objectives = [
        {"type": "talk", "person": "Imran", "text": "Talk to Imran at the ghat"},
        {"type": "talk", "person": "Shirin", "text": "Shirin is on the steps: talk to her"},
        {"type": "gate", "gate": "L16_boatman", "text": "Persuade the boatman to take you across"},
        {"type": "ride", "key": "boat", "text": "Cross the river"},
        {"type": "gate", "gate": "L16_pressguard", "text": "Get past the press guard"},
        {"type": "task", "key": "press", "count": 2, "text": "Jam both printing presses"},
        {"type": "reach", "marker": "E", "text": "Slip away along the south bank"},
    ]
    gates = {
        "L16_boatman": gate("boatman", size=10, compose=[(("VEH-BOAT",), 5), (("RS",), 2), (("G",), 3)], category="ride", no_bribe=True),
        "L16_pressguard": gate("press guard", opens=gate_key(m, 0, 30, 18), bribe=350),
    }
    return lvl(16, "The river press", "Chapter 6 · The Buriganga", "The syndicate prints its copies across the river. Imran's father owns the only boat that will go.",
               m, legend, objectives, gates, start_hour=13.5, palette="green", sector="river_ghat", crowd=25,
               last_wish_cap=2, lw_share=0.35, player_yaw=180)


def L17():
    m = Map(44, 28, 1)
    frame(m)
    m.fill(0, 1, 1, 42, 26, ",")
    for y in (5, 9, 13, 17, 21):
        for x in range(4, 41, 4):
            if not (x == 20 and y == 13):
                m.put(0, x, y, "k")
    m.many(0, "l", [(6, 3), (14, 3), (22, 3), (30, 3), (38, 3)])
    m.many(0, "z", [(10, 24), (30, 24)])
    m.many(0, "T", [(2, 12), (42, 8), (2, 24)])
    m.put(0, 20, 13, "x")
    m.put(0, 21, 13, "4")
    m.put(0, 13, 9, "1")
    m.put(0, 27, 18, "2")
    m.many(0, "3", [(9, 15), (34, 7)])
    m.many(0, "Y", [(18, 7), (30, 15), (10, 19)])
    m.put(0, 38, 23, "X")
    m.many(0, "P", [(6, 7), (26, 7), (38, 11), (14, 15), (34, 19), (22, 23)])
    m.many(0, "C", [(6, 11), (16, 11), (24, 15), (32, 11), (12, 23), (28, 23)])
    m.put(0, 42, 26, "E")
    m.put(0, 2, 2, "@")
    legend = {
        "1": {"type": "gatekeeper", "name": "Salt seller", "gate": "L17_salt", "look": "shopkeeper",
              "intro": "Iodised or not, babu? Know your salt before you buy it."},
        "2": {"type": "callback", "person": "Arif", "grateful": ["reveal:60", "calm"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "3": {"type": "courier", "name": "Mela courier", "key": "leak", "found": "A roll of answer sheets wrapped in a jilapi bag."},
        "4": {"type": "gatekeeper", "name": "Quiz-board man", "gate": "L17_board",
              "intro": "Mela quiz! Three questions, win a prize, lose your pride."},
    }
    objectives = [
        {"type": "talk", "person": "Arif", "text": "Find Arif at the mela"},
        {"type": "gate", "gate": "L17_salt", "text": "Buy salt from the salt seller (the cover story for your disguise)"},
        {"type": "search", "key": "leak", "count": 2, "text": "Find and search the two couriers in the crowd"},
        {"type": "gate", "gate": "L17_board", "text": "Win the quiz board at the centre stall"},
        {"type": "reach", "marker": "E", "text": "Leave by the south-east corner"},
    ]
    gates = {
        "L17_salt": gate("salt seller", sets=("MAT-SALT",), category="purchase"),
        "L17_board": gate("quiz-board man", size=3, sets=("P2",), pass_points=2.0, category="board", no_bribe=True, story_gate=True,
                          level_on_pass=["resource:taka:300", "tokens:1"]),
    }
    return lvl(17, "The mela", "Chapter 6 · Jatrabari mela", "The last copies of the leak move through the Pohela Falgun mela, hand to hand in the crowd.",
               m, legend, objectives, gates, start_hour=15.0, palette="street", sector="mela", crowd=140,
               last_wish_cap=2, lw_share=0.35, player_yaw=135)


def L18():
    m = Map(40, 26, 1)
    m.fill(0, 0, 0, 39, 25, "#")
    m.fill(0, 2, 15, 37, 16, ".")
    m.fill(0, 2, 18, 12, 23, ".")
    m.fill(0, 2, 17, 12, 17, ".")
    m.many(0, "c", [(4, 20), (10, 22)])
    m.put(0, 8, 20, "r")
    m.put(0, 6, 19, "1")
    m.put(0, 3, 22, "@")
    m.fill(0, 14, 18, 22, 23, ".")
    m.put(0, 18, 17, "D")
    m.many(0, "2", [(15, 20), (18, 22), (21, 20)])
    m.fill(0, 26, 3, 37, 12, ".")
    m.many(0, "G", [(31, 13), (32, 13)])
    m.fill(0, 31, 14, 33, 14, ".")
    m.put(0, 33, 14, "3")
    m.fill(0, 16, 3, 24, 12, ".")
    m.put(0, 20, 13, "D")
    m.put(0, 20, 14, ".")
    m.many(0, "y", [(23, 5), (23, 10)])
    m.put(0, 24, 8, "4")
    m.put(0, 27, 8, "5")
    m.put(0, 35, 5, "6")
    m.many(0, "x", [(29, 4), (29, 10), (34, 9), (36, 11)])
    m.fill(0, 26, 18, 37, 23, ".")
    m.put(0, 30, 17, "D")
    m.put(0, 36, 22, "E")
    m.many(0, "X", [(8, 15), (26, 16), (35, 15), (28, 6), (33, 10)])
    m.many(0, "P", [(4, 16), (16, 15), (36, 16), (31, 5), (27, 11)])
    m.many(0, "Y", [(10, 18), (30, 20)])
    m.many(0, "P", [(4, 18), (34, 22)])
    legend = {
        "1": {"type": "callback", "person": "Babu", "grateful": ["resource:ammo:24", "toast:Babu ran the armoury's stock out in his CNG last night. Take what's left."],
              "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "2": {"type": "captive", "name": "Armoury man (tied up)", "interrogate": True, "tag": "lt", "sit": True, "look": "goon",
              "intro": "Babu's drivers caught me. Ask, then. If you know your books, I'll tell you where the guns are."},
        "3": {"type": "gatekeeper", "name": "Armoury guard", "gate": "L18_armoury", "look": "goon",
              "intro": "Ten questions, seven right, and maybe I forget I saw you."},
        "4": {"type": "bypass", "key": "breach", "label": "Blow the side wall with the gas cylinder (very loud)", "to": "5", "gate": "L18_armoury", "noise": 95,
              "toast": "The wall comes down in a cloud of plaster. Everyone in the basement heard that."},
        "5": {"type": "spot"},
        "6": {"type": "captive", "name": "Rumi", "person": "Rumi", "female": True, "key": "Rumi", "if_flag": "rumi_moved_to_armoury",
              "line": "Sakib? I knew you'd lose that trial on purpose. Joking. Get me out."},
    }
    objectives = [
        {"type": "talk", "person": "Babu", "text": "Babu drove you in: talk to him in the garage"},
        {"type": "interrogate", "tag": "lt", "count": 3, "text": "Question the three armoury men tied up next door"},
        {"type": "gate", "gate": "L18_armoury", "text": "Get into the armoury: answer the guard, or blow the side wall"},
        {"type": "free", "key": "Rumi", "if_flag": "rumi_moved_to_armoury", "text": "Free Rumi"},
        {"type": "reach", "marker": "E", "text": "Out through the loading bay"},
    ]
    gates = {"L18_armoury": gate("armoury guard", size=10, opens=gate_key(m, 0, 31, 13), bribe=800)}
    return lvl(18, "The armoury", "Chapter 7 · Under Kajla", "The syndicate's guns are in a basement under the Kajla market. Every wounded man down here has something to confess.",
               m, legend, objectives, gates, start_hour=20.0, palette="night", sector="basement", crowd=0,
               last_wish_cap=4, lw_share=1.0, player_yaw=0)


def L19():
    m = Map(38, 24, 5)
    frame(m)
    compound_and_street(m, False)
    for f in range(4):
        m.fill(f, 2, 2, 23, 13, "#")
        m.fill(f, 3, 3, 22, 12, ".")
        m.fill(f, 2, 5, 23, 5, "#")
        m.many(f, "D", [(6, 5), (18, 5)])
    m.put(0, 12, 13, "D")
    rf = 4
    m.fill(rf, 2, 2, 23, 13, ",")
    parapet(m, rf, 2, 2, 23, 13)
    m.fill(rf, 14, 2, 21, 5, "#")
    m.fill(rf, 15, 3, 20, 4, ".")
    m.put(rf, 20, 5, ROOF_DOOR)
    ramp(m, 0, 4, 3, ">")
    ramp(m, 1, 16, 3, ">")
    ramp(m, 2, 4, 3, ">")
    ramp(m, 3, 16, 3, ">")
    for f, keeper, kx in ((1, "2", 11), (2, "3", 13), (3, "4", 11)):
        m.many(f, "G", [(12, 3), (12, 4)])
        m.put(f, kx, 4, keeper)
    # one hall door a floor, on the side you arrive, so the hall can't be used to walk round the guard
    m.put(1, 18, 5, "#")
    m.put(2, 6, 5, "#")
    m.put(3, 18, 5, "#")
    for f in range(1, 4):
        m.fill(f, 3, 9, 8, 9, "#")
        m.fill(f, 17, 9, 22, 9, "#")
        m.many(f, "x", [(10, 8), (14, 10), (20, 11)])
        m.put(f, 12, 8, "X")
        m.many(f, "P", [(5, 7), (20, 7), (12, 11)])
    m.put(0, 14, 9, "1")
    m.many(0, "Y", [(8, 10), (18, 8)])
    m.many(0, "P", [(5, 8), (20, 11), (12, 11)])
    m.put(rf, 12, 10, "5")
    m.many(rf, "X", [(6, 9), (18, 11)])
    m.many(rf, "P", [(5, 12), (21, 8), (11, 7)])
    m.many(rf, "w", [(5, 7), (8, 11)])
    m.put(0, 6, 19, "@")
    m.many(0, "C", [(20, 19), (30, 21)])
    legend = {
        "1": {"type": "callback", "person": "Lipi", "grateful": ["waive_gates:3"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "2": {"type": "gatekeeper", "name": "First-floor guard", "gate": "L19_f1", "look": "goon"},
        "3": {"type": "gatekeeper", "name": "Second-floor guard", "gate": "L19_f2", "look": "goon"},
        "4": {"type": "gatekeeper", "name": "Third-floor guard", "gate": "L19_f3", "look": "goon"},
        "5": {"type": "lieutenant", "name": "Shamim", "tag": "shamim", "static": True},
    }
    objectives = [
        {"type": "talk", "person": "Lipi", "text": "Lipi is waiting in the lobby: talk to her"},
        {"type": "gate", "gate": "L19_f1", "text": "Get past the first-floor guard"},
        {"type": "gate", "gate": "L19_f2", "text": "Get past the second-floor guard"},
        {"type": "gate", "gate": "L19_f3", "text": "Get past the third-floor guard"},
        {"type": "eliminate", "tag": "shamim", "count": 1, "text": "Take down Shamim, Kibria's lieutenant, on the roof"},
    ]
    gates = {
        "L19_f1": gate("first-floor guard", opens=gate_key(m, 1, 12, 3), bribe=400),
        "L19_f2": gate("second-floor guard", opens=gate_key(m, 2, 12, 3), bribe=400),
        "L19_f3": gate("third-floor guard", opens=gate_key(m, 3, 12, 3), bribe=400),
    }
    return lvl(19, "Top to bottom", "Chapter 7 · The Tower", "Shamim holds the Tower's roof with Kibria's last men. Every floor has a guard and the clock is running: by five the roof is his for good.",
               m, legend, objectives, gates, start_hour=14.5, palette="tower", sector="tower", crowd=30,
               last_wish_cap=3, lw_share=0.4, player_yaw=90, roof_floor=rf, deadline_hour=17.0,
               deadline_text="Five o'clock. Shamim's men have sealed the roof.")


def L20():
    m = Map(46, 28, 4)
    frame(m)
    rf = 3
    roof_block(m, 2, 2, 15, 11, rf)
    roof_block(m, 18, 2, 27, 9, rf)
    roof_block(m, 30, 2, 41, 9, rf)
    roof_block(m, 18, 13, 27, 22, rf)
    roof_block(m, 30, 13, 41, 22, rf)
    m.fill(0, 2, 14, 15, 22, "b")
    street(m, 23, 1, 44)
    plank(m, rf, [(16, 6), (17, 6)], [(15, 6), (18, 6)])
    plank(m, rf, [(28, 5), (29, 5)], [(27, 5), (30, 5)])
    plank(m, rf, [(22, 10), (22, 11), (22, 12)], [(22, 9), (22, 13)])
    plank(m, rf, [(35, 10), (35, 11), (35, 12)], [(35, 9), (35, 13)])
    plank(m, rf, [(28, 18), (29, 18)], [(27, 18), (30, 18)])
    m.put(rf, 6, 6, "@")
    m.put(rf, 10, 8, "1")
    m.many(rf, "8", [(4, 4), (5, 9), (13, 4)])
    m.put(rf, 24, 4, "2")
    m.put(rf, 20, 15, "9")
    m.many(rf, "Z", [(38, 4), (25, 20), (39, 20)])
    m.put(rf, 33, 16, "5")
    m.many(rf, "X", [(36, 15), (32, 20)])
    m.many(rf, "P", [(31, 14), (40, 17), (33, 21)])
    m.many(rf, "w", [(8, 3), (26, 3), (40, 3), (19, 21)])
    m.many(rf, "z", [(12, 10), (31, 8)])
    m.many(rf, "l", [(20, 7), (34, 6)])
    m.many(0, "C", [(10, 24), (25, 25), (40, 24)])
    legend = {
        "1": {"type": "callback", "person": "Masud", "grateful": ["ally:8:3", "reveal:60", "toast:Masud arrives with three honest police officers."],
              "mixed": ["resource:ammo:6"], "bitter": ["delay:20", "bitter"]},
        "2": {"type": "callback", "person": "Imran", "grateful": ["remove_sniper"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]},
        "5": {"type": "boss", "name": "Kibria", "gate": "L20_duel", "look": "boss",
              "intro": "Kibria straightens his panjabi. 'Before six, then. Ten questions, thirty seconds each, two of them law. Your way.'"},
        "8": {"type": "spot"},
        "9": {"type": "spot"},
    }
    objectives = [
        {"type": "talk", "person": "Masud", "text": "Masud has come up the back stairs: talk to him"},
        {"type": "talk", "person": "Imran", "text": "Cross to the next roof and talk to Imran"},
        {"type": "reach", "marker": "9", "text": "Cross the planks to the south roofs"},
        {"type": "eliminate", "tag": "sniper", "count": 3, "text": "Take down the three snipers"},
        {"type": "gate", "gate": "L20_duel", "text": "Face Kibria before six"},
    ]
    gates = {"L20_duel": gate("Kibria", size=10, compose=[(("G",), 8), (("BAR",), 2)], timer=30, category="duel", no_bribe=True)}
    return lvl(20, "Before six", "Chapter 8 · The roofs", "Kibria is on the roofs with his last snipers, waiting for the papers that will never arrive. The roof doors lock at six. This ends before then.",
               m, legend, objectives, gates, start_hour=16.6, palette="street", sector="rooftops", crowd=0,
               last_wish_cap=3, lw_share=0.4, player_yaw=-90, roof_floor=rf, deadline_hour=18.0, marker_tags={"Z": "sniper"},
               deadline_text="Six o'clock. The roof doors lock and Kibria walks away.")


LEVELS = [L01, L02, L03, L04, L05, L06, L07, L08, L09, L10, L11, L12, L13, L14, L15, L16, L17, L18, L19, L20]


# --- Checks -----------------------------------------------------------------------------------

def walkable(m, f, x, y, closed=None):
    ch = m.get(f, x, y)
    if ch in BLOCKED or ch in RAMPS:
        return False
    if ch == "G" and closed is not None and (f, x, y) in closed:
        return False
    if f > 0 and ch == " ":
        return False
    return 0 <= x < m.w and 0 <= y < m.h


def graph(m, d, closed=None):
    edges = {}

    def link(a, b, both=True):
        edges.setdefault(a, set()).add(b)
        if both:
            edges.setdefault(b, set()).add(a)

    for f in range(m.nf):
        for y in range(m.h):
            for x in range(m.w):
                ch = m.get(f, x, y)
                if ch in RAMPS:
                    dx, dy = RAMPS[ch]
                    nxt = m.get(f, x + dx, y + dy)
                    if nxt == ch:
                        link((f, x, y), (f, x + dx, y + dy))
                    elif walkable(m, f + 1, x + dx, y + dy, closed):
                        link((f, x, y), (f + 1, x + dx, y + dy))
                    if m.get(f, x - dx, y - dy) != ch and walkable(m, f, x - dx, y - dy, closed):
                        link((f, x, y), (f, x - dx, y - dy))
                elif walkable(m, f, x, y, closed):
                    for dx, dy in ((1, 0), (0, 1)):
                        if walkable(m, f, x + dx, y + dy, closed):
                            link((f, x, y), (f, x + dx, y + dy))
                    if ch == "L":
                        for g in range(m.nf):
                            if g != f and m.get(g, x, y) == "L":
                                link((f, x, y), (g, x, y))
    legend = d["legend"]
    for ch, info in legend.items():
        if "to" in info and info.get("type") in ("bypass", "ride", "plank", "driver"):
            dests = m.find(info["to"])
            for src in m.find(ch):
                for dst in dests:
                    for nb in near(m, src):
                        link(nb, dst, both=False)
    return edges


def near(m, cell):
    f, x, y = cell
    out = [cell]
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        out.append((f, x + dx, y + dy))
    return out


def check(d):
    m = d["_map"]
    errs = []
    n = d["level"]
    for f in range(m.nf):
        for y in range(m.h):
            for x in range(m.w):
                ch = m.get(f, x, y)
                if ch not in KNOWN:
                    errs.append(f"unknown char {ch!r} at {f},{x},{y}")
                if ch in RAMPS:
                    if f + 1 >= m.nf:
                        errs.append(f"ramp on the top floor at {f},{x},{y}")
                    elif m.get(f + 1, x, y) != " ":
                        errs.append(f"no headroom over ramp at {f},{x},{y} ({m.get(f + 1, x, y)!r} above)")
    starts = m.find("@")
    if len(starts) != 1:
        errs.append(f"need exactly one '@', found {len(starts)}")
        return errs
    legend = d["legend"]
    for ch in legend:
        if ch not in CUSTOM:
            errs.append(f"legend key {ch!r} is not a custom marker")
        if not m.find(ch) and not legend[ch].get("if_flag"):
            errs.append(f"legend {ch!r} ({legend[ch].get('type')}) is not on the map")
    edges = graph(m, d)
    seen = {starts[0]}
    q = deque([starts[0]])
    while q:
        c = q.popleft()
        for nb in edges.get(c, ()):
            if nb not in seen:
                seen.add(nb)
                q.append(nb)

    def reachable(cells):
        return any(c in seen or any(nb in seen for nb in near(m, c)[1:]) for c in cells)

    def cells_where(pred):
        return [c for ch, info in legend.items() if pred(info) for c in m.find(ch)]

    bank = json.loads((ROOT / "Data" / "Questions" / "question_bank.json").read_text(encoding="utf-8"))
    sets = {s for q_ in bank["questions"] for s in q_["sets"]}
    scen = {s["person"] for s in json.loads((ROOT / "Data" / "CareerAdvice" / "scenarios.json").read_text(encoding="utf-8"))["scenarios"]}
    groups = set(gate_groups(m).values())
    for gid, g in d["gates"].items():
        draw_sets = list(g.get("draw", {}).get("sets", [])) + [s for part in g.get("compose", []) for s in part["sets"]]
        for s in draw_sets:
            if s not in sets:
                errs.append(f"gate {gid}: set {s} is not in the bank")
        opens = g.get("opens", [])
        for k in ([opens] if isinstance(opens, str) else opens):
            if k not in groups:
                errs.append(f"gate {gid}: opens {k} but the map has {sorted(groups)}")
        if not cells_where(lambda i, gid=gid: i.get("gate") == gid):
            errs.append(f"gate {gid}: nobody on the map asks it")
    for ch, info in legend.items():
        if info.get("gate") and info["gate"] not in d["gates"] and not (ROOT / "Data" / "Gates" / f"{info['gate']}.json").exists():
            errs.append(f"legend {ch}: gate {info['gate']} has no definition")
        if info.get("type") in ("career", "callback") and info.get("person") not in scen:
            errs.append(f"legend {ch}: {info.get('person')} is not in scenarios.json")
        if info.get("type") in ("career", "callback"):
            pass
    for i, o in enumerate(d["objectives"]):
        t = o["type"]
        if o.get("if_flag"):
            targets = cells_where(lambda info, o=o: info.get("key") == o.get("key"))
            if targets and not reachable(targets):
                errs.append(f"objective {i + 1} ({t}) is not reachable")
            continue
        if t == "reach":
            targets = m.find(o.get("marker", "E"))
        elif t in ("pickup", "utility", "task", "plank", "bypass", "ride"):
            targets = cells_where(lambda info, o=o: info.get("key") == o["key"])
        elif t == "gate":
            targets = cells_where(lambda info, o=o: info.get("gate") == o["gate"])
        elif t == "talk":
            targets = cells_where(lambda info, o=o: info.get("person") == o["person"] and info.get("type") in ("career", "callback"))
        elif t == "search":
            targets = cells_where(lambda info, o=o: info.get("type") == "courier" and info.get("key") == o["key"])
            if len(targets) < int(o.get("count", 1)):
                errs.append(f"objective {i + 1}: needs {o.get('count', 1)} couriers, map has {len(targets)}")
        elif t == "free":
            targets = cells_where(lambda info, o=o: info.get("type") == "captive" and info.get("key") == o["key"])
        elif t == "interrogate":
            targets = cells_where(lambda info, o=o: info.get("interrogate") and info.get("tag") == o["tag"])
            if len(targets) < int(o.get("count", 1)):
                errs.append(f"objective {i + 1}: needs {o.get('count')} people to question, map has {len(targets)}")
        elif t == "eliminate":
            tag = o.get("tag", "")
            tags = d.get("marker_tags", {})
            targets = [c for ch, tg in tags.items() if tg == tag for c in m.find(ch)]
            targets += cells_where(lambda info, tag=tag: info.get("tag") == tag and info.get("type") in ("goon", "gunman", "sniper", "lieutenant", "boss"))
            if not tag:
                targets = [c for ch in "XYZ" for c in m.find(ch)]
            if len(targets) < int(o.get("count", 1)):
                errs.append(f"objective {i + 1}: needs {o.get('count')} tagged '{tag}', map has {len(targets)}")
        elif t == "survive":
            for w in o.get("waves", []):
                if not m.find(w["marker"]):
                    errs.append(f"objective {i + 1}: wave marker {w['marker']} missing")
            continue
        else:
            errs.append(f"objective {i + 1}: unknown type {t}")
            continue
        if not targets:
            errs.append(f"objective {i + 1} ({t}): no target on the map")
        elif not reachable(targets):
            errs.append(f"objective {i + 1} ({t} {o.get('key', o.get('gate', o.get('person', o.get('marker', ''))))}): not reachable from the start")
        elif not progress_reachable(m, d, i, targets, starts[0]):
            errs.append(f"objective {i + 1} ({t}): only reachable through a gate that is still shut at that point")
    return errs


def progress_reachable(m, d, index, targets, start):
    """Reachability with every gate group shut except those opened by gate objectives before `index`."""
    opened = set()
    for o in d["objectives"][:index]:
        if o["type"] == "gate":
            g = d["gates"].get(o["gate"], {})
            ops = g.get("opens", [])
            opened.update([ops] if isinstance(ops, str) else ops)
    cell_group = {}
    for (f, x, y), key in gate_groups(m).items():
        cx, cy = x, y
        while m.get(f, cx, cy) == "G":
            cell_group[(f, cx, cy)] = key
            if m.get(f, cx + 1, cy) == "G":
                cx += 1
            else:
                cy += 1
    closed = {c for c, key in cell_group.items() if key not in opened}
    edges = graph(m, d, closed)
    seen = {start}
    q = deque([start])
    while q:
        c = q.popleft()
        for nb in edges.get(c, ()):
            if nb not in seen:
                seen.add(nb)
                q.append(nb)
    return any(c in seen or any(nb in seen for nb in near(m, c)[1:]) for c in targets)


def export(d):
    out = {k: v for k, v in d.items() if not k.startswith("_")}
    out.pop("legend_roof_door", None)
    m = d["_map"]
    if m.find(ROOF_DOOR):
        out["legend"].setdefault(ROOF_DOOR, {"type": "roof_door", "axis": "x"})
    out.setdefault("roof_floor", max(1, m.nf - 1))
    out.setdefault("block_height", 18.0)
    out.setdefault("roofed", True)
    return out


def main():
    only_check = "--check" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for make in LEVELS:
        d = make()
        m = d["_map"]
        if m.find(ROOF_DOOR):
            d["legend"].setdefault(ROOF_DOOR, {"type": "roof_door", "axis": "x"})
        errs = check(d)
        tag = "L%02d" % d["level"]
        if errs:
            total += len(errs)
            print(f"{tag} {d['title']}: {len(errs)} problem(s)")
            for e in errs:
                print("   -", e)
        else:
            print(f"{tag} {d['title']}: ok ({m.w}x{m.h}, {m.nf} floor(s), {len(d['objectives'])} objectives, {len(d['gates'])} gates)")
        if not only_check:
            (OUT / f"{tag}.json").write_text(json.dumps(export(d), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("problems:", total)
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
