class_name OpenWorld
extends Node3D
## The game world: loads the city, builds it, lights it, puts Sakib in it and starts every system.
## Order (docs/ARCHITECTURE.md 4): CityData, ProceduralDhaka, DhakaAtmosphere, Player, HUD,
## pedestrians, traffic, posters, police heat, the night rule; then registers them all in Services
## (dependency injection) and hands the world to the mission director.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

var city: CityData
var builder: ProceduralDhaka
var atmosphere: DhakaAtmosphere
var player: Player
var hud: HUD
var peds: PedestrianSystem
var traffic: TrafficSystem
var posters: PosterSystem
var heat: HeatSystem
var ghosts: GhostDirector
var interiors: BuildingInteriorSystem
var _power := PackedFloat32Array([1, 1, 1, 1, 1])
var _autosave_t := 120.0
var _light_vis_t := 0.0
var _loading: CanvasLayer


func _ready() -> void:
	_show_loading()
	await get_tree().process_frame
	await get_tree().process_frame
	Services.clear()
	city = CityData.new()
	if not city.load_city():
		push_error("No city data. Run tools/make_city.py")
		return
	Services.city = city
	Services.world = self
	builder = ProceduralDhaka.new()
	builder.name = "City"
	add_child(builder)
	builder.build(city)
	atmosphere = DhakaAtmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.setup(Vector3(city.width, 40.0, city.height), false)
	RenderQuality.apply_saved(get_viewport(), atmosphere.environment, atmosphere.sun, atmosphere.dust)
	Services.atmosphere = atmosphere

	peds = PedestrianSystem.new()
	peds.name = "People"
	add_child(peds)
	Services.peds = peds

	player = Player.new()
	player.name = "Sakib"
	add_child(player)
	Services.player = player
	if GameState.has_position:
		player.global_position = GameState.player_position + Vector3(0, 0.3, 0)
		player.rotation.y = GameState.player_rotation
		player.yaw = GameState.player_rotation
	else:
		player.global_position = city.spawn_point() + Vector3(0, 0.3, 0)

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(city)
	Services.hud = hud
	player.interact_target_changed.connect(hud.set_prompt)
	if Game.touch_mode:
		var touch := TouchControls.new()
		touch.player = player
		add_child(touch)

	peds.setup(city, player)
	traffic = TrafficSystem.new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.setup(city, player)
	Services.traffic = traffic
	posters = PosterSystem.new()
	posters.name = "Posters"
	add_child(posters)
	posters.setup(city)
	Services.posters = posters
	heat = HeatSystem.new()
	heat.name = "Heat"
	add_child(heat)
	heat.setup(player, peds, city)
	Services.heat = heat
	ghosts = GhostDirector.new()
	ghosts.name = "Ghosts"
	add_child(ghosts)
	ghosts.setup(city, player, atmosphere)
	Services.ghosts = ghosts
	ghosts.power_changed.connect(func(_d: String, _on: bool) -> void: _sync_power())
	Services.crime.connect(_on_crime)

	# Real, walkable building shells.  Landmarks are built once; ordinary buildings stream in when
	# the player opens their front door.  This runs after the player exists so interiors can cull
	# their lights and build around him.
	interiors = BuildingInteriorSystem.new()
	interiors.name = "Interiors"
	add_child(interiors)
	interiors.setup(city, builder, player)
	Services.interiors = interiors

	Services.register("builder", builder)
	Missions.attach_world(self)
	atmosphere.set_hour(GameState.hour())
	GameState.time_changed.connect(func(h: float) -> void: atmosphere.set_hour(h))
	_loading.queue_free()


func _show_loading() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 90
	add_child(_loading)
	var bg := ColorRect.new()
	bg.color = UiKit.INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	var l := UiKit.label("যাত্রাবাড়ী তৈরি হচ্ছে... দনিয়া · সোনটেক · কাজলা · জুরাইন", 30, UiKit.MARIGOLD, true)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.add_child(l)


func _sync_power() -> void:
	if ghosts != null:
		_power = ghosts.power


func _on_crime(kind: String, pos: Vector3, by_player: bool) -> void:
	if not by_player:
		return
	GameState.log_event("shooting" if kind in ["shooting", "murder"] else kind, city.district_id_at(pos))
	for c in get_tree().get_nodes_in_group(&"citizens"):
		var cz := c as Citizen
		if cz != null and cz.is_alive() and cz.global_position.distance_to(pos) < 30.0:
			cz.ai.notify_crime(kind, pos)


func _process(delta: float) -> void:
	if player == null or builder == null or atmosphere == null:
		return
	var night := atmosphere.lamp_amount()
	if ghosts != null:
		_power = ghosts.power
	builder.update_lamps(delta, player.global_position, night, _power)
	_light_vis_t -= delta
	if _light_vis_t <= 0.0:
		_light_vis_t = 0.5
		var p := player.global_position
		for l in builder.interior_lights:
			if l == null or not is_instance_valid(l):
				continue
			l.visible = l.global_position.distance_to(p) < 60.0
	_autosave_t -= delta
	if _autosave_t <= 0.0:
		_autosave_t = 180.0
		if Missions.active.is_empty():
			GameState.save_game()
