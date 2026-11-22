#!/usr/bin/env python3
"""The only way a new question enters the bank (design doc Section 7.4).

Every field is required. The item is saved as verified:false; a second person flips it to
true after checking the printed paper. Never add an item whose paper you cannot find.

Example:
  python3 tools/add_item.py --id G41 --sets G --exam "44th BCS Preliminary" --date 2022-05-27 \
    --q Q12 --bucket bcs --lang bn --stem-bn "..." --stem-en "..." --options "a" "b" "c" "d" \
    --answer 2 --topic bengal_history --parent bangladesh_history --evidence https://... --note "checked by ..."
"""
import argparse, json
p = argparse.ArgumentParser()
for a in ("--id", "--exam", "--date", "--q", "--bucket", "--lang", "--stem-bn", "--stem-en",
          "--topic", "--parent", "--evidence", "--note"):
    p.add_argument(a, required=True)
p.add_argument("--sets", nargs="+", required=True)
p.add_argument("--options", nargs=4, required=True)
p.add_argument("--answer", type=int, choices=range(4), required=True, help="0-based index of the right option")
p.add_argument("--coupling", default=None)
p.add_argument("--bank", default="Data/Questions/question_bank.json")
a = p.parse_args()
bank = json.load(open(a.bank, encoding="utf-8"))
if any(q["id"] == a.id for q in bank["questions"]):
    raise SystemExit(f"{a.id} already exists")
if a.bucket not in ("bcs", "gov_job", "bar_council"):
    raise SystemExit("bucket must be bcs, gov_job or bar_council (university admission papers are excluded)")
o = a.options
bank["questions"].append({
    "id": a.id, "sets": a.sets, "source_exam": a.exam, "source_year": a.date, "source_paper": a.q,
    "source_bucket": a.bucket, "question_text": a.stem_bn if a.lang == "bn" else a.stem_en,
    "question_text_bn": a.stem_bn, "question_text_en": a.stem_en,
    "option_1": o[0], "option_2": o[1], "option_3": o[2], "option_4": o[3], "correct_index": a.answer,
    "topic_tags": [a.topic, a.parent], "time_sensitive": False, "language": a.lang, "item_coupling": a.coupling,
    "verified": False, "synthetic": False, "requires_replacement": False, "chain_topic": a.topic,
    "chain_parent": a.parent, "options_source": "paper", "stem_policy": "paraphrased; fact, answer and source kept",
    "verification_evidence": a.evidence, "verification_note": "Awaiting second check. " + a.note,
})
json.dump(bank, open(a.bank, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"Added {a.id} as verified:false")
