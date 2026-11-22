class_name Player
extends CharacterBody3D
## S M Nazmuz Sakib: third-person by default (V switches to first person), over-the-shoulder aiming,
## walk / jog / sprint / crouch / jump, fists, an iron rod and a pistol, a torch for the night,
## interaction with people, ghosts and posters (E), vehicles (F), bandages (H).
## His body is the same skinned HumanoidRig as everyone else, wearing his own face.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal died
signal weapon_changed(weapon: String)
signal interact_target_changed(label: Dictionary)

const WALK := 2.2
const JOG := 4.4
const SPRINT := 6.8
const CROUCH := 1.5
const JUMP := 4.8
const GRAVITY := 18.0
const MAG := 12
const WEAPONS := ["fists", "rod", "pistol"]

var rig: HumanoidRig
var pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var torch: SpotLight3D
var first_person := false
var weapon := "fists"
var mag := 0
var yaw := 0.0
var pitch := -0.15
var vehicle: Vehicle = null
var crouching := false
var aiming := false
var dead := false
var _anim := "idle"
var _attack_t := 0.0
var _reload_t := 0.0
var _scan_t := 0.0
var _step_t := 0.0
var _torch_drain := 0.0
var _focus: Object = null
var _focus_kind := ""
var _poster: Dictionary = {}
var _pistol_mesh: MeshInstance3D
var _rod_mesh: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.76
	cs.shape = cap
	cs.position = Vector3(0, 0.88, 0)
	add_child(cs)
	rig = HumanoidRig.new()
	rig.name = "Body"
	add_child(rig)
	var rec := DhakaMaterials.face_record("sakib")
	var skin := Color(0.69, 0.5, 0.37)
	if not rec.is_empty():
		var sk: Array = rec.get("skin", [0.69, 0.5, 0.37])
		skin = Color(float(sk[0]), float(sk[1]), float(sk[2]))
	rig.build({"gender": "m", "height": 1.72, "build": "average", "skin": skin, "face": "sakib", "hair": Color(0.045, 0.04, 0.038),
		"hair_style": "curly", "outfit": "shirt_trousers", "shirt": Color(0.75, 0.8, 0.9), "lower": Color(0.16, 0.18, 0.24),
		"cloth": "shirt_check_blue"})
	_attach_weapons()
	pivot = Node3D.new()
	pivot.top_level = true
	add_child(pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 3.4
	spring.collision_mask = 1
	spring.margin = 0.2
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	spring.shape = sph
	pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.08
	camera.far = 2400.0
	spring.add_child(camera)
	camera.current = true
	torch = SpotLight3D.new()
	torch.light_color = Color(1.0, 0.95, 0.85)
	torch.light_energy = 6.0
	torch.spot_range = 22.0
	torch.spot_angle = 22.0
	torch.shadow_enabled = true
	torch.visible = false
	camera.add_child(torch)
	torch.position = Vector3(0.3, -0.2, -0.3)
	if not Game.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.health_changed.connect(func(_v: float) -> void: pass)


func _attach_weapons() -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	rig.skeleton.add_child(att)
	_pistol_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.12, 0.2)
	_pistol_mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.09)
	m.metallic = 0.7
	m.roughness = 0.35
	_pistol_mesh.material_override = m
	_pistol_mesh.position = Vector3(0, -0.12, -0.06)
	att.add_child(_pistol_mesh)
	_rod_mesh = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 0.9
	_rod_mesh.mesh = cm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.3, 0.22, 0.18)
	rm.metallic = 0.8
	_rod_mesh.material_override = rm
	_rod_mesh.position = Vector3(0, -0.3, -0.05)
	att.add_child(_rod_mesh)
	_show_weapon()


func _show_weapon() -> void:
	_pistol_mesh.visible = weapon == "pistol" and not first_person
	_rod_mesh.visible = weapon == "rod" and not first_person


func is_alive() -> bool:
	return not dead


func in_vehicle() -> bool:
	return vehicle != null


func teleport(p: Vector3) -> void:
	if vehicle != null:
		_exit_vehicle()
	global_position = p + Vector3(0, 0.2, 0)
	velocity = Vector3.ZERO


# --- Input -------------------------------------------------------------------------------------

## Turn the camera by a screen-space drag (mouse motion, or the look pad in TouchControls).
func look(rel: Vector2) -> void:
	if dead:
		return
	var sens := 0.0025 * Game.mouse_sensitivity * (0.55 if aiming else 1.0)
	yaw -= rel.x * sens
	pitch -= rel.y * sens * (-1.0 if Game.invert_y else 1.0)
	pitch = clampf(pitch, -1.25, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Game.touch_mode:
		look((event as InputEventMouseMotion).relative)
	if event.is_action_pressed("camera"):
		first_person = not first_person
		rig.visible = not first_person
		_show_weapon()
	elif event.is_action_pressed("weapon_next"):
		_cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		_cycle_weapon(-1)
	elif event.is_action_pressed("torch"):
		_toggle_torch()
	elif event.is_action_pressed("vehicle"):
		if vehicle != null:
			_exit_vehicle()
		else:
			_try_enter_vehicle()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("bandage"):
		if GameState.health < GameState.MAX_HEALTH and GameState.take_item("bandages"):
			GameState.set_health(GameState.health + 35.0)
			AudioEventBus.play_ui("pickup")
	elif event.is_action_pressed("reload"):
		_reload()
	elif event.is_action_pressed("horn") and vehicle != null:
		AudioEventBus.emit_event("horn", global_position, 100.0)


func _cycle_weapon(dir: int) -> void:
	var avail: Array = ["fists"]
	if GameState.count("iron_rod") > 0:
		avail.append("rod")
	if GameState.count("pistol") > 0:
		avail.append("pistol")
	var i := avail.find(weapon)
	weapon = String(avail[(i + dir + avail.size()) % avail.size()])
	_show_weapon()
	weapon_changed.emit(weapon)


func _toggle_torch() -> void:
	if not torch.visible and GameState.count("batteries") <= 0:
		Services.say_toast({"bn": "টর্চের ব্যাটারি শেষ।", "en": "The torch batteries are dead."}, "warn")
		return
	torch.visible = not torch.visible
	AudioEventBus.play_ui("click")


func _reload() -> void:
	if weapon != "pistol" or _reload_t > 0.0 or mag >= MAG:
		return
	var need := MAG - mag
	var have := GameState.count("pistol_ammo")
	if have <= 0:
		AudioEventBus.play_ui("dry_fire")
		return
	var take := mini(need, have)
	GameState.take_item("pistol_ammo", take)
	mag += take
	_reload_t = 1.4
	AudioEventBus.play_ui("reload")


# --- Interaction ---------------------------------------------------------------------------------

func _scan(delta: float) -> void:
	_scan_t -= delta
	if _scan_t > 0.0:
		return
	_scan_t = 0.15
	var best: Object = null
	var best_d := 2.8
	var fwd := -Vector3(sin(yaw), 0, cos(yaw))
	for n in get_tree().get_nodes_in_group(&"interactable"):
		var n3 := n as Node3D
		if n3 == null or n3 == self:
			continue
		var to := n3.global_position - global_position
		to.y = 0
		var d := to.length()
		if d > best_d:
			continue
		if d > 0.8 and to.normalized().dot(fwd) < 0.2:
			continue
		if n3.has_method(&"interact_options") and (n3.call("interact_options", self) as Array).is_empty():
			continue
		best = n3
		best_d = d
	_poster = {}
	var kind := ""
	if best != null:
		kind = "actor"
	elif Services.posters != null:
		var ps: PosterSystem = Services.posters
		_poster = ps.nearest(global_position, 2.2)
		if not _poster.is_empty():
			kind = "poster"
	var label := {}
	if kind == "actor":
		var opts: Array = best.call("interact_options", self)
		label = (opts[0] as Dictionary).get("label", {})
	elif kind == "poster":
		label = {"bn": "পোস্টার", "en": "Poster"}
	if best != _focus or kind != _focus_kind:
		_focus = best
		_focus_kind = kind
		interact_target_changed.emit(label)


func _interact() -> void:
	var hud: Node = Services.hud
	if _focus_kind == "actor" and _focus != null and is_instance_valid(_focus):
		var target: Node = _focus
		var opts: Array = target.call("interact_options", self)
		if opts.size() == 1 or hud == null:
			target.call("interact", self, String((opts[0] as Dictionary)["id"]))
		else:
			var nm: Variant = target.call("display_name") if target.has_method(&"display_name") else {"bn": "", "en": ""}
			hud.call("show_options", nm, opts, func(id: String) -> void:
				if is_instance_valid(target):
					target.call("interact", self, id))
	elif _focus_kind == "poster" and not _poster.is_empty():
		var ps: PosterSystem = Services.posters
		var e := _poster
		var opts2 := ps.options_for(e)
		if opts2.size() == 1 or hud == null:
			ps.use(e, "read")
		else:
			hud.call("show_options", {"bn": "পোস্টার", "en": "Poster"}, opts2, func(id: String) -> void: ps.use(e, id))
	else:
		Missions.on_interact_world(global_position)


func _try_enter_vehicle() -> void:
	var traffic: TrafficSystem = Services.traffic
	if traffic == null:
		return
	var v := traffic.nearest_vehicle(global_position, 3.5)
	if v == null:
		return
	if not v.can_drive():
		Services.say_toast({"bn": "এটা চালানো যায় না। CNG, গাড়ি বা মোটরসাইকেল নাও।", "en": "You can't drive that. Take a CNG, car or motorbike."}, "info")
		return
	vehicle = v
	v.enter(self)
	collision_layer = 0
	collision_mask = 0
	rig.visible = false
	torch.visible = false


func _exit_vehicle() -> void:
	if vehicle == null:
		return
	var v := vehicle
	vehicle = null
	v.exit_vehicle()
	global_position = v.global_position + v.global_transform.basis.x * -1.8 + Vector3(0, 0.3, 0)
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	rig.visible = not first_person


# --- Damage --------------------------------------------------------------------------------------

func take_damage(amount: float, _source: Object, kind: String = "bullet") -> void:
	if dead:
		return
	GameState.set_health(GameState.health - amount)
	if kind != "ghost" or _rng.randf() < 0.1:
		rig.gesture("hit")
	var hud: Node = Services.hud
	if hud != null and hud.has_method(&"flash_damage"):
		hud.call("flash_damage", clampf(amount / 25.0, 0.15, 1.0))
	if GameState.health <= 0.0:
		_die()


func _die() -> void:
	dead = true
	GameState.bump("deaths")
	died.emit()
	if vehicle != null:
		_exit_vehicle()
	var hud: Node = Services.hud
	if hud != null and hud.has_method(&"big_message"):
		hud.call("big_message", {"bn": "অজ্ঞান!", "en": "KNOCKED OUT"}, UiKit.RED)
	await get_tree().create_timer(2.5).timeout
	await Game.fade_to(1.0, 0.6)
	var lost := GameState.money / 10
	GameState.add_money(-lost)
	GameState.set_health(60.0)
	GameState.skip_to(fmod(GameState.hour() + 3.0, 24.0))
	if Services.heat != null:
		Services.heat.call("clear")
	teleport(Services.city.poi_pos("clinic") if Services.city != null else global_position)
	dead = false
	Services.say_toast({"bn": "জনতা ক্লিনিকে জ্ঞান ফিরল। চিকিৎসার খরচ ৳%s।" % UiKit.bengali_digits(str(lost)),
		"en": "You woke up at Janata Clinic. The bill was Tk %d." % lost}, "warn")
	Game.fade_to(0.0, 0.8)


# --- Per frame -----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_attack_t -= delta
	_reload_t -= delta
	if dead:
		rig.animate(delta, 0.0, "dead")
		_update_camera(delta)
		return
	if vehicle != null:
		_drive(delta)
		_update_camera(delta)
		return
	aiming = Input.is_action_pressed("aim") and weapon == "pistol"
	crouching = Input.is_action_pressed("crouch")
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := Basis(Vector3.UP, yaw)
	var dir := (cam_basis * Vector3(input.x, 0, input.y))
	var speed := JOG
	if Input.is_action_pressed("sprint") and not aiming:
		speed = SPRINT
	if crouching:
		speed = CROUCH
	elif aiming:
		speed = WALK
	var target_v := dir * speed
	var accel := 10.0 if is_on_floor() else 2.5
	velocity.x = lerpf(velocity.x, target_v.x, clampf(delta * accel, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target_v.z, clampf(delta * accel, 0.0, 1.0))
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not crouching:
			velocity.y = JUMP
		else:
			velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	GameState.bump("distance_m", hspeed * delta)
	# face the camera when aiming or in first person, otherwise the way we move
	if aiming or first_person:
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 14.0, 0.0, 1.0))
	elif hspeed > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), clampf(delta * 10.0, 0.0, 1.0))
	if Input.is_action_pressed("fire") and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Game.touch_mode):
		_attack()
	_anim = "crouch" if crouching else ("aim" if aiming else ("run" if hspeed > 5.0 else ("walk" if hspeed > 0.2 else "idle")))
	rig.animate(delta, hspeed, _anim)
	_steps(delta, hspeed)
	_torch_tick(delta)
	_scan(delta)
	_update_camera(delta)
	GameState.player_position = global_position
	GameState.player_rotation = rotation.y
	GameState.has_position = true


func _steps(delta: float, hspeed: float) -> void:
	if hspeed < 0.5 or not is_on_floor():
		return
	_step_t -= delta * hspeed
	if _step_t <= 0.0:
		_step_t = 1.6
		AudioEventBus.emit_event("footstep", global_position, 40.0 if crouching else (70.0 if hspeed > 5.0 else 55.0))


func _torch_tick(delta: float) -> void:
	if not torch.visible:
		return
	_torch_drain += delta
	if _torch_drain > 90.0:
		_torch_drain = 0.0
		if not GameState.take_item("batteries"):
			torch.visible = false
	var ghosts: Node = Services.ghosts
	if ghosts == null:
		return
	var fwd := -camera.global_transform.basis.z
	for g in ghosts.call("active_ghosts"):
		var gn := g as Ghost
		var to := gn.global_position + Vector3(0, 1.2, 0) - camera.global_position
		if to.length() < 22.0 and to.normalized().dot(fwd) > cos(deg_to_rad(16.0)):
			gn.hurt_by_light(delta * 1.4)


func _attack() -> void:
	if _attack_t > 0.0:
		return
	match weapon:
		"pistol":
			if _reload_t > 0.0:
				return
			if mag <= 0:
				_attack_t = 0.3
				AudioEventBus.play_ui("dry_fire")
				_reload()
				return
			_attack_t = 0.28
			mag -= 1
			_fire()
		_:
			_attack_t = 0.55 if weapon == "fists" else 0.75
			rig.gesture("punch")
			var dmg := 10.0 if weapon == "fists" else 24.0
			var fwd := -global_transform.basis.z
			for c in get_tree().get_nodes_in_group(&"citizens"):
				var cz := c as Citizen
				if cz == null or not cz.is_alive():
					continue
				var to := cz.global_position - global_position
				if to.length() < 1.7 and to.normalized().dot(fwd) > 0.5:
					cz.take_damage(dmg, self, "melee")
					AudioEventBus.emit_event("punch", cz.global_position, 70.0)
					break
			if weapon == "rod" and Services.ghosts != null:
				for g in Services.ghosts.call("active_ghosts"):
					var gn := g as Ghost
					if gn.global_position.distance_to(global_position) < 2.2:
						gn.hurt_by_light(0.8)          # iron drives a bhoot back (folk belief)


func _fire() -> void:
	rig.gesture("recoil")
	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	var spread := 0.004 if aiming else 0.025
	dir = (dir + Vector3(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 150.0, 1 | 2 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var muzzle := global_position + Vector3(0, 1.45, 0) - global_transform.basis.z * 0.5
	AudioEventBus.emit_event("gunshot", muzzle, 150.0)
	Services.gunshot.emit(muzzle)
	Services.report_crime("shooting", global_position, true)
	var hud: Node = Services.hud
	if hud != null and hud.has_method(&"muzzle_flash"):
		hud.call("muzzle_flash")
	if hit.is_empty():
		return
	var col: Object = hit["collider"]
	if col is Citizen:
		var cz := col as Citizen
		var head := (hit["position"] as Vector3).y > cz.global_position.y + 1.45
		cz.take_damage(80.0 if head else 34.0, self, "bullet")
	elif col is Vehicle:
		AudioEventBus.emit_event("impact", hit["position"], 90.0)


# --- Vehicle and camera ----------------------------------------------------------------------------

func _drive(delta: float) -> void:
	var throttle := Input.get_axis("move_back", "move_forward")
	var steer := Input.get_axis("move_right", "move_left")
	vehicle.drive_input(delta, throttle, steer, Input.is_action_pressed("jump"))
	global_position = vehicle.global_position + Vector3(0, 0.5, 0)
	GameState.player_position = global_position
	_scan_t = 1.0


func _update_camera(delta: float) -> void:
	var base := global_position
	var arm := 3.4
	var height := 1.62
	var shoulder := 0.45
	if vehicle != null:
		base = vehicle.global_position
		arm = 7.5 if vehicle.kind in ["car", "cng"] else 5.0
		height = 2.4
		shoulder = 0.0
		yaw = lerp_angle(yaw, vehicle.rotation.y, clampf(delta * 2.0, 0.0, 1.0))
	elif first_person:
		arm = 0.0
		shoulder = 0.0
		height = 1.62 if not crouching else 1.05
	elif aiming:
		arm = 1.5
		shoulder = 0.55
	elif crouching:
		height = 1.1
	spring.spring_length = lerpf(spring.spring_length, arm, clampf(delta * 10.0, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 55.0 if aiming else 70.0, clampf(delta * 8.0, 0.0, 1.0))
	pivot.global_position = base + Vector3(0, height, 0) + Basis(Vector3.UP, yaw) * Vector3(shoulder, 0, 0)
	pivot.rotation = Vector3(pitch, yaw, 0)
