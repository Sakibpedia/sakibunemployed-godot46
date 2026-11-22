class_name Citizen
extends CharacterBody3D
## A person in the open world. The body is a CharacterBody3D; the parts are injected components:
##   ActorVisuals  the skinned HumanoidRig, speech bubble and marker
##   ActorAI       states, senses, chatter, quizzing, fighting
##   ActorHealth   health, bleeding out, the dying questions, becoming a ghost
## Every Citizen can be talked to, asked a question, quizzed by, and every one of them may ask you
## one before letting you pass (the brief: "every NPC is a potential gatekeeper").
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal arrived

const GRAVITY := 18.0

var profile: Dictionary = {}
var services: Node = null
var visuals: ActorVisuals
var ai: ActorAI
var health: ActorHealth
var anim_state := "idle"
var mission_tag := ""            # set by MissionDirector for mission characters
var persistent := false          # mission and named people are never recycled
var _target := Vector3.INF
var _speed := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _avoid := 0.0
var _anim_skip := 0


func setup(p: Dictionary, svc: Node) -> void:
	profile = p
	services = svc
	name = "Citizen_%s" % String(p.get("id", "x"))
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | 8
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = float((p.get("look", {}) as Dictionary).get("height", 1.7))
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5, 0)
	add_child(cs)
	visuals = ActorVisuals.new()
	visuals.name = "Visuals"
	add_child(visuals)
	visuals.setup(self)
	health = ActorHealth.new()
	health.name = "Health"
	add_child(health)
	health.setup(self, svc)
	ai = ActorAI.new()
	ai.name = "AI"
	add_child(ai)
	ai.setup(self, svc)
	add_to_group(&"citizens")
	add_to_group(&"listeners")
	add_to_group(&"interactable")
	floor_snap_length = 0.4


func display_name() -> Dictionary:
	return profile.get("name", {"bn": "পথচারী", "en": "Passer-by"})


func is_alive() -> bool:
	return health != null and not health.is_dead()


# --- Movement -----------------------------------------------------------------------------------

func move_to(target: Vector3, speed: float) -> void:
	_target = Vector3(target.x, global_position.y, target.z)
	_speed = speed


func stop_moving() -> void:
	_target = Vector3.INF
	_speed = 0.0


func has_target() -> bool:
	return _target != Vector3.INF


func face_toward(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 0.25)


func _physics_process(delta: float) -> void:
	if health.is_dead() or health.is_dying():
		velocity = Vector3(0, velocity.y - GRAVITY * delta, 0) if not is_on_floor() else Vector3.ZERO
		move_and_slide()
		_animate(delta, 0.0)
		return
	ai.tick(delta)
	var want := Vector3.ZERO
	if _target != Vector3.INF:
		var to := _target - global_position
		to.y = 0
		var dist := to.length()
		if dist < 0.5:
			stop_moving()
			arrived.emit()
		else:
			want = to / dist * _speed
			want = _avoid_obstacles(want, delta)
	var horiz := Vector3(velocity.x, 0, velocity.z).lerp(want, clampf(delta * 6.0, 0.0, 1.0))
	velocity.x = horiz.x
	velocity.z = horiz.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	if horiz.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-horiz.x, -horiz.z), clampf(delta * 8.0, 0.0, 1.0))
	# unstick: if we barely moved while trying to, sidestep
	if want.length() > 0.3:
		if global_position.distance_to(_last_pos) < 0.02:
			_stuck_t += delta
			if _stuck_t > 1.2:
				_avoid = 1.0 if randf() < 0.5 else -1.0
				_stuck_t = 0.0
		else:
			_stuck_t = 0.0
	_last_pos = global_position
	_animate(delta, horiz.length())


func _avoid_obstacles(want: Vector3, delta: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.9, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + want.normalized() * 1.4, 1 | 2 | 4)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty() or _avoid != 0.0:
		var side := Vector3(-want.z, 0, want.x).normalized() * (_avoid if _avoid != 0.0 else 1.0)
		_avoid = move_toward(_avoid, 0.0, delta * 0.8)
		return (want.normalized() * 0.4 + side).normalized() * want.length()
	return want


func _animate(delta: float, speed: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var d := cam.global_position.distance_to(global_position)
		if d > 90.0:
			visuals.visible = false
			return
		visuals.visible = true
		if d > 40.0:
			_anim_skip = (_anim_skip + 1) % 3
			if _anim_skip != 0:
				return
			delta *= 3.0
	var st := anim_state
	if health.is_dead():
		st = "dead"
	elif health.is_dying():
		st = "kneel"
	visuals.rig.animate(delta, speed, st)


# --- Talking and interaction ---------------------------------------------------------------------

func say(line: Dictionary, seconds: float = 3.5, priority: int = 0) -> void:
	if line.is_empty():
		return
	var speaker := {"id": String(profile.get("id", "")), "name": display_name(), "voice": profile.get("voice", {}), "face": profile.get("face", "")}
	Voice.speak(speaker, line, priority, global_position)
	visuals.bubble(Game.text(line), seconds)


func interact_options(_player: Node) -> Array:
	var opts: Array = []
	if health.is_dying():
		opts.append({"id": "listen", "label": {"bn": "শেষ প্রশ্ন শোনো", "en": "Hear the last questions"}})
		opts.append({"id": "finish", "label": {"bn": "শেষ করে দাও", "en": "Finish him"}})
		return opts
	if health.is_dead():
		return opts
	if mission_tag != "":
		opts.append({"id": "mission", "label": {"bn": "কথা বলো", "en": "Talk"}})
	if ai.offers_quiz:
		opts.append({"id": "duel", "label": {"bn": "প্রশ্নের লড়াই মেনে নাও", "en": "Accept the question duel"}})
	opts.append({"id": "talk", "label": {"bn": "আলাপ করো", "en": "Chat"}})
	opts.append({"id": "rumour", "label": {"bn": "খবর জিজ্ঞেস করো", "en": "Ask for news"}})
	if String(profile.get("profession", "")) not in ["police", "goon"]:
		opts.append({"id": "challenge", "label": {"bn": "প্রশ্নে চ্যালেঞ্জ করো", "en": "Challenge to a quiz"}})
	return opts


func interact(player: Node, option_id: String) -> void:
	match option_id:
		"listen":
			health.ask_dying_questions(player)
		"finish":
			health.finish_off(player)
		"mission":
			Missions.on_talk(self)
		"duel", "challenge":
			ai.start_duel(option_id == "challenge")
		"talk":
			face_toward(player.global_position)
			say(ChatterAI.line(profile, "smalltalk", ai.context(), ai.rng), 4.0, 1)
			visuals.rig.gesture("talk")
		"rumour":
			face_toward(player.global_position)
			say(ChatterAI.line(profile, "rumour", ai.context(), ai.rng), 4.5, 1)


## AudioEventBus calls this for every loud enough sound.
func hear(event_name: String, pos: Vector3, level: float) -> void:
	if ai != null:
		ai.hear(event_name, pos, level)


func take_damage(amount: float, source: Node, kind: String = "bullet") -> void:
	if health != null:
		health.take_damage(amount, source, kind)
