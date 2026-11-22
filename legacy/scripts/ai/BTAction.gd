class_name BTAction
extends BTTask
## Runs a callable that returns SUCCESS, FAILURE or RUNNING.

var run: Callable


func _init(fn: Callable) -> void:
	run = fn


func tick(actor, dt: float) -> int:
	return run.call(actor, dt)
