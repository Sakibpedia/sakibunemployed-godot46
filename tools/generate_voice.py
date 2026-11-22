#!/usr/bin/env python3
"""Generate the game's spoken Bengali and English lines with edge-tts.

The game used to rely on whatever voices the player's operating system happened to have.  That is
not good enough for a Bengali open world: most Windows installs have no bn-BD voice at all.  This
tool pre-renders every line that can be spoken into small MP3 files and writes a manifest that
Voice.gd looks up at runtime.

    python tools/generate_voice.py                 # generate everything missing
    python tools/generate_voice.py --test          # one sample only
    python tools/generate_voice.py --limit 20      # first 20 lines (for a quick check)
    python tools/generate_voice.py --lang bn       # Bengali only

Files live in res://audio/voice/<lang>/ and the manifest in res://audio/voice/manifest.json.
The key is  lang|voice_id|sha256(normalised text)[:16]  so the runtime never needs a fragile
line index.  Re-running is safe: existing files are kept and only missing lines are generated.
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "audio" / "voice"
MANIFEST = OUT / "manifest.json"

# voice id -> (bn voice, en voice, bn rate, bn pitch, en rate, en pitch)
PROFILES = {
    "sakib":    ("bn-BD-PradeepNeural",  "en-IN-PrabhatNeural", "-2%",  "-2Hz",  "-2%",  "-2Hz"),
    "narrator": ("bn-BD-PradeepNeural",  "en-IN-PrabhatNeural", "-8%",  "-5Hz",  "-6%",  "-4Hz"),
    "bark_m":   ("bn-BD-PradeepNeural",  "en-IN-PrabhatNeural", "+3%",  "+0Hz",  "+2%",  "+0Hz"),
    "bark_f":   ("bn-BD-NabanitaNeural", "en-IN-NeerjaNeural",  "+4%",  "+2Hz",  "+3%",  "+1Hz"),
    "bark_old": ("bn-IN-BashkarNeural",  "en-IN-PrabhatNeural", "-8%",  "-8Hz",  "-7%",  "-6Hz"),
    "ghost":    ("bn-IN-BashkarNeural",  "en-IN-PrabhatNeural", "-15%", "-20Hz", "-12%", "-14Hz"),
}

FEMALE_FACES = {"f_", "f-"}
FEMALE_IDS = {
    "rina_apa", "nadia", "shirin", "rumana", "moushumi", "nusrat", "tania", "sumi", "rumana",
    "farzana", "taslima", "sathi", "mitu", "papia", "lipi", "ruma", "shilpi", "moushumi", "joya",
    "purnima", "shikha",
}


def norm(text: str) -> str:
    return re.sub(r"\s+", " ", str(text)).strip()


def key_for(lang: str, voice_id: str, text: str) -> str:
    digest = hashlib.sha256(norm(text).encode("utf-8")).hexdigest()[:16]
    return f"{lang}|{voice_id}|{digest}"


def load_manifest() -> dict:
    if MANIFEST.exists():
        try:
            return json.loads(MANIFEST.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {"version": 1, "generated": "", "profiles": {}, "lines": {}}


def save_manifest(data: dict) -> None:
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    tmp = MANIFEST.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    tmp.replace(MANIFEST)


# ------------------------------------------------------------------------------------------------
# Collect lines from the game data
# ------------------------------------------------------------------------------------------------

def unescape_gd(s: str) -> str:
    try:
        return json.loads('"' + s + '"')
    except Exception:
        return s.replace('\\"', '"').replace("\\n", "\n")


def parse_pairs(path: Path) -> list[tuple[str, str]]:
    """All {"bn": "...", "en": "..."} literals in a GDScript file."""
    if not path.exists():
        return []
    src = path.read_text(encoding="utf-8", errors="replace")
    pattern = re.compile(
        r'\{\s*"bn"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,\s*"en"\s*:\s*"((?:[^"\\]|\\.)*)"\s*\}',
        re.S,
    )
    return [(unescape_gd(m.group(1)), unescape_gd(m.group(2))) for m in pattern.finditer(src)]


def infer_female(char: dict) -> bool:
    cid = str(char.get("id", ""))
    face = str(char.get("face", ""))
    return face.startswith("f_") or cid in FEMALE_IDS or str(char.get("profession", "")) == "aunty"


def named_profile(char: dict) -> tuple[str, str, str, str, str, str]:
    cid = str(char.get("id", ""))
    female = infer_female(char)
    h = int(hashlib.sha256(cid.encode("utf-8")).hexdigest()[:8], 16)
    if female:
        bn = "bn-BD-NabanitaNeural" if h % 3 else "bn-IN-TanishaaNeural"
        en = "en-IN-NeerjaNeural"
        return (bn, en, "+0%", "+1Hz", "+0%", "+1Hz")
    bn = "bn-BD-PradeepNeural" if h % 3 else "bn-IN-BashkarNeural"
    en = "en-IN-PrabhatNeural"
    return (bn, en, "-1%", "-1Hz", "-1%", "-1Hz")


def collect() -> list[dict]:
    """Return [{lang, voice_id, text, source}] for every line we can pre-render."""
    out: list[dict] = []
    seen: set[str] = set()

    def add(lang: str, voice_id: str, text: str, source: str) -> None:
        text = norm(text)
        if not text or len(text) < 2:
            return
        if "%s" in text or "{" in text or "}" in text:
            return  # templates are filled at runtime; don't bake a placeholder voice
        k = key_for(lang, voice_id, text)
        if k in seen:
            return
        seen.add(k)
        out.append({"lang": lang, "voice_id": voice_id, "text": text, "source": source, "key": k})

    chars_path = ROOT / "Data" / "Story" / "characters.json"
    chars = []
    if chars_path.exists():
        chars = json.loads(chars_path.read_text(encoding="utf-8")).get("characters", [])
    char_ids = {str(c.get("id")) for c in chars}
    profiles = {str(c.get("id")): named_profile(c) for c in chars}

    missions_path = ROOT / "Data" / "Story" / "missions.json"
    if missions_path.exists():
        data = json.loads(missions_path.read_text(encoding="utf-8"))
        for m in data.get("missions", []):
            mid = str(m.get("id", "mission"))
            for ln in m.get("intro", []):
                who = str(ln.get("who", "narrator"))
                vid = who if who in char_ids or who in ("sakib", "narrator") else "narrator"
                for lang, field in (("bn", "bn"), ("en", "en")):
                    add(lang, vid, str(ln.get(field, "")), f"{mid}/intro/{who}")
            for si, step in enumerate(m.get("steps", [])):
                for ln in step.get("lines", []):
                    who = str(ln.get("who", "narrator"))
                    vid = who if who in char_ids or who in ("sakib", "narrator") else "narrator"
                    for lang, field in (("bn", "bn"), ("en", "en")):
                        add(lang, vid, str(ln.get(field, "")), f"{mid}/step{si}/{who}")
                for ch in step.get("choices", []):
                    for lang, field in (("bn", "bn"), ("en", "en")):
                        add(lang, "sakib", str(ch.get(field, "")), f"{mid}/step{si}/choice")
                txt = step.get("text", {})
                if isinstance(txt, dict):
                    for lang, field in (("bn", "bn"), ("en", "en")):
                        add(lang, "narrator", str(txt.get(field, "")), f"{mid}/step{si}/objective")
            title = m.get("title", {})
            if isinstance(title, dict):
                for lang, field in (("bn", "bn"), ("en", "en")):
                    add(lang, "narrator", str(title.get(field, "")), f"{mid}/title")

    # Ambient chatter and taunts.  These are shared by everyone, so render them in the generic
    # voices; Voice.gd picks bark_m / bark_f / bark_old from the speaker's pitch.
    for rel in ("scripts/dialogue/ChatterAI.gd", "scripts/dialogue/TauntBank.gd"):
        for bn, en in parse_pairs(ROOT / rel):
            for vid in ("bark_m", "bark_f", "bark_old"):
                add("bn", vid, bn, rel)
                add("en", vid, en, rel)
            # Ghosts and the dying get a colder, slower read of the same lines.
            if rel.endswith("TauntBank.gd"):
                add("bn", "ghost", bn, rel)
                add("en", "ghost", en, rel)

    # Named characters' own greetings, so meeting Rina Apa or Habib Sir is voiced in their voice.
    for c in chars:
        cid = str(c.get("id", ""))
        name = c.get("name", {})
        if isinstance(name, dict):
            for lang, field in (("bn", "bn"), ("en", "en")):
                add(lang, cid, str(name.get(field, "")), "characters/name")

    # Sort so the first lines are the story, not the taunt bank: nicer progress output.
    out.sort(key=lambda r: (0 if "/step" in r["source"] or "/intro" in r["source"] else 1, r["source"], r["lang"], r["text"]))
    return out, profiles


def voice_for(lang: str, voice_id: str, profiles: dict) -> tuple[str, str, str]:
    if voice_id in profiles:
        p = profiles[voice_id]
    elif voice_id in PROFILES:
        p = PROFILES[voice_id]
    else:
        p = PROFILES["narrator"]
    if lang == "bn":
        return p[0], p[2], p[3]
    return p[1], p[4], p[5]


# ------------------------------------------------------------------------------------------------
# Render
# ------------------------------------------------------------------------------------------------

async def render_one(item: dict, profiles: dict, sem: asyncio.Semaphore, stats: dict) -> None:
    lang, vid, text, key = item["lang"], item["voice_id"], item["text"], item["key"]
    async with sem:
        voice, rate, pitch = voice_for(lang, vid, profiles)
        dest = OUT / lang / f"{vid}_{key.split('|')[-1]}.mp3"
        if dest.exists() and dest.stat().st_size > 800:
            stats["skipped"] += 1
            return
        dest.parent.mkdir(parents=True, exist_ok=True)
        for attempt in range(4):
            try:
                comm = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch, volume="+0%")
                audio = bytearray()
                last_end = 0.0
                sub = edge_tts.SubMaker()
                async for chunk in comm.stream():
                    if chunk["type"] == "audio":
                        audio.extend(chunk["data"])
                    elif chunk["type"] == "WordBoundary":
                        sub.feed(chunk)
                        last_end = max(last_end, (chunk["offset"] + chunk["duration"]) / 1e7)
                if len(audio) < 800:
                    raise RuntimeError("empty audio")
                dest.write_bytes(audio)
                dur = last_end if last_end > 0.3 else max(1.2, len(text) / 13.0)
                item["file"] = "res://audio/voice/" + lang + "/" + dest.name
                item["dur"] = round(dur + 0.25, 2)
                stats["made"] += 1
                if stats["made"] % 25 == 0:
                    print(f"  ... {stats['made']} rendered, {stats['skipped']} existing", flush=True)
                return
            except Exception as exc:  # noqa: BLE001 - edge-tts raises several network errors
                if attempt == 3:
                    print(f"  FAIL {lang} {vid} {text[:42]!r}: {exc}", file=sys.stderr)
                    stats["failed"] += 1
                else:
                    await asyncio.sleep(1.5 * (attempt + 1))


async def main_async(args: argparse.Namespace) -> int:
    items, profiles = collect()
    if args.lang != "all":
        items = [i for i in items if i["lang"] == args.lang]
    if args.only:
        items = [i for i in items if args.only in i["source"]]
    if args.limit:
        items = items[: args.limit]
    manifest = load_manifest()
    manifest["profiles"] = {
        "sakib": {"bn": PROFILES["sakib"][0], "en": PROFILES["sakib"][1]},
        "narrator": {"bn": PROFILES["narrator"][0], "en": PROFILES["narrator"][1]},
        "bark_m": {"bn": PROFILES["bark_m"][0], "en": PROFILES["bark_m"][1]},
        "bark_f": {"bn": PROFILES["bark_f"][0], "en": PROFILES["bark_f"][1]},
        "bark_old": {"bn": PROFILES["bark_old"][0], "en": PROFILES["bark_old"][1]},
        "ghost": {"bn": PROFILES["ghost"][0], "en": PROFILES["ghost"][1]},
    }
    # Drop stale entries for files that no longer exist.
    lines = {k: v for k, v in manifest.get("lines", {}).items() if (ROOT / str(v.get("file", "")).replace("res://", "")).exists()}
    manifest["lines"] = lines
    print(f"Voice lines: {len(items)} requested, {len(lines)} already in manifest, output {OUT}")
    if args.test:
        items = items[:1]
    sem = asyncio.Semaphore(max(1, args.jobs))
    stats = {"made": 0, "skipped": 0, "failed": 0}
    t0 = time.time()
    tasks = [asyncio.create_task(render_one(i, profiles, sem, stats)) for i in items]
    # Save periodically while the tasks run, so a long run is resumable.
    async def saver() -> None:
        while True:
            await asyncio.sleep(10.0)
            for i in items:
                if "file" in i:
                    lines[i["key"]] = {"file": i["file"], "dur": i.get("dur", 2.0)}
            manifest["lines"] = lines
            save_manifest(manifest)
    saver_task = asyncio.create_task(saver())
    await asyncio.gather(*tasks)
    saver_task.cancel()
    for i in items:
        if "file" in i:
            lines[i["key"]] = {"file": i["file"], "dur": i.get("dur", 2.0)}
    manifest["lines"] = lines
    manifest["generated"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    save_manifest(manifest)
    print(f"Done in {time.time() - t0:.1f}s: {stats['made']} rendered, {stats['skipped']} existing, "
          f"{stats['failed']} failed, manifest {len(lines)} lines.")
    return 0 if stats["failed"] == 0 else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lang", choices=["bn", "en", "all"], default="all")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--only", default="")
    ap.add_argument("--jobs", type=int, default=6)
    ap.add_argument("--test", action="store_true")
    return asyncio.run(main_async(ap.parse_args()))


if __name__ == "__main__":
    raise SystemExit(main())
