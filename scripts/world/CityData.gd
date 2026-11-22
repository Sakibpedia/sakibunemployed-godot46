class_name CityData
extends RefCounted
## Loads Data/World/city.json (tools/make_city.py) and answers spatial questions about the city:
## which district a point is in, the nearest pedestrian path node, lamps near a point, safe zones,
## points of interest. World axes match the JSON: x east, z south, y up.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const PATH := "res://Data/World/city.json"
const HASH := 24.0

var data: Dictionary = {}
var width := 1400.0
var height := 1100.0
var buildings: Array = []
var roads: Array = []
var lanes: Array = []
var lamps: Array = []
var posters: Array = []
var pois: Dictionary = {}
var safe_zones: Array = []
var districts: Dictionary = {}
var ped_pos := PackedVector3Array()
var ped_adj: Array = []          # Array[PackedInt32Array]
var _ped_hash: Dictionary = {}
var _lamp_hash: Dictionary = {}
var _bld_hash: Dictionary = {}
var _raster := ""
var _raster_w := 0
var _raster_h := 0
var _raster_cell := 10.0
var _district_ids: Array = []


func load_city(path: String = PATH) -> bool:
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CityData: could not read %s. Run tools/make_city.py." % path)
		return false
	data = parsed
	var sz: Array = data.get("size", [1400.0, 1100.0])
	width = float(sz[0])
	height = float(sz[1])
	buildings = data.get("buildings", [])
	roads = data.get("roads", [])
	lanes = data.get("lanes", [])
	lamps = data.get("lamps", [])
	posters = data.get("posters", [])
	safe_zones = data.get("safe_zones", [])
	for d in data.get("districts", []):
		var dd: Dictionary = d
		districts[String(dd["id"])] = dd
		_district_ids.append(String(dd["id"]))
	for p in data.get("pois", []):
		var pd: Dictionary = p
		pois[String(pd["id"])] = pd
	var r: Dictionary = data.get("district_raster", {})
	_raster = String(r.get("data", ""))
	_raster_w = int(r.get("w", 0))
	_raster_h = int(r.get("h", 0))
	_raster_cell = float(r.get("cell", 10.0))
	_index_peds()
	_index_lamps()
	_index_buildings()
	return true


func size() -> Vector2:
	return Vector2(width, height)


func _key(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / HASH)), int(floor(z / HASH)))


func _index_peds() -> void:
	var nodes: Array = data.get("ped_nodes", [])
	ped_pos.resize(nodes.size())
	ped_adj.resize(nodes.size())
	for i in nodes.size():
		var n: Array = nodes[i]
		ped_pos[i] = Vector3(float(n[0]), 0.0, float(n[1]))
		ped_adj[i] = PackedInt32Array()
		var k := _key(float(n[0]), float(n[1]))
		if not _ped_hash.has(k):
			_ped_hash[k] = PackedInt32Array()
		var arr: PackedInt32Array = _ped_hash[k]
		arr.append(i)
		_ped_hash[k] = arr
	for e in data.get("ped_edges", []):
		var ea: Array = e
		var a := int(ea[0])
		var b := int(ea[1])
		var la: PackedInt32Array = ped_adj[a]
		la.append(b)
		ped_adj[a] = la
		var lb: PackedInt32Array = ped_adj[b]
		lb.append(a)
		ped_adj[b] = lb


func _index_lamps() -> void:
	for i in lamps.size():
		var l: Array = lamps[i]
		var k := _key(float(l[0]), float(l[1]))
		if not _lamp_hash.has(k):
			_lamp_hash[k] = PackedInt32Array()
		var arr: PackedInt32Array = _lamp_hash[k]
		arr.append(i)
		_lamp_hash[k] = arr


func _index_buildings() -> void:
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		var rad := 0.5 * Vector2(float(b["w"]), float(b["d"])).length()
		var k0 := _key(float(b["x"]) - rad, float(b["z"]) - rad)
		var k1 := _key(float(b["x"]) + rad, float(b["z"]) + rad)
		for kx in range(k0.x, k1.x + 1):
			for kz in range(k0.y, k1.y + 1):
				var k := Vector2i(kx, kz)
				if not _bld_hash.has(k):
					_bld_hash[k] = PackedInt32Array()
				var arr: PackedInt32Array = _bld_hash[k]
				arr.append(i)
				_bld_hash[k] = arr


# --- Queries -------------------------------------------------------------------------------------

func district_id_at(p: Vector3) -> String:
	if _raster == "" or _district_ids.is_empty():
		return "jatrabari"
	var i := clampi(int(p.x / _raster_cell), 0, _raster_w - 1)
	var j := clampi(int(p.z / _raster_cell), 0, _raster_h - 1)
	var c := _raster.unicode_at(j * _raster_w + i) - 48
	return String(_district_ids[clampi(c, 0, _district_ids.size() - 1)])


func district_name(id: String) -> Dictionary:
	var d: Dictionary = districts.get(id, {})
	return d.get("name", {"bn": id, "en": id})


func power_group(id: String) -> int:
	var d: Dictionary = districts.get(id, {})
	return int(d.get("power_group", 0))


func nearest_ped_node(p: Vector3, max_rings: int = 3) -> int:
	var k := _key(p.x, p.z)
	var best := -1
	var best_d := INF
	for ring in range(0, max_rings + 1):
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var arr: PackedInt32Array = _ped_hash.get(Vector2i(k.x + dx, k.y + dz), PackedInt32Array())
				for i in arr:
					var d := ped_pos[i].distance_squared_to(Vector3(p.x, 0.0, p.z))
					if d < best_d:
						best_d = d
						best = i
		if best >= 0 and ring >= 1:
			break
	return best


func ped_node_pos(i: int) -> Vector3:
	return ped_pos[i] if i >= 0 and i < ped_pos.size() else Vector3.ZERO


func ped_neighbors(i: int) -> PackedInt32Array:
	return ped_adj[i] if i >= 0 and i < ped_adj.size() else PackedInt32Array()


## A path node between rmin and rmax metres from p (or -1).
func ped_node_in_ring(p: Vector3, rmin: float, rmax: float, rng: RandomNumberGenerator) -> int:
	for attempt in 12:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax)
		var q := p + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var i := nearest_ped_node(q, 2)
		if i >= 0:
			var d := ped_pos[i].distance_to(Vector3(p.x, 0.0, p.z))
			if d >= rmin * 0.8 and d <= rmax * 1.2:
				return i
	return -1


func poi(id: String) -> Dictionary:
	return pois.get(id, {})


func poi_pos(id: String) -> Vector3:
	var p: Dictionary = pois.get(id, {})
	if p.is_empty():
		return spawn_point()
	return Vector3(float(p["x"]), float(p.get("y", 0.0)), float(p["z"]))


func spawn_point() -> Vector3:
	var s: Array = data.get("spawn", [width * 0.2, height * 0.5])
	return Vector3(float(s[0]), 0.0, float(s[1]))


func is_safe_zone(p: Vector3) -> String:
	for z in safe_zones:
		var zd: Dictionary = z
		var r: Array = zd["rect"]
		if p.x >= float(r[0]) and p.x <= float(r[2]) and p.z >= float(r[1]) and p.z <= float(r[3]) and p.y < 4.0:
			return String(zd["id"])
	return ""


## Lamps within `radius`: Array of [Vector3, district id]
func lamps_near(p: Vector3, radius: float) -> Array:
	var out: Array = []
	var k0 := _key(p.x - radius, p.z - radius)
	var k1 := _key(p.x + radius, p.z + radius)
	for kx in range(k0.x, k1.x + 1):
		for kz in range(k0.y, k1.y + 1):
			var arr: PackedInt32Array = _lamp_hash.get(Vector2i(kx, kz), PackedInt32Array())
			for i in arr:
				var l: Array = lamps[i]
				var lp := Vector3(float(l[0]), 0.0, float(l[1]))
				if lp.distance_to(Vector3(p.x, 0.0, p.z)) <= radius:
					out.append([lp, String(l[2])])
	return out


func buildings_near(p: Vector3) -> PackedInt32Array:
	return _bld_hash.get(_key(p.x, p.z), PackedInt32Array())


## Every building whose 24 m hash cell overlaps the square around p.  Buildings are indexed by
## their bounding radius, so this is a cheap superset; callers do the exact distance test.
func buildings_in_radius(p: Vector3, radius: float) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var k0 := _key(p.x - radius, p.z - radius)
	var k1 := _key(p.x + radius, p.z + radius)
	for kx in range(k0.x, k1.x + 1):
		for kz in range(k0.y, k1.y + 1):
			var arr: PackedInt32Array = _bld_hash.get(Vector2i(kx, kz), PackedInt32Array())
			for i in arr:
				if seen.has(i):
					continue
				seen[i] = true
				out.append(buildings[i])
	return out


## The building whose footprint contains p, or {}.
func building_at(p: Vector3) -> Dictionary:
	for i in buildings_near(p):
		var b: Dictionary = buildings[i]
		var rot := float(b["rot"])
		var dx := p.x - float(b["x"])
		var dz := p.z - float(b["z"])
		var u := dx * cos(rot) + dz * sin(rot)
		var v := -dx * sin(rot) + dz * cos(rot)
		if absf(u) <= float(b["w"]) * 0.5 and absf(v) <= float(b["d"]) * 0.5:
			return b
	return {}


func building_by_id(id: String) -> Dictionary:
	for b in buildings:
		var bd: Dictionary = b
		if String(bd["id"]) == id:
			return bd
	return {}
