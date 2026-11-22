extends Control
## The ending: which way Sakib went (honesty and the people he advised), the run's numbers,
## all sixteen career outcomes, and the credits line.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.07)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	margin.add_child(box)

	var honesty := int(WorldState.reputation.get("exam_honesty", 60))
	var moral := int(WorldState.reputation.get("moral", 0))
	var tally := {"grateful": 0, "mixed": 0, "bitter": 0}
	for person in CareerAdvice.outcomes:
		var o := String(CareerAdvice.outcomes[person].get("outcome", "mixed"))
		tally[o] = int(tally.get(o, 0)) + 1
	var ending := _ending(honesty, int(tally.grateful))
	_text(box, ending[0], 44, Color(1.0, 0.88, 0.5))
	_text(box, ending[1], 22, Color.WHITE)
	if moral <= -30:
		_text(box, "Some faces from those weeks still look away when he passes the tea stall.", 20, Color(1.0, 0.65, 0.6))
	_text(box, "He is still unemployed. But Jatrabari knows his name.", 22, Color(0.85, 0.85, 0.85))

	_text(box, "The run", 28, Color(1.0, 0.88, 0.5))
	var s: Dictionary = Game.stats
	_text(box, "Questions answered %d (right first time %d) · gates passed %d, failed %d · bribes %d\nEnemies killed %d, knocked out %d · last wishes heard %d · intel %d · deaths %d\nHonesty %d · moral %d · grateful %d, mixed %d, bitter %d" % [
		int(s.get("answered", 0)), int(s.get("first_try_right", 0)), int(s.get("gates_passed", 0)), int(s.get("gates_failed", 0)),
		int(s.get("bribes", 0)), int(s.get("kills", 0)), int(s.get("knockouts", 0)), int(s.get("last_wishes", 0)),
		int(s.get("intel", 0)), int(s.get("deaths", 0)), honesty, moral, int(tally.grateful), int(tally.mixed), int(tally.bitter)], 18, Color.WHITE)

	_text(box, "The people he advised", 28, Color(1.0, 0.88, 0.5))
	for person in CareerAdvice.scenarios:
		var sc: Dictionary = CareerAdvice.scenarios[person]
		var g: Dictionary = CareerAdvice.given.get(person, {})
		var out: Dictionary = CareerAdvice.outcomes.get(person, {})
		var line := "%s (%s): " % [person, String(sc.get("role", ""))]
		if g.is_empty():
			line += "never asked"
		else:
			line += String(sc.options[g.option].get("label", ""))
			if not out.is_empty():
				var o := String(out.get("outcome", ""))
				line += "  →  %s: %s" % [o, String(sc.get("summary_" + o, ""))]
		_text(box, line, 17, Color(0.9, 0.9, 0.9))

	_text(box, "Developed by S M Nazmuz Sakib", 30, Color.WHITE)
	_text(box, "© 2026 S M Nazmuz Sakib. All rights reserved.", 18, Color(0.8, 0.8, 0.8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	box.add_child(row)
	_button(row, "Credits", func() -> void: get_tree().change_scene_to_file("res://scenes/ui/Credits.tscn"))
	_button(row, "Copyright", func() -> void: get_tree().change_scene_to_file("res://scenes/ui/Copyright.tscn"))
	_button(row, "Main menu", Game.to_menu)
	Game.fade_to(0.0, 0.8)


func _ending(honesty: int, grateful: int) -> Array:
	if honesty >= 60 and grateful >= 8:
		return ["The honest way", "Kibria's coaching centre is shut and the leak is on the front page. In spring Sakib sits the BCS preliminary with nothing in his pocket but a pencil, and the people he once advised wait outside the hall to walk him home."]
	if honesty >= 60:
		return ["Clean hands", "The syndicate is broken, but Jatrabari is tired, and fewer doors open when Sakib knocks. He studies alone on the roof every evening, and comes down before six."]
	if honesty >= 30:
		return ["Grey", "Some gates he answered and some he bought. The leak is gone; the habit of paying for doors is not. Sakib keeps his receipts in the back of his notebook and does not look at them."]
	return ["The new broker", "The syndicate is gone, and people now pay Sakib to get them through doors. He tells himself it is different, because he knows the answers."]


func _text(parent: Node, text: String, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1500, 0)
	l.add_theme_font_size_override(&"font_size", size)
	l.modulate = col
	parent.add_child(l)


func _button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 46)
	b.pressed.connect(cb)
	parent.add_child(b)
