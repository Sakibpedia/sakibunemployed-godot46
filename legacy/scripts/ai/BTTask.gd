class_name BTTask
extends RefCounted
## Built-in behaviour tree (replaces LimboAI in the playable build). Every task returns one status.

const SUCCESS := 0
const FAILURE := 1
const RUNNING := 2


func tick(_actor, _dt: float) -> int:
	return FAILURE
