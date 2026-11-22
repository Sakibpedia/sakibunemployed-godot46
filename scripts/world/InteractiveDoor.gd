class_name InteractiveDoor
extends Node3D
## A real hinged door: frame, panel, handle, nameplate and a collider that is removed while the door
## is open.  It can be clicked/interacted with (E) or opened automatically when the player walks up to
## it.  Doors are used for the building entrance, every flat, the stair core, bathrooms and the roof.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal opened
signal closed

var width := 0.95
var height := 2.08
var thickness := 0.055
var open_angle := -1.75          # radians; negative swings into the room for a +Z facing door
var auto_open := false
var locked := false
var is_open := false
var label := {"bn": "দরজা", "en": "Door"}
var wood_tint := Color(0.38, 0.23, 0.14)
var metal_tint := Color(0.55, 0.56, 0.58)
var nameplate := ""
var interactive := true

var _hinge: Node3D
var _panel: MeshInstance3D
var _collider: CollisionShape3D
var _body: StaticBody3D
var _tween: Tween
var _auto_t := 0.0


func configure(opts: Dictionary) -> void:
	width = float(opts.get("width", width))
	height = float(opts.get("height", height))
	thickness = float(opts.get("thickness", thickness))
	open_angle = float(opts.get("open_angle", open_angle))
	auto_open = bool(opts.get("auto_open", auto_open))
	locked = bool(opts.get("locked", locked))
	if opts.has("label"):
		label = opts["label"]
	if opts.has("wood"):
		wood_tint = opts["wood"]
	if opts.has("metal"):
		metal_tint = opts["metal"]
	nameplate = String(opts.get("nameplate", ""))


func _ready() -> void:
	if interactive:
		add_to_group(&"interactable")
	_build()


func _build() -> void:
	var frame_mat := BuildingMaterials.wood(wood_tint.darkened(0.18))
	var panel_mat := BuildingMaterials.wood(wood_tint)
	var steel := BuildingMaterials.metal(metal_tint)
	var jamb := 0.075
	for s in [-1.0, 1.0]:
		var j := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(jamb, height + 0.1, 0.13)
		j.mesh = bm
		j.position = Vector3(s * (width * 0.5 + jamb * 0.5), (height + 0.1) * 0.5, 0)
		j.material_override = frame_mat
		add_child(j)
	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(width + jamb * 2.0, 0.1, 0.13)
	lintel.mesh = lm
	lintel.position = Vector3(0, height + 0.05, 0)
	lintel.material_override = frame_mat
	add_child(lintel)
	var threshold := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(width + 0.16, 0.035, 0.16)
	threshold.mesh = tm
	threshold.position = Vector3(0, 0.017, 0)
	threshold.material_override = BuildingMaterials.concrete()
	add_child(threshold)

	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(-width * 0.5, 0, 0)
	add_child(_hinge)
	_panel = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(width, height, thickness)
	_panel.mesh = pm
	_panel.position = Vector3(width * 0.5, height * 0.5, 0)
	_panel.material_override = panel_mat
	_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hinge.add_child(_panel)
	# Recessed panels, so a door reads as a door even in flat light.
	for yy in [0.42, 0.72]:
		var inset := MeshInstance3D.new()
		var im := BoxMesh.new()
		im.size = Vector3(width * 0.62, height * 0.24, thickness + 0.012)
		inset.mesh = im
		inset.position = Vector3(width * 0.5, height * yy, 0)
		inset.material_override = BuildingMaterials.wood(wood_tint.darkened(0.08))
		_hinge.add_child(inset)
	var handle := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.032
	hm.height = 0.064
	hm.radial_segments = 12
	hm.rings = 6
	handle.mesh = hm
	handle.position = Vector3(width * 0.44, height * 0.46, thickness * 0.5 + 0.035)
	handle.material_override = steel
	_hinge.add_child(handle)
	var plate := MeshInstance3D.new()
	var plm := BoxMesh.new()
	plm.size = Vector3(0.05, 0.16, 0.012)
	plate.mesh = plm
	plate.position = Vector3(width * 0.44, height * 0.46, thickness * 0.5 + 0.006)
	plate.material_override = steel
	_hinge.add_child(plate)
	# Physics: the door blocks the opening when closed and disappears from collision while open.
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_hinge.add_child(_body)
	_collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.09)
	_collider.shape = shape
	_collider.position = Vector3(width * 0.5, height * 0.5, 0)
	_body.add_child(_collider)
	if nameplate != "":
		var lbl := Label3D.new()
		lbl.text = nameplate
		lbl.font = UiKit.font(true)
		lbl.font_size = 40
		lbl.pixel_size = 0.0035
		lbl.outline_size = 6
		lbl.position = Vector3(0, height + 0.23, 0.02)
		lbl.modulate = Color(0.95, 0.88, 0.65)
		add_child(lbl)


func interact_options(_player: Node) -> Array:
	if locked:
		return []
	return [{"id": "toggle", "label": {"bn": "বন্ধ করো" if is_open else "খোলো", "en": "Close" if is_open else "Open"}}]


func display_name() -> Dictionary:
	return label


func interact(_player: Node, _id: String) -> void:
	if locked:
		return
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or _hinge == null:
		return
	is_open = true
	if _collider != null:
		_collider.disabled = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hinge, "rotation:y", open_angle, 0.42)
	_auto_t = 0.0
	AudioEventBus.emit_event("gate_screech", global_position, 42.0)
	opened.emit()


func close() -> void:
	if not is_open or _hinge == null:
		return
	is_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_hinge, "rotation:y", 0.0, 0.38)
	_tween.tween_callback(func() -> void:
		if _collider != null:
			_collider.disabled = false)
	AudioEventBus.emit_event("gate_screech", global_position, 38.0)
	closed.emit()


func _process(delta: float) -> void:
	if not auto_open or locked or _hinge == null:
		return
	var p: Node3D = Services.player
	if p == null or not is_instance_valid(p):
		return
	var d := global_position.distance_to(p.global_position)
	if d < 1.65 and not is_open:
		open()
	elif d > 3.2 and is_open:
		_auto_t += delta
		if _auto_t > 2.5:
			close()
			_auto_t = 0.0
	else:
		_auto_t = 0.0
