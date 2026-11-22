extends Node
## GPU crowd (design doc Sections 11.2 and 14): up to 2,500 agents on a compute shader,
## drawn with one MultiMesh. Runs at 30 Hz on a local RenderingDevice; results are read
## back one tick later so the CPU never waits on the GPU.

const SHADER_PATH := "res://shaders/crowd_sim.glsl"
const MAX_AGENTS := 2500
const MAX_PANIC_SOURCES := 16
const SIM_HZ := 30.0
const CELL := 1.0

var enabled := false
var agent_count := 0

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _agents_buf: RID
var _field_buf: RID
var _params_buf: RID
var _xform_buf: RID
var _uniform_set: RID
var _mmi: MultiMeshInstance3D
var _origin := Vector2.ZERO
var _grid := Vector2i(128, 128)
var _panic: Array[Vector4] = []
var _accum := 0.0
var _in_flight := false


func _ready() -> void:
	_rd = RenderingServer.create_local_rendering_device()
	if _rd == null:
		push_warning("No RenderingDevice (Compatibility renderer?); GPU crowd disabled")
		return
	var file := load(SHADER_PATH) as RDShaderFile
	if file == null:
		push_warning("Crowd shader missing")
		return
	_shader = _rd.shader_create_from_spirv(file.get_spirv())
	_pipeline = _rd.compute_pipeline_create(_shader)
	enabled = true


## Spawn agents inside the current grid. Call after refresh_flow_field().
func spawn(count: int, parent: Node3D, mesh: Mesh, ground_y: float = 0.0) -> void:
	if not enabled:
		return
	agent_count = mini(count, MAX_AGENTS)
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldState.save_seed
	var a := PackedFloat32Array()
	a.resize(agent_count * 8)
	for i in agent_count:
		a[i * 8 + 0] = _origin.x + rng.randf() * _grid.x * CELL
		a[i * 8 + 1] = _origin.y + rng.randf() * _grid.y * CELL
		a[i * 8 + 4] = rng.randf_range(0.9, 1.4)   # walking speed, m/s
		a[i * 8 + 6] = ground_y
		a[i * 8 + 7] = rng.randf() * 10.0
	_free_buffers()
	_agents_buf = _rd.storage_buffer_create(a.size() * 4, a.to_byte_array())
	_params_buf = _rd.storage_buffer_create((2 + MAX_PANIC_SOURCES) * 16)
	_xform_buf = _rd.storage_buffer_create(agent_count * 12 * 4)
	if not _field_buf.is_valid():
		var empty := PackedFloat32Array()
		empty.resize(_grid.x * _grid.y * 4)
		_field_buf = _rd.storage_buffer_create(empty.size() * 4, empty.to_byte_array())
	_make_uniform_set()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = agent_count
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = mm
	parent.add_child(_mmi)


## Rebuilds the 1 m flow field from the navmesh after a (re)bake (Section 4.5).
func refresh_flow_field(chunk) -> void:
	if not enabled:
		return
	var map: RID = chunk.map_rid if chunk != null and "map_rid" in chunk else _default_map()
	if not map.is_valid():
		return
	var origin3: Vector3 = chunk.origin if chunk != null and "origin" in chunk else Vector3.ZERO
	_origin = Vector2(origin3.x, origin3.z)
	var w := _grid.x
	var h := _grid.y
	var walkable := PackedByteArray()
	walkable.resize(w * h)
	for y in h:
		for x in w:
			var p := Vector3(_origin.x + (x + 0.5) * CELL, origin3.y, _origin.y + (y + 0.5) * CELL)
			var q := NavigationServer3D.map_get_closest_point(map, p)
			walkable[y * w + x] = 1 if Vector2(q.x - p.x, q.z - p.z).length() < 0.4 else 0
	var goals: Array[Vector2i] = []
	for hub in get_tree().get_nodes_in_group(&"crowd_hubs"):
		var c := Vector2i(floori((hub.global_position.x - _origin.x) / CELL), floori((hub.global_position.z - _origin.y) / CELL))
		if c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
			goals.append(c)
	if goals.is_empty():
		goals.append(Vector2i(int(w / 2.0), int(h / 2.0)))
	var cells := _bfs_field(walkable, goals)
	if _field_buf.is_valid():
		_rd.free_rid(_field_buf)
	_field_buf = _rd.storage_buffer_create(cells.size() * 4, cells.to_byte_array())
	if _agents_buf.is_valid():
		_make_uniform_set()


func add_panic_source(position: Vector3, radius: float, strength: float = 3.0) -> void:
	_panic.append(Vector4(position.x, position.z, radius, strength))
	if _panic.size() > MAX_PANIC_SOURCES:
		_panic.pop_front()


## Removes the crowd when a level unloads (the MultiMesh belongs to the old scene).
func clear() -> void:
	agent_count = 0
	_in_flight = false
	if is_instance_valid(_mmi):
		_mmi.queue_free()
	_mmi = null
	_panic.clear()


func _process(delta: float) -> void:
	if not enabled or agent_count == 0 or not _uniform_set.is_valid():
		return
	if not is_instance_valid(_mmi):
		clear()
		return
	_accum += delta
	if _accum < 1.0 / SIM_HZ:
		return
	var dt := _accum
	_accum = 0.0
	if _in_flight:
		_rd.sync()   # results of the previous tick, submitted one tick ago
		var bytes := _rd.buffer_get_data(_xform_buf)
		RenderingServer.multimesh_set_buffer(_mmi.multimesh.get_rid(), bytes.to_float32_array())
		_in_flight = false
	_upload_params(dt)
	var cl := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, _pipeline)
	_rd.compute_list_bind_uniform_set(cl, _uniform_set, 0)
	_rd.compute_list_dispatch(cl, ceili(agent_count / 64.0), 1, 1)
	_rd.compute_list_end()
	_rd.submit()
	_in_flight = true
	for i in range(_panic.size() - 1, -1, -1):   # panic sources fade over about 3 s
		_panic[i].w -= dt
		if _panic[i].w <= 0.0:
			_panic.remove_at(i)


func _upload_params(dt: float) -> void:
	var p := PackedFloat32Array([_origin.x, _origin.y, CELL, dt, _grid.x, _grid.y, agent_count, _panic.size()])
	for s in _panic:
		p.append_array(PackedFloat32Array([s.x, s.y, s.z, s.w]))
	p.resize((2 + MAX_PANIC_SOURCES) * 4)
	_rd.buffer_update(_params_buf, 0, p.size() * 4, p.to_byte_array())


func _make_uniform_set() -> void:
	var uniforms: Array[RDUniform] = []
	for pair in [[0, _agents_buf], [1, _field_buf], [2, _params_buf], [3, _xform_buf]]:
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u.binding = pair[0]
		u.add_id(pair[1])
		uniforms.append(u)
	_uniform_set = _rd.uniform_set_create(uniforms, _shader, 0)


func _bfs_field(walkable: PackedByteArray, goals: Array[Vector2i]) -> PackedFloat32Array:
	# Breadth-first distance from the hubs, then each cell points to its lowest neighbour.
	var w := _grid.x
	var h := _grid.y
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(1 << 30)
	var queue: Array[Vector2i] = []
	for g in goals:
		dist[g.y * w + g.x] = 0
		queue.append(g)
	var head := 0
	var steps := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for s in steps:
			var n: Vector2i = c + s
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or walkable[n.y * w + n.x] == 0:
				continue
			if dist[n.y * w + n.x] > dist[c.y * w + c.x] + 1:
				dist[n.y * w + n.x] = dist[c.y * w + c.x] + 1
				queue.append(n)
	var cells := PackedFloat32Array()
	cells.resize(w * h * 4)
	for y in h:
		for x in w:
			var i := y * w + x
			var best := Vector2.ZERO
			var best_d := dist[i]
			for s in steps:
				var n: Vector2i = Vector2i(x, y) + s
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and dist[n.y * w + n.x] < best_d:
					best_d = dist[n.y * w + n.x]
					best = Vector2(s)
			cells[i * 4 + 0] = best.x
			cells[i * 4 + 1] = best.y
			cells[i * 4 + 2] = float(walkable[i])
	return cells


func _default_map() -> RID:
	var world := get_viewport().find_world_3d() if get_viewport() else null
	return world.navigation_map if world else RID()


func _free_buffers() -> void:
	for rid in [_agents_buf, _params_buf, _xform_buf]:
		if rid.is_valid():
			_rd.free_rid(rid)
	if _mmi:
		_mmi.queue_free()
		_mmi = null
