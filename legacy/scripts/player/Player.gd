class_name Player
extends CharacterBody3D
## Sakib in first person: walk, sprint, crouch, lean, aim, a suppressed pistol, takedowns and
## interaction, with head bob, landing dip, weapon sway, recoil and reload animation.

signal health_changed(hp: float)
signal died

const WALK := 3.0
const SPRINT := 5.4
const CROUCH_SPEED := 1.6
const JUMP := 3.8
const MAG := 12
const SENS := 0.0024
const HIP := Vector3(0.2, -0.2, -0.42)
const ADS := Vector3(0.0, -0.115, -0.34)

var level: Node = null
var health := 100.0
var mag := MAG
var crouching := false
var input_locked := false
var dead := false
var frozen := false   # scripted moves: planks, rides, lifts
var head: Node3D
var cam: Camera3D
var gun: Node3D
var flash: OmniLight3D

var _cap: CapsuleShape3D
var _shape: CollisionShape3D
var _bob := 0.0
var _lean := 0.0
var _recoil := 0.0
var _reload := 0.0
var _shake := 0.0
var _land := 0.0
var _aim := 0.0
var _step := 0.0
var _fire_cd := 0.0
var _flash_t := 0.0
var _air_vy := 0.0
var _sway := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 64
	_cap = CapsuleShape3D.new()
	_cap.radius = 0.32
	_cap.height = 1.75
	_shape = CollisionShape3D.new()
	_shape.shape = _cap
	_shape.position.y = 0.875
	add_child(_shape)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.cull_mask = 0xFFFFF & ~(1 << 19)   # Sky-lens markers live on layer 20
	head.add_child(cam)
	cam.current = true
	_build_gun()
	add_to_group("player")


func _build_gun() -> void:
	gun = Node3D.new()
	gun.position = HIP
	cam.add_child(gun)
	var dark := Humanoid.mat(Color(0.08, 0.08, 0.09))
	_vm_box(Vector3(0.045, 0.06, 0.24), Vector3(0, 0.02, -0.04), dark)
	_vm_box(Vector3(0.04, 0.12, 0.06), Vector3(0, -0.06, 0.04), dark)
	_vm_box(Vector3(0.036, 0.036, 0.15), Vector3(0, 0.02, -0.23), dark)
	_vm_box(Vector3(0.08, 0.09, 0.12), Vector3(0, -0.1, 0.1), Humanoid.mat(Color(0.55, 0.38, 0.27)))
	_vm_box(Vector3(0.075, 0.075, 0.32), Vector3(0.02, -0.12, 0.3), Humanoid.mat(Color(0.25, 0.3, 0.38)))
	flash = OmniLight3D.new()
	flash.position = Vector3(0, 0.02, -0.33)
	flash.light_color = Color(1.0, 0.8, 0.5)
	flash.omni_range = 4.0
	flash.light_energy = 0.0
	gun.add_child(flash)


func _vm_box(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun.add_child(mi)


func _unhandled_input(e: InputEvent) -> void:
	if dead or input_locked:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var k := SENS * (0.6 if _aim > 0.5 else 1.0)
		rotate_y(-e.relative.x * k)
		head.rotation.x = clampf(head.rotation.x - e.relative.y * k, -1.45, 1.45)
		_sway += e.relative * 0.0004
	elif e.is_action_pressed("interact"):
		var n = best_interactable()
		if n != null:
			n.interact(self)
	elif e.is_action_pressed("takedown"):
		_takedown()
	elif e.is_action_pressed("reload"):
		_start_reload()
	elif e.is_action_pressed("medkit"):
		_medkit()


func _physics_process(delta: float) -> void:
	if dead or frozen:
		return
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= 9.8 * delta
		_air_vy = minf(_air_vy, velocity.y)
	elif _air_vy < -2.0:
		_land = clampf(-_air_vy / 30.0, 0.0, 0.15)
		if _air_vy < -11.0:
			take_damage((-_air_vy - 11.0) * 9.0, global_position)
		AudioEventBus.emit_event("footstep", global_position, 60.0, WorldState.current_sector)
		_air_vy = 0.0
	var input := Vector2.ZERO
	var sprint := false
	if not input_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		crouching = Input.is_action_pressed("crouch")
		sprint = Input.is_action_pressed("sprint") and input.y < 0.0 and not crouching
		if Input.is_action_just_pressed("jump") and on_floor and not crouching:
			velocity.y = JUMP
	var spd := CROUCH_SPEED if crouching else (SPRINT if sprint else WALK)
	if _aim > 0.5:
		spd = minf(spd, 2.0)
	var dir := (global_transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var accel := 10.0 if on_floor else 3.0
	velocity.x = lerpf(velocity.x, dir.x * spd, 1.0 - exp(-accel * delta))
	velocity.z = lerpf(velocity.z, dir.z * spd, 1.0 - exp(-accel * delta))
	move_and_slide()
	_cap.height = lerpf(_cap.height, 1.1 if crouching else 1.75, 1.0 - exp(-12.0 * delta))
	_shape.position.y = _cap.height * 0.5
	var hv := Vector2(velocity.x, velocity.z).length()
	if on_floor and hv > 0.5:
		_step += hv * delta
		if _step >= (1.4 if hv < 4.0 else 1.9):
			_step = 0.0
			AudioEventBus.emit_event("footstep", global_position, 34.0 if crouching else (62.0 if hv > 4.0 else 50.0), WorldState.current_sector)


func _process(delta: float) -> void:
	if dead:
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	var aiming := Input.is_action_pressed("aim") and not input_locked and _reload <= 0.0
	_aim = move_toward(_aim, 1.0 if aiming else 0.0, delta * 6.0)
	cam.fov = lerpf(75.0, 52.0, _aim)
	if not input_locked and Input.is_action_just_pressed("fire"):
		_fire()
	var lean_in := 0.0
	if not input_locked:
		lean_in = Input.get_action_strength("lean_right") - Input.get_action_strength("lean_left")
	_lean = lerpf(_lean, lean_in, 1.0 - exp(-8.0 * delta))
	var hv := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hv > 0.3:
		_bob += delta * hv * 2.2
	var bob_amt := (0.02 if crouching else 0.035) * clampf(hv / WALK, 0.0, 1.6) * (1.0 - 0.7 * _aim)
	_land = move_toward(_land, 0.0, delta * 0.6)
	_shake = maxf(0.0, _shake - delta)
	var shake := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * _shake * 0.05
	head.position = Vector3(_lean * 0.35, lerpf(head.position.y, 1.0 if crouching else 1.6, 1.0 - exp(-10.0 * delta)), 0.0)
	cam.position = Vector3(cos(_bob) * bob_amt * 0.5, absf(sin(_bob)) * bob_amt - _land, 0.0) + shake
	cam.rotation.z = -_lean * 0.17
	_recoil = move_toward(_recoil, 0.0, delta * 5.0)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
	var p := HIP.lerp(ADS, _aim)
	p += Vector3(cos(_bob) * bob_amt * 0.4 - _sway.x, absf(sin(_bob)) * bob_amt * 0.5 + _sway.y, _recoil * 0.06)
	var rx := _recoil * 0.25
	if _reload > 0.0:
		_reload -= delta
		var k := 1.0 - _reload / 1.6
		rx -= sin(k * PI) * 0.9
		p.y -= sin(k * PI) * 0.12
		if _reload <= 0.0:
			_finish_reload()
	gun.position = p
	gun.rotation = Vector3(rx, -_sway.x * 2.0, _sway.x * 3.0)
	_flash_t = maxf(0.0, _flash_t - delta)
	flash.light_energy = 6.0 if _flash_t > 0.0 else 0.0


func best_interactable():
	var best = null
	var best_d := 2.6
	var fwd := -cam.global_basis.z
	for n in get_tree().get_nodes_in_group("interactables"):
		if not is_instance_valid(n) or not n.has_method("prompt"):
			continue
		if n.prompt() == "":
			continue
		var to: Vector3 = (n.global_position + Vector3(0, 0.9, 0)) - cam.global_position
		var d := to.length()
		if d < best_d and (d < 1.3 or fwd.dot(to / d) > 0.55):
			best = n
			best_d = d
	return best


func _fire() -> void:
	if _fire_cd > 0.0 or _reload > 0.0:
		return
	if mag <= 0:
		AudioEventBus.play_ui("dry_fire")
		_start_reload()
		return
	mag -= 1
	_fire_cd = 0.22
	_recoil = 1.0
	_flash_t = 0.05
	_shake = maxf(_shake, 0.06)
	AudioEventBus.emit_event("suppressed_shot", global_position, 85.0, WorldState.current_sector)
	var spread := (0.004 if _aim > 0.5 else 0.02) + clampf(velocity.length() / 60.0, 0.0, 0.05)
	var from := cam.global_position
	var b := cam.global_basis
	var fwd := (-b.z + b.x * _rng.randf_range(-spread, spread) + b.y * _rng.randf_range(-spread, spread)).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 150.0, 1 | 2 | 4 | 64)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var c = hit.collider
	if c is Actor:
		var local_y: float = hit.position.y - c.global_position.y
		var zone := "head" if local_y > 1.42 * (c.body.height / 1.65) else ("legs" if local_y < 0.85 else "torso")
		c.take_hit(55.0 if zone == "torso" else 32.0, zone, fwd)
		if level:
			level.blood(hit.position)
	elif level:
		level.impact(hit.position, hit.normal)
		PhysicsEventBus.report_impact(hit.position, "concrete_dusty", 1.5, WorldState.current_sector)


func _takedown() -> void:
	for a in get_tree().get_nodes_in_group("syndicate"):
		if a.state in ["dead", "ko", "dying", "combat"]:
			continue
		var to: Vector3 = a.global_position - global_position
		to.y = 0.0
		if to.length() < 1.8 and to.length() > 0.01:
			var facing_away: float = (-a.global_transform.basis.z).dot(to.normalized())
			if facing_away > 0.2:
				a.knockout()
				Game.stats["knockouts"] += 1
				_shake = 0.15
				return
	if level:
		level.toast("Takedown: get behind him, within arm's reach, before he sees you")


func _start_reload() -> void:
	if _reload > 0.0 or mag >= MAG or int(WorldState.resources.get("ammo", 0)) <= 0:
		return
	_reload = 1.6
	AudioEventBus.play_ui("reload")


func _finish_reload() -> void:
	var take := mini(MAG - mag, int(WorldState.resources.get("ammo", 0)))
	mag += take
	WorldState.add_resource("ammo", -take)


func _medkit() -> void:
	if health >= 100.0 or not WorldState.spend("medical", 1):
		return
	health = minf(100.0, health + 50.0)
	health_changed.emit(health)
	if level:
		level.toast("Bandaged: +50 health")


func take_damage(amount: float, from: Vector3) -> void:
	if dead:
		return
	health = maxf(0.0, health - amount)
	_shake = maxf(_shake, 0.25)
	health_changed.emit(health)
	if level:
		level.on_player_hurt(amount, from)
	if health <= 0.0:
		dead = true
		died.emit()


func freeze(on: bool) -> void:
	frozen = on
	velocity = Vector3.ZERO
	_air_vy = 0.0


func heal_full() -> void:
	health = 100.0
	health_changed.emit(health)
