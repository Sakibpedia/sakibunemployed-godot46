#!/usr/bin/env python3
"""The story of "S M Nazmuz Sakib is unemployed": five acts and the side jobs, written here and
exported to Data/Story/missions.json for scripts/missions/MissionDirector.gd.

Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

Every line is bilingual. Step types are documented in docs/ARCHITECTURE.md section 7.
Run:  python3 tools/make_story.py   (then python3 tools/check_story.py)
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Data" / "Story" / "missions.json"


def L(who, bn, en):
    return {"who": who, "bn": bn, "en": en}


def T(bn, en):
    return {"bn": bn, "en": en}


def mission(mid, act, kind, title, giver, start_poi, steps, requires=(), hours=None, rewards=None, intro=(), on_fail="retry", repeat=False):
    m = {"id": mid, "act": act, "kind": kind, "title": title, "giver": giver, "start_poi": start_poi, "requires": list(requires),
         "intro": list(intro), "steps": steps, "rewards": rewards or {}, "on_fail": on_fail}
    if hours:
        m["hours"] = list(hours)
    if repeat:
        m["repeat"] = True
    return m


M = []

# =============================================================================================
# ACT 1 — The admit card (Jurain, Kajla, Dania)
# =============================================================================================
M.append(mission("m01", 1, "story", T("সকাল", "Morning"), "rina_apa", "mess", [
    {"type": "talk", "npc": "rina_apa", "text": T("রিনা আপার সঙ্গে কথা বলো", "Talk to Rina Apa"), "lines": [
        L("rina_apa", "সাকিব, এগারোটা বাজে! চাকরিপ্রার্থী মানুষ এত ঘুমায়?", "Sakib, it's nearly eleven! Does a job-seeker sleep this much?"),
        L("sakib", "আপা, রাত তিনটা পর্যন্ত সংবিধান পড়েছি।", "Apa, I read the constitution until three."),
        L("rina_apa", "সংবিধান পড়ে পেট ভরে না। কালামের দোকানে যা, শুনলাম সার্কুলার বেরিয়েছে।", "The constitution won't fill your stomach. Go to Kalam's stall; I hear the circular is out."),
        L("rina_apa", "আর শোন, সন্ধ্যার আগে ঘরে ফিরবি। জুরাইনে রাত ভালো না।", "And listen: be home before dusk. Nights in Jurain are not good.")]},
    {"type": "goto", "poi": "tea_flyover", "radius": 7, "text": T("কাজলা ফ্লাইওভারের নিচে কালাম মামার দোকানে যাও (F চেপে CNG নিতে পারো)", "Go to Kalam Mama's stall under the Kajla flyover (press F to take a CNG)")},
    {"type": "talk", "npc": "kalam", "text": T("কালাম মামার সঙ্গে কথা বলো", "Talk to Kalam Mama"), "lines": [
        L("kalam", "আসেন আসেন, বেকার সমিতির সভাপতি! রং চা?", "Come, come, president of the unemployed association! Red tea?"),
        L("kalam", "বিসিএসের প্রিলির সার্কুলার বেরিয়েছে। প্রবেশপত্র দনিয়া কলেজের অফিস থেকে নিতে হবে।", "The BCS prelim circular is out. The admit card is issued at the Dania College office."),
        L("kalam", "তবে আগে একটা ভালো কলম কিনে নেন। সেলিমের সুপারস্টোরে এক্সপোর্ট কোয়ালিটি।", "But buy a good pen first. Selim's superstore has 'export quality'."),
        L("sakib", "কলম তো কলমই, মামা।", "A pen is a pen, Mama."),
        L("kalam", "পরীক্ষার হলে কালি শেষ হলে বুঝবেন।", "You'll see when the ink runs out in the exam hall.")]},
], rewards={"money": 0, "respect": 1}, intro=[L("narrator", "জুরাইন, এক বেকার সকাল।", "Jurain. An unemployed morning.")]))

M.append(mission("m02", 1, "story", T("পরীক্ষার কলম", "The exam pen"), "kalam", "tea_flyover", [
    {"type": "goto", "poi": "superstore", "radius": 5, "text": T("কাজলা সুপারস্টোরে যাও", "Go to Kajla Superstore")},
    {"type": "talk", "npc": "selim", "text": T("সেলিম ভাইয়ের সঙ্গে কথা বলো", "Talk to Selim Bhai"), "lines": [
        L("selim", "এক্সপোর্ট কোয়ালিটি কলম? শেষ পিস। কিন্তু যে-সে পায় না।", "An export-quality pen? The last one. But not just anyone gets it."),
        L("selim", "চাকরির পরীক্ষার তিনটা প্রশ্ন। দুইটা পারলে কলম আপনার, দাম অর্ধেক।", "Three job-test questions. Get two and the pen is yours at half price.")]},
    {"type": "exam", "npc": "selim", "mode": "gate", "family": "job", "count": 3, "pass": 2, "allow_bribe": True, "bribe_cost": 120,
     "text": T("সেলিম ভাইয়ের প্রশ্নের উত্তর দাও", "Answer Selim Bhai's questions"), "on_fail": "retry"},
    {"type": "reward", "item": "exam_pen", "money": -20, "text": T("কলম পেলে", "You got the pen")},
], requires=["m01"], rewards={"respect": 2}))

M.append(mission("m03", 1, "story", T("প্রবেশপত্র", "The admit card"), "kalam", "tea_flyover", [
    {"type": "goto", "poi": "college_office", "radius": 5, "text": T("দনিয়া কলেজের অফিসে যাও", "Go to the Dania College office")},
    {"type": "talk", "npc": "motin", "text": T("কেরানি মতিনের সঙ্গে কথা বলো", "Talk to Motin the clerk"), "lines": [
        L("motin", "প্রবেশপত্র? লাইনে দাঁড়ান। লাইন কাল শুরু হবে।", "An admit card? Queue up. The queue starts tomorrow."),
        L("sakib", "ভাই, আজকেই লাগবে।", "Brother, I need it today."),
        L("motin", "আজকে লাগলে চা-নাস্তার খরচ পাঁচশো। নইলে আমার তিনটা প্রশ্ন।", "If it's today, tea-and-snacks costs five hundred. Otherwise, my three questions.")],
     "choices": [{"id": "pay", "bn": "পাঁচশো টাকা দাও", "en": "Pay the five hundred", "money": -500, "honesty": -8, "flag": "bribed_motin"},
                 {"id": "answer", "bn": "প্রশ্ন করেন", "en": "Ask your questions", "honesty": 2}]},
    {"type": "exam", "npc": "motin", "mode": "gate", "family": "bcs", "count": 3, "pass": 2, "skip_if_flag": "bribed_motin",
     "text": T("মতিনের প্রশ্নের উত্তর দাও", "Answer Motin's questions"), "on_fail": "retry"},
    {"type": "talk", "npc": "principal", "text": T("অধ্যক্ষের সই নাও", "Get the Principal's signature"), "lines": [
        L("principal", "এলএলবি পাস, বিসিএস দিচ্ছ। ভালো। কিন্তু শোনো, কোচিংয়ের প্রশ্ন কিনবে না।", "An LLB graduate sitting the BCS. Good. But listen: don't buy coaching-centre questions."),
        L("principal", "এ বছর কাজলায় প্রশ্ন ফাঁসের গুজব শুনছি। সৎ থাকো।", "I hear rumours of a leak in Kajla this year. Stay honest.")]},
    {"type": "reward", "item": "admit_card", "text": T("প্রবেশপত্র হাতে", "Admit card in hand")},
], requires=["m02"], hours=[8.0, 16.5], rewards={"respect": 3}))

M.append(mission("m04", 1, "story", T("পোস্টারের শহর", "City of posters"), "habib_sir", "school", [
    {"type": "talk", "npc": "habib_sir", "text": T("হাবিব স্যারের সঙ্গে কথা বলো", "Talk to Habib Sir"), "lines": [
        L("habib_sir", "সাকিব! দেয়ালগুলো দেখেছ? প্রতিটা পোস্টার একটা পাঠ।", "Sakib! Have you seen the walls? Every poster is a lesson."),
        L("habib_sir", "কোচিংয়ের বিজ্ঞাপন থেকে সার্কুলার, সব পড়ো। আর লাল পোস্টারগুলো, 'প্রশ্ন চাই', ওগুলো ছিঁড়ে ফেলো।", "From coaching ads to circulars, read them all. And the red ones, 'Want the questions?': tear those down.")]},
    {"type": "posters", "count": 5, "mode": "read", "text": T("পাঁচটা পোস্টার পড়ো (কাছে গিয়ে E)", "Read five posters (walk up and press E)")},
    {"type": "posters", "count": 2, "mode": "tear", "text": T("দুটো ফাঁস-চক্রের পোস্টার ছিঁড়ে ফেলো", "Tear down two leak-gang posters")},
    {"type": "talk", "npc": "habib_sir", "text": T("হাবিব স্যারকে জানাও", "Report to Habib Sir"), "lines": [
        L("habib_sir", "ভালো। ওরা খেয়াল করবে, সাবধানে থেকো।", "Good. They will notice; be careful."),
        L("habib_sir", "এই নাও, পুরোনো দিনের নিয়ম: প্রতিদিন দশটা প্রশ্ন।", "Here, an old rule: ten questions a day.")]},
], requires=["m03"], rewards={"tokens": 2, "honesty": 3}))

M.append(mission("m05", 1, "story", T("প্রথম সন্ধ্যা", "The first dusk"), "rina_apa", "library", [
    {"type": "wait", "until_hour": 16.8, "text": T("বিকেল পর্যন্ত পাঠাগারে পড়ো (অপেক্ষা)", "Study at the library until late afternoon (wait)")},
    {"type": "cutscene", "lines": [
        L("rina_apa", "(ফোনে) সাকিব, সূর্য ডুবছে। সন্ধ্যার আগে মেসে ফেরো!", "(on the phone) Sakib, the sun is going down. Get back to the mess before dusk!"),
        L("sakib", "আসছি, আপা।", "On my way, Apa.")]},
    {"type": "goto", "poi": "mess", "radius": 4, "before_hour": 18.2, "text": T("অন্ধকার হওয়ার আগে মেসে ফেরো", "Get back to the mess before dark")},
    {"type": "talk", "npc": "rina_apa", "text": T("রিনা আপার সঙ্গে কথা বলো", "Talk to Rina Apa"), "lines": [
        L("rina_apa", "এসেছিস! শোন, এই এলাকায় যারা অপঘাতে মরে, উত্তর না পেলে রাতে ফিরে আসে।", "You're back! Listen: those who die by violence here come back at night if they are left unanswered."),
        L("rina_apa", "রাস্তায় বাতির নিচে থাকবি, অন্ধকার গলিতে না। ঘরের ভেতরে ওরা ঢোকে না।", "Stay under the street lights, never in dark lanes. They do not come indoors."),
        L("rina_apa", "এই টর্চটা রাখ। ব্যাটারি ফুরালে দোকান থেকে কিনবি।", "Keep this torch. Buy batteries from the shop when they run out.")]},
    {"type": "reward", "item": "batteries", "count": 2, "text": T("টর্চ আর ব্যাটারি পেলে", "You got a torch and batteries")},
], requires=["m04"], rewards={"respect": 2}, on_fail="retry"))

# =============================================================================================
# ACT 2 — Coaching wars (Kajla, Sontek)
# =============================================================================================
M.append(mission("m06", 2, "story", T("টিউশনি", "The tuition"), "moushumi", "pond", [
    {"type": "talk", "npc": "moushumi", "text": T("মৌসুমী খালার সঙ্গে কথা বলো", "Talk to Moushumi Khala"), "lines": [
        L("moushumi", "তুমি নাকি এলএলবি? আমার রাফিকে পড়াবে? মাসে দুই হাজার।", "They say you're an LLB? Will you teach my Rafi? Two thousand a month."),
        L("sakib", "খালা, তিন হাজার।", "Khala, three thousand."),
        L("moushumi", "আগে দেখি পারো কিনা। রাফি, প্রশ্ন কর।", "First let me see if you can. Rafi, ask him.")]},
    {"type": "exam", "npc": "rafi", "mode": "tuition", "family": "bcs", "subject": "math", "count": 4, "pass": 3,
     "text": T("রাফির প্রশ্নের উত্তর দাও", "Answer Rafi's questions"), "on_fail": "retry"},
    {"type": "reward", "money": 2500, "text": T("প্রথম মাসের বেতন", "The first month's fee")},
], requires=["m05"], hours=[9.0, 17.0], rewards={"respect": 3}))

M.append(mission("m07", 2, "story", T("শর্টকাটের অফার", "Shortcut's offer"), "kalam", "tea_flyover", [
    {"type": "goto", "poi": "coaching", "radius": 5, "text": T("শর্টকাট কোচিংয়ে যাও", "Go to Shortcut Coaching")},
    {"type": "talk", "npc": "shahjahan", "text": T("শাহজাহানের সঙ্গে দেখা করো", "Meet Shahjahan"), "lines": [
        L("shahjahan", "সাকিব সাহেব! আইনের ছাত্র, আমাদের দরকার আপনার মতো শিক্ষক।", "Mr Sakib! A law graduate: we need teachers like you."),
        L("shahjahan", "একটা ছোট ইন্টারভিউ। তারপর মাসে বিশ হাজার।", "A small interview. Then twenty thousand a month.")]},
    {"type": "exam", "npc": "shahjahan", "mode": "interview", "family": "bcs", "count": 5, "pass": 3, "text": T("ইন্টারভিউ দাও", "Take the interview"), "on_fail": "continue"},
    {"type": "choice", "npc": "shahjahan", "text": T("সিদ্ধান্ত নাও", "Decide"), "lines": [
        L("shahjahan", "চমৎকার। আসল কাজটা বলি: পরীক্ষার আগের রাতে 'সাজেশন' পৌঁছে দেবেন। প্রশ্নগুলো... আসল।", "Excellent. Now the real work: the night before the exam you deliver 'suggestions'. The questions are... real."),
        L("shahjahan", "রাজি থাকলে নিজের প্রশ্নও পাবেন। ক্যাডার নিশ্চিত।", "Agree and you get your own paper too. Cadre guaranteed.")],
     "choices": [{"id": "refuse", "bn": "না। আমি নিজে পড়ে পাস করব।", "en": "No. I'll pass by studying.", "honesty": 8, "flag": "refused_shahjahan"},
                 {"id": "accept", "bn": "রাজি (ভেতর থেকে প্রমাণ জোগাড় করব)", "en": "Agree (and gather proof from inside)", "honesty": -4, "money": 2000, "flag": "inside_man"}]},
    {"type": "talk", "npc": "kalam", "text": T("কালাম মামাকে সব বলো", "Tell Kalam Mama everything"), "lines": [
        L("kalam", "শাহজাহান! এই লোক তিন বছর ধরে চাকরি বেচে।", "Shahjahan! That man has sold jobs for three years."),
        L("kalam", "ওর কুরিয়ার দুলাল প্রতি বৃহস্পতিবার মোটরসাইকেলে প্যাকেট নিয়ে যায়।", "His courier Dulal carries packets by motorbike every Thursday.")]},
], requires=["m06"], hours=[9.0, 20.0], rewards={"respect": 2}))

M.append(mission("m08", 2, "story", T("কুরিয়ার", "The courier"), "kalam", "tea_flyover", [
    {"type": "goto", "poi": "superstore", "radius": 10, "text": T("সুপারস্টোরের সামনে দুলালকে খোঁজো", "Find Dulal outside the superstore")},
    {"type": "chase", "npc": "dulal", "spawn_poi": "superstore", "route": ["coaching", "pond", "mosque", "tower_gate"], "time": 150,
     "text": T("দুলালকে ধরো! কাছে গিয়ে ঘুষি দাও", "Catch Dulal! Get close and hit him")},
    {"type": "collect", "item": "leak_packet", "at_npc": "dulal", "text": T("ফাঁস প্রশ্নের প্যাকেট তুলে নাও", "Pick up the leaked-paper packet")},
], requires=["m07"], hours=[8.0, 18.0], rewards={"money": 500, "respect": 4}))

M.append(mission("m09", 2, "story", T("চায়ের দোকানের টুর্নামেন্ট", "The tea-stall tournament"), "kalam", "tea_flyover", [
    {"type": "talk", "npc": "kalam", "text": T("কালাম মামার সঙ্গে কথা বলো", "Talk to Kalam Mama"), "lines": [
        L("kalam", "আজ আমার দোকানে কুইজ টুর্নামেন্ট! তিন রাউন্ড। জিতলে একটা জিনিস দেব।", "A quiz tournament at my stall today! Three rounds. Win and I'll give you something.")]},
    {"type": "exam", "npc": "kalam", "mode": "duel", "family": "bcs", "count": 3, "pass": 2, "text": T("প্রথম রাউন্ড", "Round one"), "on_fail": "retry"},
    {"type": "exam", "npc": "kalam", "mode": "duel", "family": "job", "count": 3, "pass": 2, "text": T("দ্বিতীয় রাউন্ড", "Round two"), "on_fail": "retry"},
    {"type": "exam", "npc": "kalam", "mode": "duel", "family": "bar", "count": 3, "pass": 2, "text": T("ফাইনাল", "The final"), "on_fail": "retry"},
    {"type": "talk", "npc": "kalam", "text": T("পুরস্কার নাও", "Collect the prize"), "lines": [
        L("kalam", "চ্যাম্পিয়ন! এই লোহার রডটা রাখেন। রাতে কাজে লাগবে। লোহা দেখলে ওরা পিছু হটে।", "Champion! Keep this iron rod. It helps at night: they back away from iron.")]},
    {"type": "reward", "item": "iron_rod", "text": T("লোহার রড পেলে (Q দিয়ে অস্ত্র বদলাও)", "You got an iron rod (Q switches weapons)")},
], requires=["m08"], rewards={"respect": 5, "money": 300}))

M.append(mission("m10", 2, "story", T("বুলু ভাইয়ের হামলা", "Bulu Bhai's raid"), "kalam", "tea_flyover", [
    {"type": "cutscene", "lines": [
        L("bulu", "কালাম! তোর দোকানে নাকি আমাদের প্যাকেট আছে?", "Kalam! They say our packet is at your stall?"),
        L("kalam", "সাকিব ভাই, ওরা এসে গেছে!", "Sakib bhai, they're here!")]},
    {"type": "defend", "poi": "tea_flyover", "waves": [{"count": 3, "role": "goon", "armed": False}, {"count": 3, "role": "goon", "armed": True}],
     "text": T("দোকান রক্ষা করো", "Defend the stall")},
    {"type": "talk", "npc": "kalam", "text": T("কালাম মামা ঠিক আছেন কিনা দেখো", "Check on Kalam Mama"), "lines": [
        L("kalam", "বুলু পালিয়েছে। এই পিস্তলটা আমার ভাইয়ের ছিল। আত্মরক্ষার জন্য রাখেন।", "Bulu ran. This pistol was my brother's. Keep it for self-defence."),
        L("kalam", "কিন্তু মনে রাখবেন: যাকে মারবেন, তার প্রশ্ন শুনবেন। নইলে রাতে ফিরবে।", "But remember: whoever you bring down, hear their question. Otherwise they come back at night.")]},
    {"type": "reward", "item": "pistol", "ammo": 36, "text": T("পিস্তল আর ৩৬ রাউন্ড", "A pistol and 36 rounds")},
], requires=["m09"], rewards={"respect": 5}))

M.append(mission("m11", 2, "story", T("দুলালের শেষ প্রশ্ন", "Dulal's last question"), "nadia", "library", [
    {"type": "talk", "npc": "nadia", "text": T("নাদিয়ার সঙ্গে কথা বলো", "Talk to Nadia"), "lines": [
        L("nadia", "সাকিব, দুলাল আমাকে হুমকি দিয়েছে। ফাঁসের কথা আমি রুমানাকে বলেছিলাম।", "Sakib, Dulal threatened me. I told Rumana about the leak."),
        L("nadia", "ও এখন মসজিদ রোডের দিকে, পিস্তল নিয়ে।", "He's near Masjid Road now, with a pistol.")]},
    {"type": "kill", "targets": [{"npc": "dulal", "poi": "mosque"}], "guards": 2, "text": T("দুলালকে থামাও। পড়ে গেলে তার শেষ প্রশ্ন শোনো (E)", "Stop Dulal. When he falls, hear his last questions (E)")},
    {"type": "talk", "npc": "nadia", "text": T("নাদিয়াকে জানাও", "Tell Nadia"), "lines": [
        L("nadia", "শেষ হলো? তুমি কি ওর প্রশ্নের উত্তর দিয়েছ? না দিলে... আজ রাতে জানালা বন্ধ রেখো।", "Is it over? Did you answer his questions? If not... keep your windows shut tonight.")]},
], requires=["m10"], rewards={"respect": 4}))

# =============================================================================================
# ACT 3 — The question bazaar (Jatrabari, the bus stand, N1)
# =============================================================================================
M.append(mission("m12", 3, "story", T("সাংবাদিক", "The journalist"), "rumana", "library", [
    {"type": "talk", "npc": "rumana", "text": T("রুমানার সঙ্গে কথা বলো", "Talk to Rumana"), "lines": [
        L("rumana", "প্যাকেট যথেষ্ট না। আমার দরকার দামের তালিকা আর হিসাবের খাতা।", "The packet isn't enough. I need the price list and the ledger."),
        L("rumana", "যাত্রাবাড়ী বাসস্ট্যান্ডের একটা কাউন্টারে ফাঁস প্রশ্ন বিক্রি হয়। ক্রেতা সেজে যাও।", "Leaked papers are sold at a counter in the Jatrabari bus stand. Go as a buyer.")]},
    {"type": "goto", "poi": "bus_stand", "radius": 8, "text": T("যাত্রাবাড়ী বাসস্ট্যান্ডে যাও", "Go to the Jatrabari bus stand")},
    {"type": "talk", "npc": "bulu", "spawn_poi": "bus_stand", "text": T("কাউন্টারে বিক্রেতার সঙ্গে কথা বলো", "Talk to the seller at the counter"), "lines": [
        L("bulu", "প্রশ্ন? আসল পরীক্ষার্থী কিনা আগে দেখি। গোয়েন্দা হলে এখানেই কবর।", "Questions? First let me see if you're a real candidate. If you're a spy, you're buried right here.")]},
    {"type": "exam", "npc": "bulu", "mode": "gate", "family": "bcs", "count": 3, "pass": 2, "text": T("ক্রেতা হিসেবে পরীক্ষা দাও", "Prove you're a buyer"), "on_fail": "fail"},
    {"type": "reward", "item": "price_list", "money": -1000, "text": T("দামের তালিকা হাতে (১০০০ টাকা গেল)", "Price list in hand (Tk 1000 spent)")},
], requires=["m11"], hours=[8.0, 19.0], rewards={"respect": 3}))

M.append(mission("m13", 3, "story", T("মহাসড়কের ট্রাক", "The highway truck"), "jamal", "jatrabari_crossing", [
    {"type": "talk", "npc": "jamal", "text": T("রিকশাওয়ালা জামালের সঙ্গে কথা বলো", "Talk to Jamal the rickshaw puller"), "lines": [
        L("jamal", "আমার ছেলেরা দেখেছে, দুপুরে প্রশ্নের বাক্স ট্রাকে উঠছে। কাজলার র‍্যাম্পে থামাবে।", "My boys saw it: the box of papers goes on a truck at midday. It stops at the Kajla ramp."),
        L("jamal", "একটা সিএনজি নেন, এখনই!", "Take a CNG, now!")]},
    {"type": "drive", "poi": "tea_flyover", "time": 150, "text": T("গাড়ি নিয়ে কাজলার র‍্যাম্পে পৌঁছাও", "Drive to the Kajla ramp")},
    {"type": "defend", "poi": "tea_flyover", "waves": [{"count": 4, "role": "goon", "armed": True}], "text": T("ট্রাকের পাহারাদারদের সামলাও", "Deal with the truck's guards")},
    {"type": "collect", "item": "question_box", "poi": "tea_flyover", "text": T("প্রশ্নের বাক্স তুলে নাও", "Take the box of papers")},
], requires=["m12"], hours=[10.0, 15.0], rewards={"money": 800, "respect": 6}))

M.append(mission("m14", 3, "story", T("আইনের পাঠ", "Lessons in law"), "shirin", "lawyer", [
    {"type": "talk", "npc": "shirin", "text": T("অ্যাডভোকেট শিরিনের সঙ্গে কথা বলো", "Talk to Advocate Shirin"), "lines": [
        L("shirin", "প্রমাণ আছে, ভালো। কিন্তু আদালতে দাঁড়াতে হলে আইন জানতে হবে। তুমি তো এলএলবি।", "You have proof, good. But to stand in court you must know the law. You are an LLB."),
        L("shirin", "বার কাউন্সিলের মতো পাঁচটা প্রশ্ন। চারটা পারলে মামলায় সাক্ষী হিসেবে তোমাকে নেব।", "Five Bar Council-style questions. Get four and I'll take you on as a witness in the case.")]},
    {"type": "exam", "npc": "shirin", "mode": "bar", "family": "bar", "count": 5, "pass": 4, "text": T("বার কাউন্সিলের অনুশীলন", "Bar Council practice"), "on_fail": "retry"},
    {"type": "reward", "item": "enrolment_form", "text": T("বার কাউন্সিলের এনরোলমেন্ট ফরম", "Bar Council enrolment form")},
], requires=["m13"], hours=[9.0, 18.0], rewards={"respect": 5, "honesty": 2}))

M.append(mission("m15", 3, "story", T("থানা", "The police station"), "shirin", "lawyer", [
    {"type": "goto", "poi": "police_station", "radius": 5, "text": T("থানায় যাও", "Go to the police station")},
    {"type": "talk", "npc": "oc_haque", "text": T("ওসি হকের সঙ্গে কথা বলো", "Talk to OC Haque"), "lines": [
        L("oc_haque", "প্রশ্ন ফাঁস? বড় অভিযোগ। আগে দেখি আপনি আইন কতটা জানেন।", "A leak? A serious charge. First let me see how much law you know.")]},
    {"type": "exam", "npc": "oc_haque", "mode": "police", "family": "bar", "count": 3, "pass": 2, "text": T("ওসির জেরা", "The OC's questioning"), "on_fail": "continue"},
    {"type": "choice", "npc": "oc_haque", "text": T("প্রমাণ দেবে?", "Hand over the proof?"), "lines": [
        L("oc_haque", "প্রমাণগুলো আমাকে দিন। আমি দেখব।", "Give me the evidence. I'll look into it.")],
     "choices": [{"id": "give", "bn": "প্রমাণ দাও", "en": "Hand it over", "flag": "trusted_oc", "honesty": 2},
                 {"id": "copy", "bn": "শুধু ফটোকপি দাও", "en": "Give him photocopies only", "flag": "kept_originals", "respect": 2}]},
], requires=["m14"], hours=[9.0, 20.0], rewards={"respect": 3}))

M.append(mission("m16", 3, "story", T("তানভীর", "Tanvir"), "rina_apa", "mess", [
    {"type": "talk", "npc": "rina_apa", "text": T("রিনা আপার সঙ্গে কথা বলো", "Talk to Rina Apa"), "lines": [
        L("rina_apa", "তানভীর সারারাত ফেরেনি। শুনলাম শর্টকাট কোচিংয়ে টাকা নিয়ে গেছে।", "Tanvir didn't come back last night. I hear he took money to Shortcut Coaching.")]},
    {"type": "goto", "poi": "coaching", "radius": 6, "text": T("কোচিংয়ে তানভীরকে খোঁজো", "Find Tanvir at the coaching centre")},
    {"type": "choice", "npc": "tanvir", "spawn_poi": "coaching", "text": T("তানভীরকে বোঝাও", "Talk Tanvir round"), "lines": [
        L("tanvir", "সাকিব, তিনবার ফেল করেছি। এবার প্রশ্ন হাতে। আমাকে থামাস না।", "Sakib, I've failed three times. This time the paper is in my hand. Don't stop me."),
        L("sakib", "তানভীর, ধরা পড়লে আজীবন নিষিদ্ধ। চল, একসঙ্গে পড়ি।", "Tanvir, if you're caught you're banned for life. Come on, let's study together.")],
     "choices": [{"id": "study", "bn": "একসঙ্গে পড়ার কথা দাও (কুইজে প্রমাণ করো)", "en": "Promise to study together (prove it with a quiz)", "flag": "tanvir_saved", "honesty": 3},
                 {"id": "let", "bn": "ওর ইচ্ছা, ছেড়ে দাও", "en": "His choice: let him be", "flag": "tanvir_lost", "honesty": -2}]},
    {"type": "exam", "npc": "tanvir", "mode": "duel", "family": "job", "count": 3, "pass": 2, "only_if_flag": "tanvir_saved",
     "text": T("তানভীরকে দেখাও যে পড়েই পারা যায়", "Show Tanvir it can be done by studying"), "on_fail": "retry"},
], requires=["m15"], rewards={"respect": 2}))

# =============================================================================================
# ACT 4 — Jurain nights (Jurain, the graveyard, the rail gate)
# =============================================================================================
M.append(mission("m17", 4, "story", T("কবরস্থানের কেয়ারটেকার", "The graveyard caretaker"), "fakir_chan", "graveyard_shed", [
    {"type": "talk", "npc": "fakir_chan", "text": T("ফকির চানের সঙ্গে কথা বলো", "Talk to Fakir Chan"), "lines": [
        L("fakir_chan", "বাবা, প্রতি রাতে এখানে একজন পরিদর্শক হাঁটেন। বহু বছর আগে ফাঁস-চক্র তাকে মেরেছিল।", "Son, every night an invigilator walks here. The leak ring killed him many years ago."),
        L("fakir_chan", "তার আগে ছোটগুলোকে মুক্তি দাও। রাতে এখানে থাকো, ওদের প্রশ্নের উত্তর দাও।", "Free the small ones first. Stay here tonight and answer their questions.")]},
    {"type": "wait", "until_hour": 19.0, "text": T("সন্ধ্যা পর্যন্ত অপেক্ষা করো", "Wait for nightfall")},
    {"type": "banish", "count": 1, "text": T("একটা ভূতকে মুক্তি দাও (কাছে গিয়ে E, প্রশ্নের উত্তর)", "Free one ghost (go close, press E, answer it)")},
    {"type": "talk", "npc": "fakir_chan", "text": T("ফকির চানকে জানাও", "Tell Fakir Chan"), "lines": [
        L("fakir_chan", "এক জন গেল। শাহজাহানের খাতাটা আমার ঘরের পাশে পুঁতে রেখেছিল বুলু, আমি দেখেছি।", "One is gone. Bulu buried Shahjahan's ledger beside my shed; I saw him."),
        L("fakir_chan", "কিন্তু রাতে খুঁড়তে গেলে প্রথম পরীক্ষক জাগবেন।", "But dig at night and the First Examiner will wake.")]},
], requires=["m16"], hours=[15.0, 23.0], rewards={"respect": 4, "tokens": 1}))

M.append(mission("m18", 4, "story", T("লোডশেডিং", "Load-shedding"), "rina_apa", "mess", [
    {"type": "talk", "npc": "rina_apa", "text": T("রিনা আপার সঙ্গে কথা বলো", "Talk to Rina Apa"), "lines": [
        L("rina_apa", "বাজারে গিয়েছিলাম, কারেন্ট চলে গেল। একা ফিরতে ভয় করছে। বাজার থেকে আমাকে নিয়ে আয়।", "I went to the market and the power went. I'm scared to walk back alone. Fetch me from the market.")]},
    {"type": "goto", "poi": "bazar", "radius": 8, "text": T("যাত্রাবাড়ী কাঁচাবাজারে যাও", "Go to the Jatrabari kitchen market")},
    {"type": "escort", "npc": "rina_apa", "spawn_poi": "bazar", "to": "mess", "power_cut": "jurain", "text": T("রিনা আপাকে মেসে পৌঁছে দাও; টর্চ জ্বালাও (T)", "Walk Rina Apa home to the mess; use the torch (T)")},
], requires=["m17"], hours=[18.3, 23.5], rewards={"respect": 5, "honesty": 2}))

M.append(mission("m19", 4, "story", T("রেলগেটের ফাঁদ", "Ambush at the rail gate"), "jamal", "jatrabari_crossing", [
    {"type": "talk", "npc": "jamal", "text": T("জামালের সঙ্গে কথা বলো", "Talk to Jamal"), "lines": [
        L("jamal", "বুলু জুরাইন রেলগেটে লোক জড়ো করছে। আপনাকে ধরবে।", "Bulu is gathering men at the Jurain rail gate. They're coming for you.")]},
    {"type": "kill", "targets": [{"npc": "bulu", "poi": "rail_gate"}], "guards": 4, "text": T("বুলুকে থামাও; তার শেষ প্রশ্ন শোনো", "Stop Bulu; hear his last questions")},
    {"type": "collect", "item": "ledger_key", "at_npc": "bulu", "text": T("বুলুর পকেট থেকে চাবি নাও", "Take the key from Bulu's pocket")},
], requires=["m18"], hours=[7.0, 18.0], rewards={"money": 1500, "respect": 6}))

M.append(mission("m20", 4, "story", T("হিসাবের খাতা", "The ledger"), "fakir_chan", "graveyard_shed", [
    {"type": "wait", "until_hour": 21.0, "text": T("রাত নয়টা পর্যন্ত অপেক্ষা করো", "Wait until nine at night")},
    {"type": "collect", "item": "ledger", "poi": "graveyard_shed", "text": T("কেয়ারটেকারের ঘরের পাশ থেকে খাতা খুঁড়ে তোলো", "Dig up the ledger beside the caretaker's shed")},
    {"type": "survive", "until_hour": 23.0, "spawn_ghost": "first_examiner", "text": T("প্রথম পরীক্ষক জেগেছেন! রাত এগারোটা পর্যন্ত বেঁচে থাকো", "The First Examiner has woken! Survive until eleven")},
], requires=["m19"], hours=[19.0, 22.5], rewards={"respect": 4}))

M.append(mission("m21", 4, "story", T("প্রথম পরীক্ষক", "The First Examiner"), "fakir_chan", "graveyard_shed", [
    {"type": "talk", "npc": "fakir_chan", "text": T("ফকির চানের সঙ্গে কথা বলো", "Talk to Fakir Chan"), "lines": [
        L("fakir_chan", "তিনি একা ছাড়বেন না। পাঁচটা প্রশ্ন, বাবা। তিনটা টোকেন সঙ্গে রাখো।", "He will not let go alone. Five questions, son. Keep three study tokens with you.")]},
    {"type": "wait", "until_hour": 20.0, "text": T("রাতের জন্য অপেক্ষা করো", "Wait for the night")},
    {"type": "boss_ghost", "spirit": "first_examiner", "poi": "graveyard", "count": 5, "pass": 4, "text": T("প্রথম পরীক্ষককে খুঁজে তার প্রশ্নের উত্তর দাও", "Find the First Examiner and answer his questions")},
], requires=["m20"], rewards={"respect": 8, "honesty": 6, "tokens": 2}))

# =============================================================================================
# ACT 5 — Viva (Dania College, the Tower, the rooftops)
# =============================================================================================
M.append(mission("m22", 5, "story", T("প্রিলিমিনারি", "The preliminary"), "rina_apa", "mess", [
    {"type": "wait", "until_hour": 7.5, "text": T("পরীক্ষার দিনের সকাল (ঘুমাও বা অপেক্ষা করো)", "Exam-day morning (sleep or wait)")},
    {"type": "goto", "poi": "dania_college", "radius": 8, "before_hour": 9.5, "text": T("সাড়ে নয়টার আগে দনিয়া কলেজে পৌঁছাও! পথে শাহজাহানের লোক", "Reach Dania College before 9:30! Shahjahan's men are on the way")},
    {"type": "exam", "npc": "principal", "mode": "prelim", "family": "bcs", "cited_only": True, "count": 10, "pass": 6, "text": T("বিসিএস প্রিলিমিনারি পরীক্ষা", "The BCS preliminary exam"), "on_fail": "continue"},
    {"type": "cutscene", "lines": [
        L("principal", "খাতা জমা। ফল জানা যাবে ভাইভার দিন।", "Papers in. Results on the day of the viva.")]},
], requires=["m21"], hours=[5.0, 9.4], rewards={"respect": 5}))

M.append(mission("m23", 5, "story", T("টাওয়ার", "The Tower"), "nadia", "library", [
    {"type": "talk", "npc": "nadia", "text": T("নাদিয়ার সঙ্গে কথা বলো", "Talk to Nadia"), "lines": [
        L("nadia", "রুমানাকে তুলে নিয়ে গেছে! সোনটেকের টাওয়ারের ছাদে। শাহজাহান খাতা চায়।", "They've taken Rumana! To the roof of the Tower in Sontek. Shahjahan wants the ledger.")]},
    {"type": "goto", "poi": "tower_gate", "radius": 5, "text": T("টাওয়ারের গেটে যাও", "Go to the Tower gate")},
    {"type": "exam", "npc": "ramzan", "spawn_poi": "tower_gate", "mode": "gate", "family": "job", "count": 3, "pass": 2, "allow_bribe": True, "bribe_cost": 300,
     "text": T("দারোয়ান রমজানের প্রশ্ন", "Ramzan the guard's questions"), "on_fail": "retry"},
    {"type": "goto", "poi": "tower_roof", "radius": 12, "text": T("সিঁড়ি দিয়ে ছাদে ওঠো (গেটের পাশে E)", "Take the stairs to the roof (E beside the gate)")},
    {"type": "defend", "poi": "tower_roof", "waves": [{"count": 4, "role": "goon", "armed": True}], "text": T("ছাদের পাহারাদারদের সামলাও", "Deal with the guards on the roof")},
], requires=["m22"], rewards={"respect": 6}))

M.append(mission("m24", 5, "story", T("শর্টকাট", "Shortcut"), "nadia", "tower_roof", [
    {"type": "choice", "npc": "shahjahan", "spawn_poi": "tower_roof", "text": T("শাহজাহানের মুখোমুখি", "Face Shahjahan"), "lines": [
        L("shahjahan", "সাকিব সাহেব, এত কষ্ট কেন? খাতাটা দিন, কাল সকালে আপনি ক্যাডার।", "Mr Sakib, why so much trouble? Give me the ledger and tomorrow morning you are a cadre."),
        L("rumana", "সাকিব, ওর কথা শুনো না!", "Sakib, don't listen to him!")],
     "choices": [{"id": "expose", "bn": "খাতা রুমানার কাছে যাবে, তুমি পুলিশের কাছে", "en": "The ledger goes to Rumana; you go to the police", "flag": "ending_expose", "honesty": 10},
                 {"id": "deal", "bn": "চুক্তি: আমি ক্যাডার, তুমি মুক্ত", "en": "Deal: I become a cadre, you walk free", "flag": "ending_deal", "honesty": -25, "money": 50000},
                 {"id": "fight", "bn": "কথা শেষ", "en": "Enough talk", "flag": "ending_fight"}]},
    {"type": "kill", "targets": [{"npc": "shahjahan", "poi": "tower_roof"}], "guards": 3, "only_if_flag": "ending_fight",
     "text": T("শাহজাহানকে থামাও; তার শেষ প্রশ্ন শোনো", "Stop Shahjahan; hear his last questions")},
    {"type": "cutscene", "lines": [
        L("rumana", "খাতাটা কাল সকালের পত্রিকায় যাবে। ধন্যবাদ, সাকিব।", "The ledger goes in tomorrow morning's paper. Thank you, Sakib.")]},
], requires=["m23"], rewards={"respect": 10}))

M.append(mission("m25", 5, "story", T("ভাইভা বোর্ড", "The viva board"), "principal", "exam_hall", [
    {"type": "goto", "poi": "dania_college", "radius": 8, "text": T("দনিয়া কলেজে ভাইভা বোর্ডে যাও", "Go to the viva board at Dania College")},
    {"type": "talk", "npc": "viva_chair", "spawn_poi": "dania_college", "text": T("বোর্ডের সামনে বসো", "Sit before the board"), "lines": [
        L("viva_chair", "এস এম নাজমুয সাকিব। এলএলবি। প্রিলিতে পাস। শুনলাম তুমি নাকি প্রশ্ন ফাঁস চক্র ধরিয়ে দিয়েছ?", "S M Nazmuz Sakib. LLB. Passed the prelims. I hear you helped bring down the leak ring?"),
        L("viva_chair", "তাহলে দেখি, প্রশ্নের উত্তর তুমি নিজে কতটা জানো।", "Then let us see how many answers you know yourself.")]},
    {"type": "exam", "npc": "viva_chair", "mode": "viva", "family": "", "count": 8, "pass": 5, "text": T("ভাইভা", "The viva"), "on_fail": "continue", "flag_pass": "viva_passed"},
    {"type": "ending", "text": T("শেষ", "The end")},
], requires=["m24"], hours=[9.0, 15.0], rewards={"respect": 10}))

# =============================================================================================
# Side jobs
# =============================================================================================
M.append(mission("s01", 0, "job", T("সিএনজি ভাড়া", "CNG fares"), "jamal", "jatrabari_crossing", [
    {"type": "talk", "npc": "jamal", "text": T("জামালের সঙ্গে কথা বলো", "Talk to Jamal"), "lines": [
        L("jamal", "ড্রাইভার অসুস্থ। একটা ভাড়া টেনে দেন, অর্ধেক আপনার।", "A driver's sick. Run one fare for me; half is yours.")]},
    {"type": "drive", "poi": "random", "time": 180, "text": T("যাত্রী নিয়ে গন্তব্যে যাও", "Drive the passenger to the destination")},
    {"type": "reward", "money": 350, "text": T("ভাড়ার অর্ধেক", "Half the fare")},
], requires=["m02"], repeat=True))

M.append(mission("s02", 0, "job", T("রাফির টিউশনি", "Rafi's tuition"), "moushumi", "pond", [
    {"type": "exam", "npc": "rafi", "mode": "tuition", "family": "bcs", "count": 4, "pass": 3, "text": T("রাফিকে পড়াও", "Teach Rafi"), "on_fail": "fail"},
    {"type": "reward", "money": 400, "text": T("আজকের বেতন", "Today's fee")},
], requires=["m06"], hours=[15.0, 19.5], repeat=True))

M.append(mission("s03", 0, "job", T("ব্যাংক ইন্টারভিউ", "The bank interview"), "liton", "cyber_cafe", [
    {"type": "talk", "npc": "liton", "text": T("লিটনের সঙ্গে কথা বলো", "Talk to Liton"), "lines": [
        L("liton", "ব্যাংকে সিনিয়র অফিসারের আবেদন করে দিলাম। কাল না, এখনই অনলাইন ইন্টারভিউ!", "I've applied for you as a bank Senior Officer. The online interview is right now!")]},
    {"type": "exam", "npc": "liton", "mode": "interview", "family": "job", "count": 8, "pass": 6, "text": T("ব্যাংকের ইন্টারভিউ", "The bank interview"), "on_fail": "fail", "flag_pass": "bank_offer"},
    {"type": "reward", "money": 1000, "respect": 6, "text": T("ব্যাংক থেকে চাকরির প্রস্তাব!", "A job offer from the bank!")},
], requires=["m05"], hours=[9.0, 17.0]))

M.append(mission("s04", 0, "job", T("বার কাউন্সিল মডেল টেস্ট", "Bar Council model test"), "shirin", "lawyer", [
    {"type": "exam", "npc": "shirin", "mode": "bar", "family": "bar", "count": 10, "pass": 6, "text": T("দশটা আইনের প্রশ্ন", "Ten law questions"), "on_fail": "fail"},
    {"type": "reward", "money": 300, "tokens": 1, "text": T("চেম্বারের পারিশ্রমিক", "A fee from the chamber")},
], requires=["m14"], hours=[9.0, 19.0], repeat=True))

M.append(mission("s05", 0, "side", T("পোস্টার শিকারি", "Poster hunter"), "habib_sir", "school", [
    {"type": "posters", "count": 30, "mode": "read", "text": T("ত্রিশটা পোস্টার পড়ো", "Read thirty posters")},
    {"type": "reward", "tokens": 3, "respect": 5, "text": T("হাবিব স্যারের পুরস্কার", "Habib Sir's prize")},
], requires=["m04"]))

M.append(mission("s06", 0, "side", T("মুক্তি", "Release"), "fakir_chan", "graveyard_shed", [
    {"type": "banish", "count": 3, "text": T("তিনটা ভূতকে মুক্তি দাও", "Free three ghosts")},
    {"type": "reward", "money": 1500, "honesty": 5, "text": T("ফকির চানের দোয়া আর টাকা", "Fakir Chan's blessing, and money")},
], requires=["m17"]))

M.append(mission("s07", 0, "side", T("হারানো সনদ", "The lost certificate"), "rina_apa", "mess", [
    {"type": "talk", "npc": "rina_apa", "text": T("রিনা আপার সঙ্গে কথা বলো", "Talk to Rina Apa"), "lines": [
        L("rina_apa", "পাশের বাসার মেয়েটার এসএসসি সনদ বাজারে হারিয়েছে। খুঁজে দে, বাবা।", "The girl next door lost her SSC certificate at the market. Find it, son.")]},
    {"type": "collect", "item": "certificate", "poi": "bazar", "text": T("কাঁচাবাজারে সনদটা খোঁজো", "Find the certificate at the kitchen market")},
    {"type": "deliver", "item": "certificate", "npc": "rina_apa", "text": T("রিনা আপাকে দাও", "Give it to Rina Apa")},
    {"type": "reward", "honesty": 4, "respect": 3, "text": T("মহল্লা খুশি", "The neighbourhood is pleased")},
], requires=["m03"]))

M.append(mission("s08", 0, "side", T("মহল্লার কুইজ মাস্টার", "Quiz master of the neighbourhood"), "kalam", "tea_flyover", [
    {"type": "duels", "count": 10, "text": T("রাস্তায় দশটা প্রশ্ন-লড়াই জেতো", "Win ten street question duels")},
    {"type": "reward", "money": 2000, "respect": 10, "tokens": 2, "text": T("কালাম মামার পুরস্কার", "Kalam Mama's prize")},
], requires=["m09"]))


def main():
    data = {"version": 2, "generator": "tools/make_story.py", "missions": M}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    story = [m for m in M if m["kind"] == "story"]
    print("Wrote %s: %d missions (%d story, %d side jobs)" % (OUT.relative_to(ROOT), len(M), len(story), len(M) - len(story)))


if __name__ == "__main__":
    main()
