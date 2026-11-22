class_name Humanoid
extends Node3D
## A body built from primitives and animated in code, so the game needs no imported rig.
## Owners set speed, crouch, aim, talking, pose and look_target; the body blends between
## idle breathing, walk, run, crouch, aim, recoil, talk, sit, cower, flinch, falls and dying.

static var _mats := {}

var height := 1.65
var shirt := Color(0.86, 0.85, 0.80)
var lower := Color(0.22, 0.24, 0.32)
var skin := Color(0.55, 0.38, 0.27)
var outfit := "pants"     # pants, lungi, uniform, panjabi, kameez
var hat := ""             # cap, tupi, helmet, scarf
var armed := false
var face_id := ""          # a face from art/textures/faces (see DhakaMaterials.pick_face)
var hair_color := Color(0.05, 0.045, 0.04)
var hair_style := ""

var speed := 0.0
var crouch := 0.0
var aim := 0.0
var talking := false
var pose := "normal"      # normal, sit, cower, dying, dead
var look_target = null    # Vector3 or null

var j := {}
var _torso: MeshInstance3D
var _t := 0.0
var _phase := 0.0
var _c := 0.0
var _a := 0.0
var _flinch := 0.0
var _flinch_dir := 1.0
var _recoil := 0.0
var _fall := 0.0
var _fall_dir := 1.0
var _look := Vector2.ZERO
var _hip_y := 0.95


static func mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_mats[k] = m
	return _mats[k]


func setup(opts: Dictionary) -> void:
	height = opts.get("height", height)
	shirt = opts.get("shirt", shirt)
	lower = opts.get("lower", lower)
	skin = opts.get("skin", skin)
	outfit = opts.get("outfit", outfit)
	hat = opts.get("hat", hat)
	armed = opts.get("armed", armed)
	face_id = String(opts.get("face", ""))
	if face_id != "":
		var rec := DhakaMaterials.face_record(face_id)
		if not rec.is_empty():
			var sk: Array = rec["skin"]
			var hc: Array = rec["hair"]
			skin = Color(float(sk[0]), float(sk[1]), float(sk[2]))
			hair_color = Color(float(hc[0]), float(hc[1]), float(hc[2]))
			hair_style = String(rec.get("style", ""))
	_build()


func flinch(travel_dir: Vector3) -> void:
	_flinch = 1.0
	var local := global_transform.basis.inverse() * travel_dir
	_flinch_dir = -1.0 if local.x > 0.0 else 1.0


func kick() -> void:
	_recoil = 1.0


func fall(travel_dir: Vector3) -> void:
	# Hit from the front falls backwards (+X rotation tips the head towards +Z).
	var local := global_transform.basis.inverse() * travel_dir
	_fall_dir = 1.0 if local.z > 0.0 else -1.0


func _build() -> void:
	var s := height / 1.65
	_hip_y = 0.95 * s
	var hips := _joint("hips", self, Vector3(0, _hip_y, 0))
	var spine := _joint("spine", hips, Vector3.ZERO)
	_torso = _box(spine, Vector3(0.36, 0.5, 0.2) * s, Vector3(0, 0.29 * s, 0), shirt)
	_box(spine, Vector3(0.34, 0.12, 0.19) * s, Vector3(0, 0.03 * s, 0), lower)
	var neck := _joint("neck", spine, Vector3(0, 0.55 * s, 0))
	_cyl(neck, 0.045 * s, 0.05 * s, 0.08 * s, Vector3(0, 0.02 * s, 0), skin)
	var head := _joint("head", neck, Vector3(0, 0.06 * s, 0))
	var face_mat: Material = DhakaMaterials.face(face_id) if face_id != "" else null
	if face_mat:
		# a smooth head wearing a painted face (eyes, brows, nose, lips, hair) with ears for the silhouette
		var hm := _sphere(head, 0.105 * s, Vector3(0, 0.11 * s, 0), skin, Vector3(0.93, 1.07, 0.98))
		var sm := hm.mesh as SphereMesh
		sm.radial_segments = 32
		sm.rings = 16
		hm.material_override = face_mat
		for side in [-1.0, 1.0]:
			_sphere(head, 0.022 * s, Vector3(0.098 * side * s, 0.105 * s, 0.004 * s), skin.darkened(0.05), Vector3(0.45, 1.25, 0.85))
		if hair_style in ["long_middle", "long_side"]:
			_box(head, Vector3(0.19, 0.26, 0.05) * s, Vector3(0, 0.01 * s, 0.085 * s), hair_color)
		elif hair_style == "bun":
			_sphere(head, 0.045 * s, Vector3(0, 0.16 * s, 0.095 * s), hair_color, Vector3.ONE)
	else:
		_sphere(head, 0.105 * s, Vector3(0, 0.11 * s, 0), skin, Vector3.ONE)
		_sphere(head, 0.108 * s, Vector3(0, 0.14 * s, 0.012 * s), Color(0.07, 0.06, 0.05), Vector3(1.0, 0.62, 1.0))
		_box(head, Vector3(0.12, 0.02, 0.02) * s, Vector3(0, 0.12 * s, -0.098 * s), Color(0.1, 0.08, 0.07))   # brow line
	for side in [-1.0, 1.0]:
		var n := "r" if side > 0.0 else "l"
		var sh := _joint("shoulder_" + n, spine, Vector3(0.215 * side * s, 0.49 * s, 0))
		_cyl(sh, 0.052 * s, 0.048 * s, 0.3 * s, Vector3(0, -0.14 * s, 0), shirt)
		var el := _joint("elbow_" + n, sh, Vector3(0, -0.29 * s, 0))
		_cyl(el, 0.044 * s, 0.038 * s, 0.26 * s, Vector3(0, -0.13 * s, 0), skin)
		_box(el, Vector3(0.07, 0.09, 0.045) * s, Vector3(0, -0.3 * s, 0), skin)
		var hp := _joint("hip_" + n, hips, Vector3(0.1 * side * s, 0, 0))
		_cyl(hp, 0.07 * s, 0.058 * s, 0.44 * s, Vector3(0, -0.22 * s, 0), lower)
		var kn := _joint("knee_" + n, hp, Vector3(0, -0.44 * s, 0))
		_cyl(kn, 0.056 * s, 0.045 * s, 0.44 * s, Vector3(0, -0.22 * s, 0), skin if outfit == "lungi" else lower)
		_box(kn, Vector3(0.09, 0.06, 0.25) * s, Vector3(0, -0.46 * s, -0.05 * s), Color(0.12, 0.1, 0.09))
	match outfit:
		"lungi":
			_cyl(hips, 0.2 * s, 0.25 * s, 0.62 * s, Vector3(0, -0.33 * s, 0), lower)
		"panjabi", "kameez":
			_cyl(spine, 0.2 * s, 0.27 * s, 0.58 * s, Vector3(0, -0.2 * s, 0), shirt)
		"uniform":
			_box(spine, Vector3(0.37, 0.05, 0.21) * s, Vector3(0, 0.08 * s, 0), Color(0.1, 0.08, 0.06))
	match hat:
		"tupi":
			_cyl(head, 0.09 * s, 0.095 * s, 0.06 * s, Vector3(0, 0.21 * s, 0), Color(0.95, 0.95, 0.92))
		"cap":
			_sphere(head, 0.112 * s, Vector3(0, 0.19 * s, 0.005 * s), Color(0.12, 0.13, 0.16), Vector3(1.0, 0.45, 1.0))
			_box(head, Vector3(0.12, 0.012, 0.07) * s, Vector3(0, 0.155 * s, -0.12 * s), Color(0.1, 0.11, 0.14))
		"helmet":
			_sphere(head, 0.125 * s, Vector3(0, 0.15 * s, 0), Color(0.16, 0.18, 0.14), Vector3(1.0, 0.75, 1.05))
		"scarf":
			var orna := _box(spine, Vector3(0.4, 0.08, 0.23) * s, Vector3(0, 0.43 * s, 0), lower.lightened(0.25))
			orna.rotation.z = 0.45
			_sphere(head, 0.118 * s, Vector3(0, 0.13 * s, 0.035 * s), lower.lightened(0.25), Vector3(1.0, 0.95, 0.85))
	if armed:
		_box(j["elbow_r"], Vector3(0.05, 0.24, 0.1) * s, Vector3(0, -0.4 * s, -0.03 * s), Color(0.07, 0.07, 0.08))


func _process(delta: float) -> void:
	if j.is_empty():
		return
	_t += delta
	var k := 1.0 - exp(-delta * 9.0)
	_c = lerpf(_c, 1.0 if pose == "cower" else crouch, k)
	_a = lerpf(_a, aim, k)
	_flinch = move_toward(_flinch, 0.0, delta * 2.5)
	_recoil = move_toward(_recoil, 0.0, delta * 5.0)
	if pose == "dead" or pose == "dying":
		_fall = minf(1.0, _fall + delta * 1.6)
	else:
		_fall = maxf(0.0, _fall - delta * 2.5)
	var s := height / 1.65
	var mv := clampf(speed / 1.4, 0.0, 1.0)
	var run := clampf((speed - 2.2) / 2.3, 0.0, 1.0)
	if speed > 0.05:
		_phase = fmod(_phase + delta * TAU * speed / lerpf(1.3, 1.9, run), TAU)
	var swing := sin(_phase) * (0.45 * mv + 0.3 * run)
	var kl := maxf(0.0, -sin(_phase + 0.6)) * (0.35 + 0.8 * run) * mv
	var kr := maxf(0.0, -sin(_phase + PI + 0.6)) * (0.35 + 0.8 * run) * mv
	j.hip_l.rotation = Vector3(swing + 0.95 * _c, 0, 0)
	j.hip_r.rotation = Vector3(-swing + 0.95 * _c, 0, 0)
	j.knee_l.rotation.x = -kl - 1.7 * _c
	j.knee_r.rotation.x = -kr - 1.7 * _c
	j.hips.position = Vector3(0.012 * sin(_t * 0.6) * (1.0 - mv), _hip_y - 0.36 * s * _c + 0.025 * mv * cos(2.0 * _phase), 0)
	j.hips.rotation = Vector3.ZERO
	j.spine.rotation = Vector3(-(0.1 * run + 0.3 * _c) + 0.12 * _flinch, 0.35 * _flinch * _flinch_dir + 0.06 * swing * (1.0 - _a), 0)
	_torso.scale.y = 1.0 + 0.015 * sin(_t * 1.7) * (1.0 - mv)
	var arm := -swing * 0.75 * (1.0 - _a)
	j.shoulder_l.rotation = Vector3(arm + 0.05 + 0.03 * sin(_t * 0.9), 0, -0.08)
	j.shoulder_r.rotation = Vector3(-arm + 0.05 + 0.03 * sin(_t * 0.9 + 1.0), 0, 0.08)
	j.elbow_l.rotation.x = 0.15 + 0.7 * run
	j.elbow_r.rotation.x = 0.15 + 0.7 * run
	if _a > 0.01:
		j.shoulder_r.rotation.x = lerpf(j.shoulder_r.rotation.x, 1.45 + 0.3 * _recoil, _a)
		j.shoulder_r.rotation.y = lerpf(0.0, -0.12, _a)
		j.elbow_r.rotation.x = lerpf(j.elbow_r.rotation.x, 0.08, _a)
		j.shoulder_l.rotation.x = lerpf(j.shoulder_l.rotation.x, 1.25, _a)
		j.shoulder_l.rotation.z = lerpf(-0.08, 0.5, _a)
		j.elbow_l.rotation.x = lerpf(j.elbow_l.rotation.x, 0.65, _a)
	elif _recoil > 0.0:
		j.shoulder_r.rotation.x += 1.2 * _recoil   # a punch or a shove
		j.elbow_r.rotation.x += 0.4 * _recoil
	if talking and _a < 0.5:
		j.shoulder_r.rotation.x += 0.35 + 0.15 * sin(_t * 3.1)
		j.elbow_r.rotation.x += 0.8 + 0.3 * sin(_t * 2.3)
		j.shoulder_l.rotation.x += 0.1 + 0.08 * sin(_t * 2.0 + 1.3)
	match pose:
		"sit":
			j.hips.position.y = 0.5 * s
			j.hip_l.rotation.x = 1.5
			j.hip_r.rotation.x = 1.5
			j.knee_l.rotation.x = -1.5
			j.knee_r.rotation.x = -1.5
			j.shoulder_l.rotation.x = 0.5
			j.shoulder_r.rotation.x = 0.5 if not talking else j.shoulder_r.rotation.x
			j.elbow_l.rotation.x = 0.9
		"cower":
			j.shoulder_l.rotation = Vector3(2.7, 0, -0.5)
			j.shoulder_r.rotation = Vector3(2.7, 0, 0.5)
			j.elbow_l.rotation.x = 1.9
			j.elbow_r.rotation.x = 1.9
	var want := Vector2.ZERO
	if look_target != null and _fall < 0.5:
		var d: Vector3 = (look_target as Vector3) - (j.head as Node3D).global_position
		var local := global_transform.basis.inverse() * d
		var flat := Vector2(local.x, local.z).length()
		want = Vector2(clampf(atan2(-local.x, -local.z), -1.1, 1.1), clampf(atan2(local.y, flat), -0.5, 0.5))
	_look = _look.lerp(want, 1.0 - exp(-delta * 5.0))
	j.neck.rotation = Vector3(_look.y * 0.4, _look.x * 0.4, 0)
	j.head.rotation = Vector3(_look.y * 0.6 + (0.06 * sin(_t * 2.7) if talking else 0.0), _look.x * 0.6, 0)
	if _fall > 0.0:
		var e := _fall * _fall * (3.0 - 2.0 * _fall)
		rotation.x = _fall_dir * PI * 0.5 * e
		position.y = 0.13 * e
		j.shoulder_l.rotation.z -= 0.9 * e
		j.shoulder_r.rotation.z += 0.9 * e
		j.hip_l.rotation.z = -0.15 * e
		j.hip_r.rotation.z = 0.15 * e
		if pose == "dying":
			j.shoulder_r.rotation.x = lerpf(j.shoulder_r.rotation.x, 1.1, e)
			j.elbow_r.rotation.x = lerpf(j.elbow_r.rotation.x, 1.9, e)
			_torso.scale.y = 1.0 + 0.04 * sin(_t * 4.0) * e
	else:
		rotation.x = 0.0
		position.y = 0.0


func _joint(n: String, parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pos
	parent.add_child(p)
	j[n] = p
	return p


func _mesh(parent: Node3D, m: Mesh, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(parent, m, pos, c)


func _sphere(parent: Node3D, r: float, pos: Vector3, c: Color, sc: Vector3) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 8
	var mi := _mesh(parent, m, pos, c)
	mi.scale = sc
	return mi


func _cyl(parent: Node3D, top: float, bottom: float, hh: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = hh
	m.radial_segments = 10
	return _mesh(parent, m, pos, c)
