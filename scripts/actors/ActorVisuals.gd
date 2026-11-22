class_name ActorVisuals
extends Node3D
## The visible half of a Citizen: the skinned HumanoidRig, a speech bubble (Label3D) and an
## optional marker above the head (mission target, gatekeeper, quiz challenger).
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

var actor: Node3D
var rig: HumanoidRig
var _bubble: Label3D
var _bubble_t := 0.0
var _marker: Sprite3D


func setup(a: Node3D) -> void:
	actor = a
	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	var prof: Dictionary = a.get("profile")
	rig.build(prof.get("look", {}))
	var h := float((prof.get("look", {}) as Dictionary).get("height", 1.7))
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font = UiKit.font(true)
	_bubble.font_size = 40
	_bubble.pixel_size = 0.004
	_bubble.outline_size = 12
	_bubble.modulate = UiKit.PAPER
	_bubble.outline_modulate = Color(0.04, 0.08, 0.1, 0.9)
	_bubble.width = 900.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.position = Vector3(0, h + 0.45, 0)
	_bubble.no_depth_test = false
	_bubble.visible = false
	_bubble.visibility_range_end = 30.0
	add_child(_bubble)


func bubble(text: String, seconds: float) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = seconds


## kind: "" (none), "target", "gatekeeper", "quiz", "mission"
func set_marker(kind: String) -> void:
	if kind == "":
		if _marker:
			_marker.visible = false
		return
	if _marker == null:
		_marker = Sprite3D.new()
		_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marker.pixel_size = 0.006
		_marker.no_depth_test = true
		_marker.render_priority = 10
		var prof: Dictionary = actor.get("profile")
		var h := float((prof.get("look", {}) as Dictionary).get("height", 1.7))
		_marker.position = Vector3(0, h + 0.9, 0)
		add_child(_marker)
	var svg := {"target": "marker_enemy", "gatekeeper": "marker_gatekeeper", "quiz": "marker_gatekeeper", "mission": "marker_objective"}
	_marker.texture = UiKit.tex(String(svg.get(kind, "marker_objective")))
	_marker.modulate = Color(1, 1, 1) if kind != "quiz" else UiKit.TEAL
	_marker.visible = true


func _process(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.visible = false
