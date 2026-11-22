class_name HeatSystem
extends Node
## Police attention, GTA-style stars (0-5). Crimes raise heat; police come in numbers that grow
## with it. At one star an officer stops Sakib with a question (a police quiz): answer and walk
## free. At two or more they attack. Heat cools when no officer has seen him for a while.
## Arrest (an officer beside him for 3 s while he stands still, or knocked out with heat) costs
## money and a night at the police station.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal heat_changed(level: int)

const WEIGHT := {"assault": 0.6, "shooting": 1.0, "murder": 2.0, "hijack": 1.0, "hit_and_run": 1.2, "bribe": 0.0, "trespass": 0.4}

var heat := 0.0
var player: Node3D
var peds: Node3D
var city: CityData
var _unseen := 0.0
var _spawn_t := 0.0
var _arrest_t := 0.0
var _quizzed := false
var _rng := RandomNumberGenerator.new()


func setup(p: Node3D, ped_system: Node3D, c: CityData) -> void:
	player = p
	peds = ped_system
	city = c
	_rng.randomize()


func level() -> int:
	return clampi(int(ceil(heat - 0.001)), 0, 5)


func add_crime(kind: String, _pos: Vector3) -> void:
	var before := level()
	heat = clampf(heat + float(WEIGHT.get(kind, 0.5)), 0.0, 5.0)
	_unseen = 0.0
	if level() != before:
		_quizzed = false
		heat_changed.emit(level())
	if level() >= 2:
		for c in get_tree().get_nodes_in_group(&"citizens"):
			var cz := c as Citizen
			if cz != null and cz.is_alive() and cz.ai.profession() == "police" and cz.global_position.distance_to(player.global_position) < 90.0:
				cz.ai.order_attack(player)


func clear() -> void:
	heat = 0.0
	_quizzed = false
	heat_changed.emit(0)
	for c in get_tree().get_nodes_in_group(&"citizens"):
		var cz := c as Citizen
		if cz != null and cz.ai.profession() == "police" and cz.ai.state == ActorAI.S.FIGHT:
			cz.ai.set_state(ActorAI.S.WANDER)


func _process(delta: float) -> void:
	if heat <= 0.0 or player == null:
		return
	var seen := false
	var nearest: Citizen = null
	var nd := 999.0
	for c in get_tree().get_nodes_in_group(&"citizens"):
		var cz := c as Citizen
		if cz == null or not cz.is_alive() or cz.ai.profession() != "police":
			continue
		var d := cz.global_position.distance_to(player.global_position)
		if d < 35.0:
			seen = true
		if d < nd:
			nd = d
			nearest = cz
	if seen:
		_unseen = 0.0
	else:
		_unseen += delta
		if _unseen > 12.0 + level() * 6.0:
			var before := level()
			heat = maxf(0.0, heat - delta * 0.15)
			if level() != before:
				heat_changed.emit(level())
	# keep officers coming
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 6.0
		var police := 0
		for c in get_tree().get_nodes_in_group(&"citizens"):
			var cz := c as Citizen
			if cz != null and cz.is_alive() and cz.ai.profession() == "police":
				police += 1
		if police < mini(level() * 2, 8):
			var node := city.ped_node_in_ring(player.global_position, 45.0, 75.0, _rng)
			if node >= 0:
				var prof := PersonGenerator.make(_rng.randi(), "police", city.district_id_at(player.global_position))
				prof["armed"] = level() >= 3
				var cop := ActorFactory.spawn(prof, peds, city.ped_node_pos(node), 0.0)
				if level() >= 2:
					cop.ai.order_attack(player)
				else:
					cop.ai.order_follow(player)
	# one star: the stop-and-question
	if level() == 1 and nearest != null and nd < 3.0 and not _quizzed:
		_quizzed = true
		nearest.say(TauntBank.pick("police", _rng), 4.0, 2)
		Exams.start({"mode": "police", "speaker": nearest.display_name(), "face": String(nearest.profile.get("face", "")),
			"voice": nearest.profile.get("voice", {}), "family": "bar", "count": 2, "pass": 2, "seconds": 16.0,
			"allow_bribe": true, "bribe_cost": 500, "allow_flee": true, "taunts": "police",
			"stakes": {"bn": "দুটোই ঠিক হলে ছাড়া পাবে।", "en": "Both right and you walk free."}}, _on_police_quiz)
	# arrest
	if level() >= 1 and nearest != null and nd < 2.0 and (player as CharacterBody3D).velocity.length() < 0.5:
		_arrest_t += delta
		if _arrest_t > 3.0:
			arrest()
	else:
		_arrest_t = 0.0


func _on_police_quiz(r: Dictionary) -> void:
	if bool(r.get("passed", false)):
		clear()
		Services.say_toast({"bn": "পুলিশ ছেড়ে দিল।", "en": "The police let you go."}, "good")
	elif bool(r.get("fled", false)):
		add_crime("assault", player.global_position)
	else:
		add_crime("shooting", player.global_position)


func arrest() -> void:
	_arrest_t = 0.0
	var fine := mini(GameState.money, 500 + level() * 300)
	GameState.add_money(-fine)
	GameState.bump("arrests")
	GameState.change_respect(-5)
	clear()
	GameState.skip_to(fmod(GameState.hour() + 8.0, 24.0))
	if player.has_method(&"teleport"):
		player.call("teleport", city.poi_pos("police_station"))
	Services.say_toast({"bn": "গ্রেপ্তার! জরিমানা ৳%s, থানায় রাত কাটল।" % UiKit.bengali_digits(str(fine)),
		"en": "Arrested! Fined Tk %d and a night in the police station." % fine}, "warn")
