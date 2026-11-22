extends Node
## On-device language model bridge (design doc Sections 8.5 and 14).
## The model writes flavour lines only: taunts, praise and career callbacks. It never sees
## or writes questions, options or answers. Lines are generated ahead of time and cached,
## so a gate never waits; an empty cache falls back to authored lines at once.
##
## Backend contract (an adapter node for NobodyWho or Godot Llama, see README):
##   func generate(prompt: String) -> void
##   signal first_token
##   signal finished(text: String)

signal line_cached(key: String, text: String)

const FIRST_TOKEN_BUDGET_MS := 300
const MAX_CHARS := 220
const FALLBACK_PATH := "res://Data/Text/fallback_lines.json"
const BANNED_PATH := "res://Data/Text/banned_words.json"

var backend: Object = null
var stats := {"requests": 0, "late_first_token": 0, "rejected": 0}

var _cache: Dictionary = {}        # "kind/speaker" -> Array of lines
var _fallback: Dictionary = {}     # kind -> Array of authored lines
var _banned: PackedStringArray = []
var _queue: Array[Dictionary] = []
var _busy := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(FALLBACK_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		_fallback = data
	var banned = JSON.parse_string(FileAccess.get_file_as_string(BANNED_PATH))
	if typeof(banned) == TYPE_DICTIONARY:
		for w in banned.get("words", []):
			_banned.append(String(w).to_lower())


func set_backend(b: Object) -> void:
	backend = b
	if not _queue.is_empty() and not _busy:
		_pump()


## Returns a line immediately: cached model output if there is one, else an authored line.
func take_line(kind: String, speaker: String) -> String:
	var key := "%s/%s" % [kind, speaker]
	var pool: Array = _cache.get(key, [])
	if pool.size() < 2:
		prefetch(kind, speaker, {})
	if not pool.is_empty():
		return pool.pop_front()
	return fallback_line(kind)


func fallback_line(kind: String) -> String:
	var lines: Array = _fallback.get(kind, [])
	if lines.is_empty():
		return "..."
	return lines[_rng.randi_range(0, lines.size() - 1)]


## Queue a line for later. Call on level load for every gatekeeper and callback person.
func prefetch(kind: String, speaker: String, slots: Dictionary) -> void:
	_queue.append({"kind": kind, "speaker": speaker, "slots": slots})
	if backend != null and not _busy:
		_pump()


func _pump() -> void:
	_busy = true
	while not _queue.is_empty() and backend != null:
		var req: Dictionary = _queue.pop_front()
		stats.requests += 1
		var t0 := Time.get_ticks_msec()
		var first := [-1]
		var on_first := func() -> void:
			if first[0] < 0:
				first[0] = Time.get_ticks_msec() - t0
		backend.first_token.connect(on_first, CONNECT_ONE_SHOT)
		backend.generate(_build_prompt(req))
		var text: String = await backend.finished
		if backend.first_token.is_connected(on_first):
			backend.first_token.disconnect(on_first)
		if first[0] > FIRST_TOKEN_BUDGET_MS:
			stats.late_first_token += 1   # still cached; it was never on the critical path
		var line := _validate(text)
		if line == "":
			stats.rejected += 1
			continue
		var key := "%s/%s" % [req.kind, req.speaker]
		_cache.get_or_add(key, []).append(line)
		line_cached.emit(key, line)
	_busy = false


func _build_prompt(req: Dictionary) -> String:
	var s: Dictionary = req.slots
	match String(req.kind):
		"callback":
			return ("You are %s, %s, %s in %s, Dhaka. Speak colloquial Dhaka Bangla. At most two sentences. "
				+ "Use only the facts below; add no names, places, numbers or exam answers.\n"
				+ "Facts: In level %s, Sakib advised you to \"%s\". Since then: %s.\n"
				+ "Your feeling towards Sakib: %s. What you will do now: %s.\n"
				+ "Reply as JSON: {\"line_bn\": \"...\", \"line_en\": \"...\", \"emotion\": \"...\"}\n"
				+ "Sakib walks up to you.") % [
					s.get("name", req.speaker), s.get("age", ""), s.get("role", ""), s.get("area", "Jatrabari"),
					s.get("level_then", ""), s.get("advice_label", ""), s.get("outcome_summary", ""),
					s.get("tone", "mixed"), s.get("callback_action", "")]
		_:
			return ("You are a %s guarding a door in Jatrabari, Dhaka. Sakib just answered your exam question wrong. "
				+ "Mock him in one short sentence of colloquial Bangla. No names, no numbers, no facts, no slurs.\n"
				+ "Reply as JSON: {\"line_bn\": \"...\", \"line_en\": \"...\", \"emotion\": \"mocking\"}") % req.speaker


func _validate(text: String) -> String:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var line: String = String(data.get("line_bn", "")).strip_edges()
	if line == "" or line.length() > MAX_CHARS:
		return ""
	var lower := line.to_lower()
	for w in _banned:
		if lower.contains(w):
			return ""
	for digit in "0123456789০১২৩৪৫৬৭৮৯":
		if line.contains(digit):
			return ""   # numbers could look like answers
	return line
