class_name PersonGenerator
extends RefCounted
## Makes a whole person from a seed: Bengali name, age, profession, outfit and colours, face from
## faces.json, voice (pitch, rate), temperament, and which exam family they quiz you on.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const MALE := [["রহিম", "Rahim"], ["করিম", "Karim"], ["জামাল", "Jamal"], ["কামাল", "Kamal"], ["রফিক", "Rafiq"],
	["শফিক", "Shafiq"], ["হাবিব", "Habib"], ["নাসির", "Nasir"], ["ফারুক", "Faruk"], ["মনির", "Monir"], ["সেলিম", "Selim"],
	["বাবুল", "Babul"], ["জাহিদ", "Jahid"], ["আরিফ", "Arif"], ["সোহেল", "Sohel"], ["রুবেল", "Rubel"], ["তানভীর", "Tanvir"],
	["শাকিল", "Shakil"], ["মামুন", "Mamun"], ["লিটন", "Liton"], ["হাসান", "Hasan"], ["মেহেদী", "Mehedi"], ["নাঈম", "Nayeem"],
	["রাকিব", "Rakib"], ["সাব্বির", "Sabbir"], ["ইমরান", "Imran"], ["মাসুদ", "Masud"], ["আলমগীর", "Alamgir"], ["দেলোয়ার", "Delwar"],
	["আবুল", "Abul"], ["কাশেম", "Kashem"], ["মতিন", "Motin"], ["দুলাল", "Dulal"], ["স্বপন", "Swapan"], ["প্রদীপ", "Pradip"],
	["বিমল", "Bimal"], ["শ্যামল", "Shyamal"], ["অনুপ", "Anup"], ["রাজু", "Raju"], ["বাদল", "Badal"]]
const FEMALE := [["রিনা", "Rina"], ["শিরিন", "Shirin"], ["নাসিমা", "Nasima"], ["রোকেয়া", "Rokeya"], ["সালমা", "Salma"],
	["ফাতেমা", "Fatema"], ["সুমি", "Sumi"], ["রুমানা", "Rumana"], ["তাসলিমা", "Taslima"], ["সাথী", "Shathi"], ["মিতু", "Mitu"],
	["পাপিয়া", "Papia"], ["ফারজানা", "Farzana"], ["নুসরাত", "Nusrat"], ["তানিয়া", "Tania"], ["লিপি", "Lipi"], ["রুমা", "Ruma"],
	["শিল্পী", "Shilpi"], ["মৌসুমী", "Moushumi"], ["জয়া", "Joya"], ["পূর্ণিমা", "Purnima"], ["শিখা", "Shikha"]]
const SURNAME_M := [["হোসেন", "Hossain"], ["আহমেদ", "Ahmed"], ["ইসলাম", "Islam"], ["রহমান", "Rahman"], ["খান", "Khan"],
	["মিয়া", "Mia"], ["উদ্দিন", "Uddin"], ["চৌধুরী", "Chowdhury"], ["সরকার", "Sarker"], ["দাস", "Das"], ["রায়", "Roy"],
	["শেখ", "Sheikh"], ["মোল্লা", "Molla"], ["হাওলাদার", "Howlader"], ["সিকদার", "Sikder"]]
const SURNAME_F := [["বেগম", "Begum"], ["আক্তার", "Akter"], ["খাতুন", "Khatun"], ["ইসলাম", "Islam"], ["রহমান", "Rahman"],
	["দাস", "Das"], ["চৌধুরী", "Chowdhury"]]
const PROFESSIONS := {
	"ped": ["rickshaw", "tea", "shop", "student", "student", "aunty", "elder", "clerk", "teacher", "journalist", "shop", "rickshaw"],
	"police": ["police"], "goon": ["goon"], "guard": ["guard"], "lawyer": ["lawyer"], "student": ["student"],
}
const PROF_NAMES := {
	"rickshaw": {"bn": "রিকশাচালক", "en": "Rickshaw puller"}, "tea": {"bn": "চা-দোকানি", "en": "Tea seller"},
	"shop": {"bn": "দোকানদার", "en": "Shopkeeper"}, "student": {"bn": "চাকরিপ্রার্থী ছাত্র", "en": "Job-seeking student"},
	"aunty": {"bn": "মহল্লার খালা", "en": "Neighbourhood aunty"}, "elder": {"bn": "মুরুব্বি", "en": "Elder"},
	"clerk": {"bn": "অফিস কেরানি", "en": "Office clerk"}, "teacher": {"bn": "স্কুলশিক্ষক", "en": "Schoolteacher"},
	"journalist": {"bn": "সাংবাদিক", "en": "Journalist"}, "police": {"bn": "পুলিশ", "en": "Police officer"},
	"goon": {"bn": "ফাঁস-চক্রের মাস্তান", "en": "Leak-gang thug"}, "guard": {"bn": "নিরাপত্তারক্ষী", "en": "Security guard"},
	"lawyer": {"bn": "আইনজীবী", "en": "Lawyer"},
}
const FAMILY_FOR := {"student": "bcs", "teacher": "bcs", "journalist": "bcs", "lawyer": "bar", "police": "bar", "clerk": "job",
	"shop": "job", "guard": "job", "goon": "bcs", "rickshaw": "", "tea": "", "aunty": "", "elder": "bcs"}
const SHIRTS := [Color(0.92, 0.92, 0.9), Color(0.55, 0.7, 0.86), Color(0.85, 0.75, 0.55), Color(0.4, 0.45, 0.55),
	Color(0.75, 0.3, 0.3), Color(0.3, 0.5, 0.35), Color(0.9, 0.85, 0.6), Color(0.35, 0.3, 0.45), Color(0.95, 0.6, 0.35)]
const LUNGIS := ["lungi_check_blue", "lungi_check_green", "lungi_check_maroon"]
const KAMEEZ := ["kameez_print_rose", "kameez_print_teal"]


static func make(seed_value: int, role: String = "ped", district: String = "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var profs: Array = PROFESSIONS.get(role, PROFESSIONS["ped"])
	var prof: String = profs[rng.randi_range(0, profs.size() - 1)]
	var female := false
	if prof in ["aunty"]:
		female = true
	elif prof in ["student", "teacher", "journalist", "lawyer", "clerk"]:
		female = rng.randf() < 0.35
	elif prof == "shop":
		female = rng.randf() < 0.12
	var elder := prof == "elder" or (prof == "aunty" and rng.randf() < 0.4)
	var age := rng.randi_range(55, 75) if elder else rng.randi_range(19, 50)
	var first: Array = (FEMALE if female else MALE)[rng.randi_range(0, (FEMALE if female else MALE).size() - 1)]
	var last: Array = (SURNAME_F if female else SURNAME_M)[rng.randi_range(0, (SURNAME_F if female else SURNAME_M).size() - 1)]
	var rec := DhakaMaterials.pick_face(rng.randi(), female, elder)
	var face := String(rec.get("id", ""))
	var skin := Color(0.62, 0.45, 0.33)
	var hair := Color(0.05, 0.04, 0.04)
	var hair_style := "long_middle" if female else "short"
	if not rec.is_empty():
		var sk: Variant = rec.get("skin", null)
		if typeof(sk) == TYPE_ARRAY:
			var ska: Array = sk
			skin = Color(float(ska[0]), float(ska[1]), float(ska[2]))
		var hc: Variant = rec.get("hair", null)
		if typeof(hc) == TYPE_ARRAY:
			var hca: Array = hc
			hair = Color(float(hca[0]), float(hca[1]), float(hca[2]))
		hair_style = String(rec.get("style", hair_style))
	var outfit := "shirt_trousers"
	var cloth := ""
	var lower_cloth := ""
	var shirt: Color = SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
	var lower := Color(0.18, 0.2, 0.26)
	var cap := false
	var cap_color := Color(0.15, 0.2, 0.4)
	match prof:
		"rickshaw", "tea":
			outfit = "lungi_shirt"
			lower_cloth = LUNGIS[rng.randi_range(0, 2)]
			lower = Color(0.4, 0.45, 0.6)
			cloth = "shirt_check_blue" if rng.randf() < 0.3 else ""
		"shop":
			outfit = "kameez" if female else ("lungi_shirt" if rng.randf() < 0.4 else "shirt_trousers")
			lower_cloth = LUNGIS[rng.randi_range(0, 2)]
		"elder":
			outfit = "panjabi"
			cloth = "panjabi_white" if rng.randf() < 0.6 else "panjabi_sky"
			shirt = Color(0.95, 0.95, 0.92)
			lower = Color(0.9, 0.9, 0.88)
		"aunty":
			outfit = "saree" if rng.randf() < 0.55 else "kameez"
			cloth = KAMEEZ[rng.randi_range(0, 1)]
			shirt = SHIRTS[rng.randi_range(4, SHIRTS.size() - 1)]
			lower = shirt.darkened(0.3)
		"police":
			outfit = "uniform"
			shirt = Color(0.18, 0.24, 0.38)
			lower = Color(0.14, 0.18, 0.28)
			cap = true
			cap_color = Color(0.12, 0.16, 0.26)
		"guard":
			outfit = "guard"
			shirt = Color(0.42, 0.5, 0.62)
			lower = Color(0.16, 0.18, 0.24)
			cap = true
			cap_color = Color(0.2, 0.24, 0.32)
		"goon":
			outfit = "shirt_trousers"
			shirt = [Color(0.1, 0.1, 0.12), Color(0.6, 0.1, 0.12), Color(0.85, 0.85, 0.2), Color(0.2, 0.2, 0.25)][rng.randi_range(0, 3)]
			lower = Color(0.12, 0.14, 0.2)
		_:
			if female:
				outfit = "kameez"
				cloth = KAMEEZ[rng.randi_range(0, 1)]
				lower = Color(0.9, 0.88, 0.85)
	var builds := ["thin", "average", "average", "heavy"]
	var personality := {"kind": rng.randf(), "temper": rng.randf() * (1.4 if prof == "goon" else 0.8),
		"brains": rng.randf(), "curiosity": rng.randf() * (1.3 if prof in ["student", "teacher", "elder", "journalist"] else 0.7)}
	var family := String(FAMILY_FOR.get(prof, ""))
	if family == "":
		family = ["bcs", "job", "bar"][rng.randi_range(0, 2)]
	return {
		"id": "p%d" % seed_value, "seed": seed_value, "role": role, "profession": prof,
		"profession_name": PROF_NAMES.get(prof, PROF_NAMES["shop"]),
		"name": {"bn": "%s %s" % [first[0], last[0]], "en": "%s %s" % [first[1], last[1]]},
		"gender": "f" if female else "m", "age": age, "face": face, "district": district,
		"look": {"gender": "f" if female else "m", "height": rng.randf_range(1.5, 1.62) if female else rng.randf_range(1.6, 1.78),
			"build": builds[rng.randi_range(0, 3)], "skin": skin, "face": face, "hair": hair, "hair_style": hair_style,
			"outfit": outfit, "shirt": shirt, "lower": lower, "cloth": cloth, "lower_cloth": lower_cloth, "cap": cap, "cap_color": cap_color},
		"personality": personality,
		"voice": {"pitch": rng.randf_range(1.12, 1.35) if female else rng.randf_range(0.82, 1.05) - (0.08 if elder else 0.0),
			"rate": rng.randf_range(0.92, 1.1) - (0.08 if elder else 0.0), "index": rng.randi_range(0, 7)},
		"family": family, "armed": prof in ["police", "goon"] and rng.randf() < 0.6,
		"hp": 140.0 if prof == "police" else (120.0 if prof == "goon" else 100.0),
	}
