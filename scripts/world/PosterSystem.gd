class_name PosterSystem
extends Node3D
## The posters on Dhaka's walls, as at the start of the project brief: coaching adverts, BCS
## circulars, bank and teacher job notices, Bar Council courses, "100% common" question-leak
## adverts, To-Let and mess notices. Each is a quad on a wall with a texture drawn once in a
## SubViewport (so the Bengali text is shaped properly). Reading one (E) teaches a fact (a question
## with its answer from the bank) or offers a quiz; leak posters can be torn down (honesty up, the
## gang notices) or used (honesty down, a study token).
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const KINDS := {
	"coaching": [{"t": {"bn": "শর্টকাট কোচিং", "en": "Shortcut Coaching"}, "s": {"bn": "বিসিএস প্রিলি স্পেশাল ব্যাচ\n১০০% গ্যারান্টি!", "en": "BCS prelim special batch\n100% guaranteed!"}, "bg": Color(0.95, 0.85, 0.15), "fg": Color(0.75, 0.05, 0.1)},
		{"t": {"bn": "কনফিডেন্স কোচিং", "en": "Confidence Coaching"}, "s": {"bn": "ব্যাংক জব মডেল টেস্ট\nপ্রতি শুক্রবার", "en": "Bank job model tests\nevery Friday"}, "bg": Color(0.1, 0.35, 0.7), "fg": Color(1, 1, 1)},
		{"t": {"bn": "ক্যাডার ফ্যাক্টরি", "en": "Cadre Factory"}, "s": {"bn": "লিখিত + ভাইভা\nএক প্যাকেজে", "en": "Written + viva\nin one package"}, "bg": Color(0.85, 0.1, 0.25), "fg": Color(1, 0.95, 0.6)}],
	"circular": [{"t": {"bn": "বিসিএস পরীক্ষার বিজ্ঞপ্তি", "en": "BCS examination notice"}, "s": {"bn": "প্রিলিমিনারি পরীক্ষার\nআবেদন চলছে", "en": "Applications open for\nthe preliminary"}, "bg": Color(0.95, 0.95, 0.92), "fg": Color(0.1, 0.25, 0.15)},
		{"t": {"bn": "নিয়োগ বিজ্ঞপ্তি", "en": "Recruitment notice"}, "s": {"bn": "প্রবেশপত্র ডাউনলোড\nসাইবার ক্যাফেতে", "en": "Download admit cards\nat the cyber cafe"}, "bg": Color(0.92, 0.92, 0.88), "fg": Color(0.1, 0.1, 0.35)}],
	"job": [{"t": {"bn": "সিনিয়র অফিসার নিয়োগ", "en": "Senior Officer wanted"}, "s": {"bn": "ব্যাংক · স্নাতক পাস\nবয়স ৩০ পর্যন্ত", "en": "Bank · graduates\nage up to 30"}, "bg": Color(0.15, 0.5, 0.3), "fg": Color(1, 1, 1)},
		{"t": {"bn": "সহকারী শিক্ষক নিয়োগ", "en": "Assistant teachers wanted"}, "s": {"bn": "প্রাথমিক বিদ্যালয়\nলিখিত পরীক্ষা", "en": "Primary schools\nwritten test"}, "bg": Color(0.95, 0.7, 0.2), "fg": Color(0.15, 0.1, 0.05)}],
	"bar": [{"t": {"bn": "বার কাউন্সিল প্রস্তুতি", "en": "Bar Council preparation"}, "s": {"bn": "এমসিকিউ + লিখিত + ভাইভা\nআইনজীবীর চেম্বারে", "en": "MCQ + written + viva\nat the lawyer's chamber"}, "bg": Color(0.12, 0.12, 0.14), "fg": Color(0.95, 0.85, 0.5)}],
	"leak": [{"t": {"bn": "প্রশ্ন চাই?", "en": "Want the questions?"}, "s": {"bn": "১০০% কমন!\nযোগাযোগ: ০১৭XX-XXXXXX", "en": "100% common!\nCall: 017XX-XXXXXX"}, "bg": Color(0.6, 0.0, 0.05), "fg": Color(1, 1, 0.3)},
		{"t": {"bn": "পরীক্ষার আগের রাতে", "en": "The night before the exam"}, "s": {"bn": "আসল প্রশ্ন · গোপনে\nকাজলা ফ্লাইওভারের নিচে", "en": "The real paper · discreetly\nunder the Kajla flyover"}, "bg": Color(0.08, 0.08, 0.08), "fg": Color(0.95, 0.2, 0.2)}],
	"notice": [{"t": {"bn": "টু-লেট", "en": "TO-LET"}, "s": {"bn": "মেস সিট খালি\nশুধু ব্যাচেলর", "en": "Mess seat free\nbachelors only"}, "bg": Color(0.95, 0.95, 0.95), "fg": Color(0.8, 0.05, 0.05)},
		{"t": {"bn": "হারানো বিজ্ঞপ্তি", "en": "Lost"}, "s": {"bn": "এসএসসি সনদপত্র\nপেলে যোগাযোগ করুন", "en": "SSC certificate\nplease contact"}, "bg": Color(0.9, 0.9, 0.82), "fg": Color(0.1, 0.1, 0.1)}],
}
const FAMILY := {"coaching": "bcs", "circular": "bcs", "job": "job", "bar": "bar", "leak": "bcs", "notice": "bcs"}

var city: CityData
var posters: Array = []          # {data, node}
var _textures: Dictionary = {}   # "kind_variant" -> Texture2D


func setup(c: CityData) -> void:
	city = c
	for kind in KINDS:
		var list: Array = KINDS[kind]
		for v in list.size():
			_textures["%s_%d" % [kind, v]] = _make_texture(list[v])
	for pd in city.posters:
		var d: Dictionary = pd
		var kind := String(d.get("kind", "coaching"))
		var list: Array = KINDS.get(kind, KINDS["coaching"])
		var v := int(d.get("variant", 0)) % list.size()
		var torn := GameState.posters_torn.has(String(d["id"]))
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.62, 0.86)
		mi.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_texture = _textures["%s_%d" % [kind, v]]
		m.roughness = 0.85
		mi.material_override = m
		var n := Vector3(float(d["nx"]), 0, float(d["nz"]))
		var pos := Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
		mi.transform = Transform3D(Basis(Vector3.UP, atan2(n.x, n.z)), pos)
		mi.rotate_object_local(Vector3(0, 0, 1), randf_range(-0.08, 0.08))
		mi.visibility_range_end = 45.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = not torn
		add_child(mi)
		posters.append({"data": d, "node": mi})


func _make_texture(spec: Dictionary) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(384, 532)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = spec["bg"]
	bg.size = Vector2(384, 532)
	vp.add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = (spec["fg"] as Color)
	stripe.position = Vector2(0, 400)
	stripe.size = Vector2(384, 18)
	vp.add_child(stripe)
	var t := UiKit.label(Game.text(spec["t"]), 46, spec["fg"], true)
	t.add_theme_constant_override("outline_size", 0)
	t.position = Vector2(18, 40)
	t.size = Vector2(348, 200)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(t)
	var s := UiKit.label(Game.text(spec["s"]), 30, spec["fg"], false)
	s.add_theme_constant_override("outline_size", 0)
	s.position = Vector2(18, 230)
	s.size = Vector2(348, 160)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(s)
	var foot := UiKit.label("যাত্রাবাড়ী · সোনটেক · দনিয়া", 20, (spec["fg"] as Color), false)
	foot.add_theme_constant_override("outline_size", 0)
	foot.position = Vector2(18, 440)
	foot.size = Vector2(348, 60)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(foot)
	return vp.get_texture()


func nearest(p: Vector3, max_d: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := max_d
	for e in posters:
		var ed: Dictionary = e
		var node: MeshInstance3D = ed["node"]
		if not node.visible:
			continue
		var d := node.global_position.distance_to(p + Vector3(0, 1.4, 0))
		if d < bd:
			bd = d
			best = ed
	return best


func options_for(e: Dictionary) -> Array:
	var d: Dictionary = e["data"]
	var opts: Array = [{"id": "read", "label": {"bn": "পোস্টার পড়ো", "en": "Read the poster"}}]
	if String(d["kind"]) == "leak":
		opts.append({"id": "tear", "label": {"bn": "ছিঁড়ে ফেলো", "en": "Tear it down"}})
	elif String(d["kind"]) in ["coaching", "circular", "job", "bar"]:
		opts.append({"id": "quiz", "label": {"bn": "পোস্টারের কুইজ", "en": "Poster quiz"}})
	return opts


func use(e: Dictionary, option_id: String) -> void:
	var d: Dictionary = e["data"]
	var id := String(d["id"])
	var kind := String(d["kind"])
	match option_id:
		"read":
			var first := not GameState.posters_read.has(id)
			if first:
				GameState.posters_read.append(id)
				GameState.bump("posters")
			var it: Array = Exams.session.draw({"family": String(FAMILY.get(kind, "bcs"))}, 1)
			var note := {"bn": "", "en": ""}
			if not it.is_empty():
				var item: Dictionary = it[0]
				var bn := QuestionBank.display(item, "bn")
				var en := QuestionBank.display(item, "en")
				var ob: Array = bn["options"]
				var oe: Array = en["options"]
				note = {"bn": "নোট: %s → %s" % [String(bn["text"]), String(ob[int(bn["answer"])]) if ob.size() > 0 else ""],
					"en": "Note: %s → %s" % [String(en["text"]), String(oe[int(en["answer"])]) if oe.size() > 0 else ""]}
			if kind == "leak" and first:
				GameState.change_honesty(-1)
			if first and GameState.posters_read.size() % 10 == 0:
				GameState.add_item("study_tokens", 1)
				Services.say_toast({"bn": "দশটা পোস্টার পড়া হলো: একটা স্টাডি টোকেন!", "en": "Ten posters read: a study token!"}, "good")
			Services.poster_read.emit(d)
			Services.say_toast(note, "info")
		"tear":
			GameState.posters_torn.append(id)
			(e["node"] as MeshInstance3D).visible = false
			GameState.change_honesty(1)
			GameState.change_respect(1)
			GameState.log_event("poster_torn", Services.city.district_id_at((e["node"] as Node3D).global_position) if Services.city != null else "kajla")
			Services.poster_read.emit(d)
			Services.say_toast({"bn": "ফাঁস-চক্রের পোস্টার ছিঁড়লে। সততা বাড়ল, চক্রও খেয়াল করল।", "en": "You tore down a leak-gang poster. Honesty up; the gang noticed."}, "good")
		"quiz":
			Exams.start({"mode": "poster", "speaker": {"bn": "পোস্টার", "en": "Poster"}, "family": String(FAMILY.get(kind, "bcs")),
				"count": 2, "pass": 2, "seconds": 30.0, "allow_flee": true,
				"stakes": {"bn": "দুটোই ঠিক হলে একটা স্টাডি টোকেন", "en": "Both right wins a study token"}},
				func(r: Dictionary) -> void:
					if bool(r.get("passed", false)):
						GameState.add_item("study_tokens", 1))


func torn_count() -> int:
	return GameState.posters_torn.size()
