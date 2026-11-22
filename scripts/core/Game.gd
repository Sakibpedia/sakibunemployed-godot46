extends Node
## Game flow: input map, settings (language, voices, graphics), scene switching and fades.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal settings_changed

const MENU_SCENE := "res://scenes/Main.tscn"
const WORLD_SCENE := "res://scenes/World.tscn"
const SETTINGS_PATH := "user://settings.cfg"

const KEYS := {
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT], "sprint": [KEY_SHIFT], "crouch": [KEY_C, KEY_CTRL], "jump": [KEY_SPACE],
	"interact": [KEY_E], "vehicle": [KEY_F], "reload": [KEY_R], "torch": [KEY_T], "camera": [KEY_V],
	"map": [KEY_M], "missions": [KEY_TAB], "bandage": [KEY_H], "weapon_next": [KEY_Q], "horn": [KEY_G],
	"pause": [KEY_ESCAPE], "help": [KEY_F1], "answer_1": [KEY_1, KEY_KP_1], "answer_2": [KEY_2, KEY_KP_2],
	"answer_3": [KEY_3, KEY_KP_3], "answer_4": [KEY_4, KEY_KP_4], "skip": [KEY_ENTER, KEY_KP_ENTER],
	"bribe": [KEY_B], "flee": [KEY_X],
}

var language := "bn"          # "bn" or "en": main language of every line
var show_english := false     # optional second line in English under Bengali text (Settings)
var voices := true
var voice_volume := 80
var mouse_sensitivity := 1.0
var invert_y := false
## Phones, tablets and phone browsers: on-screen joystick and buttons (scripts/ui/TouchControls.gd).
var touch_mode := false
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_settings()
	touch_mode = _detect_touch()
	if touch_mode:
		_strip_mouse_buttons()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func _setup_input() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var mouse := [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT],
		["weapon_next", MOUSE_BUTTON_WHEEL_DOWN], ["weapon_prev", MOUSE_BUTTON_WHEEL_UP]]
	for pair in mouse:
		var action: String = pair[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(action, mb)


func _detect_touch() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return DisplayServer.is_touchscreen_available() and OS.has_feature("web") and not OS.has_feature("pc")


## A tap is also sent as an emulated left click (so menus work); keep taps from firing the pistol.
func _strip_mouse_buttons() -> void:
	for action in ["fire", "aim"]:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)


# --- Text -------------------------------------------------------------------------------------

## The line in the chosen language, falling back to the other one.
func text(line: Variant) -> String:
	if typeof(line) == TYPE_STRING:
		return String(line)
	if typeof(line) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = line
	var main := String(d.get(language, ""))
	if main == "":
		main = String(d.get("en" if language == "bn" else "bn", ""))
	return main


## Main language plus, when enabled, the English line underneath (for Bengali subtitles).
func text2(line: Variant) -> String:
	var main := text(line)
	if typeof(line) == TYPE_DICTIONARY and language == "bn" and show_english:
		var d: Dictionary = line
		var en := String(d.get("en", ""))
		if en != "" and en != main:
			return main + "\n[" + en + "]"
	return main


# --- Settings ---------------------------------------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	language = String(cfg.get_value("game", "language", language))
	show_english = bool(cfg.get_value("game", "show_english", show_english))
	voices = bool(cfg.get_value("game", "voices", voices))
	voice_volume = int(cfg.get_value("game", "voice_volume", voice_volume))
	mouse_sensitivity = float(cfg.get_value("game", "mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(cfg.get_value("game", "invert_y", invert_y))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "show_english", show_english)
	cfg.set_value("game", "voices", voices)
	cfg.set_value("game", "voice_volume", voice_volume)
	cfg.set_value("game", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("game", "invert_y", invert_y)
	cfg.save(SETTINGS_PATH)
	settings_changed.emit()


# --- Flow ---------------------------------------------------------------------------------------

func new_game() -> void:
	GameState.new_game()
	Missions.reset()
	_go(WORLD_SCENE)


func continue_game() -> void:
	if GameState.load_game():
		Missions.reset()
		_go(WORLD_SCENE)
	else:
		new_game()


func to_menu() -> void:
	get_tree().paused = false
	Services.clear()
	_go(MENU_SCENE)


func _go(path: String) -> void:
	get_tree().paused = false
	await fade_to(1.0, 0.35)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	fade_to(0.0, 0.6)


func fade_to(alpha: float, seconds_: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, seconds_)
	await tw.finished
