class_name RenderQuality
extends RefCounted
## Four quality tiers for the Forward+ pipeline. Each tier sets the viewport (anti-aliasing, upscaling,
## LOD, shadow atlas), the RenderingServer globals (SSAO / SSIL / SDFGI / volumetric fog quality,
## soft-shadow filters) and switches whole effects in the Environment on or off.
## The choice is saved in user://settings.cfg; the main menu and pause menu can cycle it.

enum Tier { LOW, MEDIUM, HIGH, ULTRA }

const NAMES := ["Low", "Medium", "High", "Ultra"]
const SETTINGS_PATH := "user://settings.cfg"

## What each tier turns on. Budgets assume a 1080p target: Low ~ integrated GPUs, Medium ~ GTX 1060 /
## RX 580, High ~ RTX 2060 / RX 6600, Ultra ~ RTX 3070 and up.
const TIERS := [
	{"sdfgi": false, "ssil": false, "ssao": true, "ssr": false, "vfog": false, "glow": true,
	 "msaa": Viewport.MSAA_DISABLED, "ssaa": Viewport.SCREEN_SPACE_AA_SMAA, "taa": false, "lod": 4.0,
	 "ssao_q": RenderingServer.ENV_SSAO_QUALITY_LOW, "ssil_q": RenderingServer.ENV_SSIL_QUALITY_VERY_LOW, "half": true,
	 "sdfgi_rays": RenderingServer.ENV_SDFGI_RAY_COUNT_8, "sdfgi_frames": RenderingServer.ENV_SDFGI_CONVERGE_IN_30_FRAMES,
	 "vf_size": 48, "vf_depth": 48, "dir_shadow": 2048, "soft": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	 "pos_atlas": 2048, "splits": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "shadow_dist": 80.0,
	 "ssr_q": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED, "gi_half": true, "bicubic": false, "dust": false},
	{"sdfgi": false, "ssil": false, "ssao": true, "ssr": false, "vfog": true, "glow": true,
	 "msaa": Viewport.MSAA_DISABLED, "ssaa": Viewport.SCREEN_SPACE_AA_SMAA, "taa": false, "lod": 2.0,
	 "ssao_q": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "ssil_q": RenderingServer.ENV_SSIL_QUALITY_LOW, "half": true,
	 "sdfgi_rays": RenderingServer.ENV_SDFGI_RAY_COUNT_16, "sdfgi_frames": RenderingServer.ENV_SDFGI_CONVERGE_IN_30_FRAMES,
	 "vf_size": 64, "vf_depth": 64, "dir_shadow": 4096, "soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	 "pos_atlas": 4096, "splits": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "shadow_dist": 120.0,
	 "ssr_q": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED, "gi_half": true, "bicubic": false, "dust": true},
	{"sdfgi": true, "ssil": true, "ssao": true, "ssr": false, "vfog": true, "glow": true,
	 "msaa": Viewport.MSAA_2X, "ssaa": Viewport.SCREEN_SPACE_AA_SMAA, "taa": false, "lod": 1.0,
	 "ssao_q": RenderingServer.ENV_SSAO_QUALITY_HIGH, "ssil_q": RenderingServer.ENV_SSIL_QUALITY_MEDIUM, "half": true,
	 "sdfgi_rays": RenderingServer.ENV_SDFGI_RAY_COUNT_16, "sdfgi_frames": RenderingServer.ENV_SDFGI_CONVERGE_IN_20_FRAMES,
	 "vf_size": 96, "vf_depth": 96, "dir_shadow": 4096, "soft": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
	 "pos_atlas": 4096, "splits": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "shadow_dist": 140.0,
	 "ssr_q": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW, "gi_half": true, "bicubic": true, "dust": true},
	{"sdfgi": true, "ssil": true, "ssao": true, "ssr": true, "vfog": true, "glow": true,
	 "msaa": Viewport.MSAA_4X, "ssaa": Viewport.SCREEN_SPACE_AA_SMAA, "taa": false, "lod": 1.0,
	 "ssao_q": RenderingServer.ENV_SSAO_QUALITY_ULTRA, "ssil_q": RenderingServer.ENV_SSIL_QUALITY_HIGH, "half": false,
	 "sdfgi_rays": RenderingServer.ENV_SDFGI_RAY_COUNT_32, "sdfgi_frames": RenderingServer.ENV_SDFGI_CONVERGE_IN_15_FRAMES,
	 "vf_size": 128, "vf_depth": 128, "dir_shadow": 8192, "soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
	 "pos_atlas": 8192, "splits": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "shadow_dist": 160.0,
	 "ssr_q": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_MEDIUM, "gi_half": false, "bicubic": true, "dust": true},
]


## Forward+ (desktop .exe). The Android build uses the Mobile renderer and the web build uses
## Compatibility (WebGL 2): no SDFGI, SSIL, volumetric fog or FSR there, so those get the Low tier.
static func is_forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


static func apply(tier: int, vp: Viewport, env: Environment, sun: DirectionalLight3D = null, dust: Node3D = null) -> void:
	if not is_forward_plus():
		tier = Tier.LOW
	var t: Dictionary = TIERS[clampi(tier, 0, TIERS.size() - 1)].duplicate()
	if not is_forward_plus():
		t["msaa"] = Viewport.MSAA_DISABLED
		t["ssaa"] = Viewport.SCREEN_SPACE_AA_DISABLED if OS.has_feature("web") else t["ssaa"]
		t["sdfgi"] = false
		t["ssil"] = false
		t["vfog"] = false
		t["ssr"] = false
		t["dir_shadow"] = mini(int(t["dir_shadow"]), 2048)
		t["pos_atlas"] = mini(int(t["pos_atlas"]), 2048)
	vp.msaa_3d = t["msaa"]
	vp.screen_space_aa = t["ssaa"]
	vp.use_taa = t["taa"]
	# Every tier renders at native resolution (the old 67 % FSR upscale was the blur).
	# Render scale is a separate, opt-in performance setting.
	var rs := render_scale()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if rs >= 0.999 or not is_forward_plus() else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = rs
	vp.fsr_sharpness = 0.2
	vp.use_debanding = true
	vp.mesh_lod_threshold = t["lod"]
	vp.positional_shadow_atlas_size = t["pos_atlas"]
	vp.anisotropic_filtering_level = Viewport.ANISOTROPY_8X

	RenderingServer.directional_shadow_atlas_set_size(t["dir_shadow"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(t["soft"])
	RenderingServer.positional_soft_shadow_filter_set_quality(t["soft"])
	RenderingServer.environment_set_ssao_quality(t["ssao_q"], t["half"], 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(t["ssil_q"], t["half"], 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_sdfgi_ray_count(t["sdfgi_rays"])
	RenderingServer.environment_set_sdfgi_frames_to_converge(t["sdfgi_frames"])
	RenderingServer.environment_set_volumetric_fog_volume_size(t["vf_size"], t["vf_depth"])
	RenderingServer.environment_set_volumetric_fog_filter_active(true)
	RenderingServer.environment_set_ssr_roughness_quality(t["ssr_q"])
	RenderingServer.environment_glow_set_use_bicubic_upscale(t["bicubic"])
	RenderingServer.gi_set_use_half_resolution(t["gi_half"])

	if env:
		env.sdfgi_enabled = t["sdfgi"]
		env.ssil_enabled = t["ssil"]
		env.ssao_enabled = t["ssao"]
		env.ssr_enabled = t["ssr"]
		env.volumetric_fog_enabled = t["vfog"]
		env.glow_enabled = t["glow"]
	if sun:
		sun.directional_shadow_mode = t["splits"]
		sun.directional_shadow_max_distance = t["shadow_dist"]
	if dust:
		dust.visible = t["dust"]


## A sensible first guess: integrated GPUs start on Low, everything else on High.
static func detect() -> int:
	if not is_forward_plus():
		return Tier.LOW
	var kind := RenderingServer.get_video_adapter_type()
	if kind == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU or kind == RenderingDevice.DEVICE_TYPE_CPU:
		return Tier.LOW
	return Tier.HIGH


static func saved() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return clampi(int(cfg.get_value("video", "quality", detect())), 0, TIERS.size() - 1)
	return detect()


static func save(tier: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("video", "quality", tier)
	cfg.save(SETTINGS_PATH)


## 1.0 (default, sharp), 0.85 or 0.7 (faster, softer); saved in user://settings.cfg [video] render_scale.
static func render_scale() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return clampf(float(cfg.get_value("video", "render_scale", 1.0)), 0.5, 1.0)
	return 1.0


static func cycle_render_scale(vp: Viewport) -> float:
	var steps := [1.0, 0.85, 0.7]
	var cur := render_scale()
	var idx := 0
	for i in steps.size():
		if absf(float(steps[i]) - cur) < 0.01:
			idx = i
	var next: float = steps[(idx + 1) % steps.size()]
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("video", "render_scale", next)
	cfg.save(SETTINGS_PATH)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if next >= 0.999 or not is_forward_plus() else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = next
	return next


static func apply_saved(vp: Viewport, env: Environment, sun: DirectionalLight3D = null, dust: Node3D = null) -> void:
	apply(saved(), vp, env, sun, dust)


static func cycle(vp: Viewport, env: Environment, sun: DirectionalLight3D = null, dust: Node3D = null) -> int:
	var next := (saved() + 1) % TIERS.size()
	save(next)
	apply(next, vp, env, sun, dust)
	return next
