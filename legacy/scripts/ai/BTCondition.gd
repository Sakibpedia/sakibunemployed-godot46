class_name BTCondition
extends BTTask
## Succeeds when its check returns true.

var check: Callable


func _init(fn: Callable) -> void:
	check = fn


func tick(actor, _dt: float) -> int:
	return SUCCESS if check.call(actor) else FAILURE
