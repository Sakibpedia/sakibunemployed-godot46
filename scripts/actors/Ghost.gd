class_name Ghost
extends CharacterBody3D
## A bhoot: the spirit of someone Sakib killed without answering their dying questions.
## Rules (the night rule, docs/DESIGN.md):
##   * ghosts exist only between sunset and sunrise; at dawn they burn away (and return next night
##     until they are freed);
##   * they cannot enter homes, the mosque, shops or the college (safe zones), nor the light of a
##     working street lamp; they hover at the edge of the light and taunt;
##   * touching Sakib drains his health; the torch makes them flicker and back off (uses batteries);
##   * standing your ground and pressing E lets the ghost ask its question: answer it right and it is
##     freed for good (mukti); answer wrong and it grows stronger.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal freed(spirit_id: String)

var spirit: Dictionary = {}
var services: Node
var rig: HumanoidRig
var mat: ShaderMaterial
var strength := 1.0
var _rng := RandomNumberGenerator.new()
var _taunt_t := 4.0
var _hurt := 0.0
var _burn := 0.0
var _burning := false
var _asking := false
var _label: Label3D
var _bob := 0.0


func setup(s: Dictionary, svc: Node) -> void:
	spirit = s
	services = svc
	strength = float(s.get("strength", 1))
	_rng.seed = hash(String(s.get("id", "g")))
	collision_layer = 16
	collision_mask = 0
	add_to_group(&"ghosts")
	add_to_group(&"interactable")
	rig = HumanoidRig.new()
	add_child(rig)
	var look: Dictionary = {}
	var raw: Dictionary = s.get("look", {})
	for k in raw:
		var v: Variant = raw[k]
		if typeof(v) == TYPE_ARRAY and (v as Array).size() == 3:
			var a: Array = v
			look[k] = Color(float(a[0]), float(a[1]), float(a[2]))
		else:
			look[k] = v
	if look.is_empty():
		look = {"gender": "m", "outfit": "panjabi", "height": 1.7}
	rig.build(look)
	mat = rig.set_ghost(true, 0.0)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = UiKit.font(true)
	_label.font_size = 42
	_label.pixel_size = 0.004
	_label.outline_size = 12
	_label.modulate = Color(0.75, 0.92, 1.0)
	_label.outline_modulate = Color(0, 0, 0, 0.9)
	_label.width = 900.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.position = Vector3(0, 2.35, 0)
	add_child(_label)
	_label.text = Game.text(s.get("name", {}))


func interact_options(_player: Node) -> Array:
	if _asking or _burning:
		return []
	return [{"id": "answer", "label": {"bn": "ভূতের প্রশ্নের উত্তর দাও", "en": "Answer the ghost's question"}}]


func interact(_player: Node, _option_id: String) -> void:
	_ask()


func _ask() -> void:
	_asking = true
	var qs: Array = spirit.get("questions", [])
	var item_filter := {"family": "bcs"}
	var ctx := {"mode": "ghost", "speaker": spirit.get("name", {}), "face": String(spirit.get("face", "")), "count": 1, "pass": 1,
		"seconds": maxf(7.0, 12.0 - strength), "allow_flee": true, "taunts": "ghost", "voice": {"pitch": 0.6, "rate": 0.8},
		"open_line": TauntBank.pick("ghost", _rng),
		"stakes": {"bn": "ঠিক উত্তরে মুক্তি। ভুল হলে সে আরও শক্তিশালী।", "en": "Answer right to free it. Wrong, and it grows stronger."}}
	# the ghost asks one of its own unanswered dying questions when it can
	if not qs.is_empty():
		var id := String(qs[_rng.randi_range(0, qs.size() - 1)])
		var it := Exams.bank.item(id)
		if not it.is_empty():
			item_filter = {"category": String(it.get("category", ""))}
	ctx.merge(item_filter)
	var boss: Dictionary = spirit.get("exam", {})
	if not boss.is_empty():
		ctx["count"] = int(boss.get("count", 5))
		ctx["pass"] = int(boss.get("pass", 4))
		ctx.erase("category")
		ctx["family"] = ""
	Exams.start(ctx, _on_answer)


func _on_answer(r: Dictionary) -> void:
	_asking = false
	if bool(r.get("passed", false)):
		GameState.banish_spirit(String(spirit.get("id", "")))
		GameState.change_honesty(3)
		GameState.add_item("study_tokens", 1)
		var city: CityData = Services.city
		GameState.log_event("banished", city.district_id_at(global_position) if city != null else "jurain")
		Services.ghost_banished.emit(String(spirit.get("id", "")))
		Services.say_toast({"bn": "মুক্তি! %s আর ফিরবে না।" % Game.text(spirit.get("name", {})), "en": "Freed! %s will not return." % Game.text(spirit.get("name", {}))}, "good")
		freed.emit(String(spirit.get("id", "")))
		burn()
	else:
		strength += 1.0
		spirit["strength"] = int(strength)
		if Services.player != null and Services.player.has_method(&"take_damage"):
			Services.player.call("take_damage", 10.0 + strength * 3.0, self, "ghost")
		_say(TauntBank.pick("ghost", _rng))


func hurt_by_light(amount: float) -> void:
	_hurt = minf(1.0, _hurt + amount)


func burn() -> void:
	_burning = true


func _say(line: Dictionary) -> void:
	_label.text = Game.text(line)
	Voice.speak({"id": "ghost", "voice_id": "ghost", "name": spirit.get("name", {}), "voice": {"pitch": 0.62, "rate": 0.82, "index": 1}}, line, 1, global_position)
	AudioEventBus.emit_event("ghost", global_position, 70.0)


func _physics_process(delta: float) -> void:
	_bob += delta
	if _burning:
		_burn += delta * 0.6
		if mat:
			mat.set_shader_parameter("burn", clampf(_burn, 0.0, 1.0))
		if _burn >= 1.0:
			queue_free()
		return
	if _asking:
		return
	_hurt = maxf(0.0, _hurt - delta * 0.6)
	if mat:
		mat.set_shader_parameter("hurt", _hurt)
		mat.set_shader_parameter("base_height", global_position.y)
	var p: Node3D = Services.player
	if p == null or not is_instance_valid(p):
		return
	var director: Node = Services.ghosts
	var exposed := true
	if director != null and director.has_method(&"player_exposed"):
		exposed = bool(director.call("player_exposed"))
	var to := p.global_position - global_position
	to.y = 0
	var dist := to.length()
	var speed := (1.9 + strength * 0.35) * (1.0 - _hurt * 0.85)
	var want := Vector3.ZERO
	if _hurt > 0.5:
		want = -to.normalized() * 3.0            # the torch drives it back
	elif exposed:
		want = to.normalized() * speed
	elif dist < 9.0:
		want = -to.normalized() * 1.2            # wait at the edge of the light
	else:
		want = to.normalized() * speed * 0.3 if dist > 12.0 else Vector3.ZERO
	velocity = velocity.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	var hover := 0.25 + 0.12 * sin(_bob * 2.0)
	global_position += velocity * delta
	global_position.y = lerpf(global_position.y, hover, delta * 3.0)
	if to.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), delta * 4.0)
	rig.animate(delta, 0.0, "float")
	if exposed and dist < 1.5 and p.has_method(&"take_damage"):
		p.call("take_damage", (5.0 + strength * 1.5) * delta, self, "ghost")
	_taunt_t -= delta
	if _taunt_t <= 0.0 and dist < 25.0:
		_taunt_t = _rng.randf_range(7.0, 13.0)
		_say(TauntBank.pick("ghost", _rng))
