extends Node
## Dependency-injection container. The open world registers its systems here; ActorFactory hands
## this object to every person it builds, so actors call `services.city`, `services.heat` and so on
## instead of reaching into globals. Cross-system signals live here too.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

signal crime(kind: String, position: Vector3, by_player: bool)
signal gunshot(position: Vector3)
signal person_died(citizen: Node, peaceful: bool)
signal person_downed(citizen: Node)
signal ghost_banished(spirit_id: String)
signal poster_read(poster: Dictionary)
signal toast(line: Dictionary, kind: String)
signal subtitle(speaker: Dictionary, line: Dictionary, seconds: float)

var world: Node3D = null
var city = null            # CityData (RefCounted); untyped to avoid load-order cycles
var player: Node3D = null
var hud: CanvasLayer = null
var atmosphere: Node3D = null
var heat: Node = null
var ghosts: Node3D = null
var peds: Node3D = null
var traffic: Node3D = null
var posters: Node3D = null
var interiors: Node3D = null
var rng := RandomNumberGenerator.new()

var _extra: Dictionary = {}


func _ready() -> void:
	rng.seed = 20261119


func register(service_name: String, obj: Object) -> void:
	_extra[service_name] = obj


func get_service(service_name: String) -> Object:
	return _extra.get(service_name, null)


func clear() -> void:
	world = null
	city = null
	player = null
	hud = null
	atmosphere = null
	heat = null
	ghosts = null
	peds = null
	traffic = null
	posters = null
	interiors = null
	_extra.clear()


func has_world() -> bool:
	return world != null and is_instance_valid(world)


## Short helper for toasts: Services.say_toast({"bn": "...", "en": "..."})
func say_toast(line: Dictionary, kind: String = "info") -> void:
	toast.emit(line, kind)


func report_crime(kind: String, position: Vector3, by_player: bool = true) -> void:
	crime.emit(kind, position, by_player)
	if by_player and heat != null and heat.has_method(&"add_crime"):
		heat.add_crime(kind, position)
