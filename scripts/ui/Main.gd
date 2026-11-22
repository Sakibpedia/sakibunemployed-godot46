extends Control
## Main menu, in Bengali: new game, continue, the exam practice room (BCS, job, Bar), settings
## (graphics, render scale, language, voices, English subtitles), credits and copyright.
## The logo is S M Nazmuz Sakib's portrait (icon.png).
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

var _menu: VBoxContainer
var _settings: VBoxContainer
var _status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var bg := ColorRect.new()
	bg.color = UiKit.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 80
	row.offset_top = 60
	row.offset_right = -80
	row.offset_bottom = -40
	row.add_theme_constant_override("separation", 60)
	add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.png") if ResourceLoader.exists("res://icon.png") else null
	logo.custom_minimum_size = Vector2(320, 320)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(logo)
	var t := UiKit.label("এস এম নাজমুয সাকিব\nবেকার", 54, UiKit.MARIGOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(t)
	var sub := UiKit.label("যাত্রাবাড়ী · দনিয়া · সোনটেক · কাজলা · জুরাইন", 22, UiKit.PAPER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(sub)
	var dev := UiKit.label("ডেভেলপ করেছেন এস এম নাজমুয সাকিব", 20, UiKit.DIM)
	dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(dev)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	right.add_child(_menu)
	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override("separation", 12)
	_settings.visible = false
	right.add_child(_settings)
	_status = UiKit.label("", 18, UiKit.DIM)
	right.add_child(_status)
	_build_menu()
	_build_settings()
	var bank: QuestionBank = Exams.bank
	_status.text = "প্রশ্নভান্ডার: %s টি প্রশ্ন (%s টি বাস্তব প্রশ্নপত্র থেকে)" % [UiKit.bengali_digits(str(bank.items.size())), UiKit.bengali_digits(str(bank.cited_count()))]


func _btn(parent: Container, text: String, cb: Callable) -> Button:
	var b := UiKit.button(text, 26)
	b.custom_minimum_size = Vector2(520, 58)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_menu() -> void:
	if GameState.has_save():
		_btn(_menu, "চালিয়ে যাও", Game.continue_game)
	_btn(_menu, "নতুন খেলা", Game.new_game)
	_btn(_menu, "প্রশ্ন অনুশীলন: বিসিএস", func() -> void: _practice("bcs"))
	_btn(_menu, "প্রশ্ন অনুশীলন: চাকরি", func() -> void: _practice("job"))
	_btn(_menu, "প্রশ্ন অনুশীলন: বার কাউন্সিল", func() -> void: _practice("bar"))
	_btn(_menu, "সেটিংস", func() -> void:
		_menu.visible = false
		_settings.visible = true)
	_btn(_menu, "ক্রেডিট", func() -> void: get_tree().change_scene_to_file("res://scenes/ui/Credits.tscn"))
	_btn(_menu, "কপিরাইট", func() -> void: get_tree().change_scene_to_file("res://scenes/ui/Copyright.tscn"))
	_btn(_menu, "বের হও", func() -> void: get_tree().quit())


func _build_settings() -> void:
	for c in _settings.get_children():
		c.queue_free()
	var q := String(RenderQuality.NAMES[RenderQuality.saved()])
	_btn(_settings, "গ্রাফিক্স: %s" % q, func() -> void:
		RenderQuality.cycle(get_viewport(), null)
		_build_settings())
	_btn(_settings, "রেন্ডার স্কেল: %s%%" % UiKit.bengali_digits(str(int(RenderQuality.render_scale() * 100))), func() -> void:
		RenderQuality.cycle_render_scale(get_viewport())
		_build_settings())
	_btn(_settings, "ভাষা: %s" % ("বাংলা" if Game.language == "bn" else "English"), func() -> void:
		Game.language = "en" if Game.language == "bn" else "bn"
		Game.save_settings()
		_build_settings())
	_btn(_settings, "ইংরেজি সাবটাইটেল: %s" % ("চালু" if Game.show_english else "বন্ধ"), func() -> void:
		Game.show_english = not Game.show_english
		Game.save_settings()
		_build_settings())
	var voice_note := "" if Voice.has_bengali_voice() else " (বাংলা কণ্ঠ ইনস্টল নেই, ইংরেজিতে বলবে)"
	_btn(_settings, "কণ্ঠ: %s%s" % ["চালু" if Game.voices else "বন্ধ", voice_note], func() -> void:
		Game.voices = not Game.voices
		Game.save_settings()
		_build_settings())
	_btn(_settings, "ফিরে যাও", func() -> void:
		_settings.visible = false
		_menu.visible = true)


func _practice(family: String) -> void:
	var names := {"bcs": "বিসিএস প্রিলিমিনারি অনুশীলন", "job": "চাকরির পরীক্ষার অনুশীলন", "bar": "বার কাউন্সিল অনুশীলন"}
	Exams.start({"mode": "prelim" if family != "bar" else "bar", "speaker": {"bn": String(names[family]), "en": family},
		"family": family, "count": 10, "pass": 6, "seconds": 30.0, "allow_flee": true,
		"stakes": {"bn": "দশটার মধ্যে ছয়টা ঠিক হলে পাস", "en": "Six out of ten to pass"}}, func(r: Dictionary) -> void:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_status.text = "ফল: %s/%s ঠিক" % [UiKit.bengali_digits(str(int(r.get("right", 0)))), UiKit.bengali_digits(str(int(r.get("total", 0))))])
