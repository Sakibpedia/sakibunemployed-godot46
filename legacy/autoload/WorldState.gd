extends Node
## One shared simulation for both lenses (design doc Section 2.4) and the clock (Section 12).
## Every system reads and writes here; nothing keeps a private copy of the world.

signal lens_changed(lens: int)
signal sector_alert_changed(sector_id: String, alert: float)
signal scanner_ping(sector_id: String)
signal utility_changed(sector_id: String, utility: String, on: bool)
signal resource_changed(resource: String, amount: int)
signal reputation_changed(key: String, value: int)
signal intel_granted(card: Dictionary)
signal minute_changed(h: int, m: int)
signal prayer(prayer_name: String)
signal roof_warning
signal roof_locked

enum Lens { GROUND_STEALTH, GROUND_ALERT, GROUND_GATE, TRANSIT_UP, SKY_PLAN, SKY_LIVE, TRANSIT_DOWN, DOWNED, CUTSCENE }

const TIME_SCALE := 10.0            # game seconds per real second (Section 2.1)
const COMMS_HEAT_PER_ORDER := 5.0   # Section 2.2
const SCANNER_THRESHOLD := 50.0
const SAVE_PATH := "user://save.json"

var save_seed: int = 20261119
var level: int = 1
var game_seconds: float = 9.0 * 3600.0
var lens: int = Lens.GROUND_STEALTH
var current_sector: String = "tower_ground"
var clock_rate := 1.0                # slowed while an exam gate is open

var sectors: Dictionary = {}        # id -> {alert, control, comms_heat}
var agents: Dictionary = {}         # agent id -> {kind, sector, node}
var utilities: Dictionary = {}      # sector id -> {power, generator, lights, cctv, water}
var resources: Dictionary = {
	"food": 10, "scrap": 0, "medical": 2, "ammo": 24,
	"taka": 500, "batteries": 1, "study_tokens": 0,
}
var structures: Dictionary = {}     # id -> {kind, sector, hp}
var intel: Array[Dictionary] = []
var reputation: Dictionary = {"exam_honesty": 60, "moral": 0}
var household_rep: Dictionary = {}  # household id -> -100..100
var exam_record: Dictionary = {"asked": {}, "right": {}, "wrong": {}, "gates": []}  # item id -> level
var prayer_times: Dictionary = {}   # "HH:MM" -> prayer name, set per level


func _process(delta: float) -> void:
	_advance_clock(delta)
	for id in sectors:
		var s: Dictionary = sectors[id]
		s.comms_heat = maxf(0.0, s.comms_heat - delta)   # decays 1 per second


# --- Clock (Section 12) -------------------------------------------------------

func set_level(n: int, start_hour: float, prayers: Dictionary = {}) -> void:
	level = n
	game_seconds = start_hour * 3600.0
	prayer_times = prayers


func clock() -> Vector2i:
	var minutes := int(game_seconds / 60.0)
	return Vector2i(int(minutes / 60.0) % 24, minutes % 60)


func _advance_clock(delta: float) -> void:
	var before := int(game_seconds / 60.0)
	game_seconds += delta * TIME_SCALE * clock_rate
	var now := int(game_seconds / 60.0)
	for minute in range(before + 1, now + 1):    # never skip a minute on a slow frame
		var h := int(minute / 60.0) % 24
		var m := minute % 60
		minute_changed.emit(h, m)
		if h == 17 and m == 45:
			roof_warning.emit()
		elif h == 18 and m == 0:
			for door in get_tree().get_nodes_in_group("roof_doors"):
				if door.has_method("lock"):
					door.lock()
			roof_locked.emit()
		var key := "%02d:%02d" % [h, m]
		if prayer_times.has(key):
			prayer.emit(prayer_times[key])


# --- Lens (Section 2.3) ---------------------------------------------------------

func set_lens(new_lens: int) -> void:
	if new_lens == lens:
		return
	lens = new_lens
	lens_changed.emit(lens)


func in_sky_lens() -> bool:
	return lens == Lens.SKY_PLAN or lens == Lens.SKY_LIVE


# --- Sectors ------------------------------------------------------------------

func sector(id: String) -> Dictionary:
	if not sectors.has(id):
		sectors[id] = {"alert": 0.0, "control": "contested", "comms_heat": 0.0}
	return sectors[id]


func add_alert(id: String, amount: float) -> void:
	var s := sector(id)
	s.alert = clampf(s.alert + amount, 0.0, 100.0)
	sector_alert_changed.emit(id, s.alert)


func set_control(id: String, faction: String) -> void:
	sector(id).control = faction   # "sakib", "contested" or "syndicate"


func add_comms_heat(id: String, amount: float = COMMS_HEAT_PER_ORDER) -> void:
	var s := sector(id)
	s.comms_heat = clampf(s.comms_heat + amount, 0.0, 100.0)
	if s.comms_heat >= SCANNER_THRESHOLD:
		scanner_ping.emit(id)    # level script sends a patrol
		s.comms_heat = SCANNER_THRESHOLD - 15.0


# --- Utilities ----------------------------------------------------------------

func set_utility(sector_id: String, utility: String, on: bool) -> void:
	if not utilities.has(sector_id):
		utilities[sector_id] = {"power": true, "generator": true, "lights": true, "cctv": true, "water": true}
	utilities[sector_id][utility] = on
	utility_changed.emit(sector_id, utility, on)


func is_on(sector_id: String, utility: String) -> bool:
	return utilities.get(sector_id, {}).get(utility, true)


func vision_multiplier(sector_id: String) -> float:
	# A power cut halves sight range in the sector (Section 11.3).
	var lit := is_on(sector_id, "power") or is_on(sector_id, "generator")
	return 1.0 if lit and is_on(sector_id, "lights") else 0.5


# --- Resources, reputation, intel ---------------------------------------------

func add_resource(resource: String, amount: int) -> void:
	resources[resource] = int(resources.get(resource, 0)) + amount
	resource_changed.emit(resource, resources[resource])


func spend(resource: String, amount: int) -> bool:
	if int(resources.get(resource, 0)) < amount:
		return false
	add_resource(resource, -amount)
	return true


func change_rep(key: String, delta: int) -> void:
	reputation[key] = clampi(int(reputation.get(key, 0)) + delta, -100, 100)
	reputation_changed.emit(key, reputation[key])


func change_household(household: String, delta: int) -> void:
	household_rep[household] = clampi(int(household_rep.get(household, 0)) + delta, -100, 100)


func grant_intel(card: Dictionary) -> void:
	intel.append(card)
	intel_granted.emit(card)


# --- Agents and structures ----------------------------------------------------

func register_agent(id: String, kind: String, sector_id: String, node: Node) -> void:
	agents[id] = {"kind": kind, "sector": sector_id, "node": node}


func unregister_agent(id: String) -> void:
	agents.erase(id)


func add_structure(id: String, kind: String, sector_id: String, hp: int) -> void:
	structures[id] = {"kind": kind, "sector": sector_id, "hp": hp}


# --- Exam record (Section 6) --------------------------------------------------

func record_answer(item_id: String, correct: bool, depth: int) -> void:
	if depth > 0:
		return   # only main questions drive spaced repetition
	exam_record.asked[item_id] = level
	if correct:
		exam_record.right[item_id] = level
		exam_record.wrong.erase(item_id)
	else:
		exam_record.wrong[item_id] = level


func record_gate(result: Dictionary) -> void:
	exam_record.gates.append({
		"gate_id": result.get("gate_id", ""), "level": level,
		"passed": result.get("passed", false), "points": result.get("points", 0.0),
	})


# --- Save and load ------------------------------------------------------------

func save_game() -> void:
	var data := {
		"seed": save_seed, "level": level, "game_seconds": game_seconds,
		"sectors": sectors, "resources": resources, "reputation": reputation,
		"household_rep": household_rep, "exam_record": exam_record, "intel": intel,
		"career": CareerAdvice.to_dict(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	save_seed = int(data.get("seed", save_seed))
	level = int(data.get("level", 1))
	game_seconds = float(data.get("game_seconds", game_seconds))
	sectors = data.get("sectors", {})
	resources = data.get("resources", resources)
	reputation = data.get("reputation", reputation)
	household_rep = data.get("household_rep", {})
	exam_record = data.get("exam_record", exam_record)
	CareerAdvice.from_dict(data.get("career", {}))
	return true
