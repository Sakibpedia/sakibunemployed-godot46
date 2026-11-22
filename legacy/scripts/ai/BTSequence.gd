class_name BTSequence
extends BTTask
## Runs children in order until one does not succeed.

var children: Array = []


func _init(kids: Array) -> void:
	children = kids


func tick(actor, dt: float) -> int:
	for c in children:
		var r: int = c.tick(actor, dt)
		if r != SUCCESS:
			return r
	return SUCCESS
