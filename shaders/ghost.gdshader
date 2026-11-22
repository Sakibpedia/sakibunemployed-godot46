// Ghosts (bhoot): a pale, see-through body that fades out below the knees, with a fresnel rim, a
// slow shimmer that drifts upward, and a flicker when hit by the torch (hurt uniform). At dawn
// `burn` rises from 0 to 1 and the body chars and dissolves from the feet up.
// Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 tint : source_color = vec4(0.62, 0.86, 0.95, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.9;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform float base_height = 0.0;   // world Y of the feet

varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += NORMAL * 0.015 * sin(TIME * 3.0 + VERTEX.y * 9.0);
}

void fragment() {
	float h = v_world.y - base_height;
	float legs = smoothstep(0.15, 0.75, h);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float shimmer = vnoise(vec2(v_world.x * 3.0 + v_world.z * 2.0, h * 4.0 - TIME * 1.4));
	float flicker = 1.0 - hurt * (0.5 + 0.5 * sin(TIME * 60.0));
	float dissolve = step(burn * 2.2, h + shimmer * 0.4);
	float a = (0.18 + fres * 0.9) * (0.6 + 0.5 * shimmer) * legs * flicker * dissolve * strength;
	vec3 col = tint.rgb;
	col = mix(col, vec3(1.0, 0.45, 0.15), burn);
	ALBEDO = col * a;
}
