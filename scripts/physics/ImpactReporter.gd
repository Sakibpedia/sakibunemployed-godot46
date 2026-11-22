extends RigidBody3D
## Attach to any Jolt rigid prop. Reports impacts to the PhysicsEventBus, which turns them
## into sound, AI hearing and crowd panic (design doc Sections 5.6 and 10.8).

@export var surface_type: String = "tile"   # overridden by the prop's tactical tags if present
@export var sector_id: String = ""

var _last_ms := 0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	if has_meta(&"tactical_tags"):
		var tags: Dictionary = get_meta(&"tactical_tags")
		surface_type = tags.get("surface_type", surface_type)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var n := state.get_contact_count()
	if n == 0:
		return
	var now := Time.get_ticks_msec()
	if now - _last_ms < 120:
		return   # one report per burst of contacts
	var total := 0.0
	var where := global_position
	for i in n:
		total += state.get_contact_impulse(i).length()
		where = state.get_contact_collider_position(i)
	if total >= PhysicsEventBus.MIN_IMPULSE:
		_last_ms = now
		# Deferred: never query the physics space from inside its own step.
		PhysicsEventBus.report_impact.call_deferred(where, surface_type, total, sector_id)
