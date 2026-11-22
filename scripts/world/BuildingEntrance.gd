class_name BuildingEntrance
extends Node3D
## The front-door marker that exists for every nearby building before its interior has been
## generated.  It draws a porch, a door and the building's name; interacting with it asks the
## interior system to build the real building around the player.  The moment the interior exists
## this proxy is removed and the interior's own animated door takes over.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

var building: Dictionary
var system: BuildingInteriorSystem
var _door: InteractiveDoor
var _label := ""


func setup(b: Dictionary, sys: BuildingInteriorSystem) -> void:
	building = b
	system = sys
	_label = BuildingInterior.building_name(b)


func _ready() -> void:
	add_to_group(&"interactable")
	_build()


func _build() -> void:
	var l := BuildingInterior.layout_for(building)
	var ew := float(l["entrance_w"])
	_door = InteractiveDoor.new()
	_door.configure({
		"width": ew, "height": 2.2, "auto_open": false, "locked": false,
		"label": {"bn": "প্রবেশ করো", "en": "Enter"},
		"wood": Color(0.34, 0.22, 0.15),
	})
	_door.interactive = false
	add_child(_door)
	# Porch: two pillars, a lintel and a pair of steps that read as a real entrance on the street.
	var concrete := BuildingMaterials.concrete()
	var paint := BuildingMaterials.wall_colored(Color(0.80, 0.76, 0.68))
	for s in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.16, 2.6, 0.62)
		pillar.mesh = pm
		pillar.position = Vector3(s * (ew * 0.5 + 0.14), 1.3, 0.34)
		pillar.material_override = paint
		add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(ew + 0.6, 0.16, 0.72)
	lintel.mesh = lm
	lintel.position = Vector3(0, 2.62, 0.36)
	lintel.material_override = paint
	add_child(lintel)
	var sill := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(ew + 0.4, 0.08, 0.75)
	sill.mesh = sm
	sill.position = Vector3(0, 0.04, 0.37)
	sill.material_override = concrete
	add_child(sill)
	var lbl := Label3D.new()
	lbl.text = _label
	lbl.font = UiKit.font(true)
	lbl.font_size = 40
	lbl.pixel_size = 0.0032
	lbl.outline_size = 7
	lbl.position = Vector3(0, 2.36, 0.76)
	lbl.modulate = Color(0.98, 0.88, 0.55)
	add_child(lbl)


func interact_options(_player: Node) -> Array:
	return [{"id": "enter", "label": {"bn": "প্রবেশ করো", "en": "Enter"}}]


func display_name() -> Dictionary:
	return {"bn": _label, "en": _label}


func interact(_player: Node, _id: String) -> void:
	if system != null:
		system.enter(building)
