class_name SetPieceGen
extends RefCounted
## Planners for set pieces (data/gen/setpieces.json, SetPieces): famous places built from their
## recipe with SceneGen's building blocks. `plot`: a landmark building on its own grounds with its
## annexes (Fort Sumter, Ziggurat HQ, Totentanz, Trauma Team Tower, Eurasiabank Plaza); `port`:
## quays, moored and anchored ships and the floats between them (Main Port and Flotsam);
## `compound`: buildings round a central court inside a perimeter wall (the Potentilla's five
## petals, MAX-TAC's castle wings). After the scene's own guard posts, posts() adds the recipe's
## posts (roof snipers, AA gunners, checkpoints), which the guards man first. Set pieces have props
## of their own (PIECES: a school cupola, a flagpole, a warship's turret ...), real cover the view
## draws with SetPieceDressing.

const G := TacMap.G
const T := TacMap.T
const GROUNDS := {"asphalt": G.ASPHALT, "sidewalk": G.SIDEWALK, "gravel": G.GRAVEL, "dirt": G.DIRT, "concrete": G.CONCRETE,
	"grass": G.GRASS, "dock": G.DOCK}
const ROAD := 6   ## street depth (SceneGen.road: sidewalks either side)

## Set pieces' own props: piece → [material, thick] (cover HP from armor.json like Furnish's).
## A school's roof cupola (brick and timber: concrete thick), a flagpole (steel thin), a tower's
## crowning spire, a warship's gun turret, mast and funnel (steel thick), the Potentilla's
## columbarium (stone thick), an AV parked on its pad and a burnt-out school bus (vehicle bodies:
## steel thin, like a car).
const PIECES := {"cupola": ["concrete", true], "flagpole": ["steel", false], "spire": ["steel", true],
	"turret": ["steel", true], "mast": ["steel", true], "funnel": ["steel", true], "columbarium": ["stone", true],
	"av": ["steel", false], "bus": ["steel", false]}
## Multi-square set-piece props: piece → [w, h] squares.
const SIZES := {"cupola": [3, 3], "spire": [3, 3], "turret": [2, 2], "funnel": [2, 2], "columbarium": [3, 3], "av": [3, 3], "bus": [1, 5]}


static func _sp(c: Dictionary) -> Dictionary:
	return SetPieces.get_def(String(c.p.setpiece))


static func _roll(dice: Dice, r: Variant) -> int:
	if r is Array:
		return dice.rng.randi_range(int(r[0]), int(r[1]))
	return int(r)


## Map size: a plot set piece is its main building's footprint, the front yard, margins, its
## annexes and the street; the port's are in its params. The recipe owns the size
## (SetPieces.overrides drops a caller's w / h / floors).
static func size(dice: Dice, p: Dictionary, _overrides: Dictionary) -> void:
	var sp := SetPieces.get_def(String(p.setpiece))
	if String(sp.get("base", {}).get("planner", "")) == "compound":
		_compound_size(dice, p, sp)
		return
	if String(sp.get("base", {}).get("planner", "")) != "plot":
		return
	var main_def := SetPieces.site_def("", String(p.setpiece), "main")
	var fl: Array = main_def.get("floors", [p.floors, p.floors])
	p.floors = dice.rng.randi_range(int(fl[0]), int(fl[1]))
	var plot: Dictionary = sp.get("plot", {})
	var fw := _roll(dice, main_def.footprint.w)
	var fd := _roll(dice, main_def.footprint.d)
	var margin := int(plot.get("margin", 3))
	var front := _roll(dice, plot.get("front", 6))
	var w := margin * 2 + fw
	var h := margin + fd + front + ROAD
	var annexes: Array = []
	for a in plot.get("annexes", []):
		var ad := {"part": a.part, "where": a.where, "gap": _roll(dice, a.gap), "w": _roll(dice, a.w), "d": _roll(dice, a.d), "floors": int(a.get("floors", 1))}
		if ad.where == "behind":
			h += ad.d + ad.gap
		else:
			w += ad.w + ad.gap
		annexes.append(ad)
	var side := _roll(dice, plot.get("side_yard", 0))   # open ground beside the building (a schoolyard)
	w += side
	p["_plot"] = {"fw": fw, "fd": fd, "margin": margin, "front": front, "annexes": annexes, "side": side}
	p.w = w
	p.h = h


static func run(c: Dictionary) -> void:
	match String(_sp(c).get("base", {}).get("planner", "plot")):
		"port": port(c)
		"compound": compound(c)
		_: plot(c)
	_props(c)


# --- Plot: a landmark building on its grounds -----------------------------------------------------

## The main building faces the street (south) across a front yard; annexes stand behind it or
## beside it on the same grounds (an outdoor structure with its yard, fenced or open as a plaza).
static func plot(c: Dictionary) -> void:
	var m: TacMap = c.m
	var sp := _sp(c)
	var plot_def: Dictionary = sp.get("plot", {})
	var pl: Dictionary = c.p._plot   # size() drew the footprint, yard and annexes
	var sec := int(c.p.security)
	var road_y := m.h - ROAD
	SceneGen.road(c, Rect2i(0, road_y, m.w, ROAD), true)
	var lot := Rect2i(0, 0, m.w, road_y)
	SceneGen.ground(c, lot, GROUNDS.get(String(plot_def.get("ground", "concrete")), G.CONCRETE))
	var margin := int(pl.margin)
	var behind := 0
	var beside := int(pl.get("side", 0))
	for a in pl.annexes:
		if a.where == "behind":
			behind = int(a.d) + int(a.gap)
		else:
			beside += int(a.w) + int(a.gap)
	var main_shell := Rect2i(margin, margin + behind, int(pl.fw), int(pl.fd))
	main_shell.size = Vector2i(mini(main_shell.size.x, m.w - margin * 2 - beside), mini(main_shell.size.y, road_y - int(pl.front) - main_shell.position.y))
	var mst := SceneGen.building(c, main_shell, String(sp.sites.main.base), int(c.p.floors), sec, true, TacMap.Zone.PUBLIC, "S", {}, "main")
	var sid := SceneGen.outdoor_structure(c, "grounds", maxi(sec - 1, 0), lot)
	SceneGen.related(c, mst.id, sid, 0.7)
	for a in pl.annexes:
		var shell: Rect2i
		if a.where == "behind":
			var ax: int = main_shell.position.x + c.dice.rng.randi_range(0, maxi(0, main_shell.size.x - int(a.w)))
			shell = Rect2i(ax, margin, int(a.w), int(a.d))
		else:
			shell = Rect2i(main_shell.end.x + int(a.gap), main_shell.end.y - int(a.d), int(a.w), int(a.d))
		var ast := SceneGen.building(c, shell, String(sp.sites[a.part].base), int(a.floors), maxi(sec - 1, 0), false, TacMap.Zone.PUBLIC, "S", {}, String(a.part))
		SceneGen.related(c, ast.id, sid, 0.6)
	# The front path from the street to the main door stays clear.
	var door := m.main_entrance()
	var gate := Vector2i(m.w / 2, road_y - 1)
	var front_r := Rect2i(1, main_shell.end.y + 1, m.w - 2, road_y - main_shell.end.y - 2)
	# A front lawn (or other ground) between the building and the street.
	if plot_def.has("front_ground"):
		for y in range(main_shell.end.y, road_y):
			for x in m.w:
				if m.t(0, x, y) == T.OUTSIDE and m.label(0, x, y) < 0:
					m.set_ground(x, y, GROUNDS.get(String(plot_def.front_ground), G.GRASS))
	var path_w := int(plot_def.get("approach", {}).get("w", 3))
	if not door.is_empty():
		gate = Vector2i(door.pos.x, road_y - 1)
		for y in range(door.pos.y + 1, road_y):
			SceneGen.reserve(c, Rect2i(door.pos.x - path_w / 2, y, path_w, 1))
			if String(plot_def.get("ground", "concrete")) != "concrete" or plot_def.has("front_ground"):
				SceneGen.ground(c, Rect2i(door.pos.x - path_w / 2, y, path_w, 1), G.CONCRETE)
	var fenced: bool = plot_def.get("fence", false)
	# An approach of its own (Totentanz: the street up to the club door is anyone's; the ruins
	# round it are Maelstrom's): a yard over the path, zoned apart from the rest of the lot.
	if plot_def.has("approach") and not door.is_empty():
		var ap: Dictionary = plot_def.approach
		SceneGen.yard(c, Rect2i(door.pos.x - path_w / 2, door.pos.y + 1, path_w, road_y - door.pos.y - 1 - (1 if fenced else 0)),
			String(ap.get("kind", "plaza")), Layouts._zone_of(String(ap.get("zone", "public"))), sid)
	var kind := String(plot_def.get("yard", "compound_yard"))
	var zone := Layouts._zone_of(String(plot_def.get("zone", "public")))
	var yard_room := SceneGen.yard(c, Rect2i(0, 0, m.w, road_y - (1 if fenced else 0)), kind, zone, sid)
	if fenced:
		SceneGen.fence(c, Rect2i(-1, -1, m.w + 2, road_y + 1), [gate], yard_room, int(plot_def.get("fence_mat", 3)))
		m.doors[-1].b = m.label(0, gate.x, gate.y - 1)
	# A flagpole on the front lawn, beside the path to the door (before the dressing takes the lawn).
	if plot_def.get("flagpole", false) and not door.is_empty():
		var done := false
		for dy in [3, 2, 4, 5]:
			for dx in [path_w / 2 + 2, -(path_w / 2 + 2), path_w / 2 + 3, -(path_w / 2 + 3), path_w / 2 + 5, -(path_w / 2 + 5)]:
				var v := Vector2i(door.pos.x + dx, door.pos.y + dy)
				if not done and m.label(0, v.x, v.y) >= 0 and m.rooms[m.label(0, v.x, v.y)].get("outdoor", false) \
						and try_piece(m, 0, Rect2i(v, Vector2i.ONE), "flagpole", m.label(0, v.x, v.y), {}, c.reserved):
					done = true
	# Dressing: the recipe's, else a plaza gets planters and trees, a yard barriers and crates.
	if plot_def.has("dress"):
		for d in plot_def.dress:
			var area := front_r if String(d.get("area", "front")) == "front" else Rect2i(1, 1, m.w - 2, road_y - 2)
			_dress(c, yard_room, area, String(d.piece), _roll(c.dice, d.get("count", 1)))
	elif kind == "plaza":
		_dress(c, yard_room, front_r, "planter", 5 + c.dice.d(4))
		_dress(c, yard_room, front_r, "tree", 3 + c.dice.d(3))
	else:
		_dress(c, yard_room, front_r, "barrier", 3 + c.dice.d(3))
		_dress(c, yard_room, Rect2i(1, 1, m.w - 2, road_y - 2), "crate", 4 + c.dice.d(4))
	Furnish.run_structure(m, c.dice, sid)
	if m.devices.any(func(d): return d.structure == sid):
		m.architectures[sid] = NetGen.generate(m, c.dice, sid)
	SceneGen.curb_cars(c, Rect2i(0, road_y, m.w, ROAD), true)
	SceneGen.spawn(c, Vector2i(0, m.h - 3))
	SceneGen.spawn(c, Vector2i(m.w - 1, m.h - 3))


## Scatter one-square props over a yard's own squares inside `r` (never indoors).
static func _dress(c: Dictionary, room: Dictionary, r: Rect2i, piece: String, n: int) -> void:
	var m: TacMap = c.m
	var cells := Furnish.room_cells(m, room).filter(func(v): return r.has_point(v))
	var allowed := {}
	for v in cells:
		allowed[v] = true
	Layouts._shuffle(c.dice, cells)
	var sz := piece_size(piece)
	var placed := 0
	for v in cells:
		if placed >= n:
			break
		var fp := Vector2i(sz[0], sz[1]) if c.dice.d(2) == 1 else Vector2i(sz[1], sz[0])
		if try_piece(m, 0, Rect2i(v, fp), piece, int(room.id), allowed, c.reserved):
			placed += 1


## A piece's footprint in squares (set-piece props, else Furnish's multi-square props, else 1x1).
static func piece_size(piece: String) -> Array:
	return SIZES.get(piece, Furnish.PROP_SIZES.get(piece, [1, 1]))


## A cover entry for a piece: a set piece's own (PIECES), else Furnish's.
static func piece_entry(piece: String, f: int, pos: Vector2i, room: int, prop := -1) -> Dictionary:
	if not PIECES.has(piece):
		return Furnish.cover_entry(piece, f, pos, room, prop)
	var mat: Array = PIECES[piece]
	var hp := int(RulesDB.load_json("armor.json")["cover_hp"][mat[0]][0 if mat[1] else 1])
	return {"floor": f, "pos": pos, "kind": piece, "material": mat[0], "thick": mat[1], "hp": hp, "room": room, "prop": prop, "hazard": ""}


## Furnish.try_prop for any piece (set-piece props too): every square open and unreserved, a
## one-square ring clear of other cover, doorways and stairs. Multi-square pieces share a prop id.
static func try_piece(m: TacMap, f: int, rect: Rect2i, piece: String, room: int, allowed: Dictionary = {}, reserved: Dictionary = {}) -> bool:
	if not PIECES.has(piece):
		return Furnish.try_prop(m, f, rect, piece, room, allowed, reserved)
	for y in range(rect.position.y - 1, rect.end.y + 1):
		for x in range(rect.position.x - 1, rect.end.x + 1):
			var v := Vector2i(x, y)
			if rect.has_point(v):
				if not m.inb(x, y) or not Furnish.open_tile(m.t(f, x, y)) or reserved.has(v) or (not allowed.is_empty() and not allowed.has(v)):
					return false
			if m.has_cover_at(f, v) or m.t(f, x, y) in [T.DOOR, T.STAIRS, T.ELEVATOR] or m.is_connector_end(f, v):
				return false
	var multi := rect.size != Vector2i.ONE
	var prop := m.cover.size() if multi else -1
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			m.add_cover(piece_entry(piece, f, Vector2i(x, y), room, prop))
	return true


# --- Compound: buildings round a court --------------------------------------------------------

## The compound's layout, drawn once (size() runs before the map exists): the court in the middle,
## each building `at` [x, y] (-1..1, in court half-widths: [0, -1] north of it, [0.55, 1] south-east)
## set `gap` squares off the court with its entrance facing it, the perimeter `margin` round them.
static func _compound_size(dice: Dice, p: Dictionary, sp: Dictionary) -> void:
	var cp: Dictionary = sp.get("compound", {})
	var court_def: Dictionary = cp.get("court", {})
	var cw := _roll(dice, court_def.get("w", 14))
	var ch := _roll(dice, court_def.get("d", 12))
	var court := Rect2i(-cw / 2, -ch / 2, cw, ch)
	var bounds := court
	var blds: Array = []
	var floors := 1
	for b in cp.get("buildings", []):
		var at: Array = b.at
		var entry := String(b.get("entry", ""))
		if entry == "":
			entry = ("S" if float(at[1]) < 0 else "N") if absf(float(at[1])) >= absf(float(at[0])) else ("W" if float(at[0]) > 0 else "E")
		var bw := _roll(dice, b.w)   # along its entrance facade
		var bd := _roll(dice, b.d)   # into the building
		var sz := Vector2i(bw, bd) if entry in ["S", "N"] else Vector2i(bd, bw)
		var gap := _roll(dice, b.get("gap", 3))
		var ctr := Vector2(float(at[0]) * (cw / 2.0 + gap + sz.x / 2.0), float(at[1]) * (ch / 2.0 + gap + sz.y / 2.0))
		var rect := Rect2i(Vector2i(roundi(ctr.x - sz.x / 2.0), roundi(ctr.y - sz.y / 2.0)), sz)
		var fl := _roll(dice, b.get("floors", 1))
		floors = maxi(floors, fl)
		bounds = bounds.merge(rect)
		blds.append({"part": String(b.part), "rect": rect, "entry": entry, "floors": fl, "zone": String(b.get("zone", "staff"))})
	var margin := int(cp.get("margin", 4))
	var off := Vector2i(margin, margin) - bounds.position
	court.position += off
	for b in blds:
		b.rect = Rect2i(b.rect.position + off, b.rect.size)
	p["_compound"] = {"court": court, "buildings": blds}
	p.w = bounds.size.x + margin * 2
	p.h = bounds.size.y + margin * 2 + ROAD
	p.floors = floors


## Buildings round a central court (a garden, a parade square, a memorial), inside a perimeter wall
## or fence with one gate on the street and a guard booth behind it; a path from the gate to the
## court, which is reached through the gaps between the buildings.
static func compound(c: Dictionary) -> void:
	var m: TacMap = c.m
	var sp := _sp(c)
	var cp: Dictionary = sp.get("compound", {})
	var lay: Dictionary = c.p._compound
	var sec := int(c.p.security)
	var target := String(c.p.get("target", "main"))
	var road_y := m.h - ROAD
	SceneGen.road(c, Rect2i(0, road_y, m.w, ROAD), true)
	var lot := Rect2i(0, 0, m.w, road_y)
	SceneGen.ground(c, lot, GROUNDS.get(String(cp.get("ground", "concrete")), G.CONCRETE))
	var court: Rect2i = lay.court
	var court_def: Dictionary = cp.get("court", {})
	SceneGen.ground(c, court, GROUNDS.get(String(court_def.get("ground", "grass")), G.GRASS))
	var sid := SceneGen.outdoor_structure(c, "grounds", maxi(sec - 1, 0), lot)
	for b in lay.buildings:
		var part := String(b.part)
		var st := SceneGen.building(c, b.rect, String(sp.sites[part].base), int(b.floors), sec if part == target else maxi(sec - 1, 1),
			part == target, Layouts._zone_of(String(b.zone)), String(b.entry), {}, part)
		SceneGen.related(c, st.id, sid, 0.7)
	# The gate under the court's middle, a paved path from it up to the court.
	var gx := court.get_center().x
	var gate := Vector2i(gx, road_y - 1)
	for y in range(court.end.y, road_y):
		for x in range(gx - 1, gx + 2):
			if m.t(0, x, y) == T.OUTSIDE and m.label(0, x, y) < 0:
				SceneGen.reserve(c, Rect2i(x, y, 1, 1))
				m.set_ground(x, y, G.CONCRETE)
	if cp.get("booth", true):   # inside the gate, on whichever side has room
		for bx in [gx + 2, gx - 7, 3, m.w - 8]:
			var booth := Rect2i(bx, road_y - 6, 5, 4)
			if _free(m, booth.grow(1)):
				var bst := SceneGen.building(c, booth, "guard_booth", 1, maxi(sec - 1, 0), false, TacMap.Zone.STAFF)
				SceneGen.related(c, bst.id, sid, 0.9)
				break
	var zone := Layouts._zone_of(String(cp.get("zone", "staff")))
	var court_room := SceneGen.yard(c, court, String(court_def.get("kind", "courtyard")), Layouts._zone_of(String(court_def.get("zone", "staff"))), sid)
	var inside := Rect2i(2, 2, m.w - 4, road_y - 3)
	var yard_room := SceneGen.yard(c, inside, String(cp.get("yard", "compound_yard")), zone, sid)
	SceneGen.fence(c, Rect2i(1, 1, m.w - 2, road_y - 1), [gate], yard_room, int(cp.get("wall_mat", 3)))
	# Dressing the court and the grounds (the recipe's; the court's centrepiece is a prop).
	for d in cp.get("dress", []):
		var room := court_room if String(d.get("area", "yard")) == "court" else yard_room
		_dress(c, room, inside, String(d.piece), _roll(c.dice, d.get("count", 1)))
	Furnish.run_structure(m, c.dice, sid)
	if m.devices.any(func(d): return d.structure == sid):
		m.architectures[sid] = NetGen.generate(m, c.dice, sid)
	SceneGen.curb_cars(c, Rect2i(0, road_y, m.w, ROAD), true)
	SceneGen.spawn(c, Vector2i(0, m.h - 3))
	SceneGen.spawn(c, Vector2i(m.w - 1, m.h - 3))


## Every square of `r` is open, unlabelled ground (nothing built there yet).
static func _free(m: TacMap, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not m.inb(x, y) or m.t(0, x, y) != T.OUTSIDE or m.label(0, x, y) >= 0:
				return false
	return true


# --- Port: quays, ships and Flotsam --------------------------------------------------------------

## The working quays along the shore (Quay 1 hand-offloaded, Quays 2-3 with cranes, rail and the
## freighter, Quay 4 with the drone hangar, Quay 5 half built), the fenced container yard and the
## gate on the road; out in the bay, Flotsam: the three anchor ships (the OGV Lund, the Sakata
## Maru, the Rose) on a web of floats and kelongs, joined to the quays by a long float walkway.
static func port(c: Dictionary) -> void:
	var m: TacMap = c.m
	var sec := int(c.p.security)
	var target := String(c.p.get("target", "sakata_maru"))
	var rng: RandomNumberGenerator = c.dice.rng
	var quay_y := 48                # the quay edge (sea above)
	var road_y := m.h - ROAD
	var q2 := 22                    # Quays 2-3 start
	var q4 := 80                    # Quay 4 start
	var q5 := m.w - 22              # Quay 5 (half built) start
	SceneGen.water(c, Rect2i(0, 0, m.w, quay_y))
	SceneGen.road(c, Rect2i(0, road_y, m.w, ROAD), true)
	SceneGen.ground(c, Rect2i(0, quay_y, m.w, road_y - quay_y), G.CONCRETE)
	SceneGen.ground(c, Rect2i(0, quay_y, q5, 7), G.DOCK)
	# Quay 5: the landward half poured, the seaward half still open water.
	SceneGen.ground(c, Rect2i(q5, quay_y + 3, m.w - q5, 4), G.CONCRETE)
	SceneGen.water(c, Rect2i(q5 + 4, quay_y, m.w - q5 - 4, 3))
	SceneGen.ground(c, Rect2i(0, quay_y + 8, q4, 2), G.RAIL)   # rail from Quays 2-3 to the Yard

	# Flotsam: the float row the anchor ships lie along, the walkway to the quay, the Rose's float.
	var fy := 19 + rng.randi_range(-1, 1)
	var walk_x := q5 - 6 + rng.randi_range(-1, 1)   # the walkway lands on Quay 4
	var freighter := Rect2i(q2 + 3 + rng.randi_range(0, 3), quay_y - 12, q4 - q2 - 8, 12)
	SceneGen.ground(c, Rect2i(0, fy, walk_x + 2, 2), G.DOCK)
	SceneGen.ground(c, Rect2i(walk_x, fy, 2, quay_y - fy), G.DOCK)
	SceneGen.reserve(c, Rect2i(walk_x, quay_y - 2, 2, 3))   # no fence across the walkway
	var rose_len := 20 + rng.randi_range(0, 4)
	var rose := Rect2i(walk_x - 5 - rose_len, fy + 6, rose_len, 6)
	SceneGen.ground(c, Rect2i(rose.position.x, rose.end.y, walk_x - rose.position.x, 2), G.DOCK)
	SceneGen.ground(c, Rect2i(rose.end.x, rose.position.y + 2, walk_x - rose.end.x, 2), G.DOCK)
	# Kelongs: float platforms with a shack each, off the walkway and the floats.
	var k2x := maxi(rose.position.x + 2 + rng.randi_range(0, 3), freighter.end.x + 3)
	var kelongs: Array[Rect2i] = [Rect2i(walk_x + 2, fy + 4 + rng.randi_range(0, 3), mini(16, m.w - walk_x - 3), 9),
		Rect2i(k2x, rose.end.y + 2, mini(14, walk_x - k2x), 9),
		Rect2i(8 + rng.randi_range(0, 16), fy + 2, 14, 9)]
	for k in kelongs:
		SceneGen.ground(c, k, G.DOCK)
	# Ships. Shells end on the float row so their south facade (the gangway side) faces it.
	var sakata_len := 46 + rng.randi_range(0, 4)
	var sakata := Rect2i(walk_x - 2 - sakata_len, fy - 14, sakata_len, 14)
	var lund := Rect2i(2, fy - 15, sakata.position.x - 7, 15)
	# Flotsam's programmed ships are entered like buildings (the gangway hall, the Pilots' Club):
	# their briefs zone them from public in, so their base is the public level.
	# The Sakata Maru was built as a warship: a long raked bow, a square transom stern.
	var sak_st := SceneGen.building(c, sakata, "ship", int(c.p.floors), sec, target == "sakata_maru", TacMap.Zone.PUBLIC, "S", hull(sakata, "E", 12), "sakata_maru")
	var rose_st := SceneGen.building(c, rose, "ship", 1, maxi(sec - 1, 1), target == "rose", TacMap.Zone.PUBLIC, "S", hull(rose, "both", 4), "rose")
	var lund_st := SceneGen.building(c, lund, "ship", 1, 1, target == "lund", TacMap.Zone.STAFF, "S", hull(lund, "W", 6), "lund")
	var fr_floors := mini(2, int(c.p.floors))
	var fr_st := SceneGen.building(c, freighter, "ship", fr_floors, sec, target == "freighter", TacMap.Zone.PUBLIC, "S", hull(freighter, "W", 5), "freighter")
	for k in kelongs:
		var shack := Rect2i(k.position.x + 2, k.position.y + 1, mini(8, k.size.x - 4), 6)
		SceneGen.building(c, shack, "shack", 1, 1, false, TacMap.Zone.STAFF, "S", {}, "kelong")
	# The freighter's gangway: keep the quay clear in front of its door.
	for e in m.entrances:
		if e.get("structure", -1) == fr_st.id:
			SceneGen.reserve(c, Rect2i(e.pos.x - 2, e.pos.y + 1, 5, 4))
	# Quay 4: the cargo-drone hangar and control, facing the quay.
	var hangar := Rect2i(q4 + 2, quay_y + 9, q5 - q4 - 4, 13)
	var hg_st := SceneGen.building(c, hangar, "warehouse", 1, maxi(sec - 1, 0), target == "drone_hangar", TacMap.Zone.STAFF, "N", {}, "drone_hangar")
	# The gate on the road and its booth.
	var gate := Vector2i(q2 + (q4 - q2) / 2 + rng.randi_range(-4, 4), road_y - 1)
	SceneGen.reserve(c, Rect2i(gate.x - 1, gate.y - 3, 3, 4))
	var booth := Rect2i(gate.x + 3, road_y - 8, 6, 5)
	var booth_st := SceneGen.building(c, booth, "guard_booth", 1, maxi(sec - 1, 0), false, TacMap.Zone.STAFF)
	var sid := SceneGen.outdoor_structure(c, "port", maxi(sec - 1, 0), Rect2i(0, quay_y, m.w, road_y - quay_y))
	var fsid := SceneGen.outdoor_structure(c, "flotsam", sec, Rect2i(0, 0, m.w, quay_y))
	for pair in [[fr_st, sid, 0.8], [hg_st, sid, 0.8], [booth_st, sid, 0.9], [sak_st, fsid, 0.8], [rose_st, fsid, 0.9], [sak_st, rose_st, 0.6]]:
		SceneGen.related(c, pair[0].id, pair[1] if pair[1] is int else pair[1].id, pair[2])
	# Cranes: two per quay on Quays 2 and 3 (and two on Quay 4), steel legs either side of the apron.
	var cranes: Array[int] = []
	for k in 4:
		cranes.append(q2 + 3 + k * (q4 - q2 - 8) / 3)
	cranes.append_array([q4 + 3, q4 + 14])
	for cx in cranes:
		for leg in [Vector2i(cx, quay_y + 1), Vector2i(cx, quay_y + 5), Vector2i(cx + 4, quay_y + 1), Vector2i(cx + 4, quay_y + 5)]:
			if not c.reserved.has(leg) and m.t(0, leg.x, leg.y) == T.OUTSIDE and not m.has_cover_at(0, leg):
				m.add_cover(Furnish.cover_entry("crane_leg", 0, leg, -1))
	# Quay 1 is offloaded by hand: pallets and crates on the apron.
	SceneGen.props(c, Rect2i(1, quay_y + 1, q2 - 2, 5), "pallet", 6)
	SceneGen.props(c, Rect2i(1, quay_y + 1, q2 - 2, 5), "crate", 5)
	# The container yard behind the quays: stacks with lanes, like the shipyard's.
	var yard_r := Rect2i(3, quay_y + 11, hangar.position.x - 6, road_y - quay_y - 14)
	for by in range(yard_r.position.y, yard_r.end.y - 2, 5):
		for bx in range(yard_r.position.x, yard_r.end.x - 6, 9):
			if rng.randf() < 0.75:
				for dy in 2:
					for dx in 6:
						var v := Vector2i(bx + dx, by + dy)
						if m.t(0, v.x, v.y) == T.OUTSIDE and not c.reserved.has(v) and not m.has_cover_at(0, v):
							m.add_cover(Furnish.cover_entry("container", 0, v, -1, bx * 1000 + by))
	SceneGen.props(c, Rect2i(q5 + 1, quay_y + 3, m.w - q5 - 2, 4), "scaffold", 3)
	SceneGen.props(c, Rect2i(q4, quay_y + 1, q5 - q4, 5), "fuel_barrel", 2)
	# Outdoor rooms: the quays, Quay 5's construction site, the container yard, the floats (their
	# barrels and crates come with the float room's furniture).
	var quay := SceneGen.yard(c, Rect2i(0, quay_y, q2, 7), "quay", TacMap.Zone.STAFF, sid)
	SceneGen.yard(c, Rect2i(q2, quay_y, q4 - q2, 7), "quay", TacMap.Zone.STAFF, sid)
	SceneGen.yard(c, Rect2i(q4, quay_y, q5 - q4, 7), "quay", TacMap.Zone.STAFF, sid)
	SceneGen.yard(c, Rect2i(q5, quay_y, m.w - q5, 8), "construction_site", TacMap.Zone.STAFF, sid)
	SceneGen.yard(c, Rect2i(1, quay_y + 7, m.w - 2, road_y - quay_y - 8), "container_yard", TacMap.Zone.STAFF, sid)
	SceneGen.yard(c, Rect2i(0, 0, m.w, quay_y), "float", TacMap.Zone.STAFF, fsid)
	SceneGen.fence(c, Rect2i(-1, quay_y - 1, m.w + 2, road_y - quay_y + 1), [gate], quay, 3)
	m.doors[-1].b = m.label(0, gate.x, gate.y - 1)
	for s in [sid, fsid]:
		Furnish.run_structure(m, c.dice, s)
		if m.devices.any(func(d): return d.structure == s):
			m.architectures[s] = NetGen.generate(m, c.dice, s)
	SceneGen.spawn(c, Vector2i(0, m.h - 3))
	SceneGen.spawn(c, Vector2i(m.w - 1, m.h - 3))


## A hull: the shell with its bow (E, W or both ends) tapered to a point over `k` squares.
static func hull(shell: Rect2i, bow: String, k: int) -> Dictionary:
	var mask := {}
	var mid := shell.position.y + (shell.size.y - 1) / 2.0
	var half := shell.size.y / 2.0
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			var from_e := shell.end.x - 1 - x
			var from_w := x - shell.position.x
			var d := k
			if bow in ["E", "both"]:
				d = mini(d, from_e)
			if bow in ["W", "both"]:
				d = mini(d, from_w)
			var keep := half if d >= k else maxf(1.5, half * (d + 1) / float(k + 1))
			if absf(y - mid) <= keep:
				mask[Vector2i(x, y)] = true
	return mask


# --- Props and posts ---------------------------------------------------------------------------

## A part's structure, or {} if this map has none.
static func _structure(m: TacMap, part: String) -> Dictionary:
	for st in m.structures:
		if String(st.get("part", "")) == part:
			return st
	return {}


## Rooms for `where` of a part: roof (its roofs), top (the highest roof only), deck (its terraces,
## else its roof), room:<kind>. Part `_scene`: the scene's outdoor rooms of that kind.
static func _where(m: TacMap, part: String, where: String) -> Array:
	var want := "roof"
	if where.begins_with("room:"):
		want = where.trim_prefix("room:")
	if part == "_scene":
		return m.rooms.filter(func(r): return r.cells > 0 and r.get("outdoor", false) and String(r.kind) == want)
	var st := _structure(m, part)
	if st.is_empty():
		return []
	var out := []
	if where == "deck":
		want = "terrace" if m.rooms.any(func(r): return r.cells > 0 and r.get("structure", -1) == st.id and r.kind == "terrace") else "roof"
	for r in m.rooms:
		if r.cells > 0 and r.get("structure", -1) == st.id and String(r.kind) == want:
			out.append(r)
	if where in ["top", "deck"] and not out.is_empty():   # the highest roof; the main (lowest) deck
		var lvl: int = out.map(func(r): return int(r.floor)).max() if where == "top" else out.map(func(r): return int(r.floor)).min()
		out = out.filter(func(r): return int(r.floor) == lvl)
	return out


## The recipe's props: `count` pieces in the rooms `where` names, spread out (at least 5 squares
## apart), or as near as they fit to the rooms' middle (`at: center`) or the part's main door
## (`at: door`: a school's cupola over its entrance).
static func _props(c: Dictionary) -> void:
	var m: TacMap = c.m
	for spec in _sp(c).get("props", []):
		var n := _roll(c.dice, spec.get("count", 1))
		var rooms := _where(m, String(spec.part), String(spec.where))
		if rooms.is_empty():
			continue
		var cells: Array = []
		var box := Rect2i()
		for r in rooms:
			for v in Furnish.room_cells(m, r):
				cells.append([r, v])
				box = Rect2i(v, Vector2i.ONE) if box.size == Vector2i.ZERO else box.expand(v).expand(v + Vector2i.ONE)
		Layouts._shuffle(c.dice, cells)
		var sz := piece_size(String(spec.piece))
		var at := String(spec.get("at", ""))
		if at in ["center", "door"]:
			var goal := Vector2(box.get_center())
			if at == "door":
				var st := _structure(m, String(spec.part))
				for e in m.entrances:
					if e.get("structure", -1) == st.get("id", -2) and e.main:
						goal = Vector2(e.pos)
			var half := Vector2(sz[0], sz[1]) / 2.0
			cells.sort_custom(func(p, q): return (Vector2(p[1]) + half).distance_squared_to(goal) < (Vector2(q[1]) + half).distance_squared_to(goal))
		var placed: Array[Vector2i] = []
		for cv in cells:
			if placed.size() >= n:
				break
			var v: Vector2i = cv[1]
			if placed.any(func(q): return q.distance_to(v) < 5.0):
				continue
			var r: Dictionary = cv[0]
			if try_piece(m, int(r.floor), Rect2i(v, Vector2i(sz[0], sz[1])), String(spec.piece), int(r.id), {}, c.reserved):
				placed.append(v)


## The recipe's posts, after the scene's own (SceneGen._guard_posts): each a guard position the
## guards fill first (`priority`), maybe with a weapon to hand and sandbags in front.
static func posts(c: Dictionary) -> void:
	var m: TacMap = c.m
	var dice: Dice = c.dice
	for spec in _sp(c).get("posts", []):
		var n := _roll(dice, spec.get("count", 1))
		var rooms := _where(m, String(spec.part), String(spec.where))
		var picks := []   # [room, cell, facing-out direction]
		var where := String(spec.where)
		for r in rooms:
			var f := int(r.floor)
			var cand: Array = []
			for v in Furnish.room_cells(m, r):
				if not m.walkable(f, v) or m.has_cover_at(f, v) or m.is_connector_end(f, v) or m.t(f, v.x, v.y) == T.STAIRS:
					continue
				if where == "roof":   # a nest one square in from the parapet, facing out
					for d in MapGen.DIRS:
						var edge: Vector2i = v + d
						var past: Vector2i = v + d * 2
						if m.label(f, edge.x, edge.y) == r.id and m.label(f, past.x, past.y) != r.id and m.t(f, past.x, past.y) != T.ROOF \
								and m.t(f, edge.x, edge.y) == T.ROOF and not m.has_cover_at(f, edge) and not m.is_connector_end(f, edge):
							cand.append([r, v, d])
							break
				elif where == "deck":   # beside a gun mount
					for d in MapGen.DIRS + BuildingGen.DIAG:
						var gun: Vector2i = v + d
						if String(m.cover_at(f, gun).get("kind", "")) == "aa_gun":
							cand.append([r, v, Vector2i.ZERO])
							break
				else:
					cand.append([r, v, Vector2i.ZERO])
			if where.begins_with("room:") and not spec.get("spread", false):   # the middle of the room (`spread`: anywhere in it)
				var mid: Vector2 = Vector2((r.bounds as Rect2i).get_center())
				cand.sort_custom(func(a, b): return Vector2(a[1]).distance_squared_to(mid) < Vector2(b[1]).distance_squared_to(mid))
				cand = cand.slice(0, 1)
			else:
				Layouts._shuffle(dice, cand)
			picks.append_array(cand)
		var chosen := []
		for pk in picks:
			if chosen.size() >= n:
				break
			if chosen.any(func(q): return q[0].floor == pk[0].floor and Vector2(q[1]).distance_to(Vector2(pk[1])) < 6.0):
				continue
			chosen.append(pk)
		for pk in chosen:
			var r: Dictionary = pk[0]
			var v: Vector2i = pk[1]
			var f := int(r.floor)
			m.posts = m.posts.filter(func(q): return not (int(q.floor) == f and q.pos == v))
			var post := {"floor": f, "pos": v, "structure": r.structure, "zone": r.zone, "kind": String(spec.kind), "priority": true}
			if spec.has("weapon"):
				post["weapon"] = String(spec.weapon)
			if pk[2] != Vector2i.ZERO:
				post["facing"] = pk[2]
				if spec.has("cover"):   # on the parapet square in front: nothing walks the edge anyway
					var e: Vector2i = v + pk[2]
					if not m.has_cover_at(f, e):
						m.add_cover(Furnish.cover_entry(String(spec.cover), f, e, int(r.id)))
			m.posts.append(post)
