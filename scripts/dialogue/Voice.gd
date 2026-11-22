extends Node
## Spoken lines, with no overlap.  Every line goes through one priority queue:
##
##   2  conversation / story line  (stops whatever is playing, clears the queue)
##   1  a person answering you      (waits its turn)
##   0  ambient bark                 (dropped when anything else is speaking, or while paused)
##
## The game ships pre-rendered Bengali and English lines in res://audio/voice (made by
## tools/generate_voice.py).  If a line has no recording, the operating system's TTS is used as a
## fallback; if that is missing too, the subtitle still appears.  A conversation therefore never
## fights an ambient bark, and a new line always stops the old one cleanly.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal line_started(speaker: Dictionary, line: Dictionary, seconds: float)

const HEAR_RANGE := 26.0
const MANIFEST_PATH := "res://audio/voice/manifest.json"
const MAX_QUEUE := 6

var _bn_voices: PackedStringArray = []
var _en_voices: PackedStringArray = []
var _available := false
var _manifest: Dictionary = {}
var _audio_cache: Dictionary = {}
var _voice_ids: Dictionary = {}
var _queue: Array = []
var _current: Dictionary = {}
var _current_player: Object = null
var _finish_t := 0.0
var _busy_until := 0.0
var _utterance := 0
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _player_i := 0
var _player3d_i := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scan()
	_load_manifest()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.bus = &"Master"
		add_child(p)
		p.finished.connect(_on_player_finished.bind(p))
		_players.append(p)
	for i in 5:
		var p3 := AudioStreamPlayer3D.new()
		p3.process_mode = Node.PROCESS_MODE_ALWAYS
		p3.bus = &"Master"
		p3.unit_size = 7.0
		p3.max_distance = HEAR_RANGE
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.max_db = 0.0
		add_child(p3)
		p3.finished.connect(_on_player_finished.bind(p3))
		_players3d.append(p3)


func _scan() -> void:
	_available = false
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	_bn_voices = DisplayServer.tts_get_voices_for_language("bn")
	_en_voices = DisplayServer.tts_get_voices_for_language("en")
	_available = not _bn_voices.is_empty() or not _en_voices.is_empty()


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_manifest = parsed
	for key in _manifest.get("lines", {}):
		var parts := String(key).split("|")
		if parts.size() >= 2:
			_voice_ids[parts[1]] = true
	for vid in _manifest.get("profiles", {}):
		_voice_ids[String(vid)] = true


func has_bengali_voice() -> bool:
	return not _bn_voices.is_empty() or _has_rendered("bn")


func available() -> bool:
	return _available or not _manifest.is_empty()


func _has_rendered(lang: String) -> bool:
	for key in _manifest.get("lines", {}):
		if String(key).begins_with(lang + "|"):
			return true
	return false


func has_audio(speaker: Dictionary, line: Dictionary, lang: String = "") -> bool:
	var l := lang if lang != "" else Game.language
	var text := String(line.get(l, ""))
	if text == "":
		text = String(line.get("en", ""))
		l = "en"
	return not _lookup(l, voice_id_for(speaker), text).is_empty()


# ------------------------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------------------------

## priority: 0 ambient bark, 1 conversation reply, 2 story line (interrupts anything).
## at: a world position for a spatial bark; Vector3.INF for a non-spatial conversation line.
func speak(speaker: Dictionary, line: Dictionary, priority: int = 1, at: Vector3 = Vector3.INF) -> void:
	if line.is_empty():
		return
	var dist := 0.0
	if at != Vector3.INF and Services.player != null and is_instance_valid(Services.player):
		dist = at.distance_to(Services.player.global_position)
		if dist > HEAR_RANGE:
			return
	# Ambient chatter never talks over a paused conversation, and never queues up behind one.
	if priority <= 0 and get_tree().paused:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if priority <= 0 and (now < _busy_until or not _current.is_empty() or _queue.size() > 0):
		return
	if priority >= 2:
		_stop_audio()
		_queue.clear()
		_current = {}
		_finish_t = 0.0
	if _queue.size() >= MAX_QUEUE:
		if priority <= 0:
			return
		_queue.pop_front()
	_queue.append({"speaker": speaker, "line": line, "priority": priority, "at": at, "dist": dist})
	# Higher priority first, but keep arrival order within a priority.
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) > int(b["priority"]))
	if _current.is_empty():
		_play_next()


func stop() -> void:
	_stop_audio()
	_queue.clear()
	_current = {}
	_finish_t = 0.0
	_busy_until = 0.0
	if _available:
		DisplayServer.tts_stop()


func is_speaking() -> bool:
	return not _current.is_empty() or (_available and DisplayServer.tts_is_speaking())


## Which pre-rendered voice belongs to this speaker.  Named characters use their own id; a crowd
## member falls back to a gender/age bark voice, so every line still sounds like a person.
func voice_id_for(speaker: Dictionary) -> String:
	var explicit := String(speaker.get("voice_id", ""))
	if explicit != "":
		return explicit
	var sid := String(speaker.get("id", ""))
	if sid != "" and _voice_ids.has(sid):
		return sid
	if sid == "sakib" or sid == "narrator":
		return sid
	var v: Dictionary = speaker.get("voice", {})
	var pitch := float(v.get("pitch", 1.0))
	if pitch < 0.72:
		return "ghost"
	if pitch > 1.08:
		return "bark_f"
	if pitch < 0.9:
		return "bark_old"
	return "bark_m"


# ------------------------------------------------------------------------------------------------
# Playback
# ------------------------------------------------------------------------------------------------

func _play_next() -> void:
	if _queue.is_empty():
		return
	var item: Dictionary = _queue.pop_front()
	var speaker: Dictionary = item["speaker"]
	var line: Dictionary = item["line"]
	var priority := int(item["priority"])
	var at: Vector3 = item["at"]
	var dist := float(item["dist"])
	var lang := Game.language
	var text := String(line.get(lang, ""))
	if text == "":
		lang = "en" if lang == "bn" else "bn"
		text = String(line.get(lang, ""))
	if text == "":
		text = String(line.get("en", ""))
		lang = "en"
	var rec := _lookup(lang, voice_id_for(speaker), text)
	var secs := float(rec.get("dur", 0.0)) if not rec.is_empty() else clampf(1.4 + 0.065 * text.length(), 2.0, 12.0)
	_current = item
	_finish_t = secs
	_busy_until = Time.get_ticks_msec() / 1000.0 + secs * (0.55 if priority <= 0 else 1.0)
	Services.subtitle.emit(speaker, line, secs)
	line_started.emit(speaker, line, secs)
	if not Game.voices:
		return
	# 1. A real recording.
	if not rec.is_empty():
		var stream: AudioStream = _audio_cache.get(rec["file"], null)
		if stream == null:
			var path := String(rec["file"])
			if ResourceLoader.exists(path):
				stream = load(path)
			elif FileAccess.file_exists(path):
				var mp3 := AudioStreamMP3.new()
				var bytes := FileAccess.get_file_as_bytes(path)
				if not bytes.is_empty():
					mp3.data = bytes
					stream = mp3
			if stream != null:
				_audio_cache[rec["file"]] = stream
		if stream != null:
			var player: Object = null
			if at != Vector3.INF:
				var p3 := _players3d[_player3d_i % _players3d.size()]
				_player3d_i += 1
				p3.global_position = at + Vector3(0, 1.5, 0)
				player = p3
			else:
				var p2 := _players[_player_i % _players.size()]
				_player_i += 1
				player = p2
			player.set("stream", stream)
			player.set("volume_db", linear_to_db(clampf(float(Game.voice_volume) / 100.0 * (1.0 - dist / HEAR_RANGE * 0.65), 0.03, 1.0)))
			player.call("play")
			_current_player = player
			return
	# 2. System TTS fallback.
	if _available:
		var use_bn := lang == "bn" and not _bn_voices.is_empty()
		var pool := _bn_voices if use_bn else _en_voices
		if not pool.is_empty():
			var v: Dictionary = speaker.get("voice", {})
			var pitch := float(v.get("pitch", 1.0))
			var rate := float(v.get("rate", 1.0))
			var idx := int(v.get("index", 0)) % pool.size()
			var vol := int(clampf(float(Game.voice_volume) * (1.0 - dist / HEAR_RANGE * 0.7), 5.0, 100.0))
			_utterance += 1
			DisplayServer.tts_speak(text, pool[idx], vol, clampf(pitch, 0.5, 2.0), clampf(rate, 0.6, 1.6), _utterance, priority >= 1)
			_current_player = null
			return
	# 3. Subtitles only: the timer advances the queue.
	_current_player = null


func _lookup(lang: String, vid: String, text: String) -> Dictionary:
	var key := "%s|%s|%s" % [lang, vid, text.sha256_text().substr(0, 16)]
	var lines: Dictionary = _manifest.get("lines", {})
	if lines.has(key):
		return lines[key]
	# If the exact voice was not rendered for this line, try the generic bark in the same language.
	var fallback := "bark_f" if vid == "bark_f" else ("bark_old" if vid == "bark_old" else "bark_m")
	var key2 := "%s|%s|%s" % [lang, fallback, text.sha256_text().substr(0, 16)]
	if lines.has(key2):
		return lines[key2]
	return {}


func _stop_audio() -> void:
	for p in _players:
		if p.playing:
			p.stop()
	for p in _players3d:
		if p.playing:
			p.stop()
	_current_player = null
	if _available:
		DisplayServer.tts_stop()


func _on_player_finished(p: Node) -> void:
	if p == _current_player:
		_finish_current()


func _finish_current() -> void:
	_current = {}
	_current_player = null
	_finish_t = 0.0


func _process(delta: float) -> void:
	if not _current.is_empty():
		_finish_t -= delta
		if _finish_t <= 0.0:
			_finish_current()
	if _current.is_empty() and not _queue.is_empty():
		_play_next()
