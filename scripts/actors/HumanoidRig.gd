class_name HumanoidRig
extends Node3D
## A whole person built in code: a Skeleton3D with 19 bones and one continuous skinned body (torso,
## arms, hands, legs, feet lofted as smooth rings with blended bone weights at every joint, so elbows
## and knees bend without gaps), clothes as separate skinned shells (shirt, panjabi, kameez and
## salwar, lungi, trousers, uniform, orna), the painted face from art/textures/faces on the head, and
## hair. Animation is procedural: walk and run cycles, idle breathing, talking gestures, aiming,
## crouching, sitting, kneeling (dying), lying dead, cowering, punching, phoning, driving and the
## ghost float, all blended per bone.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

enum B { HIPS, SPINE, CHEST, NECK, HEAD, SHOULDER_L, ARM_L, FOREARM_L, HAND_L, SHOULDER_R, ARM_R, FOREARM_R, HAND_R,
	THIGH_L, SHIN_L, FOOT_L, THIGH_R, SHIN_R, FOOT_R }
const BONE_NAMES := ["hips", "spine", "chest", "neck", "head", "shoulder_l", "arm_l", "forearm_l", "hand_l",
	"shoulder_r", "arm_r", "forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const PARENTS := [-1, 0, 1, 2, 3, 2, 5, 6, 7, 2, 9, 10, 11, 0, 13, 14, 0, 16, 17]
const RING := 10

static var _mesh_cache: Dictionary = {}

var look: Dictionary = {}
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var scale_h := 1.0
var _rest: Array[Vector3] = []
var _cur: Array[Quaternion] = []
var _tgt: Array[Quaternion] = []
var _phase := 0.0
var _gesture := ""
var _gesture_t := 0.0
var _look_target := Vector3.INF
var _hip_drop := 0.0
var _hip_drop_tgt := 0.0
var _lie := 0.0
var _lie_tgt := 0.0
var _ghost := false
var _materials: Array[Material] = []


## look: {gender: "m"/"f", height (m), build: "thin"/"average"/"heavy", skin: Color, face: id, hair: Color,
##        hair_style, outfit: "lungi_shirt"|"panjabi"|"shirt_trousers"|"kameez"|"saree"|"uniform"|"guard"|"student"|"goon",
##        shirt: Color, lower: Color, cloth: texture set name or "", cap: bool, glasses: bool}
func build(l: Dictionary) -> void:
	look = l
	scale_h = float(look.get("height", 1.68)) / 1.7
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	_make_bones()
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "Body"
	skeleton.add_child(body_mesh)
	body_mesh.mesh = _get_mesh()
	body_mesh.skeleton = NodePath("..")
	body_mesh.skin = skeleton.create_skin_from_rest_transforms()
	_apply_materials()
	_make_head()
	for i in BONE_NAMES.size():
		_cur.append(Quaternion.IDENTITY)
		_tgt.append(Quaternion.IDENTITY)


func _make_bones() -> void:
	var s := scale_h
	var female := String(look.get("gender", "m")) == "f"
	var sh := 0.2 if not female else 0.18
	var offs := [Vector3(0, 0.95, 0), Vector3(0, 0.12, 0), Vector3(0, 0.2, 0), Vector3(0, 0.22, 0), Vector3(0, 0.1, 0),
		Vector3(-sh * 0.25, 0.17, 0), Vector3(-sh * 0.75, -0.02, 0), Vector3(0, -0.28, 0), Vector3(0, -0.25, 0),
		Vector3(sh * 0.25, 0.17, 0), Vector3(sh * 0.75, -0.02, 0), Vector3(0, -0.28, 0), Vector3(0, -0.25, 0),
		Vector3(-0.095, -0.06, 0), Vector3(0, -0.42, 0), Vector3(0, -0.41, 0),
		Vector3(0.095, -0.06, 0), Vector3(0, -0.42, 0), Vector3(0, -0.41, 0)]
	for i in BONE_NAMES.size():
		var idx := skeleton.add_bone(BONE_NAMES[i])
		var off: Vector3 = offs[i] * s
		_rest.append(off)
		if int(PARENTS[i]) >= 0:
			skeleton.set_bone_parent(idx, int(PARENTS[i]))
		skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, off))
	skeleton.reset_bone_poses()


## Global rest position of a bone (I-pose).
func _gpos(i: int) -> Vector3:
	var p := Vector3.ZERO
	var b := i
	while b >= 0:
		p += _rest[b]
		b = int(PARENTS[b])
	return p


# =============================================================================================
# Mesh: lofted rings with bone weights
# =============================================================================================

func _mesh_key() -> String:
	return "%s|%s|%.2f|%s" % [String(look.get("gender", "m")), String(look.get("build", "average")), scale_h, String(look.get("outfit", "lungi_shirt"))]


func _get_mesh() -> ArrayMesh:
	var key := _mesh_key()
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var am := ArrayMesh.new()
	var female := String(look.get("gender", "m")) == "f"
	var bscale := 1.0
	match String(look.get("build", "average")):
		"thin":
			bscale = 0.88
		"heavy":
			bscale = 1.2
	var outfit := String(look.get("outfit", "lungi_shirt"))
	# surface 0: skin (whole body)
	_add_surface(am, _body_rings(female, bscale, 0.0, "skin"))
	# clothes
	match outfit:
		"lungi_shirt":
			_add_surface(am, _body_rings(female, bscale, 0.012, "shirt_short"))
			_add_surface(am, _skirt(female, bscale, 1.0, 0.12, 0.2))
		"panjabi":
			_add_surface(am, _body_rings(female, bscale, 0.014, "shirt_long"))
			_add_surface(am, _skirt(female, bscale, 1.0, 0.52, 0.06))
			_add_surface(am, _body_rings(female, bscale, 0.008, "trousers"))
		"kameez":
			_add_surface(am, _body_rings(female, bscale, 0.012, "shirt_long"))
			_add_surface(am, _skirt(female, bscale, 1.0, 0.5, 0.08))
			_add_surface(am, _body_rings(female, bscale, 0.014, "trousers"))
		"saree":
			_add_surface(am, _body_rings(female, bscale, 0.012, "shirt_short"))
			_add_surface(am, _skirt(female, bscale, 1.02, 0.08, 0.16))
			_add_surface(am, _sash(female, bscale))
		_:
			# shirt_trousers, uniform, guard, student, goon
			_add_surface(am, _body_rings(female, bscale, 0.012, "shirt_long" if outfit in ["uniform", "guard"] else "shirt_mid"))
			_add_surface(am, _body_rings(female, bscale, 0.01, "trousers"))
	_mesh_cache[key] = am
	return am


## Each part: Array of rings; each ring = [center, ex, ey, rx, ry, bones[4], weights[4], v]
func _body_rings(female: bool, b: float, grow: float, part: String) -> Array:
	var parts: Array = []
	var s := scale_h
	var hw := 1.12 if female else 1.0          # hip width
	var ww := 0.86 if female else 1.0          # waist
	var cw := 0.94 if female else 1.0          # chest width
	var belly := 0.03 if String(look.get("build", "")) == "heavy" else 0.0
	var X := Vector3(1, 0, 0)
	var Z := Vector3(0, 0, 1)
	var Y := Vector3(0, 1, 0)
	if part in ["skin", "shirt_short", "shirt_long", "shirt_mid"]:
		# anatomical cross-sections: [height, half-width, half-depth, forward(-)/back(+) offset, bone a, bone b, blend]
		var torso: Array
		if female:
			torso = [
				[0.79, 0.165, 0.115, 0.015, B.HIPS, B.HIPS, 0.0],
				[0.86, 0.188, 0.135, 0.028, B.HIPS, B.HIPS, 0.0],       # hips and glutes
				[0.93, 0.182, 0.125, 0.018, B.HIPS, B.HIPS, 0.0],
				[1.0, 0.156, 0.11, 0.0, B.HIPS, B.SPINE, 0.3],
				[1.07, 0.126, 0.095, -0.004, B.SPINE, B.SPINE, 0.0],    # narrow waist
				[1.15, 0.13, 0.1, -0.006, B.SPINE, B.SPINE, 0.0],
				[1.23, 0.143, 0.108, -0.012, B.SPINE, B.CHEST, 0.5],
				[1.29, 0.155, 0.13 + belly * 0.3, -0.034, B.CHEST, B.CHEST, 0.0],   # bust
				[1.35, 0.158, 0.126, -0.03, B.CHEST, B.CHEST, 0.0],
				[1.41, 0.156, 0.1, -0.006, B.CHEST, B.CHEST, 0.0],
				[1.46, 0.152, 0.088, 0.0, B.CHEST, B.CHEST, 0.0],
				[1.5, 0.094, 0.07, 0.006, B.CHEST, B.NECK, 0.35],       # trapezius slope
			]
		else:
			torso = [
				[0.79, 0.15, 0.108, 0.01, B.HIPS, B.HIPS, 0.0],
				[0.86, 0.163, 0.122, 0.018, B.HIPS, B.HIPS, 0.0],       # hips and glutes
				[0.93, 0.163, 0.118, 0.01, B.HIPS, B.HIPS, 0.0],
				[1.0, 0.152, 0.11 + belly * 0.5, -0.002 - belly * 0.4, B.HIPS, B.SPINE, 0.3],
				[1.07, 0.14, 0.103 + belly, -0.006 - belly * 0.6, B.SPINE, B.SPINE, 0.0],   # waist
				[1.15, 0.143, 0.106 + belly, -0.008 - belly * 0.5, B.SPINE, B.SPINE, 0.0],
				[1.24, 0.158, 0.114, -0.012, B.SPINE, B.CHEST, 0.5],    # lower ribs
				[1.32, 0.174, 0.122, -0.018, B.CHEST, B.CHEST, 0.0],    # pectorals
				[1.39, 0.184, 0.117, -0.012, B.CHEST, B.CHEST, 0.0],    # chest at the armpits
				[1.45, 0.178, 0.097, 0.0, B.CHEST, B.CHEST, 0.0],       # shoulder line
				[1.5, 0.112, 0.077, 0.006, B.CHEST, B.NECK, 0.35],      # trapezius slope
			]
		if part == "skin":
			torso.append([1.55, 0.054 if not female else 0.046, 0.054 if not female else 0.046, 0.0, B.NECK, B.NECK, 0.0])
			torso.append([1.62, 0.048 if not female else 0.042, 0.05 if not female else 0.044, 0.004, B.NECK, B.HEAD, 0.5])
		var rings: Array = []
		var v := 0.0
		for t in torso:
			var rx := float(t[1]) * b + grow
			var rz := float(t[2]) * b + grow
			if part == "shirt_short" and float(t[0]) < 0.9:
				continue
			rings.append(_ring(Vector3(0, float(t[0]) * s, float(t[3]) * s), X, Z, rx, rz, int(t[4]), int(t[5]), float(t[6]), v))
			v += 0.11
		parts.append(rings)
		# arms
		var sleeve := {"skin": 1.0, "shirt_short": 0.45, "shirt_mid": 0.95, "shirt_long": 1.9}
		var reach := float(sleeve.get(part, 1.0))
		for side in [-1.0, 1.0]:
			var arm := B.ARM_L if side < 0.0 else B.ARM_R
			var fore := B.FOREARM_L if side < 0.0 else B.FOREARM_R
			var hand := B.HAND_L if side < 0.0 else B.HAND_R
			var top := _gpos(arm)
			var elbow := _gpos(fore)
			var wrist := _gpos(hand)
			var ar: Array = []
			var av := 0.0
			var nseg := 6
			for k in nseg + 1:
				var t := float(k) / nseg
				if part != "skin" and t > reach:
					break
				var c := top.lerp(elbow, t)
				# deltoid cap, biceps belly, slimmer above the elbow (women: slimmer overall)
				var arm_r := 0.06 - 0.016 * t + 0.006 * sin(t * PI) * (0.6 if female else 1.0)
				var r := arm_r * (0.86 if female else 1.0) * b + grow
				var w2 := smoothstep(0.75, 1.0, t) * 0.5
				ar.append(_ring(c, X, Z, r, r * 0.92, arm, fore, w2, av))
				av += 0.05
			if part == "skin" or reach > 1.0:
				for k in range(1, nseg + 1):
					var t := float(k) / nseg
					if part != "skin" and t > reach - 1.0:
						break
					var c := elbow.lerp(wrist, t)
					# forearm muscles near the elbow, tapering to the wrist
					var fore_r := 0.043 + 0.004 * sin(clampf(t * 1.6, 0.0, 1.0) * PI) - 0.014 * t
					var r := fore_r * (0.86 if female else 1.0) * b + grow
					var w1 := (1.0 - smoothstep(0.0, 0.25, t)) * 0.5
					ar.append(_ring(c, X, Z, r, r * 0.85, fore, arm, w1, av))
					av += 0.05
				if part == "skin":
					# hand: a mitten
					var hp := [[0.0, 0.03, 0.022], [0.05, 0.042, 0.018], [0.12, 0.04, 0.016], [0.17, 0.028, 0.013]]
					for hk in hp:
						var c := wrist + Vector3(0, -float(hk[0]) * s, 0)
						ar.append(_ring(c, Z, X, float(hk[1]) * s, float(hk[2]) * s, hand, hand, 0.0, av))
						av += 0.04
			parts.append(ar)
	if part in ["skin", "trousers"]:
		for side in [-1.0, 1.0]:
			var thigh := B.THIGH_L if side < 0.0 else B.THIGH_R
			var shin := B.SHIN_L if side < 0.0 else B.SHIN_R
			var foot := B.FOOT_L if side < 0.0 else B.FOOT_R
			var hip := _gpos(thigh)
			var knee := _gpos(shin)
			var ankle := _gpos(foot)
			var lr: Array = []
			var lv := 0.0
			var nseg := 7
			for k in nseg + 1:
				var t := float(k) / nseg
				var c := hip.lerp(knee, t)
				# thigh: full at the top (fuller for women), slimming to the knee
				var r := lerpf(0.088 * hw * (1.04 if female else 1.0), 0.054, t * t * 0.6 + t * 0.4) * b + grow
				if part == "trousers":
					r = maxf(r, 0.07) + 0.01
				lr.append(_ring(c + Vector3(0, 0, -0.008 * sin(t * PI) * s), X, Z, r, r * 0.95, thigh, shin, smoothstep(0.75, 1.0, t) * 0.5, lv))
				lv += 0.06
			for k in range(1, nseg + 1):
				var t := float(k) / nseg
				var c := knee.lerp(ankle + Vector3(0, 0.03 * s, 0), t)
				# calf belly in the upper third (behind the shin), slim ankle
				var calf := 0.05 + 0.012 * sin(clampf(t * 1.8, 0.0, 1.0) * PI) * (0.8 if female else 1.0) - 0.018 * t
				var r := calf * b + grow
				if part == "trousers":
					r = maxf(r, 0.06) + 0.008
				lr.append(_ring(c + Vector3(0, 0, 0.012 * sin(clampf(t * 1.8, 0.0, 1.0) * PI) * s), X, Z, r, r * 0.92, shin, thigh, (1.0 - smoothstep(0.0, 0.25, t)) * 0.5, lv))
				lv += 0.06
			parts.append(lr)
			if part == "skin":
				# foot: lofted forward (-Z) from heel to toe, weighted to the foot bone
				var fr: Array = []
				var fp := [[0.05, 0.03, 0.032, 0.03], [0.0, 0.045, 0.038, 0.035], [-0.08, 0.044, 0.03, 0.02], [-0.16, 0.036, 0.016, 0.014]]
				var fv := 0.0
				for fk in fp:
					var c := ankle + Vector3(0, -float(fk[3]) * s * 0.8, float(fk[0]) * s)
					fr.append(_ring(c, X, Y, float(fk[1]) * s, float(fk[2]) * s, foot, foot, 0.0, fv))
					fv += 0.05
				parts.append(fr)
	return parts


## A skirt-like tube from the waist to `bottom` (fraction of height), flaring by `flare`. Weighted to
## hips at the top and shared between the thighs lower down, so it swings with the legs.
func _skirt(female: bool, b: float, top_y: float, bottom_y: float, flare: float) -> Array:
	var s := scale_h
	var hw := 1.12 if female else 1.0
	var rings: Array = []
	var n := 7
	var v := 0.0
	for k in n + 1:
		var t := float(k) / n
		var y := lerpf(top_y, bottom_y, t) * s
		var rx := (lerpf(0.165 * hw, 0.2 * hw + flare, t)) * b + 0.012
		var rz := (lerpf(0.118, 0.15 + flare * 0.6, t)) * b + 0.012
		rings.append(["skirt", Vector3(0, y, 0), rx, rz, t, v])
		v += 0.12
	return [rings]


## Saree pallu / orna: a band from the left hip over the right shoulder, weighted to the chest.
func _sash(female: bool, b: float) -> Array:
	var s := scale_h
	var rings: Array = []
	var pts := [Vector3(-0.14, 0.98, -0.12), Vector3(-0.05, 1.2, -0.13), Vector3(0.08, 1.4, -0.12), Vector3(0.15, 1.5, -0.02),
		Vector3(0.14, 1.46, 0.1), Vector3(0.1, 1.2, 0.13)]
	var v := 0.0
	for i in pts.size():
		var p: Vector3 = pts[i] * s
		p.x *= b
		rings.append(_ring(p, Vector3(1, 0, 0).rotated(Vector3.UP, 0.3), Vector3(0, 0, 1), 0.07 * s, 0.012, B.CHEST, B.SPINE, 0.3 if i < 2 else 0.0, v))
		v += 0.15
	return [rings]


func _ring(c: Vector3, ex: Vector3, ey: Vector3, rx: float, ry: float, b0: int, b1: int, w1: float, v: float) -> Array:
	return [c, ex, ey, rx, ry, b0, b1, w1, v]


func _add_surface(am: ArrayMesh, parts: Array) -> void:
	var st := SurfaceTool.new()
	# The skin weight count must be configured before begin(): Godot locks the vertex format once
	# the SurfaceTool has started, and calling it afterwards raises "Condition 'begun' is true".
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos: Array = []      # plain Arrays: shared by reference with the emit helpers
	var nrm: Array = []
	for rings in parts:
		var ra: Array = rings
		if ra.size() < 2:
			continue
		var part_start := pos.size()
		for r in ra:
			var rr: Array = r
			if typeof(rr[0]) == TYPE_STRING:
				_emit_skirt_ring(st, rr, pos, nrm)
			else:
				_emit_ring(st, rr, pos, nrm)
		var nrings := ra.size()
		for i in nrings - 1:
			for k in RING:
				var a := part_start + i * (RING + 1) + k
				var bb := a + RING + 1
				_tri(st, pos, nrm, a, bb, a + 1)
				_tri(st, pos, nrm, a + 1, bb, bb + 1)
		# caps (skirts stay open at the hem)
		for end in [0, nrings - 1]:
			var r: Array = ra[end]
			var skirt := typeof(r[0]) == TYPE_STRING
			if skirt and end == nrings - 1:
				continue
			var centre: Vector3 = r[1] if skirt else r[0]
			var other: Array = ra[1] if end == 0 else ra[nrings - 2]
			var other_c: Vector3 = other[1] if skirt else other[0]
			var out_n := (centre - other_c).normalized()
			if skirt:
				st.set_bones(PackedInt32Array([B.HIPS, 0, 0, 0]))
				st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			else:
				st.set_bones(PackedInt32Array([int(r[5]), int(r[6]), 0, 0]))
				st.set_weights(PackedFloat32Array([1.0 - float(r[7]), float(r[7]), 0.0, 0.0]))
			st.set_normal(out_n)
			st.set_uv(Vector2(0.5, 0.0))
			st.add_vertex(centre)
			var ci := pos.size()
			pos.append(centre)
			nrm.append(out_n)
			var ring_start: int = part_start + end
			for k in RING:
				_tri(st, pos, nrm, ci, ring_start + k, ring_start + k + 1)
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())


## Adds a triangle wound clockwise as seen from outside (Godot's front face), judged by the
## outward vertex normals, so every loft direction (up the torso, down the arms) comes out right.
func _tri(st: SurfaceTool, pos: Array, nrm: Array, i0: int, i1: int, i2: int) -> void:
	var p0: Vector3 = pos[i0]
	var p1: Vector3 = pos[i1]
	var p2: Vector3 = pos[i2]
	var c := (p1 - p0).cross(p2 - p0)
	var outward: Vector3 = nrm[i0] + nrm[i1] + nrm[i2]
	if c.dot(outward) < 0.0:
		st.add_index(i0)
		st.add_index(i1)
		st.add_index(i2)
	else:
		st.add_index(i0)
		st.add_index(i2)
		st.add_index(i1)


func _emit_ring(st: SurfaceTool, r: Array, pos: Array, nrm: Array) -> int:
	var c: Vector3 = r[0]
	var ex: Vector3 = r[1]
	var ey: Vector3 = r[2]
	var rx := float(r[3])
	var ry := float(r[4])
	var bones := PackedInt32Array([int(r[5]), int(r[6]), 0, 0])
	var w1 := float(r[7])
	var weights := PackedFloat32Array([1.0 - w1, w1, 0.0, 0.0])
	for k in RING + 1:
		var a := TAU * float(k) / RING
		var dir := ex * cos(a) * rx + ey * sin(a) * ry
		st.set_bones(bones)
		st.set_weights(weights)
		var nn := (ex * cos(a) / maxf(rx, 0.001) + ey * sin(a) / maxf(ry, 0.001)).normalized()
		st.set_uv(Vector2(float(k) / RING, float(r[8])))
		st.set_normal(nn)
		st.add_vertex(c + dir)
		pos.append(c + dir)
		nrm.append(nn)
	return RING + 1


func _emit_skirt_ring(st: SurfaceTool, r: Array, pos: Array, nrm: Array) -> int:
	var c: Vector3 = r[1]
	var rx := float(r[2])
	var rz := float(r[3])
	var t := float(r[4])
	for k in RING + 1:
		var a := TAU * float(k) / RING
		var x := cos(a) * rx
		var z := sin(a) * rz
		var leg := t * 0.7
		var left := clampf(0.5 - x / (2.0 * rx), 0.0, 1.0)
		st.set_bones(PackedInt32Array([B.HIPS, B.THIGH_L, B.THIGH_R, 0]))
		st.set_weights(PackedFloat32Array([1.0 - leg, leg * left, leg * (1.0 - left), 0.0]))
		st.set_uv(Vector2(float(k) / RING, float(r[5])))
		st.set_normal(Vector3(cos(a), 0.0, sin(a)))
		st.add_vertex(c + Vector3(x, 0, z))
		pos.append(c + Vector3(x, 0, z))
		nrm.append(Vector3(cos(a), 0.0, sin(a)))
	return RING + 1


# =============================================================================================
# Materials, head, hair
# =============================================================================================

func _apply_materials() -> void:
	var skin_col: Color = look.get("skin", Color(0.62, 0.45, 0.33))
	var skin := StandardMaterial3D.new()
	skin.albedo_color = skin_col
	skin.roughness = 0.62
	skin.subsurf_scatter_enabled = true
	skin.subsurf_scatter_strength = 0.25
	skin.subsurf_scatter_skin_mode = true
	_materials.append(skin)
	var outfit := String(look.get("outfit", "lungi_shirt"))
	var shirt_col: Color = look.get("shirt", Color(0.9, 0.9, 0.88))
	var lower_col: Color = look.get("lower", Color(0.2, 0.3, 0.55))
	var cloth := String(look.get("cloth", ""))
	var lower_cloth := String(look.get("lower_cloth", ""))
	var mats: Array[Material] = [skin]
	match outfit:
		"lungi_shirt":
			mats.append(_cloth_mat(cloth, shirt_col))
			mats.append(_cloth_mat(lower_cloth if lower_cloth != "" else "lungi_check_blue", lower_col))
		"panjabi":
			var pm := _cloth_mat(cloth if cloth != "" else "panjabi_white", shirt_col)
			mats.append(pm)
			mats.append(pm)
			mats.append(_cloth_mat("", lower_col))
		"kameez":
			var km := _cloth_mat(cloth if cloth != "" else "kameez_print_rose", shirt_col)
			mats.append(km)
			mats.append(km)
			mats.append(_cloth_mat("", lower_col))
		"saree":
			var sm := _cloth_mat(cloth, shirt_col)
			mats.append(_cloth_mat("", lower_col.darkened(0.2)))
			mats.append(sm)
			mats.append(sm)
		_:
			mats.append(_cloth_mat(cloth, shirt_col))
			mats.append(_cloth_mat("", lower_col))
	for i in body_mesh.mesh.get_surface_count():
		body_mesh.set_surface_override_material(i, mats[mini(i, mats.size() - 1)])
	_materials = mats


func _cloth_mat(set_name: String, tint: Color) -> Material:
	if set_name != "" and DhakaMaterials.has_textures():
		var m: Material = DhakaMaterials.cloth(set_name, Vector3(1.6, 2.6, 1.0))
		if m is BaseMaterial3D:
			var dup := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			dup.albedo_color = tint.lightened(0.15)
			return dup
		return m
	var p := StandardMaterial3D.new()
	p.albedo_color = tint
	p.roughness = 0.85
	return p


func _make_head() -> void:
	var s := scale_h
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	skeleton.add_child(att)
	head_mesh = MeshInstance3D.new()
	var face_id := String(look.get("face", ""))
	var female := String(look.get("gender", "m")) == "f"
	var rec := DhakaMaterials.face_record(face_id)
	var age := int(rec.get("age", 30)) if not rec.is_empty() else 30
	# a sculpted head (nose, brow, sockets, cheekbones, lips, chin) wearing the painted face
	head_mesh.mesh = HeadSculpt.mesh(face_id, female, age)
	var hs := 0.105 * s
	head_mesh.scale = Vector3(0.88, 1.07, 0.98) * hs
	head_mesh.position = Vector3(0, 0.1 * s, 0.005 * s)
	var fm: Material = DhakaMaterials.face(face_id) if face_id != "" else null
	if fm == null:
		var p := StandardMaterial3D.new()
		p.albedo_color = look.get("skin", Color(0.62, 0.45, 0.33))
		fm = p
	head_mesh.material_override = fm
	att.add_child(head_mesh)
	# glossy corneas over the painted eyes: they catch the light like real eyes
	var cornea := StandardMaterial3D.new()
	cornea.albedo_color = Color(1, 1, 1, 0.06)
	cornea.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cornea.roughness = 0.02
	cornea.metallic_specular = 1.0
	cornea.clearcoat_enabled = true
	cornea.clearcoat = 1.0
	cornea.clearcoat_roughness = 0.02
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.1
		em.height = 0.2
		em.radial_segments = 12
		em.rings = 8
		eye.mesh = em
		eye.material_override = cornea
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.position = HeadSculpt.eye_position(side, female) * Vector3(0.88, 1.07, 0.98) * hs + head_mesh.position
		eye.scale = Vector3(0.93, 0.8, 0.6) * hs
		# iris: a coloured disc visible through the transparent cornea
		var iris_col := Color(0.42, 0.24, 0.12)   # warm brown, typical South Asian iris
		var im := MeshInstance3D.new()
		var ism := SphereMesh.new()
		ism.radius = 0.064
		ism.height = 0.018
		ism.radial_segments = 16
		ism.rings = 4
		im.mesh = ism
		im.scale = Vector3(1.0, 1.0, 0.18) * hs
		var imat := StandardMaterial3D.new()
		imat.albedo_color = iris_col
		imat.roughness = 0.95
		im.material_override = imat
		im.position = Vector3(0, 0, -0.010 * s)   # just toward the viewer from the cornea centre
		im.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(im)
		# pupil: a black dot at the centre of the iris
		var pu := MeshInstance3D.new()
		var psm := SphereMesh.new()
		psm.radius = 0.027
		psm.height = 0.018
		psm.radial_segments = 12
		psm.rings = 4
		pu.mesh = psm
		pu.scale = Vector3(1.0, 1.0, 0.18) * hs
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.04, 0.04, 0.05)
		pmat.roughness = 1.0
		pu.material_override = pmat
		pu.position = Vector3(0, 0, -0.012 * s)   # in front of the iris
		pu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(pu)
		att.add_child(eye)
	var skin_col: Color = look.get("skin", Color(0.62, 0.45, 0.33))
	var ear_mat := StandardMaterial3D.new()
	ear_mat.albedo_color = skin_col.darkened(0.05)
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.022 * s
		es.height = 0.044 * s
		ear.mesh = es
		ear.scale = Vector3(0.45, 1.25, 0.85)
		ear.position = Vector3(0.098 * side * s, 0.1 * s, 0.004 * s)
		ear.material_override = ear_mat
		att.add_child(ear)
	var hair_col: Color = look.get("hair", Color(0.05, 0.04, 0.04))
	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = hair_col
	hair_mat.roughness = 0.55
	var style := String(look.get("hair_style", "short"))
	if style in ["long_middle", "long_side"]:
		var hb := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.19, 0.3, 0.05) * s
		hb.mesh = bm
		hb.position = Vector3(0, 0.02 * s, 0.085 * s)
		hb.material_override = hair_mat
		att.add_child(hb)
	elif style in ["bun", "bun_flowers"]:
		var bun := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.045 * s
		bs.height = 0.09 * s
		bun.mesh = bs
		bun.position = Vector3(0, 0.16 * s, 0.095 * s)
		bun.material_override = hair_mat
		att.add_child(bun)
		if style == "bun_flowers":
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = Color(0.96, 0.95, 0.9)
			fmat.roughness = 0.7
			for k in 12:
				var a := TAU * float(k) / 12.0
				var fl := MeshInstance3D.new()
				var fs := SphereMesh.new()
				fs.radius = 0.008 * s
				fs.height = 0.016 * s
				fl.mesh = fs
				fl.material_override = fmat
				fl.position = bun.position + Vector3(cos(a) * 0.048 * s, sin(a) * 0.04 * s, 0.015 * s)
				att.add_child(fl)
	elif style == "curly":
		# volume of tight curls over the crown
		var cap := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 0.5
		cs.height = 1.0
		cs.is_hemisphere = true
		cap.mesh = cs
		cap.scale = Vector3(0.2, 0.09, 0.215) * s
		cap.position = Vector3(0, 0.155 * s, 0.012 * s)
		var cmat2 := hair_mat.duplicate() as StandardMaterial3D
		cmat2.roughness = 0.85
		cap.material_override = cmat2
		att.add_child(cap)
	# earrings from the face record: gold hoops, jhumka bells or studs
	var ear_kind := String(rec.get("earrings", "")) if not rec.is_empty() else ""
	if ear_kind != "":
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(0.95, 0.75, 0.32) if ear_kind != "stud" else Color(0.95, 0.94, 0.9)
		gold.metallic = 1.0 if ear_kind != "stud" else 0.1
		gold.roughness = 0.25
		for side in [-1.0, 1.0]:
			var er := MeshInstance3D.new()
			match ear_kind:
				"gold_hoop":
					var tm := TorusMesh.new()
					tm.inner_radius = 0.009 * s
					tm.outer_radius = 0.012 * s
					er.mesh = tm
					er.rotation = Vector3(0, 0, PI * 0.5)
					er.position = Vector3(0.1 * side * s, 0.06 * s, 0.006 * s)
				"jhumka":
					var jm := CylinderMesh.new()
					jm.top_radius = 0.003 * s
					jm.bottom_radius = 0.011 * s
					jm.height = 0.022 * s
					er.mesh = jm
					er.position = Vector3(0.1 * side * s, 0.058 * s, 0.006 * s)
				_:
					var sm2 := SphereMesh.new()
					sm2.radius = 0.004 * s
					sm2.height = 0.008 * s
					er.mesh = sm2
					er.position = Vector3(0.101 * side * s, 0.075 * s, 0.006 * s)
			er.material_override = gold
			er.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			att.add_child(er)
	if bool(look.get("cap", false)):
		var cap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.09 * s
		cm.bottom_radius = 0.1 * s
		cm.height = 0.06 * s
		cap.mesh = cm
		cap.position = Vector3(0, 0.19 * s, 0.01 * s)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = look.get("cap_color", Color(0.15, 0.2, 0.4))
		cap.material_override = cmat
		att.add_child(cap)


## Ghost look: every surface gets the translucent ghost shader.
func set_ghost(on: bool, base_y: float = 0.0) -> ShaderMaterial:
	_ghost = on
	if not on:
		return null
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/ghost.gdshader")
	gm.set_shader_parameter("base_height", base_y)
	for i in body_mesh.mesh.get_surface_count():
		body_mesh.set_surface_override_material(i, gm)
	for n in head_mesh.get_parent().get_children():
		if n is MeshInstance3D:
			(n as MeshInstance3D).material_override = gm
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return gm


func set_shadows(on: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body_mesh.cast_shadow = mode
	head_mesh.cast_shadow = mode


# =============================================================================================
# Animation
# =============================================================================================

func gesture(gesture_name: String) -> void:
	_gesture = gesture_name
	_gesture_t = 0.0


func look_at_point(p: Vector3) -> void:
	_look_target = p


func clear_look() -> void:
	_look_target = Vector3.INF


func _q(axis: Vector3, angle: float) -> Quaternion:
	return Quaternion(axis, angle)


## speed in m/s; state: idle, walk, run, crouch, aim, talk, sit, kneel, dead, cower, punch, phone, float, drive
func animate(delta: float, speed: float, state: String) -> void:
	if skeleton == null:
		return
	var X := Vector3(1, 0, 0)
	var Y := Vector3(0, 1, 0)
	var Z := Vector3(0, 0, 1)
	for i in _tgt.size():
		_tgt[i] = Quaternion.IDENTITY
	var moving := clampf(speed / 1.4, 0.0, 1.0)
	var running := clampf((speed - 2.6) / 2.5, 0.0, 1.0)
	var freq := lerpf(1.7, 2.9, running) if speed > 0.05 else 0.0
	_phase = fmod(_phase + delta * freq * TAU * 0.5 * clampf(speed / 1.5, 0.6, 2.2), TAU * 100.0)
	var ph := _phase
	var amp := lerpf(0.42, 0.78, running) * moving
	_hip_drop_tgt = 0.0
	_lie_tgt = 0.0
	# arms hang slightly out from the body
	_tgt[B.ARM_L] = _q(Z, -0.07)
	_tgt[B.ARM_R] = _q(Z, 0.07)
	_tgt[B.FOREARM_L] = _q(X, 0.12)
	_tgt[B.FOREARM_R] = _q(X, 0.12)
	match state:
		"dead":
			_lie_tgt = 1.0
			_tgt[B.ARM_L] = _q(Z, -0.5)
			_tgt[B.ARM_R] = _q(Z, 0.4)
			_tgt[B.HEAD] = _q(Y, 0.5)
		"kneel":
			_hip_drop_tgt = 0.48
			_tgt[B.THIGH_L] = _q(X, 1.4)
			_tgt[B.SHIN_L] = _q(X, -1.45)
			_tgt[B.THIGH_R] = _q(X, 0.1)
			_tgt[B.SHIN_R] = _q(X, -1.55)
			_tgt[B.FOOT_R] = _q(X, 0.6)
			_tgt[B.SPINE] = _q(X, -0.35)
			_tgt[B.HEAD] = _q(X, -0.3)
			_tgt[B.ARM_L] = _q(X, 0.5) * _q(Z, -0.1)
			_tgt[B.FOREARM_L] = _q(X, 1.2)
			_tgt[B.ARM_R] = _q(X, 0.3)
			_tgt[B.FOREARM_R] = _q(X, 0.9)
		"sit", "drive":
			_hip_drop_tgt = 0.44
			for t in [B.THIGH_L, B.THIGH_R]:
				_tgt[t] = _q(X, 1.5)
			for t in [B.SHIN_L, B.SHIN_R]:
				_tgt[t] = _q(X, -1.45)
			if state == "drive":
				_tgt[B.ARM_L] = _q(X, 1.1)
				_tgt[B.ARM_R] = _q(X, 1.1)
				_tgt[B.FOREARM_L] = _q(X, 0.4)
				_tgt[B.FOREARM_R] = _q(X, 0.4)
			else:
				_tgt[B.FOREARM_L] = _q(X, 0.9)
				_tgt[B.FOREARM_R] = _q(X, 0.9)
		"crouch", "cower":
			_hip_drop_tgt = 0.36
			for t in [B.THIGH_L, B.THIGH_R]:
				_tgt[t] = _q(X, 1.1 + amp * 0.3 * sin(ph))
			for t in [B.SHIN_L, B.SHIN_R]:
				_tgt[t] = _q(X, -1.7)
			_tgt[B.FOOT_L] = _q(X, 0.6)
			_tgt[B.FOOT_R] = _q(X, 0.6)
			_tgt[B.SPINE] = _q(X, -0.45)
			if state == "cower":
				_tgt[B.ARM_L] = _q(X, 2.6)
				_tgt[B.ARM_R] = _q(X, 2.6)
				_tgt[B.FOREARM_L] = _q(X, 1.9)
				_tgt[B.FOREARM_R] = _q(X, 1.9)
				_tgt[B.HEAD] = _q(X, -0.5)
		"float":
			var bob := sin(Time.get_ticks_msec() * 0.002)
			_tgt[B.THIGH_L] = _q(X, -0.15)
			_tgt[B.THIGH_R] = _q(X, -0.1)
			_tgt[B.SHIN_L] = _q(X, -0.35)
			_tgt[B.SHIN_R] = _q(X, -0.3)
			_tgt[B.ARM_L] = _q(X, 1.35 + 0.1 * bob) * _q(Z, -0.15)
			_tgt[B.ARM_R] = _q(X, 1.3 - 0.1 * bob) * _q(Z, 0.15)
			_tgt[B.HEAD] = _q(Z, 0.2 * bob) * _q(X, -0.15)
		_:
			# walking and running legs
			var swing := amp * sin(ph)
			_tgt[B.THIGH_L] = _q(X, swing)
			_tgt[B.THIGH_R] = _q(X, -swing)
			var kb := lerpf(0.55, 1.2, running) * moving
			_tgt[B.SHIN_L] = _q(X, -(0.06 + kb * maxf(0.0, sin(ph + 1.9))))
			_tgt[B.SHIN_R] = _q(X, -(0.06 + kb * maxf(0.0, sin(ph + 1.9 + PI))))
			_tgt[B.FOOT_L] = _q(X, -swing * 0.35)
			_tgt[B.FOOT_R] = _q(X, swing * 0.35)
			_tgt[B.ARM_L] = _q(X, -swing * 0.7) * _q(Z, -0.07)
			_tgt[B.ARM_R] = _q(X, swing * 0.7) * _q(Z, 0.07)
			var fb := 0.12 + running * 0.9
			_tgt[B.FOREARM_L] = _q(X, fb + maxf(0.0, -swing) * 0.4)
			_tgt[B.FOREARM_R] = _q(X, fb + maxf(0.0, swing) * 0.4)
			_tgt[B.SPINE] = _q(Y, 0.07 * sin(ph) * moving) * _q(X, -0.12 * running)
			_tgt[B.HIPS] = _q(Y, -0.06 * sin(ph) * moving)
			_hip_drop_tgt = 0.025 * absf(cos(ph)) * moving + running * 0.03
			if moving < 0.1:
				var br := sin(Time.get_ticks_msec() * 0.0021)
				_tgt[B.CHEST] = _q(X, 0.02 * br)
				_tgt[B.ARM_L] = _q(Z, -0.07 - 0.015 * br)
				_tgt[B.ARM_R] = _q(Z, 0.07 + 0.015 * br)
			if state == "talk" or _gesture == "talk":
				var g := sin(Time.get_ticks_msec() * 0.006)
				_tgt[B.ARM_R] = _q(X, 0.5 + 0.15 * g) * _q(Z, 0.15)
				_tgt[B.FOREARM_R] = _q(X, 1.1 + 0.25 * g)
				_tgt[B.HEAD] = _q(X, 0.05 * g)
			if state == "aim":
				_tgt[B.ARM_R] = _q(X, 1.5)
				_tgt[B.FOREARM_R] = _q(X, 0.05)
				_tgt[B.ARM_L] = _q(X, 1.3) * _q(Z, 0.35)
				_tgt[B.FOREARM_L] = _q(X, 0.5)
			if state == "phone":
				_tgt[B.ARM_R] = _q(X, 0.4) * _q(Z, 0.5)
				_tgt[B.FOREARM_R] = _q(X, 2.5)
	# one-shot gestures on top
	if _gesture != "":
		_gesture_t += delta
		var k := clampf(_gesture_t / 0.45, 0.0, 1.0)
		var pulse := sin(k * PI)
		match _gesture:
			"punch":
				_tgt[B.ARM_R] = _q(X, 1.55 * pulse)
				_tgt[B.FOREARM_R] = _q(X, 0.1 + 1.2 * (1.0 - pulse))
				_tgt[B.SPINE] = _q(Y, -0.4 * pulse)
			"wave":
				_tgt[B.ARM_R] = _q(Z, 2.4 * pulse)
				_tgt[B.FOREARM_R] = _q(Z, 0.5 * sin(_gesture_t * 18.0))
			"point":
				_tgt[B.ARM_R] = _q(X, 1.45 * pulse)
			"shrug":
				_tgt[B.SHOULDER_L] = _q(Z, -0.25 * pulse)
				_tgt[B.SHOULDER_R] = _q(Z, 0.25 * pulse)
				_tgt[B.FOREARM_L] = _q(X, 1.2 * pulse)
				_tgt[B.FOREARM_R] = _q(X, 1.2 * pulse)
			"hit":
				_tgt[B.SPINE] = _q(X, 0.35 * pulse)
				_tgt[B.HEAD] = _q(X, 0.3 * pulse)
			"recoil":
				_tgt[B.ARM_R] = _q(X, 1.5 + 0.35 * pulse)
				_tgt[B.FOREARM_R] = _q(X, 0.05 + 0.25 * pulse)
		if _gesture_t > 0.45 and _gesture != "talk":
			_gesture = ""
	# head looks toward a point (relative to the body's facing)
	if _look_target != Vector3.INF and state not in ["dead"]:
		var to := global_transform.affine_inverse() * _look_target
		var yaw := clampf(atan2(-to.x, -to.z), -1.1, 1.1)
		var pitch := clampf(atan2(to.y - 1.6 * scale_h, Vector2(to.x, to.z).length()), -0.5, 0.5)
		_tgt[B.HEAD] = _tgt[B.HEAD] * _q(Y, yaw * 0.7) * _q(X, pitch)
		_tgt[B.NECK] = _q(Y, yaw * 0.3)
	# blend and apply
	var rate := clampf(delta * 12.0, 0.0, 1.0)
	for i in _cur.size():
		_cur[i] = _cur[i].slerp(_tgt[i], rate)
		skeleton.set_bone_pose_rotation(i, _cur[i])
	_hip_drop = lerpf(_hip_drop, _hip_drop_tgt, rate)
	skeleton.set_bone_pose_position(B.HIPS, _rest[B.HIPS] - Vector3(0, _hip_drop * scale_h, 0))
	_lie = lerpf(_lie, _lie_tgt, clampf(delta * 4.0, 0.0, 1.0))
	if _lie > 0.001:
		skeleton.rotation = Vector3(-PI * 0.5 * _lie, 0, 0)
		skeleton.position = Vector3(0, 0.12 * _lie, 0.9 * scale_h * _lie)
	else:
		skeleton.rotation = Vector3.ZERO
		skeleton.position = Vector3.ZERO
