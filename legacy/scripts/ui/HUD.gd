class_name HUD
extends CanvasLayer
## On-screen information: objective and waypoint, clock, health, ammo, inventory, alert,
## prompts, sliding toasts, damage vignette, revealed enemies, and one modal panel.
## Runs while the game is paused so the pause panel works.

var level: Node
var _objective: Label
var _title: Label
var _clock: Label
var _health: ProgressBar
var _ammo: Label
var _inv: Label
var _alert: Label
var _alert_bar: ProgressBar
var _prompt: Label
var _cross: Label
var _toasts: VBoxContainer
var _vignette: ColorRect
var _waypoint: Label
var _marks: Array[Label] = []
var _center: CenterContainer
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _help: Label
var _roof_warn := false


func setup(lvl: Node) -> void:
	level = lvl
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vignette = ColorRect.new()
	_vignette.color = Color(0.7, 0.0, 0.0, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = _label(Vector2(28, 18), 22, Color(1, 1, 1, 0.9), 0.0, 0.0)
	_objective = _label(Vector2(28, 52), 21, Color(1.0, 0.92, 0.6), 0.0, 0.0)
	_clock = _label(Vector2(-150, 18), 30, Color.WHITE, 1.0, 0.0)
	_health = ProgressBar.new()
	_health.max_value = 100.0
	_health.show_percentage = false
	_place(_health, Vector2(28, -74), Vector2(260, 18), 0.0, 1.0)
	_ammo = _label(Vector2(28, -50), 19, Color.WHITE, 0.0, 1.0)
	_inv = _label(Vector2(310, -74), 16, Color(0.88, 0.88, 0.88), 0.0, 1.0)
	_alert = _label(Vector2(-300, -76), 19, Color.WHITE, 1.0, 1.0)
	_alert_bar = ProgressBar.new()
	_alert_bar.show_percentage = false
	_place(_alert_bar, Vector2(-300, -46), Vector2(260, 12), 1.0, 1.0)
	_cross = _label(Vector2(-7, -16), 24, Color(1, 1, 1, 0.8), 0.5, 0.5)
	_cross.text = "+"
	_prompt = _label(Vector2(-320, 44), 21, Color.WHITE, 0.5, 0.5)
	_prompt.custom_minimum_size = Vector2(640, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waypoint = _label(Vector2.ZERO, 18, Color(1.0, 0.85, 0.3), 0.0, 0.0)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override(&"separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_toasts, Vector2(-470, 100), Vector2(440, 10), 1.0, 0.0)
	for i in 12:
		var m := _label(Vector2.ZERO, 22, Color(1.0, 0.25, 0.2), 0.0, 0.0)
		m.text = "▼"
		m.visible = false
		_marks.append(m)
	_help = _label(Vector2(28, 96), 17, Color(1, 1, 1, 0.9), 0.0, 0.0)
	_help.visible = false
	_help.text = "WASD move · Shift sprint · C crouch · Space jump · Q / Z lean · right mouse aim · left mouse shoot\nR reload · E talk / use · F takedown from behind · H bandage · Tab notebook (Sky lens) · Esc pause · F1 this help"
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.custom_minimum_size = Vector2(640, 0)
	_center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_panel.add_child(margin)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override(&"separation", 10)
	margin.add_child(_panel_box)


func _process(delta: float) -> void:
	if level == null or level.player == null:
		return
	var p: Player = level.player
	var c := WorldState.clock()
	_clock.text = "%02d:%02d" % [c.x, c.y]
	_clock.modulate = Color(1.0, 0.4, 0.3) if _roof_warn and Time.get_ticks_msec() % 1000 < 500 else Color.WHITE
	_health.value = p.health
	_ammo.text = "Pistol %d / %d" % [p.mag, int(WorldState.resources.get("ammo", 0))]
	var r := WorldState.resources
	_inv.text = "৳%d   Bandages %d   Study tokens %d   Batteries %d   Scrap %d   Honesty %d" % [int(r.get("taka", 0)),
		int(r.get("medical", 0)), int(r.get("study_tokens", 0)), int(r.get("batteries", 0)), int(r.get("scrap", 0)),
		int(WorldState.reputation.get("exam_honesty", 0))]
	var top := 0.0
	for a in get_tree().get_nodes_in_group("syndicate"):
		if a.active and not (a.state in ["dead", "ko", "dying"]):
			top = maxf(top, a.suspicion)
	_alert_bar.value = top
	_alert.text = "Unseen" if top < 25.0 else ("Noticed" if top < 50.0 else ("Searching" if top < 100.0 else "COMBAT"))
	_alert.modulate = Color.WHITE if top < 50.0 else (Color(1.0, 0.8, 0.3) if top < 100.0 else Color(1.0, 0.3, 0.25))
	var n = null
	if not p.input_locked and not p.dead:
		n = p.best_interactable()
	_prompt.text = n.prompt() if n != null else ""
	_cross.visible = not p.input_locked and not p.dead
	var floor_a := (1.0 - p.health / 100.0) * 0.25
	_vignette.color.a = maxf(_vignette.color.a - delta * 0.8, floor_a)
	_update_waypoint(p)
	_update_marks(p)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("help"):
		_help.visible = not _help.visible
	elif e.is_action_pressed("pause") and level and level.has_method("toggle_pause"):
		level.toggle_pause()
		get_viewport().set_input_as_handled()


func set_title(text: String) -> void:
	_title.text = text


func set_objective(text: String) -> void:
	if text == _objective.text:
		return
	_objective.text = text
	_objective.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_objective, "modulate:a", 1.0, 0.5)


func roof_warning(on: bool) -> void:
	_roof_warn = on


func flash_damage() -> void:
	_vignette.color.a = minf(0.55, _vignette.color.a + 0.3)


func toast(text: String, col := Color.WHITE) -> void:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	l.add_theme_font_size_override(&"font_size", 18)
	l.modulate = col
	pc.add_child(l)
	pc.modulate.a = 0.0
	_toasts.add_child(pc)
	var tw := pc.create_tween()
	tw.tween_property(pc, "modulate:a", 1.0, 0.25)
	tw.tween_interval(5.0)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pc.queue_free)
	if _toasts.get_child_count() > 5:
		_toasts.get_child(0).queue_free()


func show_panel(title: String, body: String, buttons: Array) -> void:
	for ch in _panel_box.get_children():
		ch.queue_free()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override(&"font_size", 30)
	_panel_box.add_child(t)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(600, 0)
	b.add_theme_font_size_override(&"font_size", 18)
	_panel_box.add_child(b)
	var first: Button = null
	for pair in buttons:
		var btn := Button.new()
		btn.text = String(pair[0])
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(pair[1])
		btn.pressed.connect(func() -> void: AudioEventBus.play_ui("click"))
		_panel_box.add_child(btn)
		if first == null:
			first = btn
	_panel.visible = true
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)
	if first:
		first.grab_focus.call_deferred()


func hide_panel() -> void:
	_panel.visible = false


func panel_open() -> bool:
	return _panel.visible


func _update_waypoint(p: Player) -> void:
	var target = level.objective_target()
	if target == null or p.input_locked:
		_waypoint.visible = false
		return
	var pos: Vector3 = target
	var vp := get_viewport().get_visible_rect().size
	var d := p.global_position.distance_to(pos)
	var sp: Vector2
	var head := pos + Vector3(0, 1.0, 0)
	if p.cam.is_position_behind(head):
		var rel := p.global_transform.basis.inverse() * (pos - p.global_position)
		sp = Vector2(vp.x * 0.5 + signf(rel.x) * vp.x * 0.45, vp.y * 0.85)
	else:
		sp = p.cam.unproject_position(head)
	sp = sp.clamp(Vector2(40, 100), vp - Vector2(140, 130))
	_waypoint.position = sp
	var floors := int(roundf((pos.y - p.global_position.y) / 3.2))
	var updown := "" if floors == 0 else ("  ↑%d" % floors if floors > 0 else "  ↓%d" % -floors)
	_waypoint.text = "◆ %d m%s" % [int(d), updown]
	_waypoint.visible = true


func _update_marks(p: Player) -> void:
	var i := 0
	for a in get_tree().get_nodes_in_group("syndicate"):
		if i >= _marks.size():
			break
		if a.revealed <= 0.0 or a.state in ["dead", "ko"]:
			continue
		var pos: Vector3 = a.global_position + Vector3(0, 2.1, 0)
		if p.cam.is_position_behind(pos):
			continue
		_marks[i].position = p.cam.unproject_position(pos) - Vector2(8, 12)
		_marks[i].visible = true
		i += 1
	for k in range(i, _marks.size()):
		_marks[k].visible = false


## Anchors first (keeping offsets), then offsets, so placement never depends on tree state.
func _place(c: Control, pos: Vector2, size: Vector2, ax: float, ay: float) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchor(SIDE_LEFT, ax, true)
	c.set_anchor(SIDE_RIGHT, ax, true)
	c.set_anchor(SIDE_TOP, ay, true)
	c.set_anchor(SIDE_BOTTOM, ay, true)
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + size.x
	c.offset_bottom = pos.y + size.y


func _label(pos: Vector2, size: int, col: Color, ax: float, ay: float) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.modulate = col
	_place(l, pos, Vector2.ZERO, ax, ay)
	return l
