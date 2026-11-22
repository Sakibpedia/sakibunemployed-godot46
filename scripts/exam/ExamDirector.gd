extends Node
## The `Exams` autoload: loads both question banks once, keeps the no-repeat session and opens the
## exam panel for any situation (gate, street duel, dying words, ghost, police stop, viva, job
## interview, poster quiz, tuition). The world pauses while the panel is open.
##   Exams.start({"mode": "duel", "speaker": {...}, "face": "m_mustache", "family": "bcs", "count": 3, "pass": 2},
##               func(result): ...)
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal exam_finished(ctx: Dictionary, result: Dictionary)

const MODE_TITLES := {
	"gate": {"bn": "দরজার পরীক্ষা", "en": "Gate exam"},
	"duel": {"bn": "রাস্তার প্রশ্ন-লড়াই", "en": "Street question duel"},
	"dying": {"bn": "মৃত্যুর আগের প্রশ্ন", "en": "Dying questions"},
	"ghost": {"bn": "ভূতের প্রশ্ন", "en": "The ghost's question"},
	"police": {"bn": "পুলিশের জেরা", "en": "Police stop"},
	"viva": {"bn": "ভাইভা বোর্ড", "en": "Viva board"},
	"interview": {"bn": "চাকরির ইন্টারভিউ", "en": "Job interview"},
	"poster": {"bn": "পোস্টারের কুইজ", "en": "Poster quiz"},
	"tuition": {"bn": "টিউশনি", "en": "Tuition"},
	"bar": {"bn": "বার কাউন্সিল অনুশীলন", "en": "Bar Council practice"},
	"prelim": {"bn": "বিসিএস প্রিলিমিনারি", "en": "BCS preliminary"},
}

var bank: QuestionBank
var session: ExamSession
var _panel: ExamPanel = null
var _was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bank = QuestionBank.new()
	bank.load_all()
	session = ExamSession.new(bank)


func is_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


func title_for(mode: String) -> Dictionary:
	return MODE_TITLES.get(mode, MODE_TITLES["gate"])


## ctx keys: mode, speaker{bn,en}, face, family, subject, category, cited_only, count, pass, seconds,
## stakes{bn,en}, allow_bribe, bribe_cost, allow_flee, taunts (category for wrong answers), reward_money
func start(ctx: Dictionary, done: Callable) -> void:
	if is_open():
		return
	var filter := {"family": String(ctx.get("family", "")), "subject": String(ctx.get("subject", "")),
		"category": String(ctx.get("category", "")), "cited_only": bool(ctx.get("cited_only", false)),
		"max_difficulty": int(ctx.get("max_difficulty", 3))}
	var n := int(ctx.get("count", 3))
	var items := session.draw(filter, n)
	if items.is_empty():
		var empty := {"passed": true, "right": 0, "wrong": 0, "total": 0, "bribed": false, "fled": false, "timed_out": 0, "items": []}
		if done.is_valid():
			done.call(empty)
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel = ExamPanel.new()
	get_tree().root.add_child(_panel)
	_panel.finished.connect(_on_finished.bind(ctx, done))
	_panel.open(ctx, items, session)


func _on_finished(result: Dictionary, ctx: Dictionary, done: Callable) -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	get_tree().paused = _was_paused
	if not _was_paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if bool(result.get("bribed", false)):
		GameState.bump("bribes")
		GameState.change_honesty(-6)
	exam_finished.emit(ctx, result)
	if done.is_valid():
		done.call(result)
