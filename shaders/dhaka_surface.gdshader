// Dhaka surface: triplanar, world-space PBR for everything built from boxes (brick, plaster, concrete,
// asphalt, tin, awnings, tiles). No UVs needed, so LevelBuilder's MultiMesh boxes of any size texture
// correctly. Layered on top, by world position and facing:
//   - macro variation from grime_tex, so a long facade does not show the same tile twice in a row;
//   - street grime splashed up the first metre of every wall;
//   - soot runs streaking down vertical faces;
//   - dust settling on anything that faces up.
// The MultiMesh instance colour arrives as COLOR and tints the texture by tint_strength (plaster takes
// the facade colour, brick barely changes).
// Normal maps are OpenGL style (green up). Triplanar normals use Ben Golus's whiteout blend in world
// space, then convert to view space for Godot's lighting.
// Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grime_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms surface;
uniform float tile_m = 2.0;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.2;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_scale : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_bias : hint_range(-0.5, 0.5) = 0.0;
uniform float blend_sharpness : hint_range(1.0, 16.0) = 6.0;
uniform float macro_variation : hint_range(0.0, 1.0) = 0.25;

group_uniforms weathering;
uniform float grime_height = 1.2;
uniform float grime_strength : hint_range(0.0, 1.0) = 0.35;
uniform float soot_strength : hint_range(0.0, 1.0) = 0.25;
uniform float dust_strength : hint_range(0.0, 1.0) = 0.2;
uniform vec3 grime_color : source_color = vec3(0.17, 0.15, 0.12);
uniform vec3 dust_color : source_color = vec3(0.58, 0.53, 0.45);

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 v_tint;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_tint = COLOR;
}

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(blend_sharpness));
	return w / max(w.x + w.y + w.z, 0.0001);
}

// Two-channel friendly: Godot may store normal maps as RGTC, so rebuild z.
vec3 unpack_normal(vec4 t) {
	vec3 n;
	n.xy = (t.xy * 2.0 - 1.0) * normal_strength;
	n.z = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0001));
	return n;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 bw = tri_weights(n);
	vec3 p = w_pos / tile_m;
	// image "up" always points to world up (or +Z on the floor), so soot runs run downwards
	vec2 uv_x = vec2(p.z, -p.y);
	vec2 uv_y = vec2(p.x, -p.z);
	vec2 uv_z = vec2(p.x, -p.y);

	vec4 alb = texture(albedo_tex, uv_x) * bw.x + texture(albedo_tex, uv_y) * bw.y + texture(albedo_tex, uv_z) * bw.z;
	vec3 orm = (texture(orm_tex, uv_x) * bw.x + texture(orm_tex, uv_y) * bw.y + texture(orm_tex, uv_z) * bw.z).rgb;

	vec3 tx = unpack_normal(texture(normal_tex, uv_x));
	vec3 ty = unpack_normal(texture(normal_tex, uv_y));
	vec3 tz = unpack_normal(texture(normal_tex, uv_z));
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	vec3 wn = normalize(tx.zyx * bw.x + ty.xzy * bw.y + tz.xyz * bw.z);

	vec4 macro = texture(grime_tex, w_pos.xz * 0.013 + vec2(w_pos.y * 0.007));
	vec3 base = alb.rgb * mix(vec3(1.0), v_tint.rgb, tint_strength);
	base *= mix(1.0, 0.8 + 0.4 * macro.r, macro_variation);

	float vertical = 1.0 - abs(n.y);
	float ground = 1.0 - smoothstep(0.0, grime_height, w_pos.y);
	float grime = ground * grime_strength * vertical * (0.6 + 0.4 * macro.a);
	float streak = texture(grime_tex, vec2(dot(w_pos.xz, vec2(0.37, 0.61)) * 0.35, w_pos.y * 0.025)).g;
	float soot = smoothstep(0.55, 0.85, streak) * soot_strength * vertical;
	float dust = smoothstep(0.55, 0.95, n.y) * dust_strength * (0.5 + 0.5 * texture(grime_tex, w_pos.xz * 0.21).b);

	base = mix(base, base * grime_color * 2.2, clamp(grime + soot, 0.0, 0.85));
	base = mix(base, dust_color, dust);

	ALBEDO = base;
	ROUGHNESS = clamp(orm.g + roughness_bias + grime * 0.15 + dust * 0.3 - soot * 0.1, 0.04, 1.0);
	METALLIC = orm.b * metallic_scale * (1.0 - dust);
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.25;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
