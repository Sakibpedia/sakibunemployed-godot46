class_name ActorHealth
extends Node
## Health for a Citizen. Anyone Sakib brings down does not die at once: they kneel, bleeding out,
## and ask their last questions (press E to listen). Answer them and they die in peace (and often
## tell you something useful). Ignore them, fail them or finish them off, and they come back after
## dark as a ghost that hunts you with the same questions (a spirit record in GameState.spirits).
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal downed(actor: Node)
signal died(actor: Node, peaceful: bool)

const BLEED_SECONDS := 50.0

var actor: Node3D
var services: Node
var hp := 100.0
var max_hp := 100.0
var _dying := false
var _dead := false
var _bleed := 0.0
var _cry_t := 0.0
var _killer: Node = null
var _asked := false
var _rng := RandomNumberGenerator.new()


func setup(a: Node3D, svc: Node) -> void:
	actor = a
	services = svc
	var prof: Dictionary = a.get("profile")
	max_hp = float(prof.get("hp", 100.0))
	hp = max_hp
	_rng.seed = int(prof.get("seed", 1)) + 99


func is_dead() -> bool:
	return _dead


func is_dying() -> bool:
	return _dying


func heal(n: float) -> void:
	hp = minf(max_hp, hp + n)


func take_damage(amount: float, source: Node, kind: String) -> void:
	if _dead:
		return
	var by_player := source != null and source == Services.player
	if _dying:
		if by_player:
			finish_off(source)
		return
	hp -= amount
	var rig: HumanoidRig = actor.get("visuals").rig
	rig.gesture("hit")
	if by_player:
		var ai: ActorAI = actor.get("ai")
		ai.on_attacked(source)
		Services.report_crime("assault" if kind == "melee" else "shooting", actor.global_position, true)
	if hp <= 0.0:
		if by_player:
			_start_dying(source)
		else:
			_die(true)


func _start_dying(by: Node) -> void:
	_dying = true
	_killer = by
	_bleed = BLEED_SECONDS
	_cry_t = 2.0
	actor.call("say", TauntBank.pick("dying", _rng), 5.0, 1)
	(actor.get("visuals") as ActorVisuals).set_marker("quiz")
	downed.emit(actor)
	Services.person_downed.emit(actor)
	Services.say_toast({"bn": "%s মরতে বসেছে। E চেপে তার শেষ প্রশ্ন শোনো, নইলে রাতে ফিরে আসবে।" % Game.text(actor.call("display_name")),
		"en": "%s is dying. Press E to hear the last questions, or they will come back after dark." % Game.text(actor.call("display_name"))}, "warn")


func _process(delta: float) -> void:
	if not _dying:
		return
	_bleed -= delta
	_cry_t -= delta
	if _cry_t <= 0.0:
		_cry_t = _rng.randf_range(8.0, 12.0)
		actor.call("say", TauntBank.pick("dying", _rng), 4.0, 0)
	if _bleed <= 0.0 and not _asked:
		_die_unanswered([])


func ask_dying_questions(_player: Node) -> void:
	if _asked or not _dying:
		return
	_asked = true
	var prof: Dictionary = actor.get("profile")
	Exams.start({"mode": "dying", "speaker": prof.get("name", {}), "face": String(prof.get("face", "")),
		"voice": prof.get("voice", {}), "family": String(prof.get("family", "bcs")), "count": 3, "pass": 2,
		"seconds": 18.0, "allow_flee": false, "taunts": "dying", "open_line": TauntBank.pick("dying", _rng),
		"stakes": {"bn": "দুটো ঠিক হলে শান্তিতে মরবে। না হলে রাতে ভূত হয়ে ফিরবে।",
			"en": "Two right and they die in peace. Otherwise they return at night as a ghost."}}, _on_dying_result)


func _on_dying_result(r: Dictionary) -> void:
	if bool(r.get("passed", false)):
		GameState.change_honesty(2)
		GameState.bump("peaceful_deaths")
		var gift := _rng.randi_range(50, 300)
		GameState.add_money(gift)
		Services.say_toast({"bn": "শান্তিতে বিদায় নিল। পকেটে ছিল ৳%s।" % UiKit.bengali_digits(str(gift)),
			"en": "They passed in peace. Their pocket held Tk %d." % gift}, "good")
		_die(true)
	else:
		_die_unanswered(r.get("items", []))


func finish_off(_by: Node) -> void:
	if _dead:
		return
	_die_unanswered([])


func _die_unanswered(items: Array) -> void:
	var prof: Dictionary = actor.get("profile")
	var qs: Array = items.duplicate()
	if qs.is_empty():
		for it in Exams.session.draw({"family": String(prof.get("family", "bcs"))}, 3):
			qs.append(String((it as Dictionary).get("id", "")))
	var city: CityData = Services.city
	var district := city.district_id_at(actor.global_position) if city != null else "jatrabari"
	GameState.add_spirit({
		"id": "spirit_%s_%d" % [String(prof.get("id", "x")), GameState.day], "name": prof.get("name", {}),
		"face": String(prof.get("face", "")), "look": _plain_look(prof.get("look", {})), "voice": prof.get("voice", {}),
		"questions": qs, "died_at": {"x": actor.global_position.x, "z": actor.global_position.z, "day": GameState.day},
		"district": district, "strength": 1, "banished": false,
	})
	GameState.change_honesty(-3)
	GameState.log_event("killing", district)
	Services.say_toast({"bn": "প্রশ্নের উত্তর না পেয়ে মারা গেল। আজ রাতে সে তোমাকে খুঁজবে।",
		"en": "They died unanswered. Tonight they will come looking for you."}, "warn")
	_die(false)


## Colours as arrays so the record survives JSON saving.
func _plain_look(l: Dictionary) -> Dictionary:
	var out := {}
	for k in l:
		var v: Variant = l[k]
		if typeof(v) == TYPE_COLOR:
			var c: Color = v
			out[k] = [c.r, c.g, c.b]
		else:
			out[k] = v
	return out


func _die(peaceful: bool) -> void:
	if _dead:
		return
	_dead = true
	_dying = false
	(actor.get("visuals") as ActorVisuals).set_marker("")
	actor.set("collision_layer", 0)
	if _killer == Services.player and _killer != null:
		GameState.bump("kills")
		Services.report_crime("murder", actor.global_position, true)
	died.emit(actor, peaceful)
	Services.person_died.emit(actor, peaceful)
