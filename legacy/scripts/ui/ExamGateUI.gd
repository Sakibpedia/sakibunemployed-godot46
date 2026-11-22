extends Control
## The gate card (design doc Section 6): question, four options, taunt, reveal and result.
## Slides in, shakes on a wrong answer, pulses green on a right one, shows a timer bar for timed
## gates and bleeding-out last wishes, and offers a bribe where the gate allows one.
## Built in code so it needs no scene file. Usage: add_child(ui); ui.open(session)

signal closed

var session: ExamSession
var bribe_cost := 0               # 0 hides the bribe button
var _dim: ColorRect
var _center: CenterContainer
var _card: PanelContainer
var _who: Label
var _question: Label
var _gloss: Label
var _buttons: Array[Button] = []
var _line: Label
var _status: Label
var _timer: ProgressBar
var _continue: Button
var _token: Button
var _bribe: Button
var _leave: Button
var _close: Button
var _show_gloss := true
var _mode := "wait"
var _chosen := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.0)
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center = CenterContainer.new()
	add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(1000, 0)
	_center.add_child(_card)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	margin.add_child(box)
	_who = _label(box, 22)
	_who.modulate = Color(1.0, 0.85, 0.45)
	_timer = ProgressBar.new()
	_timer.show_percentage = false
	_timer.custom_minimum_size = Vector2(0, 8)
	_timer.visible = false
	box.add_child(_timer)
	_question = _label(box, 30)
	_gloss = _label(box, 18)
	_gloss.modulate = Color(1, 1, 1, 0.6)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 50)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override(&"font_size", 24)
		b.pressed.connect(_on_option.bind(i))
		box.add_child(b)
		_buttons.append(b)
	_line = _label(box, 23)
	_status = _label(box, 17)
	_status.modulate = Color(1, 1, 1, 0.7)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	box.add_child(row)
	_token = _button(row, "Study token: strike two")
	_token.pressed.connect(_on_token)
	_bribe = _button(row, "Bribe")
	_bribe.pressed.connect(_on_bribe)
	_continue = _button(row, "Continue (Space)")
	_continue.pressed.connect(_on_continue)
	_leave = _button(row, "Walk away")
	_leave.pressed.connect(func() -> void: session.abandon())
	_close = _button(row, "Close (Space)")
	_close.pressed.connect(_on_close)


func open(s: ExamSession) -> void:
	session = s
	_who.text = "%s asks  ·  %s" % [s.gatekeeper.capitalize(), s.gate_id]
	s.question_ready.connect(_on_question)
	s.answered.connect(_on_answered)
	s.taunt_ready.connect(_on_taunt)
	s.revealed.connect(_on_revealed)
	s.resolved.connect(_on_resolved)
	_bribe.text = "Bribe (৳%d, honesty −10)" % bribe_cost
	_set_mode("wait")
	_card.modulate.a = 0.0
	_center.position.y = 90.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_dim, "color:a", 0.45, 0.25)
	tw.tween_property(_card, "modulate:a", 1.0, 0.25)
	tw.tween_property(_center, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioEventBus.play_ui("page")


func _process(_delta: float) -> void:
	if session == null or not session.is_open():
		return
	_status.text = "Points %.1f / %.1f   ·   follow-up depth %d of %d   ·   study tokens %d   ·   1-4 to answer" % [
		session.points(), session.pass_points, session.depth(), session.max_depth,
		int(WorldState.resources.get("study_tokens", 0))]
	if session.total_time_s > 0.0:
		_timer.visible = true
		_timer.max_value = session.total_time_s
		_timer.value = session.total_left()
		_timer.modulate = Color(1.0, 0.35, 0.3)
	elif session.question_time_s > 0.0:
		_timer.visible = _mode == "ask"
		_timer.max_value = session.question_time_s
		_timer.value = session.time_left()
		_timer.modulate = Color(1.0, 0.8, 0.3) if session.time_left() > 5.0 else Color(1.0, 0.35, 0.3)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if _mode == "ask" and k >= KEY_1 and k <= KEY_4:
		var i := k - KEY_1
		if not _buttons[i].disabled:
			_on_option(i)
		get_viewport().set_input_as_handled()
	elif _mode == "line" and k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
		_on_continue()
		get_viewport().set_input_as_handled()
	elif _mode == "done" and k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_ESCAPE]:
		_on_close()
		get_viewport().set_input_as_handled()


func _on_question(item: Dictionary, depth: int) -> void:
	var prefix := "Follow-up %d: " % depth if depth > 0 else ""
	_question.text = prefix + String(item.get("question_text", ""))
	_gloss.text = String(item.get("question_text_en", "")) if _show_gloss else ""
	for i in 4:
		_buttons[i].text = "%d.  %s" % [i + 1, String(item.get("option_%d" % (i + 1), ""))]
		_buttons[i].disabled = false
		_buttons[i].modulate = Color.WHITE
	_line.text = "Source: %s, %s" % [item.get("source_exam", ""), item.get("source_paper", "")]
	_line.modulate = Color(1, 1, 1, 0.6)
	_set_mode("ask")
	_question.modulate.a = 0.0
	create_tween().tween_property(_question, "modulate:a", 1.0, 0.2)


func _on_option(i: int) -> void:
	if _mode != "ask":
		return
	_chosen = i
	for b in _buttons:
		b.disabled = true
	session.answer(i)


func _on_answered(_item_id: String, _depth: int, correct: bool, _ms: int) -> void:
	if correct:
		AudioEventBus.play_ui("right")
		if _chosen >= 0:
			_pulse(_buttons[_chosen], Color(0.55, 1.0, 0.55))
		_pulse(_card, Color(0.8, 1.0, 0.8))
	else:
		AudioEventBus.play_ui("wrong")
		if _chosen >= 0:
			_buttons[_chosen].modulate = Color(1.0, 0.5, 0.45)
		_shake()
	_chosen = -1


func _on_taunt(text: String) -> void:
	_line.text = text
	_line.modulate = Color(1.0, 0.55, 0.5)
	_set_mode("line")


func _on_revealed(item: Dictionary, line: String) -> void:
	var right := int(item.get("correct_index", -1))
	if right >= 0 and right < 4:
		_buttons[right].modulate = Color(0.55, 1.0, 0.55)
		for b in _buttons:
			b.visible = true
			b.disabled = true
	_line.text = line
	_line.modulate = Color(0.6, 1.0, 0.65)
	_set_mode("line")
	for b in _buttons:
		b.visible = true


func _on_continue() -> void:
	_line.modulate = Color.WHITE
	if session.state == ExamSession.State.WRONG_TAUNTED:
		session.continue_after_taunt()
	elif session.state == ExamSession.State.CORRECT_REVEALED:
		session.continue_after_reveal()


func _on_token() -> void:
	if session.depth() > 0 or not WorldState.spend("study_tokens", 1):
		return
	var item := session.current_item()
	var struck := 0
	for i in 4:
		if i != int(item.correct_index) and struck < 2:
			_buttons[i].disabled = true
			_buttons[i].modulate = Color(1, 1, 1, 0.35)
			struck += 1
	_token.disabled = true


func _on_bribe() -> void:
	if bribe_cost <= 0 or not session.is_open():
		return
	if not WorldState.spend("taka", bribe_cost):
		_line.text = "You don't have ৳%d." % bribe_cost
		_line.modulate = Color(1.0, 0.6, 0.5)
		_shake()
		return
	WorldState.change_rep("exam_honesty", -10)
	Game.stats["bribes"] += 1
	AudioEventBus.play_ui("coins")
	session.force_pass()


func _on_resolved(result: Dictionary) -> void:
	var verdict := "Gate passed" if result.passed else "Gate failed"
	var why := ""
	if result.get("bribed", false):
		why = " (bought)"
	elif result.locked:
		why = " (locked for this level)"
	elif result.chain_exhausted:
		why = " (chain exhausted)"
	elif result.timed_out:
		why = " (out of time)"
	elif result.abandoned:
		why = " (walked away)"
	_question.text = verdict + why
	_question.modulate = Color(0.6, 1.0, 0.6) if result.passed else Color(1.0, 0.55, 0.5)
	_gloss.text = "Points %.1f · right first time %d of %d" % [result.points, result.first_try_correct, result.main_count]
	_line.text = ""
	_timer.visible = false
	_set_mode("done")
	AudioEventBus.play_ui("objective" if result.passed else "fail")
	if result.passed:
		_pulse(_card, Color(0.8, 1.0, 0.8))
	else:
		_shake()


func _on_close() -> void:
	if _mode != "done":
		return
	_mode = "closing"
	var tw := create_tween().set_parallel()
	tw.tween_property(_card, "modulate:a", 0.0, 0.2)
	tw.tween_property(_dim, "color:a", 0.0, 0.2)
	tw.tween_property(_center, "position:y", 60.0, 0.2)
	await tw.finished
	closed.emit()
	queue_free()


func _set_mode(mode: String) -> void:
	_mode = mode
	for b in _buttons:
		b.visible = mode == "ask" or mode == "line"
	_token.visible = mode == "ask"
	_token.disabled = false
	_bribe.visible = mode == "ask" and bribe_cost > 0
	_continue.visible = mode == "line"
	_leave.visible = mode == "ask" or mode == "line"
	_close.visible = mode == "done"
	if mode == "done":
		_close.grab_focus.call_deferred()


func _shake() -> void:
	var tw := create_tween()
	for x in [14.0, -11.0, 8.0, -5.0, 2.0, 0.0]:
		tw.tween_property(_center, "position:x", x, 0.045)


func _pulse(c: Control, col: Color) -> void:
	var tw := create_tween()
	tw.tween_property(c, "modulate", col, 0.12)
	tw.tween_property(c, "modulate", Color.WHITE, 0.35)


func _label(parent: Node, size: int) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(950, 0)
	l.add_theme_font_size_override(&"font_size", size)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 44)
	parent.add_child(b)
	return b
