class_name InteractiveWindow
extends Node3D
## A casement window with two sashes, glass, a sill, a grille and curtains.  It opens on interaction
## or automatically when the player is close, and its collider disappears while open.  Windows are
## placed in real openings cut into the generated walls, so the player can look down into the street.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

var width := 1.15
var height := 1.30
var auto_open := false
var is_open := false
var label := {"bn": "জানালা", "en": "Window"}
var curtain_color := Color(0.78, 0.70, 0.58)
var grille := true

var _left: Node3D
var _right: Node3D
var _collider: CollisionShape3D
var _tween: Tween
var _auto_t := 0.0


func configure(opts: Dictionary) -> void:
	width = float(opts.get("width", width))
	height = float(opts.get("height", height))
	auto_open = bool(opts.get("auto_open", auto_open))
	grille = bool(opts.get("grille", grille))
	if opts.has("label"):
		label = opts["label"]
	if opts.has("curtain"):
		curtain_color = opts["curtain"]


func _ready() -> void:
	add_to_group(&"interactable")
	_build()


func _build() -> void:
	var frame_mat := BuildingMaterials.painted_metal(Color(0.30, 0.32, 0.33))
	var glass_mat := BuildingMaterials.glass()
	var jamb := 0.055
	# Outer frame.
	for s in [-1.0, 1.0]:
		var j := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(jamb, height + jamb * 2.0, 0.12)
		j.mesh = bm
		j.position = Vector3(s * (width * 0.5 + jamb * 0.5), height * 0.5, 0)
		j.material_override = frame_mat
		add_child(j)
	for y in [0.0, height]:
		var l := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(width + jamb * 2.0, jamb, 0.12)
		l.mesh = lm
		l.position = Vector3(0, y, 0)
		l.material_override = frame_mat
		add_child(l)
	var sill := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(width + 0.24, 0.07, 0.28)
	sill.mesh = sm
	sill.position = Vector3(0, -0.045, 0.06)
	sill.material_override = BuildingMaterials.concrete()
	add_child(sill)
	# Two sashes.
	_left = Node3D.new()
	_left.position = Vector3(-width * 0.5, 0, 0)
	add_child(_left)
	_right = Node3D.new()
	_right.position = Vector3(width * 0.5, 0, 0)
	add_child(_right)
	_sash(_left, width * 0.5, glass_mat, frame_mat)
	_sash(_right, -width * 0.5, glass_mat, frame_mat)
	if grille:
		for i in 3:
			var bar := MeshInstance3D.new()
			var bm2 := BoxMesh.new()
			bm2.size = Vector3(0.018, height + 0.04, 0.018)
			bar.mesh = bm2
			bar.position = Vector3(-width * 0.35 + i * width * 0.35, height * 0.5, 0.075)
			bar.material_override = BuildingMaterials.metal(Color(0.18, 0.19, 0.2))
			add_child(bar)
		for i in 3:
			var hb := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(width + 0.04, 0.016, 0.016)
			hb.mesh = hm
			hb.position = Vector3(0, 0.2 + i * height * 0.3, 0.075)
			hb.material_override = BuildingMaterials.metal(Color(0.18, 0.19, 0.2))
			add_child(hb)
	# Curtains just inside the glass.
	for s in [-1.0, 1.0]:
		var c := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(width * 0.44, height * 0.96, 0.018)
		c.mesh = cm
		c.position = Vector3(s * width * 0.24, height * 0.5, -0.085)
		c.material_override = BuildingMaterials.curtain(curtain_color)
		add_child(c)
	# A small pot on the sill.
	var pot := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.055
	pm.bottom_radius = 0.045
	pm.height = 0.1
	pot.mesh = pm
	pot.position = Vector3(width * 0.34, 0.04, 0.12)
	pot.material_override = BuildingMaterials.plastic(Color(0.55, 0.28, 0.16))
	add_child(pot)
	var leaf := MeshInstance3D.new()
	var lm2 := SphereMesh.new()
	lm2.radius = 0.08
	lm2.height = 0.16
	leaf.mesh = lm2
	leaf.scale = Vector3(0.8, 1.2, 0.8)
	leaf.position = Vector3(width * 0.34, 0.16, 0.12)
	leaf.material_override = BuildingMaterials.leaf()
	add_child(leaf)
	# Collider across the opening.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.06)
	_collider.shape = shape
	_collider.position = Vector3(0, height * 0.5, 0)
	body.add_child(_collider)


func _sash(hinge: Node3D, extent: float, glass_mat: Material, frame_mat: Material) -> void:
	var pane := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(absf(extent) - 0.03, height - 0.06, 0.025)
	pane.mesh = gm
	pane.position = Vector3(extent * 0.5, height * 0.5, 0)
	pane.material_override = glass_mat
	hinge.add_child(pane)
	var rail := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(absf(extent), 0.035, 0.04)
	rail.mesh = rm
	rail.position = Vector3(extent * 0.5, height * 0.5, 0)
	rail.material_override = frame_mat
	hinge.add_child(rail)
	var handle := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.018
	hm.height = 0.036
	hm.radial_segments = 8
	hm.rings = 4
	handle.mesh = hm
	handle.position = Vector3(extent * 0.82, height * 0.48, -0.035)
	handle.material_override = BuildingMaterials.metal()
	hinge.add_child(handle)


func interact_options(_player: Node) -> Array:
	return [{"id": "toggle", "label": {"bn": "বন্ধ করো" if is_open else "খোলো", "en": "Close" if is_open else "Open"}}]


func display_name() -> Dictionary:
	return label


func interact(_player: Node, _id: String) -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or _left == null:
		return
	is_open = true
	if _collider != null:
		_collider.disabled = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_left, "rotation:y", 1.15, 0.55)
	_tween.tween_property(_right, "rotation:y", -1.15, 0.55)
	AudioEventBus.emit_event("gate_screech", global_position, 28.0)


func close() -> void:
	if not is_open or _left == null:
		return
	is_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_left, "rotation:y", 0.0, 0.45)
	_tween.tween_property(_right, "rotation:y", 0.0, 0.45)
	_tween.chain().tween_callback(func() -> void:
		if _collider != null:
			_collider.disabled = false)


func _process(delta: float) -> void:
	if not auto_open or _left == null:
		return
	var p: Node3D = Services.player
	if p == null or not is_instance_valid(p):
		return
	var d := global_position.distance_to(p.global_position)
	if d < 4.5 and not is_open:
		open()
	elif d > 7.0 and is_open:
		_auto_t += delta
		if _auto_t > 3.0:
			close()
			_auto_t = 0.0
	else:
		_auto_t = 0.0
