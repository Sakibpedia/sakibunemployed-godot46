class_name CityMap
extends Control
## The city map, drawn once into a texture from CityData (roads, buildings, water, parks, rail,
## flyover), then used by the radar (rotating with the camera) and the full map screen.
## Blips: player, mission marker, waypoint, points of interest, police, ghosts.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const PX_PER_M := 1.4

static var _texture: Texture2D = null
static var _viewport: SubViewport = null

var city: CityData
var full := false              # false: radar, true: full map screen
var zoom := 1.0
var waypoint := Vector3.INF
var mission_target := Vector3.INF


## Builds the map texture once (a SubViewport rendered a single time).
static func build_texture(c: CityData, host: Node) -> Texture2D:
	if _texture != null:
		return _texture
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(c.width * PX_PER_M), int(c.height * PX_PER_M))
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(_viewport)
	var drawer := _MapDrawer.new()
	drawer.city = c
	drawer.size = Vector2(_viewport.size)
	_viewport.add_child(drawer)
	_texture = _viewport.get_texture()
	return _texture


static func forget() -> void:
	_texture = null
	_viewport = null


class _MapDrawer:
	extends Control
	var city: CityData

	func _draw() -> void:
		var s := CityMap.PX_PER_M
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.19, 0.17))
		for a in city.data.get("landmark_areas", []):
			var ad: Dictionary = a
			var col := Color(0.24, 0.38, 0.2) if String(ad["id"]) in ["college_field", "graveyard"] else Color(0.3, 0.3, 0.32)
			draw_colored_polygon(_rect_poly(float(ad["x"]), float(ad["z"]), float(ad["w"]), float(ad["d"]), float(ad["rot"]), s), col)
		for p in city.data.get("ponds", []):
			var r: Array = (p as Dictionary)["rect"]
			draw_rect(Rect2(Vector2(float(r[0]), float(r[1])) * s, Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1])) * s), Color(0.2, 0.42, 0.55))
		for r in city.roads:
			var rd: Dictionary = r
			var pts: Array = rd["points"]
			var col2 := Color(0.62, 0.62, 0.6) if String(rd["kind"]) == "highway" else (Color(0.5, 0.5, 0.5) if String(rd["kind"]) == "main" else Color(0.42, 0.42, 0.42))
			for i in pts.size() - 1:
				draw_line(Vector2(float(pts[i][0]), float(pts[i][1])) * s, Vector2(float(pts[i + 1][0]), float(pts[i + 1][1])) * s, col2,
					maxf(1.5, (float(rd["width"]) + float(rd.get("sidewalk", 0.0)) * 2.0) * s), true)
		for rl in city.data.get("rail", []):
			var rp: Array = (rl as Dictionary)["points"]
			draw_line(Vector2(float(rp[0][0]), float(rp[0][1])) * s, Vector2(float(rp[1][0]), float(rp[1][1])) * s, Color(0.5, 0.38, 0.28), 4.0)
		for b in city.buildings:
			var bd: Dictionary = b
			var c := Color(0.27, 0.3, 0.3) if String(bd.get("landmark", "")) == "" else Color(0.75, 0.55, 0.22)
			draw_colored_polygon(_rect_poly(float(bd["x"]), float(bd["z"]), float(bd["w"]), float(bd["d"]), float(bd["rot"]), s), c)
		for f in city.data.get("flyovers", []):
			var fp: Array = (f as Dictionary)["points"]
			for i in fp.size() - 1:
				draw_line(Vector2(float(fp[i][0]), float(fp[i][1])) * s, Vector2(float(fp[i + 1][0]), float(fp[i + 1][1])) * s,
					Color(0.8, 0.8, 0.82, 0.85), float((f as Dictionary)["width"]) * s * 0.8, true)

	func _rect_poly(cx: float, cz: float, w: float, d: float, rot: float, s: float) -> PackedVector2Array:
		var c := cos(rot)
		var si := sin(rot)
		var out := PackedVector2Array()
		for uv: Vector2 in [Vector2(-w, -d), Vector2(w, -d), Vector2(w, d), Vector2(-w, d)]:
			var u := uv.x * 0.5
			var v := uv.y * 0.5
			out.append(Vector2(cx + u * c - v * si, cz + u * si + v * c) * s)
		return out


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if city == null or _texture == null:
		return
	var p: Node3D = Services.player
	if p == null:
		return
	var pp := Vector2(p.global_position.x, p.global_position.z) * PX_PER_M
	var centre := size * 0.5
	var rot := 0.0
	var sc := zoom
	if full:
		sc = minf(size.x / (city.width * PX_PER_M), size.y / (city.height * PX_PER_M))
		var off := (size - Vector2(city.width, city.height) * PX_PER_M * sc) * 0.5
		draw_set_transform(off, 0.0, Vector2(sc, sc))
		draw_texture(_texture, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_blips(func(w: Vector3) -> Vector2: return off + Vector2(w.x, w.z) * PX_PER_M * sc, 1.6)
		var pl: Vector2 = off + pp * sc
		_arrow(pl, -float(p.get("yaw")) if p.get("yaw") != null else 0.0, 12.0)
		return
	if p.get("yaw") != null:
		rot = float(p.get("yaw"))
	draw_set_transform(centre, rot, Vector2(sc, sc))
	draw_texture(_texture, -pp)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var to_screen := func(w: Vector3) -> Vector2:
		var d := (Vector2(w.x, w.z) * PX_PER_M - pp) * sc
		return centre + d.rotated(rot)
	_blips(to_screen, 1.0)
	_arrow(centre, 0.0, 9.0)
	# edge fade ring
	draw_arc(centre, minf(size.x, size.y) * 0.5 - 2.0, 0.0, TAU, 64, Color(0.04, 0.08, 0.1, 0.9), 5.0, true)


func _clamp_to_radar(v: Vector2) -> Vector2:
	if full:
		return v
	var centre := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 10.0
	var d := v - centre
	if d.length() > r:
		return centre + d.normalized() * r
	return v


func _blips(to_screen: Callable, scale_: float) -> void:
	var f := UiKit.font(true)
	for k in city.pois:
		var poi: Dictionary = city.pois[k]
		var kind := String(poi.get("kind", ""))
		if kind in ["roof", "exam", "shed"]:
			continue
		var v: Vector2 = to_screen.call(Vector3(float(poi["x"]), 0, float(poi["z"])))
		if not full and v.distance_to(size * 0.5) > minf(size.x, size.y) * 0.5 - 8.0:
			continue
		var col := UiKit.TEAL if kind == "home" else UiKit.PAPER
		draw_circle(v, 3.5 * scale_, col)
		if full:
			draw_string(f, v + Vector2(6, 4), Game.text(poi.get("name", {})), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.PAPER)
	for c in get_tree().get_nodes_in_group(&"citizens"):
		var cz := c as Citizen
		if cz == null or not cz.is_alive():
			continue
		var prof := cz.ai.profession()
		if prof == "police" or cz.mission_tag != "":
			var v2: Vector2 = to_screen.call(cz.global_position)
			if full or v2.distance_to(size * 0.5) < minf(size.x, size.y) * 0.5 - 6.0:
				draw_circle(v2, 4.0 * scale_, Color(0.3, 0.5, 1.0) if prof == "police" else UiKit.RED)
	for g in get_tree().get_nodes_in_group(&"ghosts"):
		var v3: Vector2 = to_screen.call((g as Node3D).global_position)
		if full or v3.distance_to(size * 0.5) < minf(size.x, size.y) * 0.5 - 6.0:
			draw_circle(v3, 5.0 * scale_, Color(0.7, 0.9, 1.0, 0.8))
	if mission_target != Vector3.INF:
		var m: Vector2 = _clamp_to_radar(to_screen.call(mission_target))
		draw_circle(m, 7.0 * scale_, UiKit.MARIGOLD)
		draw_circle(m, 3.0 * scale_, UiKit.INK)
	if waypoint != Vector3.INF:
		var w: Vector2 = _clamp_to_radar(to_screen.call(waypoint))
		draw_circle(w, 6.0 * scale_, UiKit.PINK)


func _arrow(at: Vector2, angle: float, s: float) -> void:
	var pts := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.7, s * 0.8), Vector2(0, s * 0.35), Vector2(-s * 0.7, s * 0.8)])
	var out := PackedVector2Array()
	for p in pts:
		out.append(at + p.rotated(angle))
	draw_colored_polygon(out, UiKit.MARIGOLD)


func _gui_input(event: InputEvent) -> void:
	if not full or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var sc := minf(size.x / (city.width * PX_PER_M), size.y / (city.height * PX_PER_M))
		var off := (size - Vector2(city.width, city.height) * PX_PER_M * sc) * 0.5
		var w := (mb.position - off) / (PX_PER_M * sc)
		waypoint = Vector3(w.x, 0, w.y)
		var hud: Node = Services.hud
		if hud != null:
			hud.set("waypoint", waypoint)
	elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		waypoint = Vector3.INF
		var hud2: Node = Services.hud
		if hud2 != null:
			hud2.set("waypoint", Vector3.INF)
