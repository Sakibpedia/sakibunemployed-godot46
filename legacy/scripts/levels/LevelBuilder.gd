class_name LevelBuilder
extends RefCounted
## Builds a level from the ASCII floors in its JSON (design doc Sections 4 and 5).
## Everything static is drawn by three MultiMeshes (boxes, spheres, cylinders) with per-instance
## colours; colliders are merged along rows; stairs are ramps under stepped visuals; the navmesh
## is baked once at load. Cell = 2 m, storey = 3.2 m.

const C := 2.0
const H := 3.2
const CUSTOM := "123456789AFHIJKMNOQSUV"
const MARKS := "@EXYZPC"
const PALETTES := {
	"street": {"ground": Color(0.42, 0.4, 0.36), "wall": Color(0.86, 0.84, 0.78), "parapet": Color(0.7, 0.7, 0.68),
		"tile": Color(0.82, 0.8, 0.76), "road": Color(0.2, 0.2, 0.22), "pave": Color(0.6, 0.58, 0.55), "roof": Color(0.62, 0.6, 0.57)},
	"tower": {"ground": Color(0.42, 0.4, 0.36), "wall": Color(0.88, 0.86, 0.8), "parapet": Color(0.68, 0.7, 0.66),
		"tile": Color(0.85, 0.83, 0.78), "road": Color(0.2, 0.2, 0.22), "pave": Color(0.62, 0.6, 0.57), "roof": Color(0.6, 0.6, 0.58)},
	"green": {"ground": Color(0.33, 0.4, 0.25), "wall": Color(0.82, 0.86, 0.78), "parapet": Color(0.6, 0.62, 0.58),
		"tile": Color(0.8, 0.78, 0.72), "road": Color(0.4, 0.33, 0.25), "pave": Color(0.55, 0.5, 0.42), "roof": Color(0.6, 0.6, 0.58)},
	"night": {"ground": Color(0.3, 0.3, 0.3), "wall": Color(0.5, 0.52, 0.5), "parapet": Color(0.45, 0.45, 0.45),
		"tile": Color(0.45, 0.47, 0.45), "road": Color(0.18, 0.18, 0.2), "pave": Color(0.4, 0.4, 0.4), "roof": Color(0.45, 0.45, 0.45)},
}
const FACADES := [Color(0.88, 0.86, 0.8), Color(0.78, 0.86, 0.78), Color(0.9, 0.8, 0.8), Color(0.9, 0.86, 0.7), Color(0.75, 0.78, 0.82), Color(0.7, 0.68, 0.64)]
const BRIGHT := [Color(0.85, 0.2, 0.2), Color(0.15, 0.45, 0.8), Color(0.2, 0.6, 0.3), Color(0.95, 0.6, 0.1), Color(0.6, 0.2, 0.6)]

var root: Node3D
var nav: NavigationRegion3D
var statics: StaticBody3D
var props: StaticBody3D
var markers: Dictionary = {}      # marker char -> Array of Vector3 (cell centre on its floor)
var hazards: Array = []           # [Vector3, cause]
var lights: Array = []            # interior OmniLight3D
var lamps: Array = []             # street lamps, lit at night
var gates: Array = []             # Interactable gates in reading order
var lifts: Array = []
var floors: Array = []
var w := 0
var h := 0
var block_height := 18.0
var roof_floor := 3
var _pal: Dictionary
var _boxes: Array = []
var _spheres: Array = []
var _cyls: Array = []
var _rng := RandomNumberGenerator.new()
var _fans := 0
var _water_mat: ShaderMaterial


func build(def: Dictionary, parent: Node3D) -> void:
	root = parent
	floors = def.floors
	h = floors[0].size()
	w = 0
	for row in floors[0]:
		w = maxi(w, String(row).length())
	block_height = float(def.get("block_height", 18.0))
	roof_floor = maxi(1, int(def.get("roof_floor", 3)))
	_pal = PALETTES.get(def.get("palette", "street"), PALETTES.street)
	_rng.seed = int(def.get("level", 1)) * 7919
	nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.35
	nm.agent_height = 1.7
	nm.agent_max_climb = 0.35
	nm.agent_max_slope = 40.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | 2
	nav.navigation_mesh = nm
	root.add_child(nav)
	statics = StaticBody3D.new()
	statics.collision_layer = 1
	statics.collision_mask = 0
	nav.add_child(statics)
	props = StaticBody3D.new()
	props.collision_layer = 2
	props.collision_mask = 0
	nav.add_child(props)
	_ground()
	for f in floors.size():
		_floor(f, bool(def.get("roofed", true)))
	_flush()
	nav.bake_navigation_mesh(false)


func at(f: int, x: int, y: int) -> String:
	if f < 0 or f >= floors.size() or y < 0 or y >= h or x < 0:
		return " "
	var row: String = floors[f][y]
	return row[x] if x < row.length() else " "


func cell_pos(f: int, x: int, y: int) -> Vector3:
	return Vector3((x + 0.5) * C, f * H, (y + 0.5) * C)


func _ground() -> void:
	var size := Vector3(w * C + 40.0, 1.0, h * C + 40.0)
	var center := Vector3(w * C * 0.5, -0.5, h * C * 0.5)
	_box(center, size, _pal.ground, 0.0, DhakaMaterials.CONCRETE)
	_collider(statics, center, size)
	for side in 4:
		var bsize := Vector3(w * C, 30.0, 1.0) if side < 2 else Vector3(1.0, 30.0, h * C)
		var bpos := Vector3(w * C * 0.5, 15.0, -0.5 if side == 0 else h * C + 0.5) if side < 2 else Vector3(-0.5 if side == 2 else w * C + 0.5, 15.0, h * C * 0.5)
		_collider(statics, bpos, bsize)


func _floor(f: int, roofed: bool) -> void:
	for y in h:
		var x := 0
		while x < w:
			var ch := at(f, x, y)
			if ch in ["#", "|", "B", "b", "R"]:
				var x2 := x
				while x2 + 1 < w and at(f, x2 + 1, y) == ch:
					x2 += 1
				_run(f, x, x2, y, ch)
				x = x2 + 1
				continue
			_cell(f, x, y, ch)
			x += 1
		if f > 0:
			_slab_row(f, y)
		if roofed and f == floors.size() - 1:
			_roof_row(f, y)


func _run(f: int, x1: int, x2: int, y: int, ch: String) -> void:
	var n := x2 - x1 + 1
	var y0 := f * H
	var hh := H
	var col: Color = _pal.wall
	var surf := DhakaMaterials.PLASTER
	match ch:
		"|":
			hh = 1.1
			col = _pal.parapet
			surf = DhakaMaterials.CONCRETE
		"B":
			hh = block_height + float((x1 * 7 + y * 13) % 4) * 3.2
			col = FACADES[(x1 * 3 + y * 5) % FACADES.size()]
			surf = [DhakaMaterials.BRICK, DhakaMaterials.PLASTER, DhakaMaterials.CONCRETE, DhakaMaterials.BRICK, DhakaMaterials.PLASTER][(x1 * 3 + y * 5) % 5]
		"b":
			hh = 6.4
			col = FACADES[(x1 * 5 + y * 3 + 2) % FACADES.size()]
			surf = [DhakaMaterials.BRICK, DhakaMaterials.PLASTER][(x1 + y) % 2]
		"R":
			hh = roof_floor * H
			col = FACADES[(x1 + y) % FACADES.size()]
			surf = [DhakaMaterials.PLASTER, DhakaMaterials.CONCRETE, DhakaMaterials.BRICK][(x1 + y) % 3]
	var center := Vector3((x1 + n * 0.5) * C, y0 + hh * 0.5, (y + 0.5) * C)
	_collider(statics, center, Vector3(n * C, hh, C))
	for i in n:
		var cx := x1 + i
		_box(Vector3((cx + 0.5) * C, y0 + hh * 0.5, (y + 0.5) * C), Vector3(C, hh, C), col, 0.04, surf)
		if ch == "B" or ch == "b":
			_windows(f, cx, y, hh, ch)


func _windows(f: int, x: int, y: int, hh: float, ch: String) -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var n := at(f, x + d.x, y + d.y)
		if n == ch or n == "B" or n == "b" or n == "#":
			continue
		var storeys := int(hh / H)
		for s in range(0, storeys):
			var base := cell_pos(f, x, y) + Vector3(d.x * (C * 0.5 + 0.03), s * H + 1.7, d.y * (C * 0.5 + 0.03))
			var size := Vector3(0.06, 1.0, 0.8) if d.x != 0 else Vector3(0.8, 1.0, 0.06)
			_box(base, size, Color(0.16, 0.2, 0.24), 0.05)


func _slab_row(f: int, y: int) -> void:
	var x := 0
	while x < w:
		if at(f, x, y) == " " or at(f, x, y) == "%":
			x += 1
			continue
		var x2 := x
		while x2 + 1 < w and at(f, x2 + 1, y) != " " and at(f, x2 + 1, y) != "%":
			x2 += 1
		var n := x2 - x + 1
		var center := Vector3((x + n * 0.5) * C, f * H - 0.125, (y + 0.5) * C)
		_collider(statics, center, Vector3(n * C, 0.25, C))
		_box(center, Vector3(n * C, 0.25, C), _pal.roof, 0.0, DhakaMaterials.CONCRETE)
		x = x2 + 1


func _roof_row(f: int, y: int) -> void:
	# Interior cells on the top floor get a ceiling, so single-storey halls are indoors.
	var x := 0
	while x < w:
		var ch := at(f, x, y)
		if not (ch in [".", "t", "n", "D", "L", "f"]) and not (CUSTOM.contains(ch) and _indoor(f, x, y)):
			x += 1
			continue
		var x2 := x
		while x2 + 1 < w and (at(f, x2 + 1, y) in [".", "t", "n", "D", "L", "#"] or CUSTOM.contains(at(f, x2 + 1, y))):
			x2 += 1
		var n := x2 - x + 1
		var center := Vector3((x + n * 0.5) * C, (f + 1) * H + 0.1, (y + 0.5) * C)
		_collider(statics, center, Vector3(n * C, 0.2, C))
		_box(center, Vector3(n * C, 0.2, C), _pal.roof, 0.0, DhakaMaterials.TIN if f == 0 else DhakaMaterials.CONCRETE)
		x = x2 + 1


func _indoor(f: int, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if at(f, x + d.x, y + d.y) == ".":
			return true
	return false


func _cell(f: int, x: int, y: int, ch: String) -> void:
	var p := cell_pos(f, x, y)
	var col: Color
	match ch:
		" ", ",":
			if f > 0 and ch == ",":
				pass
		".", "f":
			_box(p + Vector3(0, 0.02, 0), Vector3(C, 0.04, C), _pal.tile.darkened(0.05 * ((x + y) % 2)), 0.0, DhakaMaterials.TILE if f == 0 else DhakaMaterials.CONCRETE)
			if x % 4 == 2 and y % 4 == 2 and lights.size() < 26:
				var l := OmniLight3D.new()
				l.position = p + Vector3(0, H - 0.35, 0)
				l.omni_range = 7.0
				l.light_energy = 1.1
				l.light_color = Color(0.9, 0.96, 1.0)
				root.add_child(l)
				lights.append(l)
				_box(p + Vector3(0, H - 0.08, 0), Vector3(1.2, 0.05, 0.12), Color(0.98, 0.98, 0.95), 0.0)
			if (ch == "f" or (x % 5 == 1 and y % 5 == 3)) and _fans < 18:
				_fans += 1
				_fan(p + Vector3(0, H - 0.45, 0))
		"=":
			_box(p + Vector3(0, 0.015, 0), Vector3(C, 0.03, C), _pal.road, 0.02, DhakaMaterials.ASPHALT)
			if (x + y) % 3 == 0:
				_box(p + Vector3(0, 0.035, 0), Vector3(0.9, 0.01, 0.12), Color(0.85, 0.85, 0.8), 0.0)
		"-":
			_box(p + Vector3(0, 0.07, 0), Vector3(C, 0.14, C), _pal.pave, 0.03, DhakaMaterials.CONCRETE)
			if f == 0 and (x * 3 + y * 5) % 13 == 0 and lamps.size() < 14:
				_lamp(p)
		"W":
			_water(p)
		"T":
			_cyl(p + Vector3(0, 1.5, 0), 0.22, 3.0, Color(0.35, 0.25, 0.16))
			_sphere(p + Vector3(0, 3.9, 0), Vector3(3.0, 2.6, 3.0), Color(0.22, 0.42, 0.2).lightened(0.1 * (x % 3)))
			_collider(props, p + Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5))
		"+":
			_sphere(p + Vector3(0, 0.12, 0), Vector3(1.0, 0.45, 1.8), Color(0.4, 0.33, 0.25))
			_box(p + Vector3(0, 0.45, -0.85), Vector3(0.5, 0.6, 0.08), Color(0.8, 0.8, 0.78), 0.0, DhakaMaterials.CONCRETE)
			_collider(props, p + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 1.8))
		"t":
			_floor_tile(f, p)
			_box(p + Vector3(0, 0.38, 0), Vector3(1.5, 0.76, 0.75), Color(0.45, 0.3, 0.18), 0.05)
			_collider(props, p + Vector3(0, 0.38, 0), Vector3(1.5, 0.76, 0.75))
		"n":
			_floor_tile(f, p)
			_box(p + Vector3(0, 0.23, 0), Vector3(1.8, 0.45, 0.5), Color(0.5, 0.35, 0.2), 0.05)
			_collider(props, p + Vector3(0, 0.23, 0), Vector3(1.8, 0.45, 0.5))
		"k":
			col = BRIGHT[(x + y) % BRIGHT.size()]
			_box(p + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 0.8), Color(0.55, 0.4, 0.25), 0.05)
			_box(p + Vector3(0, 2.4, 0.2), Vector3(2.0, 0.08, 1.5), col, 0.0, DhakaMaterials.AWNING, x * 7 + y * 3)
			_box(p + Vector3(0, 1.2, -0.7), Vector3(1.8, 2.2, 0.15), Color(0.6, 0.5, 0.35), 0.05, DhakaMaterials.TIN_PAINTED if (x + y) % 2 == 0 else DhakaMaterials.TIN)
			_collider(props, p + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 0.8))
		"c":
			col = [Color(0.92, 0.92, 0.9), Color(0.6, 0.62, 0.65), Color(0.6, 0.1, 0.1), Color(0.1, 0.1, 0.12)][(x + y) % 4]
			_box(p + Vector3(0, 0.55, 0), Vector3(1.8, 0.6, 4.0), col, 0.0)
			_box(p + Vector3(0, 1.1, 0.2), Vector3(1.6, 0.5, 2.0), Color(0.15, 0.2, 0.25), 0.0)
			for wx in [-0.85, 0.85]:
				for wz in [-1.3, 1.3]:
					_cyl(p + Vector3(wx, 0.32, wz), 0.32, 0.22, Color(0.05, 0.05, 0.05), Basis(Vector3.FORWARD, PI * 0.5))
			_collider(props, p + Vector3(0, 0.7, 0), Vector3(1.9, 1.4, 4.1))
		"r":
			_rickshaw(p)
		"u":
			col = [Color(0.15, 0.5, 0.25), Color(0.7, 0.12, 0.12), Color(0.15, 0.3, 0.6)][(x + y) % 3]
			_box(p + Vector3(0, 1.6, 0), Vector3(9.0, 2.8, 2.5), col, 0.0)
			_box(p + Vector3(0, 2.2, 0), Vector3(8.6, 0.8, 2.55), Color(0.12, 0.16, 0.2), 0.0)
			_collider(props, p + Vector3(0, 1.6, 0), Vector3(9.0, 2.8, 2.5))
		"o":
			_box(p + Vector3(0, 0.25, 0), Vector3(1.8, 0.6, 6.0), Color(0.4, 0.26, 0.14), 0.0)
			_box(p + Vector3(0, 1.3, 0.5), Vector3(1.7, 0.08, 2.6), Color(0.3, 0.3, 0.12), 0.0)
		"p":
			_cyl(p + Vector3(0.6, 0.2, 0.6), 0.25, 0.4, Color(0.65, 0.33, 0.2))
			_sphere(p + Vector3(0.6, 0.65, 0.6), Vector3(0.8, 0.7, 0.8), Color(0.2, 0.5, 0.22))
			_floor_tile(f, p)
		"w":
			_cyl(p + Vector3(0, 0.8, 0), 0.9, 1.6, Color(0.55, 0.56, 0.55))
			_collider(props, p + Vector3(0, 0.8, 0), Vector3(1.8, 1.6, 1.8))
		"m":
			_box(p + Vector3(0, 0.9, 0), Vector3(1.6, 1.8, 0.45), Color(0.5, 0.52, 0.5), 0.0)
			_collider(props, p + Vector3(0, 0.9, 0), Vector3(1.6, 1.8, 0.45))
			hazards.append([p, "shock"])
			_floor_tile(f, p)
		"g":
			_box(p + Vector3(0, 0.65, 0), Vector3(1.8, 1.3, 1.1), Color(0.18, 0.35, 0.22), 0.0)
			_cyl(p + Vector3(0.6, 1.6, 0), 0.08, 0.7, Color(0.2, 0.2, 0.2))
			_collider(props, p + Vector3(0, 0.65, 0), Vector3(1.8, 1.3, 1.1))
			hazards.append([p, "shock"])
		"x":
			_box(p + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), Color(0.5, 0.38, 0.22), 0.08)
			_collider(props, p + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0))
			_floor_tile(f, p)
		"y":
			_cyl(p + Vector3(0.5, 0.3, 0.5), 0.18, 0.6, Color(0.75, 0.12, 0.1))
			hazards.append([p, "blast"])
			_floor_tile(f, p)
		"q":
			_box(p + Vector3(0, 0.5, 0), Vector3(C, 1.0, 0.05), Color(0.6, 0.78, 0.85), 0.0)
			_collider(props, p + Vector3(0, 0.5, 0), Vector3(C, 1.0, 0.05))
			hazards.append([p, "bleed"])
		"h":
			for i in [-1, 0, 1]:
				_box(p + Vector3(i * 0.9, 2.2 + (0.4 if i == 0 else 0.0), 0), Vector3(0.35, 4.4 + (0.8 if i == 0 else 0.0), 0.3), Color(0.92, 0.92, 0.9), 0.0, DhakaMaterials.PLASTER)
			_cyl(p + Vector3(0, 3.0, -0.6), 1.3, 0.1, Color(0.8, 0.1, 0.1), Basis(Vector3.RIGHT, PI * 0.5))
			_collider(props, p + Vector3(0, 2.2, 0), Vector3(2.4, 4.4, 0.4))
		"d":
			_box(p + Vector3(0, 3.2, 0), Vector3(C, 6.4, C), Color(0.92, 0.92, 0.88), 0.0, DhakaMaterials.PLASTER)
			_collider(statics, p + Vector3(0, 3.2, 0), Vector3(C, 6.4, C))
			_sphere(p + Vector3(0, 7.6, 0), Vector3(4.0, 3.2, 4.0), Color(0.95, 0.95, 0.92))
			_cyl(p + Vector3(1.8, 9.0, 1.8), 0.35, 18.0, Color(0.92, 0.92, 0.88))
		"l":
			_laundry(p)
		"z":
			_kites(p)
		"%":
			var along_x := at(f, x - 1, y) != " " or at(f, x + 1, y) != " "
			var size := Vector3(C, 0.08, 0.7) if along_x else Vector3(0.7, 0.08, C)
			_box(p + Vector3(0, -0.04, 0), size, Color(0.5, 0.36, 0.2), 0.05)
			_collider(statics, p + Vector3(0, -0.04, 0), size)
		">", "<", "^", "v":
			_ramp(f, x, y, ch)
		"D":
			_floor_tile(f, p)
			var axis := "x" if at(f, x - 1, y) == "#" or at(f, x + 1, y) == "#" else "z"
			_interactable("door", {"axis": axis}, p)
		"G":
			if at(f, x - 1, y) != "G" and at(f, x, y - 1) != "G":
				var along := "x" if at(f, x + 1, y) == "G" or at(f, x - 1, y) == "#" or at(f, x + 1, y) == "#" else "z"
				var n := 1
				while at(f, x + (n if along == "x" else 0), y + (0 if along == "x" else n)) == "G":
					n += 1
				for i in n:
					var gp := cell_pos(f, x + (i if along == "x" else 0), y + (0 if along == "x" else i))
					var it := _interactable("gate", {"axis": along, "key": "gate%d" % gates.size()}, gp)
					it.set_meta("gate_index", gates.size())
				gates.append(gates.size())
		"L":
			_floor_tile(f, p)
			var lift := _interactable("lift", {"key": "%d,%d" % [x, y], "floor": f}, p)
			lifts.append(lift)
		_:
			if MARKS.contains(ch) or CUSTOM.contains(ch):
				if not markers.has(ch):
					markers[ch] = []
				markers[ch].append(p)
				if _indoor(f, x, y) or f > 0:
					_floor_tile(f, p)


func _floor_tile(f: int, p: Vector3) -> void:
	if f == 0:
		_box(p + Vector3(0, 0.02, 0), Vector3(C, 0.04, C), _pal.tile, 0.03, DhakaMaterials.TILE)


func _ramp(f: int, x: int, y: int, ch: String) -> void:
	var dir: Vector2i = {">": Vector2i(1, 0), "<": Vector2i(-1, 0), "v": Vector2i(0, 1), "^": Vector2i(0, -1)}[ch]
	if at(f, x - dir.x, y - dir.y) == ch:
		return
	var n := 1
	while n < 4 and at(f, x + dir.x * n, y + dir.y * n) == ch:
		n += 1
	var d3 := Vector3(dir.x, 0, dir.y)
	var start := cell_pos(f, x, y) - d3 * (C * 0.5)
	var end := start + d3 * (n * C) + Vector3(0, H, 0)
	var basis := Basis.looking_at((end - start).normalized(), Vector3.UP)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(C, 0.2, start.distance_to(end))
	shape.shape = box
	shape.transform = Transform3D(basis, (start + end) * 0.5 - basis.y * 0.1)
	statics.add_child(shape)
	var steps := n * 6
	var depth := n * C / steps
	for i in steps:
		var top := (i + 1) * H / steps
		var c := start + d3 * (depth * (i + 0.5)) + Vector3(0, top * 0.5, 0)
		var size := Vector3(depth, top, C) if dir.x != 0 else Vector3(C, top, depth)
		_box(c, size, Color(0.62, 0.62, 0.64).darkened(0.04 * (i % 2)), 0.0, DhakaMaterials.CONCRETE)


func _interactable(kind: String, info: Dictionary, p: Vector3) -> Interactable:
	var it := Interactable.new()
	it.setup(kind, info)
	it.position = p
	root.add_child(it)
	return it


func _fan(p: Vector3) -> void:
	var a := Animated.new()
	a.mode = "spin"
	a.speed = 1.0
	a.position = p
	root.add_child(a)
	for i in 3:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.02, 0.12)
		blade.mesh = bm
		blade.material_override = Humanoid.mat(Color(0.85, 0.85, 0.82))
		blade.rotation.y = i * TAU / 3.0
		blade.position = Vector3(cos(i * TAU / 3.0), 0, -sin(i * TAU / 3.0)) * 0.42
		a.add_child(blade)


func _lamp(p: Vector3) -> void:
	_cyl(p + Vector3(0.8, 2.6, 0.8), 0.06, 5.2, Color(0.3, 0.3, 0.32))
	_box(p + Vector3(0.5, 5.2, 0.8), Vector3(0.7, 0.12, 0.25), Color(0.3, 0.3, 0.32), 0.0)
	var l := OmniLight3D.new()
	l.position = p + Vector3(0.3, 5.0, 0.8)
	l.omni_range = 11.0
	l.light_energy = 0.0
	l.light_color = Color(1.0, 0.72, 0.4)
	root.add_child(l)
	lamps.append(l)


func _rickshaw(p: Vector3) -> void:
	_box(p + Vector3(0, 0.9, 0.3), Vector3(1.0, 0.18, 0.7), Color(0.6, 0.1, 0.12), 0.0)
	_box(p + Vector3(0, 1.45, 0.65), Vector3(1.0, 0.9, 0.08), BRIGHT[int(p.x + p.z) % BRIGHT.size()], 0.0)
	_box(p + Vector3(0, 1.95, 0.35), Vector3(1.1, 0.06, 0.9), Color(0.1, 0.1, 0.1), 0.0)
	_box(p + Vector3(0, 0.95, -0.7), Vector3(0.12, 0.08, 1.0), Color(0.2, 0.2, 0.2), 0.0)
	for wx in [-0.55, 0.55]:
		_cyl(p + Vector3(wx, 0.35, 0.35), 0.35, 0.06, Color(0.08, 0.08, 0.08), Basis(Vector3.FORWARD, PI * 0.5))
	_cyl(p + Vector3(0, 0.35, -1.1), 0.35, 0.06, Color(0.08, 0.08, 0.08), Basis(Vector3.FORWARD, PI * 0.5))
	_collider(props, p + Vector3(0, 0.8, 0), Vector3(1.2, 1.6, 2.0))


func _laundry(p: Vector3) -> void:
	_cyl(p + Vector3(-0.9, 1.0, 0), 0.03, 2.0, Color(0.3, 0.3, 0.3))
	_cyl(p + Vector3(0.9, 1.0, 0), 0.03, 2.0, Color(0.3, 0.3, 0.3))
	for i in 3:
		var a := Animated.new()
		a.mode = "sway"
		a.speed = 1.0 + i * 0.3
		a.position = p + Vector3(-0.6 + i * 0.6, 1.95, 0)
		root.add_child(a)
		var cloth := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.8, 0.02)
		cloth.mesh = bm
		cloth.position = Vector3(0, -0.4, 0)
		cloth.material_override = Humanoid.mat(BRIGHT[(i + int(p.x)) % BRIGHT.size()].lightened(0.3))
		a.add_child(cloth)


func _kites(p: Vector3) -> void:
	for i in 3:
		var a := Animated.new()
		a.mode = "kite"
		a.speed = 0.6 + i * 0.25
		a.position = p + Vector3(i * 6.0 - 6.0, 22.0 + i * 3.0, -8.0 - i * 4.0)
		root.add_child(a)
		var kite := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.9, 0.02)
		kite.mesh = bm
		kite.rotation.z = PI * 0.25
		var m := StandardMaterial3D.new()
		m.albedo_color = BRIGHT[i % BRIGHT.size()]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		kite.material_override = m
		a.add_child(kite)


func _water(p: Vector3) -> void:
	if _water_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode cull_disabled;\nvoid vertex() { VERTEX.y += sin(VERTEX.x * 2.1 + TIME * 1.5) * 0.04 + cos(VERTEX.z * 1.7 + TIME * 1.1) * 0.04; }\nvoid fragment() { vec3 deep = vec3(0.1, 0.24, 0.28); ALBEDO = deep + 0.05 * sin(UV.x * 24.0 + TIME * 2.0) * vec3(0.4, 0.7, 0.8); ROUGHNESS = 0.12; SPECULAR = 0.8; }\n"
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = sh
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(C, C)
	pm.subdivide_width = 3
	pm.subdivide_depth = 3
	mi.mesh = pm
	mi.material_override = _water_mat
	mi.position = p + Vector3(0, 0.06, 0)
	root.add_child(mi)
	_collider(statics, p + Vector3(0, 0.6, 0), Vector3(C, 1.2, C))
	hazards.append([p, "drown"])


func _collider(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	body.add_child(cs)


func _box(center: Vector3, size: Vector3, c: Color, jitter: float, surf: int = 0, variant: int = 0) -> void:
	var v := c
	if jitter > 0.0:
		v = c.lightened(_rng.randf_range(0.0, jitter)) if _rng.randf() < 0.5 else c.darkened(_rng.randf_range(0.0, jitter))
	_boxes.append([Transform3D(Basis.from_scale(size), center), v, surf, variant % 6])


func _sphere(center: Vector3, size: Vector3, c: Color) -> void:
	_spheres.append([Transform3D(Basis.from_scale(size), center), c])


func _cyl(center: Vector3, radius: float, hh: float, c: Color, rot := Basis.IDENTITY) -> void:
	_cyls.append([Transform3D(rot * Basis.from_scale(Vector3(radius * 2.0, hh * 0.5, radius * 2.0)), center), c])


func _flush() -> void:
	# one MultiMesh per surface material: brick walls, plaster, concrete, asphalt, tin, awnings, tiles
	var groups: Dictionary = {}
	for b in _boxes:
		var k := "%d_%d" % [b[2], b[3]]
		if not groups.has(k):
			groups[k] = []
		groups[k].append(b)
	for k in groups:
		var parts: PackedStringArray = String(k).split("_")
		var surf := int(parts[0])
		var mat: Material = null
		if surf != DhakaMaterials.PAINT:
			mat = DhakaMaterials.surface(surf, int(parts[1]))
		_multimesh(groups[k], BoxMesh.new(), mat)
	var sm := SphereMesh.new()
	sm.radial_segments = 16
	sm.rings = 8
	_multimesh(_spheres, sm)
	var cm := CylinderMesh.new()
	cm.radial_segments = 14
	_multimesh(_cyls, cm)


func _multimesh(items: Array, mesh: PrimitiveMesh, mat: Material = null) -> void:
	if items.is_empty():
		return
	if mat == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.9
		mat = m
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	root.add_child(mi)
