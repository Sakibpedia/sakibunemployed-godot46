class_name BuildingInterior
extends Node3D
## A complete, walkable interior generated inside one city building: a real stair core from the
## ground to the roof, a floor slab with a stair opening on every storey, flats with living rooms,
## bedrooms, kitchens and baths, shop/office/college/mosque ground floors, animated doors and windows,
## lights, fans, furniture and a roof with a headroom, parapet, tank, solar panel, garden and
## clothesline.  The building is generated on demand when the player opens its front door and is
## freed when they leave, so the open world can have 2,600 enterable buildings without 2,600
## interiors in memory.
##
## Two layouts cover the city:
##   * wide plot (w >= 6.2 m): the stair core sits on the left, centred on the corridor at z = 0,
##     two flights run east-west, and the corridor gives onto front and rear flats.
##   * narrow plot (w < 6.2 m): the core spans the back of the plot, two flights run north-south, and
##     each floor is one studio flat in front of the stair (the classic Jatrabari shophouse).
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const WALL_T := 0.14
const SLAB_T := 0.16
const DOOR_H := 2.12
const BATH_W := 1.55
const BATH_D := 1.75

var b: Dictionary
var system: BuildingInteriorSystem
var origin: Vector3
var xform_basis: Basis
var w := 10.0
var d := 10.0
var storey := 3.2
var floors := 4
var h := 12.8
var enterable := false
var narrow := false
var full_roof := false
var body: StaticBody3D
var batch: InteriorBatch
var doors: Array = []
var windows: Array = []
var lights: Array[OmniLight3D] = []
var fans: Array[Node3D] = []
var core_x0 := 0.0
var core_x1 := 0.0
var core_z0 := 0.0
var core_z1 := 0.0
var core_w := 3.45
var core_d := 3.45
var lobby_x := 0.0
var entrance_w := 1.5
var door_side := "right"
var door_z := 0.0
var _rng := RandomNumberGenerator.new()
var _fan_t := 0.0
var _light_t := 0.0
var _name := ""


# =============================================================================================
# Layout shared with the entrance proxies
# =============================================================================================

static func layout_for(building: Dictionary) -> Dictionary:
	var bw := float(building.get("w", 10.0))
	var bd := float(building.get("d", 10.0))
	var l: Dictionary = {}
	if bw >= 6.2:
		var cw := clampf(3.45, 2.4, bw - 3.0)
		var cd := clampf(3.45, 2.8, bd - 1.2)
		l["narrow"] = false
		l["core_x0"] = -bw * 0.5 + 0.3
		l["core_x1"] = float(l["core_x0"]) + cw
		# Centred on the corridor at z = 0, so the stair door opens straight onto the landing.
		l["core_z0"] = -cd * 0.5
		l["core_z1"] = cd * 0.5
		l["lobby_x"] = clampf((float(l["core_x1"]) + bw * 0.5) * 0.5, float(l["core_x1"]) + 0.55, bw * 0.5 - 0.7)
		l["door_side"] = "right"
		l["entrance_w"] = clampf(minf(1.5, bw * 0.5 - float(l["core_x1"]) - 0.35), 0.85, 1.5)
	else:
		var cw2 := clampf(bw - 0.6, 1.9, 3.2)
		var cd2 := clampf(minf(3.45, bd * 0.5), 2.1, 3.45)
		l["narrow"] = true
		l["core_x0"] = -bw * 0.5 + 0.3
		l["core_x1"] = float(l["core_x0"]) + cw2
		l["core_z0"] = -bd * 0.5 + 0.3
		l["core_z1"] = float(l["core_z0"]) + cd2
		l["lobby_x"] = 0.0
		l["door_side"] = "front"
		l["entrance_w"] = clampf(minf(1.4, bw - 1.0), 0.85, 1.5)
	return l


## Where the front door sits in world space, for the entrance proxy that exists before the
## interior has been generated.
static func entrance_transform(building: Dictionary) -> Transform3D:
	var l := layout_for(building)
	var bw := float(building.get("w", 10.0))
	var bd := float(building.get("d", 10.0))
	var rot := float(building.get("rot", 0.0))
	var basis := Basis(Vector3.UP, -rot)
	var origin := Vector3(float(building.get("x", 0.0)), 0.0, float(building.get("z", 0.0)))
	var p := Vector3(float(l["lobby_x"]), 0.0, bd * 0.5 - WALL_T * 0.5)
	return Transform3D(basis, origin + basis * p)


static func building_name(building: Dictionary) -> String:
	var n: Variant = building.get("name", null)
	if typeof(n) == TYPE_DICTIONARY:
		return String((n as Dictionary).get("bn", (n as Dictionary).get("en", "বাড়ি")))
	if typeof(n) == TYPE_STRING and String(n) != "":
		return String(n)
	var shop := String(building.get("shop", ""))
	var style := String(building.get("style", "apartment"))
	if shop != "":
		return "দোকান"
	match style:
		"commercial":
			return "অফিস"
		"college":
			return "কলেজ"
		"mosque":
			return "মসজিদ"
		"shophouse":
			return "দোকান ও বাসা"
		"old":
			return "পুরনো বাড়ি"
	return "বাসা"


# =============================================================================================
# Build
# =============================================================================================

func build(building: Dictionary, sys: BuildingInteriorSystem) -> void:
	b = building
	system = sys
	name = "Interior_" + String(b.get("id", "building"))
	w = float(b.get("w", 10.0))
	d = float(b.get("d", 10.0))
	storey = maxf(2.6, float(b.get("storey", 3.2)))
	floors = maxi(1, int(b.get("floors", 3)))
	h = float(floors) * storey
	enterable = bool(b.get("enterable", false))
	full_roof = enterable
	origin = Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
	xform_basis = Basis(Vector3.UP, -float(b.get("rot", 0.0)))
	transform = Transform3D(xform_basis, origin)
	_rng.seed = absi(hash(String(b.get("id", "building")))) + 17
	_name = building_name(b)

	var l := layout_for(b)
	narrow = bool(l["narrow"])
	core_x0 = float(l["core_x0"])
	core_x1 = float(l["core_x1"])
	core_z0 = float(l["core_z0"])
	core_z1 = float(l["core_z1"])
	core_w = core_x1 - core_x0
	core_d = core_z1 - core_z0
	lobby_x = float(l["lobby_x"])
	entrance_w = float(l["entrance_w"])
	door_side = String(l["door_side"])
	if door_side == "front":
		door_z = core_z1
	else:
		door_z = 0.0

	body = StaticBody3D.new()
	body.name = "InteriorCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	batch = InteriorBatch.new()
	_setup_materials()

	_build_stair_core()
	_build_slabs()
	_build_perimeter()
	_build_floor_programs()
	_build_roof()
	_build_entrance()
	_build_core_signs()
	_build_lights()
	batch.commit(self)


func _setup_materials() -> void:
	var mats := {
		"wall": BuildingMaterials.wall(),
		"wall_warm": BuildingMaterials.wall_colored(Color(0.80, 0.74, 0.64)),
		"wall_cool": BuildingMaterials.wall_colored(Color(0.70, 0.76, 0.78)),
		"wall_rose": BuildingMaterials.wall_colored(Color(0.82, 0.70, 0.68)),
		"wall_green": BuildingMaterials.wall_colored(Color(0.68, 0.76, 0.66)),
		"bath": BuildingMaterials.bathroom_wall(),
		"floor": BuildingMaterials.floor_tile(),
		"floor_wood": BuildingMaterials.floor_wood(),
		"concrete": BuildingMaterials.concrete(),
		"plaster_old": BuildingMaterials.plaster_old(),
		"wood": BuildingMaterials.wood(),
		"wood_dark": BuildingMaterials.wood(Color(0.24, 0.15, 0.09)),
		"wood_light": BuildingMaterials.wood(Color(0.62, 0.43, 0.26)),
		"metal": BuildingMaterials.metal(),
		"steel": BuildingMaterials.metal(Color(0.62, 0.64, 0.66)),
		"glass": BuildingMaterials.glass(),
		"fabric_blue": BuildingMaterials.fabric(Color(0.24, 0.34, 0.55)),
		"fabric_red": BuildingMaterials.fabric(Color(0.62, 0.20, 0.20)),
		"fabric_white": BuildingMaterials.fabric(Color(0.88, 0.86, 0.80)),
		"fabric_green": BuildingMaterials.fabric(Color(0.24, 0.42, 0.28)),
		"curtain": BuildingMaterials.curtain(Color(0.78, 0.70, 0.58)),
		"dark": BuildingMaterials.dark(),
		"ceramic": BuildingMaterials.ceramic(),
		"paper": BuildingMaterials.paper(),
		"leaf": BuildingMaterials.leaf(),
		"plastic_blue": BuildingMaterials.plastic(Color(0.16, 0.38, 0.62)),
		"plastic_red": BuildingMaterials.plastic(Color(0.62, 0.14, 0.14)),
		"plastic_green": BuildingMaterials.plastic(Color(0.18, 0.46, 0.24)),
		"water": BuildingMaterials.water(),
		"gold": BuildingMaterials.gold(),
		"tube": BuildingMaterials.emissive(Color(0.92, 0.96, 1.0), 2.0),
		"bulb": BuildingMaterials.emissive(Color(1.0, 0.82, 0.52), 2.6),
	}
	for k in mats:
		batch.set_material(String(k), mats[k])


# =============================================================================================
# Local geometry helpers
# =============================================================================================

func _box(c: Vector3, s: Vector3, key: String, lb: Basis = Basis.IDENTITY) -> void:
	if s.x <= 0.005 or s.y <= 0.005 or s.z <= 0.005:
		return
	batch.box(c, s, lb, key)


func _solid(c: Vector3, s: Vector3, key: String, lb: Basis = Basis.IDENTITY) -> void:
	_box(c, s, key, lb)
	_collide(c, s, lb)


func _collide(c: Vector3, s: Vector3, lb: Basis = Basis.IDENTITY) -> void:
	if s.x <= 0.005 or s.y <= 0.005 or s.z <= 0.005:
		return
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = s
	cs.shape = sh
	cs.transform = Transform3D(lb, c)
	body.add_child(cs)


func _collide_cyl(c: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	cs.position = c
	body.add_child(cs)


## A wall run along X at fixed Z.  Openings are {a, b, sill, head} with sill/head measured **from
## the floor** (y0), which is what every caller naturally wants.
func _wall_x(z: float, x0: float, x1: float, y0: float, y1: float, openings: Array = [], key: String = "wall") -> void:
	if x1 <= x0:
		return
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a["a"]) < float(c["a"]))
	var cur := x0
	for o in sorted:
		var oa := clampf(float(o["a"]), x0, x1)
		var ob := clampf(float(o["b"]), x0, x1)
		if ob <= oa:
			continue
		if oa > cur + 0.001:
			_solid(Vector3((cur + oa) * 0.5, (y0 + y1) * 0.5, z), Vector3(oa - cur, y1 - y0, WALL_T), key)
		var sill := clampf(y0 + float(o.get("sill", 0.0)), y0, y1)
		var head := clampf(y0 + float(o.get("head", y1 - y0)), y0, y1)
		if sill > y0 + 0.001:
			_solid(Vector3((oa + ob) * 0.5, (y0 + sill) * 0.5, z), Vector3(ob - oa, sill - y0, WALL_T), key)
		if head < y1 - 0.001:
			_solid(Vector3((oa + ob) * 0.5, (head + y1) * 0.5, z), Vector3(ob - oa, y1 - head, WALL_T), key)
		cur = maxf(cur, ob)
	if cur < x1 - 0.001:
		_solid(Vector3((cur + x1) * 0.5, (y0 + y1) * 0.5, z), Vector3(x1 - cur, y1 - y0, WALL_T), key)


## A wall run along Z at fixed X, openings measured from the floor.
func _wall_z(x: float, z0: float, z1: float, y0: float, y1: float, openings: Array = [], key: String = "wall") -> void:
	if z1 <= z0:
		return
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a["a"]) < float(c["a"]))
	var cur := z0
	for o in sorted:
		var oa := clampf(float(o["a"]), z0, z1)
		var ob := clampf(float(o["b"]), z0, z1)
		if ob <= oa:
			continue
		if oa > cur + 0.001:
			_solid(Vector3(x, (y0 + y1) * 0.5, (cur + oa) * 0.5), Vector3(WALL_T, y1 - y0, oa - cur), key)
		var sill := clampf(y0 + float(o.get("sill", 0.0)), y0, y1)
		var head := clampf(y0 + float(o.get("head", y1 - y0)), y0, y1)
		if sill > y0 + 0.001:
			_solid(Vector3(x, (y0 + sill) * 0.5, (oa + ob) * 0.5), Vector3(WALL_T, sill - y0, ob - oa), key)
		if head < y1 - 0.001:
			_solid(Vector3(x, (head + y1) * 0.5, (oa + ob) * 0.5), Vector3(WALL_T, y1 - head, ob - oa), key)
		cur = maxf(cur, ob)
	if cur < z1 - 0.001:
		_solid(Vector3(x, (y0 + y1) * 0.5, (cur + z1) * 0.5), Vector3(WALL_T, y1 - y0, z1 - cur), key)


# =============================================================================================
# Stair core
# =============================================================================================

func _build_stair_core() -> void:
	for f in range(0, floors):
		var y0 := float(f) * storey
		var y1 := y0 + storey
		var dw := 0.95
		if door_side == "right":
			var op := [{"a": door_z - dw * 0.5, "b": door_z + dw * 0.5, "sill": 0.0, "head": DOOR_H}]
			_wall_z(core_x1, core_z0, core_z1, y0, y1, op)
			_wall_x(core_z1, core_x0, core_x1, y0, y1, [])
			_wall_x(core_z0, core_x0, core_x1, y0, y1, [])
			_wall_z(core_x0, core_z0, core_z1, y0, y1, [])
		else:
			var cx := (core_x0 + core_x1) * 0.5
			var op2 := [{"a": cx - dw * 0.5, "b": cx + dw * 0.5, "sill": 0.0, "head": DOOR_H}]
			_wall_x(core_z1, core_x0, core_x1, y0, y1, op2)
			_wall_x(core_z0, core_x0, core_x1, y0, y1, [])
			_wall_z(core_x0, core_z0, core_z1, y0, y1, [])
			_wall_z(core_x1, core_z0, core_z1, y0, y1, [])
		var door := InteractiveDoor.new()
		var label := {"bn": "সিঁড়ির দরজা", "en": "Stair door"}
		var plate := ""
		if narrow and f > 0:
			label = {"bn": "ফ্ল্যাটের দরজা", "en": "Flat door"}
			plate = "ফ্ল্যাট %d" % f
		elif narrow and f == 0:
			plate = "সিঁড়ি"
		door.configure({
			"width": dw, "height": DOOR_H, "auto_open": false,
			"label": label, "wood": Color(0.36, 0.22, 0.14), "nameplate": plate,
		})
		if door_side == "right":
			door.position = Vector3(core_x1, y0, door_z)
			door.rotation.y = PI * 0.5
			door.open_angle = -1.72
		else:
			door.position = Vector3((core_x0 + core_x1) * 0.5, y0, core_z1)
			door.rotation.y = 0.0
			door.open_angle = -1.72
		add_child(door)
		doors.append(door)
		if door_side == "right":
			_stairs_east_west(f, y0)
		else:
			_stairs_north_south(f, y0)
	# top landing at roof level
	var cx2 := (core_x0 + core_x1) * 0.5
	if door_side == "right":
		_solid(Vector3(core_x1 - 0.31, h - 0.07, (core_z0 + core_z1) * 0.5), Vector3(0.54, 0.14, core_d - 0.04), "concrete")
	else:
		_solid(Vector3(cx2, h - 0.07, core_z1 - 0.31), Vector3(core_w - 0.04, 0.14, 0.54), "concrete")


func _stairs_east_west(f: int, y0: float) -> void:
	var lane := (core_d - 0.24) * 0.5
	var z_back := core_z0 + 0.12 + lane * 0.5
	var z_front := core_z1 - 0.12 - lane * 0.5
	var x_low := core_x0 + 0.14
	var x_high := core_x1 - 0.60
	_flight(Vector3(x_high, y0, z_back), Vector3(x_low, y0 + storey * 0.5, z_back), lane, -1.0)
	_flight(Vector3(x_low, y0 + storey * 0.5, z_front), Vector3(x_high, y0 + storey, z_front), lane, -1.0)
	# Central spine wall: it closes the wedge between the up and down flights, so the player cannot
	# straddle two surfaces at different heights, and gives the stairwell its real half-landing look.
	_solid(Vector3((x_low + x_high) * 0.5, y0 + storey * 0.5, 0.0), Vector3(x_high - x_low, storey, 0.08), "wall")
	# floor landing at the door end, mid landing at the far end
	_solid(Vector3(core_x1 - 0.31, y0 - 0.07, (core_z0 + core_z1) * 0.5), Vector3(0.54, 0.14, core_d - 0.04), "concrete")
	_solid(Vector3(core_x0 + 0.34, y0 + storey * 0.5 - 0.07, (core_z0 + core_z1) * 0.5), Vector3(0.56, 0.14, core_d - 0.04), "concrete")


func _stairs_north_south(f: int, y0: float) -> void:
	var lane := (core_w - 0.24) * 0.5
	var x_left := core_x0 + 0.12 + lane * 0.5
	var x_right := core_x1 - 0.12 - lane * 0.5
	var z_low := core_z0 + 0.14
	var z_high := core_z1 - 0.60
	_flight(Vector3(x_left, y0, z_high), Vector3(x_left, y0 + storey * 0.5, z_low), lane, -1.0)
	_flight(Vector3(x_right, y0 + storey * 0.5, z_low), Vector3(x_right, y0 + storey, z_high), lane, 1.0)
	# Spine wall between the two narrow flights, as above.
	_solid(Vector3(0.0, y0 + storey * 0.5, (z_low + z_high) * 0.5), Vector3(0.08, storey, z_high - z_low), "wall")
	_solid(Vector3((core_x0 + core_x1) * 0.5, y0 - 0.07, core_z1 - 0.31), Vector3(core_w - 0.04, 0.14, 0.54), "concrete")
	_solid(Vector3((core_x0 + core_x1) * 0.5, y0 + storey * 0.5 - 0.07, core_z0 + 0.34), Vector3(core_w - 0.04, 0.14, 0.56), "concrete")


## A flight of real treads plus a smooth ramp collider, so the CharacterBody3D walks up without
## catching on the step edges.
func _flight(a: Vector3, c: Vector3, width: float, rail_side: float) -> void:
	var rise_total := c.y - a.y
	var flat := Vector3(c.x - a.x, 0.0, c.z - a.z)
	var run := flat.length()
	if run < 0.2 or absf(rise_total) < 0.05:
		return
	var dir := flat / run
	var yaw := atan2(dir.x, dir.z)
	var n := maxi(6, int(ceil(absf(rise_total) / 0.172)))
	var rise := rise_total / float(n)
	var step := run / float(n)
	var flat_basis := Basis(Vector3.UP, yaw)
	for i in n:
		var t := (float(i) + 0.5) * step
		var p := a + dir * t + Vector3(0.0, rise * (float(i) + 0.5), 0.0)
		_box(p, Vector3(width, absf(rise) + 0.006, step + 0.014), "concrete", flat_basis)
	var slope := atan2(rise_total, run)
	var xaxis := dir.cross(Vector3.UP).normalized()
	var ramp_basis := Basis(xaxis, slope) * flat_basis
	var mid := (a + c) * 0.5
	var length := Vector2(run, rise_total).length()
	_box(mid - ramp_basis.y * 0.065, Vector3(width, 0.13, length), "concrete", ramp_basis)
	_collide(mid - ramp_basis.y * 0.065, Vector3(width, 0.13, length), ramp_basis)
	# A slim steel handrail on the boundary between the two flights.
	var off := xaxis * (width * 0.5 - 0.04) * rail_side
	var ra := a + off + Vector3(0, 0.95, 0)
	var rc := c + off + Vector3(0, 0.95, 0)
	var rmid := (ra + rc) * 0.5
	var rlen := ra.distance_to(rc)
	_box(rmid, Vector3(0.035, 0.035, rlen), "steel", ramp_basis)
	for t2 in [0.18, 0.82]:
		var pp := ra.lerp(rc, t2)
		_box(Vector3(pp.x, pp.y - 0.45, pp.z), Vector3(0.03, 0.9, 0.03), "steel")


# =============================================================================================
# Slabs
# =============================================================================================

func _build_slabs() -> void:
	_slab_at(0.0, false)
	for f in range(1, floors):
		_slab_at(float(f) * storey, false)
	_slab_at(h, true)


func _slab_at(y: float, roof: bool) -> void:
	var x0 := -w * 0.5 + 0.05
	var x1 := w * 0.5 - 0.05
	var z0 := -d * 0.5 + 0.05
	var z1 := d * 0.5 - 0.05
	var cy := y - SLAB_T * 0.5
	var mat := "concrete" if roof else "floor"
	_slab_piece(x0, core_x0, z0, z1, cy, mat)
	_slab_piece(core_x1, x1, z0, z1, cy, mat)
	_slab_piece(core_x0, core_x1, z0, core_z0, cy, mat)
	_slab_piece(core_x0, core_x1, core_z1, z1, cy, mat)
	if not roof:
		_tile_piece(x0 + 0.04, core_x0 - 0.02, z0 + 0.04, z1 - 0.04, y)
		_tile_piece(core_x1 + 0.02, x1 - 0.04, z0 + 0.04, z1 - 0.04, y)
		_tile_piece(core_x0 + 0.02, core_x1 - 0.02, z0 + 0.04, core_z0 - 0.02, y)
		_tile_piece(core_x0 + 0.02, core_x1 - 0.02, core_z1 + 0.02, z1 - 0.04, y)


func _slab_piece(x0: float, x1: float, z0: float, z1: float, cy: float, mat: String) -> void:
	if x1 - x0 < 0.02 or z1 - z0 < 0.02:
		return
	_solid(Vector3((x0 + x1) * 0.5, cy, (z0 + z1) * 0.5), Vector3(x1 - x0, SLAB_T, z1 - z0), mat)


func _tile_piece(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	if x1 - x0 < 0.02 or z1 - z0 < 0.02:
		return
	_box(Vector3((x0 + x1) * 0.5, y + 0.011, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.022, z1 - z0), "floor")


# =============================================================================================
# Perimeter walls, windows and balcony doors
# =============================================================================================

func _balcony_slots() -> Array:
	if not bool(b.get("balconies", false)):
		return []
	var bseed := float(absi(hash(String(b.get("id", "")))) % 1000) / 1000.0
	var nb := maxi(1, int(round(w / 3.2)))
	var bw := w / float(nb)
	var pattern := int(bseed * 7.0) % 3
	var out: Array = []
	for k in nb:
		var on := ((k + pattern) % 2 == 0) if nb > 2 else k == 0
		if on:
			out.append([-w * 0.5 + (float(k) + 0.5) * bw, bw])
	return out


func _build_perimeter() -> void:
	var slots := _balcony_slots()
	for f in range(0, floors):
		var y0 := float(f) * storey
		var y1 := y0 + storey
		var style := String(b.get("style", "apartment"))
		var front: Array = []
		var back: Array = []
		var left: Array = []
		var right: Array = []
		var balcony_x: Array = []
		if f == 0:
			var da := lobby_x - entrance_w * 0.5
			var db := lobby_x + entrance_w * 0.5
			front.append({"a": da, "b": db, "sill": 0.0, "head": 2.22})
			# Shop/lobby windows either side of the door, inside the usable frontage.
			var win_slots: Array = []
			if narrow:
				win_slots = [-w * 0.5 + 0.95, w * 0.5 - 0.95]
			else:
				win_slots = [(core_x1 + 0.16 + da) * 0.5, (db + w * 0.5 - 0.16) * 0.5]
			for sx in win_slots:
				var x := float(sx)
				if absf(x - lobby_x) < entrance_w * 0.5 + 0.75:
					continue
				if x - w * 0.5 < 0.45 or w * 0.5 - x < 0.45:
					continue
				front.append({"a": x - 0.55, "b": x + 0.55, "sill": 0.68, "head": 2.16})
				_window_at(x, y0 + 0.68, d * 0.5 - WALL_T * 0.5, 0.0, 1.1, 1.48, style == "shophouse")
		else:
			# Balcony doors replace the window that would sit in front of each real balcony.
			for slot in slots:
				var sx2 := float(slot[0])
				var bw2 := float(slot[1])
				var dw2 := maxf(0.9, bw2 - 0.55)
				front.append({"a": sx2 - dw2 * 0.5, "b": sx2 + dw2 * 0.5, "sill": 0.0, "head": 2.2})
				balcony_x.append(sx2)
				_balcony_at(sx2, bw2, y0, f)
				_balcony_door_at(sx2, y0, dw2)
			var n := clampi(int(round(w / 4.2)), 1, 4)
			for i in n:
				var x := -w * 0.5 + (float(i) + 0.5) * w / float(n)
				var skip := false
				for bx in balcony_x:
					if absf(x - float(bx)) < 1.3:
						skip = true
						break
				if skip:
					continue
				var ww := 1.12
				front.append({"a": x - ww * 0.5, "b": x + ww * 0.5, "sill": 0.92, "head": 2.22})
				_window_at(x, y0 + 0.92, d * 0.5 - WALL_T * 0.5, 0.0, ww, 1.30, _rng.randf() < 0.25)
			var nb := clampi(int(round(d / 5.0)), 1, 3)
			for i in nb:
				var z := -d * 0.5 + (float(i) + 0.5) * d / float(nb)
				var ww2 := 1.0
				back.append({"a": z - ww2 * 0.5, "b": z + ww2 * 0.5, "sill": 0.95, "head": 2.20})
				_window_at(z, y0 + 0.95, -d * 0.5 + WALL_T * 0.5, PI, ww2, 1.25, _rng.randf() < 0.2)
			if d > 7.0:
				left.append({"a": -0.55, "b": 0.55, "sill": 0.98, "head": 2.18})
				_window_at(0.0, y0 + 0.98, -w * 0.5 + WALL_T * 0.5, -PI * 0.5, 1.1, 1.2, _rng.randf() < 0.2)
				right.append({"a": -0.55, "b": 0.55, "sill": 0.98, "head": 2.18})
				_window_at(0.0, y0 + 0.98, w * 0.5 - WALL_T * 0.5, PI * 0.5, 1.1, 1.2, _rng.randf() < 0.2)
		_wall_x(d * 0.5 - WALL_T * 0.5, -w * 0.5, w * 0.5, y0, y1, front)
		_wall_x(-d * 0.5 + WALL_T * 0.5, -w * 0.5, w * 0.5, y0, y1, back)
		_wall_z(-w * 0.5 + WALL_T * 0.5, -d * 0.5, d * 0.5, y0, y1, left)
		_wall_z(w * 0.5 - WALL_T * 0.5, -d * 0.5, d * 0.5, y0, y1, right)


func _window_at(along: float, y: float, fixed: float, yaw: float, ww: float, wh: float, auto: bool) -> void:
	var win := InteractiveWindow.new()
	win.configure({
		"width": ww, "height": wh, "auto_open": auto,
		"curtain": [Color(0.78, 0.70, 0.58), Color(0.62, 0.72, 0.64), Color(0.72, 0.62, 0.72)][_rng.randi_range(0, 2)],
	})
	if absf(yaw) < 0.01 or absf(absf(yaw) - PI) < 0.01:
		win.position = Vector3(along, y, fixed)
	else:
		win.position = Vector3(fixed, y, along)
	win.rotation.y = yaw
	add_child(win)
	windows.append(win)


## The decorative balcony built by ProceduralDhaka is real geometry; give it a floor and a railing
## collider so the player can step out through the new balcony door and stand on it.
func _balcony_at(x: float, bw: float, y: float, f: int) -> void:
	var z := d * 0.5 + 0.6
	# The decorative slab's top is 14 cm above the floor.  A short ramp bridges it so the player can
	# walk out without jumping; the slab collider starts where the ramp ends.
	var lip := 0.14
	var run := 0.38
	_collide(Vector3(x, y + lip * 0.5, d * 0.5 + run * 0.5), Vector3(bw - 0.3, 0.06, run + 0.06), Basis(Vector3.RIGHT, -atan2(lip, run)))
	_collide(Vector3(x, y + 0.07, d * 0.5 + run + (1.2 - run) * 0.5), Vector3(bw - 0.3, 0.14, 1.2 - run))
	_collide(Vector3(x, y + 0.6, d * 0.5 + 1.18), Vector3(bw - 0.3, 1.0, 0.06))
	for s in [-1.0, 1.0]:
		_collide(Vector3(x + s * (bw - 0.3) * 0.5, y + 0.6, z), Vector3(0.06, 1.0, 1.15))
	# A line of washing on some balconies, as on the real ones.
	if (f + int(round(x))) % 5 == 0:
		for i in 3:
			_box(Vector3(x - 0.4 + float(i) * 0.4, y + 1.55, z + 0.2), Vector3(0.35, 0.55, 0.04),
				["fabric_red", "fabric_white", "fabric_blue"][i])


func _balcony_door_at(x: float, y0: float, dw: float) -> void:
	var door := InteractiveDoor.new()
	door.configure({
		"width": dw, "height": 2.15, "auto_open": false,
		"label": {"bn": "বারান্দার দরজা", "en": "Balcony door"},
		"wood": Color(0.30, 0.20, 0.13),
	})
	door.position = Vector3(x, y0, d * 0.5 - WALL_T * 0.5)
	door.rotation.y = 0.0
	door.open_angle = -1.62
	add_child(door)
	doors.append(door)


# =============================================================================================
# Floor programmes
# =============================================================================================

func _build_floor_programs() -> void:
	for f in range(0, floors):
		if f == 0:
			_ground_program(f)
		elif narrow:
			var z0 := core_z1 + 0.14
			var z1 := d * 0.5 - 0.16
			if z1 - z0 < 1.2:
				continue
			_studio(Rect2(-w * 0.5 + 0.16, z0, w - 0.32, z1 - z0), f, 0, float(f) * storey)
		else:
			_flat_floor(f)


func _flat_floor(f: int) -> void:
	var y0 := float(f) * storey
	var x_start := core_x1 + 0.16
	var x_end := w * 0.5 - 0.16
	if x_end - x_start < 2.0:
		return
	var style := String(b.get("style", "apartment"))
	if style == "commercial":
		_office_floor(f, y0, x_start, x_end)
		return
	if style == "college":
		_college_floor(f, y0, x_start, x_end)
		return
	var two_sided := d >= 7.2
	var n := clampi(int(round((x_end - x_start) / 6.0)), 1, 4)
	var seg := (x_end - x_start) / float(n)
	if two_sided:
		_box(Vector3((x_start + x_end) * 0.5, y0 + 0.02, 0), Vector3(x_end - x_start, 0.04, 1.55), "floor")
		_light(Vector3((x_start + x_end) * 0.5, y0 + 2.62, 0), Color(0.92, 0.96, 1.0), 0.9, 5.5)
	for i in n:
		var fx0 := x_start + float(i) * seg
		var fx1 := x_start + float(i + 1) * seg
		if fx1 - fx0 < 1.4:
			continue
		if two_sided:
			var front := Rect2(fx0, 0.80, fx1 - fx0, d * 0.5 - 0.16 - 0.80)
			var back := Rect2(fx0, -d * 0.5 + 0.16, fx1 - fx0, d * 0.5 - 0.16 - 0.80)
			_flat(front, -1, f, i * 2, y0, i == 0)
			_flat(back, 1, f, i * 2 + 1, y0, i == 0)
		else:
			var one := Rect2(fx0, -d * 0.5 + 0.16, fx1 - fx0, d - 0.32)
			_flat(one, 0, f, i, y0, i == 0)


func _flat(rect: Rect2, corridor_side: int, f: int, idx: int, y0: float, left_wall: bool) -> void:
	var x0 := rect.position.x
	var x1 := rect.position.x + rect.size.x
	var z0 := rect.position.y
	var z1 := rect.position.y + rect.size.y
	if x1 - x0 < 1.5 or z1 - z0 < 2.0:
		return
	var y1 := y0 + storey
	var door_w := 0.9
	var door_c := clampf((x0 + x1) * 0.5, x0 + 0.62, x1 - 0.62)
	# Corridor wall and door (not needed when the stair opens straight into the flat).
	if corridor_side < 0:
		var op := [{"a": door_c - door_w * 0.5, "b": door_c + door_w * 0.5, "sill": 0.0, "head": DOOR_H}]
		_wall_x(0.80, x0, x1, y0, y1, op)
	elif corridor_side > 0:
		var op2 := [{"a": door_c - door_w * 0.5, "b": door_c + door_w * 0.5, "sill": 0.0, "head": DOOR_H}]
		_wall_x(-0.80, x0, x1, y0, y1, op2)
	if left_wall:
		_wall_z(x0, z0, z1, y0, y1, [])
	_wall_z(x1, z0, z1, y0, y1, [])
	# Partition between living and bedroom.
	var depth := z1 - z0
	var pz := z0 + depth * (0.44 if corridor_side > 0 else 0.56)
	if corridor_side == 0:
		pz = z0 + depth * 0.52
	var part_op := [{"a": clampf(door_c - 0.45, x0 + 0.2, x1 - 0.2), "b": clampf(door_c + 0.45, x0 + 0.2, x1 - 0.2), "sill": 0.0, "head": DOOR_H}]
	_wall_x(pz, x0, x1, y0, y1, part_op)
	# Bathroom in the back corner.
	var bx0 := x0 + 0.06
	var bx1 := minf(x0 + BATH_W, x1 - 0.8)
	var bz0 := (z1 - BATH_D - 0.08) if corridor_side <= 0 else (z0 + 0.08)
	var bz1 := bz0 + BATH_D
	if bx1 - bx0 > 1.0 and bz1 - bz0 > 1.0 and bz1 < z1 - 0.05:
		var bdoor := [{"a": bz0 + 0.45, "b": bz0 + 1.25, "sill": 0.0, "head": 2.02}]
		_wall_z(bx1, bz0, bz1, y0, y1, bdoor, "bath")
		_wall_x(bz1 if corridor_side <= 0 else bz0, bx0, bx1, y0, y1, [], "bath")
		_box(Vector3((bx0 + bx1) * 0.5, y0 + 0.02, (bz0 + bz1) * 0.5), Vector3(bx1 - bx0, 0.04, bz1 - bz0), "bath")
		_box(Vector3(bx0 + 0.35, y0 + 0.35, bz0 + 0.35), Vector3(0.38, 0.55, 0.55), "ceramic")
		_box(Vector3(bx0 + 0.35, y0 + 0.68, bz0 + 0.35), Vector3(0.42, 0.18, 0.42), "ceramic")
		_box(Vector3(bx1 - 0.35, y0 + 0.72, bz0 + 0.28), Vector3(0.5, 0.12, 0.38), "ceramic")
		_box(Vector3(bx1 - 0.35, y0 + 0.55, bz0 + 0.28), Vector3(0.08, 0.35, 0.08), "metal")
		_box(Vector3(bx0 + 0.25, y0 + 1.8, bz1 - 0.12), Vector3(0.12, 0.2, 0.12), "metal")
		_box(Vector3(bx0 + 0.25, y0 + 2.05, bz1 - 0.3), Vector3(0.3, 0.05, 0.3), "metal")
		_light(Vector3((bx0 + bx1) * 0.5, y0 + 2.5, (bz0 + bz1) * 0.5), Color(0.92, 0.96, 1.0), 0.55, 2.6)
	# Flat door from the corridor.
	if corridor_side != 0:
		var door := InteractiveDoor.new()
		door.configure({
			"width": door_w, "height": DOOR_H, "auto_open": false,
			"label": {"bn": "ফ্ল্যাটের দরজা", "en": "Flat door"},
			"nameplate": _flat_name(f, idx),
		})
		if corridor_side < 0:
			door.position = Vector3(door_c, y0, 0.80)
			door.rotation.y = PI
			door.open_angle = 1.7
		else:
			door.position = Vector3(door_c, y0, -0.80)
			door.rotation.y = 0.0
			door.open_angle = -1.7
		add_child(door)
		doors.append(door)
	_furnish_flat(x0, x1, z0, z1, pz, corridor_side, y0, idx)
	_light(Vector3((x0 + x1) * 0.5, y0 + 2.62, (z0 + z1) * 0.5), Color(1.0, 0.86, 0.62), 0.95, 5.2)


func _flat_name(f: int, idx: int) -> String:
	var letter := "এ" if idx % 2 == 0 else "বি"
	return "ফ্ল্যাট %d%s" % [f, letter]


## A one-room shophouse flat in front of the stair.
func _studio(rect: Rect2, f: int, idx: int, y0: float) -> void:
	var x0 := rect.position.x
	var x1 := rect.position.x + rect.size.x
	var z0 := rect.position.y
	var z1 := rect.position.y + rect.size.y
	if x1 - x0 < 1.8 or z1 - z0 < 1.2:
		return
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	# Bathroom against the right-hand wall, clear of the stair door at x = 0.
	var bx1 := x1 - 0.06
	var bx0 := maxf(x0 + 0.8, bx1 - 1.45)
	var bz0 := z0 + 0.06
	var bz1 := minf(z1 - 0.3, bz0 + 1.65)
	if bx1 - bx0 > 0.9 and bz1 - bz0 > 1.0:
		var bdoor := [{"a": bz0 + 0.45, "b": bz0 + 1.2, "sill": 0.0, "head": 2.0}]
		_wall_z(bx0, bz0, bz1, y0, y0 + storey, bdoor, "bath")
		_wall_x(bz1, bx0, bx1, y0, y0 + storey, [], "bath")
		_box(Vector3((bx0 + bx1) * 0.5, y0 + 0.02, (bz0 + bz1) * 0.5), Vector3(bx1 - bx0, 0.04, bz1 - bz0), "bath")
		_box(Vector3(bx0 + 0.3, y0 + 0.35, bz0 + 0.32), Vector3(0.36, 0.55, 0.5), "ceramic")
		_box(Vector3(bx1 - 0.3, y0 + 0.72, bz0 + 0.3), Vector3(0.45, 0.12, 0.36), "ceramic")
		_light(Vector3((bx0 + bx1) * 0.5, y0 + 2.45, (bz0 + bz1) * 0.5), Color(0.92, 0.96, 1.0), 0.5, 2.4)
	# Bed along the left wall.
	var bed_w := minf(1.25, (x1 - x0) * 0.42)
	var bed_x := x0 + 0.55 + bed_w * 0.5
	var bed_len := minf(1.85, maxf(0.9, z1 - z0 - 0.35))
	var bed_z := clampf(cz + 0.35, z0 + bed_len * 0.5 + 0.08, z1 - bed_len * 0.5 - 0.08)
	_box(Vector3(bed_x, y0 + 0.24, bed_z), Vector3(bed_w, 0.28, bed_len), "wood_dark")
	_box(Vector3(bed_x, y0 + 0.45, bed_z), Vector3(bed_w - 0.06, 0.18, bed_len - 0.07), "fabric_white")
	_box(Vector3(bed_x, y0 + 0.56, bed_z + bed_len * 0.35), Vector3(bed_w - 0.16, 0.12, 0.32), "fabric_blue")
	_box(Vector3(bed_x, y0 + 0.03, bed_z), Vector3(bed_w + 0.5, 0.03, bed_len + 0.15), "fabric_red")
	# Kitchen counter along the front wall.
	var kx := clampf(cx + 0.3, x0 + 0.6, x1 - 0.6)
	var kz := z1 - 0.45
	_box(Vector3(kx, y0 + 0.45, kz), Vector3(1.35, 0.85, 0.55), "concrete")
	_box(Vector3(kx, y0 + 0.89, kz), Vector3(1.4, 0.06, 0.6), "ceramic")
	_box(Vector3(kx - 0.2, y0 + 0.97, kz), Vector3(0.3, 0.1, 0.36), "metal")
	_box(Vector3(kx + 0.42, y0 + 1.02, kz), Vector3(0.26, 0.3, 0.26), "metal")
	# Small table, chair, TV, water jar, prayer mat.
	_box(Vector3(cx + 0.2, y0 + 0.38, cz - 0.55), Vector3(0.8, 0.06, 0.65), "wood_light")
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			_box(Vector3(cx + 0.2 + s * 0.3, y0 + 0.18, cz - 0.55 + t * 0.24), Vector3(0.05, 0.36, 0.05), "wood_dark")
	_box(Vector3(x1 - 0.32, y0 + 1.35, cz - 0.4), Vector3(0.06, 0.62, 0.9), "dark")
	_box(Vector3(x1 - 0.36, y0 + 1.35, cz - 0.4), Vector3(0.02, 0.52, 0.8), "glass")
	_box(Vector3(x0 + 0.4, y0 + 0.28, z1 - 0.55), Vector3(0.32, 0.5, 0.32), "plastic_blue")
	_box(Vector3(cx - 0.4, y0 + 0.025, z0 + 0.5), Vector3(0.5, 0.03, 0.9), "fabric_green")
	_fan(Vector3(cx, y0 + storey - 0.35, cz))
	_light(Vector3(cx, y0 + 2.62, cz), Color(1.0, 0.86, 0.62), 0.95, 4.6)


func _furnish_flat(x0: float, x1: float, z0: float, z1: float, pz: float, corridor_side: int, y0: float, idx: int) -> void:
	var living_z := (z0 + pz) * 0.5 if corridor_side < 0 else (pz + z1) * 0.5
	var bed_z := (pz + z1) * 0.5 if corridor_side < 0 else (z0 + pz) * 0.5
	var cx := (x0 + x1) * 0.5
	# Bedroom: bed, mattress, pillows, wardrobe, side table, rug.
	var bed_x := clampf(cx + (x1 - x0) * 0.12, x0 + 0.8, x1 - 0.8)
	var bed_w := minf(1.35, x1 - x0 - 0.5)
	_solid(Vector3(bed_x, y0 + 0.24, bed_z), Vector3(bed_w, 0.28, 1.95), "wood_dark")
	_box(Vector3(bed_x, y0 + 0.45, bed_z), Vector3(bed_w - 0.08, 0.18, 1.86), "fabric_white")
	_box(Vector3(bed_x, y0 + 0.55, bed_z + 0.72), Vector3(bed_w - 0.18, 0.12, 0.34), "fabric_blue")
	_box(Vector3(bed_x, y0 + 0.55, bed_z + 0.35), Vector3(bed_w - 0.18, 0.12, 0.34), "fabric_white")
	_solid(Vector3(bed_x - bed_w * 0.5 - 0.25, y0 + 0.38, bed_z + 0.2), Vector3(0.42, 0.72, 0.42), "wood")
	_solid(Vector3(bed_x + bed_w * 0.5 + 0.2, y0 + 0.9, bed_z - 0.55), Vector3(0.52, 1.8, 1.1), "wood_dark")
	_box(Vector3(bed_x, y0 + 0.03, bed_z), Vector3(bed_w + 0.7, 0.03, 2.2), "fabric_red")
	# Living room: sofa, table, TV, shelf, dining set, water jar, prayer mat.
	var sofa_x := clampf(x0 + 1.0, x0 + 0.6, x1 - 0.6)
	_solid(Vector3(sofa_x, y0 + 0.38, living_z), Vector3(1.55, 0.45, 0.62), "fabric_blue")
	_box(Vector3(sofa_x, y0 + 0.66, living_z + 0.24), Vector3(1.55, 0.55, 0.16), "fabric_blue")
	_box(Vector3(sofa_x, y0 + 0.24, living_z - 0.22), Vector3(1.55, 0.12, 0.18), "fabric_blue")
	_solid(Vector3(sofa_x, y0 + 0.42, living_z - 0.55), Vector3(0.95, 0.06, 0.55), "wood_light")
	_box(Vector3(sofa_x, y0 + 0.22, living_z - 0.55), Vector3(0.08, 0.42, 0.08), "wood_dark")
	_box(Vector3(x1 - 0.4, y0 + 0.75, living_z + 0.35), Vector3(0.08, 0.9, 1.25), "dark")
	_box(Vector3(x1 - 0.44, y0 + 0.75, living_z + 0.35), Vector3(0.02, 0.72, 1.08), "glass")
	_box(Vector3(x1 - 0.32, y0 + 0.35, living_z + 0.35), Vector3(0.35, 0.5, 1.0), "wood_dark")
	_box(Vector3(x0 + 0.25, y0 + 0.9, living_z - 0.7), Vector3(0.42, 1.7, 1.1), "wood")
	for s in 3:
		_box(Vector3(x0 + 0.25, y0 + 0.35 + s * 0.45, living_z - 0.7), Vector3(0.48, 0.04, 1.05), "wood_dark")
	_fan(Vector3((x0 + x1) * 0.5, y0 + storey - 0.35, living_z))
	_box(Vector3(x1 - 0.7, y0 + 0.025, z0 + 0.55), Vector3(0.55, 0.03, 1.0), "fabric_green")
	var jar := Vector3(x0 + 0.45, y0 + 0.28, z0 + 0.45)
	_box(jar, Vector3(0.34, 0.5, 0.34), "plastic_blue")
	_box(jar + Vector3(0, 0.28, 0), Vector3(0.2, 0.12, 0.2), "plastic_blue")
	_box(Vector3(x1 - 0.4, y0 + 0.18, z1 - 0.4), Vector3(0.28, 0.35, 0.28), "plastic_red")
	_box(Vector3(x1 - 0.4, y0 + 0.48, z1 - 0.4), Vector3(0.45, 0.35, 0.45), "leaf")
	# Kitchen along the wall opposite the sofa, in the living half.
	var kx := x1 - 0.35
	if x1 - x0 < 4.2:
		kx = x0 + 0.35
	var kz := living_z - 0.35
	_solid(Vector3(kx, y0 + 0.45, kz), Vector3(0.55, 0.85, 1.6), "concrete")
	_box(Vector3(kx, y0 + 0.89, kz), Vector3(0.6, 0.06, 1.65), "ceramic")
	_box(Vector3(kx, y0 + 0.42, kz - 0.5), Vector3(0.52, 0.8, 0.5), "wood_dark")
	_box(Vector3(kx, y0 + 0.42, kz + 0.5), Vector3(0.52, 0.8, 0.5), "wood_dark")
	_box(Vector3(kx - 0.1, y0 + 0.95, kz), Vector3(0.25, 0.08, 0.4), "metal")
	_box(Vector3(kx + 0.12, y0 + 1.0, kz - 0.6), Vector3(0.28, 0.3, 0.28), "metal")
	_box(Vector3(kx + 0.05, y0 + 1.22, kz - 0.6), Vector3(0.22, 0.18, 0.22), "plastic_red")
	# A fridge and a small dining table.
	var fx := x0 + 0.55
	if x1 - x0 < 4.2:
		fx = x1 - 0.55
	_solid(Vector3(fx, y0 + 0.85, living_z + 0.55), Vector3(0.62, 1.7, 0.65), "ceramic")
	_box(Vector3(fx, y0 + 0.85, living_z + 0.88), Vector3(0.58, 1.6, 0.03), "metal")
	_solid(Vector3(cx, y0 + 0.38, living_z + 0.9), Vector3(0.9, 0.06, 0.8), "wood_light")
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			_box(Vector3(cx + s * 0.36, y0 + 0.18, living_z + 0.9 + t * 0.3), Vector3(0.06, 0.36, 0.06), "wood_dark")
	# A wall clock and a calendar.
	_box(Vector3(cx, y0 + 1.95, (z0 + z1) * 0.5 + (0.07 if corridor_side > 0 else -0.07)), Vector3(0.32, 0.32, 0.04), "dark")
	_box(Vector3(cx, y0 + 1.95, (z0 + z1) * 0.5 + (0.095 if corridor_side > 0 else -0.095)), Vector3(0.26, 0.26, 0.01), "paper")
	_box(Vector3(x1 - 0.35, y0 + 1.75, z0 + 0.55), Vector3(0.28, 0.4, 0.02), "paper")


func _office_floor(f: int, y0: float, x_start: float, x_end: float) -> void:
	var cx := (x_start + x_end) * 0.5
	_box(Vector3(cx, y0 + 0.03, 0), Vector3(x_end - x_start, 0.05, 1.5), "floor_wood")
	for i in 4:
		var x := x_start + 0.8 + float(i) * (x_end - x_start - 1.6) / 3.0
		_box(Vector3(x, y0 + 0.4, 0), Vector3(1.15, 0.08, 0.65), "wood_light")
		for s in [-1.0, 1.0]:
			_box(Vector3(x + s * 0.5, y0 + 0.2, 0), Vector3(0.06, 0.4, 0.06), "metal")
		_box(Vector3(x, y0 + 0.55, 0.45), Vector3(0.45, 0.08, 0.45), "fabric_blue")
		_box(Vector3(x, y0 + 0.82, 0.45), Vector3(0.45, 0.5, 0.06), "fabric_blue")
		_box(Vector3(x, y0 + 0.7, -0.35), Vector3(0.4, 0.3, 0.04), "dark")
		_box(Vector3(x, y0 + 0.7, -0.32), Vector3(0.34, 0.24, 0.01), "glass")
		_box(Vector3(x + 0.55, y0 + 0.72, -0.35), Vector3(0.12, 0.35, 0.12), "plastic_red")
	_light(Vector3(cx, y0 + 2.62, 0), Color(0.92, 0.96, 1.0), 1.2, 7.0)
	_box(Vector3(x_start + 0.9, y0 + 1.1, 0.78), Vector3(1.8, 2.1, 0.05), "glass")
	_box(Vector3(cx, y0 + 0.48, -1.55), Vector3(2.4, 0.9, 0.55), "wood_dark")
	_box(Vector3(cx, y0 + 0.95, -1.55), Vector3(2.5, 0.06, 0.6), "wood_light")


func _college_floor(f: int, y0: float, x_start: float, x_end: float) -> void:
	var cx := (x_start + x_end) * 0.5
	for r in 4:
		for c in 3:
			var x := x_start + 0.7 + float(c) * (x_end - x_start - 1.4) / 2.0
			var z := -1.8 + float(r) * 1.25
			_box(Vector3(x, y0 + 0.42, z), Vector3(1.0, 0.07, 0.42), "wood_light")
			_box(Vector3(x, y0 + 0.7, z + 0.35), Vector3(1.0, 0.5, 0.06), "wood")
			for s in [-1.0, 1.0]:
				_box(Vector3(x + s * 0.4, y0 + 0.21, z), Vector3(0.05, 0.42, 0.05), "metal")
	_box(Vector3(cx, y0 + 1.55, -d * 0.5 + 0.25), Vector3(minf(5.0, x_end - x_start - 1.0), 1.35, 0.06), "dark")
	_box(Vector3(cx, y0 + 1.55, -d * 0.5 + 0.29), Vector3(minf(4.8, x_end - x_start - 1.2), 1.2, 0.01), "plastic_green")
	_box(Vector3(cx, y0 + 0.45, -d * 0.5 + 1.2), Vector3(1.6, 0.85, 0.65), "wood")
	_box(Vector3(cx, y0 + 0.9, -d * 0.5 + 1.2), Vector3(1.65, 0.06, 0.7), "wood_light")
	_light(Vector3(cx, y0 + 2.62, 0), Color(0.92, 0.96, 1.0), 1.2, 7.0)


# =============================================================================================
# Ground floors
# =============================================================================================

func _ground_rect() -> Rect2:
	if narrow:
		return Rect2(-w * 0.5 + 0.16, core_z1 + 0.16, w - 0.32, d * 0.5 - 0.16 - core_z1 - 0.16)
	return Rect2(core_x1 + 0.16, -d * 0.5 + 0.16, w * 0.5 - 0.16 - core_x1 - 0.16, d - 0.32)


func _ground_program(_f: int) -> void:
	var g := _ground_rect()
	if g.size.x < 0.8 or g.size.y < 0.8:
		return
	var y0 := 0.0
	var style := String(b.get("style", "apartment"))
	var lm := String(b.get("landmark", ""))
	var shop := String(b.get("shop", ""))
	var cx := g.position.x + g.size.x * 0.5
	var cz := g.position.y + g.size.y * 0.5
	if lm == "tower" or bool(b.get("parking", false)):
		_tower_parking(g, y0)
		return
	if lm == "mess":
		_mess_room(g, y0)
		return
	if style == "mosque" or lm == "mosque":
		_mosque_hall(g, y0)
		return
	if style == "college" or lm in ["dania_college", "college_admin", "adarsha_school"]:
		_college_ground(y0, g)
		return
	if style == "commercial" or lm in ["cyber", "library", "lawyer", "police_station", "clinic", "superstore", "coaching"]:
		_office_ground(y0, g)
		return
	if style == "shophouse" or shop != "":
		_shop_ground(g, y0)
		return
	# Apartment lobby: guard desk, mailboxes, notice board, sofa, plant, lift doors.
	_box(Vector3(g.position.x + g.size.x * 0.72, y0 + 0.48, g.position.y + 0.9), Vector3(1.8, 0.9, 0.55), "wood_dark")
	_box(Vector3(g.position.x + g.size.x * 0.72, y0 + 0.95, g.position.y + 0.9), Vector3(1.9, 0.06, 0.6), "wood_light")
	_box(Vector3(g.position.x + g.size.x * 0.72, y0 + 1.55, g.position.y + 0.2), Vector3(1.3, 0.95, 0.06), "wood")
	_box(Vector3(g.position.x + g.size.x * 0.72, y0 + 1.55, g.position.y + 0.24), Vector3(1.15, 0.8, 0.01), "paper")
	for i in 4:
		_box(Vector3(g.position.x + 0.5 + i * 0.5, y0 + 1.35, g.position.y + 0.25), Vector3(0.4, 0.5, 0.07), "metal")
		_box(Vector3(g.position.x + 0.5 + i * 0.5, y0 + 1.35, g.position.y + 0.3), Vector3(0.34, 0.44, 0.01), "paper")
	_box(Vector3(cx, y0 + 0.38, g.position.y + g.size.y - 1.1), Vector3(1.5, 0.45, 0.6), "fabric_blue")
	_box(Vector3(cx, y0 + 0.66, g.position.y + g.size.y - 0.85), Vector3(1.5, 0.55, 0.16), "fabric_blue")
	_box(Vector3(g.position.x + g.size.x - 0.5, y0 + 0.2, g.position.y + 0.7), Vector3(0.35, 0.4, 0.35), "plastic_red")
	_box(Vector3(g.position.x + g.size.x - 0.5, y0 + 0.55, g.position.y + 0.7), Vector3(0.6, 0.5, 0.6), "leaf")
	_box(Vector3(w * 0.5 - 0.42, y0 + 1.1, g.position.y + g.size.y * 0.45), Vector3(0.07, 2.2, 1.25), "metal")
	_box(Vector3(w * 0.5 - 0.47, y0 + 1.1, g.position.y + g.size.y * 0.45), Vector3(0.02, 1.9, 0.05), "dark")
	_light(Vector3(cx, y0 + 2.6, cz), Color(1.0, 0.9, 0.7), 1.2, 6.5)


func _shop_ground(g: Rect2, y0: float) -> void:
	var x0 := g.position.x
	var x1 := g.position.x + g.size.x
	var z0 := g.position.y
	var z1 := g.position.y + g.size.y
	var cx := (x0 + x1) * 0.5
	# Counter across the shop, shelves on the wall, goods, a back storeroom and a fan.
	var counter_z := clampf(z0 + g.size.y * 0.45, z0 + 1.0, z1 - 1.4)
	_box(Vector3(cx, y0 + 0.5, counter_z), Vector3(minf(2.4, g.size.x - 0.8), 0.95, 0.62), "wood_dark")
	_box(Vector3(cx, y0 + 1.0, counter_z), Vector3(minf(2.45, g.size.x - 0.75), 0.06, 0.68), "wood_light")
	_box(Vector3(cx, y0 + 0.35, counter_z + 0.4), Vector3(minf(2.2, g.size.x - 1.0), 0.7, 0.3), "wood_dark")
	var sx := x0 + 0.35
	for i in 4:
		_box(Vector3(sx, y0 + 0.35 + i * 0.42, z0 + g.size.y * 0.55), Vector3(0.55, 0.04, minf(2.6, g.size.y - 1.0)), "wood")
		for j in 5:
			var jz := z0 + g.size.y * 0.55 - minf(1.1, (g.size.y - 1.2) * 0.4) + j * 0.5
			_box(Vector3(sx, y0 + 0.48 + i * 0.42, jz), Vector3(0.28, 0.18, 0.25),
				"plastic_red" if (i + j) % 3 == 0 else ("plastic_green" if (i + j) % 3 == 1 else "paper"))
	_box(Vector3(x1 - 0.45, y0 + 0.8, z1 - 0.6), Vector3(0.5, 1.5, 0.6), "ceramic")
	_box(Vector3(x1 - 0.45, y0 + 1.58, z1 - 0.6), Vector3(0.55, 0.05, 0.65), "metal")
	_fan(Vector3(cx, y0 + 2.7, (z0 + z1) * 0.5))
	_light(Vector3(cx, y0 + 2.55, (z0 + z1) * 0.5), Color(1.0, 0.86, 0.58), 1.2, 6.0)


func _tower_parking(g: Rect2, y0: float) -> void:
	var x0 := g.position.x
	var x1 := g.position.x + g.size.x
	var z0 := g.position.y
	var z1 := g.position.y + g.size.y
	var nx := maxi(2, int((x1 - x0) / 5.5))
	var nz := maxi(2, int((z1 - z0) / 5.5))
	for i in nx:
		for j in nz:
			var cp := Vector3(x0 + (float(i) + 0.6) * (x1 - x0) / float(nx), y0 + storey * 0.5, z0 + (float(j) + 0.6) * (z1 - z0) / float(nz))
			_solid(cp, Vector3(0.55, storey, 0.55), "concrete")
	# Covered cars and a generator.
	_box(Vector3(x0 + 2.2, y0 + 0.75, z0 + 2.0), Vector3(1.8, 1.4, 4.1), "metal")
	_box(Vector3(x0 + 4.4, y0 + 0.75, z0 + 2.0), Vector3(1.8, 1.4, 4.1), "metal")
	_box(Vector3(x1 - 1.6, y0 + 0.7, z1 - 1.5), Vector3(2.4, 1.4, 1.0), "plastic_green")
	_box(Vector3(x0 + 1.0, y0 + 0.95, z1 - 0.5), Vector3(1.4, 0.9, 0.5), "wood_dark")
	_light(Vector3((x0 + x1) * 0.5, y0 + 2.8, (z0 + z1) * 0.5), Color(0.94, 0.96, 1.0), 1.2, 9.0)


func _mess_room(g: Rect2, y0: float) -> void:
	var x0 := g.position.x
	var z0 := g.position.y
	# Three beds, a study desk, a shelf of books, a fan and a tube light.
	for i in 3:
		var bx := x0 + 0.85 + float(i % 2) * 1.55
		var bz := z0 + 1.1 + float(i) * 1.55
		_solid(Vector3(bx, y0 + 0.28, bz), Vector3(0.95, 0.32, 1.95), "wood_dark")
		_box(Vector3(bx, y0 + 0.5, bz), Vector3(0.88, 0.16, 1.86), "fabric_blue")
		_box(Vector3(bx, y0 + 0.6, bz + 0.7), Vector3(0.7, 0.12, 0.32), "fabric_white")
	_box(Vector3(x0 + g.size.x - 1.0, y0 + 0.4, z0 + 1.0), Vector3(1.3, 0.8, 0.65), "wood_dark")
	_box(Vector3(x0 + g.size.x - 1.0, y0 + 0.85, z0 + 1.0), Vector3(1.35, 0.08, 0.7), "wood_light")
	for i in 4:
		_box(Vector3(x0 + g.size.x - 1.3 + float(i) * 0.2, y0 + 0.98, z0 + 1.0), Vector3(0.14, 0.18, 0.3), "paper")
	_box(Vector3(x0 + 0.4, y0 + 0.9, z0 + g.size.y - 0.9), Vector3(0.4, 1.7, 1.1), "wood")
	for s in 3:
		_box(Vector3(x0 + 0.4, y0 + 0.35 + s * 0.45, z0 + g.size.y - 0.9), Vector3(0.46, 0.04, 1.05), "wood_dark")
	_fan(Vector3(x0 + g.size.x * 0.5, y0 + 2.7, z0 + g.size.y * 0.5))
	_light(Vector3(x0 + g.size.x * 0.5, y0 + 2.6, z0 + g.size.y * 0.5), Color(1.0, 0.9, 0.68), 1.2, 6.0)


func _mosque_hall(g: Rect2, y0: float) -> void:
	var x0 := g.position.x
	var x1 := g.position.x + g.size.x
	var z0 := g.position.y
	var z1 := g.position.y + g.size.y
	var cx := (x0 + x1) * 0.5
	_box(Vector3(cx, y0 + 0.025, (z0 + z1) * 0.5), Vector3(x1 - x0 - 0.6, 0.05, z1 - z0 - 0.6), "fabric_green")
	for i in 3:
		_box(Vector3(cx, y0 + 0.06, z0 + 1.0 + float(i) * 1.6), Vector3(x1 - x0 - 1.0, 0.02, 0.08), "fabric_white")
	_box(Vector3(x1 - 0.35, y0 + 1.25, (z0 + z1) * 0.5), Vector3(0.1, 2.3, 2.0), "wall_cool")
	_box(Vector3(x1 - 0.43, y0 + 1.2, (z0 + z1) * 0.5), Vector3(0.04, 1.6, 1.1), "gold")
	_box(Vector3(cx, y0 + 0.55, z0 + 0.8), Vector3(1.7, 0.9, 0.55), "wood")
	_box(Vector3(cx, y0 + 1.0, z0 + 0.8), Vector3(1.8, 0.08, 0.6), "wood_light")
	for i in 4:
		_box(Vector3(x0 + 0.4 + i * 0.5, y0 + 0.55, z1 - 0.7), Vector3(0.3, 0.9, 0.3), "metal")
	_light(Vector3(cx, y0 + 2.6, (z0 + z1) * 0.5), Color(1.0, 0.92, 0.72), 1.4, 8.0)


func _office_ground(y0: float, g: Rect2) -> void:
	var x0 := g.position.x
	var x1 := g.position.x + g.size.x
	var z0 := g.position.y
	var z1 := g.position.y + g.size.y
	var cx := (x0 + x1) * 0.5
	_box(Vector3(cx, y0 + 0.03, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.05, minf(2.4, z1 - z0)), "floor_wood")
	_box(Vector3(cx, y0 + 0.48, z0 + 0.9), Vector3(minf(2.6, x1 - x0 - 0.6), 0.9, 0.62), "wood_dark")
	_box(Vector3(cx, y0 + 0.96, z0 + 0.9), Vector3(minf(2.7, x1 - x0 - 0.55), 0.06, 0.68), "wood_light")
	for i in 3:
		var x := x0 + 0.8 + float(i) * (x1 - x0 - 1.6) / 2.0
		_box(Vector3(x, y0 + 0.4, z0 + 2.4), Vector3(1.1, 0.08, 0.65), "wood_light")
		_box(Vector3(x, y0 + 0.2, z0 + 2.4), Vector3(0.07, 0.4, 0.07), "metal")
		_box(Vector3(x, y0 + 0.55, z0 + 2.8), Vector3(0.45, 0.08, 0.45), "fabric_blue")
		_box(Vector3(x, y0 + 0.82, z0 + 2.8), Vector3(0.45, 0.5, 0.06), "fabric_blue")
		_box(Vector3(x, y0 + 0.72, z0 + 2.0), Vector3(0.4, 0.3, 0.04), "dark")
		_box(Vector3(x, y0 + 0.72, z0 + 2.03), Vector3(0.34, 0.24, 0.01), "glass")
	_light(Vector3(cx, y0 + 2.62, z0 + 1.5), Color(0.92, 0.96, 1.0), 1.2, 7.0)


func _college_ground(y0: float, g: Rect2) -> void:
	var x0 := g.position.x
	var x1 := g.position.x + g.size.x
	var z0 := g.position.y
	var z1 := g.position.y + g.size.y
	var cx := (x0 + x1) * 0.5
	for r in 4:
		for c in 3:
			var x := x0 + 0.7 + float(c) * maxf(1.2, (x1 - x0 - 1.4) / 2.0)
			var z := z0 + 1.2 + float(r) * 1.25
			_box(Vector3(x, y0 + 0.42, z), Vector3(1.0, 0.07, 0.42), "wood_light")
			_box(Vector3(x, y0 + 0.7, z + 0.35), Vector3(1.0, 0.5, 0.06), "wood")
			for s in [-1.0, 1.0]:
				_box(Vector3(x + s * 0.4, y0 + 0.21, z), Vector3(0.05, 0.42, 0.05), "metal")
	_box(Vector3(cx, y0 + 1.55, z1 - 0.2), Vector3(minf(5.0, x1 - x0 - 1.0), 1.35, 0.06), "dark")
	_box(Vector3(cx, y0 + 1.55, z1 - 0.24), Vector3(minf(4.8, x1 - x0 - 1.2), 1.2, 0.01), "plastic_green")
	_box(Vector3(cx, y0 + 0.45, z0 + 1.0), Vector3(1.6, 0.85, 0.65), "wood")
	_box(Vector3(cx, y0 + 0.9, z0 + 1.0), Vector3(1.65, 0.06, 0.7), "wood_light")
	_light(Vector3(cx, y0 + 2.62, (z0 + z1) * 0.5), Color(0.92, 0.96, 1.0), 1.2, 7.0)


# =============================================================================================
# Roof
# =============================================================================================

func _build_roof() -> void:
	var ph := 1.05
	for s in [-1.0, 1.0]:
		_collide(Vector3(0, h + ph * 0.5, s * (d * 0.5 - 0.1)), Vector3(w, ph, 0.18))
		_collide(Vector3(s * (w * 0.5 - 0.1), h + ph * 0.5, 0), Vector3(0.18, ph, d - 0.36))
	# Headroom over the stair, with the roof door on the same side as the stair door.
	var hh := 2.45
	var dw := 0.95
	if door_side == "right":
		var op := [{"a": door_z - dw * 0.5, "b": door_z + dw * 0.5, "sill": 0.0, "head": 2.1}]
		_wall_z(core_x1, core_z0, core_z1, h, h + hh, op, "wall_warm")
		_wall_x(core_z1, core_x0, core_x1, h, h + hh, [], "wall_warm")
		_wall_x(core_z0, core_x0, core_x1, h, h + hh, [], "wall_warm")
		_wall_z(core_x0, core_z0, core_z1, h, h + hh, [], "wall_warm")
	else:
		var cx := (core_x0 + core_x1) * 0.5
		var op2 := [{"a": cx - dw * 0.5, "b": cx + dw * 0.5, "sill": 0.0, "head": 2.1}]
		_wall_x(core_z1, core_x0, core_x1, h, h + hh, op2, "wall_warm")
		_wall_x(core_z0, core_x0, core_x1, h, h + hh, [], "wall_warm")
		_wall_z(core_x0, core_z0, core_z1, h, h + hh, [], "wall_warm")
		_wall_z(core_x1, core_z0, core_z1, h, h + hh, [], "wall_warm")
	_solid(Vector3((core_x0 + core_x1) * 0.5, h + hh + 0.08, (core_z0 + core_z1) * 0.5), Vector3(core_w + 0.2, 0.16, core_d + 0.2), "concrete")
	var roof_door := InteractiveDoor.new()
	roof_door.configure({
		"width": dw, "height": 2.1, "auto_open": false,
		"label": {"bn": "ছাদের দরজা", "en": "Roof door"}, "nameplate": "ছাদ",
	})
	if door_side == "right":
		roof_door.position = Vector3(core_x1, h, door_z)
		roof_door.rotation.y = PI * 0.5
	else:
		roof_door.position = Vector3((core_x0 + core_x1) * 0.5, h, core_z1)
		roof_door.rotation.y = 0.0
	roof_door.open_angle = -1.72
	add_child(roof_door)
	doors.append(roof_door)
	_light(Vector3((core_x0 + core_x1) * 0.5, h + 2.1, (core_z0 + core_z1) * 0.5), Color(1.0, 0.86, 0.6), 0.75, 4.0)
	if not full_roof:
		_light(Vector3(0, h + 2.0, 0), Color(0.92, 0.94, 1.0), 0.5, 8.0)
		return
	# Water tank on a stand, front-right.
	var tx := w * 0.5 - 2.1
	var tz := d * 0.5 - 2.1
	_solid(Vector3(tx, h + 0.35, tz), Vector3(2.3, 0.7, 2.3), "concrete")
	batch.prism(Vector3(tx, h + 1.65, tz), 1.0, 1.9, 16, "plastic_blue", 1.0)
	_collide_cyl(Vector3(tx, h + 1.65, tz), 1.0, 1.9)
	_box(Vector3(tx, h + 2.65, tz), Vector3(0.5, 0.12, 0.5), "plastic_blue")
	_box(Vector3(tx + 0.3, h + 1.0, tz + 0.3), Vector3(0.08, 1.3, 0.08), "metal")
	# Solar panel and frame.
	var sx := w * 0.5 - 2.4
	var sz := -d * 0.5 + 2.2
	_box(Vector3(sx, h + 1.1, sz), Vector3(2.2, 0.08, 1.35), "dark", Basis(Vector3.RIGHT, -0.42))
	_box(Vector3(sx, h + 0.55, sz), Vector3(0.08, 1.1, 0.08), "metal")
	# Clothesline with a few clothes.
	var a := Vector3(-w * 0.5 + 1.2, h + 1.9, -d * 0.3)
	var c := Vector3(-w * 0.5 + 1.2, h + 1.9, d * 0.3)
	_box(a, Vector3(0.08, 1.9, 0.08), "metal")
	_box(c, Vector3(0.08, 1.9, 0.08), "metal")
	_box((a + c) * 0.5, Vector3(0.025, 0.025, a.distance_to(c)), "steel")
	for i in 5:
		var p := a.lerp(c, (float(i) + 0.5) / 5.0) + Vector3(0, -0.45, 0)
		_box(p, Vector3(0.04, 0.8, 0.55), ["fabric_red", "fabric_blue", "fabric_white", "fabric_green", "fabric_red"][i])
	# Roof garden and a charpai.
	for i in 4:
		var px := -w * 0.2 + float(i % 2) * 1.1
		var pz := d * 0.5 - 1.1 - float(i / 2) * 1.1
		_box(Vector3(px, h + 0.22, pz), Vector3(0.75, 0.35, 0.75), "plastic_red")
		_box(Vector3(px, h + 0.55, pz), Vector3(0.9, 0.4, 0.9), "leaf")
	var bx := -w * 0.5 + 2.0
	var bz := d * 0.5 - 1.7
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			_box(Vector3(bx + s * 0.8, h + 0.25, bz + t * 0.45), Vector3(0.08, 0.5, 0.08), "wood_dark")
	_box(Vector3(bx, h + 0.52, bz), Vector3(1.8, 0.08, 1.1), "wood")
	_box(Vector3(bx, h + 0.6, bz), Vector3(1.6, 0.08, 0.9), "fabric_blue")
	# A dish antenna.
	var dx := -w * 0.5 + 1.2
	var dz := -d * 0.5 + 1.2
	_box(Vector3(dx, h + 0.9, dz), Vector3(0.06, 1.8, 0.06), "metal")
	batch.prism(Vector3(dx, h + 1.8, dz), 0.55, 0.12, 16, "metal", 0.4)
	_light(Vector3(0, h + 2.2, 0), Color(0.92, 0.94, 1.0), 0.6, 8.0)


# =============================================================================================
# Entrance and signs
# =============================================================================================

func _build_entrance() -> void:
	var door := InteractiveDoor.new()
	door.configure({
		"width": entrance_w, "height": 2.2, "auto_open": true,
		"label": {"bn": "প্রবেশ / বের হও", "en": "Enter / leave"}, "nameplate": _name,
	})
	door.position = Vector3(lobby_x, 0.0, d * 0.5 - WALL_T * 0.5)
	door.rotation.y = 0.0
	door.open_angle = -1.75
	add_child(door)
	doors.append(door)
	_box(Vector3(lobby_x, 0.025, d * 0.5 - 0.8), Vector3(1.0, 0.03, 0.55), "fabric_red")
	_box(Vector3(core_x1 + 0.55, 0.22, d * 0.5 - 0.5), Vector3(0.5, 0.4, 0.3), "wood")
	var lbl := Label3D.new()
	lbl.text = _name
	lbl.font = UiKit.font(true)
	lbl.font_size = 44
	lbl.pixel_size = 0.0036
	lbl.outline_size = 8
	lbl.position = Vector3(lobby_x, 2.55, d * 0.5 - WALL_T * 0.5 - 0.08)
	lbl.modulate = Color(0.96, 0.86, 0.58)
	add_child(lbl)


func _build_core_signs() -> void:
	for f in range(0, floors):
		var lbl := Label3D.new()
		lbl.text = "সিঁড়ি ↑" if f == 0 else "সিঁড়ি · %d" % (f + 1)
		lbl.font = UiKit.font(true)
		lbl.font_size = 36
		lbl.pixel_size = 0.0032
		lbl.outline_size = 6
		if door_side == "right":
			lbl.position = Vector3(core_x1 + 0.02, float(f) * storey + 2.32, door_z + 0.55)
			lbl.rotation.y = PI * 0.5
		else:
			lbl.position = Vector3((core_x0 + core_x1) * 0.5, float(f) * storey + 2.32, core_z1 + 0.02)
		lbl.modulate = Color(0.95, 0.88, 0.62)
		add_child(lbl)


# =============================================================================================
# Lights, fans, per-frame life
# =============================================================================================

func _light(p: Vector3, col: Color, energy: float, range_m: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = false
	l.position = p
	add_child(l)
	lights.append(l)


func _build_lights() -> void:
	for f in range(0, floors):
		_light(Vector3((core_x0 + core_x1) * 0.5, float(f) * storey + 2.45, (core_z0 + core_z1) * 0.5), Color(0.9, 0.96, 1.0), 0.75, 4.0)
		var tx := lobby_x if not narrow else 0.0
		_box(Vector3(tx, float(f) * storey + 2.72, 0.0), Vector3(1.1, 0.06, 0.08), "tube")


func _fan(p: Vector3) -> void:
	var root := Node3D.new()
	root.position = p
	add_child(root)
	var rod := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.018
	rm.bottom_radius = 0.018
	rm.height = 0.32
	rod.mesh = rm
	rod.position = Vector3(0, 0.16, 0)
	rod.material_override = BuildingMaterials.metal()
	root.add_child(rod)
	var hub := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.09
	hm.height = 0.18
	hub.mesh = hm
	hub.position = Vector3(0, -0.02, 0)
	hub.material_override = BuildingMaterials.metal(Color(0.72, 0.72, 0.7))
	root.add_child(hub)
	for i in 3:
		var holder := Node3D.new()
		holder.rotation.y = TAU * float(i) / 3.0
		root.add_child(holder)
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.55, 0.018, 0.14)
		blade.mesh = bm
		blade.position = Vector3(0.3, 0, 0)
		blade.material_override = BuildingMaterials.painted_metal(Color(0.62, 0.64, 0.66))
		holder.add_child(blade)
	fans.append(root)


func _process(delta: float) -> void:
	_fan_t += delta * 7.0
	for fan in fans:
		if is_instance_valid(fan):
			fan.rotation.y = _fan_t * (0.9 + float(fan.get_index() % 3) * 0.08)
	_light_t += delta
	if _light_t > 2.7:
		_light_t = 0.0
		for i in lights.size():
			if i % 7 == 0:
				lights[i].light_energy = 0.65 + _rng.randf() * 0.45
