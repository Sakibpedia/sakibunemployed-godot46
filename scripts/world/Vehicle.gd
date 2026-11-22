class_name Vehicle
extends CharacterBody3D
## Rickshaws, CNG auto-rickshaws, local buses, cars, motorbikes and trucks. AI vehicles drive their
## lane (on the left, as in Bangladesh), brake for anything in front and honk. Sakib can take one
## (F): CNGs, cars and motorbikes are driveable with arcade handling; taking one from its driver is
## a crime.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const SPECS := {
	"rickshaw": {"size": Vector3(1.2, 1.9, 2.4), "speed": 4.0, "drive": false, "color": [Color(0.85, 0.15, 0.2), Color(0.2, 0.4, 0.8), Color(0.95, 0.75, 0.1)]},
	"cng": {"size": Vector3(1.4, 1.75, 2.7), "speed": 11.0, "drive": true, "color": [Color(0.15, 0.55, 0.25)]},
	"bus": {"size": Vector3(2.5, 3.0, 10.5), "speed": 10.0, "drive": false, "color": [Color(0.75, 0.15, 0.15), Color(0.2, 0.35, 0.7), Color(0.9, 0.85, 0.75)]},
	"car": {"size": Vector3(1.8, 1.45, 4.3), "speed": 13.0, "drive": true, "color": [Color(0.9, 0.9, 0.9), Color(0.15, 0.15, 0.18), Color(0.6, 0.62, 0.66), Color(0.55, 0.1, 0.1)]},
	"motorbike": {"size": Vector3(0.7, 1.3, 2.0), "speed": 14.0, "drive": true, "color": [Color(0.1, 0.1, 0.12), Color(0.7, 0.1, 0.1)]},
	"truck": {"size": Vector3(2.4, 3.2, 8.0), "speed": 9.0, "drive": false, "color": [Color(0.9, 0.6, 0.1), Color(0.3, 0.45, 0.2)]},
}

var kind := "cng"
var lanes: Array = []
var lane := -1
var lane_seg := 0
var lane_t := 0.0
var speed := 0.0
var max_speed := 10.0
var player_driven := false
var has_driver := true
var _driver: HumanoidRig
var _rng := RandomNumberGenerator.new()
var _horn_t := 0.0
var _steer := 0.0
var _size := Vector3.ONE


func setup(k: String, lane_list: Array, lane_index: int, rng_seed: int) -> void:
	kind = k
	lanes = lane_list
	lane = lane_index
	_rng.seed = rng_seed
	var spec: Dictionary = SPECS.get(k, SPECS["cng"])
	_size = spec["size"]
	max_speed = float(spec["speed"]) * _rng.randf_range(0.8, 1.05)
	collision_layer = 4
	collision_mask = 1 | 4
	add_to_group(&"vehicles")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = _size
	cs.shape = bs
	cs.position = Vector3(0, _size.y * 0.5, 0)
	add_child(cs)
	var cols: Array = spec["color"]
	_build_body(cols[_rng.randi_range(0, cols.size() - 1)])
	if k != "rickshaw" or true:
		_driver = HumanoidRig.new()
		add_child(_driver)
		var p := PersonGenerator.make(_rng.randi(), "ped", "")
		var look: Dictionary = p["look"]
		look["outfit"] = "lungi_shirt" if k == "rickshaw" or k == "cng" else "shirt_trousers"
		_driver.build(look)
		_driver.set_shadows(false)
		_driver.position = _driver_seat()
		_driver.animate(0.1, 0.0, "drive")


func can_drive() -> bool:
	return bool((SPECS.get(kind, {}) as Dictionary).get("drive", false))


func _driver_seat() -> Vector3:
	match kind:
		"rickshaw":
			return Vector3(0, 0.55, 0.75)
		"motorbike":
			return Vector3(0, 0.35, 0.1)
		"bus", "truck":
			return Vector3(-0.7, 0.9, -_size.z * 0.5 + 1.2)
	return Vector3(-0.3, 0.2, -0.3)


func _part(size: Vector3, pos: Vector3, col: Color, metal: float = 0.3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = 0.45
	mi.material_override = m
	mi.position = pos
	add_child(mi)


func _wheel(r: float, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.18
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.05)
	mi.material_override = m
	mi.rotation = Vector3(0, 0, PI * 0.5)
	mi.position = pos
	add_child(mi)


func _build_body(col: Color) -> void:
	var s := _size
	match kind:
		"rickshaw":
			_part(Vector3(1.0, 0.2, 0.6), Vector3(0, 0.75, 0.35), col)
			_part(Vector3(1.05, 0.06, 0.9), Vector3(0, 1.75, 0.45), Color(0.08, 0.08, 0.1), 0.0)
			_part(Vector3(0.06, 0.06, 1.6), Vector3(0, 0.6, -0.5), Color(0.2, 0.2, 0.22))
			_part(Vector3(0.9, 0.45, 0.06), Vector3(0, 1.0, 0.68), col.lightened(0.25), 0.0)
			_wheel(0.35, Vector3(-0.55, 0.35, 0.4))
			_wheel(0.35, Vector3(0.55, 0.35, 0.4))
			_wheel(0.35, Vector3(0, 0.35, -1.0))
		"cng":
			_part(Vector3(1.35, 1.0, 2.2), Vector3(0, 1.0, 0.1), col)
			_part(Vector3(1.3, 0.12, 2.3), Vector3(0, 1.62, 0.1), Color(0.12, 0.35, 0.18))
			_part(Vector3(1.2, 0.55, 0.05), Vector3(0, 1.25, -1.0), Color(0.15, 0.2, 0.25), 0.0)
			_part(Vector3(1.0, 0.7, 0.04), Vector3(0, 1.1, 1.16), Color(0.6, 0.6, 0.62))   # the steel grille cage at the back
			_wheel(0.28, Vector3(-0.6, 0.28, 0.75))
			_wheel(0.28, Vector3(0.6, 0.28, 0.75))
			_wheel(0.28, Vector3(0, 0.28, -1.1))
		"bus", "truck":
			_part(Vector3(s.x, s.y - 0.5, s.z), Vector3(0, s.y * 0.5 + 0.25, 0), col)
			_part(Vector3(s.x + 0.04, 0.9, s.z * 0.9), Vector3(0, s.y - 0.9, 0.2), Color(0.1, 0.12, 0.14), 0.1)
			for z in [-s.z * 0.33, s.z * 0.33]:
				_wheel(0.5, Vector3(-s.x * 0.48, 0.5, z))
				_wheel(0.5, Vector3(s.x * 0.48, 0.5, z))
		"car":
			_part(Vector3(s.x, 0.7, s.z), Vector3(0, 0.6, 0), col, 0.6)
			_part(Vector3(s.x * 0.9, 0.55, s.z * 0.55), Vector3(0, 1.15, 0.2), Color(0.12, 0.14, 0.18), 0.2)
			for z in [-1.35, 1.35]:
				_wheel(0.32, Vector3(-0.85, 0.32, z))
				_wheel(0.32, Vector3(0.85, 0.32, z))
		"motorbike":
			_part(Vector3(0.3, 0.4, 1.5), Vector3(0, 0.7, 0), col, 0.6)
			_part(Vector3(0.6, 0.06, 0.06), Vector3(0, 1.05, -0.7), Color(0.2, 0.2, 0.2))
			_wheel(0.32, Vector3(0, 0.32, -0.75))
			_wheel(0.32, Vector3(0, 0.32, 0.75))


# --- Lanes --------------------------------------------------------------------------------------

func _lane_points() -> Array:
	if lane < 0 or lane >= lanes.size():
		return []
	return (lanes[lane] as Dictionary).get("points", [])


func place_on_lane(t_frac: float) -> void:
	var pts := _lane_points()
	if pts.size() < 2:
		return
	lane_seg = 0
	var a := Vector3(float(pts[0][0]), 0.0, float(pts[0][1]))
	var b := Vector3(float(pts[1][0]), 0.0, float(pts[1][1]))
	global_position = a.lerp(b, t_frac)
	var d := (b - a).normalized()
	rotation.y = atan2(-d.x, -d.z)
	lane_t = t_frac
	speed = max_speed * 0.6


func _ai_drive(delta: float) -> void:
	var pts := _lane_points()
	if pts.size() < 2:
		return
	var i := mini(lane_seg, pts.size() - 2)
	var a := Vector3(float(pts[i][0]), 0.0, float(pts[i][1]))
	var b := Vector3(float(pts[i + 1][0]), 0.0, float(pts[i + 1][1]))
	var to := b - global_position
	to.y = 0
	if to.length() < 2.5:
		if lane_seg + 1 < pts.size() - 1:
			lane_seg += 1
		else:
			var nxt: Array = (lanes[lane] as Dictionary).get("next", [])
			if nxt.is_empty():
				queue_free()
				return
			lane = int(nxt[_rng.randi_range(0, nxt.size() - 1)])
			lane_seg = 0
		return
	var lane_speed := float((lanes[lane] as Dictionary).get("speed", 8.0))
	var want := minf(max_speed, lane_speed)
	# brake for anything ahead
	var fwd := -global_transform.basis.z
	var from := global_position + Vector3(0, 0.9, 0) + fwd * (_size.z * 0.5)
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * (4.0 + speed * 0.7), 2 | 4 | 8)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = 0.0
		_horn_t -= delta
		if _horn_t <= 0.0:
			_horn_t = _rng.randf_range(1.5, 4.0)
			AudioEventBus.emit_event("horn", global_position, 95.0)
	speed = move_toward(speed, want, delta * (6.0 if want < speed else 2.5))
	var dir := to.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 3.0, 0.0, 1.0))
	velocity = -global_transform.basis.z * speed
	velocity.y = 0.0
	move_and_slide()
	if a == b:
		return


# --- Player driving -------------------------------------------------------------------------------

func enter(by_player: Node) -> void:
	player_driven = true
	collision_mask = 1 | 2 | 4
	if has_driver and _driver != null:
		# the driver gets out, complains and runs off: taking a vehicle from its driver is a crime
		var p := PersonGenerator.make(_rng.randi(), "ped", "")
		var c := ActorFactory.spawn(p, get_parent(), global_position + global_transform.basis.x * 1.6, rotation.y)
		c.say({"bn": "আমার গাড়ি! চোর! চোর!", "en": "My vehicle! Thief! Thief!"}, 3.0, 1)
		c.ai.on_attacked(by_player)
		Services.report_crime("hijack", global_position, true)
		_driver.queue_free()
		_driver = null
		has_driver = false
	elif _driver != null:
		_driver.queue_free()
		_driver = null


func exit_vehicle() -> void:
	player_driven = false
	speed = 0.0
	velocity = Vector3.ZERO
	collision_mask = 1 | 4


func is_player_driven() -> bool:
	return player_driven


func drive_input(delta: float, throttle: float, steer: float, brake: bool) -> void:
	var accel := 7.0 if kind != "motorbike" else 9.0
	if brake:
		speed = move_toward(speed, 0.0, delta * 18.0)
	elif throttle > 0.0:
		speed = minf(max_speed * 1.25, speed + accel * throttle * delta)
	elif throttle < 0.0:
		speed = maxf(-4.0, speed + accel * 1.4 * throttle * delta)
	else:
		speed = move_toward(speed, 0.0, delta * 3.0)
	_steer = lerpf(_steer, steer, clampf(delta * 6.0, 0.0, 1.0))
	var turn := _steer * clampf(absf(speed) / 6.0, 0.0, 1.0) * (2.0 if kind == "motorbike" else 1.4)
	rotation.y += turn * delta * signf(speed if absf(speed) > 0.1 else 1.0)
	velocity = -global_transform.basis.z * speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()
	# knocking people over is a crime and hurts them
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is Citizen and absf(speed) > 4.0:
			(other as Citizen).take_damage(absf(speed) * 4.0, Services.player, "vehicle")
			speed *= 0.6
		elif other is StaticBody3D and absf(speed) > 6.0:
			speed *= 0.4
			AudioEventBus.emit_event("impact", global_position, 100.0)


func _physics_process(delta: float) -> void:
	if player_driven:
		return
	_ai_drive(delta)
	if _driver != null:
		_driver.animate(delta, 0.0, "drive")
