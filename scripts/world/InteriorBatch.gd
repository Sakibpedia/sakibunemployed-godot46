class_name InteriorBatch
extends RefCounted
## Static interior geometry batched by material.  A whole flat can be a few thousand boxes; if every
## box were a MeshInstance3D the draw-call count would collapse the frame rate.  Instead the builder
## appends boxes, quads and prisms to one SurfaceTool per material and commits a handful of meshes.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

var _surfaces: Dictionary = {}      # material key -> SurfaceTool
var _materials: Dictionary = {}     # material key -> Material
var _positions: Dictionary = {}     # material key -> Array[Vector3] (for winding)
var _vcount: Dictionary = {}        # material key -> vertices added so far (SurfaceTool has no counter)


func set_material(key: String, mat: Material) -> void:
	_materials[key] = mat


func _st(key: String) -> SurfaceTool:
	if _surfaces.has(key):
		return _surfaces[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_surfaces[key] = st
	_positions[key] = []
	_vcount[key] = 0
	return st


## Axis-aligned-in-local-space box.  `basis` may rotate it (a sloped stair stringer, a tilted panel).
func box(center: Vector3, size: Vector3, basis: Basis, key: String, uv_scale: float = 1.0) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(center + basis * Vector3(
			h.x if (i & 1) != 0 else -h.x,
			h.y if (i & 2) != 0 else -h.y,
			h.z if (i & 4) != 0 else -h.z))
	# Faces as (a,b,c,d) counter-clockwise seen from outside, plus outward normal.
	# The _quad helper fixes Godot's clockwise front-face convention.
	var faces := [
		[0, 2, 3, 1, Vector3(0, 0, -1)],  # -Z
		[4, 5, 7, 6, Vector3(0, 0, 1)],   # +Z
		[0, 1, 5, 4, Vector3(0, -1, 0)],  # -Y
		[2, 6, 7, 3, Vector3(0, 1, 0)],   # +Y
		[0, 4, 6, 2, Vector3(-1, 0, 0)],  # -X
		[1, 3, 7, 5, Vector3(1, 0, 0)],   # +X
	]
	for f in faces:
		var n: Vector3 = basis * (f[4] as Vector3)
		_quad(key, corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]], n, uv_scale)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, key: String, uv_scale: float = 1.0) -> void:
	_quad(key, a, b, c, d, normal, uv_scale)


func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, uv_scale: float) -> void:
	var st := _st(key)
	var base: int = int(_vcount[key])
	var n := normal.normalized()
	# UVs: a simple 0..1 square scaled by the face size so a cloth or tile texture does not stretch.
	var w := maxf(0.2, a.distance_to(b) * uv_scale)
	var h := maxf(0.2, b.distance_to(c) * uv_scale)
	var uvs := [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
	var pts := [a, b, c, d]
	for i in 4:
		st.set_normal(n)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])
	var pos: Array = _positions[key]
	pos.append_array([a, b, c, d])
	_vcount[key] = base + 4
	# Godot front faces are clockwise seen from outside; _tri checks the cross product.
	_tri(st, base, a, b, c, n)
	_tri(st, base, a, c, d, n)
	_positions[key] = pos


func _tri(st: SurfaceTool, base: int, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	# Godot uses clockwise winding for the front face: the cross product should point inward.
	if cr.dot(outward) < 0.0:
		st.add_index(base)
		st.add_index(base + 1)
		st.add_index(base + 2)
	else:
		st.add_index(base)
		st.add_index(base + 2)
		st.add_index(base + 1)


## Add a cylinder-ish prism (used for pipes, pots, water tanks, table legs).
func prism(center: Vector3, radius: float, height: float, sides: int, key: String, top_radius: float = -1.0) -> void:
	var st := _st(key)
	var r_top := radius if top_radius < 0.0 else top_radius
	var base: int = int(_vcount[key])
	for i in sides + 1:
		var a := TAU * float(i) / float(sides)
		st.set_normal(Vector3(cos(a), 0, sin(a)))
		st.set_uv(Vector2(float(i) / sides, 1))
		st.add_vertex(center + Vector3(cos(a) * radius, -height * 0.5, sin(a) * radius))
	for i in sides + 1:
		var a := TAU * float(i) / float(sides)
		st.set_normal(Vector3(cos(a), 0, sin(a)))
		st.set_uv(Vector2(float(i) / sides, 0))
		st.add_vertex(center + Vector3(cos(a) * r_top, height * 0.5, sin(a) * r_top))
	for i in sides:
		var a0: int = base + i
		var b0: int = base + i + 1
		var a1: int = base + sides + 1 + i
		var b1: int = base + sides + 2 + i
		# Godot front faces wind clockwise from outside, so the side quads use the reverse order.
		st.add_index(a0); st.add_index(b1); st.add_index(a1)
		st.add_index(a0); st.add_index(b0); st.add_index(b1)
	# caps
	var vc: int = base + (sides + 1) * 2
	for i in sides:
		var a := TAU * float(i) / float(sides)
		var b := TAU * float(i + 1) / float(sides)
		var p0 := center + Vector3(cos(a) * r_top, height * 0.5, sin(a) * r_top)
		var p1 := center + Vector3(cos(b) * r_top, height * 0.5, sin(b) * r_top)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2.ZERO)
		var c: int = vc
		st.add_vertex(center + Vector3(0, height * 0.5, 0))
		st.add_vertex(p0)
		st.add_vertex(p1)
		vc += 3
		st.add_index(c); st.add_index(c + 1); st.add_index(c + 2)
		var q0 := center + Vector3(cos(a) * radius, -height * 0.5, sin(a) * radius)
		var q1 := center + Vector3(cos(b) * radius, -height * 0.5, sin(b) * radius)
		st.set_normal(Vector3.DOWN)
		var d: int = vc
		st.add_vertex(center + Vector3(0, -height * 0.5, 0))
		st.add_vertex(q0)
		st.add_vertex(q1)
		vc += 3
		# The underside faces down, so it winds the opposite way from the top cap.
		st.add_index(d); st.add_index(d + 2); st.add_index(d + 1)
	_vcount[key] = vc


func commit(parent: Node3D) -> void:
	for key in _surfaces:
		var st: SurfaceTool = _surfaces[key]
		st.generate_normals()
		var mesh := st.commit()
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Batch_" + key
		mi.mesh = mesh
		mi.material_override = _materials.get(key, null)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(mi)
	_surfaces.clear()
	_positions.clear()
	_vcount.clear()
