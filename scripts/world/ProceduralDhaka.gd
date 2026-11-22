class_name ProceduralDhaka
extends Node3D
## Builds the whole open world from CityData (Data/World/city.json):
##   ground, roads with markings and sidewalks, the railway and the Jurain rail gate, the Mayor Hanif
##   flyover with its Kajla ramp, 2,600+ buildings drawn by the facade shader (windows, grilles,
##   stair-core stripes, shop shutters, lit windows at night), balconies with grilles, parapets, round
##   roof tanks, roof rooms, roof gardens, laundry and dishes, shop signboards in Bengali, awnings,
##   tea stalls, fruit carts, rickshaw stands, garbage, banners, trees, street lamps, electric poles
##   with sagging wires, the graveyard, the pond, the college field, the bus stand, the bazar, enterable
##   ground-floor rooms for the landmark buildings, and a ring of far-off city on the horizon.
## Everything is cut into 100 m chunks of MultiMesh draws with visibility ranges (docs/ARCHITECTURE.md 9).
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal built

const CHUNK := 100.0
const FACADE_SHADER := "res://shaders/dhaka_facade.gdshader"
const ROAD_SHADER := "res://shaders/dhaka_road.gdshader"
const LAMP_POOL := 16

## type -> [mesh kind, visibility range end (m), casts shadow]
const TYPES := {
	"facade": ["box", 1400.0, true], "slab": ["box", 300.0, true], "concrete": ["box", 500.0, true],
	"grille": ["box", 150.0, false], "tin": ["box", 260.0, true], "awning": ["box", 180.0, false],
	"tank_black": ["cyl", 260.0, true], "tank_concrete": ["cyl", 300.0, true], "trunk": ["cyl", 420.0, true],
	"canopy": ["sphere", 650.0, true], "lamp_pole": ["cyl", 260.0, false], "lamp_head": ["box", 400.0, false],
	"pole": ["box", 260.0, false], "grave": ["box", 220.0, false], "sign": ["box", 160.0, false],
	"laundry": ["quad", 110.0, false], "dark": ["box", 200.0, false], "paint": ["box", 200.0, true],
	"wheel": ["cyl", 120.0, false], "fruit": ["sphere", 90.0, false], "garbage": ["sphere", 120.0, false],
	"ac": ["box", 140.0, false], "dish": ["cyl", 160.0, false], "cloth": ["box", 160.0, false],
	"plant": ["sphere", 200.0, false], "metal": ["box", 220.0, true], "parapet": ["box", 320.0, true],
}
const SIGN_COLORS := [Color(0.85, 0.12, 0.14), Color(0.1, 0.42, 0.22), Color(0.1, 0.28, 0.62), Color(0.95, 0.75, 0.1),
	Color(0.9, 0.9, 0.86), Color(0.55, 0.12, 0.42), Color(0.92, 0.42, 0.1)]
const CLOTH_COLORS := [Color(0.85, 0.15, 0.2), Color(0.2, 0.35, 0.75), Color(0.95, 0.8, 0.2), Color(0.95, 0.95, 0.92),
	Color(0.15, 0.55, 0.3), Color(0.6, 0.2, 0.55), Color(0.95, 0.5, 0.2), Color(0.25, 0.25, 0.3)]

var city: CityData
var lamp_heads := PackedVector3Array()
var lamp_groups := PackedInt32Array()
var interior_lights: Array[OmniLight3D] = []

var _inst: Dictionary = {}        # type -> chunk key -> Array of [Transform3D, Color, Color]
var _chunks: Dictionary = {}      # Vector2i -> Node3D
var _bodies: Dictionary = {}      # Vector2i -> StaticBody3D
var _wires: Dictionary = {}       # Vector2i -> SurfaceTool
var _meshes: Dictionary = {}
var _mats: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _pool: Array[OmniLight3D] = []
var _pool_timer := 0.0
var _sign_font: Font
var building_visual: Dictionary = {}     # id -> {chunk: Vector2i, index: int, original: Transform3D}
var building_colliders: Dictionary = {}  # id -> CollisionShape3D


func build(c: CityData) -> void:
	city = c
	_rng.seed = 20261119
	_sign_font = UiKit.font(true)
	_make_resources()
	_ground()
	_roads()
	_rail()
	_flyovers()
	_ponds_and_areas()
	_graves()
	for b in city.buildings:
		_building(b)
	_backdrop()
	_trees()
	_lamps()
	_poles_and_wires()
	_props()
	_flush()
	_make_lamp_pool()
	built.emit()


# =============================================================================================
# Resources
# =============================================================================================

func _make_resources() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 12
	cyl.rings = 1
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 10
	sph.rings = 6
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_meshes = {"box": box, "cyl": cyl, "sphere": sph, "quad": quad}

	var fac := ShaderMaterial.new()
	fac.shader = load(FACADE_SHADER)
	var plaster := _tex("res://art/textures/surfaces/plaster_clean_albedo.png")
	if plaster:
		fac.set_shader_parameter("plaster_tex", plaster)
	var grime := _tex("res://art/textures/shared/grime_noise.png")
	if grime:
		fac.set_shader_parameter("grime_tex", grime)
	_mats["facade"] = fac
	_mats["slab"] = _vc_mat(DhakaMaterials.surface(DhakaMaterials.CONCRETE))
	_mats["concrete"] = DhakaMaterials.surface(DhakaMaterials.CONCRETE)
	_mats["paint"] = DhakaMaterials.surface(DhakaMaterials.PLASTER)
	_mats["tin"] = DhakaMaterials.surface(DhakaMaterials.TIN)
	_mats["awning"] = DhakaMaterials.surface(DhakaMaterials.AWNING, 0)
	var grille := StandardMaterial3D.new()
	var gt := _tex("res://art/textures/cutouts/grille_steel_albedo.png")
	if gt:
		grille.albedo_texture = gt
		grille.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		grille.alpha_scissor_threshold = 0.5
		grille.uv1_triplanar = true
		grille.uv1_world_triplanar = true
		grille.uv1_scale = Vector3(1.0, 1.0, 1.0)
	else:
		grille.albedo_color = Color(0.15, 0.15, 0.16)
	grille.metallic = 0.6
	grille.roughness = 0.5
	grille.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["grille"] = grille
	_mats["tank_black"] = _plain(Color(0.08, 0.08, 0.09), 0.5)
	_mats["tank_concrete"] = _plain(Color(0.72, 0.71, 0.68), 0.9, true)
	_mats["trunk"] = _plain(Color(0.3, 0.22, 0.16), 0.95)
	_mats["canopy"] = _plain(Color(1, 1, 1), 0.9, true)
	_mats["plant"] = _plain(Color(1, 1, 1), 0.9, true)
	_mats["lamp_pole"] = _plain(Color(0.35, 0.36, 0.38), 0.4)
	_mats["pole"] = _plain(Color(0.62, 0.61, 0.58), 0.9)
	_mats["grave"] = _plain(Color(0.86, 0.85, 0.8), 0.85)
	_mats["dark"] = _plain(Color(0.06, 0.06, 0.07), 0.8)
	_mats["metal"] = _plain(Color(1, 1, 1), 0.35, true, 0.5)
	_mats["wheel"] = _plain(Color(0.05, 0.05, 0.05), 0.7)
	_mats["fruit"] = _plain(Color(1, 1, 1), 0.6, true)
	_mats["garbage"] = _plain(Color(1, 1, 1), 0.95, true)
	_mats["ac"] = _plain(Color(0.86, 0.86, 0.84), 0.6)
	_mats["dish"] = _plain(Color(0.9, 0.9, 0.9), 0.4)
	_mats["cloth"] = _plain(Color(1, 1, 1), 0.9, true)
	var laundry := _plain(Color(1, 1, 1), 0.9, true)
	laundry.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["laundry"] = laundry
	_mats["parapet"] = _parapet_material(plaster)
	_mats["lamp_head"] = _glow_material(Color(1.0, 0.72, 0.4), 4.0)
	_mats["sign"] = _glow_material(Color(1, 1, 1), 0.6, true)


func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _plain(col: Color, rough: float, vertex_color: bool = false, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.vertex_color_use_as_albedo = vertex_color
	return m


## Copy of a surface material that also takes the instance colour as tint (if it is the shader).
func _vc_mat(m: Material) -> Material:
	return m


## Roof parapets pierced with square openings ("grey parapet with square openings", photos p129-p140).
func _parapet_material(plaster: Texture2D) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D plaster_tex : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 v_local;
varying vec3 v_size;
varying vec4 v_col;
void vertex() {
	v_local = VERTEX;
	v_size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_col = COLOR;
}
void fragment() {
	float along = v_size.x > v_size.z ? (v_local.x + 0.5) * v_size.x : (v_local.z + 0.5) * v_size.z;
	float y = (v_local.y + 0.5) * v_size.y;
	float cell = fract(along / 0.48);
	if (cell > 0.18 && cell < 0.72 && y > 0.32 && y < 0.78 && v_size.y > 0.6) {
		discard;
	}
	vec3 t = texture(plaster_tex, vec2(along, y) / 2.5).rgb;
	ALBEDO = v_col.rgb * (0.72 + 0.35 * t) * mix(0.85, 1.0, smoothstep(0.9, 1.0, y));
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	if plaster:
		m.set_shader_parameter("plaster_tex", plaster)
	return m


## Lamp heads and signboards: lit by night, dark in a load-shedding district.
func _glow_material(col: Color, energy: float, vertex_color: bool = false) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_back;
global uniform float dhaka_night;
global uniform vec4 dhaka_power_a;
global uniform float dhaka_power_b;
uniform vec4 glow_color : source_color = vec4(%.4f, %.4f, %.4f, 1.0);
uniform float energy = %.4f;
uniform bool use_vc = %s;
varying vec4 v_custom;
varying vec4 v_col;
void vertex() { v_custom = INSTANCE_CUSTOM; v_col = COLOR; }
void fragment() {
	int g = int(v_custom.r + 0.5);
	float power = g < 4 ? dhaka_power_a[g] : dhaka_power_b;
	vec3 base = use_vc ? v_col.rgb : glow_color.rgb;
	ALBEDO = base * 0.6;
	ROUGHNESS = 0.5;
	EMISSION = base * energy * dhaka_night * power;
}
""" % [col.r, col.g, col.b, energy, "true" if vertex_color else "false"]
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


# =============================================================================================
# Instance collection
# =============================================================================================

func _ckey(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK)), int(floor(p.z / CHUNK)))


func _add(type: String, xf: Transform3D, col: Color = Color.WHITE, custom: Color = Color(0, 0, 0, 0)) -> int:
	var k := _ckey(xf.origin)
	if not _inst.has(type):
		_inst[type] = {}
	var per: Dictionary = _inst[type]
	if not per.has(k):
		per[k] = []
	var arr: Array = per[k]
	arr.append([xf, col, custom])
	return arr.size() - 1


## A box in a frame: centre `lp` in the frame (origin, basis), size, extra local rotation.
func _box(type: String, origin: Vector3, basis: Basis, lp: Vector3, size: Vector3, col: Color = Color.WHITE,
		extra: Basis = Basis.IDENTITY, custom: Color = Color(0, 0, 0, 0)) -> int:
	var b := basis * extra * Basis.from_scale(size)
	return _add(type, Transform3D(b, origin + basis * lp), col, custom)


func _chunk_node(k: Vector2i) -> Node3D:
	if _chunks.has(k):
		return _chunks[k]
	var n := Node3D.new()
	n.name = "Chunk_%d_%d" % [k.x, k.y]
	add_child(n)
	_chunks[k] = n
	return n


func _body(k: Vector2i) -> StaticBody3D:
	if _bodies.has(k):
		return _bodies[k]
	var b := StaticBody3D.new()
	b.name = "Collision"
	b.collision_layer = 1
	b.collision_mask = 0
	_chunk_node(k).add_child(b)
	_bodies[k] = b
	return b


func _collide_box(center: Vector3, basis: Basis, size: Vector3) -> void:
	_collide_box_tag(center, basis, size, "")


func _collide_box_tag(center: Vector3, basis: Basis, size: Vector3, id: String) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.transform = Transform3D(basis, center)
	_body(_ckey(center)).add_child(cs)
	if id != "":
		building_colliders[id] = cs
	return cs


## Hide one building's shader-painted box without rebuilding its whole 100 m chunk.  A zero-scaled
## instance costs nothing to draw; the real walkable shell takes its place.
func set_building_hidden(id: String, hidden: bool) -> void:
	var rec: Dictionary = building_visual.get(id, {})
	if rec.is_empty():
		return
	var node := _chunk_node(rec["chunk"]).get_node_or_null("facade") as MultiMeshInstance3D
	if node == null:
		return
	var mm := node.multimesh
	if mm == null:
		return
	var idx := int(rec.get("index", -1))
	if idx < 0 or idx >= mm.instance_count:
		return
	if hidden:
		if not rec.has("original"):
			rec["original"] = mm.get_instance_transform(idx)
			building_visual[id] = rec
		mm.set_instance_transform(idx, Transform3D(Basis.from_scale(Vector3(0.0001, 0.0001, 0.0001)), Vector3(0, -600.0, 0)))
	else:
		if rec.has("original"):
			mm.set_instance_transform(idx, rec["original"])


func set_building_collision(id: String, enabled: bool) -> void:
	var cs: CollisionShape3D = building_colliders.get(id, null)
	if cs != null and is_instance_valid(cs):
		cs.disabled = not enabled


func _collide_cyl(center: Vector3, radius: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = h
	cs.shape = sh
	cs.position = center
	_body(_ckey(center)).add_child(cs)


func _flush() -> void:
	for type in _inst:
		var info: Array = TYPES.get(type, ["box", 200.0, false])
		var mesh: Mesh = _meshes[String(info[0])]
		var per: Dictionary = _inst[type]
		for k in per:
			var arr: Array = per[k]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = mesh
			mm.instance_count = arr.size()
			for i in arr.size():
				var e: Array = arr[i]
				mm.set_instance_transform(i, e[0])
				mm.set_instance_color(i, e[1])
				mm.set_instance_custom_data(i, e[2])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = _mats.get(type, _mats["slab"])
			mmi.visibility_range_end = float(info[1])
			mmi.visibility_range_end_margin = 20.0
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(info[2]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.name = type
			_chunk_node(k).add_child(mmi)
	for k in _wires:
		var st: SurfaceTool = _wires[k]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _wire_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 160.0
		mi.name = "wires"
		_chunk_node(k).add_child(mi)
	_inst.clear()
	_inst.clear()


func _wire_material() -> StandardMaterial3D:
	if _mats.has("wire"):
		return _mats["wire"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.03)
	m.roughness = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["wire"] = m
	return m

func _wire(a: Vector3, b: Vector3, sag: float) -> void:
	var k := _ckey((a + b) * 0.5)
	if not _wires.has(k):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_wires[k] = st
	var st2: SurfaceTool = _wires[k]
	var segs := 6
	var w := 0.025
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var p0 := a.lerp(b, t0) - Vector3(0, sag * 4.0 * t0 * (1.0 - t0), 0)
		var p1 := a.lerp(b, t1) - Vector3(0, sag * 4.0 * t1 * (1.0 - t1), 0)
		for off: Vector3 in [Vector3(0, w, 0), Vector3(w, 0, w)]:
			for v: Vector3 in [p0 - off, p1 - off, p1 + off, p0 - off, p1 + off, p0 + off]:
				st2.set_normal(Vector3.UP)
				st2.add_vertex(v)
# =============================================================================================
# Ground, roads, rail, flyover
# =============================================================================================

func _ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(city.width + 600.0, city.height + 600.0)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = DhakaMaterials.surface(DhakaMaterials.CONCRETE)
	mi.position = Vector3(city.width * 0.5, 0.0, city.height * 0.5)
	mi.name = "Ground"
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)
	# the city goes on, but the map ends: invisible walls at the edges
	var walls := StaticBody3D.new()
	walls.name = "MapEdge"
	add_child(walls)
	for spec in [[Vector3(city.width * 0.5, 20, -1), Vector3(city.width + 40, 40, 2)], [Vector3(city.width * 0.5, 20, city.height + 1), Vector3(city.width + 40, 40, 2)],
			[Vector3(-1, 20, city.height * 0.5), Vector3(2, 40, city.height + 40)], [Vector3(city.width + 1, 20, city.height * 0.5), Vector3(2, 40, city.height + 40)]]:
		var w := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = spec[1]
		w.shape = sh
		w.position = spec[0]
		walls.add_child(w)


func _roads() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load(ROAD_SHADER)
	var at := _tex("res://art/textures/surfaces/asphalt_cracked_albedo.png")
	if at:
		mat.set_shader_parameter("asphalt_tex", at)
	var ao := _tex("res://art/textures/surfaces/asphalt_cracked_orm.png")
	if ao:
		mat.set_shader_parameter("asphalt_orm", ao)
	var gt := _tex("res://art/textures/shared/grime_noise.png")
	if gt:
		mat.set_shader_parameter("grime_tex", gt)
	var idx := 0
	for r in city.roads:
		var rd: Dictionary = r
		idx += 1
		var kind := String(rd["kind"])
		var width := float(rd["width"])
		var side := float(rd.get("sidewalk", 0.0))
		var y := (0.03 if kind == "highway" else (0.024 if kind == "main" else 0.018)) + idx * 0.00008
		var kc := 1.0 if kind == "highway" else (0.5 if kind == "main" else 0.0)
		var pts: Array = rd["points"]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var along := 0.0
		for i in pts.size() - 1:
			var a := Vector3(float(pts[i][0]), y, float(pts[i][1]))
			var b := Vector3(float(pts[i + 1][0]), y, float(pts[i + 1][1]))
			var d := (b - a).normalized()
			var n := Vector3(-d.z, 0, d.x)
			var seg_len := a.distance_to(b)
			var col := Color(kc, width / 40.0, 0, 1)
			var ext := d * 2.0       # overlap junctions a little
			var v0 := a - ext - n * width * 0.5
			var v1 := a - ext + n * width * 0.5
			var v2 := b + ext + n * width * 0.5
			var v3 := b + ext - n * width * 0.5
			_quad(st, v0, v1, v2, v3, Vector2(0, along), Vector2(1, along), Vector2(1, along + seg_len), Vector2(0, along + seg_len), col)
			along += seg_len
			if side > 0.0:
				_sidewalk(a, b, d, n, width, side)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Road_%s" % String(rd["id"])
		add_child(mi)


func _quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, u0: Vector2, u1: Vector2, u2: Vector2, u3: Vector2, col: Color) -> void:
	for pair in [[v0, u0], [v2, u2], [v1, u1], [v0, u0], [v3, u3], [v2, u2]]:
		st.set_color(col)
		st.set_uv(pair[1])
		st.add_vertex(pair[0])


func _sidewalk(a: Vector3, b: Vector3, d: Vector3, n: Vector3, width: float, side: float) -> void:
	var seg_len := a.distance_to(b)
	var steps := maxi(1, int(seg_len / 6.0))
	var basis := Basis(Vector3.UP, atan2(-d.z, d.x))
	for s in [-1.0, 1.0]:
		for i in steps:
			var t0 := float(i) / steps
			var c := a.lerp(b, t0 + 0.5 / steps)
			var off: Vector3 = n * s * (width * 0.5 + side * 0.5)
			var seg := seg_len / steps
			_box("concrete", c + off + Vector3(0, 0.06, 0), basis, Vector3.ZERO, Vector3(seg, 0.12, side))
			# kerb stones painted black and yellow (as on Dhaka's main roads)
			var kc := Color(0.95, 0.78, 0.15) if i % 2 == 0 else Color(0.1, 0.1, 0.1)
			_box("paint", c + n * s * (width * 0.5 + 0.08) + Vector3(0, 0.1, 0), basis, Vector3.ZERO, Vector3(seg, 0.2, 0.16), kc)


func _rail() -> void:
	for r in city.data.get("rail", []):
		var rd: Dictionary = r
		var pts: Array = rd["points"]
		for i in pts.size() - 1:
			var a := Vector3(float(pts[i][0]), 0.0, float(pts[i][1]))
			var b := Vector3(float(pts[i + 1][0]), 0.0, float(pts[i + 1][1]))
			var d := (b - a).normalized()
			var n := Vector3(-d.z, 0, d.x)
			var seg_len := a.distance_to(b)
			var basis := Basis(Vector3.UP, atan2(-d.z, d.x))
			var seg := 10.0
			var steps := int(seg_len / seg)
			for k in steps:
				var c := a.lerp(b, (k + 0.5) / steps)
				_box("concrete", c + Vector3(0, 0.12, 0), basis, Vector3.ZERO, Vector3(seg, 0.24, 3.4), Color(0.45, 0.42, 0.38))
				for s in [-0.5, 0.5]:
					_box("metal", c + n * s + Vector3(0, 0.33, 0), basis, Vector3.ZERO, Vector3(seg, 0.12, 0.07), Color(0.4, 0.36, 0.33))
				for j in 14:
					var sp := c + d * (j - 6.5) * (seg / 14.0)
					_box("dark", sp + Vector3(0, 0.26, 0), basis, Vector3.ZERO, Vector3(0.22, 0.1, 2.0))
	# the Jurain level crossing: booths and red-white barrier arms
	var gate := city.poi_pos("rail_gate")
	if gate != city.spawn_point():
		var basis := Basis.IDENTITY
		_box("paint", gate + Vector3(3, 1.2, -3), basis, Vector3.ZERO, Vector3(2.2, 2.4, 2.2), Color(0.85, 0.82, 0.74))
		_box("tin", gate + Vector3(3, 2.55, -3), basis, Vector3.ZERO, Vector3(2.8, 0.1, 2.8))
		for s in [-1.0, 1.0]:
			_box("paint", gate + Vector3(s * 9.0, 1.0, s * 6.0), Basis(Vector3.UP, 0.1), Vector3.ZERO, Vector3(10.0, 0.18, 0.18), Color(0.85, 0.12, 0.12))
		_collide_box(gate + Vector3(3, 1.2, -3), basis, Vector3(2.2, 2.4, 2.2))


func _flyovers() -> void:
	for f in city.data.get("flyovers", []):
		var fd: Dictionary = f
		var pts: Array = fd["points"]
		var width := float(fd["width"])
		var h := float(fd["height"])
		var ramp := float(fd.get("ramp_length", 140.0))
		# total length so the last `ramp` metres descend to the ground
		var total := 0.0
		for i in pts.size() - 1:
			total += Vector2(float(pts[i][0]), float(pts[i][1])).distance_to(Vector2(float(pts[i + 1][0]), float(pts[i + 1][1])))
		var run := 0.0
		for i in pts.size() - 1:
			var a2 := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b2 := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var seg_len := a2.distance_to(b2)
			var steps := maxi(1, int(seg_len / 14.0))
			for k in steps:
				var t0 := float(k) / steps
				var t1 := float(k + 1) / steps
				var p0 := a2.lerp(b2, t0)
				var p1 := a2.lerp(b2, t1)
				var y0 := _fly_height(run + seg_len * t0, total, ramp, h)
				var y1 := _fly_height(run + seg_len * t1, total, ramp, h)
				var a := Vector3(p0.x, y0, p0.y)
				var b := Vector3(p1.x, y1, p1.y)
				var seg := a.distance_to(b)
				var dir := (b - a).normalized()
				var yaw := atan2(-dir.z, dir.x)
				var pitch := asin(clampf(dir.y, -1.0, 1.0))
				var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), pitch)
				var c := (a + b) * 0.5
				_box("concrete", c, basis, Vector3(0, -0.4, 0), Vector3(seg + 0.3, 0.8, width), Color(0.7, 0.7, 0.68))
				for s in [-1.0, 1.0]:
					_box("concrete", c, basis, Vector3(0, 0.45, s * (width * 0.5 - 0.2)), Vector3(seg + 0.3, 0.9, 0.35), Color(0.78, 0.78, 0.75))
				_collide_box(c + basis * Vector3(0, -0.4, 0), basis, Vector3(seg + 0.3, 0.8, width))
				for s in [-1.0, 1.0]:
					_collide_box(c + basis * Vector3(0, 0.45, s * (width * 0.5 - 0.2)), basis, Vector3(seg, 0.9, 0.35))
				# pillars every other segment, while the deck is high
				if k % 2 == 0 and y0 > 2.5:
					_box("concrete", Vector3(a.x, (y0 - 0.8) * 0.5, a.z), Basis.IDENTITY, Vector3.ZERO, Vector3(1.8, y0 - 0.8, 1.8), Color(0.72, 0.72, 0.7))
					_collide_box(Vector3(a.x, (y0 - 0.8) * 0.5, a.z), Basis.IDENTITY, Vector3(1.8, y0 - 0.8, 1.8))
					_box("concrete", Vector3(a.x, y0 - 1.1, a.z), Basis(Vector3.UP, yaw), Vector3.ZERO, Vector3(2.4, 0.6, width * 0.8), Color(0.7, 0.7, 0.68))
			run += seg_len


func _fly_height(dist: float, total: float, ramp: float, h: float) -> float:
	var left := total - dist
	if left < ramp:
		return h * clampf(left / ramp, 0.0, 1.0) + 0.05
	return h


func _ponds_and_areas() -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.09, 0.17, 0.15)
	water.roughness = 0.04
	water.metallic = 0.1
	for p in city.data.get("ponds", []):
		var pd: Dictionary = p
		var r: Array = pd["rect"]
		var cx := (float(r[0]) + float(r[2])) * 0.5
		var cz := (float(r[1]) + float(r[3])) * 0.5
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 0.05
		cyl.radial_segments = 40
		mi.mesh = cyl
		mi.material_override = water
		mi.scale = Vector3(float(r[2]) - float(r[0]), 1.0, float(r[3]) - float(r[1]))
		mi.position = Vector3(cx, 0.04, cz)
		mi.name = "Pond"
		add_child(mi)
		# a ghat: concrete steps down into the water on the south side
		for s in 4:
			_box("concrete", Vector3(cx, 0.08 + 0.1 * s, float(r[3]) - 1.0 - 0.6 * s), Basis.IDENTITY, Vector3.ZERO, Vector3(8.0, 0.2, 0.7), Color(0.6, 0.6, 0.58))
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.32, 0.46, 0.2)
	grass.roughness = 0.95
	for a in city.data.get("landmark_areas", []):
		var ad: Dictionary = a
		var id := String(ad["id"])
		var pos := Vector3(float(ad["x"]), 0.0, float(ad["z"]))
		var basis := Basis(Vector3.UP, -float(ad["rot"]))
		var w := float(ad["w"])
		var d := float(ad["d"])
		if id == "college_field" or id == "graveyard":
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(w, d)
			mi.mesh = pm
			mi.material_override = grass
			mi.transform = Transform3D(basis, pos + Vector3(0, 0.035, 0))
			mi.name = "Grass_" + id
			add_child(mi)
			# boundary wall with a gate gap on the near side
			var wall_col := Color(0.82, 0.78, 0.7) if id == "graveyard" else Color(0.86, 0.6, 0.5)
			for s in [-1.0, 1.0]:
				_wall(pos, basis, Vector3(0, 1.0, s * d * 0.5), Vector3(w, 2.0, 0.25), wall_col, s < 0.0, 6.0)
				_wall(pos, basis, Vector3(s * w * 0.5, 1.0, 0), Vector3(0.25, 2.0, d), wall_col, false, 0.0)
		elif id == "bus_stand":
			for i in 5:
				var bc := pos + basis * Vector3(-w * 0.4 + i * 13.0, 0, 0)
				_bus(bc, Basis(Vector3.UP, -float(ad["rot"]) + PI * 0.5), CLOTH_COLORS[i % CLOTH_COLORS.size()])
		elif id == "bazar":
			for i in 4:
				for j in 3:
					var sc := pos + basis * Vector3(-w * 0.35 + i * 11.0, 0, -d * 0.3 + j * 10.0)
					_stall(sc, basis, i + j)


func _wall(pos: Vector3, basis: Basis, lp: Vector3, size: Vector3, col: Color, gate: bool, gap: float) -> void:
	if not gate:
		_box("paint", pos, basis, lp, size, col)
		_collide_box(pos + basis * lp, basis, size)
		return
	var half := (size.x - gap) * 0.5
	for s in [-1.0, 1.0]:
		var c := lp + Vector3(s * (gap * 0.5 + half * 0.5), 0, 0)
		var sz := Vector3(half, size.y, size.z)
		_box("paint", pos, basis, c, sz, col)
		_collide_box(pos + basis * c, basis, sz)
		_box("paint", pos, basis, lp + Vector3(s * gap * 0.5, 0.4, 0), Vector3(0.5, size.y + 0.8, 0.5), col.darkened(0.15))


func _graves() -> void:
	for g in city.data.get("graves", []):
		var ga: Array = g
		var p := Vector3(float(ga[0]), 0.0, float(ga[1]))
		var basis := Basis(Vector3.UP, -float(ga[2]))
		_box("grave", p, basis, Vector3(0, 0.12, 0), Vector3(0.75, 0.24, 1.9))
		_box("grave", p, basis, Vector3(0, 0.5, -0.9), Vector3(0.6, 0.8, 0.1))
	var shed := city.poi_pos("graveyard_shed")
	if shed != city.spawn_point():
		_shack(shed + Vector3(4, 0, 0), Basis.IDENTITY, 4.0, 3.5, Color(0.5, 0.45, 0.4))


# =============================================================================================
# Buildings
# =============================================================================================

func _building(b: Dictionary) -> void:
	var style := String(b["style"])
	var pos := Vector3(float(b["x"]), 0.0, float(b["z"]))
	var basis := Basis(Vector3.UP, -float(b["rot"]))
	var w := float(b["w"])
	var d := float(b["d"])
	var floors := int(b["floors"])
	var storey := float(b["storey"])
	var col_a: Array = b["color"]
	var col := Color(float(col_a[0]), float(col_a[1]), float(col_a[2]))
	if style == "shack":
		_shack(pos, basis, w, d, col)
		return
	var h := floors * storey
	var bseed := float(absi(hash(String(b["id"]))) % 1000) / 1000.0
	var group := city.power_group(String(b["district"]))
	var flags := (1 if String(b.get("shop", "")) != "" else 0) + (2 if style == "old" else 0) + group * 4
	var stripe := float(int(b.get("stripe", -1)))
	var enter := bool(b.get("enterable", false))
	var id := String(b.get("id", ""))
	var custom := Color(storey, stripe, float(flags), bseed)
	if enter:
		# The walkable shell (walls, windows, floors, stairs, roof, doors) is generated by
		# BuildingInteriorSystem at startup.  Drawing the painted box as well would hide it.
		pass
	else:
		var fidx := _box("facade", pos, basis, Vector3(0, h * 0.5, 0), Vector3(w, h, d), col, Basis.IDENTITY, custom)
		building_visual[id] = {"chunk": _ckey(pos), "index": fidx}
		_collide_box_tag(pos + basis * Vector3(0, h * 0.5, 0), basis, Vector3(w, h, d), id)
	# parapet round the roof (pierced look from the grille on top of a low solid band)
	var pc := col.darkened(0.08) if bseed > 0.4 else Color(0.66, 0.66, 0.64)
	var ph := 1.05 if style in ["apartment", "tower", "commercial"] else 0.75
	var ptype := "parapet" if ph > 1.0 else "slab"
	for s in [-1.0, 1.0]:
		_box(ptype, pos, basis, Vector3(0, h + ph * 0.5, s * (d * 0.5 - 0.1)), Vector3(w, ph, 0.18), pc)
		_box(ptype, pos, basis, Vector3(s * (w * 0.5 - 0.1), h + ph * 0.5, 0), Vector3(0.18, ph, d - 0.36), pc)
		_box("slab", pos, basis, Vector3(0, h + ph + 0.04, s * (d * 0.5 - 0.1)), Vector3(w + 0.1, 0.08, 0.26), Color(0.62, 0.62, 0.6))
	# front boundary wall with a 4.5 m sliding grille gate (photos p67-p86)
	if style in ["apartment", "tower"] and w > 9.0 and bseed < 0.65:
		_boundary(pos, basis, w, d, col)
	# Roof clutter (tanks, headrooms, gardens) is generated by BuildingInterior together with real
	# colliders when the building is opened.  Drawing the painted version as well would leave
	# floating tanks above the walkable roof, so it is skipped for every building.
	if bool(b.get("balconies", false)):
		_balconies(pos, basis, w, d, floors, storey, col, bseed)
	# a few AC units and a meter box on the side walls
	var n_ac := _rng.randi_range(0, 3) if style != "old" else _rng.randi_range(0, 1)
	for i in n_ac:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var fy := _rng.randi_range(1, maxi(1, floors - 1)) * storey + 1.2
		_box("ac", pos, basis, Vector3(side * (w * 0.5 + 0.2), fy, _rng.randf_range(-d * 0.35, d * 0.35)), Vector3(0.38, 0.5, 0.8))
	if String(b.get("shop", "")) != "" or b.get("sign") != null:
		_shopfront(b, pos, basis, w, d, storey)
	var lm := String(b.get("landmark", ""))
	if lm == "mosque":
		_mosque(pos, basis, w, d, h)
	elif lm == "tower":
		_tower_details(pos, basis, w, d, h, storey, not enter)


func _boundary(pos: Vector3, basis: Basis, w: float, d: float, col: Color) -> void:
	var z := d * 0.5 + 1.25
	var gate := 4.5
	var seg := (w - gate) * 0.5
	var wc := col.darkened(0.15)
	for s in [-1.0, 1.0]:
		var c := Vector3(s * (gate * 0.5 + seg * 0.5), 0.9, z)
		_box("paint", pos, basis, c, Vector3(seg, 1.8, 0.2), wc)
		_box("grille", pos, basis, c + Vector3(0, 1.2, 0), Vector3(seg, 0.6, 0.04))
		_collide_box(pos + basis * c, basis, Vector3(seg, 1.8, 0.2))
		_box("paint", pos, basis, Vector3(s * (w * 0.5 - 0.1), 0.9, d * 0.5 + 0.62), Vector3(0.2, 1.8, 1.25), wc)
		_box("paint", pos, basis, Vector3(s * gate * 0.5, 1.15, z), Vector3(0.35, 2.3, 0.35), wc.darkened(0.1))
	# the gate: steel grille, slid half open
	_box("grille", pos, basis, Vector3(-gate * 0.25, 1.1, z + 0.12), Vector3(gate * 0.5, 2.2, 0.05))
	_box("metal", pos, basis, Vector3(-gate * 0.25, 2.2, z + 0.12), Vector3(gate * 0.5, 0.06, 0.06), Color(0.2, 0.22, 0.25))


func _roof(b: Dictionary, pos: Vector3, basis: Basis, w: float, d: float, h: float, col: Color) -> void:
	var roof: Dictionary = b.get("roof", {})
	if bool(roof.get("tank", false)):
		var tx := _rng.randf_range(-w * 0.3, w * 0.3)
		var tz := _rng.randf_range(-d * 0.3, d * 0.3)
		if _rng.randf() < 0.55:
			# round concrete tank about 2.5 m across on a stand (photos p109, p128)
			_box("concrete", pos, basis, Vector3(tx, h + 0.3, tz), Vector3(2.8, 0.6, 2.8), Color(0.6, 0.6, 0.58))
			_add("tank_concrete", Transform3D(basis * Basis.from_scale(Vector3(2.5, 1.8, 2.5)), pos + basis * Vector3(tx, h + 1.5, tz)))
		else:
			for i in _rng.randi_range(1, 2):
				_add("tank_black", Transform3D(basis * Basis.from_scale(Vector3(1.4, 1.6, 1.4)), pos + basis * Vector3(tx + i * 1.7, h + 0.8, tz)))
	if bool(roof.get("room", false)):
		var rx := w * 0.5 - 2.2
		var rz := -d * 0.5 + 2.0
		_box("paint", pos, basis, Vector3(rx, h + 1.4, rz), Vector3(3.6, 2.8, 3.2), col.darkened(0.05))
		_box("dark", pos, basis, Vector3(rx - 0.6, h + 1.1, rz + 1.62), Vector3(0.9, 2.0, 0.05))
		_box("slab", pos, basis, Vector3(rx, h + 2.9, rz), Vector3(3.9, 0.15, 3.5), Color(0.62, 0.62, 0.6))
	if bool(roof.get("garden", false)):
		for i in _rng.randi_range(3, 6):
			var gp := Vector3(_rng.randf_range(-w * 0.4, w * 0.4), h + 0.5, _rng.randf_range(-d * 0.4, d * 0.4))
			_box("paint", pos, basis, gp - Vector3(0, 0.2, 0), Vector3(0.7, 0.5, 0.7), Color(0.55, 0.32, 0.2))
			_add("plant", Transform3D(basis * Basis.from_scale(Vector3.ONE * _rng.randf_range(0.8, 1.6)), pos + basis * (gp + Vector3(0, 0.6, 0))),
				Color(0.2 + _rng.randf() * 0.15, 0.45 + _rng.randf() * 0.2, 0.18))
	if bool(roof.get("laundry", false)):
		_laundry_line(pos, basis, Vector3(-w * 0.3, h + 1.7, d * 0.2), Vector3(w * 0.3, h + 1.7, d * 0.2))
	if bool(roof.get("dish", false)):
		var dp := pos + basis * Vector3(-w * 0.4, h + 1.2, -d * 0.4)
		_add("dish", Transform3D(basis * Basis(Vector3(1, 0, 0), 1.1) * Basis.from_scale(Vector3(0.9, 0.06, 0.9)), dp))


func _laundry_line(pos: Vector3, basis: Basis, a: Vector3, b: Vector3) -> void:
	var n := _rng.randi_range(4, 8)
	for i in n:
		var t := (i + 0.5) / n
		var lp := a.lerp(b, t) + Vector3(0, -0.45, 0)
		var size := Vector3(_rng.randf_range(0.5, 0.9), _rng.randf_range(0.6, 1.1), 1.0)
		var dir := (b - a).normalized()
		var yaw := atan2(-dir.z, dir.x)
		_add("laundry", Transform3D(basis * Basis(Vector3.UP, yaw) * Basis.from_scale(size), pos + basis * lp),
			CLOTH_COLORS[_rng.randi_range(0, CLOTH_COLORS.size() - 1)])


func _balconies(pos: Vector3, basis: Basis, w: float, d: float, floors: int, storey: float, col: Color, bseed: float) -> void:
	var nb := maxi(1, int(round(w / 3.2)))
	var bw := w / nb
	var pattern := int(bseed * 7.0) % 3
	for f in range(1, floors):
		for k in nb:
			var on := (k + pattern) % 2 == 0 if nb > 2 else k == 0
			if not on:
				continue
			var x := -w * 0.5 + (k + 0.5) * bw
			var y := f * storey
			_box("slab", pos, basis, Vector3(x, y + 0.07, d * 0.5 + 0.6), Vector3(bw - 0.3, 0.14, 1.2), col.darkened(0.12))
			_box("grille", pos, basis, Vector3(x, y + 0.6, d * 0.5 + 1.18), Vector3(bw - 0.3, 1.0, 0.05))
			for s in [-1.0, 1.0]:
				_box("grille", pos, basis, Vector3(x + s * (bw - 0.3) * 0.5, y + 0.6, d * 0.5 + 0.6), Vector3(0.05, 1.0, 1.15))
			if _rng.randf() < 0.18:
				_laundry_line(pos, basis, Vector3(x - bw * 0.35, y + 2.1, d * 0.5 + 0.9), Vector3(x + bw * 0.35, y + 2.1, d * 0.5 + 0.9))
			if _rng.randf() < 0.2:
				_add("plant", Transform3D(basis * Basis.from_scale(Vector3.ONE * 0.6), pos + basis * Vector3(x + bw * 0.3, y + 0.5, d * 0.5 + 0.9)),
					Color(0.22, 0.5, 0.2))


func _shopfront(b: Dictionary, pos: Vector3, basis: Basis, w: float, d: float, storey: float) -> void:
	var sign_y := storey * 0.78 + 0.45
	var sc: Color = SIGN_COLORS[absi(hash(String(b["id"]))) % SIGN_COLORS.size()]
	var g := float(city.power_group(String(b["district"])))
	_box("sign", pos, basis, Vector3(0, sign_y, d * 0.5 + 0.12), Vector3(w * 0.88, 0.8, 0.14), sc, Basis.IDENTITY, Color(g, 0, 0, 0))
	var shop := String(b.get("shop", ""))
	if shop in ["tea", "hotel", "grocery", "sweets", "hardware", "phone"] and _rng.randf() < 0.7:
		_box("awning", pos, basis, Vector3(0, storey * 0.72, d * 0.5 + 0.9), Vector3(w * 0.8, 0.05, 1.7), Color.WHITE, Basis(Vector3(1, 0, 0), 0.25))
	var sign: Variant = b.get("sign", null)
	if typeof(sign) == TYPE_DICTIONARY:
		var lbl := Label3D.new()
		lbl.text = Game.text(sign)
		lbl.font = _sign_font
		lbl.font_size = 56
		lbl.pixel_size = 0.0055
		lbl.outline_size = 10
		lbl.modulate = Color(1, 1, 1) if sc.get_luminance() < 0.55 else Color(0.08, 0.08, 0.1)
		lbl.outline_modulate = Color(0, 0, 0, 0.6) if sc.get_luminance() < 0.55 else Color(1, 1, 1, 0.3)
		lbl.width = (w * 0.84) / lbl.pixel_size
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.double_sided = false
		lbl.visibility_range_end = 70.0
		lbl.transform = Transform3D(basis, pos + basis * Vector3(0, sign_y, d * 0.5 + 0.2))
		_chunk_node(_ckey(lbl.transform.origin)).add_child(lbl)


func _mosque(pos: Vector3, basis: Basis, w: float, d: float, h: float) -> void:
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = minf(w, d) * 0.32
	sm.height = minf(w, d) * 0.64
	sm.is_hemisphere = true
	dome.mesh = sm
	dome.material_override = _plain(Color(0.9, 0.92, 0.88), 0.5)
	dome.position = pos + Vector3(0, h + 0.7, 0)
	add_child(dome)
	var mp := pos + basis * Vector3(w * 0.5 - 1.5, 0, -d * 0.5 + 1.5)
	_add("tank_concrete", Transform3D(Basis.from_scale(Vector3(1.6, h + 9.0, 1.6)), mp + Vector3(0, (h + 9.0) * 0.5, 0)), Color(0.92, 0.92, 0.9))
	_add("tank_concrete", Transform3D(Basis.from_scale(Vector3(2.4, 0.5, 2.4)), mp + Vector3(0, h + 6.0, 0)))
	_collide_cyl(mp + Vector3(0, (h + 9.0) * 0.5, 0), 0.8, h + 9.0)


func _tower_details(pos: Vector3, basis: Basis, w: float, d: float, h: float, storey: float, with_roof: bool = true) -> void:
	# two light wells on the roof (photos p104-p106) and a stair/lift head room with a steel ladder
	if with_roof:
		for s in [-1.0, 1.0]:
			_box("dark", pos, basis, Vector3(s * w * 0.2, h + 0.02, 0), Vector3(2.0, 0.06, 3.0))
			_box("grille", pos, basis, Vector3(s * w * 0.2, h + 0.5, 0), Vector3(2.2, 1.0, 3.2))
		_box("paint", pos, basis, Vector3(-w * 0.3, h + 1.8, -d * 0.3), Vector3(5.0, 3.6, 4.0), Color(0.86, 0.86, 0.84))
		_box("paint", pos, basis, Vector3(-w * 0.3, h + 4.2, -d * 0.3), Vector3(3.0, 1.2, 3.0), Color(0.86, 0.86, 0.84))
	# guard booth at the main gate (photos p84-p86) and the sliding gate frame
	_box("paint", pos, basis, Vector3(w * 0.35, 1.2, d * 0.5 + 2.2), Vector3(1.5, 2.4, 1.5), Color(0.8, 0.82, 0.8))
	_box("grille", pos, basis, Vector3(0, 1.1, d * 0.5 + 3.4), Vector3(4.5, 2.2, 0.08))
	_collide_box(pos + basis * Vector3(w * 0.35, 1.2, d * 0.5 + 2.2), basis, Vector3(1.5, 2.4, 1.5))


## Ground floor that can be walked into: walls with a door gap, a ceiling, a tiled floor, furniture, a tube light.
func _interior(b: Dictionary, pos: Vector3, basis: Basis, w: float, d: float, storey: float, col: Color) -> void:
	var t := 0.22
	var wc := col.darkened(0.04)
	# back and sides
	_wall(pos, basis, Vector3(0, storey * 0.5, -d * 0.5 + t * 0.5), Vector3(w, storey, t), wc, false, 0.0)
	_wall(pos, basis, Vector3(-w * 0.5 + t * 0.5, storey * 0.5, 0), Vector3(t, storey, d), wc, false, 0.0)
	_wall(pos, basis, Vector3(w * 0.5 - t * 0.5, storey * 0.5, 0), Vector3(t, storey, d), wc, false, 0.0)
	# front with a 2.4 m doorway and a lintel
	var gap := 2.4
	var half := (w - gap) * 0.5
	for s in [-1.0, 1.0]:
		var c := Vector3(s * (gap * 0.5 + half * 0.5), storey * 0.5, d * 0.5 - t * 0.5)
		_box("paint", pos, basis, c, Vector3(half, storey, t), wc)
		_collide_box(pos + basis * c, basis, Vector3(half, storey, t))
	_box("paint", pos, basis, Vector3(0, storey - 0.4, d * 0.5 - t * 0.5), Vector3(gap, 0.8, t), wc)
	# ceiling slab and floor tiles
	_box("slab", pos, basis, Vector3(0, storey - 0.08, 0), Vector3(w, 0.16, d), Color(0.9, 0.9, 0.88))
	_collide_box(pos + basis * Vector3(0, storey - 0.08, 0), basis, Vector3(w, 0.16, d))
	_box("paint", pos, basis, Vector3(0, 0.03, 0), Vector3(w - 0.4, 0.06, d - 0.4), Color(0.78, 0.76, 0.72))
	# furniture by landmark
	var lm := String(b.get("landmark", ""))
	match lm:
		"mess":
			_box("paint", pos, basis, Vector3(-w * 0.3, 0.3, -d * 0.25), Vector3(1.2, 0.5, 2.0), Color(0.45, 0.3, 0.2))   # bed
			_box("cloth", pos, basis, Vector3(-w * 0.3, 0.6, -d * 0.25), Vector3(1.1, 0.12, 1.9), Color(0.3, 0.4, 0.75))
			_box("paint", pos, basis, Vector3(w * 0.25, 0.4, -d * 0.35), Vector3(1.4, 0.8, 0.7), Color(0.4, 0.28, 0.18))  # desk
			_box("cloth", pos, basis, Vector3(w * 0.25, 0.85, -d * 0.35), Vector3(0.9, 0.12, 0.5), Color(0.9, 0.85, 0.7))  # books
			_box("paint", pos, basis, Vector3(w * 0.4, 0.95, 0), Vector3(0.5, 1.9, 1.4), Color(0.5, 0.36, 0.24))         # shelf
		"coaching", "college", "dania_college":
			for r in 4:
				for c in 3:
					_box("paint", pos, basis, Vector3(-w * 0.3 + c * w * 0.3, 0.4, -d * 0.25 + r * 1.6), Vector3(w * 0.22, 0.75, 0.5), Color(0.55, 0.4, 0.26))
			_box("paint", pos, basis, Vector3(0, 1.5, -d * 0.5 + 0.3), Vector3(w * 0.4, 1.2, 0.06), Color(0.95, 0.95, 0.95))
		"cyber", "library", "lawyer", "college_admin", "police_station", "clinic":
			for c in 3:
				_box("paint", pos, basis, Vector3(-w * 0.3 + c * w * 0.3, 0.4, -d * 0.2), Vector3(w * 0.2, 0.75, 0.7), Color(0.5, 0.36, 0.24))
				_box("dark", pos, basis, Vector3(-w * 0.3 + c * w * 0.3, 1.0, -d * 0.25), Vector3(0.45, 0.35, 0.05))
			_box("paint", pos, basis, Vector3(w * 0.4, 1.0, 0), Vector3(0.4, 2.0, d * 0.6), Color(0.45, 0.32, 0.2))
		"superstore":
			for r in 3:
				_box("paint", pos, basis, Vector3(-w * 0.25 + r * w * 0.25, 0.9, -d * 0.1), Vector3(0.5, 1.8, d * 0.6), Color(0.6, 0.6, 0.62))
		"tower":
			# parking: a 5.5 m column grid, 2.8 m clear (photos p87-p96)
			var nx := int(w / 5.5)
			var nz := int(d / 5.5)
			for i in nx:
				for j in nz:
					var cp := Vector3(-w * 0.5 + (i + 0.75) * 5.5, storey * 0.5, -d * 0.5 + (j + 0.75) * 5.5)
					_box("paint", pos, basis, cp, Vector3(0.6, storey, 0.6), Color(0.92, 0.92, 0.9))
					_collide_box(pos + basis * cp, basis, Vector3(0.6, storey, 0.6))
			_box("metal", pos, basis, Vector3(-w * 0.2, 0.75, 0), Vector3(1.8, 1.4, 4.2), Color(0.5, 0.52, 0.56))   # covered car
			_box("metal", pos, basis, Vector3(w * 0.2, 0.75, -3), Vector3(1.8, 1.4, 4.2), Color(0.75, 0.75, 0.72))
			_box("paint", pos, basis, Vector3(-w * 0.4, 0.7, -d * 0.4), Vector3(2.6, 1.4, 1.1), Color(0.3, 0.42, 0.34))  # generator
	# a tube light
	var light := OmniLight3D.new()
	light.light_color = Color(0.9, 0.96, 1.0)
	light.light_energy = 1.6
	light.omni_range = maxf(w, d) * 0.75
	light.shadow_enabled = false
	light.position = pos + basis * Vector3(0, storey - 0.4, 0)
	_chunk_node(_ckey(light.position)).add_child(light)
	interior_lights.append(light)


func _shack(pos: Vector3, basis: Basis, w: float, d: float, col: Color) -> void:
	# tin-walled single room with a sloped tin roof (Jurain, beside the rail line)
	_box("tin", pos, basis, Vector3(0, 1.25, 0), Vector3(w, 2.5, d), Color(1, 1, 1))
	_box("tin", pos, basis, Vector3(0, 2.7, 0), Vector3(w + 0.6, 0.06, d + 0.8), Color(1, 1, 1), Basis(Vector3(1, 0, 0), 0.12))
	_box("dark", pos, basis, Vector3(w * 0.2, 1.0, d * 0.5 + 0.02), Vector3(0.9, 1.9, 0.04))
	_collide_box(pos + basis * Vector3(0, 1.25, 0), basis, Vector3(w, 2.5, d))


func _backdrop() -> void:
	# a ring of far city beyond the map edge, so the horizon is full of buildings
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spots: Array = []
	for i in 70:
		spots.append(Vector3(rng.randf_range(-60, city.width + 60), 0, rng.randf_range(-170, -40)))
		spots.append(Vector3(rng.randf_range(-60, city.width + 60), 0, rng.randf_range(city.height + 40, city.height + 170)))
	for i in 55:
		spots.append(Vector3(rng.randf_range(-170, -40), 0, rng.randf_range(-60, city.height + 60)))
		spots.append(Vector3(rng.randf_range(city.width + 40, city.width + 170), 0, rng.randf_range(-60, city.height + 60)))
	for p in spots:
		var w := rng.randf_range(14, 30)
		var d := rng.randf_range(14, 26)
		var floors := rng.randi_range(5, 14)
		var h := floors * 3.0
		var col := Color(rng.randf_range(0.75, 0.95), rng.randf_range(0.72, 0.92), rng.randf_range(0.68, 0.9))
		_box("facade", p, Basis(Vector3.UP, rng.randf() * 0.6), Vector3(0, h * 0.5, 0), Vector3(w, h, d), col, Basis.IDENTITY,
			Color(3.0, -1.0, 0.0, rng.randf()))


# =============================================================================================
# Trees, lamps, poles and wires, street props
# =============================================================================================

func _trees() -> void:
	for t in city.data.get("trees", []):
		var ta: Array = t
		var p := Vector3(float(ta[0]), 0.0, float(ta[1]))
		var r := float(ta[2])
		var trunk_h := r * 1.3 + 1.5
		_add("trunk", Transform3D(Basis.from_scale(Vector3(0.45, trunk_h, 0.45)), p + Vector3(0, trunk_h * 0.5, 0)))
		_collide_cyl(p + Vector3(0, trunk_h * 0.5, 0), 0.25, trunk_h)
		var green := Color(0.18 + _rng.randf() * 0.1, 0.36 + _rng.randf() * 0.16, 0.14 + _rng.randf() * 0.06)
		for k in 3:
			var off := Vector3(_rng.randf_range(-r, r) * 0.5, trunk_h + _rng.randf_range(0.0, r * 0.6), _rng.randf_range(-r, r) * 0.5)
			var s := r * _rng.randf_range(1.2, 1.7)
			_add("canopy", Transform3D(Basis.from_scale(Vector3(s, s * 0.75, s)), p + off), green.lightened(_rng.randf() * 0.1))


func _lamps() -> void:
	for l in city.lamps:
		var la: Array = l
		var p := Vector3(float(la[0]), 0.0, float(la[1]))
		var group := city.power_group(String(la[2]))
		_add("lamp_pole", Transform3D(Basis.from_scale(Vector3(0.16, 7.0, 0.16)), p + Vector3(0, 3.5, 0)))
		var head := p + Vector3(0, 7.0, 0)
		_add("lamp_head", Transform3D(Basis.from_scale(Vector3(0.6, 0.18, 0.3)), head), Color.WHITE, Color(group, 0, 0, 0))
		lamp_heads.append(head)
		lamp_groups.append(group)


func _poles_and_wires() -> void:
	for chain in city.data.get("poles", []):
		var ch: Array = chain
		var prev := Vector3.INF
		for pt in ch:
			var pa: Array = pt
			var p := Vector3(float(pa[0]), 0.0, float(pa[1]))
			_add("pole", Transform3D(Basis.from_scale(Vector3(0.24, 9.0, 0.24)), p + Vector3(0, 4.5, 0)))
			_add("pole", Transform3D(Basis.from_scale(Vector3(1.4, 0.12, 0.12)), p + Vector3(0, 8.4, 0)))
			_add("dark", Transform3D(Basis.from_scale(Vector3(0.5, 0.35, 0.5)), p + Vector3(0, 7.2, 0)))   # cable knot
			if prev != Vector3.INF:
				for k in 5:
					var y := 7.0 + k * 0.32
					var off: Vector3 = Vector3(0, 0, (k - 2) * 0.25)
					_wire(prev + Vector3(0, y, 0) + off, p + Vector3(0, y, 0) + off, 0.5 + k * 0.12)
			prev = p


func _props() -> void:
	for pr in city.data.get("props", []):
		var pd: Dictionary = pr
		var kind := String(pd["kind"])
		var p := Vector3(float(pd["x"]), 0.0, float(pd["z"]))
		var basis := Basis(Vector3.UP, -float(pd["rot"]))
		match kind:
			"tea_stall":
				_stall(p, basis, 0)
				for s in [-1.0, 1.0]:
					_box("paint", p, basis, Vector3(s * 1.8, 0.25, 1.6), Vector3(1.6, 0.45, 0.35), Color(0.45, 0.3, 0.2))   # benches
				_add("tank_black", Transform3D(basis * Basis.from_scale(Vector3(0.3, 0.35, 0.3)), p + basis * Vector3(0.4, 1.15, 0)))  # kettle
			"fruit_cart":
				_box("paint", p, basis, Vector3(0, 0.85, 0), Vector3(1.8, 0.15, 1.0), Color(0.5, 0.36, 0.22))
				for s in [-1.0, 1.0]:
					_add("wheel", Transform3D(basis * Basis(Vector3(1, 0, 0), PI * 0.5) * Basis.from_scale(Vector3(0.8, 0.08, 0.8)), p + basis * Vector3(s * 0.6, 0.4, 0.55)))
				for i in 10:
					_add("fruit", Transform3D(Basis.from_scale(Vector3.ONE * 0.22), p + basis * Vector3(_rng.randf_range(-0.7, 0.7), 1.02, _rng.randf_range(-0.35, 0.35))),
						[Color(0.95, 0.75, 0.1), Color(0.3, 0.6, 0.15), Color(0.85, 0.2, 0.15), Color(0.95, 0.5, 0.1)][i % 4])
				_collide_box(p + Vector3(0, 0.6, 0), basis, Vector3(1.8, 1.2, 1.0))
			"rickshaw_stand":
				for i in _rng.randi_range(2, 4):
					_rickshaw(p + basis * Vector3(i * 1.3 - 1.5, 0, 0), basis * Basis(Vector3.UP, _rng.randf_range(-0.3, 0.3)))
			"garbage":
				for i in 6:
					_add("garbage", Transform3D(Basis.from_scale(Vector3(_rng.randf_range(0.5, 1.0), _rng.randf_range(0.3, 0.6), _rng.randf_range(0.5, 1.0))),
						p + Vector3(_rng.randf_range(-0.8, 0.8), 0.15, _rng.randf_range(-0.8, 0.8))),
						[Color(0.2, 0.18, 0.15), Color(0.85, 0.85, 0.82), Color(0.2, 0.35, 0.7), Color(0.75, 0.2, 0.2), Color(0.3, 0.28, 0.22)][i % 5])
			"bench":
				_box("paint", p, basis, Vector3(0, 0.45, 0), Vector3(1.8, 0.08, 0.45), Color(0.4, 0.3, 0.22))
				_box("paint", p, basis, Vector3(0, 0.22, 0), Vector3(1.6, 0.44, 0.1), Color(0.35, 0.26, 0.2))
			"banner":
				var bw := float(pd.get("width", 10.0))
				for s in [-1.0, 1.0]:
					_add("pole", Transform3D(Basis.from_scale(Vector3(0.12, 6.0, 0.12)), p + basis * Vector3(0, 3.0, s * bw * 0.5)))
				_box("cloth", p, basis, Vector3(0, 4.8, 0), Vector3(0.04, 1.1, bw * 0.9), CLOTH_COLORS[_rng.randi_range(0, 3)])


func _stall(p: Vector3, basis: Basis, variant: int) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box("metal", p, basis, Vector3(sx * 1.4, 1.2, sz * 0.9), Vector3(0.06, 2.4, 0.06), Color(0.3, 0.3, 0.32))
	_box("tin", p, basis, Vector3(0, 2.45, 0), Vector3(3.4, 0.05, 2.4), Color.WHITE, Basis(Vector3(1, 0, 0), 0.1))
	_box("paint", p, basis, Vector3(0, 0.5, -0.4), Vector3(2.6, 1.0, 0.8), Color(0.55, 0.38, 0.24))
	_box("awning", p, basis, Vector3(0, 2.2, 1.4), Vector3(3.0, 0.04, 0.8), Color.WHITE, Basis(Vector3(1, 0, 0), 0.5))
	_collide_box(p + basis * Vector3(0, 0.5, -0.4), basis, Vector3(2.6, 1.0, 0.8))
	if variant < 0:
		return


func _rickshaw(p: Vector3, basis: Basis) -> void:
	var paint: Color = CLOTH_COLORS[_rng.randi_range(0, CLOTH_COLORS.size() - 1)]
	for s in [-1.0, 1.0]:
		_add("wheel", Transform3D(basis * Basis(Vector3(0, 0, 1), PI * 0.5) * Basis.from_scale(Vector3(0.7, 0.05, 0.7)), p + basis * Vector3(s * 0.55, 0.35, -0.4)))
	_add("wheel", Transform3D(basis * Basis(Vector3(0, 0, 1), PI * 0.5) * Basis.from_scale(Vector3(0.7, 0.05, 0.7)), p + basis * Vector3(0, 0.35, 1.3)))
	_box("metal", p, basis, Vector3(0, 0.75, -0.35), Vector3(1.1, 0.22, 0.55), paint)
	_box("cloth", p, basis, Vector3(0, 1.05, -0.62), Vector3(1.0, 0.5, 0.08), paint.lightened(0.2))
	_box("cloth", p, basis, Vector3(0, 1.75, -0.4), Vector3(1.15, 0.06, 0.95), Color(0.1, 0.1, 0.12), Basis(Vector3(1, 0, 0), -0.25))
	_box("metal", p, basis, Vector3(0, 0.6, 0.45), Vector3(0.08, 0.08, 1.6), Color(0.2, 0.2, 0.22))
	_box("metal", p, basis, Vector3(0, 0.95, 1.05), Vector3(0.3, 0.06, 0.2), Color(0.15, 0.15, 0.15))
	_collide_box(p + basis * Vector3(0, 0.7, 0.3), basis, Vector3(1.2, 1.4, 2.2))


func _bus(p: Vector3, basis: Basis, col: Color) -> void:
	_box("metal", p, basis, Vector3(0, 1.75, 0), Vector3(2.5, 2.7, 10.5), col)
	_box("dark", p, basis, Vector3(0, 2.25, 0), Vector3(2.54, 0.9, 9.6))
	for z in [-3.6, 3.6]:
		for s in [-1.0, 1.0]:
			_add("wheel", Transform3D(basis * Basis(Vector3(0, 0, 1), PI * 0.5) * Basis.from_scale(Vector3(1.0, 0.3, 1.0)), p + basis * Vector3(s * 1.15, 0.5, z)))
	_collide_box(p + basis * Vector3(0, 1.75, 0), basis, Vector3(2.5, 2.7, 10.5))


# =============================================================================================
# Street lamp lights: a pool of real lights moved to the lamps nearest the player at night
# =============================================================================================

func _make_lamp_pool() -> void:
	for i in LAMP_POOL:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.68, 0.36)
		l.omni_range = 15.0
		l.omni_attenuation = 1.3
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_pool.append(l)


## Called by OpenWorld with the lamp brightness (0 day .. 1 night) and a power test per group.
func update_lamps(delta: float, around: Vector3, night: float, power: PackedFloat32Array) -> void:
	_pool_timer -= delta
	if _pool_timer > 0.0:
		return
	_pool_timer = 0.35
	if night < 0.05:
		for l in _pool:
			l.visible = false
		return
	var near := city.lamps_near(around, 70.0)
	near.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as Vector3).distance_squared_to(around) < (b[0] as Vector3).distance_squared_to(around))
	var used := 0
	for item in near:
		if used >= _pool.size():
			break
		var g := city.power_group(String(item[1]))
		if g < power.size() and power[g] < 0.5:
			continue
		var l: OmniLight3D = _pool[used]
		l.position = (item[0] as Vector3) + Vector3(0, 6.7, 0)
		l.light_energy = 2.4 * night
		l.visible = true
		used += 1
	for i in range(used, _pool.size()):
		_pool[i].visible = false
