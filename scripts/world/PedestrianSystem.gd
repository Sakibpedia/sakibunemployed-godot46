class_name PedestrianSystem
extends Node3D
## Keeps the streets full: people are spawned on the pedestrian paths in a ring 45-95 m around
## Sakib and recycled when they fall 130 m behind. Fewer people at night, almost none after 22:00
## (the night belongs to the ghosts). A few thugs in Kajla and Jatrabari, a few police everywhere.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const COUNTS := [14, 22, 30, 40]

var city: CityData
var player: Node3D
var max_count := 22
var _rng := RandomNumberGenerator.new()
var _timer := 0.0


func setup(c: CityData, p: Node3D) -> void:
	city = c
	player = p
	_rng.randomize()
	max_count = int(COUNTS[clampi(RenderQuality.saved(), 0, 3)])


func _density() -> float:
	var h := GameState.hour()
	if h >= 22.0 or h < 5.0:
		return 0.12
	if h >= 19.0:
		return 0.4
	if h >= 17.5:
		return 0.75
	if h < 6.5:
		return 0.4
	return 1.0


func active_count() -> int:
	var n := 0
	for c in get_children():
		if c is Citizen and not (c as Citizen).persistent:
			n += 1
	return n


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or player == null:
		return
	_timer = 0.4
	var pp := player.global_position
	for c in get_children():
		if not (c is Citizen):
			continue
		var cz := c as Citizen
		if cz.persistent:
			continue
		var d := cz.global_position.distance_to(pp)
		if d > 130.0 or (not cz.is_alive() and d > 45.0):
			cz.queue_free()
	var target := int(max_count * _density())
	if active_count() < target:
		_spawn_one(pp)


func _spawn_one(around: Vector3) -> void:
	var node := city.ped_node_in_ring(around, 45.0, 95.0, _rng)
	if node < 0:
		return
	var pos := city.ped_node_pos(node)
	if city.building_at(pos).size() > 0:
		return
	var district := city.district_id_at(pos)
	var role := "ped"
	var r := _rng.randf()
	if district in ["kajla", "jatrabari"] and r < 0.07:
		role = "goon"
	elif r < 0.11:
		role = "police"
	var profile := PersonGenerator.make(_rng.randi(), role, district)
	ActorFactory.spawn(profile, self, pos + Vector3(0, 0.05, 0), _rng.randf() * TAU)
