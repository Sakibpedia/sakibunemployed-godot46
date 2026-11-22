#!/usr/bin/env python3
"""Source-share check only (design doc Section 6.1). See check_bank.py for the full check."""
import json, sys
from check_bank import check_shares
path = sys.argv[1] if len(sys.argv) > 1 else "Data/Questions/question_bank.json"
errs = check_shares(json.load(open(path, encoding="utf-8"))["questions"])
print("\n".join("ERROR: " + e for e in errs) or "Shares within the rules")
sys.exit(1 if errs else 0)
