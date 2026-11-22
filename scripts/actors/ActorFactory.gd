class_name ActorFactory
extends RefCounted
## Builds people with their dependencies injected: the Services container goes into the Citizen
## and from there into ActorAI, ActorHealth and ActorVisuals. Nothing in an actor reaches for a
## world node by path.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.


static func spawn(profile: Dictionary, parent: Node, pos: Vector3, yaw: float = 0.0) -> Citizen:
	var c := Citizen.new()
	parent.add_child(c)
	c.setup(profile, Services)
	c.global_position = pos
	c.rotation.y = yaw
	return c


## A named story character from Data/Story/characters.json: the generator gives the body, the
## record overrides name, face, outfit, colours, profession and voice.
static func spawn_character(rec: Dictionary, parent: Node, pos: Vector3, yaw: float = 0.0) -> Citizen:
	var p := PersonGenerator.make(hash(String(rec.get("id", "x"))), String(rec.get("role", "ped")), "")
	p["id"] = String(rec.get("id", p["id"]))
	if rec.has("name"):
		p["name"] = rec["name"]
	if rec.has("profession"):
		p["profession"] = String(rec["profession"])
	if rec.has("family"):
		p["family"] = String(rec["family"])
	if rec.has("armed"):
		p["armed"] = bool(rec["armed"])
	if rec.has("hp"):
		p["hp"] = float(rec["hp"])
	var look: Dictionary = p["look"]
	if rec.has("face"):
		var face := String(rec["face"])
		p["face"] = face
		look["face"] = face
		var fr := DhakaMaterials.face_record(face)
		if not fr.is_empty():
			var sk: Array = fr.get("skin", [0.62, 0.45, 0.33])
			look["skin"] = Color(float(sk[0]), float(sk[1]), float(sk[2]))
			var hc: Array = fr.get("hair", [0.05, 0.04, 0.04])
			look["hair"] = Color(float(hc[0]), float(hc[1]), float(hc[2]))
			look["hair_style"] = String(fr.get("style", "short"))
			look["gender"] = "f" if bool(fr.get("female", false)) else "m"
			p["gender"] = look["gender"]
	for k in ["outfit", "cloth", "lower_cloth", "build", "cap"]:
		if rec.has(k):
			look[k] = rec[k]
	for k in ["shirt", "lower"]:
		if rec.has(k):
			var ca: Array = rec[k]
			look[k] = Color(float(ca[0]), float(ca[1]), float(ca[2]))
	if rec.has("voice"):
		p["voice"] = rec["voice"]
	p["look"] = look
	var c := spawn(p, parent, pos, yaw)
	c.persistent = true
	return c
