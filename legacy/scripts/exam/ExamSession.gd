class_name ExamSession
extends RefCounted
## One run of a gate: the wrong-answer chain state machine (design doc Section 6.4).
## The UI drives it: answer(), then continue_after_taunt() and continue_after_reveal()
## once each line has been shown. tick() runs the timers.

enum State { ASKING, WRONG_TAUNTED, CORRECT_REVEALED, CHAINED_QUESTION, CHAIN_CLEARED, CHAIN_EXHAUSTED, GATE_FAILED, GATE_PASSED }
const STATE_NAMES := ["asking", "wrong_taunted", "correct_revealed", "chained_question",
	"chain_cleared", "chain_exhausted", "gate_failed", "gate_passed"]

signal state_changed(state: int, depth: int)
signal question_ready(item: Dictionary, depth: int)
signal answered(item_id: String, depth: int, correct: bool, ms: int)
signal taunt_ready(text: String)
signal revealed(item: Dictionary, line: String)
signal resolved(result: Dictionary)

var gate_id: String
var gatekeeper: String
var category: String
var pass_points: float
var max_depth: int
var recovered_points: float
var lock_after: int
var question_time_s: float
var total_time_s: float
var state: int = State.ASKING
var answers: Array[Dictionary] = []

var _gate                          # the ExamGate autoload (untyped to avoid a cyclic reference)
var _main: Array[String] = []
var _scripted: Dictionary = {}     # main index (0-based) -> scripted entry
var _scripted_chain: Array = []
var _asked: Dictionary = {}
var _n := 0
var _depth := 0
var _item: Dictionary = {}
var _main_item: Dictionary = {}
var _points := 0.0
var _first_try := 0
var _wrong_in_row := 0
var _q_left := 0.0
var _total_left := 0.0
var _asked_ms := 0
var _flags := {"chain_exhausted": false, "timed_out": false, "abandoned": false, "locked": false, "bribed": false}


func _init(gate, def: Dictionary, main_items: Array[String]) -> void:
	_gate = gate
	_main = main_items
	gate_id = def.get("gate_id", "gate")
	gatekeeper = def.get("gatekeeper", "")
	category = def.get("category", "door")
	pass_points = float(def.get("pass_points", 3.0 if _main.size() <= 5 else 7.0))
	var chain: Dictionary = def.get("chain", {})
	max_depth = int(chain.get("max_depth", 3))
	recovered_points = float(chain.get("recovered_points", 0.5))
	lock_after = int(chain.get("lock_after_wrong_in_row", 3 if _main.size() >= 10 else 0))
	question_time_s = float(def.get("timer_s", 0.0))
	total_time_s = float(def.get("total_time_s", 0.0))
	_total_left = total_time_s
	for sc in def.get("scripted", []):
		_scripted[int(sc.get("at", 0)) - 1] = sc


func start() -> void:
	_ask_main()


func is_open() -> bool:
	return state != State.GATE_FAILED and state != State.GATE_PASSED


func current_item() -> Dictionary:
	return _item


func depth() -> int:
	return _depth


func points() -> float:
	return _points


## Seconds left on the current question (timed gates only).
func time_left() -> float:
	return maxf(0.0, _q_left)


## Seconds left for the whole gate (last wishes bleed out on this clock).
func total_left() -> float:
	return maxf(0.0, _total_left)


## A bribe: the gate opens without the questions. The level script charges the money and honesty.
func force_pass() -> void:
	if not is_open():
		return
	_flags["bribed"] = true
	_set_state(State.GATE_PASSED)
	_emit_result(true)


func tick(delta: float) -> void:
	if not is_open():
		return
	if total_time_s > 0.0:
		_total_left -= delta
		if _total_left <= 0.0:
			_flags.timed_out = true
			_fail()
			return
	if question_time_s > 0.0 and (state == State.ASKING or state == State.CHAINED_QUESTION):
		_q_left -= delta
		if _q_left <= 0.0:
			answer(-1)   # out of time counts as a wrong answer


func answer(option_index: int) -> void:
	if state != State.ASKING and state != State.CHAINED_QUESTION:
		return
	var ms := Time.get_ticks_msec() - _asked_ms
	var correct := option_index == int(_item.correct_index)
	answers.append({"item": _item.id, "depth": _depth, "correct": correct, "ms": ms})
	answered.emit(_item.id, _depth, correct, ms)
	if correct:
		if _depth == 0:
			_points += 1.0
			_first_try += 1
			_wrong_in_row = 0
		else:
			_points += recovered_points
			_set_state(State.CHAIN_CLEARED)
			var sc: Dictionary = _scripted.get(_n, {})
			if sc.has("on_chain_cleared"):
				_gate.apply_effect(sc.on_chain_cleared)
		_after_main_resolved()
		return
	if _depth == 0:
		_wrong_in_row += 1
	_set_state(State.WRONG_TAUNTED)
	taunt_ready.emit(_gate.taunt_for(self))


func continue_after_taunt() -> void:
	if state != State.WRONG_TAUNTED:
		return
	_set_state(State.CORRECT_REVEALED)
	revealed.emit(_item, _gate.reveal_line(_item))


func continue_after_reveal() -> void:
	if state != State.CORRECT_REVEALED:
		return
	if _depth >= max_depth:
		_flags.chain_exhausted = true
		_set_state(State.CHAIN_EXHAUSTED)
		_fail()
		return
	var next := _next_followup()
	if next.is_empty():
		# No follow-up left in the bank: the main question scores 0 and the gate moves on.
		_after_main_resolved()
		return
	_depth += 1
	_show(next)


func abandon() -> void:
	if not is_open():
		return
	_flags.abandoned = true   # walking away counts as a wrong answer (Section 2.3)
	_fail()


func _ask_main() -> void:
	_depth = 0
	if _n >= _main.size():
		_finish()
		return
	_main_item = _gate.item(_main[_n])
	var sc: Dictionary = _scripted.get(_n, {})
	_scripted_chain = sc.get("chain", []).duplicate()
	_show(_main_item)


func _after_main_resolved() -> void:
	if lock_after > 0 and _wrong_in_row >= lock_after:
		_flags.locked = true
		_fail()
		return
	_n += 1
	var remaining := _main.size() - _n
	if _points + remaining < pass_points:
		_fail()   # the pass mark is out of reach
	else:
		_ask_main()


func _next_followup() -> Dictionary:
	while not _scripted_chain.is_empty():
		var id: String = _scripted_chain.pop_front()
		if not _asked.has(id) and _gate.has_item(id):
			return _gate.item(id)
	return _gate.pick_followup(_main_item, _asked)


func _show(item: Dictionary) -> void:
	_item = item
	_asked[item.id] = true
	_asked_ms = Time.get_ticks_msec()
	_q_left = question_time_s
	_set_state(State.ASKING if _depth == 0 else State.CHAINED_QUESTION)
	question_ready.emit(item, _depth)


func _finish() -> void:
	if _points >= pass_points:
		_set_state(State.GATE_PASSED)
		_emit_result(true)
	else:
		_fail()


func _fail() -> void:
	_set_state(State.GATE_FAILED)
	_emit_result(false)


func _emit_result(passed: bool) -> void:
	resolved.emit({
		"gate_id": gate_id, "category": category, "passed": passed, "points": _points,
		"first_try_correct": _first_try, "main_count": _main.size(),
		"perfect": passed and _first_try == _main.size(),
		"chain_exhausted": _flags.chain_exhausted, "timed_out": _flags.timed_out,
		"abandoned": _flags.abandoned, "locked": _flags.locked, "bribed": _flags.bribed, "answers": answers,
	})


func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s, _depth)
