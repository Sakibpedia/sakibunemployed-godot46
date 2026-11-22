// Dhaka facade: one shader draws every apartment block, shophouse and office in the city from a
// plain box (MultiMesh instance). It paints, per face and in metres:
//   floors and floor bands every `storey` metres (from world Y, so boxes may start above ground),
//   bays about 3.2 m wide, each with a window: aluminium frame, dark glass, steel grille bars
//   (as in the photos: 1.5 x 1.2 m windows, sill at 0.9 m, grilles everywhere),
//   an accent stripe bay with glass blocks (the coloured stair cores seen from the roof photos),
//   shop shutters / open shop fronts on the ground floor of the front face,
//   damp streaks under windows and street grime at the bottom,
//   and at night some windows lit by tube lights or warm bulbs, dark during load-shedding.
// INSTANCE_CUSTOM: x = storey height, y = stripe bay (-1 none), z = flags (1 shop, 2 old, 4*power group), w = seed
// COLOR = paint colour.  Global uniforms: dhaka_night (0 day .. 1 night), dhaka_power_a/b (1 on, 0 cut).
// Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float dhaka_night;
global uniform vec4 dhaka_power_a;
global uniform float dhaka_power_b;

uniform sampler2D plaster_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grime_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float bay_width = 3.2;
uniform float lit_fraction : hint_range(0.0, 1.0) = 0.45;

varying vec3 v_local;
varying vec3 v_size;
varying vec3 v_lnormal;
varying vec3 v_world;
varying vec4 v_custom;
varying vec4 v_color;

const vec3 ACCENTS[6] = vec3[](vec3(0.6, 0.12, 0.12), vec3(0.72, 0.2, 0.18), vec3(0.18, 0.32, 0.6),
	vec3(0.2, 0.45, 0.62), vec3(0.5, 0.16, 0.3), vec3(0.35, 0.35, 0.38));

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_local = VERTEX;
	v_lnormal = NORMAL;
	v_size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_custom = INSTANCE_CUSTOM;
	v_color = COLOR;
}

void fragment() {
	vec3 n = normalize(v_lnormal);
	float storey = max(v_custom.x, 2.4);
	float seed = v_custom.w;
	int flags = int(v_custom.z + 0.5);
	bool has_shop = (flags & 1) != 0;
	bool old = (flags & 2) != 0;
	int group = (flags >> 2) & 7;
	float power = group < 4 ? dhaka_power_a[group] : dhaka_power_b;
	vec3 paint = v_color.rgb;

	// roof
	if (n.y > 0.5) {
		vec2 ruv = v_world.xz * 0.4;
		float stain = texture(grime_tex, v_world.xz * 0.05).r;
		ALBEDO = vec3(0.55, 0.54, 0.51) * (0.75 + 0.35 * texture(plaster_tex, ruv).r) * (0.8 + 0.3 * stain);
		ROUGHNESS = 0.92;
	} else if (n.y < -0.5) {
		ALBEDO = vec3(0.3);
		ROUGHNESS = 1.0;
	} else {
	// Godot 4 spatial shaders do not allow `return` in fragment(), so the wall work lives in
	// the else branch instead of early-outs.

	// face coordinates in metres
	float width;
	float u;
	if (abs(n.x) > 0.5) {
		width = v_size.z;
		u = (v_local.z + 0.5) * v_size.z;
		if (n.x < 0.0) { u = width - u; }
	} else {
		width = v_size.x;
		u = (v_local.x + 0.5) * v_size.x;
		if (n.z < 0.0) { u = width - u; }
	}
	bool front = n.z > 0.5;
	float y = v_world.y;
	float fl = floor(y / storey);
	float fy = fract(y / storey);
	float nb = max(1.0, floor(width / bay_width + 0.5));
	float bu_all = u / width * nb;
	float bay = floor(bu_all);
	float bu = fract(bu_all);
	float stripe_bay = v_custom.y;
	bool stripe = stripe_bay >= 0.0 && abs(bay - min(stripe_bay, nb - 1.0)) < 0.5 && abs(n.z) > 0.5;

	// wall: paint over plaster texture, floor bands, damp, street grime
	vec3 tex = texture(plaster_tex, vec2(u, y) / 2.5).rgb;
	vec3 wall = paint * (0.7 + 0.42 * tex);
	float band = smoothstep(0.035, 0.0, fy) + smoothstep(0.965, 1.0, fy);
	wall = mix(wall, wall * 0.78, band * 0.8);
	if (stripe) {
		wall = ACCENTS[int(seed * 5.99)] * (0.8 + 0.3 * tex.r);
	}
	float streak = texture(grime_tex, vec2(u * 0.11 + seed * 7.0, y * 0.018)).g;
	float damp = smoothstep(0.5, 0.85, streak) * (old ? 0.5 : 0.22);
	wall *= 1.0 - damp;
	wall *= mix(0.72, 1.0, smoothstep(0.0, 1.4, y));
	vec3 albedo = wall;
	float rough = old ? 0.95 : 0.86;
	float metal = 0.0;
	vec3 emit = vec3(0.0);

	bool ground_shop = has_shop && front && fl < 0.5;
	if (ground_shop) {
		// shop front: shutter box, a sign band is separate geometry
		float sx = abs(bu - 0.5);
		if (fy < 0.78 && sx < 0.46) {
			float open_day = 1.0 - dhaka_night;
			float shutter = step(0.5, fract(fy * 34.0)) * 0.08;
			vec3 shut = vec3(0.42, 0.44, 0.45) * (0.9 + shutter);
			float shelves = step(0.5, fract(fy * 6.0)) * 0.3;
			vec3 goods = mix(vec3(0.12, 0.1, 0.09), vec3(0.7, 0.4, 0.2) * hash(vec2(bay, seed)), shelves);
			albedo = mix(shut, goods, open_day);
			rough = mix(0.5, 0.9, open_day);
			metal = mix(0.6, 0.0, open_day);
			emit = vec3(1.0, 0.9, 0.7) * 0.6 * open_day * smoothstep(0.2, 0.0, fy - 0.5) * 0.2;
		}
	} else if (!stripe) {
		// window: 1.5 x 1.2 m centred in the bay, sill at 0.9 m
		float wx = abs(bu - 0.5) * (width / nb);   // metres from the bay centre
		float wy = fy * storey;
		float in_w = step(wx, 0.75) * step(0.9, wy) * step(wy, 2.1);
		float frame = in_w * (1.0 - step(wx, 0.7) * step(0.95, wy) * step(wy, 2.05));
		// concrete sunshade (chajja) over every window and a sill under it, as on the Sontek blocks
		float chajja = step(wx, 0.95) * step(2.12, wy) * step(wy, 2.3);
		float sill = step(wx, 0.85) * step(0.8, wy) * step(wy, 0.9);
		if (chajja + sill > 0.5) {
			albedo = mix(paint * 0.9, vec3(0.78, 0.77, 0.74), 0.5) * (0.8 + 0.3 * tex.r);
			rough = 0.92;
		}
		if (in_w > 0.5) {
			float h = hash(vec2(bay + seed * 17.0, fl));
			vec3 glass = vec3(0.12, 0.16, 0.2) + 0.05 * h;
			glass *= mix(1.0, 0.5, smoothstep(1.7, 2.08, wy));   // the sunshade's shadow on the glass
			float curtain = step(0.6, h);
			glass = mix(glass, vec3(0.5, 0.2 + 0.3 * h, 0.2) * 0.45, curtain * 0.6);
			float bars = step(0.86, fract(wx * 8.0 + 0.1));
			albedo = mix(glass, vec3(0.08, 0.08, 0.09), bars);
			rough = mix(0.08, 0.5, bars);
			metal = bars * 0.6;
			float lit = step(h, lit_fraction) * dhaka_night * power;
			vec3 lamp = mix(vec3(1.0, 0.82, 0.55), vec3(0.85, 0.95, 1.0), step(0.5, fract(h * 13.0)));
			emit = lamp * lit * 2.2 * (1.0 - bars);
			if (frame > 0.5) {
				albedo = vec3(0.82, 0.83, 0.82);
				rough = 0.4;
				metal = 0.3;
				emit = vec3(0.0);
			}
		}
	} else {
		// glass blocks on the stair core
		vec2 gb = fract(vec2(u, y) / 0.2);
		float block = step(0.1, gb.x) * step(0.1, gb.y);
		float in_core = step(0.25, abs(bu - 0.5) * -1.0 + 0.5) * step(0.25, fy) * step(fy, 0.8);
		albedo = mix(albedo, vec3(0.62, 0.72, 0.74) * (0.8 + 0.2 * block), in_core);
		emit += vec3(0.6, 0.75, 0.8) * in_core * dhaka_night * power * 0.5;
	}

	// an exposed drain pipe down one side wall (photos: exposed plumbing everywhere)
	if (abs(n.x) > 0.5) {
		float pu = (0.2 + 0.6 * fract(seed * 13.7)) * width;
		float pd = abs(u - pu);
		if (pd < 0.07) {
			albedo = vec3(0.32, 0.33, 0.34) * (0.8 + 0.4 * smoothstep(0.07, 0.0, pd));
			rough = 0.45;
			metal = 0.15;
			emit = vec3(0.0);
		}
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
	}
}
