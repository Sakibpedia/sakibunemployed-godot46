class_name BuildingMaterials
extends RefCounted
## Materials for the generated interiors.  They are shared across every interior so a flat costs a
## handful of materials, not one per wall.  Surface sets come from DhakaMaterials where a real
## texture exists (plaster, concrete, tile, cloth); the rest are simple PBR colours with a little
## procedural grain so large painted walls do not look like flat plastic.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

static var _cache: Dictionary = {}


static func _cached(key: String, maker: Callable) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material = maker.call()
	_cache[key] = m
	return m


static func wall() -> Material:
	return _cached("wall", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.82, 0.80, 0.74)
		m.roughness = 0.92
		m.metallic_specular = 0.18
		return m)


static func wall_colored(col: Color) -> Material:
	var key := "wall_%s" % col.to_html()
	return _cached(key, func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.92
		m.metallic_specular = 0.18
		return m)


static func bathroom_wall() -> Material:
	return _cached("bathwall", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.88, 0.91, 0.90)
		m.roughness = 0.22
		m.metallic_specular = 0.55
		return m)


static func floor_tile() -> Material:
	return _cached("floor_tile", func() -> Material:
		var src := DhakaMaterials.surface(DhakaMaterials.TILE)
		return src if src != null else _plain(Color(0.62, 0.60, 0.56), 0.55))


static func floor_wood() -> Material:
	return _cached("floor_wood", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.38, 0.23, 0.14)
		m.roughness = 0.62
		m.albedo_texture = _wood_texture()
		m.uv1_scale = Vector3(1.2, 1.2, 1.2)
		return m)


static func concrete() -> Material:
	return _cached("concrete", func() -> Material:
		var src := DhakaMaterials.surface(DhakaMaterials.CONCRETE)
		return src if src != null else _plain(Color(0.55, 0.54, 0.5), 0.9))


static func plaster_old() -> Material:
	return _cached("plaster_old", func() -> Material:
		var src := DhakaMaterials.surface(DhakaMaterials.PLASTER_OLD)
		return src if src != null else _plain(Color(0.72, 0.69, 0.62), 0.95))


static func wood(tint: Color = Color(0.42, 0.26, 0.15)) -> Material:
	var key := "wood_%s" % tint.to_html()
	return _cached(key, func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = tint
		m.albedo_texture = _wood_texture()
		m.roughness = 0.58
		m.uv1_scale = Vector3(1.4, 1.4, 1.4)
		return m)


static func metal(tint: Color = Color(0.52, 0.54, 0.56)) -> Material:
	var key := "metal_%s" % tint.to_html()
	return _cached(key, func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = tint
		m.metallic = 0.78
		m.roughness = 0.34
		return m)


static func painted_metal(tint: Color) -> Material:
	var key := "pmetal_%s" % tint.to_html()
	return _cached(key, func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = tint
		m.metallic = 0.35
		m.roughness = 0.45
		return m)


static func glass() -> Material:
	return _cached("glass", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.76, 0.82, 0.20)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.04
		m.metallic_specular = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		return m)


static func mirror() -> Material:
	return _cached("mirror", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.78, 0.82, 0.84)
		m.metallic = 1.0
		m.roughness = 0.04
		return m)


static func fabric(col: Color) -> Material:
	var key := "fabric_%s" % col.to_html()
	return _cached(key, func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.95
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)


static func curtain(col: Color) -> Material:
	var key := "curtain_%s" % col.to_html()
	return _cached(key, func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.9
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.82
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)


static func ceramic() -> Material:
	return _cached("ceramic", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.93, 0.94, 0.92)
		m.roughness = 0.12
		m.metallic_specular = 0.6
		return m)


static func plastic(col: Color) -> Material:
	var key := "plastic_%s" % col.to_html()
	return _cached(key, func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.35
		return m)


static func rubber() -> Material:
	return _cached("rubber", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.06, 0.06, 0.07)
		m.roughness = 0.85
		return m)


static func dark() -> Material:
	return _cached("dark", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.045, 0.045, 0.055)
		m.roughness = 0.8
		return m)


static func paper() -> Material:
	return _cached("paper", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.90, 0.82)
		m.roughness = 0.95
		return m)


static func leaf() -> Material:
	return _cached("leaf", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.18, 0.42, 0.16)
		m.roughness = 0.8
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)


static func water() -> Material:
	return _cached("water", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.24, 0.44, 0.52, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic = 0.1
		return m)


static func emissive(col: Color, energy: float = 2.2) -> Material:
	var key := "em_%s_%.2f" % [col.to_html(), energy]
	return _cached(key, func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = energy
		m.roughness = 0.4
		return m)


static func gold() -> Material:
	return _cached("gold", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.86, 0.66, 0.24)
		m.metallic = 0.95
		m.roughness = 0.22
		return m)


static func _plain(col: Color, rough: float) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


static func _wood_texture() -> Texture2D:
	if _cache.has("wood_tex"):
		return _cache["wood_tex"]
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var grain := sin(float(x) * 0.42 + sin(float(y) * 0.11) * 4.0) * 0.5 + 0.5
			var fine := sin(float(y) * 1.7 + float(x) * 0.03) * 0.12
			var v := clampf(0.42 + grain * 0.22 + fine, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.72, v * 0.5))
	var tex := ImageTexture.create_from_image(img)
	tex.set_meta("generated", true)
	_cache["wood_tex"] = tex
	return tex
