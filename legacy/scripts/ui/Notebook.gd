class_name Notebook
extends CanvasLayer
## The Sky lens (design doc Section 2.3): Tab lifts the view above the rooftops in 1.5 s and drops
## back in 1.0 s. From above Sakib can mark enemies through his lookouts or set off a distraction.
## The world keeps running, enemies notice a still figure faster (x1.5), and getting hurt slams it shut.

const UP_S := 1.5
const DOWN_S := 1.0
const HEIGHT := 46.0
const MARK_LAYER := 1 << 19

var level: Node
var is_open := false
var _busy := false
var _cam: Camera3D
var _panel: PanelContainer
var _info: Label
var _marks: Node3D
var _mat_enemy: StandardMaterial3D
var _mat_ally: StandardMaterial3D
var _mat_me: StandardMaterial3D
var _mat_goal: StandardMaterial3D
var _disc: CylinderMesh
var _refresh := 0.0


func setup(lvl: Node) -> void:
	level = lvl
	layer = 8
	_panel = PanelContainer.new()
	_panel.visible = false
	add_child(_panel)
	_panel.set_anchor(SIDE_LEFT, 1.0, true)
	_panel.set_anchor(SIDE_RIGHT, 1.0, true)
	_panel.set_anchor(SIDE_TOP, 1.0, true)
	_panel.set_anchor(SIDE_BOTTOM, 1.0, true)
	_panel.offset_left = -520
	_panel.offset_right = -24
	_panel.offset_top = -330
	_panel.offset_bottom = -110
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	_panel.add_child(box)
	var t := Label.new()
	t.text = "Notebook · Sky lens"
	t.add_theme_font_size_override(&"font_size", 22)
	box.add_child(t)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(480, 0)
	box.add_child(_info)
	_button(box, "Lookouts: call out every enemy for 30 s (1 battery)", _order_lookouts)
	_button(box, "Firecracker across the lane: pull guards away (1 scrap)", _order_firecracker)
	_button(box, "Back down (Tab)", close)
	_mat_enemy = _flat(Color(1.0, 0.2, 0.15))
	_mat_ally = _flat(Color(0.2, 0.9, 0.95))
	_mat_me = _flat(Color(0.3, 1.0, 0.3))
	_mat_goal = _flat(Color(1.0, 0.85, 0.2))
	_disc = CylinderMesh.new()
	_disc.top_radius = 0.9
	_disc.bottom_radius = 0.9
	_disc.height = 0.15
	_disc.radial_segments = 16


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("notebook"):
		get_viewport().set_input_as_handled()
		if is_open:
			close()
		elif not level.is_busy() and not level.player.dead:
			open()


func _process(delta: float) -> void:
	if not is_open or _busy:
		return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.25
	_draw_marks()
	var heat: float = WorldState.sector(level.sector).comms_heat
	var seen := 0
	for c in _marks.get_children():
		if c.material_override == _mat_enemy:
			seen += 1
	_info.text = "Enemies in sight: %d · comms heat %d%% (their scanner listens above 50%%)\nBatteries %d · scrap %d · the world keeps moving while you plan." % [
		seen, int(heat), int(WorldState.resources.get("batteries", 0)), int(WorldState.resources.get("scrap", 0))]


func open() -> void:
	if is_open or _busy:
		return
	_busy = true
	is_open = true
	level._modal_push()
	WorldState.set_lens(WorldState.Lens.TRANSIT_UP)
	var p: Player = level.player
	_cam = Camera3D.new()
	_cam.cull_mask = 0xFFFFF
	_cam.fov = p.cam.fov
	_cam.far = 400.0
	level.add_child(_cam)
	_cam.global_transform = p.cam.global_transform
	_cam.current = true
	_marks = Node3D.new()
	level.add_child(_marks)
	var top := Transform3D(Basis.looking_at(Vector3(0, -1, -0.35).normalized(), Vector3.UP), p.global_position + Vector3(0, HEIGHT, HEIGHT * 0.35))
	var tw := create_tween()
	tw.tween_property(_cam, "global_transform", top, UP_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(_cam, "fov", 55.0, UP_S)
	AudioEventBus.play_ui("page")
	await tw.finished
	if not is_open:
		return
	_busy = false
	WorldState.set_lens(WorldState.Lens.SKY_PLAN)
	_panel.visible = true
	_refresh = 0.0


func close() -> void:
	_close(DOWN_S)


## Damage slams the notebook shut (Section 2.3).
func force_close() -> void:
	if is_open:
		level.toast("You're hit. The notebook snaps shut.", Color(1.0, 0.5, 0.45))
		_close(0.25)


func _close(seconds: float) -> void:
	if not is_open or _cam == null:
		return
	is_open = false
	_busy = true
	_panel.visible = false
	WorldState.set_lens(WorldState.Lens.TRANSIT_DOWN)
	var p: Player = level.player
	var tw := create_tween()
	tw.tween_property(_cam, "global_transform", p.cam.global_transform, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(_cam, "fov", p.cam.fov, seconds)
	await tw.finished
	p.cam.current = true
	_cam.queue_free()
	_cam = null
	if is_instance_valid(_marks):
		_marks.queue_free()
	_marks = null
	WorldState.set_lens(WorldState.Lens.GROUND_STEALTH)
	_busy = false
	level._modal_pop()


func _draw_marks() -> void:
	for c in _marks.get_children():
		c.queue_free()
	var p: Player = level.player
	_mark(p.global_position, _mat_me, 1.3)
	for a in get_tree().get_nodes_in_group("actors"):
		if not a.visible or a.state in ["dead", "ko"]:
			continue
		if a.faction == "syndicate":
			if a.revealed > 0.0 or a.global_position.distance_to(p.global_position) < 16.0:
				_mark(a.global_position, _mat_enemy, 1.0)
		elif a.role != "civilian":
			_mark(a.global_position, _mat_ally, 0.8)
	var goal = level.objective_target()
	if goal != null:
		_mark(goal, _mat_goal, 1.5)


func _mark(pos: Vector3, m: StandardMaterial3D, s: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _disc
	mi.material_override = m
	mi.layers = MARK_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(s, 1.0, s)
	_marks.add_child(mi)
	mi.global_position = pos + Vector3(0, 2.6, 0)


func _order_lookouts() -> void:
	if not WorldState.spend("batteries", 1):
		level.toast("No batteries. Your phone is dead.")
		return
	WorldState.add_comms_heat(level.sector)
	for a in get_tree().get_nodes_in_group("syndicate"):
		a.revealed = maxf(a.revealed, 30.0)
	level.toast("Your lookouts call out every gunman they can see.", Color(0.6, 1.0, 0.6))
	_refresh = 0.0


func _order_firecracker() -> void:
	if not WorldState.spend("scrap", 1):
		level.toast("No scrap to make a firecracker from.")
		return
	var p: Player = level.player
	var spot := p.global_position + Vector3(14, 0, 0)
	var best := INF
	for m in level.builder.markers.get("P", []) + level.builder.markers.get("C", []):
		var d: float = m.distance_to(p.global_position)
		if d > 10.0 and d < 40.0 and absf(d - 20.0) < best:
			best = absf(d - 20.0)
			spot = m
	WorldState.add_comms_heat(level.sector)
	AudioEventBus.emit_event("firecracker", spot, 75.0, level.sector)
	level.toast("Bang! Heads turn toward the noise.")


func _button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(cb)
	parent.add_child(b)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.no_depth_test = true
	m.render_priority = 10
	return m
