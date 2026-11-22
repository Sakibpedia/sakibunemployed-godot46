class_name DhakaAtmosphere
extends Node3D
## The look of Dhaka (Godot's equivalent of a tuned URP/HDRP volume stack). Phase 2: crisp daylight,
## haze only in the distance. A polluted procedural sky with a smog band on the horizon, a sun and a
## moon, SDFGI bounce light, SSAO and SSIL in the alleys, light volumetric fog for sun shafts, depth fog
## (no height fog, no depth of field, no bloom wash), ACES tone mapping, auto exposure and a warm/teal grade.
## On the Mobile and Compatibility renderers (Android, web) the unsupported effects are simply off.
##
## Usage (OpenWorld.gd does this):
##   var atmos := DhakaAtmosphere.new(); add_child(atmos)
##   atmos.setup(map_size_m, indoor)        # builds WorldEnvironment, sun, moon, smog volume, dust
##   atmos.set_hour(GameState.hour())   # every game minute or two
##   RenderQuality.apply_saved(get_viewport(), atmos.environment, atmos.sun)
##
## Every value below is the exact configuration; docs/RENDERING.md explains each one.
## World axes: -Z is north, +X is east, so the sun rises over +X and crosses the south (+Z) at noon.

signal hour_applied(hour: float)

const SKY_COVER := "res://art/textures/shared/sky_smog_cover.png"
const SUNRISE := 5.85
const SUNSET := 18.05
const MAX_ELEVATION := 58.0

## A Dhaka day in nine keys. Colours are sRGB. Between keys every value is blended with a smoothstep.
## Haze lives in the distance only: depth fog starts at fog_b metres and reaches fog_max opacity at fog_e.
const KEYS := [
	{"h": 0.0, "sun": Color(0.0, 0.0, 0.0), "sun_e": 0.0, "top": Color(0.03, 0.04, 0.08), "hor": Color(0.2, 0.14, 0.11),
	 "ground": Color(0.08, 0.06, 0.05), "cover": Color(0.4, 0.26, 0.16, 0.45), "fog": Color(0.16, 0.12, 0.1), "fog_b": 40.0, "fog_e": 380.0, "fog_max": 0.7,
	 "vol_d": 0.006, "vol_a": Color(0.6, 0.5, 0.4), "vol_e": Color(0.012, 0.008, 0.004), "exp": 1.25, "amb": 0.45, "sky_e": 0.7, "sat": 0.95},
	{"h": 5.0, "sun": Color(0.0, 0.0, 0.0), "sun_e": 0.0, "top": Color(0.05, 0.06, 0.11), "hor": Color(0.24, 0.18, 0.17),
	 "ground": Color(0.09, 0.07, 0.06), "cover": Color(0.36, 0.28, 0.24, 0.45), "fog": Color(0.2, 0.16, 0.15), "fog_b": 40.0, "fog_e": 380.0, "fog_max": 0.7,
	 "vol_d": 0.007, "vol_a": Color(0.6, 0.52, 0.46), "vol_e": Color(0.008, 0.006, 0.004), "exp": 1.25, "amb": 0.48, "sky_e": 0.72, "sat": 0.95},
	{"h": 5.8, "sun": Color(1.0, 0.6, 0.36), "sun_e": 0.6, "top": Color(0.3, 0.38, 0.55), "hor": Color(0.92, 0.66, 0.48),
	 "ground": Color(0.4, 0.32, 0.26), "cover": Color(1.0, 0.75, 0.6, 0.55), "fog": Color(0.86, 0.68, 0.54), "fog_b": 60.0, "fog_e": 520.0, "fog_max": 0.6,
	 "vol_d": 0.01, "vol_a": Color(0.92, 0.76, 0.62), "vol_e": Color(0.0, 0.0, 0.0), "exp": 1.05, "amb": 0.7, "sky_e": 0.95, "sat": 1.05},
	{"h": 7.5, "sun": Color(1.0, 0.86, 0.68), "sun_e": 1.5, "top": Color(0.46, 0.58, 0.74), "hor": Color(0.8, 0.82, 0.83),
	 "ground": Color(0.46, 0.43, 0.38), "cover": Color(1.0, 0.96, 0.9, 0.4), "fog": Color(0.74, 0.76, 0.76), "fog_b": 90.0, "fog_e": 700.0, "fog_max": 0.5,
	 "vol_d": 0.005, "vol_a": Color(0.9, 0.88, 0.84), "vol_e": Color(0.0, 0.0, 0.0), "exp": 1.0, "amb": 0.9, "sky_e": 1.0, "sat": 1.08},
	{"h": 12.0, "sun": Color(1.0, 0.96, 0.88), "sun_e": 2.0, "top": Color(0.5, 0.62, 0.78), "hor": Color(0.82, 0.84, 0.86),
	 "ground": Color(0.5, 0.48, 0.44), "cover": Color(1.0, 1.0, 1.0, 0.35), "fog": Color(0.74, 0.78, 0.82), "fog_b": 110.0, "fog_e": 800.0, "fog_max": 0.45,
	 "vol_d": 0.004, "vol_a": Color(0.92, 0.92, 0.9), "vol_e": Color(0.0, 0.0, 0.0), "exp": 0.95, "amb": 1.0, "sky_e": 1.0, "sat": 1.08},
	{"h": 16.0, "sun": Color(1.0, 0.88, 0.7), "sun_e": 1.7, "top": Color(0.48, 0.58, 0.72), "hor": Color(0.86, 0.8, 0.72),
	 "ground": Color(0.5, 0.44, 0.36), "cover": Color(1.0, 0.92, 0.8, 0.4), "fog": Color(0.82, 0.76, 0.66), "fog_b": 90.0, "fog_e": 700.0, "fog_max": 0.5,
	 "vol_d": 0.005, "vol_a": Color(0.92, 0.84, 0.72), "vol_e": Color(0.0, 0.0, 0.0), "exp": 1.0, "amb": 0.92, "sky_e": 1.0, "sat": 1.1},
	{"h": 17.3, "sun": Color(1.0, 0.6, 0.3), "sun_e": 1.2, "top": Color(0.3, 0.34, 0.5), "hor": Color(1.0, 0.6, 0.32),
	 "ground": Color(0.5, 0.34, 0.24), "cover": Color(1.0, 0.66, 0.42, 0.55), "fog": Color(0.94, 0.62, 0.4), "fog_b": 70.0, "fog_e": 560.0, "fog_max": 0.6,
	 "vol_d": 0.009, "vol_a": Color(0.96, 0.7, 0.5), "vol_e": Color(0.0, 0.0, 0.0), "exp": 1.05, "amb": 0.75, "sky_e": 1.0, "sat": 1.12},
	{"h": 18.0, "sun": Color(0.95, 0.4, 0.22), "sun_e": 0.3, "top": Color(0.12, 0.13, 0.24), "hor": Color(0.62, 0.32, 0.22),
	 "ground": Color(0.2, 0.12, 0.1), "cover": Color(0.66, 0.36, 0.24, 0.5), "fog": Color(0.42, 0.26, 0.2), "fog_b": 50.0, "fog_e": 420.0, "fog_max": 0.65,
	 "vol_d": 0.008, "vol_a": Color(0.72, 0.52, 0.42), "vol_e": Color(0.006, 0.004, 0.002), "exp": 1.2, "amb": 0.55, "sky_e": 0.85, "sat": 1.0},
	{"h": 19.0, "sun": Color(0.0, 0.0, 0.0), "sun_e": 0.0, "top": Color(0.03, 0.04, 0.08), "hor": Color(0.2, 0.14, 0.11),
	 "ground": Color(0.08, 0.06, 0.05), "cover": Color(0.4, 0.26, 0.16, 0.45), "fog": Color(0.16, 0.12, 0.1), "fog_b": 40.0, "fog_e": 380.0, "fog_max": 0.7,
	 "vol_d": 0.006, "vol_a": Color(0.6, 0.5, 0.4), "vol_e": Color(0.012, 0.008, 0.004), "exp": 1.25, "amb": 0.45, "sky_e": 0.7, "sat": 0.95},
]

var environment: Environment
var world_env: WorldEnvironment
var sky_material: ProceduralSkyMaterial
var camera_attributes: CameraAttributesPractical
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var smog: FogVolume
var dust: GPUParticles3D
var indoor := false
var hour := 12.0
var _sun_elevation := 45.0


func setup(map_size_m: Vector3 = Vector3(80, 30, 60), is_indoor := false) -> void:
	indoor = is_indoor
	_build_environment()
	_build_lights()
	_build_smog(map_size_m)
	_build_dust()
	set_hour(hour)


func _process(_delta: float) -> void:
	# dust motes ride along with whatever camera is active (first person or the Sky lens)
	if dust:
		var cam := get_viewport().get_camera_3d()
		if cam:
			dust.global_position = cam.global_position


# --- Construction ---------------------------------------------------------------------------

func _build_environment() -> void:
	environment = Environment.new()
	var e := environment
	e.background_mode = Environment.BG_SKY
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_curve = 0.15                 # a thin pale band at the horizon, blue overhead
	sky_material.ground_bottom_color = Color(0.12, 0.11, 0.1)
	sky_material.ground_curve = 0.04
	sky_material.ground_energy_multiplier = 0.6
	sky_material.sun_angle_max = 8.0              # a soft halo round the sun
	sky_material.sun_curve = 0.15
	sky_material.use_debanding = true
	if ResourceLoader.exists(SKY_COVER):
		sky_material.sky_cover = load(SKY_COVER)
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	e.sky = sky

	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.85
	e.ambient_light_color = Color(0.62, 0.58, 0.52)
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	e.tonemap_mode = Environment.TONE_MAPPER_ACES  # punchy, saturated daylight
	e.tonemap_white = 6.0

	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 1.6
	e.ssao_power = 1.4
	e.ssao_detail = 0.6
	e.ssao_horizon = 0.06
	e.ssao_sharpness = 0.98
	e.ssao_light_affect = 0.15
	e.ssao_ao_channel_affect = 0.4

	e.ssil_enabled = true
	e.ssil_radius = 6.0
	e.ssil_intensity = 1.1
	e.ssil_sharpness = 0.98
	e.ssil_normal_rejection = 1.0

	e.sdfgi_enabled = true
	e.sdfgi_use_occlusion = true
	e.sdfgi_read_sky_light = not indoor
	e.sdfgi_bounce_feedback = 0.45
	e.sdfgi_cascades = 4
	e.sdfgi_min_cell_size = 0.2
	e.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	e.sdfgi_energy = 1.0
	e.sdfgi_normal_bias = 1.1
	e.sdfgi_probe_bias = 1.1

	e.ssr_enabled = false                         # turned on by the Ultra tier
	e.ssr_max_steps = 48
	e.ssr_fade_in = 0.15
	e.ssr_fade_out = 2.0
	e.ssr_depth_tolerance = 0.2

	e.glow_enabled = true
	e.glow_normalized = false
	e.glow_intensity = 0.3
	e.glow_strength = 1.0
	e.glow_bloom = 0.0                            # no bloom wash: only real highlights glow
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.glow_hdr_threshold = 1.1
	e.glow_hdr_scale = 2.0
	e.glow_hdr_luminance_cap = 12.0
	var levels := [0.0, 0.0, 1.0, 0.8, 1.0, 0.6, 0.3]
	for i in levels.size():
		e.set_glow_level(i, levels[i])

	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH   # haze in the distance only, never in your face
	e.fog_light_energy = 1.0
	e.fog_sun_scatter = 0.2
	e.fog_aerial_perspective = 0.4
	e.fog_sky_affect = 0.15
	e.fog_depth_curve = 1.6
	e.fog_height_density = 0.0

	e.volumetric_fog_enabled = true
	e.volumetric_fog_emission_energy = 1.0
	e.volumetric_fog_gi_inject = 0.3
	e.volumetric_fog_anisotropy = 0.65            # forward scattering: thin shafts toward the sun
	e.volumetric_fog_length = 64.0
	e.volumetric_fog_detail_spread = 2.0
	e.volumetric_fog_ambient_inject = 0.1
	e.volumetric_fog_sky_affect = 0.25
	e.volumetric_fog_temporal_reprojection_enabled = true
	e.volumetric_fog_temporal_reprojection_amount = 0.9

	e.adjustment_enabled = true
	e.adjustment_brightness = 1.0
	e.adjustment_contrast = 1.06
	e.adjustment_color_correction = _grade()

	camera_attributes = CameraAttributesPractical.new()
	camera_attributes.auto_exposure_enabled = true
	camera_attributes.auto_exposure_scale = 0.4
	camera_attributes.auto_exposure_speed = 0.6
	camera_attributes.auto_exposure_min_sensitivity = 100.0
	camera_attributes.auto_exposure_max_sensitivity = 400.0
	camera_attributes.dof_blur_far_enabled = false     # no depth-of-field blur
	camera_attributes.dof_blur_far_distance = 90.0
	camera_attributes.dof_blur_far_transition = 60.0
	camera_attributes.dof_blur_amount = 0.06

	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = environment
	world_env.camera_attributes = camera_attributes
	add_child(world_env)


## A 1D grade applied per channel: shadows lean teal, highlights lean warm, like smoggy daylight.
func _grade() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(0.0, 0.012, 0.02))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(1.0, 0.985, 0.95))
	g.add_point(0.25, Color(0.235, 0.255, 0.26))
	g.add_point(0.5, Color(0.5, 0.5, 0.49))
	g.add_point(0.78, Color(0.8, 0.78, 0.74))
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t


func _build_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_indirect_energy = 1.0
	sun.light_volumetric_fog_energy = 1.0
	sun.light_angular_distance = 0.5              # crisp shadow edges
	sun.light_specular = 0.6
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.0
	sun.shadow_opacity = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_fade_start = 0.85
	sun.directional_shadow_pancake_size = 40.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.6, 0.68, 0.85)
	moon.light_energy = 0.0
	moon.light_volumetric_fog_energy = 0.8
	moon.light_angular_distance = 0.5
	moon.light_specular = 0.3
	moon.shadow_enabled = true
	moon.shadow_blur = 2.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 80.0
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.rotation_degrees = Vector3(-40.0, 220.0, 0.0)
	add_child(moon)


## Low street smog that thickens toward the ground (vehicle exhaust, brick-kiln smoke, dust).
func _build_smog(map_size_m: Vector3) -> void:
	var fm := FogMaterial.new()
	fm.density = 0.004 if not indoor else 0.002
	fm.albedo = Color(0.8, 0.76, 0.68)
	fm.emission = Color(0, 0, 0)
	fm.height_falloff = 0.25
	fm.edge_fade = 0.3
	smog = FogVolume.new()
	smog.name = "StreetSmog"
	smog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	smog.size = Vector3(map_size_m.x + 40.0, 6.0, map_size_m.z + 40.0)
	smog.material = fm
	smog.position = Vector3(map_size_m.x * 0.5, 2.0, map_size_m.z * 0.5)
	add_child(smog)


## Dust motes hanging in the air round the camera; lit by the sun they sparkle in the shafts.
func _build_dust() -> void:
	dust = GPUParticles3D.new()
	dust.name = "DustMotes"
	dust.amount = 240
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = false
	dust.visibility_aabb = AABB(Vector3(-14, -6, -14), Vector3(28, 12, 28))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(12, 5, 12)
	pm.direction = Vector3(0.3, 0.1, 0.2)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.gravity = Vector3(0, -0.015, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 6.0
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var alpha := Gradient.new()
	alpha.set_color(0, Color(1, 1, 1, 0))
	alpha.set_color(1, Color(1, 1, 1, 0))
	alpha.add_point(0.2, Color(1, 1, 1, 1))
	alpha.add_point(0.8, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = alpha
	pm.color_ramp = ramp
	dust.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.95, 0.9, 0.8, 0.35)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	quad.material = m
	dust.draw_pass_1 = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)


# --- Time of day ------------------------------------------------------------------------------

func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	var k := _sample(hour)
	var t := clampf((hour - SUNRISE) / (SUNSET - SUNRISE), 0.0, 1.0)
	_sun_elevation = MAX_ELEVATION * sin(t * PI) if (hour >= SUNRISE and hour <= SUNSET) else -10.0
	var azimuth := lerpf(108.0, 252.0, t)
	var dir := _direction(azimuth, maxf(_sun_elevation, 1.5))
	sun.basis = Basis.looking_at(-dir, Vector3.UP)
	var above := smoothstep(-2.0, 4.0, _sun_elevation)
	sun.light_color = k.sun
	sun.light_energy = float(k.sun_e) * above
	sun.visible = sun.light_energy > 0.01
	moon.light_energy = 0.12 * (1.0 - above)
	moon.visible = moon.light_energy > 0.01

	sky_material.sky_top_color = k.top
	sky_material.sky_horizon_color = k.hor
	sky_material.ground_horizon_color = k.ground
	sky_material.sky_energy_multiplier = float(k.sky_e)
	sky_material.sky_cover_modulate = k.cover

	var e := environment
	e.ambient_light_energy = float(k.amb) * (0.6 if indoor else 1.0)
	e.tonemap_exposure = float(k.exp)
	e.adjustment_saturation = float(k.sat)
	e.fog_light_color = k.fog
	e.fog_density = float(k.fog_max) * (0.3 if indoor else 1.0)
	e.fog_depth_begin = float(k.fog_b)
	e.fog_depth_end = float(k.fog_e)
	e.volumetric_fog_density = float(k.vol_d) * (0.4 if indoor else 1.0)
	e.volumetric_fog_albedo = k.vol_a
	e.volumetric_fog_emission = k.vol_e
	hour_applied.emit(hour)


## 0 by day, 1 by night; street lamps and shop lights follow this.
func lamp_amount() -> float:
	return 1.0 - smoothstep(-4.0, 6.0, _sun_elevation)


func sun_elevation() -> float:
	return _sun_elevation


func _direction(azimuth_deg: float, elevation_deg: float) -> Vector3:
	var a := deg_to_rad(azimuth_deg)
	var el := deg_to_rad(elevation_deg)
	return Vector3(sin(a) * cos(el), sin(el), -cos(a) * cos(el)).normalized()


func _sample(h: float) -> Dictionary:
	var keys: Array = KEYS
	var last: Dictionary = keys[keys.size() - 1]
	var k0: Dictionary = keys[0]
	var k1: Dictionary = keys[1]
	var span := 0.0
	var f := 0.0
	if h >= float(last.h):
		k0 = last
		k1 = keys[0]
		span = 24.0 - float(last.h)
		f = (h - float(last.h)) / maxf(span, 0.001)
	else:
		for i in keys.size() - 1:
			if h >= float(keys[i].h) and h < float(keys[i + 1].h):
				k0 = keys[i]
				k1 = keys[i + 1]
				f = (h - float(k0.h)) / maxf(float(k1.h) - float(k0.h), 0.001)
				break
	f = smoothstep(0.0, 1.0, f)
	var out := {}
	for key in k0:
		if key == "h":
			continue
		var a = k0[key]
		var b = k1[key]
		out[key] = a.lerp(b, f) if a is Color else lerpf(float(a), float(b), f)
	return out
