extends Node
## Last-wish enemies (design doc Section 9). When an enemy goes down, 30-40% of eligible ones
## (not head shots, not knockouts) stay alive in a dying pose for a bleed-out time set by the cause.
## Kneel and press E to hear his last wish: a 5-question gate themed on how he is dying, timed by
## the blood he has left. Intel only for five right first time; an exhausted chain, a timeout,
## walking away, or leaving him to bleed out = a scream that brings everyone running.

signal last_wish_started(agent: Node3D, cause: String)
signal last_wish_ended(agent: Node3D, result: Dictionary)

const SET_BY_CAUSE := {
	"gunshot": "LW-GUN", "fall": "LW-GUN", "bleed": "LW-BLEED", "blast": "LW-BLAST",
	"shock": "LW-SHOCK", "drown": "LW-DROWN",
}
const BLEED_S := {"gunshot": 90.0, "fall": 90.0, "bleed": 90.0, "blast": 75.0, "shock": 60.0, "drown": 45.0}
const SCREAM_DB := {"gunshot": 90.0, "fall": 90.0, "bleed": 85.0, "blast": 75.0, "shock": 80.0, "drown": 80.0}

var level_share := 0.35   # 0.30-0.40 per level
var level_cap := 2        # from table 1D
var _spawned := 0
var _active: Node3D = null
var _session: ExamSession = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = WorldState.save_seed + 7


func configure_level(share: float, cap: int) -> void:
	level_share = clampf(share, 0.30, 1.0)
	level_cap = cap
	_spawned = 0
	_active = null
	_session = null


## Damage systems call this when an enemy goes down. instant = head shot or knockout.
## Returns true if the enemy stays alive in a dying pose (the caller must not kill him).
func on_enemy_downed(agent: Node3D, cause: String, instant: bool) -> bool:
	if instant or _spawned >= level_cap or not SET_BY_CAUSE.has(cause):
		return false
	if _active != null and is_instance_valid(_active):
		return false
	if _rng.randf() > level_share:
		return false
	_spawned += 1
	_active = agent
	agent.info["lw_cause"] = cause
	agent.enter_dying_pose(BLEED_S[cause])
	last_wish_started.emit(agent, cause)
	return true


## Sakib kneels beside the dying man: open his gate with whatever time he has left.
func begin(agent: Node3D) -> ExamSession:
	if agent != _active or _session != null:
		return null
	var cause: String = agent.info.get("lw_cause", "gunshot")
	var left: float = agent.dying_left()
	var s := ExamGate.open_gate({
		"gate_id": "lw_%d_%s_%d" % [WorldState.level, agent.name, Time.get_ticks_msec()],
		"gatekeeper": "dying %s" % agent.display_name, "category": "last_wish", "size": 5,
		"pass_points": 3.0, "draw": {"sets": [SET_BY_CAUSE[cause]]}, "total_time_s": maxf(left, 15.0),
		"chain": {"max_depth": 3}, "no_bribe": true,
	})
	if s == null:
		return null
	_session = s
	agent.hold_bleeding(true)
	s.resolved.connect(_on_resolved.bind(agent, cause))
	return s


## The dying actor's own clock ran out before Sakib reached him (or while nobody listened).
func timeout(agent: Node3D) -> void:
	if _session != null and agent == _active:
		return   # the open gate's timer decides
	var cause: String = agent.info.get("lw_cause", "gunshot")
	_scream(agent, cause)
	agent.die_quietly()
	last_wish_ended.emit(agent, {"passed": false, "perfect": false, "timed_out": true})
	if agent == _active:
		_active = null


func _on_resolved(result: Dictionary, agent: Node3D, cause: String) -> void:
	_session = null
	if result.perfect:
		var card: Dictionary = agent.get_meta(&"intel_card", {"kind": "patrol_routes", "minutes": 30}) if is_instance_valid(agent) else {"kind": "patrol_routes"}
		WorldState.grant_intel(card)
	elif result.chain_exhausted or result.timed_out or result.abandoned:
		_scream(agent, cause)
	if is_instance_valid(agent):
		agent.die_quietly()
	last_wish_ended.emit(agent, result)
	_active = null


func _scream(agent: Node3D, cause: String) -> void:
	if is_instance_valid(agent):
		AudioEventBus.emit_event("scream", agent.global_position, SCREAM_DB.get(cause, 85.0), WorldState.current_sector)
