extends Node
## Physics events fan out to sound, AI hearing, navmesh rebakes and injuries
## (design doc Section 10.8). Props report through scripts/physics/ImpactReporter.gd.

signal impact(position: Vector3, surface: String, impulse: float, db_at_1m: float)
signal structure_changed(body: Node3D)
signal fall_landed(body: Node3D, height: float)
signal submerged(body: Node3D, seconds: float)
signal shocked(body: Node3D)
signal exploded(position: Vector3, radius: float)

## Loudness at 1 m for a 1 N·s impact on each surface type (Section 5.5); +10 dB per tenfold impulse.
const SURFACE_BASE_DB := {
	"tile": 64.0, "tile_stair": 64.0, "rubber_tile": 55.0, "wood": 62.0, "plaster": 58.0,
	"brick": 60.0, "concrete_dusty": 60.0, "metal_thin": 70.0, "metal_grille": 72.0,
	"metal_tube": 70.0, "metal_rust": 70.0, "glass": 78.0, "sheet": 72.0, "cloth": 40.0,
}
const MIN_IMPULSE := 0.5          # N·s; ignores resting contacts
const FALL_INJURY_M := 4.0
const FALL_LETHAL_M := 9.0        # three storeys (Section 10.2)


func report_impact(position: Vector3, surface: String, impulse: float, sector_id: String = "") -> void:
	if impulse < MIN_IMPULSE:
		return
	var base: float = SURFACE_BASE_DB.get(surface, 60.0)
	var db := base + 10.0 * log(maxf(impulse, 0.1)) / log(10.0)
	impact.emit(position, surface, impulse, db)
	AudioEventBus.emit_event("impact_%s" % surface, position, db, sector_id)


func report_structure_changed(body: Node3D) -> void:
	structure_changed.emit(body)
	var chunk = body.get_meta(&"nav_chunk", null)
	if chunk != null:
		get_tree().call_group(&"nav_rebakers", &"request_rebake", chunk)


func report_fall(body: Node3D, height: float) -> void:
	fall_landed.emit(body, height)
	if height < FALL_INJURY_M:
		return
	if body.has_method(&"apply_fall"):
		body.call(&"apply_fall", height, height >= FALL_LETHAL_M)


func report_submerged(body: Node3D, seconds: float) -> void:
	submerged.emit(body, seconds)


func report_shock(body: Node3D) -> void:
	shocked.emit(body)


func report_explosion(position: Vector3, radius: float, sector_id: String = "") -> void:
	exploded.emit(position, radius)
	AudioEventBus.emit_event("explosion", position, 140.0, sector_id)
