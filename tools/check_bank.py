#!/usr/bin/env python3
"""Build check for the question bank (design doc Sections 6.1 and 7.4).

Fails (exit code 1) on: duplicate IDs, a bad correct_index, missing options or source fields,
time_sensitive items, a verified:false item without a note, synthetic items in Bar Council sets,
a chain parent topic with fewer than four items, or a source share outside the rules.

Usage: python3 tools/check_bank.py [path/to/question_bank.json]
"""
import json, sys
from collections import Counter, defaultdict

def check(path):
    data = json.load(open(path, encoding="utf-8"))
    items = data["questions"]
    errors, ids = [], Counter(q["id"] for q in items)
    for i, n in ids.items():
        if n > 1:
            errors.append(f"duplicate id {i}")
    parents = defaultdict(int)
    for q in items:
        qid = q["id"]
        if not 0 <= int(q["correct_index"]) <= 3:
            errors.append(f"{qid}: correct_index out of range")
        for k in ("option_1", "option_2", "option_3", "option_4", "question_text", "source_exam", "source_year", "source_paper"):
            if not str(q.get(k, "")).strip():
                errors.append(f"{qid}: missing {k}")
        if q.get("time_sensitive"):
            errors.append(f"{qid}: time_sensitive items are not allowed")
        if not q.get("verified") and not q.get("verification_note"):
            errors.append(f"{qid}: verified:false needs a verification_note")
        if q.get("synthetic") and q.get("source_bucket") == "bar_council":
            errors.append(f"{qid}: synthetic items are barred from Bar Council gates")
        if q.get("synthetic") and q.get("verified"):
            errors.append(f"{qid}: a synthetic item cannot be marked verified")
        parents[q["chain_parent"]] += 1
    for p, n in parents.items():
        if n < 4:
            errors.append(f"chain parent '{p}' has only {n} items (needs 4)")
    errors += check_shares(items)
    return items, errors

def check_shares(items):
    n = len(items)
    buckets = Counter(q["source_bucket"] for q in items)
    errs = []
    if buckets["bcs"] / n < 0.40:
        errs.append(f"BCS share {buckets['bcs']/n:.1%} is below 40%")
    if buckets["bar_council"] / n > 0.20:
        errs.append(f"Bar Council share {buckets['bar_council']/n:.1%} is above 20%")
    sets = defaultdict(list)
    for q in items:
        for s in q["sets"]:
            sets[s].append(q)
    for s, qs in sets.items():
        syn = sum(1 for q in qs if q.get("synthetic"))
        if syn / len(qs) > 0.10:
            errs.append(f"set {s}: synthetic share {syn/len(qs):.0%} is above 10%")
    return errs

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "Data/Questions/question_bank.json"
    items, errors = check(path)
    n = len(items)
    ver = sum(1 for q in items if q.get("verified"))
    b = Counter(q["source_bucket"] for q in items)
    print(f"{n} items · {ver} verified · {n-ver} verified:false · "
          f"BCS {b['bcs']/n:.1%} · other government jobs {b['gov_job']/n:.1%} · Bar Council {b['bar_council']/n:.1%} · "
          f"synthetic {sum(1 for q in items if q.get('synthetic'))}")
    for e in errors:
        print("ERROR:", e)
    sys.exit(1 if errors else 0)
