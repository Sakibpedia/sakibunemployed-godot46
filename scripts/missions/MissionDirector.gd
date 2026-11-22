extends Node
## The `Missions` autoload: the story (five acts) and the side jobs from Data/Story/missions.json,
## the named cast from Data/Story/characters.json, mission markers in the world (walk into one to
## start), every step type (docs/ARCHITECTURE.md 7), rewards, failure and retry, the ending, and the
## pacing of random street encounters.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal mission_started(id: String)
signal mission_passed(id: String)
signal mission_failed(id: String, reason: String)
signal objective_changed(line: Dictionary)

const MISSIONS_PATH := "res://Data/Story/missions.json"
const CHARS_PATH := "res://Data/Story/characters.json"
const NO_HOME := ["bulu", "dulal", "shahjahan", "first_examiner", "viva_chair", "tanvir", "rafi"]

var missions: Array = []
var by_id: Dictionary = {}
var chars: Dictionary = {}
var world: Node3D = null
var city: CityData = null
var active: Dictionary = {}
var step_i := -1
var step: Dictionary = {}
var npcs: Dictionary = {}               # character id -> Citizen
var _markers: Dictionary = {}           # mission id -> Node3D
var _spawned: Array = []                # mission-only nodes to clean up
var _pickup: Node3D = null
var _st: Dictionary = {}                # per-step state
var _encounter_t := 30.0
var _marker_t := 0.0
var dialogue: DialogueBox
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS_PATH))
	if typeof(m) == TYPE_DICTIONARY:
		missions = (m as Dictionary).get("missions", [])
		for x in missions:
			by_id[String((x as Dictionary)["id"])] = x
	var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARS_PATH))
	if typeof(c) == TYPE_DICTIONARY:
		for ch in (c as Dictionary).get("characters", []):
			chars[String((ch as Dictionary)["id"])] = ch


func reset() -> void:
	world = null
	city = null
	active = {}
	step_i = -1
	step = {}
	npcs.clear()
	_markers.clear()
	_spawned.clear()
	_pickup = null
	_st = {}


func attach_world(w: Node3D) -> void:
	world = w
	city = Services.city
	dialogue = DialogueBox.new()
	w.add_child(dialogue)
	dialogue.visible = false
	dialogue.set_characters(chars)
	for id in chars:
		if id in NO_HOME:
			continue
		var rec: Dictionary = chars[id]
		if bool(rec.get("ghost", false)):
			continue
		_spawn_npc(id, String(rec.get("home", "")))
	var p: Node = Services.player
	if p != null and p.has_signal(&"died"):
		p.connect(&"died", _on_player_died)
	_refresh_markers()
	if not GameState.flag("intro_done"):
		GameState.set_flag("intro_done")
		await get_tree().create_timer(1.2).timeout
		var hud: Node = Services.hud
		if hud != null:
			hud.call("big_message", {"bn": "এস এম নাজমুয সাকিব বেকার", "en": "S M Nazmuz Sakib is unemployed"}, UiKit.MARIGOLD, 4.0)
		Services.say_toast({"bn": "হলুদ চিহ্নে হেঁটে গেলে মিশন শুরু হয়। F1 নিয়ন্ত্রণ দেখায়।", "en": "Walk into a yellow marker to start a mission. F1 shows the controls."}, "info")


# --- Characters ------------------------------------------------------------------------------------

func _spawn_npc(id: String, poi_id: String) -> Citizen:
	if npcs.has(id) and is_instance_valid(npcs[id]) and (npcs[id] as Citizen).is_alive():
		return npcs[id]
	var rec: Dictionary = chars.get(id, {"id": id})
	var pos := city.poi_pos(poi_id if poi_id != "" else String(rec.get("home", "mess")))
	pos += Vector3(_rng.randf_range(-1.5, 1.5), 0.1, _rng.randf_range(-1.5, 1.5))
	var c := ActorFactory.spawn_character(rec, Services.peds if Services.peds != null else world, pos, _rng.randf() * TAU)
	c.ai.order_guard(pos)
	npcs[id] = c
	return c


func character_name(id: String) -> Dictionary:
	if id == "sakib":
		return {"bn": "সাকিব", "en": "Sakib"}
	return (chars.get(id, {}) as Dictionary).get("name", {"bn": id, "en": id})


# --- Availability and markers -----------------------------------------------------------------------

func _completed(id: String) -> bool:
	return (GameState.missions.get("completed", []) as Array).has(id)


func _available(m: Dictionary) -> bool:
	var id := String(m["id"])
	if _completed(id) and not bool(m.get("repeat", false)):
		return false
	for r in m.get("requires", []):
		if not _completed(String(r)):
			return false
	return true


func _in_hours(m: Dictionary) -> bool:
	var hrs: Array = m.get("hours", [])
	if hrs.size() < 2:
		return true
	var h := GameState.hour()
	var a := float(hrs[0])
	var b := float(hrs[1])
	return h >= a and h <= b if a <= b else (h >= a or h <= b)


func _refresh_markers() -> void:
	for k in _markers:
		if is_instance_valid(_markers[k]):
			(_markers[k] as Node3D).queue_free()
	_markers.clear()
	if world == null or not active.is_empty():
		return
	var story_shown := false
	for m in missions:
		var md: Dictionary = m
		if not _available(md):
			continue
		var story := String(md["kind"]) == "story"
		if story and story_shown:
			continue
		if story:
			story_shown = true
		_markers[String(md["id"])] = _make_marker(md, story)


func _make_marker(m: Dictionary, story: bool) -> Node3D:
	var n := Node3D.new()
	world.add_child(n)
	n.global_position = city.poi_pos(String(m["start_poi"])) + Vector3(2.0, 0, 0)
	var col := UiKit.MARIGOLD if story else UiKit.TEAL
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.1
	cm.height = 0.12
	ring.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position = Vector3(0, 0.08, 0)
	n.add_child(ring)
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.4
	bm.bottom_radius = 0.9
	bm.height = 5.0
	beam.mesh = bm
	var bmat := mat.duplicate() as StandardMaterial3D
	bmat.albedo_color = Color(col.r, col.g, col.b, 0.16)
	beam.material_override = bmat
	beam.position = Vector3(0, 2.5, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	var l := Label3D.new()
	l.text = Game.text(m["title"])
	l.font = UiKit.font(true)
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = col
	l.position = Vector3(0, 3.0, 0)
	l.visibility_range_end = 120.0
	n.add_child(l)
	n.set_meta(&"mission", String(m["id"]))
	return n


func can_random_encounter() -> bool:
	return _encounter_t <= 0.0 and active.is_empty() and not Exams.is_open()


func note_random_encounter() -> void:
	_encounter_t = _rng.randf_range(80.0, 140.0)


# --- Main loop ------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	_encounter_t -= delta
	var p: Node3D = Services.player
	if p == null:
		return
	if active.is_empty():
		_marker_t -= delta
		if _marker_t <= 0.0:
			_marker_t = 0.3
			_check_markers(p)
	else:
		_tick_step(delta, p)


func _check_markers(p: Node3D) -> void:
	if Exams.is_open() or (dialogue != null and dialogue.is_open()) or bool(p.call("in_vehicle")):
		return
	for id in _markers:
		var mk: Node3D = _markers[id]
		if not is_instance_valid(mk):
			continue
		if mk.global_position.distance_to(p.global_position) < 1.8:
			var m: Dictionary = by_id[id]
			if not _in_hours(m):
				var hrs: Array = m.get("hours", [0, 24])
				if not _st.get("hours_warned", false):
					_st["hours_warned"] = true
					Services.say_toast({"bn": "এই মিশন %s টা থেকে %s টার মধ্যে।" % [UiKit.bengali_digits(str(int(hrs[0]))), UiKit.bengali_digits(str(int(hrs[1])))],
						"en": "This mission is available between %d:00 and %d:00." % [int(hrs[0]), int(hrs[1])]}, "info")
				return
			_st.erase("hours_warned")
			start(id)
			return


func start(id: String) -> void:
	var m: Dictionary = by_id.get(id, {})
	if m.is_empty():
		return
	active = m
	step_i = -1
	GameState.missions["active"] = id
	for k in _markers:
		if is_instance_valid(_markers[k]):
			(_markers[k] as Node3D).queue_free()
	_markers.clear()
	mission_started.emit(id)
	var hud: Node = Services.hud
	if hud != null:
		hud.call("big_message", m["title"], UiKit.MARIGOLD, 3.0)
	AudioEventBus.play_ui("objective")
	var intro: Array = m.get("intro", [])
	if not intro.is_empty():
		dialogue.play(intro, [], func(_c: String) -> void: _next_step())
	else:
		_next_step()


func _set_objective(text: Dictionary, target: Vector3) -> void:
	var hud: Node = Services.hud
	if hud != null:
		hud.call("set_mission", active.get("title", {}), text)
		hud.call("set_mission_target", target)
	objective_changed.emit(text)


func _next_step() -> void:
	if active.is_empty():
		return
	step_i += 1
	var steps: Array = active["steps"]
	if step_i >= steps.size():
		_pass()
		return
	step = steps[step_i]
	_st = {"t": 0.0}
	var only := String(step.get("only_if_flag", ""))
	var skip := String(step.get("skip_if_flag", ""))
	if (only != "" and not GameState.flag(only)) or (skip != "" and GameState.flag(skip)):
		_next_step()
		return
	var text: Dictionary = step.get("text", {"bn": "", "en": ""})
	var target := Vector3.INF
	var type := String(step["type"])
	match type:
		"talk", "choice", "exam", "deliver":
			var c := _spawn_npc(String(step["npc"]), String(step.get("spawn_poi", "")))
			c.mission_tag = String(active["id"])
			c.visuals.set_marker("mission")
			target = c.global_position
			_st["npc"] = c
		"goto":
			target = city.poi_pos(String(step["poi"]))
		"wait":
			target = Vector3.INF
			text = {"bn": Game.text(text) + " · E চেপে সময় এগিয়ে নাও", "en": String(text.get("en", "")) + " · press E to pass the time"}
		"cutscene":
			dialogue.play(step.get("lines", []), [], func(_c: String) -> void: _next_step())
			return
		"reward":
			_apply_rewards(step)
			Services.say_toast(text, "good")
			_next_step()
			return
		"posters":
			_st["base"] = GameState.posters_read.size() if String(step.get("mode", "read")) == "read" else GameState.posters_torn.size()
		"banish":
			_st["base"] = int(GameState.stats.get("ghosts_banished", 0))
		"duels":
			_st["base"] = int(GameState.stats.get("duels_won", 0))
		"kill":
			var targets: Array = []
			for t in step.get("targets", []):
				var td: Dictionary = t
				var c := _spawn_npc(String(td["npc"]), String(td.get("poi", "")))
				c.mission_tag = String(active["id"])
				c.visuals.set_marker("target")
				c.profile["armed"] = true
				targets.append(c)
				target = c.global_position
				for g in int(step.get("guards", 0)):
					var gp := PersonGenerator.make(_rng.randi(), "goon", "")
					gp["armed"] = _rng.randf() < 0.6
					var guard := ActorFactory.spawn(gp, Services.peds, c.global_position + Vector3(_rng.randf_range(-6, 6), 0.1, _rng.randf_range(-6, 6)))
					guard.persistent = true
					_spawned.append(guard)
			_st["targets"] = targets
			_st["engaged"] = false
		"collect":
			var at := Vector3.INF
			if step.has("at_npc") and npcs.has(String(step["at_npc"])) and is_instance_valid(npcs[String(step["at_npc"])]):
				at = (npcs[String(step["at_npc"])] as Node3D).global_position + Vector3(0.8, 0, 0.8)
			else:
				at = city.poi_pos(String(step.get("poi", "mess")))
			_pickup = _make_pickup(at)
			target = at
		"escort":
			var c := _spawn_npc(String(step["npc"]), String(step.get("spawn_poi", "")))
			c.mission_tag = String(active["id"])
			c.ai.order_follow(Services.player)
			_st["npc"] = c
			target = city.poi_pos(String(step["to"]))
			if step.has("power_cut") and Services.ghosts != null:
				Services.ghosts.call("force_cut", String(step["power_cut"]), true)
		"chase":
			var c := _spawn_npc(String(step["npc"]), String(step.get("spawn_poi", "")))
			c.mission_tag = String(active["id"])
			c.visuals.set_marker("target")
			_st["npc"] = c
			_st["route"] = step.get("route", [])
			_st["leg"] = 0
			_st["far"] = 0.0
			target = c.global_position
		"defend":
			_st["wave"] = -1
			_st["enemies"] = []
			target = city.poi_pos(String(step["poi"]))
		"drive":
			var poi_id := String(step["poi"])
			if poi_id == "random":
				var keys := city.pois.keys()
				for attempt in 20:
					poi_id = String(keys[_rng.randi_range(0, keys.size() - 1)])
					if city.poi_pos(poi_id).distance_to(Services.player.global_position) > 250.0:
						break
			_st["poi"] = poi_id
			target = city.poi_pos(poi_id)
		"survive":
			if String(step.get("spawn_ghost", "")) != "":
				_ensure_boss_spirit(String(step["spawn_ghost"]), 2, 1, 1)
		"boss_ghost":
			_ensure_boss_spirit(String(step["spirit"]), 3, int(step.get("count", 5)), int(step.get("pass", 4)))
			target = city.poi_pos(String(step.get("poi", "graveyard")))
		"ending":
			_show_ending()
			return
	_st["target"] = target
	_set_objective(text, target)


func _tick_step(delta: float, p: Node3D) -> void:
	if step.is_empty() or Exams.is_open() or (dialogue != null and dialogue.is_open()):
		return
	_st["t"] = float(_st.get("t", 0.0)) + delta
	var type := String(step["type"])
	if step.has("time") and float(_st["t"]) > float(step["time"]):
		_fail({"bn": "সময় শেষ", "en": "Out of time"})
		return
	if step.has("before_hour") and GameState.hour() > float(step["before_hour"]) and GameState.hour() < float(step["before_hour"]) + 6.0:
		_fail({"bn": "দেরি হয়ে গেল", "en": "Too late"})
		return
	match type:
		"talk", "choice", "exam", "deliver":
			var c: Citizen = _st.get("npc", null)
			if c == null or not is_instance_valid(c) or not c.is_alive():
				_fail({"bn": "যার সঙ্গে কথা বলার কথা, সে আর নেই", "en": "The person you needed is gone"})
				return
			if Services.hud != null:
				Services.hud.call("set_mission_target", c.global_position)
		"goto":
			var tp: Vector3 = _st["target"]
			if p.global_position.distance_to(tp) < float(step.get("radius", 5.0)) + (8.0 if String(step["poi"]) == "tower_roof" else 0.0):
				_next_step()
		"wait":
			if _hour_reached(float(step["until_hour"])):
				_next_step()
		"posters":
			var now := GameState.posters_read.size() if String(step.get("mode", "read")) == "read" else GameState.posters_torn.size()
			var need := int(step["count"])
			var got := now - int(_st["base"])
			_progress(got, need)
			if got >= need:
				_next_step()
		"banish":
			var got2 := int(GameState.stats.get("ghosts_banished", 0)) - int(_st["base"])
			_progress(got2, int(step["count"]))
			if got2 >= int(step["count"]):
				_next_step()
		"duels":
			var got3 := int(GameState.stats.get("duels_won", 0)) - int(_st["base"])
			_progress(got3, int(step["count"]))
			if got3 >= int(step["count"]):
				_next_step()
		"kill":
			var all_dead := true
			for t in _st["targets"]:
				var tc := t as Citizen
				if tc == null or not is_instance_valid(tc):
					continue
				if not tc.health.is_dead():
					all_dead = false
					if not bool(_st["engaged"]) and tc.global_position.distance_to(p.global_position) < 28.0:
						_st["engaged"] = true
						for t2 in _st["targets"]:
							(t2 as Citizen).ai.order_attack(p)
						for g in _spawned:
							if g is Citizen and is_instance_valid(g):
								(g as Citizen).ai.order_attack(p)
					if Services.hud != null:
						Services.hud.call("set_mission_target", tc.global_position)
			if all_dead:
				_next_step()
		"collect":
			if _pickup != null and is_instance_valid(_pickup):
				_pickup.rotate_y(delta * 2.0)
				if _pickup.global_position.distance_to(p.global_position) < 1.8:
					GameState.add_item(String(step["item"]), 1)
					AudioEventBus.play_ui("pickup")
					_pickup.queue_free()
					_pickup = null
					_next_step()
		"escort":
			var c2: Citizen = _st.get("npc", null)
			if c2 == null or not is_instance_valid(c2) or not c2.is_alive():
				_fail({"bn": "যাকে নিয়ে যাওয়ার কথা, সে আর নেই", "en": "The person you were escorting is gone"})
				return
			if c2.global_position.distance_to(_st["target"]) < 7.0:
				if step.has("power_cut") and Services.ghosts != null:
					Services.ghosts.call("force_cut", String(step["power_cut"]), false)
				c2.ai.order_guard(c2.global_position)
				_next_step()
		"chase":
			_tick_chase(delta, p)
		"defend":
			_tick_defend(p)
		"drive":
			var veh: Variant = p.get("vehicle")
			if veh == null:
				_set_objective({"bn": "একটা গাড়িতে ওঠো (F)", "en": "Get into a vehicle (F)"}, _st["target"])
			elif (veh as Node3D).global_position.distance_to(_st["target"]) < 12.0:
				_next_step()
			else:
				_set_objective(step.get("text", {}), _st["target"])
		"survive":
			if _hour_reached(float(step["until_hour"])):
				_next_step()
		"boss_ghost":
			for s in GameState.spirits:
				var sd: Dictionary = s
				if String(sd.get("id", "")) == String(step["spirit"]) and bool(sd.get("banished", false)):
					_next_step()
					return


func _hour_reached(h: float) -> bool:
	var now := GameState.hour()
	var diff := fmod(now - h + 24.0, 24.0)
	return diff < 6.0


func _progress(got: int, need: int) -> void:
	var text: Dictionary = step.get("text", {})
	var hud: Node = Services.hud
	if hud != null:
		hud.call("set_mission", active.get("title", {}), {"bn": "%s (%s/%s)" % [String(text.get("bn", "")), UiKit.bengali_digits(str(mini(got, need))), UiKit.bengali_digits(str(need))],
			"en": "%s (%d/%d)" % [String(text.get("en", "")), mini(got, need), need]})


func _tick_chase(_delta: float, p: Node3D) -> void:
	var c: Citizen = _st.get("npc", null)
	if c == null or not is_instance_valid(c):
		_fail({"bn": "সে পালিয়েছে", "en": "He got away"})
		return
	var d := c.global_position.distance_to(p.global_position)
	if Services.hud != null:
		Services.hud.call("set_mission_target", c.global_position)
	if d < 2.0 or c.health.hp < c.health.max_hp * 0.7:
		c.stop_moving()
		c.ai.set_state(ActorAI.S.COWER, 9999.0)
		c.say({"bn": "আচ্ছা আচ্ছা! মারবেন না! প্যাকেট নেন!", "en": "All right, all right! Don't hit me! Take the packet!"}, 4.0, 2)
		_next_step()
		return
	if d > 110.0:
		_st["far"] = float(_st["far"]) + 0.016
		if float(_st["far"]) > 8.0:
			_fail({"bn": "সে পালিয়ে গেল", "en": "He got away"})
			return
	else:
		_st["far"] = 0.0
	if not c.has_target():
		var route: Array = _st["route"]
		var leg := int(_st["leg"])
		if leg < route.size():
			c.ai.set_state(ActorAI.S.GOTO)
			c.move_to(city.poi_pos(String(route[leg])), 4.2)
			c.anim_state = "run"
			_st["leg"] = leg + 1
		else:
			_st["leg"] = 0


func _tick_defend(p: Node3D) -> void:
	var enemies: Array = _st["enemies"]
	var alive := 0
	for e in enemies:
		var ec := e as Citizen
		if ec != null and is_instance_valid(ec) and ec.is_alive() and not ec.health.is_dying():
			alive += 1
	if alive > 0:
		return
	var waves: Array = step["waves"]
	var wave := int(_st["wave"]) + 1
	if wave >= waves.size():
		_next_step()
		return
	_st["wave"] = wave
	var w: Dictionary = waves[wave]
	var centre := city.poi_pos(String(step["poi"]))
	var list: Array = []
	for i in int(w.get("count", 3)):
		var gp := PersonGenerator.make(_rng.randi(), String(w.get("role", "goon")), "")
		gp["armed"] = bool(w.get("armed", false))
		var ang := _rng.randf() * TAU
		var pos := centre + Vector3(cos(ang) * 18.0, 0.1, sin(ang) * 18.0)
		if centre.y > 3.0:
			pos = centre + Vector3(cos(ang) * 8.0, 0.2, sin(ang) * 8.0)
		var g := ActorFactory.spawn(gp, Services.peds, pos)
		g.persistent = true
		g.ai.order_attack(p)
		g.say(TauntBank.pick("goon", _rng), 3.0, 0)
		list.append(g)
		_spawned.append(g)
	_st["enemies"] = list
	Services.say_toast({"bn": "আক্রমণ আসছে! (%s/%s)" % [UiKit.bengali_digits(str(wave + 1)), UiKit.bengali_digits(str(waves.size()))],
		"en": "Here they come! (wave %d/%d)" % [wave + 1, waves.size()]}, "warn")


func _make_pickup(at: Vector3) -> Node3D:
	var n := Node3D.new()
	world.add_child(n)
	n.global_position = at + Vector3(0, 0.6, 0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 0.25, 0.45)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = UiKit.MARIGOLD
	m.emission_enabled = true
	m.emission = UiKit.MARIGOLD
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	n.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = UiKit.MARIGOLD
	light.omni_range = 4.0
	light.light_energy = 1.5
	n.add_child(light)
	_spawned.append(n)
	return n


func _ensure_boss_spirit(id: String, strength: int, count: int, pass_mark: int) -> void:
	for s in GameState.spirits:
		if String((s as Dictionary).get("id", "")) == id:
			return
	var rec: Dictionary = chars.get(id, {})
	GameState.spirits.append({"id": id, "name": rec.get("name", {"bn": "প্রথম পরীক্ষক", "en": "The First Examiner"}),
		"face": String(rec.get("face", "m_elder_white")), "look": {"gender": "m", "outfit": "panjabi", "height": 1.8},
		"questions": [], "strength": strength, "banished": false, "boss": true, "exam": {"count": count, "pass": pass_mark},
		"district": "jurain", "died_at": {"x": 0, "z": 0, "day": 0}})


# --- Talking and world interaction ---------------------------------------------------------------------

func on_talk(c: Citizen) -> void:
	var id := String(c.profile.get("id", ""))
	if not active.is_empty() and not step.is_empty() and String(step.get("npc", "")) == id:
		var type := String(step["type"])
		match type:
			"talk":
				dialogue.play(step.get("lines", []), [], func(_ch: String) -> void:
					_clear_npc_marker(c)
					_next_step())
			"choice":
				dialogue.play(step.get("lines", []), step.get("choices", []), func(ch: String) -> void:
					_apply_choice(ch)
					_clear_npc_marker(c)
					_next_step())
			"exam":
				_start_step_exam(c)
			"deliver":
				if GameState.take_item(String(step["item"])):
					_clear_npc_marker(c)
					c.say({"bn": "ধন্যবাদ, বাবা!", "en": "Thank you, son!"}, 3.0, 1)
					_next_step()
				else:
					Services.say_toast({"bn": "জিনিসটা এখনো তোমার কাছে নেই।", "en": "You don't have it yet."}, "info")
		return
	# a named character without a current job for you: a line about what they offer
	var rec: Dictionary = chars.get(id, {})
	c.say(rec.get("bio", {"bn": "...", "en": "..."}), 5.0, 1)


func _clear_npc_marker(c: Citizen) -> void:
	if is_instance_valid(c):
		c.mission_tag = ""
		c.visuals.set_marker("")


func _start_step_exam(c: Citizen) -> void:
	var ctx := {"mode": String(step.get("mode", "gate")), "speaker": c.display_name(), "face": String(c.profile.get("face", "")),
		"voice": c.profile.get("voice", {}), "family": String(step.get("family", "")), "subject": String(step.get("subject", "")),
		"cited_only": bool(step.get("cited_only", false)), "count": int(step.get("count", 3)), "pass": int(step.get("pass", 2)),
		"allow_bribe": bool(step.get("allow_bribe", false)), "bribe_cost": int(step.get("bribe_cost", 200)),
		"allow_flee": true, "stakes": step.get("text", {})}
	Exams.start(ctx, func(r: Dictionary) -> void:
		if bool(r.get("passed", false)):
			if step.has("flag_pass"):
				GameState.set_flag(String(step["flag_pass"]))
			_clear_npc_marker(c)
			_next_step()
		else:
			match String(step.get("on_fail", "retry")):
				"continue":
					GameState.set_flag("failed_%s_%d" % [String(active["id"]), step_i])
					_clear_npc_marker(c)
					_next_step()
				"fail":
					_fail({"bn": "পরীক্ষায় ফেল", "en": "Failed the questions"})
				_:
					Services.say_toast({"bn": "আবার চেষ্টা করো: কাছে গিয়ে E।", "en": "Try again: go close and press E."}, "info")
	)


func on_interact_world(pos: Vector3) -> void:
	if city == null:
		return
	# The Tower has real stairs now.  The old gate <-> roof teleport is gone: the gate only points
	# the player at the front door, and the roof is reached by climbing all nine storeys.
	var gate := city.poi_pos("tower_gate")
	if pos.distance_to(gate) < 4.0:
		Services.say_toast({"bn": "টাওয়ারের দরজা ডানদিকে। সিঁড়ি ভেঙে ছাদে ওঠো।", "en": "The tower door is on the right. Climb the stairs to the roof."}, "info")
		return
	# sleep at the mess: skip to morning and save
	var mess := city.poi_pos("mess")
	if pos.distance_to(mess) < 6.0 and (active.is_empty() or String(step.get("type", "")) == "wait"):
		var target_h := 7.0
		if not active.is_empty():
			target_h = float(step.get("until_hour", 7.0))
		_skip_time(target_h)
		GameState.save_game()
		Services.say_toast({"bn": "ঘুম দিলে। খেলা সংরক্ষিত।", "en": "You slept. Game saved."}, "good")
		return
	if not active.is_empty() and String(step.get("type", "")) == "wait":
		_skip_time(float(step["until_hour"]))


func _skip_time(h: float) -> void:
	await Game.fade_to(1.0, 0.4)
	GameState.skip_to(h)
	if Services.atmosphere != null:
		Services.atmosphere.call("set_hour", GameState.hour())
	await Game.fade_to(0.0, 0.6)


# --- Results ---------------------------------------------------------------------------------------------

func _apply_choice(choice_id: String) -> void:
	for ch in step.get("choices", []):
		var cd: Dictionary = ch
		if String(cd.get("id", "")) == choice_id:
			_apply_rewards(cd)
			if cd.has("flag"):
				GameState.set_flag(String(cd["flag"]))


func _apply_rewards(r: Dictionary) -> void:
	if r.has("money"):
		GameState.add_money(int(r["money"]))
	if r.has("respect"):
		GameState.change_respect(int(r["respect"]))
	if r.has("honesty"):
		GameState.change_honesty(int(r["honesty"]))
	if r.has("tokens"):
		GameState.add_item("study_tokens", int(r["tokens"]))
	if r.has("item"):
		var item := String(r["item"])
		GameState.add_item(item, int(r.get("count", 1)))
		if item == "pistol":
			GameState.add_item("pistol_ammo", int(r.get("ammo", 24)))
	if r.has("ammo") and not r.has("item"):
		GameState.add_item("pistol_ammo", int(r["ammo"]))


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			if n is Citizen and (n as Citizen).is_alive():
				(n as Citizen).persistent = false
			elif n is Node3D and not (n is Citizen):
				(n as Node3D).queue_free()
	_spawned.clear()
	if _pickup != null and is_instance_valid(_pickup):
		_pickup.queue_free()
	_pickup = null
	for id in npcs:
		var c: Citizen = npcs[id]
		if is_instance_valid(c):
			c.mission_tag = ""
			c.visuals.set_marker("")
	var hud: Node = Services.hud
	if hud != null:
		hud.call("set_mission", {"bn": "", "en": ""}, {"bn": "", "en": ""})
		hud.call("set_mission_target", Vector3.INF)


func _pass() -> void:
	var id := String(active["id"])
	var r: Dictionary = active.get("rewards", {})
	_apply_rewards(r)
	var done: Array = GameState.missions.get("completed", [])
	if not done.has(id):
		done.append(id)
	GameState.missions["completed"] = done
	GameState.missions["active"] = ""
	GameState.bump("missions")
	GameState.bump("people_helped")
	var hud: Node = Services.hud
	if hud != null:
		hud.call("big_message", {"bn": "মিশন সম্পন্ন!  সম্মান +%s" % UiKit.bengali_digits(str(int(r.get("respect", 0)))), "en": "MISSION PASSED  Respect +%d" % int(r.get("respect", 0))}, UiKit.GREEN, 4.0)
	AudioEventBus.play_ui("objective")
	_cleanup()
	active = {}
	step = {}
	step_i = -1
	mission_passed.emit(id)
	GameState.save_game()
	_refresh_markers()


func _fail(reason: Dictionary) -> void:
	if active.is_empty():
		return
	var id := String(active["id"])
	var failed: Dictionary = GameState.missions.get("failed", {})
	failed[id] = int(failed.get(id, 0)) + 1
	GameState.missions["failed"] = failed
	GameState.missions["active"] = ""
	var hud: Node = Services.hud
	if hud != null:
		hud.call("big_message", {"bn": "মিশন ব্যর্থ\n%s" % String(reason.get("bn", "")), "en": "MISSION FAILED\n%s" % String(reason.get("en", ""))}, UiKit.RED, 4.0)
	AudioEventBus.play_ui("fail")
	if step.has("power_cut") and Services.ghosts != null:
		Services.ghosts.call("force_cut", String(step["power_cut"]), false)
	_cleanup()
	active = {}
	step = {}
	step_i = -1
	mission_failed.emit(id, Game.text(reason))
	_refresh_markers()


func _on_player_died() -> void:
	if not active.is_empty():
		_fail({"bn": "সাকিব অজ্ঞান", "en": "Sakib was knocked out"})


func status_line() -> Dictionary:
	if not active.is_empty() and not step.is_empty():
		var t: Dictionary = active["title"]
		var o: Dictionary = step.get("text", {})
		return {"bn": "%s: %s" % [String(t.get("bn", "")), String(o.get("bn", ""))], "en": "%s: %s" % [String(t.get("en", "")), String(o.get("en", ""))]}
	for m in missions:
		var md: Dictionary = m
		if String(md["kind"]) == "story" and _available(md):
			var poi := city.poi(String(md["start_poi"])) if city != null else {}
			var where: Dictionary = poi.get("name", {"bn": "", "en": ""})
			return {"bn": "পরের মিশন: %s · %s (হলুদ চিহ্ন)" % [String((md["title"] as Dictionary)["bn"]), String(where.get("bn", ""))],
				"en": "Next mission: %s · %s (yellow marker)" % [String((md["title"] as Dictionary)["en"]), String(where.get("en", ""))]}
	return {"bn": "সব মিশন শেষ। শহর তোমার।", "en": "All missions done. The city is yours."}


# --- Ending --------------------------------------------------------------------------------------------------

func _show_ending() -> void:
	_cleanup()
	var honest := GameState.honesty
	var lines: Array = []
	var title := {"bn": "", "en": ""}
	if GameState.flag("ending_deal"):
		title = {"bn": "শর্টকাট", "en": "The Shortcut"}
		lines.append({"bn": "সাকিব ক্যাডার হলো, কিন্তু রাতে আয়নায় নিজের মুখ দেখতে পারে না।", "en": "Sakib became a cadre, but at night he cannot face his own reflection."})
	elif GameState.flag("viva_passed") and honest >= 60:
		title = {"bn": "সৎ ক্যাডার", "en": "The Honest Cadre"}
		lines.append({"bn": "ভাইভা বোর্ড উঠে দাঁড়িয়ে হাততালি দিল। এস এম নাজমুয সাকিব আর বেকার নন।", "en": "The viva board stood and applauded. S M Nazmuz Sakib is unemployed no more."})
	elif GameState.flag("bank_offer"):
		title = {"bn": "ব্যাংকের চাকরি", "en": "The Bank Job"}
		lines.append({"bn": "বিসিএস হলো না, কিন্তু ব্যাংকের চাকরিটা হলো। রিনা আপা মিষ্টি বিলালেন।", "en": "Not the BCS, but the bank job came through. Rina Apa handed out sweets."})
	else:
		title = {"bn": "আবার চেষ্টা", "en": "Try Again"}
		lines.append({"bn": "এ বছর হলো না। সার্কুলার আবার আসবে। সাকিব আবার পড়তে বসল।", "en": "Not this year. The circular will come again. Sakib sat down to study again."})
	var ghosts := GameState.unbanished_spirits().size()
	if ghosts > 0:
		lines.append({"bn": "কিন্তু %s জন আত্মা এখনো রাতে তার দরজায় প্রশ্ন নিয়ে দাঁড়ায়।" % UiKit.bengali_digits(str(ghosts)), "en": "But %d spirits still wait at his door at night with their questions." % ghosts})
	if GameState.flag("tanvir_saved"):
		lines.append({"bn": "তানভীর প্রথমবার নিজে পড়ে প্রিলি পাস করল।", "en": "Tanvir passed the prelims by studying, for the first time."})
	lines.append({"bn": "সততা %s · সম্মান %s · সঠিক উত্তর %s · মুক্ত আত্মা %s" % [UiKit.bengali_digits(str(honest)), UiKit.bengali_digits(str(GameState.respect)),
		UiKit.bengali_digits(str(int(GameState.stats.get("right", 0)))), UiKit.bengali_digits(str(int(GameState.stats.get("ghosts_banished", 0))))],
		"en": "Honesty %d · Respect %d · Right answers %d · Spirits freed %d" % [honest, GameState.respect, int(GameState.stats.get("right", 0)), int(GameState.stats.get("ghosts_banished", 0))]})
	lines.append({"bn": "ডেভেলপ করেছেন এস এম নাজমুয সাকিব", "en": "Developed by S M Nazmuz Sakib"})
	var hud: Node = Services.hud
	if hud != null:
		hud.call("big_message", title, UiKit.MARIGOLD, 6.0)
	var dl: Array = []
	for l in lines:
		var ld: Dictionary = l
		dl.append({"who": "narrator", "bn": ld["bn"], "en": ld["en"]})
	dialogue.play(dl, [], func(_c: String) -> void:
		GameState.set_flag("game_finished")
		_pass())
