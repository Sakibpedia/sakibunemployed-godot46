class_name ExamPanel
extends CanvasLayer
## The exam card used by every quiz in the game. Built from the SVG kit (exam_panel_bg, exam_option_*,
## exam_timer_*, bengali_text_backdrop, portrait_frame). Keys: 1-4 answer, B bribe, X flee,
## Enter continue. A study token strikes out one wrong option.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal finished(result: Dictionary)

const DEFAULT_SECONDS := {"duel": 20.0, "gate": 25.0, "dying": 16.0, "ghost": 11.0, "police": 15.0, "viva": 30.0,
	"interview": 25.0, "poster": 30.0, "tuition": 30.0, "bar": 30.0, "prelim": 24.0}
const LETTERS_BN := ["ক", "খ", "গ", "ঘ"]
const LETTERS_EN := ["A", "B", "C", "D"]

var ctx: Dictionary = {}
var items: Array = []
var session: ExamSession
var index := 0
var right := 0
var wrong := 0
var timed_out := 0
var pass_mark := 2
var _seconds := 20.0
var _time_left := 20.0
var _waiting := false
var _done := false
var _rng := RandomNumberGenerator.new()
var _current: Dictionary = {}
var _shown: Dictionary = {}

var _title: Label
var _speaker: Label
var _stakes: Label
var _progress: Label
var _question: RichTextLabel
var _taunt: Label
var _source: Label
var _ring: TextureProgressBar
var _ring_label: Label
var _buttons: Array[Button] = []
var _texts: Array[Label] = []
var _token_btn: Button
var _bribe_btn: Button
var _flee_btn: Button
var _banner: Label


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func open(context: Dictionary, chosen: Array, exam_session: ExamSession) -> void:
	ctx = context
	items = chosen
	session = exam_session
	pass_mark = clampi(int(ctx.get("pass", ceili(items.size() * 0.6))), 1, items.size())
	var mode := String(ctx.get("mode", "gate"))
	_seconds = float(ctx.get("seconds", DEFAULT_SECONDS.get(mode, 22.0)))
	_build()
	_title.text = Game.text(Exams.title_for(mode))
	_speaker.text = Game.text(ctx.get("speaker", {"bn": "পরীক্ষক", "en": "Examiner"}))
	_stakes.text = Game.text(ctx.get("stakes", {"bn": "", "en": ""}))
	_bribe_btn.visible = bool(ctx.get("allow_bribe", false))
	_bribe_btn.text = ("ঘুষ ৳%s (B)" if Game.language == "bn" else "Bribe Tk %s (B)") % UiKit.num(int(ctx.get("bribe_cost", 200)))
	_flee_btn.visible = bool(ctx.get("allow_flee", true))
	var open_line: Variant = ctx.get("open_line", null)
	if typeof(open_line) == TYPE_DICTIONARY:
		_taunt.text = Game.text2(open_line)
		Voice.speak(_speaker_profile(), open_line, 2)
	_show(0)


func _speaker_profile() -> Dictionary:
	return {"name": ctx.get("speaker", {}), "voice": ctx.get("voice", {"pitch": 1.0, "rate": 1.0})}


# --- Layout -------------------------------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.03, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.style("exam_panel_bg"))
	var vp := get_viewport().get_visible_rect().size
	var w := minf(1500.0, vp.x * 0.92)
	var h := minf(880.0, vp.y * 0.94)
	panel.custom_minimum_size = Vector2(w, h)
	panel.position = (vp - Vector2(w, h)) * 0.5
	root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	# header: portrait, title, speaker, stakes, progress, timer ring
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	var pf := Control.new()
	pf.custom_minimum_size = Vector2(118, 118)
	head.add_child(pf)
	var face := TextureRect.new()
	face.texture = UiKit.portrait(String(ctx.get("face", "")))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.position = Vector2(12, 12)
	face.size = Vector2(94, 94)
	pf.add_child(face)
	var frame := TextureRect.new()
	frame.texture = UiKit.tex("portrait_frame")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = Vector2(118, 118)
	pf.add_child(frame)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	_title = UiKit.label("", 30, UiKit.MARIGOLD, true)
	info.add_child(_title)
	_speaker = UiKit.label("", 22, UiKit.PAPER, true)
	info.add_child(_speaker)
	_stakes = UiKit.label("", 18, UiKit.DIM)
	info.add_child(_stakes)
	_progress = UiKit.label("", 20, UiKit.TEAL, true)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.custom_minimum_size = Vector2(260, 0)
	head.add_child(_progress)

	var ringbox := Control.new()
	ringbox.custom_minimum_size = Vector2(110, 110)
	head.add_child(ringbox)
	_ring = TextureProgressBar.new()
	_ring.texture_under = UiKit.tex("exam_timer_ring")
	_ring.texture_progress = UiKit.tex("exam_timer_fill")
	_ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	_ring.nine_patch_stretch = false
	_ring.max_value = 1000.0
	_ring.value = 1000.0
	_ring.size = Vector2(110, 110)
	_ring.scale = Vector2(110.0 / 160.0, 110.0 / 160.0)
	ringbox.add_child(_ring)
	_ring_label = UiKit.label("", 26, UiKit.PAPER, true)
	_ring_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ring_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ring_label.size = Vector2(110, 110)
	ringbox.add_child(_ring_label)

	# question on the Bengali typography backdrop
	var qp := PanelContainer.new()
	qp.add_theme_stylebox_override("panel", UiKit.style("bengali_text_backdrop"))
	qp.custom_minimum_size = Vector2(0, 150)
	col.add_child(qp)
	_question = UiKit.rich(30)
	_question.size_flags_vertical = Control.SIZE_EXPAND_FILL
	qp.add_child(_question)

	# four answers
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 84)
		b.focus_mode = Control.FOCUS_NONE
		_style_option(b, "normal")
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(row)
		var letter := UiKit.label((LETTERS_BN if Game.language == "bn" else LETTERS_EN)[i], 28, UiKit.INK, true)
		letter.custom_minimum_size = Vector2(96, 0)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_constant_override("outline_size", 0)
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(letter)
		var t := UiKit.label("", 24, UiKit.PAPER)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(t)
		b.pressed.connect(_answer.bind(i))
		col.add_child(b)
		_buttons.append(b)
		_texts.append(t)

	_taunt = UiKit.label("", 22, UiKit.PINK, true)
	_taunt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_taunt.custom_minimum_size = Vector2(0, 56)
	col.add_child(_taunt)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	_token_btn = UiKit.button("", 18)
	_token_btn.pressed.connect(_strike)
	foot.add_child(_token_btn)
	_bribe_btn = UiKit.button("", 18)
	_bribe_btn.pressed.connect(_bribe)
	foot.add_child(_bribe_btn)
	_flee_btn = UiKit.button("পালাও (X)" if Game.language == "bn" else "Flee (X)", 18)
	_flee_btn.pressed.connect(_flee)
	foot.add_child(_flee_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	_source = UiKit.label("", 14, UiKit.DIM)
	_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_source.custom_minimum_size = Vector2(520, 0)
	foot.add_child(_source)

	_banner = UiKit.label("", 64, UiKit.GREEN, true)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	root.add_child(_banner)


func _style_option(b: Button, state: String) -> void:
	var svg := "exam_option_" + state
	var sb := UiKit.style(svg)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_stylebox_override("hover", UiKit.style("exam_option_hover") if state == "normal" else sb)
	b.add_theme_stylebox_override("pressed", UiKit.style("exam_option_hover") if state == "normal" else sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# --- Flow -----------------------------------------------------------------------------------------

func _show(i: int) -> void:
	index = i
	_current = items[i]
	_shown = QuestionBank.display(_current, Game.language)
	_question.text = "[b]%s[/b]" % String(_shown["text"])
	var opts: Array = _shown["options"]
	for k in 4:
		_texts[k].text = String(opts[k]) if k < opts.size() else ""
		_buttons[k].disabled = false
		_style_option(_buttons[k], "normal")
	_progress.text = _progress_text()
	_token_btn.text = ("স্টাডি টোকেন: %s" if Game.language == "bn" else "Study token: %s") % UiKit.num(GameState.count("study_tokens"))
	_token_btn.disabled = GameState.count("study_tokens") <= 0
	var src := String(_current.get("source", ""))
	_source.text = src if bool(_current.get("cited", false)) else ("অনুশীলনী প্রশ্ন" if Game.language == "bn" else "Practice question")
	_time_left = _seconds
	_waiting = true


func _progress_text() -> String:
	if Game.language == "bn":
		return "প্রশ্ন %s/%s\nসঠিক %s · পাস %s" % [UiKit.num(index + 1), UiKit.num(items.size()), UiKit.num(right), UiKit.num(pass_mark)]
	return "Question %d/%d\nRight %d · Pass %d" % [index + 1, items.size(), right, pass_mark]


func _process(delta: float) -> void:
	if not _waiting:
		return
	_time_left -= delta
	_ring.value = clampf(_time_left / _seconds, 0.0, 1.0) * 1000.0
	_ring_label.text = UiKit.num(maxi(0, ceili(_time_left)))
	if _time_left <= 0.0:
		timed_out += 1
		_answer(-1)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	for k in 4:
		if event.is_action_pressed("answer_%d" % (k + 1)):
			_answer(k)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("bribe") and _bribe_btn.visible:
		_bribe()
	elif event.is_action_pressed("flee") and _flee_btn.visible:
		_flee()


func _answer(choice: int) -> void:
	if not _waiting or _done:
		return
	if choice >= 0 and _buttons[choice].disabled:
		return
	_waiting = false
	var ans := int(_shown["answer"])
	var ok := choice == ans
	session.record(_current, ok)
	for k in 4:
		_buttons[k].disabled = true
	_style_option(_buttons[ans], "correct")
	var line: Dictionary
	if ok:
		right += 1
		AudioEventBus.play_ui("right")
		line = TauntBank.pick("right_grudging", _rng) if _rng.randf() < 0.5 else {"bn": "সঠিক!", "en": "Correct!"}
	else:
		wrong += 1
		if choice >= 0:
			_style_option(_buttons[choice], "wrong")
		AudioEventBus.play_ui("wrong")
		line = TauntBank.pick("slow" if choice < 0 else String(ctx.get("taunts", "wrong")), _rng)
	_taunt.text = Game.text2(line)
	Voice.speak(_speaker_profile(), line, 2)
	_progress.text = _progress_text()
	await get_tree().create_timer(1.7 if ok else 2.4, true).timeout
	if _done:
		return
	var left := items.size() - (index + 1)
	if right >= pass_mark or wrong > items.size() - pass_mark or left <= 0:
		_finish(right >= pass_mark, false, false)
	else:
		_taunt.text = ""
		_show(index + 1)


func _strike() -> void:
	if not _waiting or not GameState.take_item("study_tokens"):
		return
	var ans := int(_shown["answer"])
	var candidates: Array[int] = []
	for k in 4:
		if k != ans and not _buttons[k].disabled:
			candidates.append(k)
	if candidates.is_empty():
		return
	var k2: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_buttons[k2].disabled = true
	_style_option(_buttons[k2], "struck")
	_token_btn.text = ("স্টাডি টোকেন: %s" if Game.language == "bn" else "Study token: %s") % UiKit.num(GameState.count("study_tokens"))
	_token_btn.disabled = GameState.count("study_tokens") <= 0


func _bribe() -> void:
	if _done:
		return
	var cost := int(ctx.get("bribe_cost", 200))
	if not GameState.spend(cost):
		_taunt.text = "টাকা নেই, ঘুষও নেই।" if Game.language == "bn" else "No money, no bribe."
		return
	var line := TauntBank.pick("bribe", _rng)
	_taunt.text = Game.text2(line)
	Voice.speak(_speaker_profile(), line, 2)
	AudioEventBus.play_ui("coins")
	_waiting = false
	await get_tree().create_timer(1.4, true).timeout
	_finish(true, true, false)


func _flee() -> void:
	if _done:
		return
	_waiting = false
	_finish(false, false, true)


func _finish(passed: bool, bribed: bool, fled: bool) -> void:
	if _done:
		return
	_done = true
	_waiting = false
	_banner.visible = true
	if fled:
		_banner.text = "পালালেন!" if Game.language == "bn" else "You ran!"
		_banner.add_theme_color_override("font_color", UiKit.MARIGOLD)
	elif passed:
		_banner.text = ("পাস!" if not bribed else "ঘুষে পাস") if Game.language == "bn" else ("PASSED" if not bribed else "BOUGHT A PASS")
		_banner.add_theme_color_override("font_color", UiKit.GREEN)
		AudioEventBus.play_ui("objective")
	else:
		_banner.text = "ফেল!" if Game.language == "bn" else "FAILED"
		_banner.add_theme_color_override("font_color", UiKit.RED)
		AudioEventBus.play_ui("fail")
	await get_tree().create_timer(1.3, true).timeout
	var ids: Array = []
	for it in items:
		ids.append(String(it.get("id", "")))
	finished.emit({"passed": passed, "right": right, "wrong": wrong, "total": items.size(), "bribed": bribed,
		"fled": fled, "timed_out": timed_out, "items": ids})
