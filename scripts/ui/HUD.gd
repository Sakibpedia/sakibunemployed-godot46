class_name HUD
extends CanvasLayer
## The on-screen game, GTA style, built from the SVG kit: radar with blips (bottom left) and the
## health bar under it; clock, day, money, police stars and the night-danger warning (top right);
## mission title and objective (top left); weapon, ammo, torch and study tokens (bottom right);
## crosshair; the "E" prompt and option lists; toasts; subtitles for every spoken line; big
## messages (MISSION PASSED, KNOCKED OUT); the pause menu with settings; the full map (M).
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

var waypoint := Vector3.INF:
	set(v):
		waypoint = v
		if _radar:
			_radar.waypoint = v
		if _map:
			_map.waypoint = v

var _root: Control
var _radar: CityMap
var _map: CityMap
var _map_layer: Control
var _health: TextureProgressBar
var _clock: Label
var _money: Label
var _stars: Label
var _danger: Label
var _mission: Label
var _objective: Label
var _weapon: Label
var _inv: Label
var _prompt: Label
var _prompt_box: PanelContainer
var _options: VBoxContainer
var _options_cb: Callable
var _options_list: Array = []
var _toasts: VBoxContainer
var _subtitle: Label
var _sub_t := 0.0
var _big: Label
var _big_t := 0.0
var _flash: ColorRect
var _cross: TextureRect
var _pause: Control
var _help: Label
var _dist: Label


func setup(city: CityData) -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.theme()
	add_child(_root)
	CityMap.build_texture(city, self)

	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	# radar
	var radar_frame := Panel.new()
	radar_frame.add_theme_stylebox_override("panel", UiKit.flat(Color(0.04, 0.08, 0.1, 0.75), 120, UiKit.MARIGOLD, 2))
	radar_frame.anchor_top = 1.0
	radar_frame.anchor_bottom = 1.0
	radar_frame.offset_left = 24
	radar_frame.offset_top = -300
	radar_frame.offset_right = 264
	radar_frame.offset_bottom = -60
	radar_frame.clip_contents = true
	radar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(radar_frame)
	_radar = CityMap.new()
	_radar.city = city
	_radar.zoom = 1.3
	_radar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_frame.add_child(_radar)
	_dist = UiKit.label("", 16, UiKit.MARIGOLD, true)
	_dist.anchor_top = 1.0
	_dist.anchor_bottom = 1.0
	_dist.offset_left = 24
	_dist.offset_top = -324
	_dist.offset_right = 264
	_dist.offset_bottom = -300
	_root.add_child(_dist)

	# health bar under the radar (hud_bar_* SVGs)
	_health = TextureProgressBar.new()
	_health.texture_under = UiKit.tex("hud_bar_track")
	_health.texture_progress = UiKit.tex("hud_bar_fill_health")
	_health.texture_over = UiKit.tex("hud_bar_frame")
	_health.max_value = 100
	_health.value = 100
	_health.nine_patch_stretch = true
	_health.anchor_top = 1.0
	_health.anchor_bottom = 1.0
	_health.offset_left = 24
	_health.offset_top = -50
	_health.offset_right = 264
	_health.offset_bottom = -30
	_root.add_child(_health)

	# top right: clock, money, stars, danger
	var tr := VBoxContainer.new()
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -420
	tr.offset_right = -24
	tr.offset_top = 18
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tr)
	_clock = UiKit.label("", 30, UiKit.PAPER, true)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_clock)
	_money = UiKit.label("", 30, UiKit.GREEN, true)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_money)
	_stars = UiKit.label("", 32, Color(0.95, 0.95, 0.95), true)
	_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_stars)
	_danger = UiKit.label("", 22, UiKit.RED, true)
	_danger.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_danger)

	# top left: mission and objective
	var tl := VBoxContainer.new()
	tl.offset_left = 24
	tl.offset_top = 18
	tl.offset_right = 760
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tl)
	_mission = UiKit.label("", 26, UiKit.MARIGOLD, true)
	tl.add_child(_mission)
	_objective = UiKit.label("", 22, UiKit.PAPER, false)
	tl.add_child(_objective)

	# bottom right: weapon and inventory
	var br := VBoxContainer.new()
	br.anchor_left = 1.0
	br.anchor_right = 1.0
	br.anchor_top = 1.0
	br.anchor_bottom = 1.0
	br.offset_left = -440
	br.offset_right = -24
	br.offset_top = -120
	br.offset_bottom = -24
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(br)
	_weapon = UiKit.label("", 28, UiKit.PAPER, true)
	_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_weapon)
	_inv = UiKit.label("", 18, UiKit.DIM)
	_inv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_inv)
	if Game.touch_mode:
		# The touch buttons own the bottom-right corner; weapon and inventory move under the clock.
		br.anchor_top = 0.0
		br.anchor_bottom = 0.0
		br.offset_top = 172
		br.offset_bottom = 268

	# crosshair
	_cross = TextureRect.new()
	_cross.texture = UiKit.tex("crosshair")
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.custom_minimum_size = Vector2(40, 40)
	_cross.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cross.size = Vector2(40, 40)
	_cross.position = -Vector2(20, 20)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.visible = false
	_root.add_child(_cross)

	# prompt and options
	_prompt_box = PanelContainer.new()
	_prompt_box.add_theme_stylebox_override("panel", UiKit.style("toast_plate"))
	_prompt_box.anchor_left = 0.5
	_prompt_box.anchor_right = 0.5
	_prompt_box.anchor_top = 0.62
	_prompt_box.anchor_bottom = 0.62
	_prompt_box.offset_left = -260
	_prompt_box.offset_right = 260
	_prompt_box.visible = false
	_root.add_child(_prompt_box)
	_prompt = UiKit.label("", 22, UiKit.PAPER, true)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_box.add_child(_prompt)
	_options = VBoxContainer.new()
	_options.anchor_left = 0.5
	_options.anchor_right = 0.5
	_options.anchor_top = 0.55
	_options.anchor_bottom = 0.55
	_options.offset_left = -280
	_options.offset_right = 280
	_options.visible = false
	_root.add_child(_options)

	# toasts and subtitles
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.offset_left = -430
	_toasts.offset_right = 430
	_toasts.offset_top = 90
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	_subtitle = UiKit.label("", 24, UiKit.PAPER, true)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.anchor_left = 0.15
	_subtitle.anchor_right = 0.85
	_subtitle.anchor_top = 1.0
	_subtitle.anchor_bottom = 1.0
	_subtitle.offset_top = -190
	_subtitle.offset_bottom = -110
	_root.add_child(_subtitle)
	_big = UiKit.label("", 64, UiKit.MARIGOLD, true)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.anchor_left = 0.0
	_big.anchor_right = 1.0
	_big.anchor_top = 0.35
	_big.anchor_bottom = 0.35
	_big.visible = false
	_root.add_child(_big)
	_help = UiKit.label("", 18, UiKit.PAPER)
	_help.offset_left = 24
	_help.offset_top = 120
	_help.offset_right = 700
	_help.visible = false
	_root.add_child(_help)
	_help.text = _help_text()

	_build_map()
	_build_pause()
	Services.toast.connect(toast)
	Services.subtitle.connect(_on_subtitle)
	GameState.health_changed.connect(func(v: float) -> void: _health.value = v)


func _help_text() -> String:
	if Game.language == "bn":
		return "W A S D হাঁটা · Shift দৌড় · C বসা · Space লাফ\nমাউস দেখা · ডান ক্লিক তাক · বাম ক্লিক ঘুষি/গুলি · Q অস্ত্র বদল · R রিলোড\nE কথা/পড়া/উত্তর · F গাড়িতে ওঠা-নামা · T টর্চ · H ব্যান্ডেজ · V ফার্স্ট পার্সন\nM মানচিত্র · Tab মিশন · Esc বিরতি · ১-৪ উত্তর বা পছন্দ"
	return "W A S D walk · Shift sprint · C crouch · Space jump\nMouse look · Right click aim · Left click punch/shoot · Q weapon · R reload\nE talk/read/answer · F enter/exit vehicle · T torch · H bandage · V first person\nM map · Tab missions · Esc pause · 1-4 answers or choices"


# --- Every frame --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var p: Node3D = Services.player
	_clock.text = "%s · %s %s" % [GameState.clock_text(), "দিন" if Game.language == "bn" else "Day", UiKit.num(GameState.day)]
	_money.text = "৳ %s" % UiKit.num(GameState.money)
	var heat_level := 0
	if Services.heat != null:
		heat_level = int(Services.heat.call("level"))
	_stars.text = "★".repeat(heat_level) + "☆".repeat(5 - heat_level) if heat_level > 0 else ""
	var gd: Node = Services.ghosts
	var exposed := gd != null and bool(gd.call("player_exposed"))
	var night := gd != null and bool(gd.call("is_night"))
	if exposed:
		_danger.text = "অন্ধকার! আলোয় বা ঘরে যাও" if Game.language == "bn" else "Dark! Get under a light or indoors"
		_danger.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	elif not night and GameState.hour() > 16.5 and GameState.hour() < 18.05:
		var mins := int((18.05 - GameState.hour()) * 60.0)
		_danger.text = ("সূর্যাস্ত %s মিনিটে" if Game.language == "bn" else "Sunset in %s min") % UiKit.num(mins)
		_danger.modulate.a = 1.0
	elif night:
		_danger.text = "রাত · নিরাপদ" if Game.language == "bn" else "Night · safe here"
		_danger.modulate.a = 0.8
	else:
		_danger.text = ""
	if p is Player:
		var pl := p as Player
		var wname := {"fists": {"bn": "ঘুষি", "en": "Fists"}, "rod": {"bn": "লোহার রড", "en": "Iron rod"}, "pistol": {"bn": "পিস্তল", "en": "Pistol"}}
		var wt := Game.text(wname.get(pl.weapon, wname["fists"]))
		if pl.weapon == "pistol":
			wt += "  %s / %s" % [UiKit.num(pl.mag), UiKit.num(GameState.count("pistol_ammo"))]
		_weapon.text = wt
		_cross.visible = pl.aiming or pl.first_person
		var inv := "ব্যান্ডেজ %s · ব্যাটারি %s · টোকেন %s · সম্মান %s · সততা %s" if Game.language == "bn" else "Bandages %s · Batteries %s · Tokens %s · Respect %s · Honesty %s"
		_inv.text = inv % [UiKit.num(GameState.count("bandages")), UiKit.num(GameState.count("batteries")), UiKit.num(GameState.count("study_tokens")),
			UiKit.num(GameState.respect), UiKit.num(GameState.honesty)]
		var target := _radar.mission_target if _radar.mission_target != Vector3.INF else waypoint
		if target != Vector3.INF:
			_dist.text = "%s m" % UiKit.num(int(target.distance_to(p.global_position)))
		else:
			_dist.text = ""
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.6)
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0:
			_subtitle.text = ""
	if _big_t > 0.0:
		_big_t -= delta
		if _big_t <= 0.0:
			_big.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible:
		for k in 4:
			if event.is_action_pressed("answer_%d" % (k + 1)) and k < _options_list.size():
				_choose(k)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("pause"):
			_close_options()
			get_viewport().set_input_as_handled()
			return
	if Exams.is_open():
		return
	if event.is_action_pressed("pause"):
		if _map_layer.visible:
			_toggle_map()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and not _pause.visible:
		_toggle_map()
	elif event.is_action_pressed("missions") and not _pause.visible:
		toast(Missions.status_line(), "info")
	elif event.is_action_pressed("help"):
		_help.visible = not _help.visible


# --- API used by the game -------------------------------------------------------------------------

func set_mission(title: Dictionary, objective: Dictionary) -> void:
	_mission.text = Game.text(title)
	_objective.text = Game.text2(objective)


func set_mission_target(p: Vector3) -> void:
	_radar.mission_target = p
	_map.mission_target = p


func set_prompt(label: Dictionary) -> void:
	if label.is_empty():
		_prompt_box.visible = false
		return
	_prompt.text = "[E]  " + Game.text(label)
	_prompt_box.visible = true


## True while a list of choices or the full map is open (TouchControls then leaves taps to the GUI).
func blocks_touch() -> bool:
	return _options.visible or (_map_layer != null and _map_layer.visible)


func show_options(title: Variant, options: Array, cb: Callable) -> void:
	for c in _options.get_children():
		c.queue_free()
	_options_list = options
	_options_cb = cb
	var t := UiKit.label(Game.text(title), 24, UiKit.MARIGOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_options.add_child(t)
	for i in mini(options.size(), 4):
		var o: Dictionary = options[i]
		var b := UiKit.button("%s  %s" % [UiKit.num(i + 1), Game.text(o.get("label", {}))], 20)
		b.pressed.connect(_choose.bind(i))
		_options.add_child(b)
	_options.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _choose(i: int) -> void:
	var o: Dictionary = _options_list[i]
	var cb := _options_cb
	_close_options()
	if cb.is_valid():
		cb.call(String(o.get("id", "")))


func _close_options() -> void:
	_options.visible = false
	_options_list = []
	if not _pause.visible and not Exams.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toast(line: Dictionary, kind: String = "info") -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.style("toast_plate"))
	var col := {"good": UiKit.GREEN, "warn": UiKit.PINK, "info": UiKit.PAPER}
	var l := UiKit.label(Game.text2(line), 20, col.get(kind, UiKit.PAPER), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	_toasts.add_child(box)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tw := create_tween()
	tw.tween_interval(5.5)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(box.queue_free)


func _on_subtitle(speaker: Dictionary, line: Dictionary, seconds: float) -> void:
	var who := Game.text(speaker.get("name", {}))
	_subtitle.text = ("%s: " % who if who != "" else "") + Game.text2(line)
	_sub_t = seconds


func big_message(line: Dictionary, color: Color = UiKit.MARIGOLD, seconds: float = 3.5) -> void:
	_big.text = Game.text2(line)
	_big.add_theme_color_override("font_color", color)
	_big.visible = true
	_big_t = seconds


func flash_damage(strength: float) -> void:
	_flash.color.a = clampf(_flash.color.a + strength * 0.45, 0.0, 0.6)


func muzzle_flash() -> void:
	_cross.modulate = Color(1, 0.9, 0.6)
	var tw := create_tween()
	tw.tween_property(_cross, "modulate", Color(1, 1, 1), 0.12)


# --- Map and pause ------------------------------------------------------------------------------------

func _build_map() -> void:
	_map_layer = Control.new()
	_map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_layer.visible = false
	_root.add_child(_map_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.06, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_layer.add_child(bg)
	_map = CityMap.new()
	_map.city = _radar.city
	_map.full = true
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.offset_left = 40
	_map.offset_top = 70
	_map.offset_right = -40
	_map.offset_bottom = -40
	_map_layer.add_child(_map)
	var t := UiKit.label("মানচিত্র · বাম ক্লিকে গন্তব্য, ডান ক্লিকে মুছুন · M বা Esc বন্ধ" if Game.language == "bn" else "Map · left click sets a waypoint, right click clears · M or Esc closes", 22, UiKit.MARIGOLD, true)
	t.offset_left = 40
	t.offset_top = 22
	t.offset_right = 1400
	_map_layer.add_child(t)


func _toggle_map() -> void:
	_map_layer.visible = not _map_layer.visible
	get_tree().paused = _map_layer.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _map_layer.visible else Input.MOUSE_MODE_CAPTURED


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	_root.add_child(_pause)
	var bg := ColorRect.new()
	bg.color = Color(0, 0.03, 0.04, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(bg)
	var col := VBoxContainer.new()
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -300
	col.offset_right = 300
	col.offset_top = -300
	col.offset_bottom = 300
	col.add_theme_constant_override("separation", 10)
	_pause.add_child(col)
	var title := UiKit.label("বিরতি" if Game.language == "bn" else "Paused", 40, UiKit.MARIGOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var obj := UiKit.label("", 20, UiKit.PAPER)
	obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj.name = "Status"
	col.add_child(obj)
	var items := [
		[{"bn": "চালিয়ে যাও", "en": "Resume"}, _toggle_pause],
		[{"bn": "মানচিত্র", "en": "Map"}, _pause_map],
		[{"bn": "গ্রাফিক্স বদলাও", "en": "Change graphics"}, _cycle_quality],
		[{"bn": "রেন্ডার স্কেল", "en": "Render scale"}, _pause_render_scale],
		[{"bn": "ভাষা: বাংলা / English", "en": "Language: Bengali / English"}, _pause_language],
		[{"bn": "কণ্ঠ চালু/বন্ধ", "en": "Voices on/off"}, _pause_voices],
		[{"bn": "মূল মেনু", "en": "Main menu"}, _pause_menu],
	]
	for it in items:
		var b := UiKit.button(Game.text(it[0]), 22)
		b.pressed.connect(it[1])
		col.add_child(b)


func _toggle_pause() -> void:
	_pause.visible = not _pause.visible
	get_tree().paused = _pause.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _pause.visible else Input.MOUSE_MODE_CAPTURED
	var st := _pause.find_child("Status", true, false) as Label
	if st:
		st.text = Game.text2(Missions.status_line()) + "\n" + ("গ্রাফিক্স: %s" if Game.language == "bn" else "Graphics: %s") % String(RenderQuality.NAMES[RenderQuality.saved()])


func _cycle_quality() -> void:
	var atmos: DhakaAtmosphere = Services.atmosphere
	var t := RenderQuality.cycle(get_viewport(), atmos.environment if atmos else null, atmos.sun if atmos else null, atmos.dust if atmos else null)
	toast({"bn": "গ্রাফিক্স: %s" % String(RenderQuality.NAMES[t]), "en": "Graphics: %s" % String(RenderQuality.NAMES[t])})
	var st := _pause.find_child("Status", true, false) as Label
	if st:
		st.text = Game.text2(Missions.status_line()) + "\n" + ("গ্রাফিক্স: %s" if Game.language == "bn" else "Graphics: %s") % String(RenderQuality.NAMES[t])


func _pause_map() -> void:
	_toggle_pause()
	_toggle_map()


func _pause_render_scale() -> void:
	var sc := RenderQuality.cycle_render_scale(get_viewport())
	toast({"bn": "রেন্ডার স্কেল %s%%" % UiKit.bengali_digits(str(int(sc * 100))), "en": "Render scale %d%%" % int(sc * 100)})


func _pause_language() -> void:
	Game.language = "en" if Game.language == "bn" else "bn"
	Game.save_settings()
	toast({"bn": "ভাষা বদলানো হলো (কিছু লেখা পরের বার লোড হলে বদলাবে)।", "en": "Language changed (some text updates on the next load)."})


func _pause_voices() -> void:
	Game.voices = not Game.voices
	Game.save_settings()
	Voice.stop()
	toast({"bn": "কণ্ঠ: %s" % ("চালু" if Game.voices else "বন্ধ"), "en": "Voices: %s" % ("on" if Game.voices else "off")})


func _pause_menu() -> void:
	GameState.save_game()
	Game.to_menu()
