extends Node
## Everything the save file holds: the clock, money, health, inventory, respect, honesty, knowledge,
## flags, mission progress, posters, ghosts (spirit records) and the exam no-repeat bags.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal money_changed(value: int)
signal respect_changed(value: int)
signal honesty_changed(value: int)
signal health_changed(value: float)
signal item_changed(item: String, count: int)
signal time_changed(hour: float)
signal new_day(day: int)
signal flag_set(key: String)
signal event_logged(event: Dictionary)

const SAVE_PATH := "user://save_openworld.json"
const TIME_SCALE := 30.0          # game seconds per real second: one game day = 48 real minutes
const START_HOUR := 8.5
const MAX_HEALTH := 100.0

var day: int = 1
var seconds: float = START_HOUR * 3600.0
var money: int = 300
var health: float = MAX_HEALTH
var respect: int = 10
var honesty: int = 60
var knowledge: Dictionary = {}       # category -> {"right": int, "wrong": int}
var inventory: Dictionary = {}
var flags: Dictionary = {}
var missions: Dictionary = {}
var posters_read: Array = []
var posters_torn: Array = []
var spirits: Array = []              # see docs/ARCHITECTURE.md, "Spirit records"
var exam_bags: Dictionary = {}       # pool key -> Array of remaining item ids
var asked: Dictionary = {}           # item id -> times asked
var stats: Dictionary = {}
var recent_events: Array = []        # rumours for ChatterAI: {kind, district, day, hour}
var player_position := Vector3.ZERO
var player_rotation := 0.0
var has_position := false
var clock_running := true

var _last_minute := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	new_game()


func new_game() -> void:
	day = 1
	seconds = START_HOUR * 3600.0
	money = 300
	health = MAX_HEALTH
	respect = 10
	honesty = 60
	knowledge = {}
	inventory = {"pistol_ammo": 0, "bandages": 2, "batteries": 2, "study_tokens": 1, "torch": 1, "pistol": 0, "iron_rod": 0}
	flags = {}
	missions = {"completed": [], "failed": {}, "active": "", "step": 0, "unlocked": []}
	posters_read = []
	posters_torn = []
	spirits = []
	exam_bags = {}
	asked = {}
	stats = {"answered": 0, "right": 0, "wrong": 0, "kills": 0, "peaceful_deaths": 0, "ghosts_made": 0,
		"ghosts_banished": 0, "bribes": 0, "posters": 0, "missions": 0, "deaths": 0, "arrests": 0,
		"distance_m": 0.0, "duels_won": 0, "duels_lost": 0, "people_helped": 0}
	recent_events = []
	has_position = false
	clock_running = true


# --- Clock ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not clock_running:
		return
	seconds += delta * TIME_SCALE
	if seconds >= 86400.0:
		seconds -= 86400.0
		day += 1
		new_day.emit(day)
	var minute := int(seconds / 60.0)
	if minute != _last_minute:
		_last_minute = minute
		time_changed.emit(hour())


func hour() -> float:
	return seconds / 3600.0


func clock_text() -> String:
	var h := int(seconds / 3600.0)
	var m := int(fmod(seconds, 3600.0) / 60.0)
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


## Skip forward to a given hour (sleeping, waiting). Rolls the day over if needed.
func skip_to(target_hour: float) -> void:
	var t := target_hour * 3600.0
	if t <= seconds:
		day += 1
		new_day.emit(day)
	seconds = t
	time_changed.emit(hour())


func is_daylight() -> bool:
	var h := hour()
	return h >= 5.9 and h < 18.05


# --- Money, respect, honesty, health ----------------------------------------------------------

func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	money_changed.emit(money)


func spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func change_respect(delta: int) -> void:
	respect = clampi(respect + delta, 0, 100)
	respect_changed.emit(respect)


func change_honesty(delta: int) -> void:
	honesty = clampi(honesty + delta, 0, 100)
	honesty_changed.emit(honesty)


func set_health(value: float) -> void:
	health = clampf(value, 0.0, MAX_HEALTH)
	health_changed.emit(health)


# --- Inventory ---------------------------------------------------------------------------------

func count(item: String) -> int:
	return int(inventory.get(item, 0))


func add_item(item: String, n: int = 1) -> void:
	inventory[item] = maxi(0, count(item) + n)
	item_changed.emit(item, count(item))


func take_item(item: String, n: int = 1) -> bool:
	if count(item) < n:
		return false
	inventory[item] = count(item) - n
	item_changed.emit(item, count(item))
	return true


# --- Flags and rumours --------------------------------------------------------------------------

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value
	flag_set.emit(key)


func flag(key: String) -> bool:
	return bool(flags.get(key, false))


func bump(stat: String, n: float = 1.0) -> void:
	stats[stat] = float(stats.get(stat, 0.0)) + n


func log_event(kind: String, district: String) -> void:
	var e := {"kind": kind, "district": district, "day": day, "hour": hour()}
	recent_events.push_front(e)
	if recent_events.size() > 24:
		recent_events.resize(24)
	event_logged.emit(e)


# --- Knowledge -----------------------------------------------------------------------------------

func record_answer(item_id: String, category: String, correct: bool) -> void:
	asked[item_id] = int(asked.get(item_id, 0)) + 1
	var k: Dictionary = knowledge.get(category, {"right": 0, "wrong": 0})
	if correct:
		k["right"] = int(k.get("right", 0)) + 1
		bump("right")
	else:
		k["wrong"] = int(k.get("wrong", 0)) + 1
		bump("wrong")
	knowledge[category] = k
	bump("answered")


## 0..1: how well Sakib knows a subject, from his record. Used for hints and NPC respect.
func mastery(category: String) -> float:
	var k: Dictionary = knowledge.get(category, {})
	var r := float(k.get("right", 0))
	var w := float(k.get("wrong", 0))
	return r / maxf(1.0, r + w) * clampf((r + w) / 10.0, 0.0, 1.0)


# --- Spirits ---------------------------------------------------------------------------------------

func add_spirit(record: Dictionary) -> void:
	spirits.append(record)
	bump("ghosts_made")


func unbanished_spirits() -> Array:
	var out: Array = []
	for s in spirits:
		if not bool(s.get("banished", false)):
			out.append(s)
	return out


func banish_spirit(spirit_id: String) -> void:
	for s in spirits:
		if String(s.get("id", "")) == spirit_id:
			s["banished"] = true
			bump("ghosts_banished")


# --- Save / load -----------------------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version": 2, "day": day, "seconds": seconds, "money": money, "health": health, "respect": respect,
		"honesty": honesty, "knowledge": knowledge, "inventory": inventory, "flags": flags, "missions": missions,
		"posters_read": posters_read, "posters_torn": posters_torn, "spirits": spirits, "exam_bags": exam_bags,
		"asked": asked, "stats": stats, "recent_events": recent_events,
		"player": [player_position.x, player_position.y, player_position.z, player_rotation],
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	new_game()
	day = int(d.get("day", 1))
	seconds = float(d.get("seconds", START_HOUR * 3600.0))
	money = int(d.get("money", 300))
	health = float(d.get("health", MAX_HEALTH))
	respect = int(d.get("respect", 10))
	honesty = int(d.get("honesty", 60))
	knowledge = d.get("knowledge", {})
	var inv: Dictionary = d.get("inventory", {})
	for k in inv:
		inventory[k] = int(inv[k])
	flags = d.get("flags", {})
	var m: Dictionary = d.get("missions", {})
	for k in m:
		missions[k] = m[k]
	posters_read = d.get("posters_read", [])
	posters_torn = d.get("posters_torn", [])
	spirits = d.get("spirits", [])
	exam_bags = d.get("exam_bags", {})
	asked = d.get("asked", {})
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[k] = st[k]
	recent_events = d.get("recent_events", [])
	var p: Array = d.get("player", [])
	if p.size() == 4:
		player_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		player_rotation = float(p[3])
		has_position = true
	money_changed.emit(money)
	respect_changed.emit(respect)
	honesty_changed.emit(honesty)
	health_changed.emit(health)
	time_changed.emit(hour())
	return true
