class_name DhakaMaterials
extends RefCounted
## One place that turns art/textures (made by tools/generate_textures.py) into Godot materials, and
## caches them so a city of a thousand boxes shares a handful of materials.
##
##   surface(DhakaMaterials.BRICK)      triplanar world-space material for LevelBuilder boxes (any size)
##   face("sakib")                      skin material for a head sphere (equirectangular face wrap)
##   pick_face(seed, female, elder)     a face record from faces.json (id, skin and hair colours)
##   cloth("lungi_check_blue")          UV-mapped cloth for Humanoid limbs and lungis
##   awning("tarp_blue")                UV-mapped canopy fabric
##   grille()                           alpha-scissor window grille
##   decal_textures("decal_water_stain") albedo and normal for a Decal node
##
## If a texture is missing (the generator has not been run), every call falls back to plain colours
## so the game still runs. Set use_shader = false to use ORMMaterial3D triplanar instead of the
## custom shader (handy if a driver objects to the shader).

const ROOT := "res://art/textures/"
const SHADER_PATH := "res://shaders/dhaka_surface.gdshader"
const GRIME := "res://art/textures/shared/grime_noise.png"
const FACES_JSON := "res://art/textures/faces/faces.json"

const PAINT := 0
const BRICK := 1
const PLASTER := 2
const CONCRETE := 3
const ASPHALT := 4
const TIN := 5
const TIN_PAINTED := 6
const AWNING := 7
const TILE := 8
const PLASTER_OLD := 9

## Per-surface parameters for the surface shader. tile_m = metres per texture repeat.
const SURFACES := {
	BRICK: {"set": "surfaces/brick_weathered", "tile_m": 0.96, "tint": 0.12, "normal": 1.0, "grime": 0.4, "soot": 0.3, "dust": 0.2},
	PLASTER: {"set": "surfaces/plaster_clean", "tile_m": 2.5, "tint": 0.9, "normal": 0.6, "grime": 0.3, "soot": 0.15, "dust": 0.1},
	PLASTER_OLD: {"set": "surfaces/plaster_peeling", "tile_m": 2.5, "tint": 0.85, "normal": 0.8, "grime": 0.35, "soot": 0.25, "dust": 0.12},
	CONCRETE: {"set": "surfaces/concrete_moss", "tile_m": 2.0, "tint": 0.3, "normal": 1.0, "grime": 0.3, "soot": 0.2, "dust": 0.3},
	ASPHALT: {"set": "surfaces/asphalt_cracked", "tile_m": 4.0, "tint": 0.1, "normal": 1.0, "grime": 0.0, "soot": 0.0, "dust": 0.25},
	TIN: {"set": "surfaces/tin_corrugated_rust", "tile_m": 2.0, "tint": 0.15, "normal": 1.0, "grime": 0.2, "soot": 0.1, "dust": 0.2},
	TIN_PAINTED: {"set": "surfaces/tin_corrugated_painted", "tile_m": 2.0, "tint": 0.25, "normal": 1.0, "grime": 0.2, "soot": 0.1, "dust": 0.2},
	AWNING: {"set": "awnings/tarp_blue", "tile_m": 2.0, "tint": 0.0, "normal": 0.7, "grime": 0.0, "soot": 0.0, "dust": 0.1},
	TILE: {"set": "surfaces/tile_rubber", "tile_m": 1.2, "tint": 0.1, "normal": 0.8, "grime": 0.15, "soot": 0.0, "dust": 0.1},
}
const AWNINGS := ["awning_red_white", "awning_blue_yellow", "awning_green_cream", "tarp_blue", "tarp_orange", "gamchha_check"]

static var use_shader := true
static var _cache: Dictionary = {}
static var _faces: Array = []
static var _faces_loaded := false


static func has_textures() -> bool:
	return ResourceLoader.exists(ROOT + "surfaces/brick_weathered_albedo.png")


static func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


## Material for LevelBuilder boxes. `variant` picks between awning fabrics for AWNING.
static func surface(id: int, variant: int = 0) -> Material:
	var key := "surface_%d_%d" % [id, variant]
	if _cache.has(key):
		return _cache[key]
	var m: Material = null
	if id != PAINT and SURFACES.has(id):
		var sdef: Dictionary = SURFACES[id]
		var set_path := String(sdef["set"])
		if id == AWNING:
			set_path = "awnings/" + AWNINGS[variant % AWNINGS.size()]
		var albedo := _tex(ROOT + set_path + "_albedo.png")
		var normal := _tex(ROOT + set_path + "_normal.png")
		var orm := _tex(ROOT + set_path + "_orm.png")
		if albedo and normal and orm:
			if use_shader and ResourceLoader.exists(SHADER_PATH):
				var sm := ShaderMaterial.new()
				sm.shader = load(SHADER_PATH)
				sm.set_shader_parameter("albedo_tex", albedo)
				sm.set_shader_parameter("normal_tex", normal)
				sm.set_shader_parameter("orm_tex", orm)
				sm.set_shader_parameter("grime_tex", _tex(GRIME))
				sm.set_shader_parameter("tile_m", float(sdef["tile_m"]))
				sm.set_shader_parameter("tint_strength", float(sdef["tint"]))
				sm.set_shader_parameter("normal_strength", float(sdef["normal"]))
				sm.set_shader_parameter("grime_strength", float(sdef["grime"]))
				sm.set_shader_parameter("soot_strength", float(sdef["soot"]))
				sm.set_shader_parameter("dust_strength", float(sdef["dust"]))
				m = sm
			else:
				var om := ORMMaterial3D.new()
				om.albedo_texture = albedo
				om.normal_enabled = true
				om.normal_texture = normal
				om.orm_texture = orm
				om.metallic = 1.0
				om.vertex_color_use_as_albedo = float(sdef["tint"]) > 0.5
				om.uv1_triplanar = true
				om.uv1_world_triplanar = true
				om.uv1_triplanar_sharpness = 6.0
				om.uv1_scale = Vector3.ONE / float(sdef["tile_m"])
				om.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				m = om
	if m == null:
		var pm := StandardMaterial3D.new()
		pm.vertex_color_use_as_albedo = true
		pm.roughness = 0.9
		m = pm
	_cache[key] = m
	return m


## Skin for a head sphere. The face sits at u = 0.5 (the -Z side, where Godot nodes look).
static func face(face_id: String) -> Material:
	var key := "face_" + face_id
	if _cache.has(key):
		return _cache[key]
	var base := ROOT + "faces/face_" + face_id
	var albedo := _tex(base + "_albedo.png")
	if albedo == null:
		return null
	var m := ORMMaterial3D.new()
	m.albedo_texture = albedo
	m.normal_enabled = true
	m.normal_texture = _tex(base + "_normal.png")
	m.normal_scale = 0.8
	m.orm_texture = _tex(base + "_orm.png")
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_skin_mode = true
	m.subsurf_scatter_strength = 0.28
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.45
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m


static func faces() -> Array:
	if not _faces_loaded:
		_faces_loaded = true
		if FileAccess.file_exists(FACES_JSON):
			var data = JSON.parse_string(FileAccess.get_file_as_string(FACES_JSON))
			if typeof(data) == TYPE_DICTIONARY:
				_faces = data.get("faces", [])
	return _faces


## A face for a crowd member or NPC. Sakib's own face is never handed out.
static func pick_face(seed_value: int, female: bool, elder: bool) -> Dictionary:
	var pool: Array = []
	for f in faces():
		if String(f["id"]) == "sakib" or bool(f["female"]) != female:
			continue
		if elder != (int(f["age"]) >= 55):
			continue
		pool.append(f)
	if pool.is_empty():
		for f in faces():
			if String(f["id"]) != "sakib" and bool(f["female"]) == female:
				pool.append(f)
	if pool.is_empty():
		return {}
	return pool[absi(seed_value) % pool.size()]


static func face_record(face_id: String) -> Dictionary:
	for f in faces():
		if String(f["id"]) == face_id:
			return f
	return {}


## UV-mapped cloth (lungi checks, panjabi cotton, shirt check, kameez prints).
static func cloth(cloth_name: String, uv_scale := Vector3(2, 2, 1)) -> Material:
	return _uv_material("cloth/" + cloth_name, uv_scale, false)


static func awning(awning_name: String, uv_scale := Vector3(1, 1, 1)) -> Material:
	return _uv_material("awnings/" + awning_name, uv_scale, false)


static func grille() -> Material:
	return _uv_material("cutouts/grille_steel", Vector3(1, 1, 1), true)


static func _uv_material(set_path: String, uv_scale: Vector3, cutout: bool) -> Material:
	var key := "uv_%s_%s" % [set_path, uv_scale]
	if _cache.has(key):
		return _cache[key]
	var albedo := _tex(ROOT + set_path + "_albedo.png")
	if albedo == null:
		return null
	var m := ORMMaterial3D.new()
	m.albedo_texture = albedo
	m.normal_enabled = true
	m.normal_texture = _tex(ROOT + set_path + "_normal.png")
	m.orm_texture = _tex(ROOT + set_path + "_orm.png")
	m.metallic = 1.0
	m.uv1_scale = uv_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if cutout:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


static func decal_textures(decal_name: String) -> Dictionary:
	return {"albedo": _tex(ROOT + "decals/" + decal_name + "_albedo.png"),
		"normal": _tex(ROOT + "decals/" + decal_name + "_normal.png"),
		"orm": _tex(ROOT + "decals/" + decal_name + "_orm.png")}
