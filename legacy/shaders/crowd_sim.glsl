#[compute]
#version 450
// GPU crowd for "S M Nazmuz Sakib is unemployed" (design doc Sections 11.2 and 14).
// One thread per agent. Agents follow a 1 m flow field baked from the navmesh,
// flee panic sources and write a MultiMesh transform (12 floats) for drawing.

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// a: x, z, vx, vz      b: base speed, panic 0..1, height y, phase
layout(set = 0, binding = 0, std430) restrict buffer Agents {
	vec4 data[];
} agents;

// One cell per metre: dir.x, dir.z, walkable (0 or 1), unused
layout(set = 0, binding = 1, std430) restrict readonly buffer Field {
	vec4 cells[];
} field;

// p0: origin x, origin z, cell size, dt
// p1: grid w, grid h, agent count, panic source count
// p2..p17: panic sources (x, z, radius, strength)
layout(set = 0, binding = 2, std430) restrict readonly buffer Params {
	vec4 p[];
} params;

layout(set = 0, binding = 3, std430) restrict writeonly buffer Transforms {
	float t[];
} transforms;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

vec4 cell_at(vec2 pos, vec2 origin, float cs, int w, int h) {
	ivec2 c = ivec2(floor((pos - origin) / cs));
	if (c.x < 0 || c.y < 0 || c.x >= w || c.y >= h) {
		return vec4(0.0);
	}
	return field.cells[c.y * w + c.x];
}

void main() {
	uint i = gl_GlobalInvocationID.x;
	uint count = uint(params.p[1].z);
	if (i >= count) {
		return;
	}
	vec2 origin = params.p[0].xy;
	float cs = params.p[0].z;
	float dt = params.p[0].w;
	int w = int(params.p[1].x);
	int h = int(params.p[1].y);
	int sources = int(params.p[1].w);

	vec4 a = agents.data[i * 2u];
	vec4 b = agents.data[i * 2u + 1u];
	vec2 pos = a.xy;
	vec2 vel = a.zw;
	float speed = b.x;
	float panic = b.y;

	vec4 here = cell_at(pos, origin, cs, w, h);
	vec2 desired = here.xy * speed;

	// Panic: flee every source in range; panic decays when none is near.
	float fear = 0.0;
	for (int s = 0; s < sources && s < 16; s++) {
		vec4 src = params.p[2 + s];
		vec2 away = pos - src.xy;
		float d = max(length(away), 0.5);
		if (d < src.z) {
			float k = (1.0 - d / src.z) * src.w;
			desired += normalize(away) * k;
			fear = max(fear, k / max(src.w, 0.001));
		}
	}
	panic = clamp(max(panic - dt * 0.1, fear), 0.0, 1.0);
	desired *= 1.0 + panic * 1.5;

	// A little per-agent wander so lanes do not look like conveyor belts.
	float ph = b.w + dt;
	desired += vec2(hash(float(i) + floor(ph)), hash(float(i) * 1.7 + floor(ph))) * 0.3 - 0.15;

	vel = mix(vel, desired, 1.0 - exp(-dt * 4.0));
	vec2 next = pos + vel * dt;
	if (cell_at(next, origin, cs, w, h).z < 0.5) {
		vel = -vel * 0.3;   // bounce off unwalkable cells
		next = pos;
	}

	agents.data[i * 2u] = vec4(next, vel);
	agents.data[i * 2u + 1u] = vec4(speed, panic, b.z, ph);

	// MultiMesh 3D transform: three rows of a 3x4 matrix, yaw only.
	float yaw = (length(vel) > 0.05) ? atan(vel.x, vel.y) : 0.0;
	float c = cos(yaw);
	float sn = sin(yaw);
	uint o = i * 12u;
	transforms.t[o + 0u] = c;   transforms.t[o + 1u] = 0.0; transforms.t[o + 2u] = sn;  transforms.t[o + 3u] = next.x;
	transforms.t[o + 4u] = 0.0; transforms.t[o + 5u] = 1.0; transforms.t[o + 6u] = 0.0; transforms.t[o + 7u] = b.z;
	transforms.t[o + 8u] = -sn; transforms.t[o + 9u] = 0.0; transforms.t[o + 10u] = c;  transforms.t[o + 11u] = next.y;
}
