class_name HeadSculpt
extends RefCounted
## A sculpted head instead of a plain sphere: the same UV layout as Godot's SphereMesh (so the face
## textures from tools/generate_textures.py land exactly on the features), with the surface pushed
## out and in to model a real face: nose bridge and tip, nostril wings, eye sockets and lids, brow
## ridge, cheekbones, cheek hollows, upper and lower lips, chin, temples, a jaw that narrows (more
## for women), a sloping forehead and a forward chin. Stylised realism: believable anatomy, painted
## skin. Meshes are cached per face, so a crowd shares a handful.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const SEG := 48
const RINGS := 32

static var _cache: Dictionary = {}


static func _g(dx: float, dy: float, sx: float, sy: float) -> float:
	return exp(-(dx * dx) / (sx * sx) - (dy * dy) / (sy * sy))


## Radial offset (unit head) for a point on the unit sphere, by face coordinates.
static func _offset(p: Vector3, female: bool, age: int) -> float:
	var front := smoothstep(0.0, 0.45, -p.z)
	if front <= 0.0:
		return 0.0
	var fx := -p.x
	var fy := p.y
	var ax := absf(fx)
	var d := 0.0
	# nose: a ridge from between the eyes to the tip, then the tip and the wings
	var t := clampf((0.14 - fy) / 0.34, 0.0, 1.0)
	var ridge_w := lerpf(0.045, 0.085, t)
	var ridge_h := lerpf(0.025, 0.19, t * t) * (0.9 if female else 1.0)
	var window := smoothstep(0.2, 0.12, fy) * smoothstep(-0.31, -0.2, fy)
	d += ridge_h * exp(-(fx * fx) / (ridge_w * ridge_w)) * window
	d += 0.055 * _g(ax - 0.085, fy + 0.25, 0.05, 0.04)
	d -= 0.012 * _g(fx, fy + 0.33, 0.03, 0.03)
	# eye sockets, with the lids and eyeball filling them back a little
	d -= 0.075 * _g(ax - 0.37, fy - 0.06, 0.16, 0.1)
	d += 0.035 * _g(ax - 0.37, fy - 0.055, 0.09, 0.055)
	# brow ridge, cheekbones, cheek hollows, temples
	d += (0.05 if not female else 0.022) * _g(ax - 0.3, fy - 0.25, 0.3, 0.06)
	d += (0.04 if not female else 0.05) * _g(ax - 0.48, fy + 0.12, 0.15, 0.12)
	d -= (0.02 + 0.0004 * maxf(0.0, float(age) - 30.0)) * _g(ax - 0.45, fy + 0.4, 0.12, 0.12)
	d -= 0.022 * _g(ax - 0.74, fy - 0.24, 0.1, 0.16)
	# lips and mouth corners
	d += (0.05 if not female else 0.062) * _g(fx, fy + 0.42, 0.17, 0.035)
	d += (0.045 if not female else 0.058) * _g(fx, fy + 0.52, 0.15, 0.04)
	d -= 0.015 * _g(ax - 0.2, fy + 0.47, 0.04, 0.04)
	# chin
	d += 0.07 * _g(fx, fy + 0.74, 0.12 if female else 0.17, 0.08)
	return d * front


static func mesh(face_id: String, female: bool, age: int) -> ArrayMesh:
	var key := "%s|%s|%d" % [face_id, "f" if female else "m", age / 10]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos: Array = []
	for j in RINGS + 2:
		var v := float(j) / float(RINGS + 1)
		var theta := PI * v
		for i in SEG + 1:
			var u := float(i) / float(SEG)
			var phi := TAU * u
			var p := Vector3(sin(phi) * sin(theta), cos(theta), cos(phi) * sin(theta))
			var r := 1.0 + _offset(p, female, age)
			var q := p * r
			# jaw narrows toward the chin on the front; forehead slopes back; chin comes forward
			var front := smoothstep(-0.1, 0.5, -p.z)
			var jaw := smoothstep(-0.1, -0.85, p.y) * (0.26 if female else 0.2)
			q.x *= 1.0 - jaw * (0.5 + 0.5 * front)
			q.x *= 1.0 - 0.07 * smoothstep(0.6, 0.95, absf(p.x))
			q.z += 0.035 * smoothstep(0.35, 0.85, p.y) * front
			q.z -= 0.035 * smoothstep(-0.45, -0.8, p.y) * front
			q.y -= 0.03 * smoothstep(-0.6, -0.95, p.y) * front
			q.z += 0.06 * smoothstep(-0.7, -1.0, p.y)
			q.y += 0.03 * smoothstep(-0.8, -1.0, p.y)
			st.set_uv(Vector2(u, v))
			st.set_normal(p)
			st.add_vertex(q)
			pos.append(q)
	for j in RINGS + 1:
		for i in SEG:
			var a := j * (SEG + 1) + i
			var b := a + SEG + 1
			_tri(st, pos, a, b, a + 1)
			_tri(st, pos, a + 1, b, b + 1)
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


static func _tri(st: SurfaceTool, pos: Array, i0: int, i1: int, i2: int) -> void:
	var p0: Vector3 = pos[i0]
	var p1: Vector3 = pos[i1]
	var p2: Vector3 = pos[i2]
	var c := (p1 - p0).cross(p2 - p0)
	if c.length_squared() < 1e-12:
		return
	var outward := (p0 + p1 + p2)
	if c.dot(outward) < 0.0:
		st.add_index(i0)
		st.add_index(i1)
		st.add_index(i2)
	else:
		st.add_index(i0)
		st.add_index(i2)
		st.add_index(i1)


## Where an eye sits on the unit head (for the glossy cornea), side -1 = viewer's left.
static func eye_position(side: float, female: bool) -> Vector3:
	var fx := 0.37 * side
	var fy := 0.06
	var p := Vector3(-fx, fy, -sqrt(maxf(0.0, 1.0 - fx * fx - fy * fy)))
	var r := 1.0 + _offset(p, female, 30)
	return p * (r - 0.075)
