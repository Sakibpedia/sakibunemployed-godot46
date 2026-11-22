#!/usr/bin/env python3
"""Consistency check for the story data of "S M Nazmuz Sakib is unemployed".

Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

Checks Data/Story/missions.json and characters.json against the city (POIs), the faces table, the
mission director's step types and the question banks:
  * every mission id is unique, every "requires" exists and there is no cycle;
  * every step type is one MissionDirector.gd handles, with the keys that type needs;
  * every NPC, giver and speaker is a character (or sakib / narrator), every POI exists in city.json;
  * every character face exists in faces.json and every home POI exists;
  * every line, title, objective and choice has non-empty Bengali text;
  * every exam step's filter has enough questions in the banks to fill it;
  * the Bengali name is spelled এস এম নাজমুয সাকিব everywhere (never নাজমুজ).

Usage: python3 tools/check_story.py      (exit code 1 if anything is wrong)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPECIAL_SPEAKERS = {"sakib", "narrator", "player"}
STEP_KEYS = {
    "talk": ["npc"], "choice": ["npc"], "exam": ["npc"], "deliver": ["npc", "item"], "goto": ["poi"],
    "wait": ["until_hour"], "cutscene": ["lines"], "reward": [], "posters": ["count"], "banish": ["count"],
    "duels": ["count"], "kill": ["targets"], "collect": ["item"], "escort": ["npc", "to"], "chase": ["npc"],
    "defend": ["poi", "waves"], "drive": ["poi"], "survive": ["until_hour"], "boss_ghost": ["spirit"], "ending": [],
}
EXAM_MODES = {"gate", "duel", "dying", "ghost", "police", "viva", "interview", "poster", "tuition", "bar", "prelim"}
WRONG_NAME = "নাজমুজ"


def load(p):
    return json.loads((ROOT / p).read_text(encoding="utf-8"))


def main():
    errs = []
    warn = []
    missions = load("Data/Story/missions.json")["missions"]
    chars = {c["id"]: c for c in load("Data/Story/characters.json")["characters"]}
    city = load("Data/World/city.json")
    pois = {p["id"] for p in city["pois"]}
    faces = load("art/textures/faces/faces.json")["faces"]
    face_ids = set(faces) if isinstance(faces, dict) else {f["id"] for f in faces}
    director = (ROOT / "scripts/missions/MissionDirector.gd").read_text(encoding="utf-8")
    handled = set(re.findall(r'^\t\t"(\w+)"(?:, "\w+")*:', director, re.M))
    for grp in re.findall(r'^\t\t((?:"\w+", )+"\w+"):', director, re.M):
        handled |= set(re.findall(r'"(\w+)"', grp))

    def need_bn(where, d):
        if not isinstance(d, dict) or not str(d.get("bn", "")).strip():
            errs.append("%s: missing Bengali text" % where)

    def speaker_ok(where, who):
        if who not in chars and who not in SPECIAL_SPEAKERS:
            errs.append("%s: unknown speaker/NPC '%s'" % (where, who))

    def poi_ok(where, pid):
        if pid not in pois and pid != "random":
            errs.append("%s: unknown POI '%s'" % (where, pid))

    # characters
    for cid, c in chars.items():
        need_bn("character %s name" % cid, c.get("name"))
        if c.get("face") and c["face"] not in face_ids:
            errs.append("character %s: face '%s' not in faces.json" % (cid, c["face"]))
        if c.get("home"):
            poi_ok("character %s home" % cid, c["home"])

    # missions
    ids = [m["id"] for m in missions]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        errs.append("duplicate mission ids: %s" % sorted(dup))
    idset = set(ids)
    graph = {}
    for m in missions:
        mid = m["id"]
        graph[mid] = list(m.get("requires", []))
        for r in graph[mid]:
            if r not in idset:
                errs.append("%s: requires unknown mission '%s'" % (mid, r))
        need_bn("%s title" % mid, m.get("title"))
        speaker_ok("%s giver" % mid, m.get("giver", ""))
        poi_ok("%s start_poi" % mid, m.get("start_poi", ""))
        for k, line in enumerate(m.get("intro", [])):
            speaker_ok("%s intro %d" % (mid, k), line.get("who", ""))
            need_bn("%s intro %d" % (mid, k), line)
        for i, st in enumerate(m["steps"]):
            where = "%s step %d (%s)" % (mid, i, st.get("type"))
            t = st.get("type")
            if t not in STEP_KEYS:
                errs.append("%s: unknown step type" % where)
                continue
            if t not in handled:
                errs.append("%s: MissionDirector.gd has no branch for this type" % where)
            for key in STEP_KEYS[t]:
                if key not in st:
                    errs.append("%s: missing '%s'" % (where, key))
            if t not in ("reward", "ending", "cutscene"):
                need_bn(where + " objective", st.get("text"))
            if "npc" in st:
                speaker_ok(where, st["npc"])
            for key in ("poi", "spawn_poi", "to"):
                if key in st:
                    poi_ok(where, st[key])
            for r in st.get("route", []):
                poi_ok(where + " route", r)
            for tg in st.get("targets", []):
                speaker_ok(where + " target", tg.get("npc", ""))
                poi_ok(where + " target", tg.get("poi", ""))
            for k, line in enumerate(st.get("lines", [])):
                speaker_ok("%s line %d" % (where, k), line.get("who", ""))
                need_bn("%s line %d" % (where, k), line)
            for k, ch in enumerate(st.get("choices", [])):
                need_bn("%s choice %d" % (where, k), ch.get("text", ch))
            if t == "exam":
                if st.get("mode", "gate") not in EXAM_MODES:
                    errs.append("%s: unknown exam mode '%s'" % (where, st.get("mode")))
                if int(st.get("pass", 2)) > int(st.get("count", 3)):
                    errs.append("%s: pass mark above question count" % where)

    # cycles in "requires"
    state = {}

    def visit(n, path):
        if state.get(n) == 1:
            errs.append("requires cycle: %s" % " -> ".join(path + [n]))
            return
        if state.get(n) == 2:
            return
        state[n] = 1
        for r in graph.get(n, []):
            visit(r, path + [n])
        state[n] = 2

    for n in graph:
        visit(n, [])

    # question supply for exam steps
    practice = load("Data/Questions/practice_bank.json")["questions"]
    cited_raw = load("Data/Questions/question_bank.json")
    cited = cited_raw["questions"] if isinstance(cited_raw, dict) else cited_raw

    bucket_family = {"bcs": "bcs", "gov_job": "job", "bar_council": "bar"}  # same as QuestionBank.gd

    def fams(q):
        if "source_bucket" in q:  # cited past-paper item, mapped the same way QuestionBank.gd does
            f = bucket_family.get(q["source_bucket"], "bcs")
            return {f, "bcs"} if f == "job" else {f}
        f = q.get("families") or q.get("family") or []
        return set([f] if isinstance(f, str) else f)

    for m in missions:
        for i, st in enumerate(m["steps"]):
            if st.get("type") != "exam":
                continue
            fam = st.get("family", "")
            pool = cited if st.get("cited_only") else practice + cited
            pool = [q for q in pool if q.get("verified", True) and not q.get("requires_replacement", False)]
            n = sum(1 for q in pool if not fam or fam in fams(q))
            if n < int(st.get("count", 3)) * 3:
                warn.append("%s step %d: only %d questions for family '%s' (the director relaxes filters)" % (m["id"], i, n, fam))

    # spelling of the Bengali name
    for p in list((ROOT / "Data").rglob("*.json")) + list((ROOT / "scripts").rglob("*.gd")) + \
            [ROOT / "project.godot", ROOT / "README.md", ROOT / "CREDITS.md", ROOT / "COPYRIGHT.txt"] + list((ROOT / "docs").glob("*.md")):
        if p.exists() and WRONG_NAME in p.read_text(encoding="utf-8"):
            errs.append("%s: wrong spelling %s (should be নাজমুয)" % (p.relative_to(ROOT), WRONG_NAME))

    print("Missions: %d   Characters: %d   POIs: %d   Faces: %d" % (len(missions), len(chars), len(pois), len(face_ids)))
    for w in warn:
        print("warning:", w)
    for e in errs:
        print("ERROR:", e)
    print("OK" if not errs else "%d problems" % len(errs))
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
