class_name TrafficSystem
extends Node3D
## Traffic around Sakib: vehicles are placed on the lanes (city.json "lanes", left-hand traffic)
## 60-220 m away and recycled beyond 260 m. Highways carry buses, trucks, cars and CNGs; main roads
## CNGs, rickshaws, cars and motorbikes; lanes mostly rickshaws and motorbikes.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const COUNTS := [8, 12, 18, 24]
const MIX := {
	"highway": ["bus", "bus", "truck", "car", "car", "cng", "cng", "motorbike"],
	"main": ["cng", "cng", "rickshaw", "rickshaw", "car", "motorbike"],
	"lane": ["rickshaw", "rickshaw", "rickshaw", "motorbike", "cng"],
}

var city: CityData
var player: Node3D
var max_count := 12
var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _road_kind: Dictionary = {}


func setup(c: CityData, p: Node3D) -> void:
	city = c
	player = p
	_rng.randomize()
	max_count = int(COUNTS[clampi(RenderQuality.saved(), 0, 3)])
	for r in city.roads:
		var rd: Dictionary = r
		_road_kind[String(rd["id"])] = String(rd["kind"])


func nearest_vehicle(p: Vector3, max_d: float) -> Vehicle:
	var best: Vehicle = null
	var bd := max_d
	for v in get_children():
		if v is Vehicle:
			var d := (v as Vehicle).global_position.distance_to(p)
			if d < bd:
				bd = d
				best = v
	return best


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or player == null:
		return
	_timer = 0.5
	var pp := player.global_position
	var n := 0
	for v in get_children():
		if not (v is Vehicle):
			continue
		var veh := v as Vehicle
		if veh.is_player_driven():
			continue
		n += 1
		if veh.global_position.distance_to(pp) > 260.0:
			veh.queue_free()
	var density := 0.45 if (GameState.hour() >= 22.0 or GameState.hour() < 5.5) else 1.0
	if n < int(max_count * density):
		_spawn(pp)


func _spawn(around: Vector3) -> void:
	if city.lanes.is_empty():
		return
	for attempt in 8:
		var li := _rng.randi_range(0, city.lanes.size() - 1)
		var ln: Dictionary = city.lanes[li]
		var pts: Array = ln["points"]
		var t := _rng.randf()
		var a := Vector3(float(pts[0][0]), 0.0, float(pts[0][1]))
		var b := Vector3(float(pts[1][0]), 0.0, float(pts[1][1]))
		var p := a.lerp(b, t)
		var d := p.distance_to(around)
		if d < 60.0 or d > 220.0:
			continue
		var kind_list: Array = MIX.get(String(_road_kind.get(String(ln["road"]), "lane")), MIX["lane"])
		var kind := String(kind_list[_rng.randi_range(0, kind_list.size() - 1)])
		var v := Vehicle.new()
		add_child(v)
		v.setup(kind, city.lanes, li, _rng.randi())
		v.place_on_lane(t)
		return
