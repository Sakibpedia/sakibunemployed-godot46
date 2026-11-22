class_name Actor
extends CharacterBody3D
## Everyone who is not Sakib: civilians, gatekeepers, career people, drivers, allies, captives,
## couriers and the syndicate. Behaviour runs on the built-in behaviour tree (scripts/ai).

signal died(actor: Actor, cause: String)

const SKINS := [Color(0.62, 0.45, 0.32), Color(0.55, 0.38, 0.27), Color(0.47, 0.32, 0.22), Color(0.4, 0.27, 0.19)]
const SHIRTS := [Color(0.92, 0.92, 0.88), Color(0.55, 0.7, 0.85), Color(0.6, 0.15, 0.18), Color(0.85, 0.7, 0.25),
	Color(0.25, 0.45, 0.3), Color(0.75, 0.55, 0.6), Color(0.35, 0.35, 0.4), Color(0.9, 0.5, 0.2)]
const LOWERS := [Color(0.2, 0.25, 0.4), Color(0.3, 0.3, 0.32), Color(0.45, 0.3, 0.2), Color(0.2, 0.35, 0.25), Color(0.5, 0.15, 0.2)]
const WOMEN := ["Mitu", "Nusrat", "Rina Apa", "Farzana", "Shirin", "Lipi", "Rumi"]
## Story people cannot be killed by a stray shot: the level would lose its gate, its advice or its ride.
const PROTECTED := ["gatekeeper", "career", "callback", "driver", "captive", "courier", "ally"]

var role := "civilian"
var display_name := ""
var faction := "civilian"
var gate_id := ""
var person := ""
var tag := ""
var info: Dictionary = {}
var patrol: Array = []
var home := Vector3.ZERO
var health := 100.0
var state := "idle"
var suspicion := 0.0
var last_known := Vector3.ZERO
var revealed := 0.0
var active := true
var level: Node = null
var body: Humanoid
var agent: NavigationAgent3D

var _bt: BTTask
var _shape: CollisionShape3D
var _wait := 0.0
var _pi := 0
var _cd := 0.0
var _think := 0.0
var _goal := Vector3.INF
var _dying_left := 0.0
var _hold := false
var _panic := 0.0
var _panic_from := Vector3.ZERO
var _look_t := 0.0
var _rng := RandomNumberGenerator.new()


func configure(r: String, legend: Dictionary) -> void:
	role = r
	info = legend
	display_name = legend.get("name", r.capitalize())
	gate_id = legend.get("gate", "")
	person = legend.get("person", "")
	tag = legend.get("tag", "")
	if person != "" and display_name == r.capitalize():
		display_name = person
	if r in ["goon", "gunman", "sniper", "lieutenant", "boss", "courier"]:
		faction = "syndicate" if r != "courier" else "civilian"
	elif r == "ally":
		faction = "ally"
	health = 160.0 if r == "lieutenant" else 100.0


func _ready() -> void:
	_rng.seed = hash(str(name)) ^ WorldState.save_seed
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 64
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	_shape.shape = cap
	_shape.position.y = 0.85
	add_child(_shape)
	body = Humanoid.new()
	add_child(body)
	body.setup(_appearance())
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.9
	agent.radius = 0.35
	agent.height = 1.7
	add_child(agent)
	home = global_position
	add_to_group("actors")
	add_to_group(faction)
	if faction == "syndicate":
		add_to_group("listeners")
	if role in ["gatekeeper", "career", "callback", "driver", "captive", "courier", "boss"]:
		add_to_group("interactables")
	if role == "sniper" and info.get("after_6", false):
		active = false
	_bt = _make_tree()


func _appearance() -> Dictionary:
	var a := {"skin": SKINS[_rng.randi_range(0, SKINS.size() - 1)], "shirt": SHIRTS[_rng.randi_range(0, SHIRTS.size() - 1)],
		"lower": LOWERS[_rng.randi_range(0, LOWERS.size() - 1)], "outfit": ["pants", "lungi", "pants", "panjabi"][_rng.randi_range(0, 3)],
		"height": _rng.randf_range(1.58, 1.74)}
	if person in WOMEN or info.get("female", false):
		a.outfit = "kameez"
		a.hat = "scarf"
		a.height = _rng.randf_range(1.48, 1.58)
	match role:
		"goon", "gunman", "sniper", "lieutenant":
			a.shirt = Color(0.1, 0.1, 0.12) if role != "lieutenant" else Color(0.35, 0.05, 0.08)
			a.lower = Color(0.12, 0.13, 0.18)
			a.outfit = "pants"
			a.armed = role != "goon"
			a.hat = "cap" if role == "sniper" else ""
		"boss":
			a.shirt = Color(0.93, 0.9, 0.82)
			a.outfit = "panjabi"
		"ally":
			a.shirt = Color(0.15, 0.55, 0.55)
	var look: String = info.get("look", "")
	match look:
		"doorman", "guard":
			a.shirt = Color(0.6, 0.55, 0.38)
			a.lower = Color(0.2, 0.2, 0.22)
			a.outfit = "uniform"
			a.hat = "cap"
		"imam":
			a.shirt = Color(0.96, 0.96, 0.93)
			a.outfit = "panjabi"
			a.hat = "tupi"
		"teacher":
			a.shirt = Color(0.9, 0.88, 0.8)
			a.outfit = "panjabi"
		"lawyer":
			a.shirt = Color(0.08, 0.08, 0.1)
			a.lower = Color(0.08, 0.08, 0.1)
			a.outfit = "pants"
		"shopkeeper":
			a.outfit = "lungi"
		"goon":
			a.shirt = Color(0.1, 0.1, 0.12)
			a.lower = Color(0.12, 0.13, 0.18)
			a.outfit = "pants"
		"boss":
			a.shirt = Color(0.93, 0.9, 0.82)
			a.lower = Color(0.85, 0.83, 0.78)
			a.outfit = "panjabi"
		"police":
			a.shirt = Color(0.25, 0.3, 0.45)
			a.lower = Color(0.2, 0.22, 0.3)
			a.outfit = "uniform"
			a.hat = "cap"
	var elder := look == "imam" or person == "Rina Apa" or bool(info.get("elder", false))
	var rec := DhakaMaterials.pick_face(_rng.randi(), String(a.get("outfit", "")) == "kameez", elder)
	if not rec.is_empty():
		a["face"] = String(rec["id"])
	return a


func _make_tree() -> BTTask:
	if bool(info.get("static", false)) and role in ["civilian", "courier"]:
		return BTSelector.new([
			BTSequence.new([BTCondition.new(func(a): return a._panic > 0.0), BTAction.new(func(a, dt): return a._flee(dt))]),
			BTAction.new(func(a, dt): return a._stand(dt)),
		])
	match role:
		"civilian", "courier":
			return BTSelector.new([
				BTSequence.new([BTCondition.new(func(a): return a._panic > 0.0), BTAction.new(func(a, dt): return a._flee(dt))]),
				BTAction.new(func(a, dt): return a._wander(dt)),
			])
		"goon", "gunman", "lieutenant":
			return BTSelector.new([
				BTSequence.new([BTCondition.new(func(a): return a.state == "combat"), BTAction.new(func(a, dt): return a._combat(dt))]),
				BTSequence.new([BTCondition.new(func(a): return a.state == "investigate" or a.state == "search"), BTAction.new(func(a, dt): return a._investigate(dt))]),
				BTAction.new(func(a, dt): return a._patrol(dt)),
			])
		"sniper":
			return BTSelector.new([
				BTSequence.new([BTCondition.new(func(a): return a.active and a.state == "combat"), BTAction.new(func(a, dt): return a._combat(dt))]),
				BTAction.new(func(a, dt): return a._stand(dt)),
			])
	return BTAction.new(func(a, dt): return a._stand(dt))


func _physics_process(dt: float) -> void:
	if state == "dead" or state == "ko":
		return
	if state == "dying":
		if not _hold:
			_dying_left -= dt
		body.look_target = _player_head()
		if _dying_left <= 0.0:
			LastWishDirector.timeout(self)
		return
	if not is_on_floor():
		velocity.y -= 9.8 * dt
	else:
		velocity.y = 0.0
	_think -= dt
	if _think <= 0.0:
		_think = 0.2
		if faction == "syndicate":
			_perceive(0.2)
	revealed = maxf(0.0, revealed - dt)
	_cd = maxf(0.0, _cd - dt)
	_panic = maxf(0.0, _panic - dt)
	_bt.tick(self, dt)
	move_and_slide()
	body.speed = Vector2(velocity.x, velocity.z).length()


# --- Behaviours -----------------------------------------------------------------

func _stand(dt: float) -> int:
	velocity.x = 0.0
	velocity.z = 0.0
	var p = _player()
	if p != null and global_position.distance_to(p.global_position) < 6.0:
		body.look_target = _player_head()
		if global_position.distance_to(p.global_position) < 4.0 and role != "sniper":
			_face(p.global_position, 3.0, dt)
	else:
		body.look_target = null
	return BTTask.RUNNING


func _wander(dt: float) -> int:
	body.crouch = 0.0
	if _wait > 0.0:
		_wait -= dt
		velocity.x = 0.0
		velocity.z = 0.0
		return BTTask.RUNNING
	if _goal == Vector3.INF or _go(_goal, 1.2):
		var map := get_world_3d().navigation_map
		var off := Vector3(_rng.randf_range(-10.0, 10.0), 0, _rng.randf_range(-10.0, 10.0))
		_goal = NavigationServer3D.map_get_closest_point(map, home + off)
		agent.target_position = _goal
		_wait = _rng.randf_range(1.5, 6.0)
	return BTTask.RUNNING


func _flee(dt: float) -> int:
	var away := global_position - _panic_from
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	var target := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, global_position + away.normalized() * 12.0)
	if _go(target, 3.8):
		body.pose = "cower"
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		body.pose = "normal"
	if _panic <= 0.05:
		body.pose = "normal"
	return BTTask.RUNNING


func _patrol(dt: float) -> int:
	body.aim = 0.0
	if patrol.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		_look_t += dt
		rotation.y += sin(_look_t * 0.4) * 0.3 * dt
		return BTTask.RUNNING
	if _wait > 0.0:
		_wait -= dt
		velocity.x = 0.0
		velocity.z = 0.0
		return BTTask.RUNNING
	if _go(patrol[_pi], 1.3):
		_pi = (_pi + 1) % patrol.size()
		_wait = _rng.randf_range(1.5, 3.5)
	return BTTask.RUNNING


func _investigate(dt: float) -> int:
	body.aim = 0.4
	if state == "search":
		_wait -= dt
		velocity.x = 0.0
		velocity.z = 0.0
		rotation.y += 1.2 * dt
		if _wait <= 0.0:
			state = "idle"
			suspicion = minf(suspicion, 30.0)
			_goal = Vector3.INF
		return BTTask.RUNNING
	if _go(last_known, 2.2):
		state = "search"
		_wait = 5.0
	return BTTask.RUNNING


func _combat(dt: float) -> int:
	var p = _player()
	if p == null or p.dead:
		state = "search"
		_wait = 4.0
		return BTTask.FAILURE
	var see := _sees(p)
	if see:
		last_known = p.global_position
	var dist := global_position.distance_to(p.global_position)
	body.look_target = _player_head()
	if role == "goon":
		body.aim = 0.0
		if dist > 1.5:
			_go(p.global_position, 3.6)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_face(p.global_position, 10.0, dt)
			if _cd <= 0.0:
				_cd = 1.1
				body.kick()
				p.take_damage(14.0, global_position)
		return BTTask.RUNNING
	body.aim = 1.0
	var max_range := 70.0 if role == "sniper" else 26.0
	if see and dist < max_range:
		velocity.x = 0.0
		velocity.z = 0.0
		_face(p.global_position, 8.0, dt)
		if _cd <= 0.0:
			_cd = 2.6 if role == "sniper" else _rng.randf_range(0.6, 1.0)
			_shoot(p, dist)
	elif role != "sniper":
		if _go(last_known, 3.2) and not see:
			state = "search"
			_wait = 6.0
	return BTTask.RUNNING


func _shoot(p, dist: float) -> void:
	body.kick()
	var muzzle := global_position + Vector3(0, 1.4, 0) - global_transform.basis.z * 0.5
	AudioEventBus.emit_event("gunshot", muzzle, 140.0, WorldState.current_sector)
	if level:
		level.tracer(muzzle, p.global_position + Vector3(0, 1.2, 0))
	var chance := 0.8 - dist / 45.0
	if p.crouching:
		chance -= 0.12
	if Vector2(p.velocity.x, p.velocity.z).length() > 2.0:
		chance -= 0.15
	if role == "sniper":
		chance = 0.45 if p.crouching else 0.55
	if _rng.randf() < clampf(chance, 0.08, 0.85):
		p.take_damage(26.0 if role == "sniper" else _rng.randf_range(9.0, 16.0), global_position)


# --- Senses ---------------------------------------------------------------------

func _perceive(step: float) -> void:
	if not active or role == "boss":
		return   # a boss wants to talk; his men do the watching
	if level and state != "combat" and level.in_conversation():
		return   # nobody new notices Sakib while he is answering a gate or talking
	var p = _player()
	if p == null or p.dead:
		return
	if _sees(p):
		var dist := global_position.distance_to(p.global_position)
		var rate := 500.0 / maxf(dist, 3.0)
		if p.crouching:
			rate *= 0.5
		if WorldState.in_sky_lens():
			rate *= 1.5
		if role == "sniper":
			rate *= 2.0
		suspicion = minf(100.0, suspicion + rate * step)
		last_known = p.global_position
		if suspicion >= 100.0 and state != "combat":
			enter_combat()
		elif suspicion >= 50.0 and state != "combat":
			state = "investigate"
	else:
		suspicion = maxf(0.0, suspicion - 6.0 * step)
		if state == "combat" and suspicion < 40.0:
			state = "search"
			_wait = 6.0


func _sees(p) -> bool:
	var eyes := global_position + Vector3(0, 1.6, 0)
	var target: Vector3 = p.global_position + Vector3(0, 0.95 if p.crouching else 1.4, 0)
	var to := target - eyes
	var dist := to.length()
	var max_d := (75.0 if role == "sniper" else 28.0) * WorldState.vision_multiplier(WorldState.current_sector)
	if dist > max_d:
		return false
	var fwd := -global_transform.basis.z
	if dist > 2.5 and fwd.dot(to / dist) < 0.57:
		return false
	var q := PhysicsRayQueryParameters3D.create(eyes, target, 1 | 2 | 8 | 64)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider == p


func hear(event_name: String, pos: Vector3, level_db: float) -> void:
	if faction != "syndicate" or not active or role == "boss" or state in ["dead", "ko", "dying", "combat"]:
		return
	if event_name == "footstep" and level_db < 47.0:
		return
	last_known = pos
	suspicion = maxf(suspicion, 60.0 if level_db >= 60.0 else 35.0)
	state = "investigate"
	_goal = Vector3.INF


func enter_combat() -> void:
	if state in ["dead", "ko", "dying"]:
		return
	state = "combat"
	suspicion = 100.0
	if level and level.radio_jammed:
		return
	for a in get_tree().get_nodes_in_group("syndicate"):
		if a != self and a.state in ["idle", "investigate", "search"] and a.global_position.distance_to(global_position) < 25.0:
			a.suspicion = 100.0
			a.last_known = last_known
			a.state = "combat"


func panic(from: Vector3) -> void:
	if faction == "syndicate" or state in ["dead", "dying", "ko"]:
		return
	if role == "civilian" or role == "courier":
		_panic = 6.0
		_panic_from = from


# --- Damage ---------------------------------------------------------------------

func take_hit(damage: float, zone: String, travel_dir: Vector3) -> void:
	if state in ["dead", "ko", "dying"]:
		return
	body.flinch(travel_dir)
	if role in PROTECTED:
		WorldState.change_rep("moral", -5)
		panic(global_position - travel_dir * 5.0)
		if level:
			level.toast("You shot at %s. People will remember that." % display_name)
		return
	health = 0.0 if zone == "head" else health - damage
	if faction == "syndicate" and health > 0.0:
		last_known = global_position - travel_dir * 8.0
		enter_combat()
	elif faction != "syndicate":
		WorldState.change_rep("moral", -5)
		panic(global_position - travel_dir * 5.0)
	if health <= 0.0:
		body.fall(travel_dir)
		_down(zone == "head")


func knockout() -> void:
	if state in ["dead", "ko", "dying"]:
		return
	state = "ko"
	body.fall(-global_transform.basis.z)
	body.pose = "dead"
	_disable()
	died.emit(self, "ko")


func _down(instant: bool) -> void:
	velocity = Vector3.ZERO
	_disable()
	var cause: String = level.hazard_at(global_position) if level else "gunshot"
	if faction == "syndicate" and LastWishDirector.on_enemy_downed(self, cause, instant):
		return
	_die(cause)


func enter_dying_pose(seconds: float = 90.0) -> void:
	state = "dying"
	body.pose = "dying"
	_dying_left = seconds
	add_to_group("interactables")


func dying_left() -> float:
	return _dying_left


## While Sakib listens to the last wish, the gate's own timer does the counting.
func hold_bleeding(on: bool) -> void:
	_hold = on


func die_quietly() -> void:
	_die(info.get("lw_cause", "gunshot"))


func _die(cause: String) -> void:
	state = "dead"
	body.pose = "dead"
	body.look_target = null
	remove_from_group("interactables")
	died.emit(self, cause)


func _disable() -> void:
	velocity = Vector3.ZERO
	collision_layer = 0
	remove_from_group("listeners")
	body.aim = 0.0


# --- Interaction ----------------------------------------------------------------

func prompt() -> String:
	if state == "dying":
		return "E  Hear his last wish (5 questions, %d s left)" % int(_dying_left)
	if state in ["dead", "ko"]:
		return ""
	match role:
		"gatekeeper", "boss":
			return "E  Talk to %s (exam gate)" % display_name
		"career", "callback":
			return "E  Talk to %s" % display_name
		"driver":
			return "E  Ride with %s" % display_name
		"captive":
			return "E  Free %s" % display_name
		"courier":
			return "E  Search %s" % display_name if info.get("key", "") != "" else ""
	return ""


func interact(_p) -> void:
	if level == null:
		return
	if state == "dying":
		level.begin_last_wish(self)
	else:
		level.actor_interact(self)


# --- Helpers --------------------------------------------------------------------

func _player():
	return level.player if level else null


func _player_head():
	var p = _player()
	return p.global_position + Vector3(0, 1.5, 0) if p != null else null


func _go(target: Vector3, spd: float) -> bool:
	if _goal.distance_to(target) > 0.5:
		_goal = target
		agent.target_position = target
	if global_position.distance_to(target) < 1.0 or agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	var d := agent.get_next_path_position() - global_position
	d.y = 0.0
	if d.length() < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return false
	d = d.normalized()
	velocity.x = d.x * spd
	velocity.z = d.z * spd
	_face(global_position + d, 8.0, get_physics_process_delta_time())
	return false


func _face(p: Vector3, rate: float, dt: float) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-rate * dt))
