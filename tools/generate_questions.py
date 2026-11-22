#!/usr/bin/env python3
"""Practice question generator for "S M Nazmuz Sakib is unemployed".

Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

Writes Data/Questions/practice_bank.json: 2,000+ multiple-choice practice questions in the style of
the BCS preliminary, bank and other job tests, and the Bangladesh Bar Council enrolment exam.

These are ORIGINAL PRACTICE QUESTIONS, not past-paper questions. Every item says what it is built
from in "basis":
  * maths, number systems and logic gates are computed by this script, so the answer is exact;
  * everything else comes from the fact tables below (statute sections, constitution articles,
    capitals, element symbols, grammar pairs ...). Each table row is one checkable fact.
The 173 real past-paper questions stay in question_bank.json with their citations, and the game
marks them separately ("cited": true).

Every item is in Bengali (the game's language). Items written in English in the tables below get a
Bengali stem and Bengali options from tools/question_bn.py; the English section keeps its English
words and options under a Bengali instruction.

Usage:
  python3 tools/generate_questions.py            # write the bank and print a summary
  python3 tools/generate_questions.py --check    # validate without writing
  python3 tools/generate_questions.py --sample 20  # print 20 random items
"""
import argparse
import json
import math
import random
import sys
from fractions import Fraction
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import question_bn  # noqa: E402  Bengali tables (the game is in Bengali)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Data" / "Questions" / "practice_bank.json"
SEED = 20261119

BN_DIGITS = str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯")


def bn(x):
    """Bengali digits for numbers inside Bengali text."""
    return str(x).translate(BN_DIGITS)


class Bank:
    def __init__(self, rng):
        self.rng = rng
        self.items = []
        self.seen = set()
        self.counter = {}

    def add(self, cat, families, difficulty, q_en, answer_en, distractors_en, basis,
            q_bn=None, answer_bn=None, distractors_bn=None, prefix=None):
        """Add one item. Options are shuffled; the same shuffle is used for both languages."""
        key = (cat, q_en or q_bn)
        if key in self.seen:
            return False
        opts_en = [answer_en] + list(distractors_en)[:3] if answer_en is not None else None
        opts_bn = [answer_bn] + list(distractors_bn)[:3] if answer_bn is not None else None
        ref = opts_en if opts_en is not None else opts_bn
        if ref is None or len(ref) != 4 or len(set(map(str, ref))) != 4:
            return False
        if opts_bn is not None and (len(opts_bn) != 4 or len(set(map(str, opts_bn))) != 4):
            return False
        order = list(range(4))
        self.rng.shuffle(order)
        p = prefix or cat.upper()[:4]
        self.counter[p] = self.counter.get(p, 0) + 1
        item = {
            "id": "P-%s-%04d" % (p, self.counter[p]),
            "family": families[0],
            "families": list(families),
            "category": cat,
            "difficulty": difficulty,
            "answer": order.index(0),
            "basis": basis,
            "source": "Practice question (generated, not a past paper)",
            "cited": False,
            "synthetic": True,
            "verified": True,
        }
        if q_en:
            item["q_en"] = q_en
            item["options_en"] = [str(opts_en[i]) for i in order] if opts_en else []
        if q_bn:
            item["q_bn"] = q_bn
            item["options_bn"] = [str(opts_bn[i]) for i in order] if opts_bn else []
        item["lang"] = "bn" if q_bn and not q_en else ("en" if q_en and not q_bn else "both")
        self.seen.add(key)
        self.items.append(item)
        return True

    def pick(self, pool, k, exclude):
        """k distinct values from pool, none equal to anything in exclude."""
        ex = set(map(str, exclude))
        cand = [x for x in dict.fromkeys(pool) if str(x) not in ex]
        if len(cand) < k:
            return None
        return self.rng.sample(cand, k)


# =============================================================================================
# Numeric distractors
# =============================================================================================

def num_distractors(rng, ans, spread=None, integer=True, k=3):
    """Plausible wrong numbers near ans, all distinct, all positive when ans is positive."""
    out = []
    spread = spread or max(1, abs(ans) // 10 or 1)
    tries = 0
    candidates = []
    if integer:
        candidates += [ans + spread, ans - spread, ans + 2 * spread, ans - 2 * spread, ans + 1, ans - 1,
                       ans * 2, ans // 2 if ans > 3 else ans + 3, ans + 10, ans - 10]
        s = str(abs(ans))
        if len(s) >= 2 and s[0] != s[1]:
            sw = int(s[1] + s[0] + s[2:])
            candidates.append(sw if ans >= 0 else -sw)
    rng.shuffle(candidates)
    for c in candidates:
        if c != ans and c not in out and (ans <= 0 or c > 0):
            out.append(c)
        if len(out) == k:
            return out
    while len(out) < k and tries < 200:
        tries += 1
        c = ans + rng.randint(-3 * spread, 3 * spread)
        if c != ans and c not in out and (ans <= 0 or c > 0):
            out.append(c)
    return out


def fmt_num(x):
    if isinstance(x, Fraction):
        if x.denominator == 1:
            return str(x.numerator)
        return "%d/%d" % (x.numerator, x.denominator)
    if isinstance(x, float):
        if abs(x - round(x)) < 1e-9:
            return str(int(round(x)))
        return ("%.2f" % x).rstrip("0").rstrip(".")
    return str(x)


def add_numeric(b, cat, fam, diff, q_en, q_bn, ans, basis, spread=None, unit_en="", unit_bn="", prefix="MATH"):
    ds = num_distractors(b.rng, ans, spread)
    if len(ds) < 3:
        return False
    en = [fmt_num(ans) + unit_en] + [fmt_num(d) + unit_en for d in ds]
    bnn = [bn(fmt_num(ans)) + unit_bn] + [bn(fmt_num(d)) + unit_bn for d in ds]
    return b.add(cat, fam, diff, q_en, en[0], en[1:], basis, q_bn, bnn[0], bnn[1:], prefix=prefix)


# =============================================================================================
# 1. Mathematics (computed)
# =============================================================================================

MATH_FAM = ("bcs", "job")


def gen_math(b, rng):
    basis = "Computed by the generator"
    # percentages
    n = 0
    while n < 70:
        p = rng.choice([5, 10, 12, 15, 20, 25, 30, 35, 40, 45, 50, 60, 75, 80, 120, 150])
        base = rng.choice(range(40, 2001, 20))
        if (p * base) % 100:
            continue
        ans = p * base // 100
        n += add_numeric(b, "math_percent", MATH_FAM, 1,
                         "What is %d%% of %d?" % (p, base), "%s-এর %s%% কত?" % (bn(base), bn(p)), ans, basis)
    # percentage increase / decrease
    n = 0
    while n < 50:
        p = rng.choice([5, 10, 15, 20, 25, 30, 40, 50])
        price = rng.choice(range(100, 5001, 50))
        if (p * price) % 100:
            continue
        up = rng.random() < 0.5
        ans = price + p * price // 100 if up else price - p * price // 100
        word_en, word_bn = ("increases", "বাড়লে") if up else ("decreases", "কমলে")
        n += add_numeric(b, "math_percent", MATH_FAM, 2,
                         "A price of Tk %d %s by %d%%. What is the new price (Tk)?" % (price, word_en, p),
                         "%s টাকার দাম %s%% %s নতুন দাম কত টাকা?" % (bn(price), bn(p), word_bn), ans, basis)
    # profit and loss percent
    n = 0
    while n < 60:
        cost = rng.choice(range(100, 3001, 20))
        p = rng.choice([5, 10, 12, 15, 20, 25, 30, 40, 50])
        if (cost * p) % 100:
            continue
        gain = rng.random() < 0.6
        sell = cost + cost * p // 100 if gain else cost - cost * p // 100
        if gain:
            q_en = "An item bought for Tk %d is sold for Tk %d. What is the profit percent?" % (cost, sell)
            q_bn = "একটি জিনিস %s টাকায় কিনে %s টাকায় বিক্রি করলে শতকরা কত লাভ হয়?" % (bn(cost), bn(sell))
        else:
            q_en = "An item bought for Tk %d is sold for Tk %d. What is the loss percent?" % (cost, sell)
            q_bn = "একটি জিনিস %s টাকায় কিনে %s টাকায় বিক্রি করলে শতকরা কত ক্ষতি হয়?" % (bn(cost), bn(sell))
        n += add_numeric(b, "math_profit_loss", MATH_FAM, 2, q_en, q_bn, p, basis, spread=5, unit_en="%", unit_bn="%")
    # simple interest
    n = 0
    while n < 60:
        P = rng.choice(range(1000, 50001, 500))
        r = rng.choice([4, 5, 6, 7, 8, 9, 10, 12])
        t = rng.choice([2, 3, 4, 5, 6])
        if (P * r * t) % 100:
            continue
        ans = P * r * t // 100
        n += add_numeric(b, "math_interest", MATH_FAM, 2,
                         "What is the simple interest on Tk %d at %d%% per year for %d years (Tk)?" % (P, r, t),
                         "বার্ষিক %s%% সরল সুদে %s টাকার %s বছরের সুদ কত টাকা?" % (bn(r), bn(P), bn(t)), ans, basis)
    # ratio split
    n = 0
    while n < 50:
        a, c = rng.choice([(1, 2), (2, 3), (3, 4), (3, 5), (2, 5), (4, 5), (5, 7), (1, 3), (3, 7), (4, 7)])
        total = (a + c) * rng.randint(5, 60)
        big = total * c // (a + c)
        n += add_numeric(b, "math_ratio", MATH_FAM, 1,
                         "Tk %d is divided in the ratio %d:%d. What is the larger share (Tk)?" % (total, a, c),
                         "%s টাকা %s:%s অনুপাতে ভাগ করলে বড় অংশ কত টাকা?" % (bn(total), bn(a), bn(c)), big, basis)
    # averages
    n = 0
    while n < 45:
        k = rng.randint(4, 6)
        vals = [rng.randint(10, 99) for _ in range(k)]
        if sum(vals) % k:
            continue
        avg = sum(vals) // k
        n += add_numeric(b, "math_average", MATH_FAM, 1,
                         "What is the average of %s?" % ", ".join(map(str, vals)),
                         "%s সংখ্যাগুলোর গড় কত?" % ", ".join(bn(v) for v in vals), avg, basis)
    # LCM and HCF
    n = 0
    while n < 70:
        x = rng.randint(4, 72)
        y = rng.randint(4, 72)
        if x == y:
            continue
        if rng.random() < 0.5:
            ans = x * y // math.gcd(x, y)
            q_en, q_bn = "What is the LCM of %d and %d?" % (x, y), "%s ও %s-এর ল.সা.গু. কত?" % (bn(x), bn(y))
        else:
            ans = math.gcd(x, y)
            if ans == 1:
                continue
            q_en, q_bn = "What is the HCF of %d and %d?" % (x, y), "%s ও %s-এর গ.সা.গু. কত?" % (bn(x), bn(y))
        n += add_numeric(b, "math_lcm_hcf", MATH_FAM, 1, q_en, q_bn, ans, basis, spread=max(2, ans // 6))
    # time and work
    pairs = [(a, c) for a in range(2, 61) for c in range(a + 1, 91) if (a * c) % (a + c) == 0]
    rng.shuffle(pairs)
    for a, c in pairs[:40]:
        ans = a * c // (a + c)
        add_numeric(b, "math_work", MATH_FAM, 2,
                    "A can finish a job in %d days and B in %d days. Working together, how many days will they take?" % (a, c),
                    "ক একটি কাজ %s দিনে এবং খ %s দিনে করতে পারে। একসঙ্গে কাজটি কত দিনে শেষ করবে?" % (bn(a), bn(c)),
                    ans, basis, spread=max(1, ans // 4))
    # speed: distance / time, and train passing a pole
    n = 0
    while n < 30:
        v = rng.choice([20, 24, 30, 36, 40, 45, 48, 50, 54, 60, 72])
        t = rng.choice([2, 3, 4, 5, 6])
        d = v * t
        n += add_numeric(b, "math_speed", MATH_FAM, 1,
                         "A bus covers %d km in %d hours. What is its speed (km/h)?" % (d, t),
                         "একটি বাস %s ঘণ্টায় %s কিমি যায়। এর গতিবেগ ঘণ্টায় কত কিমি?" % (bn(t), bn(d)), v, basis)
    n = 0
    while n < 30:
        v = rng.choice([36, 45, 54, 72, 90, 108])
        ms = v * 5 // 18
        t = rng.choice([6, 8, 9, 10, 12, 15, 18, 20])
        L = ms * t
        n += add_numeric(b, "math_speed", MATH_FAM, 3,
                         "A %d m long train runs at %d km/h. In how many seconds does it pass a pole?" % (L, v),
                         "%s মিটার লম্বা একটি ট্রেন ঘণ্টায় %s কিমি বেগে চলে। একটি খুঁটি অতিক্রম করতে কত সেকেন্ড লাগবে?" % (bn(L), bn(v)),
                         t, basis, spread=2)
    # algebra
    n = 0
    while n < 40:
        x = rng.randint(3, 40)
        y = rng.randint(1, x - 1)
        if rng.random() < 0.5:
            n += add_numeric(b, "math_algebra", MATH_FAM, 2,
                             "If x + y = %d and x − y = %d, what is x?" % (x + y, x - y),
                             "x + y = %s এবং x − y = %s হলে x-এর মান কত?" % (bn(x + y), bn(x - y)), x, basis, spread=2)
        else:
            n += add_numeric(b, "math_algebra", MATH_FAM, 2,
                             "If a + b = %d and a − b = %d, what is a² − b²?" % (x + y, x - y),
                             "a + b = %s এবং a − b = %s হলে a² − b²-এর মান কত?" % (bn(x + y), bn(x - y)),
                             (x + y) * (x - y), basis)
    # geometry
    n = 0
    while n < 25:
        l, w = rng.randint(5, 60), rng.randint(3, 40)
        if rng.random() < 0.5:
            n += add_numeric(b, "math_geometry", MATH_FAM, 1,
                             "What is the area (sq m) of a rectangle %d m long and %d m wide?" % (l, w),
                             "%s মিটার দৈর্ঘ্য ও %s মিটার প্রস্থের আয়তক্ষেত্রের ক্ষেত্রফল কত বর্গমিটার?" % (bn(l), bn(w)), l * w, basis)
        else:
            n += add_numeric(b, "math_geometry", MATH_FAM, 1,
                             "What is the perimeter (m) of a rectangle %d m long and %d m wide?" % (l, w),
                             "%s মিটার দৈর্ঘ্য ও %s মিটার প্রস্থের আয়তক্ষেত্রের পরিসীমা কত মিটার?" % (bn(l), bn(w)), 2 * (l + w), basis)
    for r in [7, 14, 21, 28, 35, 42]:
        add_numeric(b, "math_geometry", MATH_FAM, 2,
                    "Taking π = 22/7, what is the area (sq cm) of a circle of radius %d cm?" % r,
                    "π = ২২/৭ ধরে %s সেমি ব্যাসার্ধের বৃত্তের ক্ষেত্রফল কত বর্গসেমি?" % bn(r), 22 * r * r // 7, basis)
        add_numeric(b, "math_geometry", MATH_FAM, 2,
                    "Taking π = 22/7, what is the circumference (cm) of a circle of radius %d cm?" % r,
                    "π = ২২/৭ ধরে %s সেমি ব্যাসার্ধের বৃত্তের পরিধি কত সেমি?" % bn(r), 44 * r // 7, basis)
    n = 0
    while n < 20:
        base, h = rng.randint(4, 40), rng.randint(4, 40)
        if (base * h) % 2:
            continue
        n += add_numeric(b, "math_geometry", MATH_FAM, 1,
                         "What is the area (sq m) of a triangle with base %d m and height %d m?" % (base, h),
                         "ভূমি %s মিটার ও উচ্চতা %s মিটার হলে ত্রিভুজের ক্ষেত্রফল কত বর্গমিটার?" % (bn(base), bn(h)), base * h // 2, basis)
    # roots
    for r in range(11, 46):
        add_numeric(b, "math_roots", MATH_FAM, 1, "What is the square root of %d?" % (r * r),
                    "%s-এর বর্গমূল কত?" % bn(r * r), r, basis, spread=2)
    for r in range(4, 16):
        add_numeric(b, "math_roots", MATH_FAM, 2, "What is the cube root of %d?" % (r ** 3),
                    "%s-এর ঘনমূল কত?" % bn(r ** 3), r, basis, spread=1)
    # series
    n = 0
    while n < 45:
        kind = rng.choice(["ap", "gp", "sq"])
        if kind == "ap":
            a0, d = rng.randint(1, 30), rng.randint(2, 12)
            seq = [a0 + i * d for i in range(5)]
        elif kind == "gp":
            a0, r = rng.randint(1, 5), rng.choice([2, 3])
            seq = [a0 * r ** i for i in range(5)]
        else:
            s0 = rng.randint(1, 12)
            seq = [(s0 + i) ** 2 for i in range(5)]
        shown = seq[:4]
        n += add_numeric(b, "math_series", MATH_FAM, 2,
                         "What comes next: %s, ?" % ", ".join(map(str, shown)),
                         "পরের সংখ্যাটি কত: %s, ?" % ", ".join(bn(v) for v in shown), seq[4], basis,
                         spread=max(2, (seq[4] - seq[3]) // 2))
    # fractions
    n = 0
    while n < 30:
        f1 = Fraction(rng.randint(1, 5), rng.choice([2, 3, 4, 5, 6, 8]))
        f2 = Fraction(rng.randint(1, 5), rng.choice([2, 3, 4, 5, 6, 8]))
        s = f1 + f2
        if s.denominator == 1:
            continue
        wrong = {Fraction(f1.numerator + f2.numerator, f1.denominator + f2.denominator), s + Fraction(1, s.denominator),
                 s - Fraction(1, s.denominator), f1 * f2, s + 1}
        wrong.discard(s)
        wrong = [w for w in wrong if w > 0]
        if len(wrong) < 3:
            continue
        ws = rng.sample(wrong, 3)
        n += b.add("math_fraction", MATH_FAM, 2,
                   "What is %s + %s?" % (fmt_num(f1), fmt_num(f2)), fmt_num(s), [fmt_num(w) for w in ws], basis,
                   "%s + %s = কত?" % (bn(fmt_num(f1)), bn(fmt_num(f2))), bn(fmt_num(s)), [bn(fmt_num(w)) for w in ws], prefix="MATH")
    # unit conversion
    conv = [("km", "m", 1000, "কিমি", "মিটার"), ("kg", "g", 1000, "কেজি", "গ্রাম"), ("hours", "minutes", 60, "ঘণ্টা", "মিনিট"),
            ("metres", "centimetres", 100, "মিটার", "সেন্টিমিটার"), ("litres", "millilitres", 1000, "লিটার", "মিলিলিটার")]
    for (u1, u2, f, b1, b2) in conv:
        for v in rng.sample(range(2, 30), 5):
            add_numeric(b, "math_units", MATH_FAM, 1, "How many %s are there in %d %s?" % (u2, v, u1),
                        "%s %s = কত %s?" % (bn(v), b1, b2), v * f, basis, spread=f)


# =============================================================================================
# 2. ICT (computed + acronyms)
# =============================================================================================

def gen_ict(b, rng):
    basis = "Computed by the generator"
    fam = ("bcs", "job")
    nums = rng.sample(range(5, 256), 60)
    for v in nums[:30]:
        ans = bin(v)[2:]
        wrong = set()
        while len(wrong) < 3:
            w = bin(max(1, v + rng.choice([-3, -2, -1, 1, 2, 3, 4, 8])))[2:]
            if w != ans:
                wrong.add(w)
        b.add("ict_number", fam, 2, "What is %d (decimal) in binary?" % v, ans, sorted(wrong), basis,
              "দশমিক %s-কে বাইনারিতে লিখলে কী হয়?" % bn(v), ans, sorted(wrong), prefix="ICT")
    for v in nums[30:]:
        add_numeric(b, "ict_number", fam, 2, "What is binary %s in decimal?" % bin(v)[2:],
                    "বাইনারি %s-এর দশমিক মান কত?" % bin(v)[2:], v, basis, spread=2, prefix="ICT")
    for v in rng.sample(range(16, 256), 25):
        ans = format(v, "X")
        wrong = set()
        while len(wrong) < 3:
            w = format(max(1, v + rng.choice([-17, -16, -1, 1, 16, 17, 32])), "X")
            if w != ans:
                wrong.add(w)
        b.add("ict_number", fam, 2, "What is %d (decimal) in hexadecimal?" % v, ans, sorted(wrong), basis,
              "দশমিক %s-কে হেক্সাডেসিমালে লিখলে কী হয়?" % bn(v), ans, sorted(wrong), prefix="ICT")
    for v in rng.sample(range(8, 200), 15):
        add_numeric(b, "ict_number", fam, 2, "What is octal %s in decimal?" % format(v, "o"),
                    "অক্টাল %s-এর দশমিক মান কত?" % format(v, "o"), v, basis, spread=2, prefix="ICT")
    gates = {"AND": lambda a, c: a & c, "OR": lambda a, c: a | c, "NAND": lambda a, c: 1 - (a & c),
             "NOR": lambda a, c: 1 - (a | c), "XOR": lambda a, c: a ^ c, "XNOR": lambda a, c: 1 - (a ^ c)}
    for g, f in gates.items():
        for a in (0, 1):
            for c in (0, 1):
                out = f(a, c)
                b.add("ict_logic", fam, 2, "What is the output of a 2-input %s gate when the inputs are %d and %d?" % (g, a, c),
                      str(out), [str(1 - out), "Undefined", "Both 0 and 1"], basis,
                      "%s গেটের দুই ইনপুট %s ও %s হলে আউটপুট কত?" % (g, bn(a), bn(c)), bn(out), [bn(1 - out), "অনির্ধারিত", "০ ও ১ দুটোই"], prefix="ICT")
    units = [("1 byte", "8 bits"), ("1 kilobyte (binary)", "1024 bytes"), ("1 megabyte (binary)", "1024 kilobytes"),
             ("1 gigabyte (binary)", "1024 megabytes"), ("1 terabyte (binary)", "1024 gigabytes"), ("1 nibble", "4 bits")]
    pool = [u[1] for u in units] + ["16 bits", "1000 bytes", "2048 bytes", "512 megabytes"]
    for k, v in units:
        ds = b.pick(pool, 3, [v])
        b.add("ict_units", fam, 1, "%s equals:" % k, v, ds, "Standard binary data units", prefix="ICT")
    acr = [("CPU", "Central Processing Unit"), ("RAM", "Random Access Memory"), ("ROM", "Read Only Memory"),
           ("ALU", "Arithmetic Logic Unit"), ("URL", "Uniform Resource Locator"), ("HTTP", "Hypertext Transfer Protocol"),
           ("HTML", "Hypertext Markup Language"), ("WWW", "World Wide Web"), ("LAN", "Local Area Network"),
           ("WAN", "Wide Area Network"), ("ISP", "Internet Service Provider"), ("PDF", "Portable Document Format"),
           ("USB", "Universal Serial Bus"), ("GUI", "Graphical User Interface"), ("BIOS", "Basic Input Output System"),
           ("DNS", "Domain Name System"), ("SMTP", "Simple Mail Transfer Protocol"), ("FTP", "File Transfer Protocol"),
           ("VPN", "Virtual Private Network"), ("SQL", "Structured Query Language"), ("IoT", "Internet of Things"),
           ("OCR", "Optical Character Recognition"), ("ASCII", "American Standard Code for Information Interchange"),
           ("LED", "Light Emitting Diode"), ("LCD", "Liquid Crystal Display"), ("GPS", "Global Positioning System"),
           ("SSD", "Solid State Drive"), ("HDD", "Hard Disk Drive"), ("IP", "Internet Protocol"),
           ("TCP", "Transmission Control Protocol"), ("Wi-Fi", "Wireless Fidelity (trademark name for wireless LAN)"),
           ("MICR", "Magnetic Ink Character Recognition"), ("OMR", "Optical Mark Recognition"),
           ("GPU", "Graphics Processing Unit"), ("OS", "Operating System"), ("CD-ROM", "Compact Disc Read Only Memory"),
           ("ICT", "Information and Communication Technology"), ("AI", "Artificial Intelligence")]
    full = [a[1] for a in acr]
    for a, f in acr:
        ds = b.pick(full, 3, [f])
        b.add("ict_acronym", fam, 1, "What does %s stand for?" % a, f, ds, "Standard computing abbreviation", prefix="ICT")
    facts = [
        ("Which part of a computer is called its brain?", "CPU", ["Monitor", "Keyboard", "Printer"]),
        ("Which memory is volatile (lost when power goes off)?", "RAM", ["ROM", "Hard disk", "Pen drive"]),
        ("Which of these is an input device?", "Keyboard", ["Monitor", "Printer", "Speaker"]),
        ("Which of these is an output device?", "Printer", ["Scanner", "Mouse", "Keyboard"]),
        ("Which number system does a computer use internally?", "Binary", ["Decimal", "Roman", "Octal only"]),
        ("Which of these is an operating system?", "Linux", ["MS Word", "Google Chrome", "Photoshop"]),
        ("Which of these is a web browser?", "Mozilla Firefox", ["MS Excel", "Windows", "Oracle"]),
        ("Which key combination copies selected text in Windows?", "Ctrl + C", ["Ctrl + V", "Ctrl + X", "Ctrl + Z"]),
        ("Which key combination pastes in Windows?", "Ctrl + V", ["Ctrl + C", "Ctrl + P", "Ctrl + S"]),
        ("Which key combination undoes the last action in Windows?", "Ctrl + Z", ["Ctrl + Y", "Ctrl + U", "Ctrl + A"]),
        ("A program that harms or spies on a computer is called:", "Malware", ["Firmware", "Freeware", "Middleware"]),
        ("Who is called the father of the computer?", "Charles Babbage", ["Alan Turing", "Bill Gates", "Tim Berners-Lee"]),
        ("Who invented the World Wide Web?", "Tim Berners-Lee", ["Charles Babbage", "Steve Jobs", "Vint Cerf"]),
        ("The smallest unit of data in a computer is:", "Bit", ["Byte", "Nibble", "Word"]),
        ("Which device connects different networks and forwards packets between them?", "Router", ["Monitor", "Scanner", "Plotter"]),
        ("Which of these is a spreadsheet program?", "Microsoft Excel", ["Microsoft Word", "Notepad", "Paint"]),
    ]
    for q, a, ds in facts:
        b.add("ict_basics", fam, 1, q, a, ds, "Standard computing fact", prefix="ICT")


# =============================================================================================
# 3. Bangladesh affairs
# =============================================================================================

DIVISIONS = {
    "Dhaka": ["Dhaka", "Gazipur", "Narayanganj", "Narsingdi", "Manikganj", "Munshiganj", "Tangail", "Kishoreganj",
              "Faridpur", "Gopalganj", "Madaripur", "Rajbari", "Shariatpur"],
    "Chattogram": ["Chattogram", "Cox's Bazar", "Bandarban", "Rangamati", "Khagrachhari", "Cumilla", "Brahmanbaria",
                   "Chandpur", "Feni", "Lakshmipur", "Noakhali"],
    "Rajshahi": ["Rajshahi", "Bogura", "Joypurhat", "Naogaon", "Natore", "Chapai Nawabganj", "Pabna", "Sirajganj"],
    "Khulna": ["Khulna", "Bagerhat", "Chuadanga", "Jashore", "Jhenaidah", "Kushtia", "Magura", "Meherpur", "Narail", "Satkhira"],
    "Barishal": ["Barishal", "Barguna", "Bhola", "Jhalokati", "Patuakhali", "Pirojpur"],
    "Sylhet": ["Sylhet", "Habiganj", "Moulvibazar", "Sunamganj"],
    "Rangpur": ["Rangpur", "Dinajpur", "Gaibandha", "Kurigram", "Lalmonirhat", "Nilphamari", "Panchagarh", "Thakurgaon"],
    "Mymensingh": ["Mymensingh", "Jamalpur", "Netrokona", "Sherpur"],
}
DIV_BN = {"Dhaka": "ঢাকা", "Chattogram": "চট্টগ্রাম", "Rajshahi": "রাজশাহী", "Khulna": "খুলনা", "Barishal": "বরিশাল",
          "Sylhet": "সিলেট", "Rangpur": "রংপুর", "Mymensingh": "ময়মনসিংহ"}

BD_FACTS = [
    # (question en, answer en, distractors en, question bn, answer bn, distractors bn, difficulty)
    ("When did the Language Movement reach its peak with the killings of 21 February?", "1952", ["1948", "1954", "1966"],
     "ভাষা আন্দোলনে ২১ ফেব্রুয়ারির শহীদ দিবস কোন সালের?", "১৯৫২", ["১৯৪৮", "১৯৫৪", "১৯৬৬"], 1),
    ("Which organisation declared 21 February International Mother Language Day?", "UNESCO", ["UNICEF", "UNDP", "WHO"],
     "২১ ফেব্রুয়ারিকে আন্তর্জাতিক মাতৃভাষা দিবস ঘোষণা করে কোন সংস্থা?", "ইউনেস্কো", ["ইউনিসেফ", "ইউএনডিপি", "বিশ্ব স্বাস্থ্য সংস্থা"], 1),
    ("In which year did UNESCO declare International Mother Language Day?", "1999", ["1997", "2000", "2001"],
     "ইউনেস্কো কত সালে আন্তর্জাতিক মাতৃভাষা দিবস ঘোষণা করে?", "১৯৯৯", ["১৯৯৭", "২০০০", "২০০১"], 2),
    ("Bangladesh's Independence Day is on:", "26 March", ["16 December", "21 February", "17 April"],
     "বাংলাদেশের স্বাধীনতা দিবস কবে?", "২৬ মার্চ", ["১৬ ডিসেম্বর", "২১ ফেব্রুয়ারি", "১৭ এপ্রিল"], 1),
    ("Bangladesh's Victory Day is on:", "16 December", ["26 March", "14 December", "7 March"],
     "বাংলাদেশের বিজয় দিবস কবে?", "১৬ ডিসেম্বর", ["২৬ মার্চ", "১৪ ডিসেম্বর", "৭ মার্চ"], 1),
    ("The Mujibnagar government took oath on:", "17 April 1971", ["10 April 1971", "26 March 1971", "16 December 1971"],
     "মুজিবনগর সরকার শপথ নেয় কবে?", "১৭ এপ্রিল ১৯৭১", ["১০ এপ্রিল ১৯৭১", "২৬ মার্চ ১৯৭১", "১৬ ডিসেম্বর ১৯৭১"], 2),
    ("The Mujibnagar government took oath in which present-day district?", "Meherpur", ["Kushtia", "Chuadanga", "Jashore"],
     "মুজিবনগর সরকার বর্তমান কোন জেলায় শপথ নেয়?", "মেহেরপুর", ["কুষ্টিয়া", "চুয়াডাঙ্গা", "যশোর"], 2),
    ("Into how many sectors was the Liberation War of 1971 divided?", "11", ["9", "10", "12"],
     "১৯৭১ সালের মুক্তিযুদ্ধে দেশকে কয়টি সেক্টরে ভাগ করা হয়েছিল?", "১১টি", ["৯টি", "১০টি", "১২টি"], 1),
    ("The Constitution of Bangladesh was adopted by the Constituent Assembly on:", "4 November 1972", ["16 December 1972", "26 March 1972", "10 April 1972"],
     "গণপরিষদে বাংলাদেশের সংবিধান গৃহীত হয় কবে?", "৪ নভেম্বর ১৯৭২", ["১৬ ডিসেম্বর ১৯৭২", "২৬ মার্চ ১৯৭২", "১০ এপ্রিল ১৯৭২"], 2),
    ("The Constitution of Bangladesh came into effect on:", "16 December 1972", ["4 November 1972", "26 March 1973", "1 January 1973"],
     "বাংলাদেশের সংবিধান কার্যকর হয় কবে?", "১৬ ডিসেম্বর ১৯৭২", ["৪ নভেম্বর ১৯৭২", "২৬ মার্চ ১৯৭৩", "১ জানুয়ারি ১৯৭৩"], 2),
    ("Bangladesh became a member of the United Nations on:", "17 September 1974", ["16 December 1972", "26 March 1974", "4 November 1974"],
     "বাংলাদেশ জাতিসংঘের সদস্যপদ লাভ করে কবে?", "১৭ সেপ্টেম্বর ১৯৭৪", ["১৬ ডিসেম্বর ১৯৭২", "২৬ মার্চ ১৯৭৪", "৪ নভেম্বর ১৯৭৪"], 2),
    ("How many articles does the Constitution of Bangladesh have?", "153", ["150", "152", "155"],
     "বাংলাদেশের সংবিধানে অনুচ্ছেদ কয়টি?", "১৫৩টি", ["১৫০টি", "১৫২টি", "১৫৫টি"], 1),
    ("How many administrative divisions does Bangladesh have?", "8", ["6", "7", "9"],
     "বাংলাদেশে বিভাগ কয়টি?", "৮টি", ["৬টি", "৭টি", "৯টি"], 1),
    ("How many districts does Bangladesh have?", "64", ["60", "62", "68"],
     "বাংলাদেশে জেলা কয়টি?", "৬৪টি", ["৬০টি", "৬২টি", "৬৮টি"], 1),
    ("The national flower of Bangladesh is:", "Water lily (shapla)", ["Rose", "Lotus", "Rajanigandha"],
     "বাংলাদেশের জাতীয় ফুল কোনটি?", "শাপলা", ["গোলাপ", "পদ্ম", "রজনীগন্ধা"], 1),
    ("The national fruit of Bangladesh is:", "Jackfruit", ["Mango", "Litchi", "Banana"],
     "বাংলাদেশের জাতীয় ফল কোনটি?", "কাঁঠাল", ["আম", "লিচু", "কলা"], 1),
    ("The national tree of Bangladesh is:", "Mango tree", ["Jackfruit tree", "Banyan tree", "Palm tree"],
     "বাংলাদেশের জাতীয় বৃক্ষ কোনটি?", "আমগাছ", ["কাঁঠালগাছ", "বটগাছ", "তালগাছ"], 1),
    ("The national bird of Bangladesh is:", "Magpie robin (doyel)", ["Kingfisher", "Myna", "Crow"],
     "বাংলাদেশের জাতীয় পাখি কোনটি?", "দোয়েল", ["মাছরাঙা", "ময়না", "কাক"], 1),
    ("The national animal of Bangladesh is:", "Royal Bengal Tiger", ["Elephant", "Deer", "Leopard"],
     "বাংলাদেশের জাতীয় পশু কোনটি?", "রয়েল বেঙ্গল টাইগার", ["হাতি", "হরিণ", "চিতাবাঘ"], 1),
    ("The national fish of Bangladesh is:", "Hilsa", ["Rohu", "Pangas", "Koi"],
     "বাংলাদেশের জাতীয় মাছ কোনটি?", "ইলিশ", ["রুই", "পাঙ্গাস", "কই"], 1),
    ("The national game of Bangladesh is:", "Kabaddi", ["Cricket", "Football", "Hockey"],
     "বাংলাদেশের জাতীয় খেলা কোনটি?", "কাবাডি", ["ক্রিকেট", "ফুটবল", "হকি"], 1),
    ("Who is the national poet of Bangladesh?", "Kazi Nazrul Islam", ["Rabindranath Tagore", "Jasimuddin", "Jibanananda Das"],
     "বাংলাদেশের জাতীয় কবি কে?", "কাজী নজরুল ইসলাম", ["রবীন্দ্রনাথ ঠাকুর", "জসীমউদ্‌দীন", "জীবনানন্দ দাশ"], 1),
    ("Who wrote Bangladesh's national anthem 'Amar Sonar Bangla'?", "Rabindranath Tagore", ["Kazi Nazrul Islam", "D. L. Roy", "Atulprasad Sen"],
     "'আমার সোনার বাংলা' জাতীয় সংগীতের রচয়িতা কে?", "রবীন্দ্রনাথ ঠাকুর", ["কাজী নজরুল ইসলাম", "দ্বিজেন্দ্রলাল রায়", "অতুলপ্রসাদ সেন"], 1),
    ("In which year was the Sundarbans listed as a UNESCO World Heritage Site?", "1997", ["1985", "1992", "2001"],
     "সুন্দরবন কত সালে ইউনেস্কো বিশ্ব ঐতিহ্যের তালিকায় স্থান পায়?", "১৯৯৭", ["১৯৮৫", "১৯৯২", "২০০১"], 2),
    ("The Paharpur Buddhist Vihara is in which district?", "Naogaon", ["Bogura", "Joypurhat", "Rajshahi"],
     "পাহাড়পুর বৌদ্ধবিহার কোন জেলায়?", "নওগাঁ", ["বগুড়া", "জয়পুরহাট", "রাজশাহী"], 1),
    ("The Sixty Dome Mosque (Shat Gambuj) is in which district?", "Bagerhat", ["Khulna", "Jashore", "Satkhira"],
     "ষাটগম্বুজ মসজিদ কোন জেলায়?", "বাগেরহাট", ["খুলনা", "যশোর", "সাতক্ষীরা"], 1),
    ("The Padma Bridge was opened on:", "25 June 2022", ["16 December 2021", "26 March 2022", "1 January 2023"],
     "পদ্মা সেতু উদ্বোধন করা হয় কবে?", "২৫ জুন ২০২২", ["১৬ ডিসেম্বর ২০২১", "২৬ মার্চ ২০২২", "১ জানুয়ারি ২০২৩"], 2),
    ("What is the length of the Padma (multipurpose) Bridge?", "6.15 km", ["4.8 km", "5.5 km", "7.2 km"],
     "পদ্মা বহুমুখী সেতুর দৈর্ঘ্য কত?", "৬.১৫ কিমি", ["৪.৮ কিমি", "৫.৫ কিমি", "৭.২ কিমি"], 2),
    ("Bangladesh's first communications satellite was launched on:", "12 May 2018", ["16 December 2017", "26 March 2018", "1 July 2019"],
     "বাংলাদেশের প্রথম যোগাযোগ উপগ্রহ উৎক্ষেপণ করা হয় কবে?", "১২ মে ২০১৮", ["১৬ ডিসেম্বর ২০১৭", "২৬ মার্চ ২০১৮", "১ জুলাই ২০১৯"], 2),
    ("Dhaka's metro rail first carried passengers on:", "28 December 2022", ["16 December 2022", "1 January 2023", "26 March 2022"],
     "ঢাকার মেট্রোরেল প্রথম যাত্রী নিয়ে চলে কবে?", "২৮ ডিসেম্বর ২০২২", ["১৬ ডিসেম্বর ২০২২", "১ জানুয়ারি ২০২৩", "২৬ মার্চ ২০২২"], 2),
    ("The Rooppur Nuclear Power Plant is in which district?", "Pabna", ["Rajshahi", "Kushtia", "Natore"],
     "রূপপুর পারমাণবিক বিদ্যুৎকেন্দ্র কোন জেলায়?", "পাবনা", ["রাজশাহী", "কুষ্টিয়া", "নাটোর"], 1),
    ("The Supreme Court of Bangladesh has two divisions. They are:", "Appellate Division and High Court Division",
     ["Civil Division and Criminal Division", "Appellate Division and District Division", "High Court Division and Tribunal Division"],
     "বাংলাদেশ সুপ্রিম কোর্টের দুটি বিভাগ কী কী?", "আপিল বিভাগ ও হাইকোর্ট বিভাগ",
     ["দেওয়ানি বিভাগ ও ফৌজদারি বিভাগ", "আপিল বিভাগ ও জেলা বিভাগ", "হাইকোর্ট বিভাগ ও ট্রাইব্যুনাল বিভাগ"], 2),
    ("The largest mangrove forest in the world is:", "The Sundarbans", ["Lawachara", "Bhawal", "Madhupur"],
     "পৃথিবীর বৃহত্তম ম্যানগ্রোভ বন কোনটি?", "সুন্দরবন", ["লাউয়াছড়া", "ভাওয়াল", "মধুপুর"], 1),
    ("Which Bangladeshi city is known as the 'port city'?", "Chattogram", ["Khulna", "Barishal", "Narayanganj"],
     "বাংলাদেশের কোন শহরকে 'বন্দর নগরী' বলা হয়?", "চট্টগ্রাম", ["খুলনা", "বরিশাল", "নারায়ণগঞ্জ"], 1),
    ("The Kaptai hydroelectric project is in which district?", "Rangamati", ["Bandarban", "Khagrachhari", "Chattogram"],
     "কাপ্তাই জলবিদ্যুৎ প্রকল্প কোন জেলায়?", "রাঙামাটি", ["বান্দরবান", "খাগড়াছড়ি", "চট্টগ্রাম"], 1),
    ("The Lalbagh Fort is in which city?", "Dhaka", ["Sonargaon", "Chattogram", "Rajshahi"],
     "লালবাগ কেল্লা কোন শহরে?", "ঢাকা", ["সোনারগাঁও", "চট্টগ্রাম", "রাজশাহী"], 1),
    ("Sonargaon, the old capital of Bengal's Isa Khan era, is in which district?", "Narayanganj", ["Munshiganj", "Narsingdi", "Gazipur"],
     "ঈসা খাঁর আমলের রাজধানী সোনারগাঁও কোন জেলায়?", "নারায়ণগঞ্জ", ["মুন্সিগঞ্জ", "নরসিংদী", "গাজীপুর"], 1),
    ("The Jatrabari–Gulistan flyover in Dhaka is named after:", "Mayor Mohammad Hanif", ["Sheikh Fazilatunnesa", "Bir Uttam Ziaur Rahman", "Mayor Annisul Huq"],
     "ঢাকার যাত্রাবাড়ী–গুলিস্তান ফ্লাইওভারটি কার নামে?", "মেয়র মোহাম্মদ হানিফ", ["শেখ ফজিলাতুন্নেছা", "বীর উত্তম জিয়াউর রহমান", "মেয়র আনিসুল হক"], 2),
    ("Which national highway (N1) does the Kajla–Shonir Akhra stretch of Jatrabari lie on?", "Dhaka–Chattogram highway", ["Dhaka–Mawa highway", "Dhaka–Aricha highway", "Dhaka–Mymensingh highway"],
     "যাত্রাবাড়ীর কাজলা–শনির আখড়া অংশ কোন মহাসড়কে (এন১)?", "ঢাকা–চট্টগ্রাম মহাসড়ক", ["ঢাকা–মাওয়া মহাসড়ক", "ঢাকা–আরিচা মহাসড়ক", "ঢাকা–ময়মনসিংহ মহাসড়ক"], 2),
]


def gen_bangladesh(b, rng):
    fam = ("bcs", "job")
    for q_en, a_en, d_en, q_bn, a_bn, d_bn, diff in BD_FACTS:
        b.add("bangladesh", fam, diff, q_en, a_en, d_en, "Fact table: Bangladesh affairs", q_bn, a_bn, d_bn, prefix="BD")
    divs = list(DIVISIONS)
    for div, districts in DIVISIONS.items():
        for d in districts:
            if d == div:
                continue
            others = [x for x in divs if x != div]
            ds = rng.sample(others, 3)
            b.add("bangladesh_geo", fam, 1, "%s district is in which division?" % d, div, ds,
                  "Fact table: districts of Bangladesh by division (8 divisions, 64 districts)", prefix="BD")
    # "which of these is in X division"
    for div, districts in DIVISIONS.items():
        for _ in range(4):
            ans = rng.choice(districts)
            outside = [x for k, v in DIVISIONS.items() if k != div for x in v]
            ds = rng.sample(outside, 3)
            b.add("bangladesh_geo", fam, 2, "Which of these districts is in %s division?" % div, ans, ds,
                  "Fact table: districts of Bangladesh by division", prefix="BD")


# =============================================================================================
# 4. International affairs
# =============================================================================================

CAPITALS = [
    ("Afghanistan", "Kabul"), ("Algeria", "Algiers"), ("Angola", "Luanda"), ("Argentina", "Buenos Aires"),
    ("Armenia", "Yerevan"), ("Australia", "Canberra"), ("Austria", "Vienna"), ("Azerbaijan", "Baku"),
    ("Bahrain", "Manama"), ("Belarus", "Minsk"), ("Belgium", "Brussels"), ("Bhutan", "Thimphu"),
    ("Botswana", "Gaborone"), ("Brazil", "Brasília"), ("Brunei", "Bandar Seri Begawan"), ("Cambodia", "Phnom Penh"),
    ("Cameroon", "Yaoundé"), ("Canada", "Ottawa"), ("Chad", "N'Djamena"), ("Chile", "Santiago"), ("China", "Beijing"),
    ("Colombia", "Bogotá"), ("Croatia", "Zagreb"), ("Cuba", "Havana"), ("Cyprus", "Nicosia"), ("Czechia", "Prague"),
    ("Denmark", "Copenhagen"), ("Ecuador", "Quito"), ("Egypt", "Cairo"), ("Estonia", "Tallinn"),
    ("Ethiopia", "Addis Ababa"), ("Fiji", "Suva"), ("Finland", "Helsinki"), ("France", "Paris"), ("Georgia", "Tbilisi"),
    ("Germany", "Berlin"), ("Ghana", "Accra"), ("Greece", "Athens"), ("Hungary", "Budapest"), ("Iceland", "Reykjavík"),
    ("India", "New Delhi"), ("Iran", "Tehran"), ("Iraq", "Baghdad"), ("Ireland", "Dublin"), ("Italy", "Rome"),
    ("Jamaica", "Kingston"), ("Japan", "Tokyo"), ("Jordan", "Amman"), ("Kenya", "Nairobi"), ("Kuwait", "Kuwait City"),
    ("Kyrgyzstan", "Bishkek"), ("Laos", "Vientiane"), ("Latvia", "Riga"), ("Lebanon", "Beirut"), ("Libya", "Tripoli"),
    ("Lithuania", "Vilnius"), ("Madagascar", "Antananarivo"), ("Malaysia", "Kuala Lumpur"), ("Maldives", "Malé"),
    ("Mali", "Bamako"), ("Malta", "Valletta"), ("Mexico", "Mexico City"), ("Mongolia", "Ulaanbaatar"), ("Morocco", "Rabat"),
    ("Mozambique", "Maputo"), ("Myanmar", "Naypyidaw"), ("Namibia", "Windhoek"), ("Nepal", "Kathmandu"),
    ("New Zealand", "Wellington"), ("Niger", "Niamey"), ("Nigeria", "Abuja"), ("North Korea", "Pyongyang"),
    ("Norway", "Oslo"), ("Oman", "Muscat"), ("Pakistan", "Islamabad"), ("Papua New Guinea", "Port Moresby"),
    ("Paraguay", "Asunción"), ("Peru", "Lima"), ("Philippines", "Manila"), ("Poland", "Warsaw"), ("Portugal", "Lisbon"),
    ("Qatar", "Doha"), ("Romania", "Bucharest"), ("Russia", "Moscow"), ("Rwanda", "Kigali"), ("Saudi Arabia", "Riyadh"),
    ("Senegal", "Dakar"), ("Serbia", "Belgrade"), ("Singapore", "Singapore"), ("Slovakia", "Bratislava"),
    ("Slovenia", "Ljubljana"), ("Somalia", "Mogadishu"), ("South Korea", "Seoul"), ("Spain", "Madrid"),
    ("Sweden", "Stockholm"), ("Switzerland", "Bern"), ("Syria", "Damascus"), ("Tajikistan", "Dushanbe"),
    ("Thailand", "Bangkok"), ("Timor-Leste", "Dili"), ("Tunisia", "Tunis"), ("Turkey", "Ankara"),
    ("Turkmenistan", "Ashgabat"), ("Uganda", "Kampala"), ("Ukraine", "Kyiv"), ("United Arab Emirates", "Abu Dhabi"),
    ("United Kingdom", "London"), ("United States", "Washington, D.C."), ("Uruguay", "Montevideo"),
    ("Uzbekistan", "Tashkent"), ("Venezuela", "Caracas"), ("Vietnam", "Hanoi"), ("Zambia", "Lusaka"), ("Zimbabwe", "Harare"),
]
# famous wrong answers that make good distractors
CAPITAL_TRAPS = {"Australia": ["Sydney", "Melbourne"], "Canada": ["Toronto", "Montreal"], "Turkey": ["Istanbul"],
                 "Brazil": ["Rio de Janeiro", "São Paulo"], "Switzerland": ["Zurich", "Geneva"], "New Zealand": ["Auckland"],
                 "Pakistan": ["Karachi", "Lahore"], "Myanmar": ["Yangon"], "Nigeria": ["Lagos"], "Morocco": ["Casablanca"],
                 "United Arab Emirates": ["Dubai"], "United States": ["New York"], "India": ["Mumbai", "Kolkata"],
                 "Vietnam": ["Ho Chi Minh City"], "China": ["Shanghai"], "Saudi Arabia": ["Jeddah"]}

CURRENCIES = [
    ("Bangladesh", "Taka"), ("India", "Rupee"), ("Pakistan", "Rupee"), ("Nepal", "Rupee"), ("Sri Lanka", "Rupee"),
    ("Bhutan", "Ngultrum"), ("Maldives", "Rufiyaa"), ("Myanmar", "Kyat"), ("Thailand", "Baht"), ("Malaysia", "Ringgit"),
    ("Indonesia", "Rupiah"), ("Philippines", "Peso"), ("Vietnam", "Dong"), ("Cambodia", "Riel"), ("Laos", "Kip"),
    ("China", "Yuan (Renminbi)"), ("Japan", "Yen"), ("South Korea", "Won"), ("Mongolia", "Tugrik"),
    ("Afghanistan", "Afghani"), ("Iran", "Rial"), ("Iraq", "Dinar"), ("Saudi Arabia", "Riyal"), ("United Arab Emirates", "Dirham"),
    ("Qatar", "Riyal"), ("Kuwait", "Dinar"), ("Bahrain", "Dinar"), ("Oman", "Rial"), ("Jordan", "Dinar"), ("Turkey", "Lira"),
    ("Egypt", "Pound"), ("Kenya", "Shilling"), ("Nigeria", "Naira"), ("Ghana", "Cedi"), ("South Africa", "Rand"),
    ("Ethiopia", "Birr"), ("Morocco", "Dirham"), ("Algeria", "Dinar"), ("Botswana", "Pula"), ("Angola", "Kwanza"),
    ("Russia", "Ruble"), ("Ukraine", "Hryvnia"), ("Poland", "Zloty"), ("Czechia", "Koruna"), ("Hungary", "Forint"),
    ("Romania", "Leu"), ("United Kingdom", "Pound sterling"), ("Switzerland", "Swiss franc"), ("Sweden", "Krona"),
    ("Norway", "Krone"), ("Denmark", "Krone"), ("United States", "Dollar"), ("Canada", "Dollar"), ("Mexico", "Peso"),
    ("Brazil", "Real"), ("Argentina", "Peso"), ("Peru", "Sol"), ("Australia", "Dollar"), ("New Zealand", "Dollar"),
    ("Germany", "Euro"), ("France", "Euro"), ("Italy", "Euro"), ("Spain", "Euro"), ("Netherlands", "Euro"),
]

HQ = [
    ("United Nations", "New York"), ("UNESCO", "Paris"), ("World Health Organization (WHO)", "Geneva"),
    ("International Monetary Fund (IMF)", "Washington, D.C."), ("World Bank", "Washington, D.C."),
    ("World Trade Organization (WTO)", "Geneva"), ("International Labour Organization (ILO)", "Geneva"),
    ("Food and Agriculture Organization (FAO)", "Rome"), ("UNICEF", "New York"), ("UNHCR", "Geneva"),
    ("International Atomic Energy Agency (IAEA)", "Vienna"), ("OPEC", "Vienna"), ("ASEAN Secretariat", "Jakarta"),
    ("SAARC Secretariat", "Kathmandu"), ("NATO", "Brussels"), ("European Union (Commission)", "Brussels"),
    ("African Union", "Addis Ababa"), ("Organisation of Islamic Cooperation (OIC)", "Jeddah"), ("Interpol", "Lyon"),
    ("International Court of Justice", "The Hague"), ("International Criminal Court", "The Hague"),
    ("International Committee of the Red Cross", "Geneva"), ("Amnesty International", "London"),
    ("Asian Development Bank", "Manila"), ("Islamic Development Bank", "Jeddah"), ("BIMSTEC Secretariat", "Dhaka"),
    ("World Intellectual Property Organization (WIPO)", "Geneva"), ("World Meteorological Organization (WMO)", "Geneva"),
    ("International Telecommunication Union (ITU)", "Geneva"), ("Universal Postal Union", "Bern"),
    ("International Maritime Organization", "London"), ("International Civil Aviation Organization (ICAO)", "Montreal"),
    ("UN Environment Programme (UNEP)", "Nairobi"), ("UN-Habitat", "Nairobi"), ("UNIDO", "Vienna"), ("IFAD", "Rome"),
    ("World Food Programme", "Rome"), ("UNDP", "New York"), ("Commonwealth Secretariat", "London"),
]

INTL_FACTS = [
    ("Which is the largest ocean?", "Pacific Ocean", ["Atlantic Ocean", "Indian Ocean", "Arctic Ocean"], 1),
    ("Which is the longest river in the world (by most standard measures)?", "Nile", ["Amazon", "Yangtze", "Mississippi"], 2),
    ("The highest mountain peak above sea level is:", "Mount Everest", ["K2", "Kangchenjunga", "Makalu"], 1),
    ("Which is the largest country by area?", "Russia", ["Canada", "China", "United States"], 1),
    ("Which is the smallest country in the world?", "Vatican City", ["Monaco", "San Marino", "Liechtenstein"], 1),
    ("The Suez Canal links the Mediterranean Sea with:", "The Red Sea", ["The Black Sea", "The Arabian Sea", "The Caspian Sea"], 1),
    ("The Panama Canal links the Atlantic Ocean with:", "The Pacific Ocean", ["The Indian Ocean", "The Arctic Ocean", "The Caribbean only"], 1),
    ("How many permanent members does the UN Security Council have?", "5", ["4", "6", "10"], 1),
    ("The UN Charter was signed in 1945 in which city?", "San Francisco", ["New York", "Geneva", "London"], 2),
    ("SAARC was founded in 1985 in which city?", "Dhaka", ["Kathmandu", "New Delhi", "Islamabad"], 2),
    ("The 'Land of the Rising Sun' is:", "Japan", ["China", "South Korea", "Thailand"], 1),
    ("The 'Land of Thunder Dragon' is:", "Bhutan", ["Nepal", "Tibet", "Mongolia"], 1),
    ("Which line separates India and Pakistan in Punjab (drawn in 1947)?", "Radcliffe Line", ["Durand Line", "McMahon Line", "Maginot Line"], 2),
    ("The Durand Line is the border between Pakistan and:", "Afghanistan", ["India", "Iran", "China"], 2),
    ("The McMahon Line is a boundary between India and:", "China (Tibet)", ["Nepal", "Bhutan", "Myanmar"], 2),
    ("Which country gifted the Statue of Liberty to the United States?", "France", ["United Kingdom", "Spain", "Italy"], 1),
    ("The Great Barrier Reef lies off the coast of:", "Australia", ["Indonesia", "Philippines", "New Zealand"], 1),
    ("The Sahara desert is in:", "Africa", ["Asia", "Australia", "South America"], 1),
    ("The Kyoto Protocol is about:", "Greenhouse gas emissions", ["Nuclear weapons", "Ozone layer only", "Whaling"], 2),
    ("The Montreal Protocol protects:", "The ozone layer", ["Wetlands", "Migratory birds", "Ocean fisheries"], 2),
    ("The Ramsar Convention concerns:", "Wetlands", ["Deserts", "Ozone", "Nuclear tests"], 2),
    ("The Nobel Prizes are awarded mainly from which country (Peace Prize from Norway)?", "Sweden", ["Denmark", "Finland", "Switzerland"], 2),
]


def gen_international(b, rng):
    fam = ("bcs", "job")
    caps = [c for _, c in CAPITALS]
    for country, cap in CAPITALS:
        traps = [t for t in CAPITAL_TRAPS.get(country, []) if t != cap]
        pool = traps + rng.sample([c for c in caps if c != cap], 6)
        ds = list(dict.fromkeys(pool))[:3]
        b.add("international_capitals", fam, 1 if country in ("India", "Japan", "China", "France", "United Kingdom") else 2,
              "What is the capital of %s?" % country, cap, ds, "Fact table: national capitals", prefix="INT")
    # reverse: "X is the capital of"
    for country, cap in rng.sample(CAPITALS, 50):
        if cap == "Singapore" or cap == "Kuwait City":
            continue
        others = [c for c, _ in CAPITALS if c != country]
        b.add("international_capitals", fam, 2, "%s is the capital of:" % cap, country, rng.sample(others, 3),
              "Fact table: national capitals", prefix="INT")
    names = sorted(set(c for _, c in CURRENCIES))
    for country, cur in CURRENCIES:
        ds = b.pick(names, 3, [cur])
        b.add("international_currency", fam, 2, "What is the currency of %s?" % country, cur, ds,
              "Fact table: national currencies", prefix="INT")
    cities = sorted(set(c for _, c in HQ))
    for org, city in HQ:
        ds = b.pick(cities, 3, [city])
        b.add("international_orgs", fam, 2, "Where is the headquarters of the %s?" % org, city, ds,
              "Fact table: headquarters of international organisations", prefix="INT")
    for q, a, ds, diff in INTL_FACTS:
        b.add("international", fam, diff, q, a, ds, "Fact table: world geography and institutions", prefix="INT")


# =============================================================================================
# 5. General science
# =============================================================================================

ELEMENTS = [
    ("Hydrogen", "H", 1), ("Helium", "He", 2), ("Lithium", "Li", 3), ("Beryllium", "Be", 4), ("Boron", "B", 5),
    ("Carbon", "C", 6), ("Nitrogen", "N", 7), ("Oxygen", "O", 8), ("Fluorine", "F", 9), ("Neon", "Ne", 10),
    ("Sodium", "Na", 11), ("Magnesium", "Mg", 12), ("Aluminium", "Al", 13), ("Silicon", "Si", 14),
    ("Phosphorus", "P", 15), ("Sulfur", "S", 16), ("Chlorine", "Cl", 17), ("Argon", "Ar", 18), ("Potassium", "K", 19),
    ("Calcium", "Ca", 20), ("Titanium", "Ti", 22), ("Chromium", "Cr", 24), ("Manganese", "Mn", 25), ("Iron", "Fe", 26),
    ("Cobalt", "Co", 27), ("Nickel", "Ni", 28), ("Copper", "Cu", 29), ("Zinc", "Zn", 30), ("Arsenic", "As", 33),
    ("Selenium", "Se", 34), ("Bromine", "Br", 35), ("Krypton", "Kr", 36), ("Strontium", "Sr", 38), ("Silver", "Ag", 47),
    ("Tin", "Sn", 50), ("Antimony", "Sb", 51), ("Iodine", "I", 53), ("Xenon", "Xe", 54), ("Caesium", "Cs", 55),
    ("Barium", "Ba", 56), ("Tungsten", "W", 74), ("Platinum", "Pt", 78), ("Gold", "Au", 79), ("Mercury", "Hg", 80),
    ("Lead", "Pb", 82), ("Bismuth", "Bi", 83), ("Radon", "Rn", 86), ("Radium", "Ra", 88), ("Uranium", "U", 92),
    ("Plutonium", "Pu", 94),
]
SI_UNITS = [("Force", "Newton"), ("Energy (work)", "Joule"), ("Power", "Watt"), ("Pressure", "Pascal"),
            ("Frequency", "Hertz"), ("Electric current", "Ampere"), ("Electric charge", "Coulomb"),
            ("Electric potential difference", "Volt"), ("Electrical resistance", "Ohm"), ("Capacitance", "Farad"),
            ("Inductance", "Henry"), ("Magnetic flux", "Weber"), ("Magnetic flux density", "Tesla"),
            ("Thermodynamic temperature", "Kelvin"), ("Amount of substance", "Mole"), ("Luminous intensity", "Candela"),
            ("Mass", "Kilogram"), ("Time", "Second"), ("Illuminance", "Lux"), ("Radioactivity (activity)", "Becquerel")]
SCIENCE_FACTS = [
    ("Deficiency of vitamin C causes:", "Scurvy", ["Rickets", "Night blindness", "Beriberi"]),
    ("Deficiency of vitamin D in children causes:", "Rickets", ["Scurvy", "Goitre", "Anaemia"]),
    ("Deficiency of vitamin A causes:", "Night blindness", ["Scurvy", "Rickets", "Pellagra"]),
    ("Deficiency of vitamin B1 (thiamine) causes:", "Beriberi", ["Scurvy", "Rickets", "Night blindness"]),
    ("Which vitamin is essential for blood clotting?", "Vitamin K", ["Vitamin A", "Vitamin C", "Vitamin E"]),
    ("Iodine deficiency mainly causes:", "Goitre", ["Diabetes", "Scurvy", "Rickets"]),
    ("Insulin is produced by the:", "Pancreas", ["Liver", "Kidney", "Thyroid"]),
    ("The largest organ of the human body is the:", "Skin", ["Liver", "Brain", "Lungs"]),
    ("The largest gland of the human body is the:", "Liver", ["Pancreas", "Thyroid", "Pituitary"]),
    ("How many bones does an adult human have?", "206", ["204", "212", "300"]),
    ("How many chromosomes are there in a normal human body cell?", "46", ["23", "44", "48"]),
    ("Who discovered the ABO blood groups?", "Karl Landsteiner", ["Louis Pasteur", "Robert Koch", "Edward Jenner"]),
    ("Who discovered penicillin?", "Alexander Fleming", ["Louis Pasteur", "Joseph Lister", "Edward Jenner"]),
    ("Who developed the first smallpox vaccine?", "Edward Jenner", ["Louis Pasteur", "Robert Koch", "Alexander Fleming"]),
    ("Normal human body temperature is about:", "37 °C (98.4 °F)", ["35 °C (95 °F)", "39 °C (102 °F)", "40 °C (104 °F)"]),
    ("Sound travels fastest through:", "Solids", ["Liquids", "Gases", "Vacuum"]),
    ("Light from the Sun reaches the Earth in about:", "8 minutes 20 seconds", ["8 seconds", "1 hour", "24 hours"]),
    ("Laughing gas is:", "Nitrous oxide (N₂O)", ["Carbon monoxide (CO)", "Nitrogen dioxide (NO₂)", "Methane (CH₄)"]),
    ("Dry ice is solid:", "Carbon dioxide", ["Water", "Nitrogen", "Ammonia"]),
    ("Brass is an alloy of copper and:", "Zinc", ["Tin", "Iron", "Lead"]),
    ("Bronze is an alloy of copper and:", "Tin", ["Zinc", "Nickel", "Aluminium"]),
    ("The chemical formula of common salt is:", "NaCl", ["KCl", "NaHCO₃", "Na₂CO₃"]),
    ("The chemical formula of baking soda is:", "NaHCO₃", ["Na₂CO₃", "NaCl", "CaCO₃"]),
    ("Marsh gas is:", "Methane", ["Ethane", "Ammonia", "Hydrogen sulphide"]),
    ("The pH of pure water at 25 °C is:", "7", ["0", "5", "14"]),
    ("The hardest natural substance is:", "Diamond", ["Iron", "Quartz", "Graphite"]),
    ("The largest planet of the solar system is:", "Jupiter", ["Saturn", "Neptune", "Earth"]),
    ("The planet closest to the Sun is:", "Mercury", ["Venus", "Mars", "Earth"]),
    ("Which planet is called the Red Planet?", "Mars", ["Venus", "Jupiter", "Mercury"]),
    ("The hottest planet of the solar system is:", "Venus", ["Mercury", "Mars", "Jupiter"]),
    ("Which gas do plants take in for photosynthesis?", "Carbon dioxide", ["Oxygen", "Nitrogen", "Hydrogen"]),
    ("The study of earthquakes is called:", "Seismology", ["Meteorology", "Ecology", "Petrology"]),
    ("Which instrument measures atmospheric pressure?", "Barometer", ["Hygrometer", "Ammeter", "Thermometer"]),
    ("Which instrument measures relative humidity?", "Hygrometer", ["Barometer", "Anemometer", "Altimeter"]),
    ("Which instrument measures wind speed?", "Anemometer", ["Barometer", "Hygrometer", "Seismograph"]),
    ("Red blood cells carry oxygen with the help of:", "Haemoglobin", ["Insulin", "Keratin", "Chlorophyll"]),
    ("Which blood group is called the universal donor (ABO system)?", "O negative", ["AB positive", "A positive", "B negative"]),
]


def gen_science(b, rng):
    fam = ("bcs", "job")
    names = [e[0] for e in ELEMENTS]
    syms = [e[1] for e in ELEMENTS]
    for name, sym, z in ELEMENTS:
        b.add("science_chem", fam, 1, "What is the chemical symbol of %s?" % name, sym, b.pick(syms, 3, [sym]),
              "Fact table: periodic table", prefix="SCI")
        b.add("science_chem", fam, 1, "Which element has the symbol '%s'?" % sym, name, b.pick(names, 3, [name]),
              "Fact table: periodic table", prefix="SCI")
    for name, sym, z in ELEMENTS:
        if z > 30:
            continue
        add_numeric(b, "science_chem", fam, 2, "What is the atomic number of %s?" % name, None, z,
                    "Fact table: periodic table", spread=1, prefix="SCI")
    units = [u for _, u in SI_UNITS]
    for qty, unit in SI_UNITS:
        b.add("science_units", fam, 1, "What is the SI unit of %s?" % qty.lower(), unit, b.pick(units, 3, [unit]),
              "Fact table: SI units", prefix="SCI")
    for q, a, ds in SCIENCE_FACTS:
        b.add("science", fam, 1, q, a, ds, "Fact table: general science", prefix="SCI")


# =============================================================================================
# 6. English language
# =============================================================================================

SYNONYMS = [
    ("abandon", "desert"), ("abundant", "plentiful"), ("brief", "short"), ("candid", "frank"), ("diligent", "hardworking"),
    ("eminent", "famous"), ("enormous", "huge"), ("fragile", "delicate"), ("genuine", "authentic"), ("hostile", "unfriendly"),
    ("imitate", "copy"), ("lethal", "deadly"), ("meagre", "scanty"), ("obsolete", "outdated"), ("ponder", "consider"),
    ("prudent", "wise"), ("rapid", "quick"), ("reluctant", "unwilling"), ("vacant", "empty"), ("wealthy", "rich"),
    ("conceal", "hide"), ("commence", "begin"), ("terminate", "end"), ("accurate", "correct"), ("assist", "help"),
    ("courage", "bravery"), ("eager", "keen"), ("feeble", "weak"), ("hazard", "danger"), ("purchase", "buy"),
    ("adequate", "sufficient"), ("ambiguous", "unclear"), ("audacious", "bold"), ("benevolent", "kind"),
    ("cordial", "friendly"), ("deceive", "cheat"), ("endorse", "approve"), ("exhausted", "tired"),
    ("frugal", "thrifty"), ("gloomy", "dark"), ("hinder", "obstruct"), ("immense", "vast"), ("jubilant", "joyful"),
    ("lucid", "clear"), ("malicious", "spiteful"), ("novice", "beginner"), ("obstinate", "stubborn"),
    ("pensive", "thoughtful"), ("quarrel", "dispute"), ("rectify", "correct"), ("scarce", "rare"),
    ("tranquil", "calm"), ("utilise", "use"), ("vanish", "disappear"), ("wrath", "anger"), ("zeal", "enthusiasm"),
    ("affluent", "prosperous"), ("conspicuous", "noticeable"), ("ephemeral", "short-lived"), ("vindicate", "justify"),
]
ANTONYMS = [
    ("ancient", "modern"), ("artificial", "natural"), ("brave", "cowardly"), ("cheap", "expensive"),
    ("permanent", "temporary"), ("generous", "stingy"), ("guilty", "innocent"), ("humble", "arrogant"),
    ("import", "export"), ("increase", "decrease"), ("maximum", "minimum"), ("optimist", "pessimist"),
    ("profit", "loss"), ("rigid", "flexible"), ("shallow", "deep"), ("superior", "inferior"), ("transparent", "opaque"),
    ("victory", "defeat"), ("accept", "reject"), ("acquit", "convict"), ("admit", "deny"), ("barren", "fertile"),
    ("compulsory", "optional"), ("conceal", "reveal"), ("create", "destroy"), ("expand", "contract"),
    ("frequent", "rare"), ("gradual", "sudden"), ("include", "exclude"), ("junior", "senior"), ("majority", "minority"),
    ("private", "public"), ("strengthen", "weaken"), ("vague", "definite"), ("ascend", "descend"), ("advance", "retreat"),
    ("benefit", "harm"), ("cautious", "reckless"), ("deliberate", "accidental"), ("encourage", "discourage"),
    ("famine", "plenty"), ("hostile", "friendly"), ("lenient", "strict"), ("modest", "boastful"), ("negligent", "careful"),
    ("praise", "blame"), ("prosperity", "adversity"), ("scarcity", "abundance"), ("sane", "insane"), ("tame", "wild"),
]
ONE_WORD = [
    ("One who cannot be corrected", "Incorrigible"), ("A person who does not believe in God", "Atheist"),
    ("A life history written by oneself", "Autobiography"), ("One who knows everything", "Omniscient"),
    ("One who is present everywhere", "Omnipresent"), ("One who is all-powerful", "Omnipotent"),
    ("A place where bees are kept", "Apiary"), ("A place where birds are kept", "Aviary"),
    ("A place where dead bodies are kept", "Mortuary"), ("A speech made without preparation", "Extempore"),
    ("One who eats human flesh", "Cannibal"), ("A cure for all diseases", "Panacea"),
    ("Writing that cannot be read", "Illegible"), ("One who walks on foot", "Pedestrian"),
    ("Murder of a king", "Regicide"), ("Murder of one's own father", "Patricide"), ("Murder of one's own mother", "Matricide"),
    ("Government by the people", "Democracy"), ("Government by a few", "Oligarchy"),
    ("Government by one person with absolute power", "Autocracy"), ("One who loves mankind", "Philanthropist"),
    ("One who hates mankind", "Misanthrope"), ("A man whose wife is dead", "Widower"),
    ("The study of birds", "Ornithology"), ("The study of insects", "Entomology"), ("The study of ancient remains", "Archaeology"),
    ("Fear of water", "Hydrophobia"), ("Fear of heights", "Acrophobia"), ("One who is unable to pay debts", "Insolvent"),
    ("A list of books on a subject", "Bibliography"), ("A medicine that induces sleep", "Soporific"),
    ("Animals that eat flesh", "Carnivorous"), ("Animals that eat plants", "Herbivorous"), ("Fit to be eaten", "Edible"),
    ("A collection of poems", "Anthology"), ("A person who speaks two languages", "Bilingual"),
    ("A word opposite in meaning", "Antonym"), ("That which cannot be avoided", "Inevitable"),
    ("A speech delivered by one actor alone", "Soliloquy"), ("A person who is new to a profession", "Novice"),
]
SPELLINGS = ["accommodate", "embarrass", "occurrence", "millennium", "conscientious", "bureaucracy", "entrepreneur",
             "guarantee", "harass", "liaison", "maintenance", "necessary", "privilege", "questionnaire", "rhythm",
             "separate", "supersede", "threshold", "tomorrow", "vacuum", "committee", "definitely", "discipline",
             "existence", "fluorescent", "government", "hierarchy", "independent", "knowledge", "lieutenant",
             "mischievous", "noticeable", "parliament", "perseverance", "receive", "recommend", "referred", "restaurant",
             "schedule", "success", "unanimous", "achievement", "acquaintance", "colleague", "conscience", "dilemma",
             "exaggerate", "gauge", "grammar", "occasion", "pronunciation", "accidentally", "beginning", "believe",
             "calendar", "cemetery", "embarrassment", "environment", "forty", "foreign", "humorous", "immediately",
             "jewellery", "leisure", "license", "miniature", "neighbour", "pastime", "possession", "proceed",
             "publicly", "recede", "secretary", "sergeant", "sincerely", "succeed", "surprise", "tendency", "tyranny"]
IDIOMS = [
    ("A piece of cake", "Very easy"), ("Break the ice", "Start a conversation in an awkward situation"),
    ("Bite the bullet", "Face a hard situation bravely"), ("Once in a blue moon", "Very rarely"),
    ("Call a spade a spade", "Speak plainly and frankly"), ("Hit the nail on the head", "Be exactly right"),
    ("Burn the midnight oil", "Work or study late into the night"), ("Cry over spilt milk", "Regret what cannot be undone"),
    ("Let the cat out of the bag", "Reveal a secret"), ("Under the weather", "Feeling unwell"),
    ("At the eleventh hour", "At the last moment"), ("A white elephant", "A costly but useless possession"),
    ("Apple of one's eye", "A very dear person"), ("In hot water", "In trouble"),
    ("Red tape", "Excessive official formality"), ("Beat about the bush", "Avoid the main point"),
    ("A bolt from the blue", "A sudden, unexpected shock"), ("By hook or by crook", "By any means, fair or foul"),
    ("A Herculean task", "A very difficult task"), ("Achilles' heel", "A weak point"), ("Turn a deaf ear", "Ignore"),
    ("Bad blood", "Enmity"), ("Get cold feet", "Become nervous before an event"), ("Null and void", "Invalid"),
    ("Bone of contention", "Cause of a quarrel"), ("In black and white", "In writing"),
    ("Smell a rat", "Suspect something is wrong"), ("Take French leave", "Leave without permission"),
]


def misspell(rng, word, k=3):
    out = set()
    ops = 0
    while len(out) < k and ops < 300:
        ops += 1
        w = list(word)
        op = rng.choice(["dup", "undup", "swap_ie", "vowel", "drop"])
        i = rng.randrange(len(w))
        if op == "dup" and w[i].isalpha():
            w.insert(i, w[i])
        elif op == "undup":
            for j in range(len(w) - 1):
                if w[j] == w[j + 1]:
                    del w[j]
                    break
            else:
                continue
        elif op == "swap_ie":
            s = "".join(w)
            if "ie" in s:
                s = s.replace("ie", "ei", 1)
            elif "ei" in s:
                s = s.replace("ei", "ie", 1)
            else:
                continue
            w = list(s)
        elif op == "vowel" and w[i] in "aeiou":
            w[i] = rng.choice([v for v in "aeiou" if v != w[i]])
        elif op == "drop" and len(w) > 4 and 0 < i < len(w) - 1:
            del w[i]
        else:
            continue
        s = "".join(w)
        if s != word and s not in SPELLINGS:
            out.add(s)
    return sorted(out)


def gen_english(b, rng):
    fam = ("bcs", "job")
    syn_ans = [s for _, s in SYNONYMS]
    for w, s in SYNONYMS:
        b.add("english_synonym", fam, 2, "Choose the synonym of '%s'." % w, s.capitalize(),
              [x.capitalize() for x in b.pick(syn_ans, 3, [s])], "Fact table: English synonyms", prefix="ENG")
    ant_all = [a for _, a in ANTONYMS] + [w for w, _ in ANTONYMS]
    for w, a in ANTONYMS:
        pool = [x for x in ant_all if x not in (w, a)]
        b.add("english_antonym", fam, 2, "Choose the antonym of '%s'." % w, a.capitalize(),
              [x.capitalize() for x in rng.sample(pool, 3)], "Fact table: English antonyms", prefix="ENG")
        b.add("english_antonym", fam, 2, "Choose the antonym of '%s'." % a, w.capitalize(),
              [x.capitalize() for x in rng.sample(pool, 3)], "Fact table: English antonyms", prefix="ENG")
    words = [x for _, x in ONE_WORD]
    for phrase, word in ONE_WORD:
        b.add("english_oneword", fam, 2, "One-word substitute: '%s'" % phrase, word, b.pick(words, 3, [word]),
              "Fact table: one-word substitutions", prefix="ENG")
    for w in SPELLINGS:
        wrong = misspell(rng, w)
        if len(wrong) == 3:
            b.add("english_spelling", fam, 2, "Which spelling is correct?", w, wrong, "Fact table: standard British spelling", prefix="ENG")
    meanings = [m for _, m in IDIOMS]
    for idiom, m in IDIOMS:
        b.add("english_idiom", fam, 2, "What does the idiom '%s' mean?" % idiom, m, b.pick(meanings, 3, [m]),
              "Fact table: English idioms", prefix="ENG")
    grammar = [
        ("He is good ___ mathematics.", "at", ["in", "on", "with"]),
        ("She is fond ___ reading.", "of", ["in", "with", "for"]),
        ("He was accused ___ theft.", "of", ["for", "with", "on"]),
        ("I prefer tea ___ coffee.", "to", ["than", "over", "from"]),
        ("The train is ___ time.", "on", ["at", "in", "by"]),
        ("He has been ill ___ Monday.", "since", ["for", "from", "by"]),
        ("She has lived here ___ ten years.", "for", ["since", "from", "by"]),
        ("He died ___ cholera.", "of", ["from", "by", "with"]),
        ("Neither Rahim nor his friends ___ present.", "were", ["was", "is", "has been"]),
        ("Each of the boys ___ a book.", "has", ["have", "are having", "were having"]),
        ("If I ___ a bird, I would fly.", "were", ["am", "was being", "be"]),
        ("The plural of 'datum' is:", "data", ["datums", "datas", "datae"]),
        ("The plural of 'criterion' is:", "criteria", ["criterions", "criterias", "criteriae"]),
        ("The plural of 'phenomenon' is:", "phenomena", ["phenomenons", "phenomenas", "phenomenae"]),
        ("The past participle of 'go' is:", "gone", ["went", "goed", "going"]),
        ("The past tense of 'teach' is:", "taught", ["teached", "tought", "taughten"]),
        ("'Quickly' is which part of speech?", "Adverb", ["Adjective", "Noun", "Verb"]),
        ("'Beauty' is which part of speech?", "Noun", ["Adjective", "Adverb", "Verb"]),
        ("'Beautiful' is which part of speech?", "Adjective", ["Noun", "Adverb", "Pronoun"]),
        ("'Alas!' is which part of speech?", "Interjection", ["Conjunction", "Preposition", "Adverb"]),
    ]
    for q, a, ds in grammar:
        b.add("english_grammar", fam, 1, q, a, ds, "Standard English grammar", prefix="ENG")


# =============================================================================================
# 7. Bangla language and literature (Bengali)
# =============================================================================================

SANDHI = [("বিদ্যালয়", "বিদ্যা + আলয়"), ("হিমালয়", "হিম + আলয়"), ("সূর্যোদয়", "সূর্য + উদয়"), ("মহোৎসব", "মহা + উৎসব"),
          ("নরেশ", "নর + ঈশ"), ("পরীক্ষা", "পরি + ঈক্ষা"), ("প্রত্যেক", "প্রতি + এক"), ("অত্যন্ত", "অতি + অন্ত"),
          ("ইত্যাদি", "ইতি + আদি"), ("স্বাগত", "সু + আগত"), ("নয়ন", "নে + অন"), ("পবন", "পো + অন"), ("গায়ক", "গৈ + অক"),
          ("নাবিক", "নৌ + ইক"), ("দিগন্ত", "দিক্ + অন্ত"), ("বাগীশ", "বাক্ + ঈশ"), ("সঞ্চয়", "সম্ + চয়"),
          ("মনোরম", "মনঃ + রম"), ("নিরাশ", "নিঃ + আশ"), ("দুরবস্থা", "দুঃ + অবস্থা"), ("নমস্কার", "নমঃ + কার"),
          ("বৃহস্পতি", "বৃহৎ + পতি"), ("উচ্ছ্বাস", "উৎ + শ্বাস"), ("সচ্চরিত্র", "সৎ + চরিত্র"), ("জগন্নাথ", "জগৎ + নাথ"),
          ("উল্লাস", "উৎ + লাস"), ("যথেষ্ট", "যথা + ইষ্ট"), ("গণেশ", "গণ + ঈশ"), ("রবীন্দ্র", "রবি + ইন্দ্র"),
          ("দেবালয়", "দেব + আলয়"), ("সিংহাসন", "সিংহ + আসন"), ("রত্নাকর", "রত্ন + আকর")]
SYN_BN = [("চাঁদ", ["শশী", "সুধাংশু", "ইন্দু"]), ("সূর্য", ["রবি", "ভানু", "দিবাকর"]), ("পানি", ["জল", "বারি", "সলিল"]),
          ("আকাশ", ["গগন", "অম্বর", "নভঃ"]), ("পৃথিবী", ["ধরা", "বসুধা", "ধরিত্রী"]), ("বাতাস", ["পবন", "সমীরণ", "অনিল"]),
          ("পাহাড়", ["পর্বত", "গিরি", "অচল"]), ("চোখ", ["নয়ন", "লোচন", "আঁখি"]), ("মেঘ", ["জলদ", "নীরদ", "বারিদ"]),
          ("নদী", ["তটিনী", "তরঙ্গিণী", "স্রোতস্বিনী"]), ("রাত", ["রজনী", "নিশি", "যামিনী"]), ("ফুল", ["পুষ্প", "কুসুম", "প্রসূন"]),
          ("আগুন", ["অগ্নি", "অনল", "পাবক"]), ("সমুদ্র", ["সাগর", "সিন্ধু", "জলধি"]), ("হাত", ["কর", "হস্ত", "পাণি"]),
          ("বন", ["অরণ্য", "কানন", "বিপিন"]), ("ঘর", ["গৃহ", "আলয়", "নিকেতন"]), ("পদ্ম", ["কমল", "সরোজ", "পঙ্কজ"]),
          ("বিদ্যুৎ", ["তড়িৎ", "বিজলি", "সৌদামিনী"]), ("গাছ", ["বৃক্ষ", "তরু", "বিটপী"]), ("রাজা", ["নৃপতি", "ভূপতি", "নরপতি"]),
          ("মাথা", ["শির", "মস্তক", "মুণ্ড"])]
ANT_BN = [("আদি", "অন্ত"), ("আলো", "আঁধার"), ("আয়", "ব্যয়"), ("উন্নত", "অবনত"), ("উত্থান", "পতন"), ("কৃতজ্ঞ", "কৃতঘ্ন"),
          ("ক্রয়", "বিক্রয়"), ("জয়", "পরাজয়"), ("জীবন", "মরণ"), ("দাতা", "গ্রহীতা"), ("দুর্লভ", "সুলভ"), ("ধনী", "দরিদ্র"),
          ("নবীন", "প্রবীণ"), ("প্রশংসা", "নিন্দা"), ("বন্ধু", "শত্রু"), ("মিলন", "বিরহ"), ("সত্য", "মিথ্যা"), ("সবল", "দুর্বল"),
          ("সুখ", "দুঃখ"), ("স্বাধীন", "পরাধীন"), ("হ্রাস", "বৃদ্ধি"), ("আকর্ষণ", "বিকর্ষণ"), ("আবির্ভাব", "তিরোভাব"),
          ("ঐক্য", "অনৈক্য"), ("কৃত্রিম", "অকৃত্রিম"), ("গৌণ", "মুখ্য"), ("জঙ্গম", "স্থাবর"), ("তিক্ত", "মিষ্ট"),
          ("দীর্ঘ", "হ্রস্ব"), ("নিত্য", "অনিত্য"), ("পূর্ণ", "শূন্য"), ("বিধবা", "সধবা"), ("মৌখিক", "লিখিত"), ("লঘু", "গুরু"),
          ("শুষ্ক", "আর্দ্র"), ("স্থূল", "সূক্ষ্ম"), ("হর্ষ", "বিষাদ"), ("অগ্র", "পশ্চাৎ"), ("উদয়", "অস্ত"), ("আস্তিক", "নাস্তিক")]
LIT = [("গীতাঞ্জলি", "রবীন্দ্রনাথ ঠাকুর"), ("গোরা", "রবীন্দ্রনাথ ঠাকুর"), ("চোখের বালি", "রবীন্দ্রনাথ ঠাকুর"),
       ("শেষের কবিতা", "রবীন্দ্রনাথ ঠাকুর"), ("অগ্নিবীণা", "কাজী নজরুল ইসলাম"), ("বিষের বাঁশি", "কাজী নজরুল ইসলাম"),
       ("ব্যথার দান", "কাজী নজরুল ইসলাম"), ("দেবদাস", "শরৎচন্দ্র চট্টোপাধ্যায়"), ("শ্রীকান্ত", "শরৎচন্দ্র চট্টোপাধ্যায়"),
       ("গৃহদাহ", "শরৎচন্দ্র চট্টোপাধ্যায়"), ("পথের দাবী", "শরৎচন্দ্র চট্টোপাধ্যায়"), ("কপালকুণ্ডলা", "বঙ্কিমচন্দ্র চট্টোপাধ্যায়"),
       ("দুর্গেশনন্দিনী", "বঙ্কিমচন্দ্র চট্টোপাধ্যায়"), ("আনন্দমঠ", "বঙ্কিমচন্দ্র চট্টোপাধ্যায়"), ("বিষবৃক্ষ", "বঙ্কিমচন্দ্র চট্টোপাধ্যায়"),
       ("বিষাদ-সিন্ধু", "মীর মশাররফ হোসেন"), ("নকশী কাঁথার মাঠ", "জসীমউদ্‌দীন"), ("সোজন বাদিয়ার ঘাট", "জসীমউদ্‌দীন"),
       ("মেঘনাদবধ কাব্য", "মাইকেল মধুসূদন দত্ত"), ("শর্মিষ্ঠা", "মাইকেল মধুসূদন দত্ত"),
       ("একেই কি বলে সভ্যতা", "মাইকেল মধুসূদন দত্ত"), ("রূপসী বাংলা", "জীবনানন্দ দাশ"), ("বনলতা সেন", "জীবনানন্দ দাশ"),
       ("ধূসর পাণ্ডুলিপি", "জীবনানন্দ দাশ"), ("লালসালু", "সৈয়দ ওয়ালীউল্লাহ"), ("নন্দিত নরকে", "হুমায়ূন আহমেদ"),
       ("শঙ্খনীল কারাগার", "হুমায়ূন আহমেদ"), ("সংশপ্তক", "শহীদুল্লা কায়সার"), ("কবর", "মুনীর চৌধুরী"),
       ("হাজার বছর ধরে", "জহির রায়হান"), ("সোনালী কাবিন", "আল মাহমুদ"), ("ছাড়পত্র", "সুকান্ত ভট্টাচার্য"),
       ("সুলতানার স্বপ্ন", "বেগম রোকেয়া"), ("আলালের ঘরের দুলাল", "প্যারীচাঁদ মিত্র"), ("নীলদর্পণ", "দীনবন্ধু মিত্র"),
       ("পদ্মানদীর মাঝি", "মানিক বন্দ্যোপাধ্যায়"), ("পথের পাঁচালী", "বিভূতিভূষণ বন্দ্যোপাধ্যায়"), ("গণদেবতা", "তারাশঙ্কর বন্দ্যোপাধ্যায়"),
       ("মহাশ্মশান", "কায়কোবাদ"), ("সাত সাগরের মাঝি", "ফররুখ আহমদ"), ("চিলেকোঠার সেপাই", "আখতারুজ্জামান ইলিয়াস"),
       ("হাঙর নদী গ্রেনেড", "সেলিনা হোসেন"), ("সূর্য দীঘল বাড়ী", "আবু ইসহাক"), ("নূরলদীনের সারাজীবন", "সৈয়দ শামসুল হক"),
       ("বন্দী শিবির থেকে", "শামসুর রাহমান")]


def gen_bangla(b, rng):
    fam = ("bcs",)
    splits = [s for _, s in SANDHI]
    for w, s in SANDHI:
        b.add("bangla_sandhi", fam, 2, None, None, None, "Fact table: Bangla sandhi (school grammar)",
              "'%s' শব্দের সন্ধি-বিচ্ছেদ কোনটি?" % w, s, b.pick(splits, 3, [s]), prefix="BAN")
    all_syn = [(h, s) for h, ss in SYN_BN for s in ss]
    for head, syns in SYN_BN:
        for s in syns:
            others = [x for h, x in all_syn if h != head]
            b.add("bangla_synonym", fam, 2, None, None, None, "Fact table: Bangla synonyms",
                  "'%s' শব্দের সমার্থক কোনটি?" % head, s, rng.sample(others, 3), prefix="BAN")
    words = [x for p in ANT_BN for x in p]
    for w, a in ANT_BN:
        pool = [x for x in words if x not in (w, a)]
        b.add("bangla_antonym", fam, 1, None, None, None, "Fact table: Bangla antonyms",
              "'%s' শব্দের বিপরীত শব্দ কোনটি?" % w, a, rng.sample(pool, 3), prefix="BAN")
        b.add("bangla_antonym", fam, 1, None, None, None, "Fact table: Bangla antonyms",
              "'%s' শব্দের বিপরীত শব্দ কোনটি?" % a, w, rng.sample(pool, 3), prefix="BAN")
    authors = sorted(set(a for _, a in LIT))
    works = [w for w, _ in LIT]
    for work, author in LIT:
        b.add("bangla_literature", fam, 2, None, None, None, "Fact table: Bangla literature (author and work)",
              "'%s' কার রচনা?" % work, author, b.pick(authors, 3, [author]), prefix="BAN")
        theirs = [w for w, a in LIT if a == author]
        b.add("bangla_literature", fam, 2, None, None, None, "Fact table: Bangla literature (author and work)",
              "নিচের কোনটি %s-এর রচনা?" % author, work, b.pick([w for w in works if w not in theirs], 3, []), prefix="BAN")


# =============================================================================================
# 8. Law: Bar Council enrolment (and the BCS constitution questions)
# =============================================================================================

CONSTITUTION = [
    (1, "The Republic"), (2, "The territory of the Republic"), (3, "The state language"),
    (4, "National anthem, flag and emblem"), (5, "The capital"), (6, "Citizenship"), (7, "Supremacy of the Constitution"),
    (8, "Fundamental principles of state policy"), (11, "Democracy and human rights"), (15, "Provision of basic necessities"),
    (17, "Free and compulsory education"), (18, "Public health and morality"),
    (19, "Equality of opportunity"), (20, "Work as a right and duty"), (21, "Duties of citizens and of public servants"),
    (22, "Separation of the judiciary from the executive"), (23, "National culture"), (24, "National monuments"),
    (25, "Promotion of international peace, security and solidarity"),
    (26, "Laws inconsistent with fundamental rights to be void"), (27, "Equality before law"),
    (28, "Discrimination on grounds of religion, race, caste, sex or place of birth"),
    (29, "Equality of opportunity in public employment"), (30, "Prohibition of foreign titles"),
    (31, "Right to protection of law"), (32, "Protection of right to life and personal liberty"),
    (33, "Safeguards as to arrest and detention"), (34, "Prohibition of forced labour"),
    (35, "Protection in respect of trial and punishment"), (36, "Freedom of movement"), (37, "Freedom of assembly"),
    (38, "Freedom of association"), (39, "Freedom of thought and conscience, and of speech"),
    (40, "Freedom of profession or occupation"), (41, "Freedom of religion"), (42, "Rights to property"),
    (43, "Protection of home and correspondence"), (44, "Enforcement of fundamental rights"), (48, "The President"),
    (55, "The Cabinet"), (65, "Establishment of Parliament"), (66, "Qualifications and disqualifications for election to Parliament"),
    (77, "The Ombudsman"), (93, "Ordinance-making power"), (94, "Establishment of the Supreme Court"),
    (95, "Appointment of judges"), (102, "Powers of the High Court Division to issue certain orders and directions (writs)"),
    (103, "Jurisdiction of the Appellate Division"), (105, "Review of judgments or orders by the Appellate Division"),
    (106, "Advisory jurisdiction of the Supreme Court"), (111, "Binding effect of Supreme Court judgments"),
    (117, "Administrative tribunals"), (118, "Establishment of the Election Commission"),
    (127, "Establishment of the office of Auditor-General"), (137, "Establishment of public service commissions"),
    (140, "Functions of public service commissions"), (141, "Proclamation of emergency"),
    (142, "Power to amend any provision of the Constitution"), (152, "Interpretation"),
    (153, "Commencement, citation and authentication"),
]
CONST_DISPLAY = {141: "141A"}

PENAL = [
    ("21", "Definition of 'public servant'"), ("34", "Acts done by several persons in furtherance of common intention"),
    ("53", "Kinds of punishment"), ("82", "Act of a child under nine years of age"),
    ("83", "Act of a child above nine and under twelve of immature understanding"), ("84", "Act of a person of unsound mind"),
    ("96", "Things done in private defence"), ("100", "When the right of private defence of the body extends to causing death"),
    ("107", "Abetment of a thing"), ("120A", "Definition of criminal conspiracy"), ("121", "Waging war against Bangladesh"),
    ("141", "Unlawful assembly"), ("146", "Rioting"),
    ("149", "Every member of an unlawful assembly guilty of an offence committed in prosecution of the common object"),
    ("159", "Affray"), ("191", "Giving false evidence"), ("299", "Culpable homicide"), ("300", "Murder"),
    ("302", "Punishment for murder"), ("304", "Punishment for culpable homicide not amounting to murder"),
    ("304A", "Causing death by negligence"), ("307", "Attempt to murder"), ("319", "Hurt"), ("320", "Grievous hurt"),
    ("323", "Punishment for voluntarily causing hurt"), ("339", "Wrongful restraint"), ("340", "Wrongful confinement"),
    ("349", "Force"), ("350", "Criminal force"), ("351", "Assault"), ("359", "Kidnapping"), ("362", "Abduction"),
    ("378", "Theft"), ("379", "Punishment for theft"), ("383", "Extortion"), ("390", "Robbery"), ("391", "Dacoity"),
    ("403", "Dishonest misappropriation of property"), ("405", "Criminal breach of trust"), ("415", "Cheating"),
    ("420", "Cheating and dishonestly inducing delivery of property"), ("425", "Mischief"), ("441", "Criminal trespass"),
    ("442", "House-trespass"), ("463", "Forgery"), ("499", "Defamation"), ("500", "Punishment for defamation"),
    ("503", "Criminal intimidation"),
]
CRPC = [
    ("4", "Definitions"), ("54", "When police may arrest without warrant"),
    ("61", "Person arrested not to be detained more than twenty-four hours"),
    ("103", "Search to be made in presence of witnesses"),
    ("144", "Power to issue order in urgent cases of nuisance or apprehended danger"),
    ("154", "Information in cognizable cases (first information report)"), ("155", "Information in non-cognizable cases"),
    ("161", "Examination of witnesses by police"), ("164", "Recording of confessions and statements by a Magistrate"),
    ("167", "Procedure when investigation cannot be completed in twenty-four hours (remand)"),
    ("173", "Report of police officer on completion of investigation"), ("190", "Cognizance of offences by Magistrates"),
    ("200", "Examination of complainant"), ("204", "Issue of process"), ("342", "Power to examine the accused"),
    ("403", "Person once convicted or acquitted not to be tried for the same offence"),
    ("435", "Power to call for records of inferior courts"), ("439", "High Court Division's powers of revision"),
    ("491", "Power to issue directions of the nature of habeas corpus"), ("496", "Bail in bailable offences"),
    ("497", "Bail in non-bailable offences"), ("498", "Power to direct admission to bail or reduction of bail"),
    ("561A", "Saving of inherent powers of the High Court Division"),
]
CPC = [
    ("9", "Courts to try all civil suits unless barred"), ("10", "Stay of suit (res sub judice)"), ("11", "Res judicata"),
    ("15", "Court in which suits to be instituted"), ("16", "Suits to be instituted where subject-matter is situate"),
    ("20", "Other suits to be instituted where defendants reside or cause of action arises"),
    ("24", "General power of transfer and withdrawal"), ("26", "Institution of suits"), ("35", "Costs"),
    ("35A", "Compensatory costs in respect of false or vexatious claims"), ("51", "Powers of court to enforce execution"),
    ("60", "Property liable to attachment and sale in execution"), ("80", "Notice before suing the Government or a public officer"),
    ("89A", "Mediation"), ("96", "Appeal from original decree"), ("100", "Second appeal"),
    ("104", "Orders from which appeal lies"), ("114", "Review"), ("115", "Revision"), ("144", "Application for restitution"),
    ("148", "Enlargement of time"), ("151", "Saving of inherent powers of court"),
]
CPC_ORDERS = [("Order VII, rule 11", "Rejection of plaint"), ("Order XXXIX, rules 1 and 2", "Temporary injunction"),
              ("Order IX, rule 13", "Setting aside a decree passed ex parte against the defendant"),
              ("Order XXI", "Execution of decrees and orders"), ("Order XLI", "Appeals from original decrees"),
              ("Order XLVII", "Review"), ("Order XXXIII", "Suits by paupers")]
EVIDENCE = [
    ("3", "Interpretation clause"), ("5", "Evidence may be given of facts in issue and relevant facts"),
    ("8", "Motive, preparation and previous or subsequent conduct"), ("17", "Admission defined"),
    ("24", "Confession caused by inducement, threat or promise, when irrelevant"),
    ("25", "Confession to a police officer not to be proved"),
    ("26", "Confession by accused while in custody of police not to be proved against him"),
    ("27", "How much of information received from the accused may be proved"),
    ("30", "Consideration of proved confession affecting a co-accused"),
    ("32", "Statements by a person who is dead or cannot be found (dying declaration)"), ("45", "Opinions of experts"),
    ("60", "Oral evidence must be direct"), ("62", "Primary evidence"), ("63", "Secondary evidence"),
    ("74", "Public documents"), ("101", "Burden of proof"),
    ("106", "Burden of proving a fact especially within knowledge"),
    ("112", "Birth during marriage, conclusive proof of legitimacy"), ("114", "Court may presume existence of certain facts"),
    ("115", "Estoppel"), ("118", "Who may testify"), ("133", "Accomplice"), ("134", "Number of witnesses"),
    ("137", "Examination-in-chief, cross-examination and re-examination"), ("141", "Leading questions"),
    ("155", "Impeaching the credit of a witness"), ("165", "Judge's power to put questions or order production"),
    ("167", "No new trial for improper admission or rejection of evidence"),
]
LIMITATION = [("3", "Dismissal of suits, appeals and applications made after the period of limitation"),
              ("5", "Extension of the period in certain cases"), ("12", "Exclusion of time in legal proceedings"),
              ("14", "Exclusion of time of proceeding bona fide in a court without jurisdiction"),
              ("19", "Effect of acknowledgment in writing"), ("28", "Extinguishment of right to property")]
SPECIFIC_RELIEF = [("8", "Recovery of specific immovable property"),
                   ("9", "Suit by person dispossessed of immovable property"),
                   ("10", "Recovery of specific movable property"), ("12", "Cases in which specific performance is enforceable"),
                   ("21", "Contracts not specifically enforceable"), ("31", "Rectification of instruments"),
                   ("35", "Rescission of contracts"), ("39", "Cancellation of instruments"),
                   ("42", "Declaratory decrees (declaration of status or right)"), ("53", "Temporary and perpetual injunctions"),
                   ("54", "Perpetual injunctions when granted"), ("55", "Mandatory injunctions"),
                   ("56", "Injunction when refused")]
CONTRACT = [("2(h)", "Definition of 'contract' (an agreement enforceable by law)"), ("10", "What agreements are contracts"),
            ("11", "Who are competent to contract"), ("23", "What considerations and objects are lawful"),
            ("25", "Agreement without consideration void, except in certain cases"),
            ("56", "Agreement to do an impossible act (frustration)"), ("73", "Compensation for loss caused by breach of contract"),
            ("124", "Contract of indemnity"), ("126", "Contract of guarantee"), ("148", "Bailment"), ("172", "Pledge"),
            ("182", "Agent and principal")]
TPA = [("54", "Sale"), ("58", "Mortgage"), ("105", "Lease"), ("118", "Exchange"), ("122", "Gift")]
ACTS = {"The Penal Code": PENAL, "The Code of Criminal Procedure": CRPC, "The Code of Civil Procedure": CPC,
        "The Evidence Act": EVIDENCE, "The Limitation Act": LIMITATION, "The Specific Relief Act": SPECIFIC_RELIEF,
        "The Contract Act": CONTRACT, "The Transfer of Property Act": TPA}
ACT_YEARS = [("The Penal Code", "1860"), ("The Code of Criminal Procedure", "1898"), ("The Code of Civil Procedure", "1908"),
             ("The Evidence Act", "1872"), ("The Contract Act", "1872"), ("The Specific Relief Act", "1877"),
             ("The Limitation Act", "1908"), ("The Transfer of Property Act", "1882"), ("The Registration Act", "1908"),
             ("The Muslim Family Laws Ordinance", "1961"), ("The Family Courts Ordinance", "1985"),
             ("The Arbitration Act", "2001"), ("The Right to Information Act", "2009"),
             ("The Consumer Rights Protection Act", "2009"), ("The Money Laundering Prevention Act", "2012")]
MAXIMS = [("Audi alteram partem", "Hear the other side"), ("Ignorantia juris non excusat", "Ignorance of the law is no excuse"),
          ("Res ipsa loquitur", "The thing speaks for itself"), ("Ubi jus ibi remedium", "Where there is a right, there is a remedy"),
          ("Nemo judex in causa sua", "No one should be a judge in his own cause"), ("Volenti non fit injuria", "No injury is done to one who consents"),
          ("De minimis non curat lex", "The law does not concern itself with trifles"), ("Caveat emptor", "Let the buyer beware"),
          ("Habeas corpus", "You may have the body"), ("Mandamus", "We command"), ("Quo warranto", "By what authority"),
          ("Stare decisis", "To stand by decided cases"), ("Obiter dictum", "A remark said by the way"),
          ("Ratio decidendi", "The reason for the decision"), ("Pacta sunt servanda", "Agreements must be kept"),
          ("Sub judice", "Under judicial consideration"), ("Ultra vires", "Beyond the powers"), ("Prima facie", "At first sight"),
          ("Bona fide", "In good faith"), ("Mala fide", "In bad faith"), ("Ex parte", "On behalf of one side only"),
          ("Locus standi", "The right to be heard in court (standing)"), ("Res judicata", "A matter already judged"),
          ("Amicus curiae", "Friend of the court"), ("Mens rea", "Guilty mind"), ("Actus reus", "Guilty act"),
          ("Corpus delicti", "The body of the offence (the facts that a crime occurred)"),
          ("Nemo dat quod non habet", "No one gives what he does not have"),
          ("Damnum sine injuria", "Damage without legal injury"), ("Injuria sine damno", "Legal injury without damage"),
          ("Alibi", "Elsewhere"), ("Inter alia", "Among other things"), ("Pro bono", "For the public good (free of charge)")]
BAR_FACTS = [
    ("The Bangladesh Bar Council was established under:", "The Bangladesh Legal Practitioners and Bar Council Order, 1972",
     ["The Bar Councils Act, 1926", "The Advocates Act, 1961", "The Legal Aid Act, 2000"]),
    ("Who is the ex officio Chairman of the Bangladesh Bar Council?", "The Attorney General",
     ["The Chief Justice", "The Law Minister", "The President of the Supreme Court Bar Association"]),
    ("Professional conduct of advocates in Bangladesh is guided by the Bar Council's:", "Canons of Professional Conduct and Etiquette",
     ["Code of Civil Procedure", "Rules of Business", "Government Servants (Conduct) Rules"]),
    ("A writ to produce a detained person before the court is:", "Habeas corpus", ["Mandamus", "Certiorari", "Quo warranto"]),
    ("A writ asking a public official 'by what authority' he holds office is:", "Quo warranto", ["Mandamus", "Prohibition", "Habeas corpus"]),
    ("A writ commanding a public authority to perform a public duty is:", "Mandamus", ["Certiorari", "Habeas corpus", "Quo warranto"]),
    ("An offence for which police may arrest without a warrant is called:", "Cognizable", ["Non-cognizable", "Compoundable", "Bailable"]),
    ("Civil suits are instituted by presenting a:", "Plaint", ["Charge sheet", "Petition of appeal", "First information report"]),
    ("A dying declaration is admissible under which section of the Evidence Act?", "Section 32", ["Section 24", "Section 45", "Section 115"]),
    ("The principle that no one shall be tried twice for the same offence is called:", "Double jeopardy", ["Res judicata", "Estoppel", "Stare decisis"]),
]


def section_items(b, rng, act, rows, fam, prefix, diff=2, label="Section"):
    nums = [r[0] for r in rows]
    subj = [r[1] for r in rows]
    for num, s in rows:
        b.add("law_" + prefix.lower(), fam, diff, "%s %s of %s deals with:" % (label, num, act), s, b.pick(subj, 3, [s]),
              "Fact table: %s, section headings" % act, prefix=prefix)
        b.add("law_" + prefix.lower(), fam, diff + (1 if diff < 3 else 0), "Under %s, '%s' is dealt with in which %s?" % (act, s, label.lower()),
              "%s %s" % (label, num), ["%s %s" % (label, x) for x in b.pick(nums, 3, [num])],
              "Fact table: %s, section headings" % act, prefix=prefix)


def gen_law(b, rng):
    bar = ("bar",)
    both = ("bar", "bcs")
    arts = [CONST_DISPLAY.get(a, str(a)) for a, _ in CONSTITUTION]
    subj = [s for _, s in CONSTITUTION]
    for a, s in CONSTITUTION:
        disp = CONST_DISPLAY.get(a, str(a))
        b.add("law_constitution", both, 2, "Article %s of the Constitution of Bangladesh deals with:" % disp, s,
              b.pick(subj, 3, [s]), "Fact table: Constitution of the People's Republic of Bangladesh, article headings", prefix="CON")
        b.add("law_constitution", both, 3, "Which article of the Constitution of Bangladesh deals with '%s'?" % s,
              "Article %s" % disp, ["Article %s" % x for x in b.pick(arts, 3, [disp])],
              "Fact table: Constitution of the People's Republic of Bangladesh, article headings", prefix="CON")
    section_items(b, rng, "the Penal Code, 1860", PENAL, bar, "PEN")
    section_items(b, rng, "the Code of Criminal Procedure, 1898", CRPC, bar, "CRP")
    section_items(b, rng, "the Code of Civil Procedure, 1908", CPC, bar, "CPC")
    section_items(b, rng, "the Evidence Act, 1872", EVIDENCE, bar, "EVI")
    section_items(b, rng, "the Limitation Act, 1908", LIMITATION, bar, "LIM")
    section_items(b, rng, "the Specific Relief Act, 1877", SPECIFIC_RELIEF, bar, "SRA")
    section_items(b, rng, "the Contract Act, 1872", CONTRACT, bar, "CON")
    section_items(b, rng, "the Transfer of Property Act, 1882", TPA, bar, "TPA")
    subj = [s for _, s in CPC_ORDERS]
    for o, s in CPC_ORDERS:
        b.add("law_cpc", bar, 3, "%s of the Code of Civil Procedure deals with:" % o, s, b.pick(subj, 3, [s]),
              "Fact table: Code of Civil Procedure, 1908, First Schedule", prefix="CPC")
    # which law contains a concept
    act_names = list(ACTS)
    for act, rows in ACTS.items():
        for num, s in rng.sample(rows, min(5, len(rows))):
            b.add("law_which_act", bar, 2, "'%s' is a provision of which law?" % s, act, b.pick(act_names, 3, [act]),
                  "Fact table: section headings of the main Bangladeshi statutes", prefix="ACT")
    years = sorted(set(y for _, y in ACT_YEARS))
    for act, y in ACT_YEARS:
        b.add("law_years", bar, 2, "%s was enacted in:" % act, y, b.pick(years, 3, [y]),
              "Fact table: years of enactment", prefix="ACT")
    meanings = [m for _, m in MAXIMS]
    terms = [t for t, _ in MAXIMS]
    for t, m in MAXIMS:
        b.add("law_maxims", both, 2, "What does '%s' mean?" % t, m, b.pick(meanings, 3, [m]), "Fact table: legal maxims", prefix="MAX")
        b.add("law_maxims", both, 2, "Which Latin term means '%s'?" % m, t, b.pick(terms, 3, [t]), "Fact table: legal maxims", prefix="MAX")
    for q, a, ds in BAR_FACTS:
        b.add("law_bar", bar, 2, q, a, ds, "Fact table: Bar Council and procedure basics", prefix="BAR")


# =============================================================================================
# 9. Banking and economy (job tests)
# =============================================================================================

BANK_TERMS = [("CRR", "Cash Reserve Ratio"), ("SLR", "Statutory Liquidity Ratio"), ("ATM", "Automated Teller Machine"),
              ("KYC", "Know Your Customer"), ("LC", "Letter of Credit"), ("NPL", "Non-Performing Loan"),
              ("RTGS", "Real Time Gross Settlement"), ("BEFTN", "Bangladesh Electronic Funds Transfer Network"),
              ("CIB", "Credit Information Bureau"), ("VAT", "Value Added Tax"), ("TIN", "Taxpayer Identification Number"),
              ("GDP", "Gross Domestic Product"), ("GNP", "Gross National Product"), ("FDI", "Foreign Direct Investment"),
              ("NBR", "National Board of Revenue"), ("DSE", "Dhaka Stock Exchange"), ("CSE", "Chittagong Stock Exchange"),
              ("SME", "Small and Medium Enterprise"), ("MFS", "Mobile Financial Services"), ("EPZ", "Export Processing Zone"),
              ("IPO", "Initial Public Offering"), ("CPI", "Consumer Price Index"), ("SWIFT", "Society for Worldwide Interbank Financial Telecommunication"),
              ("IMF", "International Monetary Fund"), ("BSEC", "Bangladesh Securities and Exchange Commission")]
BANK_FACTS = [
    ("The central bank of Bangladesh is:", "Bangladesh Bank", ["Sonali Bank", "Janata Bank", "Agrani Bank"]),
    ("The head office of Bangladesh Bank is in:", "Motijheel, Dhaka", ["Agargaon, Dhaka", "Gulshan, Dhaka", "Agrabad, Chattogram"]),
    ("Who issues currency notes in Bangladesh (except the one and two taka government notes)?", "Bangladesh Bank",
     ["Ministry of Finance", "Sonali Bank", "National Board of Revenue"]),
    ("Who collects VAT and income tax in Bangladesh?", "National Board of Revenue", ["Bangladesh Bank", "Ministry of Commerce", "Election Commission"]),
    ("Inflation means a general:", "Rise in prices", ["Fall in prices", "Rise in employment", "Fall in money supply"]),
    ("A bank cheque payable only through a bank account is:", "A crossed cheque", ["A bearer cheque", "An open cheque", "A stale cheque"]),
    ("A cheque presented after its validity period is called:", "Stale cheque", ["Post-dated cheque", "Crossed cheque", "Bearer cheque"]),
    ("A cheque bearing a future date is called:", "Post-dated cheque", ["Stale cheque", "Ante-dated cheque", "Crossed cheque"]),
    ("Money kept with a bank for a fixed period at a fixed rate is a:", "Fixed deposit", ["Current deposit", "Demand draft", "Overdraft"]),
    ("Allowing a customer to withdraw more than the balance in a current account is called:", "Overdraft",
     ["Fixed deposit", "Standing instruction", "Remittance"]),
]


def gen_banking(b, rng):
    fam = ("job",)
    full = [f for _, f in BANK_TERMS]
    for a, f in BANK_TERMS:
        b.add("banking_terms", fam, 1, "In banking and economics, '%s' stands for:" % a, f, b.pick(full, 3, [f]),
              "Fact table: banking abbreviations", prefix="BNK")
    for q, a, ds in BANK_FACTS:
        b.add("banking", fam, 1, q, a, ds, "Fact table: banking basics", prefix="BNK")


# =============================================================================================

def validate(items):
    errs = []
    ids = set()
    for it in items:
        if it["id"] in ids:
            errs.append("duplicate id %s" % it["id"])
        ids.add(it["id"])
        for lang in ("en", "bn"):
            if "q_" + lang in it:
                opts = it.get("options_" + lang, [])
                if len(opts) != 4 or len(set(opts)) != 4:
                    errs.append("%s: bad %s options %r" % (it["id"], lang, opts))
                if any(o.strip() == "" for o in opts):
                    errs.append("%s: empty option" % it["id"])
        if not (0 <= it["answer"] <= 3):
            errs.append("%s: answer out of range" % it["id"])
        if "q_en" not in it and "q_bn" not in it:
            errs.append("%s: no question text" % it["id"])
    return errs


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--sample", type=int, default=0)
    ap.add_argument("--seed", type=int, default=SEED)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    b = Bank(rng)
    gen_math(b, rng)
    gen_ict(b, rng)
    gen_bangladesh(b, rng)
    gen_international(b, rng)
    gen_science(b, rng)
    gen_english(b, rng)
    gen_bangla(b, rng)
    gen_law(b, rng)
    gen_banking(b, rng)
    gaps = question_bn.bengalify(b.items, CAPITALS, SI_UNITS)
    if gaps:
        print("Bengali gaps (these items stay English-only):")
        for g in gaps[:60]:
            print("  ", g)
        print("  %d gaps" % len(gaps))
    errs = validate(b.items)
    if errs:
        print("\n".join(errs[:40]))
        print("%d problems" % len(errs))
        sys.exit(1)
    fam = {}
    cats = {}
    for it in b.items:
        for f in it["families"]:
            fam[f] = fam.get(f, 0) + 1
        top = it["category"].split("_")[0]
        cats[top] = cats.get(top, 0) + 1
    print("Practice questions: %d" % len(b.items))
    print("  by family (an item can serve several):", fam)
    print("  by subject:", dict(sorted(cats.items())))
    if args.sample:
        for it in rng.sample(b.items, args.sample):
            q = it.get("q_bn") or it.get("q_en")
            opts = it.get("options_bn") or it.get("options_en")
            print("-", it["id"], q, "|", opts, "->", opts[it["answer"]])
    if not args.check:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        data = {"schema_version": 2, "generator": "tools/generate_questions.py", "seed": args.seed,
                "notes": "Original practice questions in the style of BCS, job and Bar enrolment tests. Not past papers. "
                         "Each item's 'basis' says whether it was computed or taken from a fact table in the generator.",
                "questions": b.items}
        OUT.write_text(json.dumps(data, ensure_ascii=False, indent=0), encoding="utf-8")
        print("Wrote", OUT.relative_to(ROOT), "(%.1f MB)" % (OUT.stat().st_size / 1e6))


if __name__ == "__main__":
    main()
