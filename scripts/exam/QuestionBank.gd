class_name QuestionBank
extends RefCounted
## Both question banks in one normalised list:
##   Data/Questions/question_bank.json   173 cited past-paper items (BCS, government job, Bar Council)
##   Data/Questions/practice_bank.json   2,500+ generated practice items (tools/generate_questions.py)
## A normalised item: {id, family, families, category, subject, difficulty, q{bn,en}, options_bn[], options_en[],
## answer, source, basis, cited}. Filters: {family, subject, category, cited_only, max_difficulty}.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const CITED := "res://Data/Questions/question_bank.json"
const PRACTICE := "res://Data/Questions/practice_bank.json"
const BUCKET_FAMILY := {"bcs": "bcs", "gov_job": "job", "bar_council": "bar"}
const PARENT_CATEGORY := {"chemistry": "science_chem", "biology": "science", "physics": "science",
	"general_science": "science", "mathematics": "math", "bangladesh_history": "bangladesh", "law": "law",
	"english": "english", "international": "international", "bangla_literature": "bangla_literature",
	"bangla_grammar": "bangla_grammar", "road_safety": "road_safety"}

var items: Array = []
var by_id: Dictionary = {}


func load_all() -> void:
	items.clear()
	by_id.clear()
	_load_cited()
	_load_practice()


func _read(path: String) -> Array:
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var d: Dictionary = parsed
	var qs: Variant = d.get("questions", [])
	return qs if typeof(qs) == TYPE_ARRAY else []


func _load_cited() -> void:
	for raw in _read(CITED):
		var r: Dictionary = raw
		if not bool(r.get("verified", false)) or bool(r.get("requires_replacement", false)):
			continue
		var fam := String(BUCKET_FAMILY.get(String(r.get("source_bucket", "bcs")), "bcs"))
		var parent := String(r.get("chain_parent", "general"))
		var cat := String(PARENT_CATEGORY.get(parent, parent))
		var opts := [String(r.get("option_1", "")), String(r.get("option_2", "")), String(r.get("option_3", "")), String(r.get("option_4", ""))]
		var lang := String(r.get("language", "bn"))
		var item := {
			"id": String(r.get("id", "")), "family": fam, "families": [fam] if fam != "job" else ["job", "bcs"],
			"category": cat, "subject": cat.get_slice("_", 0), "difficulty": 2,
			"q": {"bn": String(r.get("question_text_bn", r.get("question_text", ""))), "en": String(r.get("question_text_en", ""))},
			"options_bn": opts if lang == "bn" else [], "options_en": opts if lang == "en" else [],
			"answer": int(r.get("correct_index", 0)),
			"source": "%s %s" % [String(r.get("source_exam", "")), String(r.get("source_paper", ""))],
			"basis": String(r.get("verification_evidence", "")), "cited": true,
		}
		_add(item)


func _load_practice() -> void:
	for raw in _read(PRACTICE):
		var r: Dictionary = raw
		var cat := String(r.get("category", "general"))
		var item := {
			"id": String(r.get("id", "")), "family": String(r.get("family", "bcs")), "families": r.get("families", ["bcs"]),
			"category": cat, "subject": cat.get_slice("_", 0), "difficulty": int(r.get("difficulty", 2)),
			"q": {"bn": String(r.get("q_bn", "")), "en": String(r.get("q_en", ""))},
			"options_bn": r.get("options_bn", []), "options_en": r.get("options_en", []),
			"answer": int(r.get("answer", 0)), "source": String(r.get("source", "")), "basis": String(r.get("basis", "")),
			"cited": false,
		}
		_add(item)


func _add(item: Dictionary) -> void:
	var id := String(item["id"])
	if id == "" or by_id.has(id):
		return
	items.append(item)
	by_id[id] = item


func item(id: String) -> Dictionary:
	return by_id.get(id, {})


func matches(it: Dictionary, filter: Dictionary) -> bool:
	var fam := String(filter.get("family", ""))
	if fam != "":
		var fams: Array = it.get("families", [])
		if not fams.has(fam):
			return false
	var subject := String(filter.get("subject", ""))
	if subject != "" and String(it.get("subject", "")) != subject and not String(it.get("category", "")).begins_with(subject):
		return false
	var cat := String(filter.get("category", ""))
	if cat != "" and String(it.get("category", "")) != cat:
		return false
	if bool(filter.get("cited_only", false)) and not bool(it.get("cited", false)):
		return false
	var maxd := int(filter.get("max_difficulty", 3))
	if int(it.get("difficulty", 2)) > maxd:
		return false
	return true


func ids(filter: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for it in items:
		if matches(it, filter):
			out.append(String(it["id"]))
	return out


func count(filter: Dictionary) -> int:
	return ids(filter).size()


func cited_count() -> int:
	var n := 0
	for it in items:
		if bool(it.get("cited", false)):
			n += 1
	return n


func subjects(family: String) -> PackedStringArray:
	var seen := {}
	for it in items:
		var fams: Array = it.get("families", [])
		if family == "" or fams.has(family):
			seen[String(it.get("subject", ""))] = true
	return PackedStringArray(seen.keys())


## Question text and options in the player's language (falls back to the other language).
static func display(it: Dictionary, lang: String) -> Dictionary:
	var q: Dictionary = it.get("q", {})
	var text := String(q.get(lang, ""))
	if text == "":
		text = String(q.get("en" if lang == "bn" else "bn", ""))
	var opts: Array = it.get("options_" + lang, [])
	if opts.is_empty():
		opts = it.get("options_" + ("en" if lang == "bn" else "bn"), [])
	return {"text": text, "options": opts, "answer": int(it.get("answer", 0))}
