class_name DialogueBox
extends Control
## Built-in replacement for the Dialogue Manager plugin: a speaker, lines typed out one by one,
## then up to four choices. E, Space, Enter or a click advances; 1-4 pick a choice.
## Usage: say("Mitu", ["line one", "line two"], [["Option A", "A"], ...], func(choice): ...)

signal opened
signal closed

const CHARS_PER_SECOND := 55.0

var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _hint: Label
var _choices: VBoxContainer
var _lines: Array = []
var _options: Array = []
var _cb: Callable = Callable()
var _i := 0
var _typing: Tween
var _open := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	add_child(_panel)
	_panel.set_anchor(SIDE_LEFT, 0.5, true)
	_panel.set_anchor(SIDE_RIGHT, 0.5, true)
	_panel.set_anchor(SIDE_TOP, 1.0, true)
	_panel.set_anchor(SIDE_BOTTOM, 1.0, true)
	_panel.offset_left = -520
	_panel.offset_right = 520
	_panel.offset_top = -300
	_panel.offset_bottom = -36
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.gui_input.connect(_on_panel_input)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	margin.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override(&"font_size", 22)
	_speaker.modulate = Color(1.0, 0.85, 0.45)
	box.add_child(_speaker)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(1000, 60)
	_text.add_theme_font_size_override(&"font_size", 22)
	box.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override(&"separation", 6)
	box.add_child(_choices)
	_hint = Label.new()
	_hint.add_theme_font_size_override(&"font_size", 14)
	_hint.modulate = Color(1, 1, 1, 0.5)
	_hint.text = "E / Space / click to continue"
	box.add_child(_hint)
	visible = false


func is_open() -> bool:
	return _open


func say(speaker: String, lines: Array, choices: Array = [], cb: Callable = Callable()) -> void:
	_lines = lines.duplicate()
	if _lines.is_empty():
		_lines = ["..."]
	_options = choices
	_cb = cb
	_i = 0
	_speaker.text = speaker
	if not _open:
		_open = true
		visible = true
		_panel.modulate.a = 0.0
		_panel.position.y += 30.0
		var tw := create_tween().set_parallel()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.18)
		tw.tween_property(_panel, "position:y", _panel.position.y - 30.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		opened.emit()
	_show_line()


func _show_line() -> void:
	for ch in _choices.get_children():
		ch.queue_free()
	_text.text = String(_lines[_i])
	_text.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(0.15, _text.text.length() / CHARS_PER_SECOND))
	_typing.tween_callback(_line_shown)
	AudioEventBus.play_ui("blip")


func _line_shown() -> void:
	if _i == _lines.size() - 1 and not _options.is_empty():
		_hint.text = "Choose (1-%d)" % _options.size()
		for k in _options.size():
			var b := Button.new()
			b.text = "%d.  %s" % [k + 1, String(_options[k][0])]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 40)
			b.add_theme_font_size_override(&"font_size", 19)
			b.pressed.connect(_choose.bind(k))
			_choices.add_child(b)
			if k == 0:
				b.grab_focus.call_deferred()
	else:
		_hint.text = "E / Space / click to continue"


func _advance() -> void:
	if not _open:
		return
	if _typing and _typing.is_running():
		_typing.kill()
		_text.visible_ratio = 1.0
		_line_shown()
		return
	if _i < _lines.size() - 1:
		_i += 1
		_show_line()
	elif _options.is_empty():
		_finish(null)


func _choose(k: int) -> void:
	if k < 0 or k >= _options.size():
		return
	AudioEventBus.play_ui("click")
	_finish(_options[k][1])


func _finish(value) -> void:
	var cb := _cb
	_cb = Callable()
	_open = false
	visible = false
	closed.emit()
	if cb.is_valid():
		cb.call(value)


func _on_panel_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _choices.get_child_count() == 0:
		_advance()


func _unhandled_input(e: InputEvent) -> void:
	if not _open:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k >= KEY_1 and k <= KEY_4 and not _options.is_empty() and _i == _lines.size() - 1:
			_choose(k - KEY_1)
			get_viewport().set_input_as_handled()
		elif k in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and _choices.get_child_count() == 0:
			_advance()
			get_viewport().set_input_as_handled()
