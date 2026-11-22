class_name DialogueBox
extends CanvasLayer
## Conversations: the SVG dialogue box with the speaker's portrait in its frame, the line typed
## out and spoken aloud (Voice), then the choices (1-4). E, Enter or a click moves on. The world
## pauses while people talk.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal finished(choice_id: String)

var _lines: Array = []
var _choices: Array = []
var _i := -1
var _done: Callable
var _panel: PanelContainer
var _name: Label
var _text: Label
var _face: TextureRect
var _choice_box: VBoxContainer
var _hint: Label
var _typing := 0.0
var _full := ""
var _auto := 0.0
var _open := false
var _was_paused := false
var _chars: Dictionary = {}


func _init() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_characters(chars: Dictionary) -> void:
	_chars = chars


func is_open() -> bool:
	return _open


func _build() -> void:
	if _panel != null:
		return
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.style("dialogue_box_bg"))
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -600
	_panel.offset_right = 600
	_panel.offset_top = -330
	_panel.offset_bottom = -30
	root.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_panel.add_child(row)
	var pf := Control.new()
	pf.custom_minimum_size = Vector2(150, 150)
	row.add_child(pf)
	_face = TextureRect.new()
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.position = Vector2(15, 15)
	_face.size = Vector2(120, 120)
	pf.add_child(_face)
	var frame := TextureRect.new()
	frame.texture = UiKit.tex("portrait_frame")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = Vector2(150, 150)
	pf.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_name = UiKit.label("", 26, UiKit.MARIGOLD, true)
	col.add_child(_name)
	_text = UiKit.label("", 25, UiKit.PAPER)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_text)
	_choice_box = VBoxContainer.new()
	col.add_child(_choice_box)
	_hint = UiKit.label("", 15, UiKit.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_hint)


## lines: [{who, bn, en}], choices: [{id, bn, en, ...}]
func play(lines: Array, choices: Array, done: Callable) -> void:
	_build()
	_lines = lines
	_choices = choices
	_done = done
	_i = -1
	_open = true
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_next()


func _speaker(who: String) -> Dictionary:
	if who == "sakib":
		return {"id": "sakib", "name": {"bn": "সাকিব", "en": "Sakib"}, "face": "sakib", "voice": {"pitch": 0.95, "rate": 1.0, "index": 2}}
	if who == "narrator" or who == "":
		return {"id": "narrator", "name": {"bn": "", "en": ""}, "face": "", "voice": {"pitch": 1.0, "rate": 0.95, "index": 3}}
	var c: Dictionary = _chars.get(who, {})
	var v: Dictionary = c.get("voice", {"pitch": 1.0, "rate": 1.0, "index": absi(hash(who)) % 6})
	return {"id": who, "name": c.get("name", {"bn": who, "en": who}), "face": String(c.get("face", "")), "voice": v}


func _next() -> void:
	_i += 1
	for c in _choice_box.get_children():
		c.queue_free()
	if _i >= _lines.size():
		if not _choices.is_empty() and _i == _lines.size():
			_show_choices()
			return
		_close("")
		return
	var ln: Dictionary = _lines[_i]
	var sp := _speaker(String(ln.get("who", "")))
	_name.text = Game.text(sp["name"])
	_face.texture = UiKit.portrait(String(sp["face"]))
	_face.visible = _face.texture != null
	_full = Game.text2(ln)
	_text.text = ""
	_typing = 0.0
	_auto = 2.0 + _full.length() * 0.055
	_hint.text = "E / Enter ▸"
	Voice.speak(sp, ln, 2)


func _show_choices() -> void:
	_name.text = "সাকিব" if Game.language == "bn" else "Sakib"
	_face.texture = UiKit.portrait("sakib")
	_text.text = ""
	_hint.text = "১-৪" if Game.language == "bn" else "1-4"
	for i in _choices.size():
		var ch: Dictionary = _choices[i]
		var b := UiKit.button("%s  %s" % [UiKit.num(i + 1), Game.text(ch)], 20)
		b.pressed.connect(_pick.bind(i))
		_choice_box.add_child(b)


func _pick(i: int) -> void:
	var ch: Dictionary = _choices[i]
	_choices = []
	_close(String(ch.get("id", "")))


func _close(choice_id: String) -> void:
	_open = false
	visible = false
	Voice.stop()
	get_tree().paused = _was_paused
	if not _was_paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var cb := _done
	finished.emit(choice_id)
	if cb.is_valid():
		cb.call(choice_id)


func _process(delta: float) -> void:
	if not _open or _i < 0 or _i >= _lines.size():
		return
	if _text.text.length() < _full.length():
		_typing += delta * 55.0
		_text.text = _full.substr(0, int(_typing))
	else:
		_auto -= delta


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if _i >= _lines.size() and not _choices.is_empty():
		for k in mini(4, _choices.size()):
			if event.is_action_pressed("answer_%d" % (k + 1)):
				_pick(k)
				get_viewport().set_input_as_handled()
				return
		return
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("skip")
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if advance:
		get_viewport().set_input_as_handled()
		if _text.text.length() < _full.length():
			_text.text = _full
		else:
			_next()
