class_name Animated
extends Node3D
## Small looping animations for the world: ceiling fans, laundry, kites, pigeons, bobbing items.

var mode := "spin"
var speed := 1.0
var amp := 1.0
var _t := 0.0
var _base := Vector3.ZERO
var _phase := 0.0


func _ready() -> void:
	_base = position
	_phase = fmod(absf(position.x * 0.37 + position.z * 0.71), TAU)


func _process(delta: float) -> void:
	_t += delta
	var t := _t * speed + _phase
	match mode:
		"spin":
			rotation.y += delta * speed * 9.0
		"sway":
			rotation.z = sin(t * 1.7) * 0.12 * amp
			rotation.x = sin(t * 1.1) * 0.05 * amp
		"kite":
			position = _base + Vector3(sin(t * 0.7) * 5.0, sin(t * 1.3) * 1.6, cos(t * 0.5) * 3.0) * amp
			rotation.z = sin(t * 2.1) * 0.5
			rotation.y = sin(t * 0.4) * 0.6
		"circle":
			position = _base + Vector3(cos(t) * 9.0, sin(t * 2.0) * 0.8, sin(t) * 9.0) * amp
			rotation.y = -t
		"bob":
			position.y = _base.y + sin(t * 2.0) * 0.08 * amp
			rotation.y += delta
