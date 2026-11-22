class_name Crowd
extends Node3D
## Background pedestrians for outdoor levels, drawn as two MultiMeshes (bodies and heads).
## Each walks straight lines along open ground cells (pavement, road, lanes), so nobody walks
## through a wall; loud sounds (80 dB and up) send everyone nearby running the other way.
## CPU only, so it works on every renderer. The GPU crowd in CrowdAggregate stays optional.

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const OPEN := [" ", ",", "-", "="]

var _b: LevelBuilder
var _n := 0
var _pos := PackedVector2Array()
var _target := PackedVector2Array()
var _speed := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _panic := PackedFloat32Array()
var _yaw := PackedFloat32Array()
var _bodies: MultiMesh
var _heads: MultiMesh
var _rng := RandomNumberGenerator.new()
var _open: Dictionary = {}
var _cells: Array[Vector2i] = []


func setup(b: LevelBuilder, count: int, seed_value: int) -> void:
	_b = b
	_rng.seed = seed_value * 104729
	for y in b.h:
		for x in b.w:
			if b.at(0, x, y) in OPEN and b.at(1, x, y) == " ":
				var c := Vector2i(x, y)
				_open[c] = true
				_cells.append(c)
	if _cells.is_empty():
		return
	_n = mini(count, 220)
	_pos.resize(_n)
	_target.resize(_n)
	_speed.resize(_n)
	_phase.resize(_n)
	_panic.resize(_n)
	_yaw.resize(_n)
	_bodies = _multimesh(_body_mesh())
	_heads = _multimesh(_head_mesh())
	var shirts := [Color(0.92, 0.92, 0.88), Color(0.55, 0.7, 0.85), Color(0.6, 0.15, 0.18), Color(0.85, 0.7, 0.25),
		Color(0.25, 0.45, 0.3), Color(0.75, 0.55, 0.6), Color(0.35, 0.35, 0.4), Color(0.9, 0.5, 0.2), Color(0.2, 0.3, 0.55)]
	var skins := [Color(0.62, 0.45, 0.32), Color(0.55, 0.38, 0.27), Color(0.47, 0.32, 0.22)]
	for i in _n:
		var c: Vector2i = _cells[_rng.randi_range(0, _cells.size() - 1)]
		_pos[i] = _cell_point(c)
		_target[i] = _pos[i]
		_speed[i] = _rng.randf_range(0.8, 1.5)
		_phase[i] = _rng.randf() * TAU
		_bodies.set_instance_color(i, shirts[_rng.randi_range(0, shirts.size() - 1)])
		_heads.set_instance_color(i, skins[_rng.randi_range(0, skins.size() - 1)])
		_pick_target(i, Vector2.INF)


func panic(pos: Vector3, radius: float) -> void:
	var src := Vector2(pos.x, pos.z)
	for i in _n:
		if _pos[i].distance_to(src) < radius:
			_panic[i] = 6.0
			_pick_target(i, src)


func _process(delta: float) -> void:
	if _n == 0:
		return
	for i in _n:
		var p := _pos[i]
		var to := _target[i] - p
		var spd := _speed[i] * (3.2 if _panic[i] > 0.0 else 1.0)
		if _panic[i] > 0.0:
			_panic[i] -= delta
		if to.length() < 0.15:
			_pick_target(i, Vector2.INF)
			to = _target[i] - p
		if to.length() > 0.001:
			p += to.normalized() * minf(spd * delta, to.length())
			_yaw[i] = lerp_angle(_yaw[i], atan2(-to.x, -to.y), 1.0 - exp(-8.0 * delta))
		_pos[i] = p
		_phase[i] += delta * spd * 5.5
		var bob := absf(sin(_phase[i])) * 0.05
		var basis := Basis(Vector3.UP, _yaw[i])
		var sway := Basis(Vector3.FORWARD, sin(_phase[i]) * 0.04)
		_bodies.set_instance_transform(i, Transform3D(basis * sway, Vector3(p.x, 0.8 + bob, p.y)))
		_heads.set_instance_transform(i, Transform3D(basis, Vector3(p.x, 1.62 + bob, p.y)))


## Walk along one axis while the cells stay open; when fleeing, take the axis that runs away.
func _pick_target(i: int, flee_from: Vector2) -> void:
	var here := Vector2i(int(_pos[i].x / LevelBuilder.C), int(_pos[i].y / LevelBuilder.C))
	if not _open.has(here):
		_pos[i] = _cell_point(_cells[_rng.randi_range(0, _cells.size() - 1)])
		_target[i] = _pos[i]
		return
	var order := DIRS.duplicate()
	if flee_from != Vector2.INF:
		var away := _pos[i] - flee_from
		order.sort_custom(func(a, b): return Vector2(a).dot(away) > Vector2(b).dot(away))
	else:
		order.shuffle()
	for d in order:
		var steps := 0
		var limit := 8 if flee_from != Vector2.INF else _rng.randi_range(2, 7)
		while steps < limit and _open.has(here + d * (steps + 1)):
			steps += 1
		if steps > 0:
			var lateral := Vector2(d.y, d.x) * _rng.randf_range(-0.55, 0.55)
			_target[i] = Vector2((here + d * steps)) * LevelBuilder.C + Vector2.ONE * (LevelBuilder.C * 0.5) + lateral
			return
	_target[i] = _pos[i]


func _cell_point(c: Vector2i) -> Vector2:
	return Vector2(c) * LevelBuilder.C + Vector2(_rng.randf_range(0.4, 1.6), _rng.randf_range(0.4, 1.6))


func _multimesh(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = _n
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mm


func _body_mesh() -> Mesh:
	var m := CapsuleMesh.new()
	m.radius = 0.22
	m.height = 1.5
	m.radial_segments = 8
	m.rings = 3
	m.material = _vertex_colour_mat()
	return m


func _head_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.26
	m.radial_segments = 8
	m.rings = 4
	m.material = _vertex_colour_mat()
	return m


func _vertex_colour_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	return mat
