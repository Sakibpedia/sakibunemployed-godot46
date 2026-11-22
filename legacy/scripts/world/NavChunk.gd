class_name NavChunk
extends RefCounted
## One 64 m navigation chunk (design doc Section 4.4). Its NavigationMesh parses only
## the chunk's "nav_source" collision group, with a 2 m border so edges line up.

const SIZE := 64.0
const BORDER := 2.0

var root: Node3D
var region_rid: RID
var map_rid: RID
var origin: Vector3
var nav_mesh: NavigationMesh
var dirty_at := 0


func _init(chunk_root: Node3D, region: NavigationRegion3D) -> void:
	root = chunk_root
	region_rid = region.get_rid()
	map_rid = region.get_navigation_map()
	origin = chunk_root.global_position
	nav_mesh = NavigationMesh.new()
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.2
	nav_mesh.agent_radius = 0.35
	nav_mesh.agent_height = 1.75
	nav_mesh.agent_max_climb = 0.3
	nav_mesh.agent_max_slope = 40.0
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"nav_source"
	nav_mesh.filter_baking_aabb = AABB(Vector3(-BORDER, -5.0, -BORDER), Vector3(SIZE + 2.0 * BORDER, 40.0, SIZE + 2.0 * BORDER))
	nav_mesh.filter_baking_aabb_offset = origin
