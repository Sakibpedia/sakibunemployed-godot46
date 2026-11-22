class_name BuildingInteriorSystem
extends Node3D
## Streams the city's enterable buildings.
##
## * The eleven landmark buildings are built once at startup and kept: their ground floors are the
##   mess, the tower parking, the college, the clinic, the library, the cyber cafe, the superstore,
##   the lawyer's chamber, the police station, the coaching centre and the mosque.
## * Every other building gets a light entrance proxy when the player is near.  Opening that door
##   hides the building's shader-painted box, disables its single box collider and generates the full
##   walkable building (stair, flats, shop floor, roof) in place.  When the player walks away it is
##   freed and the painted box returns, so 2,600 buildings cost almost nothing until visited.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const SCAN_RADIUS := 26.0
const KEEP_MARGIN := 7.0
const MAX_PROXIES := 18
const MAX_OPEN := 2
const LIGHT_RANGE := 13.0

var city: CityData
var builder: ProceduralDhaka
var player: Node3D
var _proxies: Dictionary = {}
var _open: Dictionary = {}
var _order: Array[String] = []
var _scan_t := 0.0
var _last := Vector3(INF, INF, INF)
var _cull_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(c: CityData, b: ProceduralDhaka, p: Node3D) -> void:
	city = c
	builder = b
	player = p
	_rng.seed = 20261122
	# Landmarks are permanent: the player must be able to walk into them at any time, and missions
	# send him to their upper floors and roofs.
	for bd in city.buildings:
		if bool((bd as Dictionary).get("enterable", false)):
			_open_interior(bd as Dictionary, true)
	_scan_t = 0.0


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or city == null:
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.4
		var p := player.global_position
		if p.distance_to(_last) > 2.5:
			_last = p
			_scan()
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.5
		_cull_lights()
	_check_open()


# ------------------------------------------------------------------------------------------------
# Entrance proxies
# ------------------------------------------------------------------------------------------------

func _scan() -> void:
	var p := player.global_position
	var cand: Array = []
	for bd in city.buildings_in_radius(p, SCAN_RADIUS):
		var b: Dictionary = bd
		if bool(b.get("enterable", false)):
			continue
		if String(b.get("style", "")) == "shack":
			continue
		if _open.has(String(b.get("id", ""))):
			continue
		var e := BuildingInterior.entrance_transform(b)
		var d := e.origin.distance_to(Vector3(p.x, e.origin.y, p.z))
		if d > SCAN_RADIUS:
			continue
		# Do not put a door where another building's footprint is: that happens in the densest lanes.
		var inside := city.building_at(e.origin + e.basis.z * 0.9)
		if not inside.is_empty() and String((inside as Dictionary).get("id", "")) != String(b.get("id", "")):
			continue
		cand.append([d, b])
	cand.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
	var wanted: Dictionary = {}
	var n := 0
	for item in cand:
		if n >= MAX_PROXIES:
			break
		var b2: Dictionary = item[1]
		var id := String(b2.get("id", ""))
		if wanted.has(id):
			continue
		wanted[id] = true
		n += 1
		if not _proxies.has(id):
			_make_proxy(b2)
	for id in _proxies.keys():
		if not wanted.has(String(id)) and not _open.has(String(id)):
			var pr: Node = _proxies[String(id)]
			if is_instance_valid(pr):
				pr.queue_free()
			_proxies.erase(id)


func _make_proxy(b: Dictionary) -> void:
	var pr := BuildingEntrance.new()
	pr.name = "Entrance_" + String(b.get("id", "building"))
	pr.setup(b, self)
	pr.transform = BuildingInterior.entrance_transform(b)
	add_child(pr)
	_proxies[String(b.get("id", ""))] = pr


func _remove_proxy(id: String) -> void:
	if _proxies.has(id):
		var pr: Node = _proxies[id]
		if is_instance_valid(pr):
			pr.queue_free()
		_proxies.erase(id)


# ------------------------------------------------------------------------------------------------
# Interiors
# ------------------------------------------------------------------------------------------------

func enter(b: Dictionary) -> void:
	var id := String(b.get("id", ""))
	if _open.has(id):
		return
	_open_interior(b, bool(b.get("enterable", false)))


func _open_interior(b: Dictionary, permanent: bool) -> void:
	var id := String(b.get("id", ""))
	if _open.has(id):
		return
	if not permanent:
		builder.set_building_hidden(id, true)
		builder.set_building_collision(id, false)
	var node := BuildingInterior.new()
	add_child(node)
	node.build(b, self)
	_open[id] = {"node": node, "permanent": permanent, "b": b}
	_order.append(id)
	_remove_proxy(id)
	if not permanent:
		var live := 0
		for key in _order:
			if not bool((_open.get(key, {}) as Dictionary).get("permanent", true)):
				live += 1
		while live > MAX_OPEN:
			for key2 in _order.duplicate():
				var rec: Dictionary = _open.get(key2, {})
				if rec.is_empty() or bool(rec.get("permanent", true)):
					continue
				_close(key2)
				live -= 1
				break


func _close(id: String) -> void:
	var rec: Dictionary = _open.get(id, {})
	if rec.is_empty():
		return
	var node: Node = rec.get("node", null)
	if node != null and is_instance_valid(node):
		node.queue_free()
	_open.erase(id)
	_order.erase(id)
	if not bool(rec.get("permanent", false)):
		builder.set_building_hidden(id, false)
		builder.set_building_collision(id, true)
	# Recreate the entrance proxy so the door is there when the player comes back.
	if player != null and is_instance_valid(player):
		var b: Dictionary = rec.get("b", {})
		if not b.is_empty():
			var e := BuildingInterior.entrance_transform(b)
			if e.origin.distance_to(player.global_position) < SCAN_RADIUS:
				_make_proxy(b)


func _check_open() -> void:
	if _order.is_empty():
		return
	var p := player.global_position
	for id in _order.duplicate():
		var rec: Dictionary = _open.get(id, {})
		if rec.is_empty() or bool(rec.get("permanent", true)):
			continue
		var b: Dictionary = rec.get("b", {})
		if b.is_empty():
			continue
		var rot := float(b.get("rot", 0.0))
		var dx := p.x - float(b.get("x", 0.0))
		var dz := p.z - float(b.get("z", 0.0))
		var u := dx * cos(rot) + dz * sin(rot)
		var v := -dx * sin(rot) + dz * cos(rot)
		var hw := float(b.get("w", 10.0)) * 0.5 + KEEP_MARGIN
		var hd := float(b.get("d", 10.0)) * 0.5 + KEEP_MARGIN
		if absf(u) > hw or absf(v) > hd:
			_close(id)


func _cull_lights() -> void:
	if player == null or not is_instance_valid(player):
		return
	var p := player.global_position
	for id in _open:
		var rec: Dictionary = _open.get(id, {})
		var node: BuildingInterior = rec.get("node", null)
		if node == null or not is_instance_valid(node):
			continue
		for l in node.lights:
			if l == null or not is_instance_valid(l):
				continue
			var d := l.global_position.distance_to(p)
			l.visible = d < LIGHT_RANGE and absf(l.global_position.y - p.y) < 9.0


func name_for(b: Dictionary) -> String:
	return BuildingInterior.building_name(b)
