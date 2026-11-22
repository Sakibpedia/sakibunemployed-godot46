class_name ExamSession
extends RefCounted
## Draws questions with no repeats: every pool (one per filter) is a shuffled bag kept in
## GameState.exam_bags, so it survives saving. A question comes back only after every other
## question in that pool has been asked. If a filter matches nothing, the filter relaxes step by
## step (category, then subject, then family) so an exam never comes up empty.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

var bank: QuestionBank
var _rng := RandomNumberGenerator.new()


func _init(question_bank: QuestionBank) -> void:
	bank = question_bank
	_rng.randomize()


func pool_key(filter: Dictionary) -> String:
	return "%s|%s|%s|%s|%d" % [String(filter.get("family", "")), String(filter.get("subject", "")),
		String(filter.get("category", "")), "c" if bool(filter.get("cited_only", false)) else "",
		int(filter.get("max_difficulty", 3))]


func _relaxed(filter: Dictionary) -> Dictionary:
	var f := filter.duplicate()
	if String(f.get("category", "")) != "":
		f["category"] = ""
	elif String(f.get("subject", "")) != "":
		f["subject"] = ""
	elif bool(f.get("cited_only", false)):
		f["cited_only"] = false
	elif int(f.get("max_difficulty", 3)) < 3:
		f["max_difficulty"] = 3
	elif String(f.get("family", "")) != "":
		f["family"] = ""
	return f


func draw(filter: Dictionary, n: int) -> Array:
	var f := filter
	var tries := 0
	while bank.count(f) == 0 and tries < 6:
		f = _relaxed(f)
		tries += 1
	var key := pool_key(f)
	var out: Array = []
	var guard := 0
	while out.size() < n and guard < n * 3 + 4:
		guard += 1
		var bag: Array = GameState.exam_bags.get(key, [])
		if bag.is_empty():
			var all := bank.ids(f)
			if all.is_empty():
				break
			bag = Array(all)
			_shuffle(bag)
			# never start a fresh bag with something we just asked
			for it in out:
				bag.erase(String(it["id"]))
				bag.append(String(it["id"]))
		var id := String(bag.pop_front())
		GameState.exam_bags[key] = bag
		var it := bank.item(id)
		if it.is_empty():
			continue
		var dup := false
		for o in out:
			if String(o["id"]) == id:
				dup = true
		if not dup:
			out.append(it)
	return out


func record(it: Dictionary, correct: bool) -> void:
	GameState.record_answer(String(it.get("id", "")), String(it.get("category", "")), correct)


## How many questions remain before a pool starts repeating.
func remaining(filter: Dictionary) -> int:
	var bag: Array = GameState.exam_bags.get(pool_key(filter), [])
	return bag.size() if not bag.is_empty() else bank.count(filter)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
