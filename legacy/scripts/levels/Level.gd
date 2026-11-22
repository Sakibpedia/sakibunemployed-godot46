class_name Level
extends Node3D
## One playable level, built from Data/Levels/Lxx.json: the map, Sakib, everyone else, objectives,
## exam gates, career talks and callbacks, last wishes, rides, lifts, time of day and endings.

const ACTOR_ROLES := ["civilian", "gatekeeper", "career", "callback", "driver", "captive", "courier",
	"ally", "goon", "gunman", "sniper", "lieutenant", "boss"]
const ITEM_KINDS := ["pickup", "utility", "task", "plank", "bypass", "ride", "roof_door"]
const GATE_UI := preload("res://scripts/ui/ExamGateUI.gd")

var def: Dictionary = {}
var builder: LevelBuilder
var player: Player
var hud: HUD
var dialogue: DialogueBox
var notebook: Notebook
var crowd: Crowd
var sector := "street"
var radio_jammed := false
var objectives: Array = []
var obj_index := 0

var _done: Dictionary = {}          # "kind:key" -> count
var _actors: Array[Actor] = []
var _items: Dictionary = {}         # key -> Array of Interactable
var _modal := 0
var _paused := false
var _finished := false
var _started := false
var _failed := false
var _gate_ui: Control = null
var _after_gate: Callable = Callable()
var atmosphere: DhakaAtmosphere
var _tick := 0.0
var _elapsed := 0.0
var _target = null
var _survive_left := -1.0
var _survive_t := 0.0
var _waves: Array = []
var _level_kills := 0
var _level_ko := 0
var _level_gates := 0
var _rng := RandomNumberGenerator.new()
var _fx_meshes: Dictionary = {}


func _ready() -> void:
	def = Game.level_def
	if def.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://Data/Levels/L01.json"))
		if typeof(data) == TYPE_DICTIONARY:
			def = data
			Game.level_def = data
	var n := int(def.get("level", 1))
	_rng.seed = n * 7919 + WorldState.save_seed
	sector = String(def.get("sector", "level_%d" % n))
	WorldState.current_sector = sector
	WorldState.utilities.erase(sector)
	WorldState.sectors.erase(sector)
	WorldState.clock_rate = 1.0
	WorldState.set_level(n, float(def.get("start_hour", 9.0)), def.get("prayers", {}))
	WorldState.set_lens(WorldState.Lens.GROUND_STEALTH)
	ExamGate.reset_level_state()
	ExamGate.register_gates(def.get("gates", {}))
	LastWishDirector.configure_level(float(def.get("lw_share", 0.35)), int(def.get("last_wish_cap", 2)))
	builder = LevelBuilder.new()
	builder.build(def, self)
	_environment()
	for c in get_children():
		if c is Interactable:
			_register_item(c)
	for it in builder.lifts:
		it.used.connect(_on_lift)
	_spawn_player()
	_spawn_from_markers()
	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	dialogue = DialogueBox.new()
	hud.add_child(dialogue)
	dialogue.opened.connect(_modal_push)
	dialogue.closed.connect(_modal_pop)
	notebook = Notebook.new()
	add_child(notebook)
	notebook.setup(self)
	if int(def.get("crowd", 0)) > 0:
		crowd = Crowd.new()
		add_child(crowd)
		crowd.setup(builder, int(def.get("crowd", 0)), int(def.get("level", 1)))
	_connect_world()
	for o in def.get("objectives", []):
		if _flag_ok(o):
			objectives.append(o)
	hud.set_title("Level %d · %s" % [n, String(def.get("title", ""))])
	_update_sun()
	_update_lights()
	_intro()


func _exit_tree() -> void:
	get_tree().paused = false
	WorldState.clock_rate = 1.0
	ExamGate.cancel_all()
	ExamGate.register_gates({})


func _connect_world() -> void:
	WorldState.minute_changed.connect(_on_minute)
	WorldState.prayer.connect(_on_prayer)
	WorldState.roof_warning.connect(_on_roof_warning)
	WorldState.roof_locked.connect(_on_roof_locked)
	WorldState.scanner_ping.connect(_on_scanner_ping)
	AudioEventBus.sound_event.connect(_on_sound)
	ExamGate.effect_requested.connect(_on_effect)
	LastWishDirector.last_wish_started.connect(_on_lw_started)
	LastWishDirector.last_wish_ended.connect(_on_lw_ended)


# --- Start, finish, fail --------------------------------------------------------

func _intro() -> void:
	_modal_push()
	Game.fade_to(0.0, 0.6)
	var body := "%s\n\n%s\n\nThe day starts at %s." % [String(def.get("chapter", "")), String(def.get("brief", "")), _clock_text()]
	if bool(def.get("roof_rule", false)):
		body += " The roof doors lock at 6 PM."
	if def.has("deadline_hour"):
		body += " Deadline: %s." % _hour_text(float(def.deadline_hour))
	hud.show_panel(String(def.get("title", "")), body, [["Start", _start]])


func _start() -> void:
	hud.hide_panel()
	_modal_pop()
	_started = true
	for e in def.get("on_start", []):
		_apply(String(e), null)
	if not objectives.is_empty():
		_start_objective(objectives[0])
	var intro: Array = def.get("intro", [])
	if not intro.is_empty():
		_say("Sakib", intro)
	_check_objectives()


func _complete() -> void:
	if _finished or _failed:
		return
	_finished = true
	_modal_push()
	AudioEventBus.play_ui("objective")
	var body := "Time %d:%02d · enemies down %d (knocked out %d) · gates passed %d\nHonesty %d · moral %d · ৳%d" % [
		int(_elapsed / 60.0), int(_elapsed) % 60, _level_kills + _level_ko, _level_ko, _level_gates,
		int(WorldState.reputation.get("exam_honesty", 0)), int(WorldState.reputation.get("moral", 0)),
		int(WorldState.resources.get("taka", 0))]
	var outro := String(def.get("outro", ""))
	if outro != "":
		body = outro + "\n\n" + body
	hud.show_panel("Level %d complete" % int(def.get("level", 1)), body, [["Continue", _continue_campaign], ["Main menu", Game.to_menu]])


func _continue_campaign() -> void:
	hud.hide_panel()
	Game.complete_level()


func _fail(title: String, body: String) -> void:
	if _finished or _failed:
		return
	_failed = true
	if _gate_ui != null and is_instance_valid(_gate_ui):
		_gate_ui.queue_free()
		_gate_ui = null
	ExamGate.cancel_all()
	if notebook:
		notebook.force_close()
	_modal_push()
	AudioEventBus.play_ui("fail")
	hud.show_panel(title, body, [["Try again", Game.retry_level], ["Main menu", Game.to_menu]])


func _on_player_died() -> void:
	if _finished or _failed:
		return
	var tw := create_tween()
	tw.tween_property(player.head, "position:y", 0.3, 1.1).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(player.cam, "rotation:z", 1.25, 1.1)
	tw.parallel().tween_property(player.gun, "position:y", -0.8, 0.6)
	await get_tree().create_timer(1.8).timeout
	_fail("Sakib is down", "Jatrabari goes on without him. Try again: crouch more, take the quiet route, or answer the gate instead of the gunmen.")


# --- Pause ----------------------------------------------------------------------

func toggle_pause() -> void:
	if _finished or _failed:
		return
	if _paused:
		_paused = false
		get_tree().paused = false
		hud.hide_panel()
		_modal_pop()
	elif not hud.panel_open():
		_paused = true
		_modal_push()
		get_tree().paused = true
		hud.show_panel("Paused", _objective_line() + "\n\nF1 shows the controls.", [["Resume", toggle_pause], ["Graphics: %s (change)" % RenderQuality.NAMES[RenderQuality.saved()], _cycle_quality], ["Restart this level", _restart], ["Main menu", Game.to_menu]])


func _cycle_quality() -> void:
	var tier := RenderQuality.cycle(get_viewport(), atmosphere.environment, atmosphere.sun, atmosphere.dust)
	toast("Graphics: " + RenderQuality.NAMES[tier])
	toggle_pause()
	toggle_pause()


func _restart() -> void:
	get_tree().paused = false
	Game.load_level(Game.current, true)


func _modal_push() -> void:
	_modal += 1
	_apply_modal()


func _modal_pop() -> void:
	_modal = maxi(0, _modal - 1)
	_apply_modal()


func _apply_modal() -> void:
	if player:
		player.input_locked = _modal > 0
	if player and player.dead:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _modal > 0 else Input.MOUSE_MODE_CAPTURED


func is_busy() -> bool:
	return _modal > 0


## True while an exam gate card or a conversation is on screen.
func in_conversation() -> bool:
	return _gate_ui != null or (dialogue != null and dialogue.is_open())


# --- Spawning -------------------------------------------------------------------

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Sakib"
	player.level = self
	player.position = _marker("@") + Vector3(0, 0.1, 0)
	player.rotation.y = deg_to_rad(float(def.get("player_yaw", 0.0)))
	add_child(player)
	player.died.connect(_on_player_died)


func _spawn_from_markers() -> void:
	var tags: Dictionary = def.get("marker_tags", {})
	var roles := {"X": "gunman", "Y": "goon", "Z": "sniper", "C": "civilian"}
	for ch in roles:
		for p in builder.markers.get(ch, []):
			var info := {"tag": String(tags.get(ch, ""))}
			if ch == "Z" and bool(def.get("snipers_after_6", false)):
				info["after_6"] = true
			spawn_actor(roles[ch], info, p)
	var legend: Dictionary = def.get("legend", {})
	for ch in legend:
		var info: Dictionary = legend[ch]
		if not _flag_ok(info):
			continue
		var kind := String(info.get("type", ""))
		for p in builder.markers.get(ch, []):
			if kind in ACTOR_ROLES:
				spawn_actor(kind, info.duplicate(true), p)
			elif kind in ITEM_KINDS:
				_spawn_item(kind, info, p)


func spawn_actor(role: String, info: Dictionary, p: Vector3) -> Actor:
	var a := Actor.new()
	a.configure(role, info)
	a.name = "%s_%d" % [role, _actors.size()]
	a.level = self
	a.position = p + Vector3(0, 0.05, 0)
	a.rotation.y = deg_to_rad(float(info.get("yaw", _rng.randf_range(-180.0, 180.0))))
	add_child(a)
	if role in ["goon", "gunman", "lieutenant"] and not bool(info.get("static", false)):
		a.patrol = _patrol_for(p)
	if bool(info.get("sit", false)):
		a.body.pose = "sit"
	if bool(info.get("cower", false)):
		a.body.pose = "cower"
	a.died.connect(_on_actor_died)
	_actors.append(a)
	return a


func _patrol_for(home: Vector3) -> Array:
	var pts: Array = []
	for p in builder.markers.get("P", []):
		if absf(p.y - home.y) < 1.0 and p.distance_to(home) < 30.0:
			pts.append(p)
	pts.sort_custom(func(a, b): return a.distance_to(home) < b.distance_to(home))
	if pts.size() > 3:
		pts.resize(3)
	if pts.is_empty():
		return []
	pts.insert(0, home)
	return pts


func _spawn_item(kind: String, info: Dictionary, p: Vector3) -> void:
	var it := Interactable.new()
	it.setup(kind, info)
	it.position = p
	add_child(it)
	_register_item(it)


func _register_item(it: Interactable) -> void:
	if it.key == "":
		return
	if not _items.has(it.key):
		_items[it.key] = []
	_items[it.key].append(it)
	if it.kind in ["pickup", "utility", "task", "plank", "bypass", "ride"]:
		it.used.connect(_on_used)


func _marker(ch: String) -> Vector3:
	var arr: Array = builder.markers.get(ch, [])
	if arr.is_empty():
		return Vector3(builder.w, 0.0, builder.h)
	return arr[0]


func _flag_ok(d: Dictionary) -> bool:
	if d.has("if_flag") and not bool(Game.flags.get(String(d.if_flag), false)):
		return false
	if d.has("unless_flag") and bool(Game.flags.get(String(d.unless_flag), false)):
		return false
	return true


# --- Objectives -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _finished or _failed or not _started:
		return
	_elapsed += delta
	if _survive_left > 0.0 and _modal == 0:
		_survive_left -= delta
		_survive_t += delta
		_spawn_waves()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	_update_lookouts()
	_target = _compute_target()
	_check_objectives()
	hud.set_objective(_objective_line())


func objective_target():
	return _target


func _event(key: String, n := 1) -> void:
	_done[key] = int(_done.get(key, 0)) + n
	_check_objectives()


func _count(key: String) -> int:
	return int(_done.get(key, 0))


func _check_objectives() -> void:
	if _finished or _failed or objectives.is_empty():
		return
	while obj_index < objectives.size() and _objective_met(objectives[obj_index]):
		var o: Dictionary = objectives[obj_index]
		toast("✓ " + String(o.get("text", "")), Color(0.6, 1.0, 0.6))
		for e in o.get("on_done", []):
			_apply(String(e), null)
		obj_index += 1
		if obj_index < objectives.size():
			AudioEventBus.play_ui("objective")
			_start_objective(objectives[obj_index])
	if obj_index >= objectives.size():
		_complete()


func _start_objective(o: Dictionary) -> void:
	if String(o.get("type", "")) == "survive":
		_survive_left = float(o.get("seconds", 60.0))
		_survive_t = 0.0
		_waves = o.get("waves", []).duplicate(true)
	for e in o.get("on_start", []):
		_apply(String(e), null)
	hud.set_objective(_objective_line())


func _objective_met(o: Dictionary) -> bool:
	var key := String(o.get("key", ""))
	match String(o.get("type", "")):
		"reach":
			return _near_marker(String(o.get("marker", "E")), float(o.get("radius", 2.6)))
		"pickup", "utility", "task", "plank", "bypass", "ride", "search", "free":
			return _count("%s:%s" % [o.type, key]) >= int(o.get("count", 1))
		"gate":
			return _count("gate:" + String(o.get("gate", ""))) > 0
		"talk":
			return _count("talk:" + String(o.get("person", ""))) > 0
		"interrogate":
			return _count("interrogate:" + String(o.get("tag", ""))) >= int(o.get("count", 1))
		"eliminate":
			var c := _tagged(String(o.get("tag", "")))
			return c.x > 0 and c.y >= mini(int(o.get("count", c.x)), c.x)
		"survive":
			return _survive_t > 0.0 and _survive_left <= 0.0
		"wait":
			return WorldState.game_seconds >= float(o.get("hour", 0.0)) * 3600.0
	return false


## x = how many actors carry the tag (or all syndicate if the tag is empty), y = how many are down.
func _tagged(tag: String) -> Vector2i:
	var total := 0
	var down := 0
	for a in _actors:
		if tag == "" and a.faction != "syndicate":
			continue
		if tag != "" and a.tag != tag:
			continue
		total += 1
		if a.state in ["dead", "ko", "dying"]:
			down += 1
	return Vector2i(total, down)


func _objective_line() -> String:
	if obj_index >= objectives.size():
		return ""
	var o: Dictionary = objectives[obj_index]
	var text := String(o.get("text", ""))
	match String(o.get("type", "")):
		"eliminate":
			var c := _tagged(String(o.get("tag", "")))
			text += "  (%d/%d)" % [c.y, mini(int(o.get("count", c.x)), c.x)]
		"survive":
			text += "  (%d s)" % maxi(0, ceili(_survive_left))
		"pickup", "task", "search", "interrogate", "utility", "free":
			var need := int(o.get("count", 1))
			if need > 1:
				var k := "interrogate:" + String(o.get("tag", "")) if o.type == "interrogate" else "%s:%s" % [o.type, String(o.get("key", ""))]
				text += "  (%d/%d)" % [mini(_count(k), need), need]
	return "▸ " + text


func _near_marker(ch: String, radius: float) -> bool:
	for p in builder.markers.get(ch, []):
		if player.global_position.distance_to(p) < radius:
			return true
	return false


func _compute_target():
	if obj_index >= objectives.size():
		return null
	var o: Dictionary = objectives[obj_index]
	var key := String(o.get("key", ""))
	match String(o.get("type", "")):
		"reach":
			return _nearest(builder.markers.get(String(o.get("marker", "E")), []))
		"pickup", "utility", "task", "plank", "bypass", "ride":
			var pts: Array = []
			for it in _items.get(key, []):
				if it.enabled:
					pts.append(it.global_position)
			if pts.is_empty():
				for a in _actors:
					if a.role == "driver" and _key_of(a) == key:
						pts.append(a.global_position)
			return _nearest(pts)
		"gate":
			return _actor_pos(func(a: Actor) -> bool: return a.gate_id == String(o.get("gate", "")))
		"talk":
			return _actor_pos(func(a: Actor) -> bool: return a.person == String(o.get("person", "")))
		"search":
			return _actor_pos(func(a: Actor) -> bool: return a.role == "courier" and String(a.info.get("key", "")) == key)
		"free":
			return _actor_pos(func(a: Actor) -> bool: return a.role == "captive" and _key_of(a) == key and a.visible)
		"interrogate":
			return _actor_pos(func(a: Actor) -> bool: return a.tag == String(o.get("tag", "")) and bool(a.info.get("interrogate", false)))
		"eliminate":
			var tag := String(o.get("tag", ""))
			return _actor_pos(func(a: Actor) -> bool:
				return (a.tag == tag if tag != "" else a.faction == "syndicate") and not (a.state in ["dead", "ko", "dying"]) and (a.revealed > 0.0 or tag != "")
			)
	return null


func _actor_pos(pred: Callable):
	var pts: Array = []
	for a in _actors:
		if a.visible and a.state != "dead" and pred.call(a):
			pts.append(a.global_position)
	return _nearest(pts)


func _nearest(pts: Array):
	var best = null
	var bd := INF
	for p in pts:
		var d: float = player.global_position.distance_to(p)
		if d < bd:
			bd = d
			best = p
	return best


func _spawn_waves() -> void:
	for w in _waves:
		if bool(w.get("spawned", false)) or _survive_t < float(w.get("at", 0.0)):
			continue
		w["spawned"] = true
		var pts: Array = builder.markers.get(String(w.get("marker", "Y")), [])
		if pts.is_empty():
			continue
		for i in int(w.get("count", 2)):
			var p: Vector3 = pts[i % pts.size()] + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0))
			var a := spawn_actor(String(w.get("role", "goon")), {"tag": String(w.get("tag", "wave"))}, p)
			a.last_known = player.global_position
			a.enter_combat()
		toast(String(w.get("text", "More of them are coming.")), Color(1.0, 0.6, 0.4))


# --- Effects ----------------------------------------------------------------------

func _on_effect(effect: String) -> void:
	_apply(effect, null)


func _apply(effect: String, src: Node) -> void:
	var parts := effect.split(":")
	var arg := parts[1] if parts.size() > 1 else ""
	match parts[0]:
		"reveal":
			_reveal(float(arg) if arg != "" else 45.0)
		"resource":
			if parts.size() >= 3:
				WorldState.add_resource(arg, int(parts[2]))
				toast("%+d %s" % [int(parts[2]), arg.replace("_", " ")])
		"tokens":
			WorldState.add_resource("study_tokens", int(arg))
			toast("+%d study token" % int(arg))
		"honesty":
			WorldState.change_rep("exam_honesty", int(arg))
		"open", "unlock":
			_open_group(String(def.get("aliases", {}).get(arg, arg)))
		"done":
			if parts.size() >= 3:
				_event("%s:%s" % [arg, parts[2]])
		"restore":
			WorldState.set_utility(sector, arg, true)
			_update_lights()
		"delay":
			WorldState.game_seconds += float(arg) * 60.0
			_update_sun()
			toast("You lose %d minutes." % int(arg), Color(1.0, 0.7, 0.4))
		"flag", "story":
			Game.flags[arg] = true
		"give":
			Game.flags["give_" + arg] = true
			toast("You now have: " + arg.replace("_", " "))
		"toast":
			toast(effect.substr(6))
		"waive_gates":
			_waive_gates(int(arg))
		"remove_sniper":
			for a in _actors:
				if a.role == "sniper" and not (a.state in ["dead", "ko"]):
					a.knockout()
					toast("A mirror flashes from the next roof. One sniper is blinded and out of the fight.")
					break
		"pass_plus":
			if parts.size() >= 3:
				Game.flags["pass_plus_" + arg] = int(Game.flags.get("pass_plus_" + arg, 0)) + int(parts[2])
		"utility":
			_cut_utility(arg)
		"jam":
			radio_jammed = true
		"heal":
			player.heal_full()
		"calm":
			for a in _syndicate():
				if a.state != "combat":
					a.suspicion = 0.0
		"skip_to":
			_skip_to(float(arg))
		"combat", "activate":
			for a in _actors:
				if a.tag == arg and not (a.state in ["dead", "ko", "dying"]):
					a.active = true
					if parts[0] == "combat":
						a.last_known = player.global_position
						a.enter_combat()
		"spawn":
			if parts.size() >= 4:
				var spawn_tag := parts[4] if parts.size() > 4 else "spawned"
				for p in builder.markers.get(parts[2], []).slice(0, int(parts[3])):
					var a := spawn_actor(arg, {"tag": spawn_tag}, p)
					a.last_known = player.global_position
					a.state = "investigate"
		"ally":
			if parts.size() >= 3:
				for p in builder.markers.get(arg, []).slice(0, int(parts[2])):
					spawn_actor("ally", {"name": "Neighbour", "lookout": true}, p)
		"bitter":
			_bitter(src)
		_:
			pass   # door:..., retry_after_game_min and other data-only notes


func _open_group(key: String) -> void:
	for it in _items.get(key, []):
		if it.kind == "gate" or it.kind == "roof_door":
			it.open_gate()


func _reveal(seconds: float) -> void:
	for a in _syndicate():
		a.revealed = maxf(a.revealed, seconds)


func _syndicate() -> Array:
	var out: Array = []
	for a in _actors:
		if a.faction == "syndicate" and not (a.state in ["dead", "ko", "dying"]):
			out.append(a)
	return out


func _update_lookouts() -> void:
	for ally in _actors:
		if ally.role != "ally" or not bool(ally.info.get("lookout", false)) or not ally.visible:
			continue
		for a in _syndicate():
			if a.global_position.distance_to(ally.global_position) < 22.0:
				a.revealed = maxf(a.revealed, 1.0)


func _cut_utility(u: String) -> void:
	if u == "radio":
		radio_jammed = true
		toast("Their radios hiss. Nobody can call for help now.")
	elif u == "cctv":
		WorldState.set_utility(sector, "cctv", false)
		toast("The cameras go dark.")
	else:
		WorldState.set_utility(sector, u, false)
		if WorldState.vision_multiplier(sector) < 1.0:
			toast("The lights die. In the dark they see half as far.")
		else:
			toast("The %s is off. Something else is still keeping the lights on." % u)
	_update_lights()


func _waive_gates(n: int) -> void:
	var left := n
	for i in range(obj_index, objectives.size()):
		if left <= 0:
			break
		var o: Dictionary = objectives[i]
		if String(o.get("type", "")) != "gate":
			continue
		var gid := String(o.get("gate", ""))
		_gate_passed(gid, _gate_def(gid), null, false, Callable(), true)
		left -= 1


func _bitter(src: Node) -> void:
	var at: Vector3 = src.global_position if src is Node3D else player.global_position
	var p := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, at + Vector3(6, 0, 6))
	var a := spawn_actor("goon", {"tag": "bitter"}, p)
	a.last_known = player.global_position
	a.state = "investigate"
	for s in _syndicate():
		if s.global_position.distance_to(player.global_position) < 30.0 and s.state != "combat":
			s.suspicion = maxf(s.suspicion, 60.0)
			s.last_known = player.global_position
			s.state = "investigate"
	WorldState.add_alert(sector, 25.0)


# --- Talking to people --------------------------------------------------------------

func actor_interact(a: Actor) -> void:
	if _modal > 0 or _finished or _failed:
		return
	match a.role:
		"gatekeeper", "boss":
			_talk_gate(a, Callable())
		"career":
			_career(a)
		"callback":
			_callback(a)
		"driver":
			_driver(a)
		"captive":
			_captive(a)
		"courier":
			_search(a)
		_:
			var lines: Array = a.info.get("lines", [])
			if not lines.is_empty():
				_say(a.display_name, lines)


func _say(speaker: String, lines: Array, choices: Array = [], cb: Callable = Callable()) -> void:
	dialogue.say(speaker, lines, choices, cb)


func _key_of(a: Actor) -> String:
	if a.info.has("key"):
		return String(a.info.key)
	return a.person if a.person != "" else a.display_name


func _name_of(n: Node) -> String:
	return n.display_name if n is Actor else "The gatekeeper"


func _gate_def(gid: String) -> Dictionary:
	var g := ExamGate.load_gate(gid)
	if g.is_empty():
		g = {"gate_id": gid, "gatekeeper": gid, "category": "door", "size": 5, "pass_points": 3.0, "draw": {"sets": ["G"]}}
	return g.duplicate(true)


func _bribe_cost(g: Dictionary) -> int:
	if bool(g.get("no_bribe", false)) or String(g.get("category", "")) in ["legal", "last_wish", "duel"]:
		return 0
	return int(g.get("bribe", 60 * int(g.get("size", 5))))


func _talk_gate(a: Actor, then: Callable) -> void:
	var gid := a.gate_id
	if gid == "":
		_say(a.display_name, a.info.get("lines", ["..."]))
		return
	if _count("gate:" + gid) > 0:
		if then.is_valid():
			then.call()
		else:
			_say(a.display_name, [String(a.info.get("after", "You've answered me already. Go on."))])
		return
	var g := _gate_def(gid)
	if not ExamGate.can_open(gid):
		_gate_blocked(a, g, then)
		return
	var intro := String(a.info.get("intro", g.get("intro", "Nobody passes without answering. %d questions, %s points to pass. Get one wrong and I'll ask you around it." % [int(g.get("size", 5)), str(g.get("pass_points", 3))])))
	var choices: Array = [["Take the questions", "ask"]]
	var cost := _bribe_cost(g)
	if cost > 0:
		choices.append(["Slip him ৳%d instead (honesty −10)" % cost, "bribe"])
	choices.append(["Not now", "leave"])
	a.body.talking = true
	_say(a.display_name, [intro], choices, func(v) -> void:
		a.body.talking = false
		if v == "ask":
			_open_gate(gid, a, then)
		elif v == "bribe":
			if _pay_bribe(cost):
				_gate_passed(gid, g, a, true, then)
			else:
				toast("You don't have ৳%d." % cost)
	)


func _open_gate(gid: String, keeper: Node, then: Callable, extra: Dictionary = {}) -> void:
	var g := _gate_def(gid)
	g.merge(extra, true)
	var base := float(g.get("pass_points", 3.0 if int(g.get("size", 5)) <= 5 else 7.0))
	g["pass_points"] = base + float(Game.flags.get("pass_plus_" + gid, 0))
	var s := ExamGate.open_gate(g)
	if s == null:
		toast("%s has run out of questions for you today and waves you through." % _name_of(keeper))
		_gate_passed(gid, g, keeper, false, then)
		return
	if keeper is Actor:
		keeper.body.talking = true
	s.resolved.connect(_on_gate_resolved.bind(gid, g, keeper, then))
	_show_gate(s, _bribe_cost(g))


func _show_gate(s: ExamSession, cost: int) -> void:
	var ui = GATE_UI.new()
	ui.bribe_cost = cost
	hud.add_child(ui)
	ui.open(s)
	_gate_ui = ui
	_modal_push()
	WorldState.clock_rate = 0.2   # a conversation takes minutes, not an hour
	ui.closed.connect(_on_gate_ui_closed)


func _on_gate_ui_closed() -> void:
	_gate_ui = null
	WorldState.clock_rate = 1.0
	_modal_pop()
	if _after_gate.is_valid():
		var c := _after_gate
		_after_gate = Callable()
		c.call()


func _on_gate_resolved(result: Dictionary, gid: String, g: Dictionary, keeper: Node, then: Callable) -> void:
	if keeper is Actor and is_instance_valid(keeper):
		keeper.body.talking = false
	if result.passed:
		_gate_passed(gid, g, keeper, bool(result.get("bribed", false)), then)
	else:
		_gate_failed(gid, g, result)


func _gate_passed(gid: String, g: Dictionary, keeper: Node, bribed: bool, then: Callable, waived := false) -> void:
	if _count("gate:" + gid) == 0:
		_level_gates += 1
	var opens = g.get("opens", [])
	if opens is String:
		opens = [opens]
	for k in opens:
		_open_group(String(k))
	for e in g.get("level_on_pass", []):
		_apply(String(e), keeper)
	if waived:
		toast("A friend vouches for you. The %s waves you through." % String(g.get("gatekeeper", "guard")))
	elif bribed:
		toast("The money disappears into a pocket. The way opens.", Color(1.0, 0.8, 0.5))
	_event("gate:" + gid)
	if then.is_valid():
		if _gate_ui != null:
			_after_gate = then
		else:
			then.call()


func _gate_failed(gid: String, g: Dictionary, result: Dictionary) -> void:
	for a in _syndicate():
		if a.global_position.distance_to(player.global_position) < 22.0:
			a.hear("shout", player.global_position, 62.0)
	if bool(g.get("story_gate", false)):
		_event("gate:" + gid)
		return
	var hint := "Come back in an hour of game time, pay, or find another way round"
	if result.get("locked", false):
		hint = "He won't ask you again today. Pay, find another way, or shove past"
	toast("Gate failed. %s." % hint, Color(1.0, 0.6, 0.5))


func _gate_blocked(a: Actor, g: Dictionary, then: Callable) -> void:
	var gid := String(g.get("gate_id", a.gate_id))
	var locked := ExamGate.is_locked(gid)
	var cost := _bribe_cost(g)
	var opts: Array = []
	var body := "%s turns away. " % a.display_name
	if locked:
		body += "He won't ask you again today."
	else:
		var mins := maxi(1, ceili((ExamGate.retry_at(gid) - WorldState.game_seconds) / 60.0))
		body += "He'll ask again in %d game minutes." % mins
		opts.append(["Wait it out (the clock moves on)", _wait_gate.bind(gid)])
	if cost > 0:
		opts.append(["Bribe him (৳%d, honesty −10)" % cost, _bribe_gate.bind(gid, g, a, then, cost)])
	if locked or cost == 0:
		opts.append(["Shove past him (everyone will hear)", _shove_gate.bind(gid, g, a, then)])
	opts.append(["Leave", _close_panel])
	_panel(a.display_name, body, opts)


func _wait_gate(gid: String) -> void:
	WorldState.game_seconds = maxf(WorldState.game_seconds, ExamGate.retry_at(gid) + 1.0)
	_update_sun()
	_close_panel()
	toast("You wait on the stairs. The clock moves on.")


func _bribe_gate(gid: String, g: Dictionary, a: Actor, then: Callable, cost: int) -> void:
	_close_panel()
	if _pay_bribe(cost):
		_gate_passed(gid, g, a, true, then)
	else:
		toast("You don't have ৳%d." % cost)


func _shove_gate(gid: String, g: Dictionary, a: Actor, then: Callable) -> void:
	_close_panel()
	_force_gate(gid, g, a, then)


func _force_gate(gid: String, g: Dictionary, keeper: Node, then: Callable) -> void:
	WorldState.change_rep("exam_honesty", -5)
	WorldState.change_rep("moral", -5)
	AudioEventBus.emit_event("shout", player.global_position, 82.0, sector)
	for a in _syndicate():
		if a.global_position.distance_to(player.global_position) < 40.0:
			a.last_known = player.global_position
			a.enter_combat()
	toast("You shove past. Every gun on the street turns your way.", Color(1.0, 0.5, 0.4))
	_gate_passed(gid, g, keeper, false, then)


func _pay_bribe(cost: int) -> bool:
	if not WorldState.spend("taka", cost):
		return false
	WorldState.change_rep("exam_honesty", -10)
	Game.stats["bribes"] += 1
	return true


func _panel(title: String, body: String, opts: Array) -> void:
	_modal_push()
	hud.show_panel(title, body, opts)


func _close_panel() -> void:
	hud.hide_panel()
	_modal_pop()


func _career(a: Actor) -> void:
	var person := a.person
	var sc: Dictionary = CareerAdvice.scenarios.get(person, {})
	if sc.is_empty():
		_say(a.display_name, a.info.get("lines", ["..."]))
		return
	if _count("talk:" + person) > 0:
		_say(person, ["I'm thinking about what you said, bhai."])
		return
	var lines: Array = a.info.get("lines", [])
	lines = lines.duplicate()
	lines.append("%s, %s, %s. %s." % [person, str(sc.get("age", "")), String(sc.get("role", "")), String(sc.get("situation", ""))])
	lines.append("You studied for every exam in this country. What should I do?")
	var choices: Array = []
	for k in ["A", "B", "C"]:
		var opt: Dictionary = sc.options[k]
		choices.append(["%s) %s" % [k, String(opt.get("label", ""))], k])
	a.body.talking = true
	_say(person, lines, choices, func(choice) -> void:
		a.body.talking = false
		var opt: Dictionary = CareerAdvice.give_advice(person, String(choice))
		_event("talk:" + person)
		var reply := "%s nods slowly." % person
		if bool(opt.get("corrupt", false)):
			reply += " It is the easy road, and you both know who owns it. (Honesty −10)"
		if int(WorldState.resources.get("study_tokens", 0)) > 0:
			_say(person, [reply, "Will you help me get started?"], [["Give an hour of your notes (1 study token)", "yes"], ["Not today", "no"]], func(v) -> void:
				if v == "yes" and WorldState.spend("study_tokens", 1):
					CareerAdvice.mark_follow_through(person)
					toast("You sit with %s over your old notes. It will matter later." % person)
			)
		else:
			_say(person, [reply])
	)


func _callback(a: Actor) -> void:
	var person := a.person
	if _count("talk:" + person) > 0:
		_say(person, ["Go, bhai. I've done what I can."])
		return
	var outcome := CareerAdvice.resolve_callback(person)
	var sc: Dictionary = CareerAdvice.scenarios.get(person, {})
	var line := LLMBridge.take_line("callback", "%s/%s" % [person, outcome])
	var tone_line := LLMBridge.fallback_line("callback_" + outcome)
	var action := String(sc.get("callback_" + outcome, ""))
	a.body.talking = true
	var tone_col: Color = {"grateful": Color(0.6, 1.0, 0.6), "mixed": Color(1.0, 0.9, 0.6), "bitter": Color(1.0, 0.5, 0.45)}[outcome]
	_say(person, [line, tone_line, "(%s: %s)" % [outcome.capitalize(), action]], [], func(_v) -> void:
		a.body.talking = false
		var effects: Array = a.info.get(outcome, {"grateful": ["reveal:45", "resource:medical:1"], "mixed": ["resource:ammo:6"], "bitter": ["bitter"]}[outcome])
		for e in effects:
			_apply(String(e), a)
		toast("%s is %s." % [person, outcome], tone_col)
		_event("talk:" + person)
	)


func _driver(a: Actor) -> void:
	var key := _key_of(a)
	var go := func() -> void: _ride(key, a.info)
	if a.gate_id != "" and _count("gate:" + a.gate_id) == 0:
		_talk_gate(a, go)
		return
	_say(a.display_name, [String(a.info.get("line", "Uthen, bhai. Where to?"))], [["Ride", "go"], ["Not now", "no"]], func(v) -> void:
		if v == "go":
			go.call()
	)


func _ride(key: String, info: Dictionary) -> void:
	var dest := _marker(String(info.get("to", "E")))
	_modal_push()
	AudioEventBus.play_ui("ride")
	await Game.fade_to(1.0, 0.5)
	WorldState.game_seconds += float(info.get("minutes", 15.0)) * 60.0
	player.global_position = dest + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	_update_sun()
	await get_tree().create_timer(0.4).timeout
	await Game.fade_to(0.0, 0.5)
	_modal_pop()
	toast(String(info.get("text", "You arrive.")))
	_event("ride:" + key)


func _captive(a: Actor) -> void:
	if bool(a.info.get("interrogate", false)):
		var gid := "%s_q_%s" % [sector, a.name]
		var extra := {"gate_id": gid, "gatekeeper": a.display_name, "category": "interrogation", "size": 3,
			"pass_points": 2.0, "draw": {"sets": a.info.get("sets", ["G", "SP"])}, "chain": {"max_depth": 1}, "no_bribe": true}
		_say(a.display_name, [String(a.info.get("intro", "Ask me, then. If you know your books, I'll tell you where the stock is."))], [["Question him", "go"], ["Later", "no"]], func(v) -> void:
			if v != "go":
				return
			var s := ExamGate.open_gate(extra)
			if s == null:
				_interrogated(a, {"passed": true})
				return
			s.resolved.connect(func(r: Dictionary) -> void: _interrogated(a, r))
			_show_gate(s, 0)
		)
		return
	var key := _key_of(a)
	_say(a.display_name, [String(a.info.get("line", "Thank you, bhai. I know the back way out."))], [], func(_v) -> void:
		_event("free:" + key)
		var tw := create_tween()
		tw.tween_property(a.body, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
		tw.tween_callback(func() -> void:
			a.visible = false
			a.collision_layer = 0
			a.process_mode = Node.PROCESS_MODE_DISABLED
		)
		a.remove_from_group("interactables")
	)


func _interrogated(a: Actor, r: Dictionary) -> void:
	a.info["interrogate"] = false
	a.remove_from_group("interactables")
	if r.get("passed", false):
		_reveal(60.0)
		Game.stats["intel"] += 1
		toast("He talks. Every guard on this floor is marked for a minute.", Color(0.6, 1.0, 0.6))
	else:
		toast("He laughs at you, but he lets slip a name.")
	_event("interrogate:" + a.tag)


func _search(a: Actor) -> void:
	var key := String(a.info.get("key", ""))
	if key == "":
		return
	a.info["key"] = ""
	a.panic(player.global_position)
	AudioEventBus.emit_event("scuffle", a.global_position, 58.0, sector)
	toast(String(a.info.get("found", "Under his shirt: a sealed envelope of question papers.")), Color(0.6, 1.0, 0.6))
	_event("search:" + key)


func begin_last_wish(a: Actor) -> void:
	if _modal > 0:
		return
	var s: ExamSession = LastWishDirector.begin(a)
	if s == null:
		return
	Game.stats["last_wishes"] += 1
	_show_gate(s, 0)


func _on_lw_started(agent: Node3D, cause: String) -> void:
	toast("%s is dying (%s). Kneel beside him and press E to hear his last wish." % [agent.display_name, cause], Color(1.0, 0.85, 0.5))


func _on_lw_ended(_agent: Node3D, result: Dictionary) -> void:
	if result.get("perfect", false):
		Game.stats["intel"] += 1
		_reveal(60.0)
		toast("His last words were patrol routes. Every enemy is marked for a minute.", Color(0.6, 1.0, 0.6))
	elif result.get("chain_exhausted", false) or result.get("timed_out", false) or result.get("abandoned", false):
		toast("He screams. Everyone nearby heard it.", Color(1.0, 0.5, 0.45))


# --- Things you use -------------------------------------------------------------------

func _on_used(it: Interactable, _by: Node) -> void:
	if _modal > 0:
		return
	var d := it.data
	match it.kind:
		"pickup":
			var give: Dictionary = d.get("give", {})
			for r in give:
				WorldState.add_resource(String(r), int(give[r]))
			toast(String(d.get("toast", "Picked up: " + it.label.trim_prefix("Take ").trim_prefix("Pick up "))), Color(0.9, 0.9, 0.6))
			AudioEventBus.play_ui("pickup")
			_event("pickup:" + it.key)
		"utility":
			AudioEventBus.emit_event("breaker", it.global_position, 55.0, sector)
			_cut_utility(String(d.get("utility", "lights")))
			_event("utility:" + it.key)
		"task":
			if d.has("noise"):
				AudioEventBus.emit_event("work", it.global_position, float(d.noise), sector)
			var give: Dictionary = d.get("give", {})
			for r in give:
				WorldState.add_resource(String(r), int(give[r]))
			if d.has("skip_to"):
				_skip_to(float(d.skip_to))
			for e in d.get("effects", []):
				_apply(String(e), null)
			if d.has("toast"):
				toast(String(d.toast))
			_event("task:" + it.key)
		"ride":
			_ride(it.key, d)
		"bypass":
			_bypass(it)
		"plank":
			_cross(it)


func _bypass(it: Interactable) -> void:
	var d := it.data
	_modal_push()
	await Game.fade_to(1.0, 0.35)
	if d.has("to"):
		player.global_position = _marker(String(d.to)) + Vector3(0, 0.1, 0)
		player.velocity = Vector3.ZERO
	await Game.fade_to(0.0, 0.35)
	_modal_pop()
	AudioEventBus.emit_event("scrape", player.global_position, float(d.get("noise", 62.0)), sector)
	toast(String(d.get("toast", "You get round the long way.")))
	if d.has("gate"):
		var gid := String(d.gate)
		_gate_passed(gid, _gate_def(gid), null, false, Callable())
	_event("bypass:" + it.key)


func _cross(it: Interactable) -> void:
	var dest := _marker(String(it.data.get("to", "E"))) + Vector3(0, 0.1, 0)
	_modal_push()
	player.freeze(true)
	var dist := player.global_position.distance_to(dest)
	var tw := create_tween()
	tw.tween_property(player, "global_position", dest, maxf(1.0, dist / 1.3)).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(player.cam, "rotation:z", 0.08, 0.5)
	tw.tween_property(player.cam, "rotation:z", 0.0, 0.3)
	await tw.finished
	player.freeze(false)
	_modal_pop()
	_event("plank:" + it.key)


func _on_lift(it: Interactable, _by: Node) -> void:
	if _modal > 0:
		return
	if not (WorldState.is_on(sector, "power") or WorldState.is_on(sector, "generator")):
		toast("You press the button. Nothing. No power, no lift.")
		return
	var opts: Array = []
	for other in builder.lifts:
		if other != it and other.key == it.key:
			var floor_n := int(other.data.get("floor", 0))
			opts.append(["Floor %d" % floor_n if floor_n > 0 else "Ground floor", _lift_choice.bind(other)])
	opts.append(["Stay here", _close_panel])
	_panel("Lift", "The cage rattles. Which floor?", opts)


func _lift_choice(other: Interactable) -> void:
	_close_panel()
	_take_lift(other)


func _take_lift(other: Interactable) -> void:
	_modal_push()
	AudioEventBus.emit_event("lift", player.global_position, 52.0, sector)
	await Game.fade_to(1.0, 0.4)
	player.global_position = other.global_position + Vector3(0, 0.1, 0.55)
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.5).timeout
	await Game.fade_to(0.0, 0.4)
	_modal_pop()


func _skip_to(hour: float) -> void:
	var day := floorf(WorldState.game_seconds / 86400.0)
	var t := day * 86400.0 + hour * 3600.0
	if t <= WorldState.game_seconds:
		t += 86400.0
	WorldState.game_seconds = t
	_update_sun()
	toast("Time passes. It is %s." % _clock_text())


# --- World events -----------------------------------------------------------------------

func _on_actor_died(a: Actor, cause: String) -> void:
	if a.faction == "syndicate":
		if cause == "ko":
			_level_ko += 1
		else:
			_level_kills += 1
			Game.stats["kills"] += 1
	elif cause != "ko":
		WorldState.change_rep("moral", -15)
		toast("%s is dead. That was not the plan." % a.display_name, Color(1.0, 0.5, 0.45))
	if a.gate_id != "" and _count("gate:" + a.gate_id) == 0:
		WorldState.change_rep("exam_honesty", -5)
		toast("With %s down, nobody is asking questions at that gate any more." % a.display_name)
		_gate_passed(a.gate_id, _gate_def(a.gate_id), a, false, Callable())
	_check_objectives()


func _on_minute(h: int, m: int) -> void:
	if m % 5 == 0:
		_update_sun()
	if def.has("deadline_hour") and not _finished:
		if float(h) + m / 60.0 >= float(def.deadline_hour) and WorldState.game_seconds >= float(def.get("start_hour", 0.0)) * 3600.0:
			_fail("Too late", String(def.get("deadline_text", "The clock beat you. Try a faster route, or skip what you can.")))


func _on_prayer(prayer_name: String) -> void:
	toast("Azan for %s from the mosque. The lanes go quiet for a few minutes." % prayer_name, Color(0.8, 0.9, 1.0))


func _on_roof_warning() -> void:
	if not bool(def.get("roof_rule", false)):
		return
	hud.roof_warning(true)
	toast("17:45. The roof doors lock at 6 PM. Get down, or find another way off.", Color(1.0, 0.7, 0.4))


func _on_roof_locked() -> void:
	var woke := false
	for a in _actors:
		if a.role == "sniper" and not a.active:
			a.active = true
			woke = true
	hud.roof_warning(false)
	if bool(def.get("roof_rule", false)):
		var on_roof := player.global_position.y >= builder.roof_floor * LevelBuilder.H - 0.6
		toast("6 PM. The roof doors are locked." + (" You are still up here." if on_roof else ""), Color(1.0, 0.6, 0.4))
	if woke:
		toast("Snipers take their places on the water tanks.", Color(1.0, 0.5, 0.45))


func _on_scanner_ping(sid: String) -> void:
	if sid != sector:
		return
	var best: Actor = null
	var bd := INF
	for a in _syndicate():
		var d: float = a.global_position.distance_to(player.global_position)
		if a.state != "combat" and d < bd:
			bd = d
			best = a
	if best:
		best.last_known = player.global_position
		best.suspicion = maxf(best.suspicion, 60.0)
		best.state = "investigate"
		toast("Their scanner picked up your calls. Someone is coming to look.", Color(1.0, 0.7, 0.4))


func _on_sound(_event_name: String, pos: Vector3, db: float) -> void:
	if db < AudioEventBus.PANIC_DB:
		return
	for a in _actors:
		if a.faction != "syndicate" and a.global_position.distance_to(pos) < 30.0:
			a.panic(pos)
	if crowd:
		crowd.panic(pos, clampf((db - 70.0) * 0.6, 8.0, 40.0))


func on_player_hurt(_amount: float, _from: Vector3) -> void:
	hud.flash_damage()
	if notebook:
		notebook.force_close()


func hazard_at(pos: Vector3) -> String:
	var best := "gunshot"
	var bd := 2.5
	for hz in builder.hazards:
		var d := pos.distance_to(hz[0])
		if d < bd:
			bd = d
			best = String(hz[1])
	return best


func toast(text: String, col := Color.WHITE) -> void:
	if hud:
		hud.toast(text, col)


# --- Effects you can see ------------------------------------------------------------------

func tracer(a: Vector3, b: Vector3) -> void:
	var dir := b - a
	if dir.length() < 0.1:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, dir.length())
	mi.mesh = bm
	mi.material_override = _glow(Color(1.0, 0.85, 0.5))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var up := Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.FORWARD
	mi.look_at_from_position((a + b) * 0.5, b, up)
	var tw := create_tween()
	tw.tween_property(mi, "transparency", 1.0, 0.09)
	tw.tween_callback(mi.queue_free)


func impact(pos: Vector3, normal: Vector3) -> void:
	_burst(pos, normal, Color(0.7, 0.68, 0.62), 10, 3.0, 0.06)


func blood(pos: Vector3) -> void:
	_burst(pos, Vector3.UP, Color(0.45, 0.02, 0.03), 14, 2.2, 0.05)


func _burst(pos: Vector3, normal: Vector3, col: Color, amount: int, speed: float, size: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 45.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.mesh = _fx_mesh(col)
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _fx_mesh(col: Color) -> Mesh:
	var k := col.to_html()
	if not _fx_meshes.has(k):
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = Humanoid.mat(col)
		_fx_meshes[k] = sm
	return _fx_meshes[k]


func _glow(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# --- Sky, sun and lights ---------------------------------------------------------------------

func _environment() -> void:
	atmosphere = DhakaAtmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	var size := Vector3(builder.w * LevelBuilder.C, builder.floors.size() * LevelBuilder.H, builder.h * LevelBuilder.C)
	atmosphere.setup(size, String(def.get("palette", "")) == "night" and bool(def.get("roofed", true)) and builder.floors.size() == 1)
	RenderQuality.apply_saved(get_viewport(), atmosphere.environment, atmosphere.sun, atmosphere.dust)


func _update_sun() -> void:
	if atmosphere == null:
		return
	atmosphere.set_hour(WorldState.game_seconds / 3600.0)
	var lamp := atmosphere.lamp_amount()
	for l in builder.lamps:
		if is_instance_valid(l):
			l.light_energy = 2.4 * lamp


func _update_lights() -> void:
	var lit := WorldState.vision_multiplier(sector) >= 1.0
	for l in builder.lights:
		if is_instance_valid(l):
			l.light_energy = 1.1 if lit else 0.04


func _clock_text() -> String:
	var c := WorldState.clock()
	return "%02d:%02d" % [c.x, c.y]


func _hour_text(h: float) -> String:
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]
