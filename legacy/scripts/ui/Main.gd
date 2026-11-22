extends Control
## Main menu: New game, Continue, Level select, the Exam Room (try any gate or practise a set),
## Credits, Copyright and Quit.

const GATES := [
	["Level 1: the doorman (5 questions)", "L01_doorman"],
	["Level 1: the pen counter (chain tutorial)", "L01_pen"],
	["Level 2: the rickshaw (3 + 2 road signs)", "L02_rickshaw"],
	["Level 4: the principal (10 questions)", "L04_principal"],
	["Level 14: the invigilator (20 s a question)", "L14_invigilator"],
	["Level 15: the trial (Bar Council)", "L15_trial"],
]
const PRACTICE_SETS := ["G", "SP", "BAR", "RS", "P1", "P2", "P5", "MAT-PEN", "MAT-BAT", "MAT-SALT", "MAT-MED",
	"MAT-FUEL", "LW-GUN", "LW-BLEED", "LW-BLAST", "LW-SHOCK", "LW-DROWN", "VEH-BOAT", "VEH-RICKSHAW", "VEH-CNG"]

var _menu: VBoxContainer
var _exam: VBoxContainer
var _levels: OptionButton
var _sets: OptionButton
var _titles: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.08)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.position = Vector2(110, 70)
	row.add_theme_constant_override(&"separation", 60)
	add_child(row)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 10)
	row.add_child(_menu)
	_exam = VBoxContainer.new()
	_exam.add_theme_constant_override(&"separation", 10)
	_exam.visible = false
	row.add_child(_exam)
	_titles = _level_titles()
	_build_menu()
	_build_exam_room()
	Game.fade_to(0.0, 0.4)


func _build_menu() -> void:
	var logo := TextureRect.new()
	logo.texture = load("res://art/logo.png")
	logo.custom_minimum_size = Vector2(170, 170)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_menu.add_child(logo)
	_title(_menu, "S M Nazmuz Sakib is unemployed", 46)
	_title(_menu, "Developed by S M Nazmuz Sakib  ·  %d cited exam questions loaded" % ExamGate.item_count(), 18)
	_item(_menu, "New game", Game.start_new)
	if Game.has_save():
		_item(_menu, "Continue (level %d)" % clampi(Game.current, 1, Game.LEVEL_COUNT), Game.continue_game)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override(&"separation", 8)
	_levels = OptionButton.new()
	_levels.custom_minimum_size = Vector2(380, 44)
	for i in range(1, mini(Game.unlocked, Game.LEVEL_COUNT) + 1):
		_levels.add_item("Level %d: %s" % [i, _titles[i - 1] if i - 1 < _titles.size() else ""], i)
	lrow.add_child(_levels)
	var play := Button.new()
	play.text = "Play from here"
	play.custom_minimum_size = Vector2(150, 44)
	play.pressed.connect(func() -> void: Game.start_at(_levels.get_selected_id()))
	lrow.add_child(play)
	_menu.add_child(lrow)
	_item(_menu, "Exam Room: try any gate, practise any set", func() -> void:
		_menu.visible = false
		_exam.visible = true
	)
	var gfx := Button.new()
	gfx.text = "Graphics: %s" % RenderQuality.NAMES[RenderQuality.saved()]
	gfx.custom_minimum_size = Vector2(540, 44)
	gfx.alignment = HORIZONTAL_ALIGNMENT_LEFT
	gfx.pressed.connect(func() -> void:
		var tier := RenderQuality.cycle(get_viewport(), null)
		gfx.text = "Graphics: %s" % RenderQuality.NAMES[tier]
	)
	_menu.add_child(gfx)
	_item(_menu, "Credits", func() -> void: get_tree().change_scene_to_file("res://scenes/ui/Credits.tscn"))
	_item(_menu, "Copyright", func() -> void: get_tree().change_scene_to_file("res://scenes/ui/Copyright.tscn"))
	_item(_menu, "Quit", func() -> void: get_tree().quit())
	_title(_menu, "WASD move · mouse look · E talk/use · F takedown · Tab notebook · F1 controls in game", 16)


func _build_exam_room() -> void:
	_title(_exam, "Exam Room", 36)
	_title(_exam, "Every question is a real past paper item with its source. Get one wrong and the gatekeeper asks around it.", 16)
	for g in GATES:
		_item(_exam, g[0], _open_gate.bind(g[1]))
	var row := HBoxContainer.new()
	_sets = OptionButton.new()
	for s in PRACTICE_SETS:
		_sets.add_item(s)
	row.add_child(_sets)
	var go := Button.new()
	go.text = "Practise this set (5 questions)"
	go.pressed.connect(_practice)
	row.add_child(go)
	_exam.add_child(row)
	_item(_exam, "Back", func() -> void:
		_exam.visible = false
		_menu.visible = true
	)


func _level_titles() -> Array:
	var out: Array = []
	for i in range(1, Game.LEVEL_COUNT + 1):
		var path := "res://Data/Levels/L%02d.json" % i
		var data = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		out.append(String(data.get("title", "")) if typeof(data) == TYPE_DICTIONARY else "")
	return out


func _open_gate(gate_id: String) -> void:
	WorldState.add_resource("study_tokens", 1)   # one token to try the strike-two button
	var def := ExamGate.load_gate(gate_id)
	if def.is_empty():
		return
	WorldState.level = int(def.get("level", 1))
	_run(ExamGate.open_gate(def))


func _practice() -> void:
	var set_code := _sets.get_item_text(_sets.selected)
	_run(ExamGate.open_gate({"gate_id": "practice_%s_%d" % [set_code, Time.get_ticks_msec()],
		"gatekeeper": "Exam Room", "category": "practice", "size": 5, "draw": {"sets": [set_code]}}))


func _run(session: ExamSession) -> void:
	if session == null:
		push_warning("Gate unavailable (locked, cooling down, or no items left for this level)")
		return
	_exam.visible = false
	var ui := preload("res://scripts/ui/ExamGateUI.gd").new()
	add_child(ui)
	ui.open(session)
	ui.closed.connect(func() -> void: _exam.visible = true)


func _title(parent: Node, text: String, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	l.add_theme_font_size_override(&"font_size", size)
	parent.add_child(l)


func _item(parent: Node, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(540, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	parent.add_child(b)
