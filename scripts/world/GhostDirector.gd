class_name GhostDirector
extends Node3D
## The night rule (Minecraft-style): when the sun is down, the dead come out.
##   * Every unanswered spirit (GameState.spirits) hunts Sakib from dusk to dawn, every night,
##     until he frees it by answering its question.
##   * Even with a clean record the night is not safe: wandering nishi spirits rise near the
##     graveyard and in dark lanes, more the longer Sakib stays out.
##   * Safe: indoors (homes, the mosque, shops, the college), and within 8 m of a working lamp.
##   * Load-shedding cuts the power to a district for a while at night: its lamps and windows go dark.
##   * At dawn every ghost burns away.
## Also drives the global shader values for night and power (dhaka_night, dhaka_power_a/b).
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal danger_changed(exposed: bool)
signal power_changed(district: String, on: bool)

const MAX_GHOSTS := [3, 4, 6, 8]
const LAMP_SAFE := 8.0
const GENERIC := [{"bn": "নিশির ডাক", "en": "The Night Caller"}, {"bn": "পেত্নী", "en": "Petni"}, {"bn": "মেছো ভূত", "en": "Mecho Bhoot"}]

var city: CityData
var player: Node3D
var atmosphere: DhakaAtmosphere
var exposed := false
var power := PackedFloat32Array([1, 1, 1, 1, 1])
var _cuts: Dictionary = {}       # power group -> game hour when power returns
var _rng := RandomNumberGenerator.new()
var _check_t := 0.0
var _spawn_t := 5.0
var _exposed_time := 0.0
var _max := 4
var _was_night := false
var _active: Dictionary = {}     # spirit id -> Ghost


func setup(c: CityData, p: Node3D, atmos: DhakaAtmosphere) -> void:
	city = c
	player = p
	atmosphere = atmos
	_rng.randomize()
	_max = int(MAX_GHOSTS[clampi(RenderQuality.saved(), 0, 3)])


func is_night() -> bool:
	return atmosphere != null and atmosphere.sun_elevation() < -1.0


func night_amount() -> float:
	return atmosphere.lamp_amount() if atmosphere != null else 0.0


func power_on(district_id: String) -> bool:
	return power[city.power_group(district_id)] > 0.5


func player_exposed() -> bool:
	return exposed


func _process(delta: float) -> void:
	var night := night_amount()
	RenderingServer.global_shader_parameter_set("dhaka_night", night)
	RenderingServer.global_shader_parameter_set("dhaka_power_a", Vector4(power[0], power[1], power[2], power[3]))
	RenderingServer.global_shader_parameter_set("dhaka_power_b", power[4])
	_check_t -= delta
	if _check_t > 0.0 or player == null:
		return
	_check_t = 0.25
	var n := is_night()
	if n != _was_night:
		_was_night = n
		if not n:
			_dawn()
	_update_power()
	var was := exposed
	exposed = n and _player_outdoors_dark()
	if exposed != was:
		danger_changed.emit(exposed)
	if exposed:
		_exposed_time += 0.25
	else:
		_exposed_time = maxf(0.0, _exposed_time - 0.5)
	if n:
		_spawn_t -= 0.25
		if _spawn_t <= 0.0:
			_spawn_t = _rng.randf_range(6.0, 12.0)
			_spawn_some()


func _player_outdoors_dark() -> bool:
	var p := player.global_position
	if city.is_safe_zone(p) != "":
		return false
	if player.has_method(&"in_vehicle") and bool(player.call("in_vehicle")):
		return true
	for l in city.lamps_near(p, LAMP_SAFE):
		var la: Array = l
		if power_on(String(la[1])):
			return false
	return true


func _update_power() -> void:
	var h := GameState.hour()
	for g in _cuts.keys():
		var back := float(_cuts[g])
		if absf(h - back) < 0.3 or (h > back and h - back < 6.0):
			_cuts.erase(g)
			power[int(g)] = 1.0
			power_changed.emit(str(g), true)
	# load-shedding: at night, now and then a district goes dark for 30-90 game minutes
	if is_night() and _cuts.size() < 2 and _rng.randf() < 0.004:
		var g := _rng.randi_range(0, 4)
		if not _cuts.has(g):
			_cuts[g] = fmod(h + _rng.randf_range(0.5, 1.5), 24.0)
			power[g] = 0.0
			power_changed.emit(str(g), false)
			Services.say_toast({"bn": "লোডশেডিং! একটা মহল্লার কারেন্ট চলে গেছে।", "en": "Load-shedding! A district has lost power."}, "warn")


## Missions can cut (or restore) a district's power on purpose (the escort through dark Jurain).
func force_cut(district_id: String, cut: bool) -> void:
	var g := city.power_group(district_id)
	if cut:
		_cuts[g] = fmod(GameState.hour() + 3.0, 24.0)
		power[g] = 0.0
	else:
		_cuts.erase(g)
		power[g] = 1.0
	power_changed.emit(district_id, not cut)


func _spawn_some() -> void:
	for k in _active.keys():
		if not is_instance_valid(_active[k]):
			_active.erase(k)
	if _active.size() >= _max:
		return
	var p := player.global_position
	# spirits of the unanswered dead come first
	for s in GameState.unbanished_spirits():
		var sd: Dictionary = s
		var id := String(sd.get("id", ""))
		if _active.has(id) or _active.size() >= _max:
			continue
		_spawn(sd, p)
		return
	# then the wandering nishi, if Sakib lingers in the dark
	if exposed and _exposed_time > 20.0 and _rng.randf() < 0.5:
		var near_grave := p.distance_to(city.poi_pos("graveyard")) < 160.0
		if near_grave or _rng.randf() < 0.35:
			var gid := "nishi_%d_%d" % [GameState.day, _rng.randi_range(0, 99999)]
			var name_line: Dictionary = GENERIC[_rng.randi_range(0, GENERIC.size() - 1)]
			var look := {"gender": "f" if _rng.randf() < 0.5 else "m", "outfit": "saree", "height": 1.75}
			_spawn({"id": gid, "name": name_line, "face": "", "look": look, "questions": [], "strength": 1, "generic": true}, p)


func _spawn(spirit: Dictionary, around: Vector3) -> void:
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(22.0, 34.0)
	var pos := around + Vector3(cos(ang) * r, 0.3, sin(ang) * r)
	var g := Ghost.new()
	add_child(g)
	g.setup(spirit, Services)
	g.global_position = pos
	g.freed.connect(_on_freed)
	_active[String(spirit.get("id", ""))] = g
	AudioEventBus.emit_event("ghost", pos, 80.0)


func _on_freed(spirit_id: String) -> void:
	_active.erase(spirit_id)


func _dawn() -> void:
	for k in _active:
		var g: Ghost = _active[k]
		if is_instance_valid(g):
			g.burn()
	_active.clear()
	_exposed_time = 0.0
	if GameState.unbanished_spirits().size() > 0:
		Services.say_toast({"bn": "ভোর হলো। ভূতেরা পুড়ে গেল, কিন্তু আজ রাতে আবার ফিরবে।", "en": "Dawn. The ghosts burned away, but they will be back tonight."}, "info")


func active_ghosts() -> Array:
	var out: Array = []
	for k in _active:
		if is_instance_valid(_active[k]):
			out.append(_active[k])
	return out
