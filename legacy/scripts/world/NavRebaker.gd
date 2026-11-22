extends Node
## Runtime navmesh rebakes without stutter (design doc Section 4.5).
## Only the dirty 64 m chunk rebakes, on a worker thread, at most two at a time,
## debounced by 0.5 s and ordered by distance to the player.

const DEBOUNCE_MS := 500
const MAX_ACTIVE := 2

@export var player: Node3D

var _queue: Dictionary = {}   # NavChunk -> true
var _active := 0


func _ready() -> void:
	add_to_group(&"nav_rebakers")


func request_rebake(chunk: NavChunk) -> void:
	chunk.dirty_at = Time.get_ticks_msec()
	_queue[chunk] = true


func _process(_dt: float) -> void:
	if _queue.is_empty() or _active >= MAX_ACTIVE:
		return
	var due: Array = []
	for chunk in _queue.keys():
		if Time.get_ticks_msec() - chunk.dirty_at >= DEBOUNCE_MS:
			due.append(chunk)
	if player:
		var pos := player.global_position
		due.sort_custom(func(a, b): return a.origin.distance_squared_to(pos) < b.origin.distance_squared_to(pos))
	for chunk in due:
		if _active >= MAX_ACTIVE:
			break
		_queue.erase(chunk)
		_active += 1
		# Parsing touches the scene tree, so it stays on the main thread; baking does not.
		var src := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(chunk.nav_mesh, src, chunk.root)
		NavigationServer3D.bake_from_source_geometry_data_async(chunk.nav_mesh, src, _on_baked.bind(chunk))


func _on_baked(chunk: NavChunk) -> void:
	_active -= 1
	NavigationServer3D.region_set_navigation_mesh(chunk.region_rid, chunk.nav_mesh)
	CrowdAggregate.refresh_flow_field(chunk)
