class_name TouchControls
extends CanvasLayer
## On-screen controls for phones, tablets and phone browsers (Android .apk and the web build).
## Left thumb: movement stick. Right thumb: drag anywhere free to look; round buttons for actions.
## Buttons press the same input actions as the keyboard, so every system works unchanged.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const STICK_CENTRE := Vector2(450, 830)  # right of the radar (bottom-left HUD)
const STICK_RADIUS := 130.0
const LOOK_GAIN := 1.7

enum Mode { TAP, HOLD, TOGGLE }
## [action, Bengali label, centre, radius, mode]. HOLD stays pressed while touched; TOGGLE flips.
const BUTTONS := [
	["fire", "মারো", Vector2(1720, 760), 92.0, Mode.HOLD],
	["jump", "লাফ", Vector2(1560, 900), 70.0, Mode.HOLD],
	["sprint", "দৌড়", Vector2(1780, 960), 62.0, Mode.HOLD],
	["interact", "কথা", Vector2(1540, 700), 62.0, Mode.TAP],
	["vehicle", "গাড়ি", Vector2(1400, 860), 58.0, Mode.TAP],
	["aim", "তাক", Vector2(1830, 610), 54.0, Mode.TOGGLE],
	["crouch", "বসো", Vector2(1410, 990), 50.0, Mode.TOGGLE],
	["reload", "রিলোড", Vector2(1680, 580), 50.0, Mode.TAP],
	["weapon_next", "অস্ত্র", Vector2(1830, 470), 48.0, Mode.TAP],
	["torch", "টর্চ", Vector2(1680, 450), 48.0, Mode.TAP],
	["bandage", "পট্টি", Vector2(1540, 560), 48.0, Mode.TAP],
	["camera", "ক্যামেরা", Vector2(110, 330), 54.0, Mode.TAP],
	["map", "মানচিত্র", Vector2(110, 460), 54.0, Mode.TAP],
	["missions", "মিশন", Vector2(110, 590), 54.0, Mode.TAP],
	["horn", "হর্ন", Vector2(1400, 720), 46.0, Mode.TAP],
	["pause", "বিরতি", Vector2(1450, 70), 46.0, Mode.TAP],
]

var player: Node = null
var _canvas: Control
var _font: Font
var _stick_touch := -1
var _stick_vec := Vector2.ZERO
var _look_touch := -1
var _held := {}  # touch index -> action (HOLD buttons)
var _toggled := {}  # action -> true (TOGGLE buttons that are on)


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = UiKit.font(true)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)


func _process(_d: float) -> void:
	var paused := get_tree().paused or _gui_open()
	_canvas.visible = not paused
	if paused and (_stick_touch >= 0 or not _held.is_empty()):
		_release_all()
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var p := t.position  # already in the 1920x1080 canvas space (stretch mode canvas_items)
		if t.pressed:
			_touch_down(t.index, p)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_touch:
			_set_stick(d.position)
		elif d.index == _look_touch and player != null and player.has_method("look"):
			player.call("look", d.relative * LOOK_GAIN)


func _driving() -> bool:
	return player != null and player.has_method("in_vehicle") and bool(player.call("in_vehicle"))


func _gui_open() -> bool:
	var hud: Node = Services.hud
	return hud != null and hud.has_method("blocks_touch") and bool(hud.call("blocks_touch"))


func _touch_down(index: int, p: Vector2) -> void:
	if _gui_open():
		return  # a choice list or the map is open: let the tap reach the buttons
	for b in BUTTONS:
		if String(b[0]) == "horn" and not _driving():
			continue
		var centre: Vector2 = b[2]
		if p.distance_to(centre) > float(b[3]) * 1.15:
			continue
		var action: String = b[0]
		match int(b[4]):
			Mode.HOLD:
				_held[index] = action
				_send(action, true)
			Mode.TOGGLE:
				var on := not _toggled.has(action)
				if on:
					_toggled[action] = true
				else:
					_toggled.erase(action)
				_send(action, on)
			_:
				_send(action, true)
				_send(action, false)
		return
	if p.distance_to(STICK_CENTRE) <= STICK_RADIUS * 1.6 and _stick_touch < 0:
		_stick_touch = index
		_set_stick(p)
	elif p.x > 760 and _look_touch < 0:
		_look_touch = index


## Buttons go through the normal event queue, so _unhandled_input and Input.is_action_* both see them.
func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _touch_up(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = -1
		_set_stick(STICK_CENTRE)
	if index == _look_touch:
		_look_touch = -1
	if _held.has(index):
		_send(String(_held[index]), false)
		_held.erase(index)


func _set_stick(p: Vector2) -> void:
	var v := (p - STICK_CENTRE) / STICK_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	_stick_vec = v
	_axis("move_left", "move_right", v.x)
	_axis("move_forward", "move_back", v.y)


func _axis(neg: String, pos: String, value: float) -> void:
	var dead := 0.12
	if value < -dead:
		Input.action_press(neg, minf(1.0, -value))
		Input.action_release(pos)
	elif value > dead:
		Input.action_press(pos, minf(1.0, value))
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _release_all() -> void:
	_stick_touch = -1
	_look_touch = -1
	_set_stick(STICK_CENTRE)
	for idx in _held:
		_send(String(_held[idx]), false)
	_held.clear()


func _draw_controls() -> void:
	var c := _canvas
	c.draw_circle(STICK_CENTRE, STICK_RADIUS, Color(0, 0, 0, 0.28))
	c.draw_arc(STICK_CENTRE, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	c.draw_circle(STICK_CENTRE + _stick_vec * STICK_RADIUS, 52.0, Color(1, 1, 1, 0.45 if _stick_touch >= 0 else 0.3))
	var driving := _driving()
	for b in BUTTONS:
		var action: String = b[0]
		if action == "horn" and not driving:
			continue
		var centre: Vector2 = b[2]
		var r := float(b[3])
		var down := _held.values().has(action) or _toggled.has(action)
		c.draw_circle(centre, r, Color(0.05, 0.05, 0.06, 0.55 if down else 0.38))
		c.draw_arc(centre, r, 0, TAU, 40, Color(1, 0.86, 0.55, 0.75 if down else 0.45), 3.0)
		var label: String = b[1]
		var size := 30 if r >= 60.0 else 24
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		while w > r * 1.7 and size > 14:  # long words (ক্যামেরা, মানচিত্র) shrink to fit the circle
			size -= 2
			w = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		c.draw_string(_font, centre + Vector2(-w * 0.5, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.92))
