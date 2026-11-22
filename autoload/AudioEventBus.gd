extends Node
## One bus for every sound the AI can hear (design doc Sections 11.3 and 16).
## Each event carries its loudness in dB at 1 m. Sound falls about 6 dB per doubling of
## distance (20 log10 d) and about 20 dB per wall between source and listener.
## Recorded files listed in Data/Audio/sound_bank.json play when present; until they are
## recorded, short synthesized stand-ins play instead (all under 8 s; no rain, no thunder,
## no continuous music, and no synthesized screams).

signal sound_event(event_name: String, position: Vector3, db_at_1m: float)
signal panic(position: Vector3, radius: float)   # loud events: pedestrians nearby scatter

const BANK_PATH := "res://Data/Audio/sound_bank.json"
const INVESTIGATE_DB := 45.0
const ALERT_DB := 60.0
const PANIC_DB := 80.0
const WALL_LOSS_DB := 20.0
const POOL_SIZE := 24
const UI_POOL := 6
const RATE := 22050
const FORBIDDEN := ["rain", "thunder", "music_loop", "bgm"]   # the brief: no rain, no thunder, no continuous music
const SYNTH_FOR := {
	"gunshot": "shot", "suppressed_shot": "suppressed", "footstep": "step", "gate_screech": "screech",
	"breaker": "click_hum", "firecracker": "crackle", "lift": "hum", "scuffle": "thud", "scrape": "thud",
	"work": "thud", "shout": "", "scream": "", "impact": "tick", "horn": "horn", "ghost": "wail", "punch": "thud",
	"bell": "bell",
}

var _bank: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _ui: Array[AudioStreamPlayer] = []
var _synth: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(BANK_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		_bank = data.get("events", {})
	for event_name in _bank:
		for word in FORBIDDEN:
			assert(not String(event_name).contains(word), "Forbidden sound in bank: %s" % event_name)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		p.unit_size = 6.0
		add_child(p)
		_pool.append(p)
	for i in UI_POOL:
		var u := AudioStreamPlayer.new()
		add_child(u)
		_ui.append(u)


func emit_event(event_name: String, position: Vector3, db_at_1m: float, sector_id: String = "") -> void:
	sound_event.emit(event_name, position, db_at_1m)
	_play(event_name, position, db_at_1m)
	for listener in get_tree().get_nodes_in_group(&"listeners"):
		if not listener is Node3D or not listener.has_method(&"hear"):
			continue
		var walls := 1 if _blocked(position, listener.global_position) else 0
		var level := heard_level(db_at_1m, position, listener.global_position, walls)
		if level >= INVESTIGATE_DB:
			listener.hear(event_name, position, level)
	if db_at_1m >= PANIC_DB:
		panic.emit(position, clampf((db_at_1m - 70.0) * 1.5, 5.0, 40.0))


static func heard_level(db_at_1m: float, from: Vector3, to: Vector3, walls: int = 0) -> float:
	var d := maxf(1.0, from.distance_to(to))
	return db_at_1m - 20.0 * log(d) / log(10.0) - WALL_LOSS_DB * walls


## Non-positional interface sounds: clicks, right / wrong answers, objective stingers.
func play_ui(sound_name: String) -> void:
	var stream := _synth_stream(sound_name)
	if stream == null:
		return
	for u in _ui:
		if not u.playing:
			u.stream = stream
			u.volume_db = -8.0
			u.play()
			return


func _blocked(from: Vector3, to: Vector3) -> bool:
	var world := get_viewport().find_world_3d() if get_viewport() else null
	if world == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.5, to + Vector3.UP * 0.5, 1)   # static world only
	return not world.direct_space_state.intersect_ray(q).is_empty()


func _play(event_name: String, position: Vector3, db_at_1m: float) -> void:
	var entry: Dictionary = _bank.get(event_name, {})
	var stream: AudioStream = null
	var streams: Array = entry.get("streams", [])
	if not streams.is_empty():
		var path: String = streams[_rng.randi_range(0, streams.size() - 1)]
		if ResourceLoader.exists(path):
			stream = load(path)
	if stream == null:
		var key := String(SYNTH_FOR.get(event_name, "tick" if event_name.begins_with("impact") else ""))
		stream = _synth_stream(key)
	if stream == null:
		return
	for p in _pool:
		if p.playing:
			continue
		p.stream = stream
		p.global_position = position
		p.volume_db = clampf((db_at_1m - 80.0) * 0.3, -24.0, 8.0)   # loud events stay loud, never deafening
		p.max_distance = float(entry.get("max_distance", 40.0 if db_at_1m < 100.0 else 90.0))
		var bus := String(entry.get("bus", "Master"))
		p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
		p.pitch_scale = _rng.randf_range(0.92, 1.08)
		p.play()
		return


# --- Synthesized stand-ins ------------------------------------------------------------

func _synth_stream(key: String) -> AudioStreamWAV:
	if key == "":
		return null
	if _synth.has(key):
		return _synth[key]
	var s := PackedFloat32Array()
	match key:
		"shot":
			s = _noise_burst(0.35, 0.06, 0.9)
			_add_tone(s, 70.0, 0.25, 0.7, 12.0)
		"suppressed":
			s = _noise_burst(0.12, 0.35, 0.55)
			_add_tone(s, 140.0, 0.08, 0.3, 30.0)
		"step":
			s = _noise_burst(0.07, 0.8, 0.35)
		"tick":
			s = _noise_burst(0.06, 0.2, 0.4)
		"thud":
			s = _noise_burst(0.15, 0.85, 0.5)
			_add_tone(s, 90.0, 0.12, 0.4, 20.0)
		"screech":
			s = _sweep(0.8, 340.0, 210.0, 0.25, 9.0)
		"click_hum":
			s = _noise_burst(0.04, 0.1, 0.6)
			_add_tone(s, 100.0, 0.5, 0.15, 3.0)
		"hum":
			s = _sweep(1.2, 95.0, 110.0, 0.2, 2.0)
		"crackle":
			s = PackedFloat32Array()
			s.resize(int(RATE * 0.7))
			for k in 6:
				var burst := _noise_burst(0.05, 0.05, 0.8)
				var at := int(RATE * (0.03 + k * 0.1 + _rng.randf() * 0.03))
				for i in burst.size():
					if at + i < s.size():
						s[at + i] += burst[i]
		"click":
			s = _noise_burst(0.025, 0.05, 0.3)
		"blip":
			s = _tones([[1100.0, 0.03]], 0.12)
		"horn":
			s = _tones([[415.0, 0.22], [415.0, 0.05], [415.0, 0.3]], 0.25)
			_add_tone(s, 523.0, 0.55, 0.12, 1.5)
		"wail":
			s = _sweep(1.6, 300.0, 520.0, 0.18, 6.0)
		"bell":
			s = _tones([[1568.0, 0.05], [1568.0, 0.05]], 0.25)
		"page":
			s = _noise_burst(0.18, 0.6, 0.25)
		"pickup":
			s = _tones([[880.0, 0.06], [1320.0, 0.08]], 0.3)
		"coins":
			s = _tones([[2100.0, 0.04], [2600.0, 0.04], [2300.0, 0.06]], 0.25)
		"right":
			s = _tones([[660.0, 0.08], [990.0, 0.14]], 0.35)
		"wrong":
			s = _sweep(0.3, 220.0, 150.0, 0.35, 0.0)
		"objective":
			s = _tones([[523.0, 0.12], [659.0, 0.12], [784.0, 0.25]], 0.35)
		"fail":
			s = _tones([[392.0, 0.18], [330.0, 0.18], [262.0, 0.35]], 0.35)
		"reload":
			s = _noise_burst(0.03, 0.1, 0.5)
			var second := _noise_burst(0.04, 0.1, 0.6)
			var off := int(RATE * 0.55)
			s.resize(off + second.size())
			for i in second.size():
				s[off + i] = second[i]
		"dry_fire":
			s = _noise_burst(0.02, 0.05, 0.4)
		"ride":
			s = _sweep(1.0, 80.0, 120.0, 0.25, 6.0)
		_:
			return null
	var wav := _to_wav(s)
	_synth[key] = wav
	return wav


## Noise with an exponential decay. tone 0 = bright, 1 = dull (one-pole low-pass).
func _noise_burst(seconds: float, tone: float, amp: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var k := clampf(1.0 - tone, 0.03, 1.0)
	for i in n:
		var t := float(i) / n
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * k
		out[i] = lp * amp * exp(-5.0 * t) * (1.0 + (1.0 - tone) * 0.5)
	return out


func _add_tone(s: PackedFloat32Array, hz: float, seconds: float, amp: float, decay: float) -> void:
	var n := mini(s.size(), int(RATE * seconds))
	for i in n:
		var t := float(i) / RATE
		s[i] += sin(TAU * hz * t) * amp * exp(-decay * t)


func _sweep(seconds: float, from_hz: float, to_hz: float, amp: float, vibrato: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var hz := lerpf(from_hz, to_hz, t) * (1.0 + 0.04 * sin(TAU * vibrato * t * seconds))
		phase += TAU * hz / RATE
		var env := minf(1.0, t * 20.0) * (1.0 - t)
		out[i] = (sin(phase) + 0.3 * sin(phase * 2.0)) * amp * env
	return out


func _tones(notes: Array, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for note in notes:
		var n := int(RATE * float(note[1]))
		for i in n:
			var t := float(i) / n
			var env := minf(1.0, t * 30.0) * (1.0 - t)
			out.append(sin(TAU * float(note[0]) * i / RATE) * amp * env)
	return out


func _to_wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
