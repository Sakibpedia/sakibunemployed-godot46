extends Node
## Career advice and life consequences (design doc Section 8).
## Outcome = fit + follow-through + credibility + world + entanglement.
## 3 or more: grateful. 1 to 2: mixed. 0 or less: bitter. No hidden dice.

signal advice_given(person: String, option: String)
signal callback_resolved(person: String, outcome: String, terms: Dictionary)

const DATA_PATH := "res://Data/CareerAdvice/scenarios.json"

var scenarios: Dictionary = {}    # person -> scenario
var links: Array = []             # entanglements (Section 8.4)
var given: Dictionary = {}        # person -> {option, level, honesty, follow_through}
var outcomes: Dictionary = {}     # person -> {outcome, terms}


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Career advice data missing: %s" % DATA_PATH)
		return
	for sc in data.get("scenarios", []):
		scenarios[sc.person] = sc
	links = data.get("entanglements", [])


func give_advice(person: String, option: String) -> Dictionary:
	var sc: Dictionary = scenarios.get(person, {})
	var opt: Dictionary = sc.get("options", {}).get(option, {})
	if opt.is_empty():
		return {}
	given[person] = {
		"option": option, "level": WorldState.level,
		"honesty": int(WorldState.reputation.get("exam_honesty", 60)), "follow_through": false,
	}
	if opt.get("corrupt", false):
		WorldState.change_rep("exam_honesty", -10)
	for e in opt.get("immediate", []):
		ExamGate.apply_effect(e)
	advice_given.emit(person, option)
	_prefetch_callback_lines(person)
	return opt


func mark_follow_through(person: String) -> void:
	if given.has(person):
		given[person].follow_through = true


func score(person: String) -> Dictionary:
	var sc: Dictionary = scenarios.get(person, {})
	var g: Dictionary = given.get(person, {})
	if sc.is_empty() or g.is_empty():
		return {}
	var fit := int(sc.options[g.option].fit)
	var follow := 1 if g.follow_through else 0
	var honesty := int(g.honesty)
	var cred := 1 if honesty >= 60 else (-1 if honesty <= 30 else 0)
	var control := String(WorldState.sector(sc.get("home_sector", "")).control)
	var world := 1 if control == "sakib" else (-1 if control == "syndicate" else 0)
	var ent := _entanglement(person)
	var total := fit + follow + cred + world + ent
	var outcome := "grateful" if total >= 3 else ("mixed" if total >= 1 else "bitter")
	return {"fit": fit, "follow_through": follow, "credibility": cred, "world": world,
		"entanglement": ent, "total": total, "outcome": outcome}


## Call when the person appears at their callback level. Returns "grateful", "mixed" or "bitter".
func resolve_callback(person: String) -> String:
	var terms := score(person)
	var outcome: String = terms.get("outcome", "mixed")
	outcomes[person] = {"outcome": outcome, "terms": terms}
	callback_resolved.emit(person, outcome, terms)
	return outcome


func _entanglement(person: String) -> int:
	var total := 0
	for link in links:
		if link.target != person:
			continue
		if _condition_met(link):
			total += int(link.effect)
	return clampi(total, -1, 1)


func _condition_met(link: Dictionary) -> bool:
	# Only facts already known at callback time count; anything later is ignored.
	for who in link.get("when_option", {}):
		if given.get(who, {}).get("option", "") != link.when_option[who]:
			return false
	for who in link.get("when_outcome", {}):
		if outcomes.get(who, {}).get("outcome", "") != link.when_outcome[who]:
			return false
	return true


func _prefetch_callback_lines(person: String) -> void:
	var sc: Dictionary = scenarios[person]
	var g: Dictionary = given[person]
	var opt: Dictionary = sc.options[g.option]
	for tone in ["grateful", "mixed", "bitter"]:
		LLMBridge.prefetch("callback", "%s/%s" % [person, tone], {
			"name": person, "age": sc.get("age", ""), "role": sc.get("role", ""),
			"area": sc.get("area", "Jatrabari"), "level_then": g.level,
			"advice_label": opt.get("label", ""), "outcome_summary": sc.get("summary_" + tone, ""),
			"tone": tone, "callback_action": sc.get("callback_" + tone, ""),
		})


func to_dict() -> Dictionary:
	return {"given": given, "outcomes": outcomes}


func from_dict(d: Dictionary) -> void:
	given = d.get("given", {})
	outcomes = d.get("outcomes", {})
