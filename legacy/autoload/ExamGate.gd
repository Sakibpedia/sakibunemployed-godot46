extends Node
## Exam gates (design doc Section 6): loads the cited bank, draws items, runs sessions,
## applies outcomes. The language model never touches questions, options or answers.

signal gate_opened(gate_id: String)
signal question_shown(gate_id: String, item: Dictionary, depth: int)
signal answer_given(gate_id: String, item_id: String, depth: int, correct: bool, ms: int)
signal chain_state_changed(gate_id: String, state: String, depth: int)
signal gate_resolved(gate_id: String, passed: bool, points: float)
signal effect_requested(effect: String)   # doors, unlocks and rewards handled by level scripts

const BANK_PATH := "res://Data/Questions/question_bank.json"
const GATES_DIR := "res://Data/Gates/"
const RETRY_GAME_SECONDS := 3600.0          # one game hour (Section 6.3)

var _items: Dictionary = {}       # id -> item
var _by_set: Dictionary = {}      # set code -> Array of ids
var _by_topic: Dictionary = {}    # chain_topic -> Array of ids
var _by_parent: Dictionary = {}   # chain_parent -> Array of ids
var _rng := RandomNumberGenerator.new()
var _active: Dictionary = {}      # gate id -> ExamSession
var _locked: Dictionary = {}      # gate id -> level it is locked for
var _retry_at: Dictionary = {}    # gate id -> game seconds
var _timed_failures: Dictionary = {}
var _level_gates: Dictionary = {}  # gate id -> def embedded in the current level's JSON


func _ready() -> void:
	_rng.seed = WorldState.save_seed
	_load_bank()


func _process(delta: float) -> void:
	for id in _active.keys():
		var s: ExamSession = _active[id]
		s.tick(delta)


# --- Bank -----------------------------------------------------------------------

func _load_bank() -> void:
	var text := FileAccess.get_file_as_string(BANK_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Question bank missing or invalid: %s" % BANK_PATH)
		return
	var release := not OS.is_debug_build()
	for item in data.get("questions", []):
		# Release builds ship only verified items (Section 7.1, step 6).
		if release and (not item.get("verified", false) or item.get("requires_replacement", false)):
			continue
		_items[item.id] = item
		for s in item.sets:
			_by_set.get_or_add(s, []).append(item.id)
		_by_topic.get_or_add(item.chain_topic, []).append(item.id)
		_by_parent.get_or_add(item.chain_parent, []).append(item.id)


func has_item(id: String) -> bool:
	return _items.has(id)


func item(id: String) -> Dictionary:
	return _items.get(id, {})


func item_count() -> int:
	return _items.size()


# --- Opening gates --------------------------------------------------------------

func load_gate(gate_id: String) -> Dictionary:
	if _level_gates.has(gate_id):
		return _level_gates[gate_id]
	var path := GATES_DIR + gate_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


## Level JSON files carry their own gate definitions; they win over Data/Gates files.
func register_gates(defs: Dictionary) -> void:
	_level_gates = {}
	for id in defs:
		var d: Dictionary = defs[id].duplicate(true)
		d["gate_id"] = String(id)
		_level_gates[String(id)] = d


func is_locked(gate_id: String) -> bool:
	return int(_locked.get(gate_id, -1)) == WorldState.level


func retry_at(gate_id: String) -> float:
	return float(_retry_at.get(gate_id, 0.0))


## Drops every open session without resolving it (level restart, death, quitting to the menu).
func cancel_all() -> void:
	_active.clear()


## A fresh attempt at a level: cooldowns and locks from the last attempt no longer apply.
func reset_level_state() -> void:
	_active.clear()
	_retry_at.clear()
	_locked.clear()
	_timed_failures.clear()


func can_open(gate_id: String) -> bool:
	if int(_locked.get(gate_id, -1)) == WorldState.level:
		return false
	return WorldState.game_seconds >= float(_retry_at.get(gate_id, 0.0))


func open_gate(def: Dictionary) -> ExamSession:
	var gate_id: String = def.get("gate_id", "gate")
	if not can_open(gate_id) or _active.has(gate_id):
		return null
	var main := draw(def)
	if main.is_empty():
		push_warning("Gate %s drew no items" % gate_id)
		return null
	var size := int(def.get("size", 5))
	if main.size() < size and def.has("pass_points"):
		# Fewer questions left in the bank than the gate wants: keep the same pass ratio.
		def = def.duplicate(true)
		def["pass_points"] = ceilf(float(def.pass_points) * main.size() / size)
	var s := ExamSession.new(self, def, main)
	_active[gate_id] = s
	s.state_changed.connect(func(st: int, d: int) -> void:
		chain_state_changed.emit(gate_id, ExamSession.STATE_NAMES[st], d)
	)
	s.question_ready.connect(func(it: Dictionary, d: int) -> void:
		question_shown.emit(gate_id, it, d)
	)
	s.answered.connect(func(item_id: String, d: int, ok: bool, ms: int) -> void:
		WorldState.record_answer(item_id, ok, d)
		answer_given.emit(gate_id, item_id, d, ok, ms)
	)
	s.resolved.connect(_on_resolved.bind(def))
	WorldState.set_lens(WorldState.Lens.GROUND_GATE)   # the Sky lens locks during a gate
	gate_opened.emit(gate_id)
	s.start.call_deferred()   # lets the caller connect to the session first
	return s


func _on_resolved(result: Dictionary, def: Dictionary) -> void:
	var gate_id: String = result.gate_id
	_active.erase(gate_id)
	WorldState.record_gate(result)
	WorldState.set_lens(WorldState.Lens.GROUND_STEALTH)
	if result.passed:
		for e in def.get("on_pass", []):
			apply_effect(e)
	else:
		for e in def.get("on_fail", []):
			apply_effect(e)
		if result.locked:
			_locked[gate_id] = WorldState.level
		elif float(def.get("timer_s", 0.0)) > 0.0:
			_timed_failures[gate_id] = int(_timed_failures.get(gate_id, 0)) + 1
			if _timed_failures[gate_id] >= 2:
				_locked[gate_id] = WorldState.level   # second failure of a timed gate
		_retry_at[gate_id] = WorldState.game_seconds + RETRY_GAME_SECONDS
	gate_resolved.emit(gate_id, result.passed, result.points)


func apply_effect(effect: String) -> void:
	var parts := effect.split(":")
	match parts[0]:
		"alert":
			WorldState.add_alert(WorldState.current_sector, float(parts[1]))
		"honesty":
			WorldState.change_rep("exam_honesty", int(parts[1]))
		"resource":
			WorldState.add_resource(parts[1], int(parts[2]))
		"retry_after_game_min":
			pass   # handled by RETRY_GAME_SECONDS; kept in data for readability
		_:
			effect_requested.emit(effect)


# --- Drawing items --------------------------------------------------------------

func draw(def: Dictionary) -> Array[String]:
	var size := int(def.get("size", 5))
	var picked: Array[String] = []
	var compose: Array = def.get("compose", [])
	if compose.is_empty():
		compose = [{"sets": def.get("draw", {}).get("sets", ["G"]), "count": size}]
	var legal := String(def.get("category", "")) == "legal"
	var exclude_sets: Array = def.get("draw", {}).get("exclude_sets", [])
	for part in compose:
		var need := int(part.count)
		# Relax step by step when the pool runs dry: first allow items answered right in the last
		# two levels, then items already asked in this level. Never repeat inside one gate.
		for relax in 3:
			if need <= 0:
				break
			var ranked := _ranked(_pool(part.sets, picked, legal, exclude_sets, relax))
			var take := mini(need, ranked.size())
			for i in take:
				picked.append(ranked[i])
			need -= take
	for sc in def.get("scripted", []):
		var id: String = sc.get("item", "")
		if not _items.has(id):
			continue
		picked.erase(id)
		picked.insert(clampi(int(sc.get("at", 1)) - 1, 0, picked.size()), id)
	if picked.size() > size:
		picked.resize(size)
	return picked


func _pool(sets: Array, exclude: Array[String], legal: bool, exclude_sets: Array = [], relax: int = 0) -> Array[String]:
	var level := WorldState.level
	var rec: Dictionary = WorldState.exam_record
	var out: Array[String] = []
	for s in sets:
		for id in _by_set.get(s, []):
			if out.has(id) or exclude.has(id):
				continue
			if relax < 2 and int(rec.asked.get(id, -99)) == level:
				continue   # never twice in a level
			if relax < 1 and level - int(rec.right.get(id, -99)) <= 2:
				continue   # answered right in the last two levels
			if legal and _items[id].get("synthetic", false):
				continue   # no synthetic items in Bar Council gates
			var skip := false
			for es in exclude_sets:
				if _items[id].sets.has(es):
					skip = true   # e.g. the CHAIN reserve stays for follow-ups
			if skip:
				continue
			out.append(id)
	return out


func _ranked(pool: Array[String]) -> Array[String]:
	# Spaced repetition: items missed two to four levels ago come first.
	var level := WorldState.level
	var due: Array[String] = []
	var rest: Array[String] = []
	for id in pool:
		var missed := int(WorldState.exam_record.wrong.get(id, -99))
		if level - missed >= 2 and level - missed <= 4:
			due.append(id)
		else:
			rest.append(id)
	_shuffle(due)
	_shuffle(rest)
	due.append_array(rest)
	return due


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func pick_followup(main_item: Dictionary, asked: Dictionary) -> Dictionary:
	var bar_only: bool = main_item.get("source_bucket", "") == "bar_council"
	for pool in [_by_topic.get(main_item.chain_topic, []), _by_parent.get(main_item.chain_parent, [])]:
		var same_lang: Array[String] = []
		var other: Array[String] = []
		for id in pool:
			var it: Dictionary = _items[id]
			if asked.has(id) or it.get("synthetic", false):
				continue
			if bar_only and it.get("source_bucket", "") != "bar_council":
				continue
			if it.language == main_item.language:
				same_lang.append(id)
			else:
				other.append(id)
		for candidates in [same_lang, other]:
			if not candidates.is_empty():
				return _items[candidates[_rng.randi_range(0, candidates.size() - 1)]]
	return {}


# --- Lines ------------------------------------------------------------------------

func taunt_for(session: ExamSession) -> String:
	return LLMBridge.take_line("taunt", session.gatekeeper)


func reveal_line(it: Dictionary) -> String:
	var answer: String = it.get("option_%d" % (int(it.correct_index) + 1), "")
	var explanation = it.get("explanation_bn")
	if explanation == null:
		explanation = ""
	var source := "%s, %s" % [it.get("source_exam", ""), it.get("source_paper", "")]
	if explanation != "":
		return "ঠিক উত্তর: %s। %s (%s)" % [answer, explanation, source]
	return "ঠিক উত্তর: %s। (%s)" % [answer, source]
