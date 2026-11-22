class_name ActorAI
extends Node
## The mind of a Citizen: a small state machine with senses (sight cone, hearing through
## AudioEventBus), daily habits (walking the pedestrian paths, sitting at tea stalls), chatter and
## gossip (ChatterAI), street quizzes (any stranger may stop Sakib with a question), reactions to
## guns and ghosts, and fighting for thugs and police.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

enum S { IDLE, WANDER, GOTO, FLEE, COWER, FIGHT, FOLLOW, GUARD, APPROACH, OFFER }

const WALK := 1.35
const RUN := 4.6
const SIGHT := 28.0

var actor: Node3D
var services: Node
var rng := RandomNumberGenerator.new()
var state: int = S.WANDER
var offers_quiz := false
var target: Node3D = null
var post := Vector3.INF
var goto_point := Vector3.INF
var _timer := 0.0
var _bark_t := 10.0
var _node := -1
var _prev := -1
var _danger := Vector3.ZERO
var _shoot_t := 0.0
var _punch_t := 0.0
var _duel_done := false
var _prof: Dictionary = {}


func setup(a: Node3D, svc: Node) -> void:
	actor = a
	services = svc
	_prof = a.get("profile")
	rng.seed = int(_prof.get("seed", 1))
	_bark_t = rng.randf_range(6.0, 30.0)
	var prof := String(_prof.get("profession", ""))
	if prof == "guard":
		state = S.GUARD
	else:
		state = S.WANDER


func profession() -> String:
	return String(_prof.get("profession", ""))


func set_state(s: int, seconds: float = 0.0) -> void:
	state = s
	_timer = seconds
	if s != S.OFFER:
		offers_quiz = false
		if not (actor.get("persistent") as bool):
			(actor.get("visuals") as ActorVisuals).set_marker("")


func context() -> Dictionary:
	var city: CityData = Services.city
	var d := city.district_id_at(actor.global_position) if city != null else "jatrabari"
	var ghosts: Node = Services.ghosts
	var pw := true
	if ghosts != null and ghosts.has_method(&"power_on"):
		pw = bool(ghosts.call("power_on", d))
	return {"district": d, "hour": GameState.hour(), "power_out": not pw}


func _player() -> Node3D:
	return Services.player


func tick(delta: float) -> void:
	_timer -= delta
	_bark_t -= delta
	_shoot_t -= delta
	_punch_t -= delta
	var p := _player()
	var pd := 999.0
	if p != null and is_instance_valid(p):
		pd = p.global_position.distance_to(actor.global_position)
	var a := actor as Citizen
	var rig: HumanoidRig = a.visuals.rig
	if pd < 7.0 and state in [S.IDLE, S.WANDER, S.GUARD, S.OFFER]:
		rig.look_at_point(p.global_position + Vector3(0, 1.5, 0))
	else:
		rig.clear_look()
	match state:
		S.IDLE:
			a.anim_state = "idle"
			if _timer <= 0.0:
				set_state(S.WANDER)
		S.WANDER:
			a.anim_state = "walk"
			if not a.has_target():
				_next_node()
			if rng.randf() < delta * 0.01:
				a.stop_moving()
				set_state(S.IDLE, rng.randf_range(3.0, 9.0))
			_maybe_approach(pd)
		S.GOTO:
			a.anim_state = "walk"
			if not a.has_target() and goto_point != Vector3.INF:
				if a.global_position.distance_to(goto_point) > 1.0:
					a.move_to(goto_point, WALK)
				else:
					set_state(S.IDLE, 9999.0)
		S.FLEE:
			a.anim_state = "run"
			if not a.has_target() or _timer <= 0.0:
				if _timer <= 0.0:
					set_state(S.WANDER)
				else:
					var away := (a.global_position - _danger)
					away.y = 0
					a.move_to(a.global_position + away.normalized() * 14.0 + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), RUN)
		S.COWER:
			a.anim_state = "cower"
			a.stop_moving()
			if _timer <= 0.0:
				_danger = p.global_position if p != null else a.global_position
				set_state(S.FLEE, rng.randf_range(6.0, 12.0))
		S.FIGHT:
			_fight(delta, pd)
		S.FOLLOW:
			if target != null and is_instance_valid(target):
				var d := target.global_position.distance_to(a.global_position)
				if d > 2.6:
					a.move_to(target.global_position, RUN if d > 7.0 else WALK * 1.4)
					a.anim_state = "walk"
				else:
					a.stop_moving()
					a.anim_state = "idle"
		S.GUARD:
			a.anim_state = "idle"
			if post == Vector3.INF:
				post = a.global_position
			if a.global_position.distance_to(post) > 1.0:
				a.move_to(post, WALK)
			if pd < 6.0:
				a.face_toward(p.global_position)
		S.APPROACH:
			a.anim_state = "walk"
			if p == null or pd > 30.0 or _timer <= 0.0:
				set_state(S.WANDER)
			elif pd > 2.2:
				a.move_to(p.global_position, WALK * 1.3)
			else:
				a.stop_moving()
				_offer()
		S.OFFER:
			a.anim_state = "talk"
			a.face_toward(p.global_position if p != null else a.global_position)
			if _timer <= 0.0 or pd > 9.0:
				offers_quiz = false
				set_state(S.WANDER)
	# chatter
	if _bark_t <= 0.0 and pd < 11.0 and state in [S.WANDER, S.IDLE, S.GUARD]:
		_bark_t = rng.randf_range(16.0, 45.0)
		var topic := "smalltalk"
		var h := GameState.hour()
		if h > 16.8 and h < 18.3 and rng.randf() < 0.5:
			topic = "warn_night"
		elif rng.randf() < 0.35:
			topic = "rumour"
		a.say(ChatterAI.line(_prof, topic, context(), rng), 4.0, 0)


func _next_node() -> void:
	var city: CityData = Services.city
	if city == null:
		return
	var a := actor as Citizen
	if _node < 0:
		_node = city.nearest_ped_node(a.global_position)
		if _node < 0:
			return
	var nb := city.ped_neighbors(_node)
	if nb.is_empty():
		_node = -1
		return
	var choice := nb[rng.randi_range(0, nb.size() - 1)]
	if nb.size() > 1 and choice == _prev:
		choice = nb[(nb.find(choice) + 1) % nb.size()]
	_prev = _node
	_node = choice
	var target_pos := city.ped_node_pos(_node) + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	a.move_to(target_pos, WALK * rng.randf_range(0.85, 1.15))


## Strangers who like a challenge walk up to Sakib with a question (by day, not too often).
func _maybe_approach(pd: float) -> void:
	if _duel_done or pd > 16.0 or pd < 3.0:
		return
	if not GameState.is_daylight():
		return
	var curiosity := float((_prof.get("personality", {}) as Dictionary).get("curiosity", 0.3))
	if not Missions.can_random_encounter():
		return
	if rng.randf() < 0.002 * curiosity:
		Missions.note_random_encounter()
		set_state(S.APPROACH, 20.0)


func _offer() -> void:
	set_state(S.OFFER, 14.0)
	offers_quiz = true
	(actor.get("visuals") as ActorVisuals).set_marker("quiz")
	var a := actor as Citizen
	a.say(ChatterAI.line(_prof, "quiz_offer", context(), rng), 5.0, 1)
	Services.say_toast({"bn": "%s প্রশ্নের লড়াইয়ে ডাকছে। E চেপে রাজি হও।" % Game.text(a.display_name()),
		"en": "%s challenges you to a question duel. Press E to accept." % Game.text(a.display_name())}, "info")


func start_duel(player_challenged: bool) -> void:
	if _duel_done:
		(actor as Citizen).say({"bn": "আজ আর না, ভাই।", "en": "Not again today, brother."}, 3.0, 1)
		return
	_duel_done = true
	offers_quiz = false
	(actor.get("visuals") as ActorVisuals).set_marker("")
	var bet := rng.randi_range(2, 6) * 50
	var a := actor as Citizen
	Exams.start({"mode": "duel", "speaker": a.display_name(), "face": String(_prof.get("face", "")), "voice": _prof.get("voice", {}),
		"family": String(_prof.get("family", "bcs")), "count": 3, "pass": 2, "seconds": 20.0, "allow_flee": true,
		"open_line": ChatterAI.line(_prof, "quiz_offer", context(), rng),
		"stakes": {"bn": "বাজি ৳%s · তিনটের মধ্যে দুটো" % UiKit.bengali_digits(str(bet)), "en": "Stake Tk %d · two out of three" % bet}},
		_on_duel.bind(bet, player_challenged))


func _on_duel(r: Dictionary, bet: int, _player_challenged: bool) -> void:
	var a := actor as Citizen
	var city: CityData = Services.city
	var d := city.district_id_at(a.global_position) if city != null else "jatrabari"
	if bool(r.get("passed", false)):
		GameState.add_money(bet)
		GameState.change_respect(2)
		GameState.bump("duels_won")
		GameState.log_event("duel_won", d)
		a.say(ChatterAI.line(_prof, "quiz_win", context(), rng), 4.0, 1)
	elif bool(r.get("fled", false)):
		GameState.change_respect(-1)
		a.say(TauntBank.pick("wrong", rng), 3.5, 1)
	else:
		GameState.add_money(-mini(bet, GameState.money))
		GameState.change_respect(-1)
		GameState.bump("duels_lost")
		GameState.log_event("duel_lost", d)
		a.say(ChatterAI.line(_prof, "quiz_lose", context(), rng), 4.0, 1)
	set_state(S.WANDER)


# --- Senses and reactions ----------------------------------------------------------------------

func hear(event_name: String, pos: Vector3, level: float) -> void:
	if (actor as Citizen).health.is_dead() or (actor as Citizen).health.is_dying():
		return
	if event_name in ["gunshot", "scream", "explosion", "ghost"]:
		var prof := profession()
		var p := _player()
		if prof in ["police", "goon"] and p != null and p.global_position.distance_to(pos) < 6.0:
			order_attack(p)
			return
		if state in [S.FIGHT, S.FOLLOW]:
			return
		_danger = pos
		if level > 95.0 and rng.randf() < 0.5:
			set_state(S.COWER, rng.randf_range(2.0, 4.0))
		else:
			set_state(S.FLEE, rng.randf_range(8.0, 15.0))
		if rng.randf() < 0.4:
			(actor as Citizen).say(ChatterAI.line(_prof, "react_ghost" if event_name == "ghost" else "react_gun", context(), rng), 2.5, 0)


func on_attacked(by: Node) -> void:
	if profession() in ["police", "goon", "guard"] or float((_prof.get("personality", {}) as Dictionary).get("temper", 0.0)) > 0.85:
		order_attack(by as Node3D)
	else:
		_danger = (by as Node3D).global_position
		set_state(S.FLEE, rng.randf_range(10.0, 18.0))


func notify_crime(_kind: String, pos: Vector3) -> void:
	if profession() == "police":
		order_attack(_player())
	elif state in [S.WANDER, S.IDLE]:
		_danger = pos
		set_state(S.FLEE, rng.randf_range(6.0, 12.0))


func order_goto(p: Vector3) -> void:
	goto_point = p
	set_state(S.GOTO)
	(actor as Citizen).move_to(p, WALK)


func order_follow(n: Node3D) -> void:
	target = n
	set_state(S.FOLLOW)


func order_attack(n: Node3D) -> void:
	if n == null:
		return
	target = n
	set_state(S.FIGHT)


func order_guard(p: Vector3) -> void:
	post = p
	set_state(S.GUARD)


# --- Fighting ------------------------------------------------------------------------------------

func _fight(_delta: float, _pd: float) -> void:
	var a := actor as Citizen
	if target == null or not is_instance_valid(target):
		set_state(S.WANDER)
		return
	if target.has_method(&"is_alive") and not bool(target.call("is_alive")):
		set_state(S.WANDER)
		return
	var d := target.global_position.distance_to(a.global_position)
	var armed := bool(_prof.get("armed", false))
	if armed and d < 26.0 and d > 3.0 and _sees(target):
		a.stop_moving()
		a.face_toward(target.global_position)
		a.anim_state = "aim"
		if _shoot_t <= 0.0:
			_shoot_t = rng.randf_range(0.9, 1.6)
			_shoot()
	elif d > 1.5:
		a.anim_state = "run"
		a.move_to(target.global_position, RUN * 0.9)
	else:
		a.stop_moving()
		a.face_toward(target.global_position)
		a.anim_state = "idle"
		if _punch_t <= 0.0:
			_punch_t = 0.9
			a.visuals.rig.gesture("punch")
			if target.has_method(&"take_damage"):
				target.call("take_damage", 7.0, actor, "melee")
	if d > 60.0:
		set_state(S.WANDER)


func _sees(n: Node3D) -> bool:
	var from := actor.global_position + Vector3(0, 1.5, 0)
	var to := n.global_position + Vector3(0, 1.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	return actor.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _shoot() -> void:
	var a := actor as Citizen
	a.visuals.rig.gesture("recoil")
	var muzzle := a.global_position + Vector3(0, 1.4, 0) + (-a.global_transform.basis.z) * 0.6
	AudioEventBus.emit_event("gunshot", muzzle, 140.0)
	Services.gunshot.emit(muzzle)
	var d := target.global_position.distance_to(a.global_position)
	var moving := 0.0
	if target is CharacterBody3D:
		moving = (target as CharacterBody3D).velocity.length()
	var hit_chance := clampf(0.75 - d * 0.018 - moving * 0.06, 0.12, 0.8)
	if rng.randf() < hit_chance and target.has_method(&"take_damage"):
		target.call("take_damage", rng.randf_range(8.0, 15.0), actor, "bullet")
