// Roads: cracked asphalt (world-space, so long roads never stretch the texture) with paint
// markings from the strip's UV: UV.x runs 0..1 across the road, UV.y is metres along it.
// COLOR.r = kind (0 lane, 0.5 main road, 1 highway), COLOR.g = width / 40 m.
// Highways get edge lines and a double centre line; main roads a dashed centre line; lanes none,
// just dust and patching. Wet patches stay darker under the night lamps.
// Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grime_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tile_m = 4.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wuv = v_world.xz / tile_m;
	vec3 base = texture(asphalt_tex, wuv).rgb;
	vec3 orm = texture(asphalt_orm, wuv).rgb;
	float kind = COLOR.r;
	float width = COLOR.g * 40.0;
	float across = UV.x * width;               // metres from the left edge
	float along = UV.y;
	float centre = abs(across - width * 0.5);
	float paint = 0.0;
	vec3 paint_col = vec3(0.92, 0.92, 0.88);
	if (kind > 0.75) {
		// highway: double yellow centre, white edge lines, dashed lane lines
		paint += step(centre, 0.32) * step(0.12, centre);
		paint_col = mix(paint_col, vec3(0.95, 0.78, 0.2), step(centre, 0.4));
		paint += step(abs(across - 0.6), 0.1) + step(abs(across - (width - 0.6)), 0.1);
		float lane_off = abs(centre - width * 0.25);
		paint += step(lane_off, 0.08) * step(0.5, fract(along / 9.0));
	} else if (kind > 0.25) {
		paint += step(centre, 0.07) * step(0.55, fract(along / 6.0));
	}
	// zebra crossing every 160 m on main roads and highways
	if (kind > 0.25) {
		float z = fract(along / 160.0) * 160.0;
		float zebra = step(z, 4.0) * step(0.5, fract(across / 0.9));
		paint = max(paint, zebra);
	}
	paint = clamp(paint, 0.0, 1.0);
	float worn = texture(grime_tex, v_world.xz * 0.08).b;
	paint *= smoothstep(0.15, 0.55, worn);
	float dust = smoothstep(0.42, 0.5, abs(UV.x - 0.5)) * (kind < 0.25 ? 0.6 : 0.3);
	vec3 col = mix(base, paint_col, paint);
	col = mix(col, vec3(0.5, 0.46, 0.4), dust);
	float repair = smoothstep(0.62, 0.66, texture(grime_tex, v_world.xz * 0.012).r);
	col = mix(col, col * 0.7, repair * 0.6);
	ALBEDO = col;
	ROUGHNESS = clamp(mix(orm.g, 0.7, paint) + dust * 0.1 - repair * 0.15, 0.3, 1.0);
	AO = orm.r;
}
