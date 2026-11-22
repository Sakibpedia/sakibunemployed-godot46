class_name Interactable
extends Node3D
## Doors that swing, gates that slide, roof doors that lock at 6 PM, lifts, pickups that bob,
## utilities with a lever, planks, drainpipes and one-off tasks.

signal used(it: Interactable, by: Node)

var kind := "task"        # door, gate, roof_door, lift, pickup, utility, task, plank, bypass, ride
var key := ""
var label := ""
var axis := "x"           # the direction a door or gate spans
var enabled := true
var opened := false
var data: Dictionary = {}
var _hinge: Node3D
var _panel: Node3D
var _body: StaticBody3D
var _check := 0.0
var _close_t := 0.0
var _base := Vector3.ZERO


func setup(k: String, info: Dictionary) -> void:
	kind = k
	data = info
	key = str(info.get("key", ""))
	label = str(info.get("label", ""))
	axis = str(info.get("axis", "x"))


func _ready() -> void:
	match kind:
		"door":
			_hinge = Node3D.new()
			_hinge.position = Vector3(-0.85, 0, 0) if axis == "x" else Vector3(0, 0, -0.85)
			add_child(_hinge)
			var size := Vector3(1.7, 2.15, 0.06) if axis == "x" else Vector3(0.06, 2.15, 1.7)
			_box(_hinge, size, Vector3(0.85, 1.075, 0) if axis == "x" else Vector3(0, 1.075, 0.85), Color(0.36, 0.22, 0.12))
		"gate", "roof_door":
			_panel = Node3D.new()
			add_child(_panel)
			var gsize := Vector3(2.0, 2.4, 0.12) if axis == "x" else Vector3(0.12, 2.4, 2.0)
			_box(_panel, gsize, Vector3(0, 1.2, 0), Color(0.42, 0.3, 0.2) if kind == "gate" else Color(0.3, 0.32, 0.34))
			for i in 4:
				var bar := Vector3(0.05, 2.3, 0.16) if axis == "x" else Vector3(0.16, 2.3, 0.05)
				var off := (i - 1.5) * 0.45
				_box(_panel, bar, Vector3(off, 1.2, 0) if axis == "x" else Vector3(0, 1.2, off), Color(0.2, 0.2, 0.22))
			_body = StaticBody3D.new()
			_body.collision_layer = 64
			_body.collision_mask = 0
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = gsize
			cs.shape = bs
			cs.position = Vector3(0, 1.2, 0)
			_body.add_child(cs)
			_panel.add_child(_body)
			if kind == "roof_door":
				add_to_group("roof_doors")
				_set_open(true, false)
		"lift":
			_box(self, Vector3(1.8, 2.3, 0.1), Vector3(0, 1.15, 0), Color(0.55, 0.38, 0.25))
			_box(self, Vector3(0.12, 0.12, 0.12), Vector3(1.1, 1.3, 0), Color(0.9, 0.7, 0.2), true)
			add_to_group("interactables")
		"pickup":
			_panel = Node3D.new()
			_panel.position = Vector3(0, 0.9, 0)
			add_child(_panel)
			_box(_panel, Vector3(0.3, 0.06, 0.22), Vector3.ZERO, Color(0.95, 0.85, 0.35), true)
			add_to_group("interactables")
		"utility":
			_box(self, Vector3(0.9, 1.4, 0.4), Vector3(0, 0.7, 0), Color(0.45, 0.47, 0.42))
			_panel = Node3D.new()
			_panel.position = Vector3(0.5, 1.0, 0)
			add_child(_panel)
			_box(_panel, Vector3(0.08, 0.45, 0.08), Vector3(0, 0.2, 0), Color(0.8, 0.1, 0.1), true)
			add_to_group("interactables")
		"plank", "bypass", "task", "ride":
			_panel = Node3D.new()
			_panel.position = Vector3(0, 1.2, 0)
			add_child(_panel)
			_box(_panel, Vector3(0.18, 0.18, 0.18), Vector3.ZERO, Color(0.3, 0.8, 0.9), true)
			add_to_group("interactables")
	_base = _panel.position if _panel else Vector3.ZERO


func _process(delta: float) -> void:
	match kind:
		"door":
			_check -= delta
			if _check <= 0.0:
				_check = 0.2
				var near := false
				for n in get_tree().get_nodes_in_group("actors") + get_tree().get_nodes_in_group("player"):
					if n is Node3D and n.global_position.distance_to(global_position) < 1.8:
						near = true
						break
				if near and not opened:
					_swing(true)
				elif not near and opened:
					_close_t += 0.2
					if _close_t > 2.5:
						_swing(false)
				if near:
					_close_t = 0.0
		"pickup", "plank", "bypass", "task", "ride":
			if _panel and enabled:
				_panel.rotation.y += delta * 1.5
				_panel.position.y = _base.y + sin(Time.get_ticks_msec() * 0.003) * 0.06


func prompt() -> String:
	if not enabled:
		return ""
	match kind:
		"lift":
			return "E  Call the lift"
		"pickup", "utility", "task", "plank", "bypass", "ride":
			return "E  " + (label if label != "" else kind.capitalize())
	return ""


func interact(by) -> void:
	if not enabled:
		return
	match kind:
		"pickup":
			enabled = false
			var tw := create_tween()
			tw.tween_property(_panel, "scale", Vector3.ZERO, 0.25)
			used.emit(self, by)
		"utility":
			enabled = false
			var tw := create_tween()
			tw.tween_property(_panel, "rotation:z", -1.3, 0.3).set_trans(Tween.TRANS_BACK)
			used.emit(self, by)
		"task":
			enabled = data.get("repeat", false)
			if not enabled and _panel:
				_panel.visible = false
			used.emit(self, by)
		_:
			used.emit(self, by)


## Gates and roof doors.
func open_gate() -> void:
	_set_open(true, true)


func lock() -> void:
	_set_open(false, true)


func _set_open(v: bool, animate: bool) -> void:
	opened = v
	if _panel == null:
		return
	var target := Vector3(1.9, 0, 0) if axis == "x" else Vector3(0, 0, 1.9)
	if not v:
		target = Vector3.ZERO
	if animate:
		var tw := create_tween()
		tw.tween_property(_panel, "position", target, 1.2).set_trans(Tween.TRANS_SINE)
		AudioEventBus.emit_event("gate_screech", global_position, 70.0, WorldState.current_sector)
	else:
		_panel.position = target
	if _body:
		_body.collision_layer = 0 if v else 64


func _swing(v: bool) -> void:
	opened = v
	_close_t = 0.0
	var tw := create_tween()
	tw.tween_property(_hinge, "rotation:y", -1.5 if v else 0.0, 0.35).set_trans(Tween.TRANS_QUAD)


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if glow:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.6
		mi.material_override = m
	else:
		mi.material_override = Humanoid.mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi
