class_name TowerDress
extends RefCounted
## A tower band's exterior (docs/plans/towers.md, stage 1a sky band; towers art pass): the band's
## own outer walls in the tower's look (TowerLook), the impostor facade that carries them down into
## the smog, the crown, the greebles that give the drop its scale, and the far city with its
## holograms and traffic. None of it is in the TacMap; the play area is never touched: nothing this
## builds stands over the floor plate above the band's lowest floor (plan() is checked for it).
##
## - The facade: the band's lowest storey repeated storey by storey (tower.gdshader style 0 reads
##   a mask of what each square of its outer wall holds), its rooms lit or dark per storey, slab
##   edges and panel joints where the band's walls have them: one building, no seam (owner, V1).
## - Setbacks step the silhouette out below the band (Ziggurat: five gold-lit tiers), with plant on
##   the terraces; louvred plant storeys with a catwalk round them break the shaft.
## - The crown stands off the plate's back edges (fins, a logo sign, stepped tiers, a lit ring),
##   with a mast and dishes on the back corner and aviation lights blinking on every corner.
## - Below: a window-cleaning cradle on its cables, pipe runs, holo-ad screens, a hotel's blade
##   sign and AV pad, sky-bridge stubs, and MA&F's twin tower with its walkways.
## - The city: varied towers (facade styles, crowns, accents, rooftop ads), a few huge holograms in
##   the smog, drones crossing, the street grid far below and the smog layers lit from beneath.
## Everything is batched into a few MultiMeshes (one per shape and material) and placed from a
## RandomNumberGenerator seeded by the map's seed and the tower, so a tower looks the same every time.

const FH := 1.6                 ## WorldBuilder.FH (a storey)
const WALL_GAP := 0.012         ## WorldBuilder.WALL_GAP
const FACE_IN := 0.21           ## the facade's face, in from the plate's edge: the band's skin, just clear of its walls' cornices
const SKIN_T := 0.02            ## the skin's thickness
const PIER := 0.62              ## the corner piers, inside the corner squares
const SKY_DROP := 64.0          ## how far the drawn city lies below the band (past the smog nothing more shows)
const TOWER_SHADER := preload("res://src/tactical/view/tower.gdshader")
const FX_SHADER := preload("res://src/tactical/view/sky_fx.gdshader")
const HOLO_SHADER := preload("res://src/tactical/view/holo.gdshader")
const GROUND_SHADER := preload("res://src/tactical/view/city_ground.gdshader")
const SMOG_SHADER := preload("res://src/tactical/view/smog.gdshader")
## What stands above the roof: drawn only while the roof is (sky_fx crown_floor): with the band
## cut at a lower storey it would hang over nothing (owner, V1: no outlines of the cut storeys).
const CROWN := ["fin", "logo", "step", "mast", "dish", "beacon"]
const RED := Color("ff3b4f")
const AMBER := Color("ffb070")

var m: TacMap
var wb: WorldBuilder            ## null: plan() only (tests)
var lk: Dictionary
var rect: Rect2i                ## the floor plate (the tower's structure)
var face: Rect2                 ## the facade's outer planes
var drop: float
var floor_y: float              ## the far city's ground
var storey0: int                ## the storey of the band's lowest floor (floor 0)
var rf := -1                    ## the band's roof floor
var seed_v: int
var punched := false            ## a hotel's punched windows
var daylight := false
var smog := Color("2a2238")
var _plan: Array = []
var _bt := {}                   ## batches: key → {shape, mat, xf, col, cus}
var _mats := {}
var _mask: ImageTexture
var _shapes := {}


func _init(p_m: TacMap, p_wb: WorldBuilder = null) -> void:
	m = p_m
	wb = p_wb
	lk = TowerLook.of(m)
	rect = Rect2i(0, 0, m.w, m.h)
	for st in m.structures:
		if st.get("target", false) and st.has("rect"):
			rect = st.rect
			punched = bool(st.get("punched_windows", false))
	face = Rect2(rect.position.x + FACE_IN, rect.position.y + FACE_IN, rect.size.x - FACE_IN * 2, rect.size.y - FACE_IN * 2)
	drop = minf(maxf(m.storey_base * FH, 12.0), SKY_DROP)
	floor_y = -drop - 4.0
	storey0 = m.storey(0)
	rf = int(m.bands[0].get("roof_floor", -1)) if not m.bands.is_empty() else -1
	seed_v = m.seed_value
	if wb != null:
		daylight = wb.daylight
		smog = wb.smog


func _seed() -> float:
	return float(posmod(seed_v, 997))


## The face of a wall run on the plate's edge: 0 -z, 1 +z, 2 -x, 3 +x; -1 not on it.
func face_of(horiz: bool, a: int) -> int:
	if horiz:
		return 0 if a == rect.position.y else (1 if a == rect.end.y - 1 else -1)
	return 2 if a == rect.position.x else (3 if a == rect.end.x - 1 else -1)


## The square inside the wall square (x, y) on face `fc` (the room the window lights).
func _inner(fc: int, x: int, y: int) -> Vector2i:
	return Vector2i(x, y) + [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)][fc]


## The room behind wall square (x, y) of face fc on floor f, as the facade's lighting counts it
## (the same number the mask gives the impostor for the lowest storey).
func room_key(f: int, fc: int, x: int, y: int) -> int:
	var c := _inner(fc, x, y)
	var l := m.label(f, c.x, c.y) if m.inb(c.x, c.y) else -1
	var r := posmod(l * 37 + 11, 251) + 1 if l >= 0 else posmod((x + y) * 13, 251) + 1
	return r + fc * 301


# --- The band's own outer walls ---------------------------------------------------------------

func _c(key: String) -> Color:
	return TowerLook.col(lk, key)


## A colour of this tower's look (WorldBuilder: the band's glass and frames).
func lk_col(key: String) -> Color:
	return TowerLook.col(lk, key)


## The facade's skin material (the impostor's colours in the band walls' own panel pattern,
## world.gdshader 7), and its slab-edge trim. Only the outside of the band's outer walls wears it:
## inside, every wall is as it was (the play area's look and light are not the tower's).
func wall_over() -> Dictionary:
	var sp := _c("spandrel")
	var o := {"shell": true, "color": sp, "color2": sp * 0.58, "pattern": 7, "scale": 1.0}
	if float(lk.get("flood", 0.0)) > 0.0:   # floodlit: the facade's own colour, lit up
		o["glow"] = float(lk.flood)
		o["emit"] = flood_color(sp)
	return o


## A floodlit facade's light: its own colour, brightened (a dark teal wall glows teal, not black).
static func flood_color(sp: Color) -> Color:
	var k := 0.75 / maxf(maxf(sp.r, maxf(sp.g, sp.b)), 0.05)
	return Color(minf(sp.r * k, 1.0), minf(sp.g * k, 1.0), minf(sp.b * k, 1.0))


func trim_over() -> Dictionary:
	return {"shell": true, "color": _c("slab"), "color2": _c("slab")}


## A thin slab of skin on the outer face of a band wall on face fc: along [s, e] (world, along the
## face), from height ya to yb of storey f, `out` further off the face (trim stands proud of it).
func _skin(f: int, fc: int, s: float, e: float, ya: float, yb: float, mt: Material, out := 0.0, thick := SKIN_T) -> void:
	var d := FACE_IN + SKIN_T - thick / 2 - out   # the slab's centre, in from the plate's edge
	var y0 := f * FH
	var mid := (s + e) / 2
	var c: Vector3
	match fc:
		0: c = Vector3(mid, 0, rect.position.y + d)
		1: c = Vector3(mid, 0, rect.end.y - d)
		2: c = Vector3(rect.position.x + d, 0, mid)
		_: c = Vector3(rect.end.x - d, 0, mid)
	var along_x := fc < 2
	wb.box(mt, c + Vector3(0, y0 + (ya + yb) / 2, 0), Vector3(e - s, yb - ya, thick) if along_x else Vector3(thick, yb - ya, e - s))


## The skin on a solid stretch of the band's outer wall (WorldBuilder._run): spandrel panels, the
## slab edge at its foot and a cornice at its head, as the impostor draws them storey by storey.
func wall_skin(f: int, horiz: bool, a: int, s: float, e: float) -> void:
	var fc := face_of(horiz, a)
	if wb == null or fc < 0:
		return
	var top := FH - WALL_GAP
	_skin(f, fc, s, e, 0.0, top, wb.mat("wall_concrete", f, true, wall_over()))
	var tr := wb.mat("skirt", f, true, trim_over())
	_skin(f, fc, s, e, 0.0, 0.12, tr, 0.004, 0.012)
	_skin(f, fc, s, e, top - 0.08, top, tr, 0.004, 0.012)


## A glass run of the band's outer wall (WorldBuilder._run hands it over): the run as it always was
## inside (sill, glass, lintel, frame), mullions on the facade's grid, rooms lit or dark as the
## impostor lights them, and outside the facade's skin over the sill and the lintel, mullion caps
## and the slab edge. False when the run is not on the plate's edge.
func glass_run(f: int, horiz: bool, a: int, s: float, e: float, t: float, c: Vector3) -> bool:
	var fc := face_of(horiz, a)
	if wb == null or fc < 0:
		return false
	var y0 := f * FH
	var length := e - s
	var size := func(h: float, thick: float) -> Vector3:
		return Vector3(length, h, thick) if horiz else Vector3(thick, h, length)
	var top := FH - WALL_GAP
	var sill := TowerLook.SILL
	var lintel := TowerLook.LINTEL
	var wm := wb.mat("wall_concrete", f, true, {"shell": true})
	wb.box(wm, c + Vector3(0, y0 + sill / 2, 0), size.call(sill, t))
	wb.box(wm, c + Vector3(0, y0 + (lintel + top) / 2, 0), size.call(top - lintel, t))
	wb.box(wb.mat("glass", f, true, {"shell": true}), c + Vector3(0, y0 + (sill + lintel) / 2, 0), size.call(lintel - sill, 0.05))
	wb.box(wb.mat("frame", f, true, {"shell": true}), c + Vector3(0, y0 + sill + 0.02, 0), size.call(0.04, t + 0.06))
	# outside: the skin over sill and lintel, the slab edge, the frame under the glass
	var sk := wb.mat("wall_concrete", f, true, wall_over())
	_skin(f, fc, s, e, 0.0, sill, sk)
	_skin(f, fc, s, e, lintel, top, sk)
	var tr := wb.mat("skirt", f, true, trim_over())
	_skin(f, fc, s, e, 0.0, 0.12, tr, 0.004, 0.012)
	var fr := wb.mat("frame", f, true, {"shell": true, "color": _c("mullion")})
	_skin(f, fc, s, e, sill, sill + 0.04, fr, 0.0, 0.03)
	# mullions on the facade's grid, through the wall and capped on the skin's face
	var step := float(lk.get("mullion_step", 0.5))
	var mw := maxf(float(lk.get("mullion_w", 0.05)), 0.04)
	var cuts: Array[float] = [s]
	var k := ceili((s + 0.02) / step)
	while k * step < e - 0.02:
		var p := k * step
		cuts.append(p)
		var mc := Vector3(p, 0, a + 0.5) if horiz else Vector3(a + 0.5, 0, p)
		wb.box(wb.mat("frame", f), mc + Vector3(0, y0 + (sill + lintel) / 2, 0), Vector3(0.04, lintel - sill, 0.08) if horiz else Vector3(0.08, lintel - sill, 0.04))
		_skin(f, fc, p - mw / 2, p + mw / 2, sill, lintel, fr, 0.0, 0.05)
		k += 1
	cuts.append(e)
	# rooms lit from inside, pane by pane
	var norm := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][fc] as Vector3
	var storey := m.storey(f)
	for i in cuts.size() - 1:
		var pc := (cuts[i] + cuts[i + 1]) / 2.0
		var pw := cuts[i + 1] - cuts[i] - mw
		if pw <= 0.05:
			continue
		var cell := Vector2i(int(pc), a) if horiz else Vector2i(a, int(pc))
		var room := room_key(f, fc, cell.x, cell.y)
		if not TowerLook.room_lit(lk, storey, room, int(_seed())):
			continue
		var wcol := TowerLook.room_color(lk, storey, room, int(_seed()))
		var pcv := (Vector3(pc, 0, a + 0.5) if horiz else Vector3(a + 0.5, 0, pc)) + norm * 0.05
		wb.box(wb.mat("dark", f, true, {"glow": 1.1, "emit": wcol, "shell": true}), pcv + Vector3(0, y0 + (sill + lintel) / 2, 0),
			Vector3(pw, lintel - sill - 0.04, 0.02) if horiz else Vector3(0.02, lintel - sill - 0.04, pw))
	return true


## The skin round a punched window of the band's outer wall (a hotel's; WorldBuilder._punched_window):
## jambs, sill and head in the facade's look, the slab edge and cornice across the square.
func punched_skin(f: int, horiz: bool, a: int, b: int) -> void:
	var fc := face_of(horiz, a)
	if wb == null or fc < 0:
		return
	var top := FH - WALL_GAP
	var pw := TowerLook.PUNCH_W
	var c := b + 0.5
	var sk := wb.mat("wall_concrete", f, true, wall_over())
	_skin(f, fc, b, c - pw / 2, 0.0, top, sk)
	_skin(f, fc, c + pw / 2, b + 1.0, 0.0, top, sk)
	_skin(f, fc, c - pw / 2, c + pw / 2, 0.0, TowerLook.PUNCH_SILL, sk)
	_skin(f, fc, c - pw / 2, c + pw / 2, TowerLook.PUNCH_LINTEL, top, sk)
	var tr := wb.mat("skirt", f, true, trim_over())
	_skin(f, fc, b, b + 1.0, 0.0, 0.12, tr, 0.004, 0.012)
	_skin(f, fc, b, b + 1.0, top - 0.08, top, tr, 0.004, 0.012)
	_skin(f, fc, c - pw / 2 - 0.04, c + pw / 2 + 0.04, TowerLook.PUNCH_SILL, TowerLook.PUNCH_SILL + 0.05, wb.mat("frame", f, true, {"shell": true, "color": _c("mullion")}), 0.0, 0.04)


## A punched window's light (WorldBuilder._punched_window on the tower's edge): the room's colour,
## or transparent when the room is dark.
func punched_light(f: int, horiz: bool, a: int, b: int) -> Color:
	var fc := face_of(horiz, a)
	var cell := Vector2i(b, a) if horiz else Vector2i(a, b)
	var room := room_key(f, fc, cell.x, cell.y)
	if not TowerLook.room_lit(lk, m.storey(f), room, int(_seed())):
		return Color(0, 0, 0, 0)
	return TowerLook.room_color(lk, m.storey(f), room, int(_seed()))


## The band's storey f outside its walls: the corner piers, the light seams, the roof's parapet
## (WorldBuilder.build, once per floor; cut with the storey like its walls).
func band_floor(f: int) -> void:
	if wb == null or m.band_of(f).is_empty():
		return
	var y0 := f * FH
	var roof := f == rf
	var h := 0.46 if roof else FH - WALL_GAP
	var pm := wb.mat("wall_concrete", f, true, {"shell": true, "color": _c("pier"), "color2": _c("pier") * 0.58})
	for cx in [rect.position.x + PIER / 2 + 0.12, rect.end.x - PIER / 2 - 0.12]:
		for cz in [rect.position.y + PIER / 2 + 0.12, rect.end.y - PIER / 2 - 0.12]:
			wb.box(pm, Vector3(cx, y0 + h / 2, cz), Vector3(PIER, h, PIER))
	if TowerLook.has(lk, "seam"):
		var sm := wb.mat("dark", f, true, {"glow": float(lk.get("seam_glow", 1.0)), "emit": _c("seam"), "shell": true})
		for s in _seam_lines(face, h):
			var a: Vector3 = s[0]
			wb.box(sm, a + Vector3(0, y0, 0), s[1])
	if roof:
		_parapet(f)


## Seam strips round a facade rect: [[centre (y = half height), size]].
func _seam_lines(r: Rect2, h: float) -> Array:
	var out := []
	for x in TowerLook.seams(lk, rect.position.x, r.position.x, r.end.x):
		out.append([Vector3(x, h / 2, r.position.y - 0.015), Vector3(0.07, h, 0.04)])
		out.append([Vector3(x, h / 2, r.end.y + 0.015), Vector3(0.07, h, 0.04)])
	for z in TowerLook.seams(lk, rect.position.y, r.position.y, r.end.y):
		out.append([Vector3(r.position.x - 0.015, h / 2, z), Vector3(0.04, h, 0.07)])
		out.append([Vector3(r.end.x + 0.015, h / 2, z), Vector3(0.04, h, 0.07)])
	return out


## A knee-high parapet round the band's roof (as it was on the roof side), the facade's skin outside it,
## a slab-edge cap and, when the look has one, a lit trim along its outer face.
func _parapet(f: int) -> void:
	var py := f * FH
	var par := wb.mat("wall_concrete", f, true, {"shell": true})
	var cap := wb.mat("skirt", f, true, trim_over())
	var x0 := face.position.x + SKIN_T + 0.12
	var x1 := face.end.x - SKIN_T - 0.12
	var z0 := face.position.y + SKIN_T + 0.12
	var z1 := face.end.y - SKIN_T - 0.12
	var mid := face.get_center()
	var inner := face.grow(-SKIN_T)
	for e in [[Vector3(mid.x, 0, z0), Vector3(inner.size.x, 0, 0.24)], [Vector3(mid.x, 0, z1), Vector3(inner.size.x, 0, 0.24)],
			[Vector3(x0, 0, mid.y), Vector3(0.24, 0, inner.size.y)], [Vector3(x1, 0, mid.y), Vector3(0.24, 0, inner.size.y)]]:
		var c: Vector3 = e[0]
		var sz: Vector3 = e[1]
		wb.box(par, c + Vector3(0, py + 0.2, 0), Vector3(sz.x, 0.4, sz.z))
		wb.box(cap, c + Vector3(0, py + 0.42, 0), Vector3(sz.x + 0.04, 0.05, sz.z + 0.04))
	var sk := wb.mat("wall_concrete", f, true, wall_over())
	for fc in 4:   # the facade's skin on the parapet's outside
		_skin(f, fc, face.position.x if fc < 2 else face.position.y, face.end.x if fc < 2 else face.end.y, 0.0, 0.4, sk)
	var trim := _c("trim") if TowerLook.has(lk, "trim") else (_c("crown_color") if String(lk.get("crown", "")) == "ring" else Color.BLACK)
	if trim != Color.BLACK:   # a lit edge (a ring crown is this, cut with the roof like the parapet)
		var tm := wb.mat("dark", f, true, {"glow": 1.0, "emit": trim, "shell": true})
		wb.box(tm, Vector3(mid.x, py + 0.32, face.position.y - 0.01), Vector3(face.size.x, 0.05, 0.02))
		wb.box(tm, Vector3(mid.x, py + 0.32, face.end.y + 0.01), Vector3(face.size.x, 0.05, 0.02))
		wb.box(tm, Vector3(face.position.x - 0.01, py + 0.32, mid.y), Vector3(0.02, 0.05, face.size.y))
		wb.box(tm, Vector3(face.end.x + 0.01, py + 0.32, mid.y), Vector3(0.02, 0.05, face.size.y))


# --- The plan: where everything outside the band goes (pure data) -----------------------------

## Every piece of dressing outside the band: {kind, at (centre), size (its box)} plus what the
## kind needs. Deterministic per map seed and tower; nothing stands over the plate above y 0.
func plan() -> Array:
	if not _plan.is_empty():
		return _plan
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(seed_v, String(lk.get("id", "")).hash(), 7))
	_plan_tiers(rng)
	_plan_crown(rng)
	_plan_greebles(rng)
	_plan_far(rng)
	return _plan


func _add(kind: String, at: Vector3, size: Vector3, extra := {}) -> Dictionary:
	var d := {"kind": kind, "at": at, "size": size, "crown": kind in CROWN}
	d.merge(extra)
	_plan.append(d)
	return d


## The facade's tiers: [rect, top y, bottom y], the band's own first.
func tiers() -> Array:
	var out := []
	var ts := TowerLook.tiers(lk, FH)
	for i in ts.size():
		var top: float = ts[i][0]
		if top <= floor_y + 2.0:
			break
		var bottom: float = ts[i + 1][0] if i + 1 < ts.size() else floor_y
		out.append([face.grow(float(ts[i][1])), top, maxf(bottom, floor_y)])
	return out


func _plan_tiers(rng: RandomNumberGenerator) -> void:
	var ts := tiers()
	for i in range(1, ts.size()):
		var r: Rect2 = ts[i][0]
		var inner: Rect2 = ts[i - 1][0]
		var y: float = ts[i][1]
		_add("ledge", Vector3(r.get_center().x, y, r.get_center().y), Vector3(r.size.x, 0.1, r.size.y), {"rect": r})
		if not "hvac" in lk.get("greebles", []):
			continue
		var ring := (r.size.x - inner.size.x) / 2.0
		if ring < 0.9:
			continue
		for k in rng.randi_range(4, 9):   # plant on the terrace: AC units, a cooling tower or two
			var side := rng.randi() % 4
			var t := rng.randf_range(0.1, 0.9)
			var off := ring / 2.0
			var p := Vector2.ZERO
			match side:
				0: p = Vector2(lerpf(r.position.x, r.end.x, t), r.position.y + off)
				1: p = Vector2(lerpf(r.position.x, r.end.x, t), r.end.y - off)
				2: p = Vector2(r.position.x + off, lerpf(r.position.y, r.end.y, t))
				3: p = Vector2(r.end.x - off, lerpf(r.position.y, r.end.y, t))
			var cool := rng.randf() < 0.3
			var s := minf(ring * 0.7, rng.randf_range(0.6, 1.4))
			_add("cooler" if cool else "hvac", Vector3(p.x, y + s * 0.4, p.y), Vector3(s, s * 0.8, s * (1.0 if cool else rng.randf_range(0.7, 1.6))))


## Mechanical storeys under the band (the shader louvres them): a catwalk round each.
func mech_storeys() -> Array[int]:
	var out: Array[int] = []
	var every := int(lk.get("mech_every", 0))
	if every <= 0:
		return out
	var sd := int(_seed())
	for st in range(storey0 - 1, storey0 - int(drop / FH) - 1, -1):
		if posmod(st + sd, every) == 0:
			out.append(st)
	return out


func _tier_at(y: float) -> Rect2:
	for t in tiers():
		if y <= float(t[1]) + 0.01 and y >= float(t[2]) - 0.01:
			return t[0]
	return face


func _plan_crown(rng: RandomNumberGenerator) -> void:
	var ry := (rf if rf >= 0 else m.floors) * FH   # the roof's floor
	var top := ry + 0.46
	var col := TowerLook.col(lk, "crown_color", TowerLook.col(lk, "seam", Color("aaf6ff")))
	# back edges: -z (along x) and -x (along z), just off the plate
	var bz := rect.position.y - 0.45
	var bx := rect.position.x - 0.45
	match String(lk.get("crown", "mast")):
		"fins":
			for along_x in [true, false]:
				var lo := (face.position.x if along_x else face.position.y) + 1.0
				var hi := (face.end.x if along_x else face.end.y) - 1.0
				var n := int((hi - lo) / 1.5)
				for i in n + 1:
					var t := float(i) / maxf(n, 1)
					var p := lerpf(lo, hi, t)
					var hgt := 1.4 + 2.4 * sin(PI * t) + rng.randf_range(0.0, 0.3)
					var y1 := top + hgt
					var y0 := ry - FH
					var at := Vector3(p, (y0 + y1) / 2, bz) if along_x else Vector3(bx, (y0 + y1) / 2, p)
					_add("fin", at, Vector3(0.16, y1 - y0, 0.7) if along_x else Vector3(0.7, y1 - y0, 0.16), {"color": col, "along_x": along_x})
		"logo":
			var text := String(lk.get("logo", "")).to_upper()
			for along_x in [true, false]:
				var span := (face.size.x if along_x else face.size.y) - 2.0
				var cols := text.length() * 6 - 1
				var px := minf(0.42, span / maxf(cols, 1))
				var w := cols * px
				var hgt := 7 * px
				var c := face.get_center()
				var at := Vector3(c.x, top + 0.5 + hgt / 2, bz - 0.1) if along_x else Vector3(bx - 0.1, top + 0.5 + hgt / 2, c.y)
				_add("logo", at, Vector3(w + 0.6, hgt + 0.6, 0.2) if along_x else Vector3(0.2, hgt + 0.6, w + 0.6),
					{"text": text, "px": px, "color": TowerLook.col(lk, "logo_color", Color.WHITE), "along_x": along_x})
		"tiers":
			for along_x in [true, false]:
				var span := (face.size.x if along_x else face.size.y)
				var c := face.get_center()
				for k in 3:
					var len := span * (0.8 - k * 0.24)
					var y := top + 0.45 + k * 0.9
					var at := Vector3(c.x, y, bz - 0.15) if along_x else Vector3(bx - 0.15, y, c.y)
					_add("step", at, Vector3(len, 0.9, 0.6) if along_x else Vector3(0.6, 0.9, len), {"color": col, "along_x": along_x})
		"ring":   # the parapet's lit edge (_parapet) and lit bands round the shaft under the band
			for k in [1, 3]:
				var y: float = -k * FH * 2.0 + 1.45
				var gl: float = 1.2 if k == 1 else 0.8
				var c := face.get_center()
				_add("ring", Vector3(c.x, y, face.position.y - 0.05), Vector3(face.size.x + 0.1, 0.08, 0.04), {"color": col, "glow": gl})
				_add("ring", Vector3(c.x, y, face.end.y + 0.05), Vector3(face.size.x + 0.1, 0.08, 0.04), {"color": col, "glow": gl})
				_add("ring", Vector3(face.position.x - 0.05, y, c.y), Vector3(0.04, 0.08, face.size.y + 0.1), {"color": col, "glow": gl})
				_add("ring", Vector3(face.end.x + 0.05, y, c.y), Vector3(0.04, 0.08, face.size.y + 0.1), {"color": col, "glow": gl})
	# the mast on the back corner, dishes on it; aviation lights on every corner
	var mh := rng.randf_range(8.0, 12.0)
	var mb := Vector3(rect.position.x - 0.9, ry - FH, rect.position.y - 0.9)
	_add("mast", mb + Vector3(0, mh / 2, 0), Vector3(0.7, mh, 0.7), {"base": mb, "height": mh})
	for k in rng.randi_range(2, 3):
		var dy := rng.randf_range(1.5, mh * 0.55)
		var yaw := rng.randf_range(PI * 0.9, PI * 1.6)   # facing out, away from the plate
		var r := rng.randf_range(0.45, 0.8)
		var at := mb + Vector3(cos(yaw), 0, sin(yaw)) * 0.75 + Vector3(0, dy, 0)
		_add("dish", at, Vector3(r * 2, r * 2, r * 2), {"yaw": yaw, "r": r})
	for cx in [rect.position.x - 0.2, rect.end.x + 0.2]:
		for cz in [rect.position.y - 0.2, rect.end.y + 0.2]:
			_add("beacon", Vector3(cx, top + 0.15, cz), Vector3(0.18, 0.18, 0.18), {"phase": rng.randf()})


func _plan_greebles(rng: RandomNumberGenerator) -> void:
	var g: Array = lk.get("greebles", [])
	var t0: Rect2 = tiers()[0][0]
	var t0_bottom: float = tiers()[0][2]
	# catwalks round the plant storeys
	if "gantry" in g:
		for st in mech_storeys():
			var y := (st - storey0) * FH
			if y < floor_y + 4.0:
				continue
			var r := _tier_at(y + 0.5)
			_add("gantry", Vector3(r.get_center().x, y, r.get_center().y), Vector3(r.size.x + 1.2, 1.0, r.size.y + 1.2), {"rect": r})
	# a window-cleaning cradle on a camera-side face, on its cables
	if "cradle" in g:
		var fx := rng.randf() < 0.5
		var y := -rng.randi_range(2, clampi(int(-t0_bottom / FH) - 1, 2, 7)) * FH + 0.35   # on the band's own shaft
		if y > t0_bottom:
			var along := rng.randf_range(0.2, 0.75)
			var at := Vector3(t0.end.x + 0.32, y, lerpf(t0.position.y, t0.end.y, along)) if fx else Vector3(lerpf(t0.position.x, t0.end.x, along), y, t0.end.y + 0.32)
			_add("cradle", at, Vector3(0.55, 0.6, 2.4) if fx else Vector3(2.4, 0.6, 0.55), {"along_x": not fx})
	# pipe runs down the right-hand face near its back corner
	if "pipes" in g:
		var z := t0.position.y + rng.randf_range(1.2, 2.4)
		for k in rng.randi_range(2, 3):
			var r := rng.randf_range(0.09, 0.17)
			var at := Vector3(t0.end.x + r + 0.05, (t0_bottom - 0.3) / 2.0, z + k * 0.42)
			_add("pipe", at, Vector3(r * 2, -0.3 - t0_bottom, r * 2), {"r": r})
	# a sky-bridge stub off the back-left face, toward a neighbour in the smog
	if "stub" in g:
		var y := -rng.randi_range(5, 10) * FH
		if y > t0_bottom:
			var z := lerpf(t0.position.y, t0.end.y, rng.randf_range(0.3, 0.7))
			var len := rng.randf_range(6.0, 9.0)
			_add("stub", Vector3(t0.position.x - len / 2, y + 0.8, z), Vector3(len, 1.6, 2.6), {"along_x": true})
	# holo-ad screens on the camera-side faces, below the band
	var screens: Array = lk.get("screens", [])
	for i in screens.size():
		var fx := i % 2 == 1
		var span := (t0.size.y if fx else t0.size.x)
		var w := minf(9.0, span * 0.45)
		var hgt := w * (0.62 if i % 3 != 2 else 1.4)
		var y := -1.2 - hgt / 2 - (i / 2) * (hgt + 2.0)
		var along := 0.32 + 0.36 * float(i % 2 == 0) * rng.randf()
		var at := Vector3(t0.end.x + 0.18, y, lerpf(t0.position.y + w / 2, t0.end.y - w / 2, along)) if fx else Vector3(lerpf(t0.position.x + w / 2, t0.end.x - w / 2, along), y, t0.end.y + 0.18)
		var kind := 2 if String(lk.get("id", "")) == "n54" else (0 if hgt > w else 3)
		_add("screen", at, Vector3(0.2, hgt, w) if fx else Vector3(w, hgt, 0.2), {"color": Color(String(screens[i])), "holo": kind, "fx": fx, "seed": rng.randi_range(1, 900)})
	# a blade sign on the left-hand corner of the camera-side face
	var blade := String(lk.get("blade", "")).to_upper()
	if blade != "":
		var px := 0.27
		var hgt := blade.length() * 8 * px + 1.2
		var at := Vector3(t0.position.x + 1.6, -1.4 - hgt / 2, t0.end.y + 1.3)
		_add("blade", at, Vector3(0.3, hgt, 2.4), {"text": blade, "px": px, "color": TowerLook.col(lk, "blade_color", Color("ff2a6d")), "edge": TowerLook.col(lk, "blade_edge", AMBER)})
	# an AV landing pad off the right-hand face, a couple of storeys down
	if bool(lk.get("pad", false)):
		var y := -2.0 * FH - 0.2
		var z := lerpf(t0.position.y, t0.end.y, 0.38)
		_add("pad", Vector3(t0.end.x + 3.1, y, z), Vector3(5.6, 0.3, 5.6))
	# a twin tower joined by walkways (MA&F)
	if bool(lk.get("twin", false)):
		var gap := 14.0
		var tr := Rect2(face.position.x, face.position.y - gap - face.size.y, face.size.x, face.size.y)
		var ttop := -0.25   # a storey under the band: its roof never competes with the play area (ours: the book has them equal)
		_add("twin", Vector3(tr.get_center().x, (ttop + floor_y) / 2, tr.get_center().y), Vector3(tr.size.x, ttop - floor_y, tr.size.y), {"rect": tr})
		for st in lk.get("bridges", []):
			var y := (int(st) - storey0) * FH
			if y < floor_y + 4.0 or y > -FH:
				continue
			var x := face.get_center().x + rng.randf_range(-3.0, 3.0)
			_add("bridge", Vector3(x, y + 0.85, face.position.y - gap / 2), Vector3(3.2, 1.7, gap), {"along_x": false})


func _plan_far(rng: RandomNumberGenerator) -> void:
	var mid := face.get_center()
	var placed: Array[Rect2] = [face.grow(4.0)]
	for t in tiers():
		placed.append((t[0] as Rect2).grow(2.0))
	for it in _plan:
		if it.kind in ["twin", "pad", "stub"]:
			placed.append(Rect2(Vector2(it.at.x, it.at.z) - Vector2(it.size.x, it.size.z) / 2, Vector2(it.size.x, it.size.z)).grow(2.0))
	var styles: Array = TowerLook.data().get("far", {}).get("styles", [{}])
	for i in 190:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(maxf(face.size.x, face.size.y) * 0.75, 210.0)
		var w := rng.randf_range(6.0, 17.0)
		var d := rng.randf_range(6.0, 17.0)
		var p := mid + Vector2(cos(ang), sin(ang)) * dist
		var r := Rect2(p - Vector2(w, d) / 2, Vector2(w, d))
		if placed.any(func(q: Rect2) -> bool: return q.grow(1.5).intersects(r)):
			continue
		placed.append(r)
		# the nearer, the lower, so none hides the plate; a few behind the map (-x / -z from the
		# default camera) stand nearly as tall
		var behind := (p.x - mid.x) + (p.y - mid.y) < -40.0
		var top_y := -drop * rng.randf_range(0.12, 0.78)
		if behind and rng.randf() < 0.2:
			top_y = rng.randf_range(-9.0, 4.0)
		var crown: String = ["flat", "flat", "step", "step", "spire", "band", "ad", "ad", "hvac"][rng.randi() % 9]
		var accent := Color.BLACK
		var accents: Array = TowerLook.data().get("far", {}).get("accents", ["ff2a6d"])
		accent = Color(String(accents[rng.randi() % accents.size()]))
		_add("far", Vector3(p.x, (top_y + floor_y) / 2, p.y), Vector3(w, top_y - floor_y, d), {"style": rng.randi() % styles.size(),
			"seed": rng.randi_range(1, 990), "lit": rng.randf_range(0.12, 0.42), "warm": rng.randf(), "accent": accent,
			"seams": rng.randf() < 0.22, "cap": crown, "beacon": rng.randf() < 0.55, "edge": rng.randf() < 0.18,
			"face_ad": rng.randf() < 0.22, "top": top_y})
	# a few huge holograms standing in the smog either side of the tower, as the default camera
	# frames it (its right: +x -z), clear of the far towers, their tops well under the band
	var kinds := [0, 1, 3, 0, 1]
	var hcols: Array = TowerLook.data().get("far", {}).get("accents", ["ff2a6d"])
	var right := Vector2(0.7071, -0.7071)
	var back := Vector2(-0.7071, -0.7071)
	for k in 4:
		var side := 1.0 if k % 2 == 0 else -1.0
		var hw := rng.randf_range(14.0, 22.0)
		var hh := hw * (1.9 if kinds[k] == 0 else rng.randf_range(0.8, 1.1))
		var top := rng.randf_range(-12.0, -5.0)
		for attempt in 16:   # further out each time it lands on a tower
			var p := mid + right * side * (rng.randf_range(28.0, 58.0) + attempt * 6.0) + back * rng.randf_range(-12.0, 30.0)
			var foot := Rect2(p - Vector2(hw, hw) * 0.5, Vector2(hw, hw))
			if placed.any(func(q: Rect2) -> bool: return q.intersects(foot)):
				continue
			placed.append(foot)
			_add("holo", Vector3(p.x, top - hh / 2, p.y), Vector3(hw, hh, 0.1), {"holo": kinds[k], "color": Color(String(hcols[rng.randi() % hcols.size()])),
				"color2": Color(String(hcols[rng.randi() % hcols.size()])), "seed": rng.randi_range(1, 900)})
			break
	# drone traffic lanes under the band
	for k in 70:
		var ang2 := rng.randf() * TAU
		var dir := Vector2(cos(ang2), sin(ang2))
		var c := mid + Vector2(rng.randf_range(-90, 90), rng.randf_range(-90, 90))
		var y := rng.randf_range(-30.0, -3.0)
		var cols := [Color("fff4e0"), RED, Color("39f0a0"), AMBER, Color("aaf6ff")]
		_add("drone", Vector3(c.x, y, c.y), Vector3(0.22, 0.12, 0.22), {"dir": dir, "speed": rng.randf_range(3.0, 9.0), "phase": rng.randf(), "color": cols[rng.randi() % cols.size()]})


# --- Building it ------------------------------------------------------------------------------

## Everything outside the band, into `sky` (WorldBuilder._sky_band).
func build(sky: Node3D) -> void:
	if wb == null:
		return
	_facade()
	for it in plan():
		_crown = bool(it.get("crown", false))
		match String(it.kind):
			"ledge": _ledge(it)
			"hvac", "cooler": _hvac(it)
			"gantry": _gantry(it)
			"fin": _fin(it)
			"logo": _logo(it)
			"step": _step(it)
			"ring": _light(it.at, it.size, it.color, float(it.get("glow", 1.0)))
			"mast": _mast(it)
			"dish": _dish(it)
			"beacon": _light(it.at, it.size, RED, 1.6, it.phase, 0.8, 0.5)
			"cradle": _cradle(it)
			"pipe": _pipe(it)
			"stub": _bridge(it, true)
			"bridge": _bridge(it, false)
			"screen": _screen(it)
			"blade": _blade(it)
			"pad": _pad(it)
			"twin": _twin(it)
			"far": _far(it)
			"holo": _holo_big(it)
			"drone": _drone(it)
	_crown = false
	_ground()
	_smog()
	flush(sky)


var _crown := false   ## drawing a crown piece (above the roof): its own materials (fx_mat(true))


## A plain, unlit-by-itself box in a per-instance colour (frames, fins, mast steel): in the crown,
## the crown's material; elsewhere the world's own dark material.
func _dk(at: Vector3, size: Vector3, col: Color, yaw := 0.0) -> void:
	if _crown:
		box(fx_mat(true), at, size, col, Color(0, 0, 1, 0), yaw)
	else:
		box(dark(col), at, size, Color.WHITE, Color(0, 0, 0, 0), yaw)


# --- Batches ----------------------------------------------------------------------------------

func _shape(name: String) -> Mesh:
	if _shapes.has(name):
		return _shapes[name]
	var mesh: Mesh
	match name:
		"box":
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			mesh = b
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 10
			c.rings = 1
			mesh = c
		"quad":
			var q := QuadMesh.new()
			q.size = Vector2.ONE
			mesh = q
	_shapes[name] = mesh
	return mesh


func put(shape: String, mt: Material, xf: Transform3D, col := Color.WHITE, cus := Color(0, 0, 0, 0)) -> void:
	var key := "%s|%d" % [shape, mt.get_instance_id()]
	var b: Dictionary = _bt.get_or_add(key, {"shape": shape, "mat": mt, "xf": [], "col": [], "cus": []})
	b.xf.append(xf)
	b.col.append(col)
	b.cus.append(cus)


func box(mt: Material, at: Vector3, size: Vector3, col := Color.WHITE, cus := Color(0, 0, 0, 0), yaw := 0.0) -> void:
	put("box", mt, Transform3D(Basis(Vector3.UP, yaw).scaled_local(size) if yaw != 0.0 else Basis.from_scale(size), at), col, cus)


func flush(parent: Node3D) -> void:
	for key in _bt:
		var b: Dictionary = _bt[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		var mesh: PrimitiveMesh = _shape(b.shape).duplicate()
		mesh.material = b.mat
		mm.mesh = mesh
		mm.instance_count = b.xf.size()
		for i in b.xf.size():
			mm.set_instance_transform(i, b.xf[i])
			mm.set_instance_color(i, b.col[i])
			mm.set_instance_custom_data(i, b.cus[i])
		if b.mat == _mats.get("drones"):
			mm.custom_aabb = AABB(Vector3(-400, -120, -400), Vector3(800, 160, 800))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	_bt = {}
	for n in _pending:
		parent.add_child(n)
	_pending.clear()


# --- Materials --------------------------------------------------------------------------------

func _common(mt: ShaderMaterial) -> void:
	mt.set_shader_parameter("map_size", Vector2(m.w, m.h))
	mt.set_shader_parameter("day", daylight)


## A facade material: style 0 the band carried down (mask), 1-4 the generic facades (tiers, the
## twin, the far city with per_instance).
func tower_mat(style: int, over := {}) -> ShaderMaterial:
	var key := "tower%d|%s" % [style, str(over)]
	if _mats.has(key):
		return _mats[key]
	var mt := ShaderMaterial.new()
	mt.shader = TOWER_SHADER
	_common(mt)
	var src := lk.duplicate()
	src.merge(over, true)
	mt.set_shader_parameter("style", style)
	for k in ["glass", "spandrel", "mullion", "slab"]:
		mt.set_shader_parameter(k + "_col", Color(String(src.get(k, "202020"))))
	var warm: Array = src.get("warm", ["ffc890"])
	var cool: Array = src.get("cool", ["aaf6ff"])
	mt.set_shader_parameter("warm_a", Color(String(warm[0])))
	mt.set_shader_parameter("warm_b", Color(String(warm[warm.size() - 1])))
	mt.set_shader_parameter("cool_a", Color(String(cool[0])))
	mt.set_shader_parameter("cool_b", Color(String(cool[cool.size() - 1])))
	mt.set_shader_parameter("warm_share", float(src.get("warm_share", 0.5)))
	mt.set_shader_parameter("lit_share", float(src.get("lit", 0.32)))
	mt.set_shader_parameter("dark_floors", float(src.get("dark_floors", 0.2)))
	mt.set_shader_parameter("mullion_step", float(src.get("mullion_step", 0.5)))
	mt.set_shader_parameter("mullion_w", float(src.get("mullion_w", 0.05)))
	mt.set_shader_parameter("bay", float(src.get("bay", 3)))
	mt.set_shader_parameter("sill", TowerLook.SILL)
	mt.set_shader_parameter("lintel", TowerLook.LINTEL)
	if TowerLook.has(src, "seam") and float(src.get("seam_every", 0)) > 0.0:
		mt.set_shader_parameter("seam_col", Color(String(src.seam)))
		mt.set_shader_parameter("seam_every", float(src.seam_every))
		mt.set_shader_parameter("seam_glow", float(src.get("seam_glow", 1.0)))
	if TowerLook.has(src, "ledge"):
		mt.set_shader_parameter("ledge_col", Color(String(src.ledge)))
		mt.set_shader_parameter("ledge_every", float(src.get("ledge_every", 0)))
	mt.set_shader_parameter("mech_every", float(src.get("mech_every", 12)))
	mt.set_shader_parameter("storey0", float(storey0))
	mt.set_shader_parameter("plate", Vector4(face.position.x, face.position.y, face.end.x, face.end.y))
	mt.set_shader_parameter("origin", Vector2(rect.position))
	mt.set_shader_parameter("seed", _seed())
	mt.set_shader_parameter("smog_col", smog)
	mt.set_shader_parameter("bounce", 0.0 if daylight else 0.55)
	mt.set_shader_parameter("flood", float(src.get("flood", 0.0)))
	mt.set_shader_parameter("flood_col", flood_color(Color(String(src.get("spandrel", "202020")))))
	mt.set_shader_parameter("sky_col", Color("7a96b8"))   # the day sky in the glass (bluer than the haze)
	mt.set_shader_parameter("haze", float(over.get("haze", 0.0)))
	mt.set_shader_parameter("per_instance", bool(over.get("per_instance", false)))
	if style == 0:
		mt.set_shader_parameter("mask", _facade_mask())
	_mats[key] = mt
	return mt


## The band's lowest storey's outer wall, square by square, for the impostor (tower.gdshader
## style 0): r = what the square holds (60 solid wall, 120 glass, 180 punched window), g = its room.
func _facade_mask() -> ImageTexture:
	if _mask != null:
		return _mask
	var n := maxi(rect.size.x, rect.size.y) + 1
	var img := Image.create(n, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color8(60, 0, 0, 255))
	for fc in 4:
		var horiz := fc < 2
		var a: int = [rect.position.y, rect.end.y - 1, rect.position.x, rect.end.x - 1][fc]
		var len := rect.size.x if horiz else rect.size.y
		for i in len:
			var x := rect.position.x + i if horiz else a
			var y := a if horiz else rect.position.y + i
			if not m.inb(x, y):
				continue
			var kind := 1
			if m.t(0, x, y) == TacMap.T.WALL and int(m.wall_mat[0][y * m.w + x]) in [5, 6]:
				kind = 2
				if punched:   # a lone window square in a hotel's wall
					var pa := Vector2i(x - 1, y) if horiz else Vector2i(x, y - 1)
					var pb := Vector2i(x + 1, y) if horiz else Vector2i(x, y + 1)
					var ga := m.inb(pa.x, pa.y) and m.t(0, pa.x, pa.y) == TacMap.T.WALL and int(m.wall_mat[0][pa.y * m.w + pa.x]) in [5, 6]
					var gb := m.inb(pb.x, pb.y) and m.t(0, pb.x, pb.y) == TacMap.T.WALL and int(m.wall_mat[0][pb.y * m.w + pb.x]) in [5, 6]
					if not ga and not gb:
						kind = 3
			var room := room_key(0, fc, x, y) - fc * 301
			img.set_pixel(i, fc, Color8(kind * 60, room, 0, 255))
	_mask = ImageTexture.create_from_image(img)
	return _mask


## Lamps, strips, letters (and, with glow 0, plain coloured boxes): one material, colour per
## instance. `crown`: the crown's own, drawn only while the band's roof is (sky_fx crown_floor).
func fx_mat(crown := false) -> ShaderMaterial:
	var key := "fx_crown" if crown else "fx"
	if not _mats.has(key):
		var mt := ShaderMaterial.new()
		mt.shader = FX_SHADER
		_common(mt)
		mt.set_shader_parameter("crown_floor", float(rf) if crown else -1.0)
		_mats[key] = mt
	return _mats[key]


func holo_mat(billboard: bool, col2: Color) -> ShaderMaterial:
	var key := "holo%s%s" % [billboard, col2.to_html()]
	if not _mats.has(key):
		var mt := ShaderMaterial.new()
		mt.shader = HOLO_SHADER
		_common(mt)
		mt.set_shader_parameter("billboard", billboard)
		mt.set_shader_parameter("col2", col2)
		_mats[key] = mt
	return _mats[key]


## A plain dark material (metal, frames) in the world's own shader, never fogged or cut.
func dark(col: Color) -> ShaderMaterial:
	return wb.mat("dark", 0, false, {"mode": 2, "no_spill": true, "color": col})


## A lamp, strip or letter: emissive, steady, or blinking (rate per second, duty).
func _light(at: Vector3, size: Vector3, col: Color, glow := 1.2, phase := 0.0, rate := 0.0, duty := 1.0) -> void:
	box(fx_mat(_crown), at, size, col, Color(phase, rate, duty, glow))


# --- The facade and its setbacks --------------------------------------------------------------

func _facade() -> void:
	var ts := tiers()
	var pier := dark(_c("pier"))
	var tier_style := 3 if punched else (1 if float(lk.get("mullion_w", 0.05)) <= 0.06 else 2)
	for i in ts.size():
		var r: Rect2 = ts[i][0]
		var top: float = ts[i][1]
		var bottom: float = ts[i][2]
		var mt := tower_mat(0) if i == 0 else tower_mat(tier_style)
		var c := r.get_center()
		box(mt, Vector3(c.x, (top + bottom) / 2 - 0.005, c.y), Vector3(r.size.x, top - bottom - 0.01, r.size.y))
		# the corner piers, carried down from the band's
		var off := PIER / 2 + 0.12 - FACE_IN
		var pm := wb.mat("wall_concrete", 0, false, {"mode": 2, "no_spill": true, "color": _c("pier"), "color2": _c("pier") * 0.58})
		for cx in [r.position.x + off, r.end.x - off]:
			for cz in [r.position.y + off, r.end.y - off]:
				box(pm if i == 0 else pier, Vector3(cx, (top + bottom) / 2, cz), Vector3(PIER, top - bottom, PIER))
		if i == 0 and TowerLook.has(lk, "seam"):   # the band's seam strips run on down the shaft
			for s in _seam_lines(face, top - bottom):
				var a: Vector3 = s[0]
				_light(a + Vector3(0, bottom, 0), s[1], _c("seam"), float(lk.get("seam_glow", 1.0)) * 0.95)


func _ledge(it: Dictionary) -> void:
	var r: Rect2 = it.rect
	var y: float = it.at.y
	var col := TowerLook.col(lk, "ledge", TowerLook.col(lk, "trim", Color.BLACK))
	var lip := dark(_c("slab"))
	for e in [[Vector3(r.get_center().x, 0, r.position.y), Vector3(r.size.x + 0.2, 0, 0.2)], [Vector3(r.get_center().x, 0, r.end.y), Vector3(r.size.x + 0.2, 0, 0.2)],
			[Vector3(r.position.x, 0, r.get_center().y), Vector3(0.2, 0, r.size.y + 0.2)], [Vector3(r.end.x, 0, r.get_center().y), Vector3(0.2, 0, r.size.y + 0.2)]]:
		var c: Vector3 = e[0]
		var sz: Vector3 = e[1]
		box(lip, c + Vector3(0, y + 0.15, 0), Vector3(sz.x, 0.3, sz.z))
		if col != Color.BLACK:   # a lit edge on the tier
			_light(c + Vector3(0, y + 0.33, 0), Vector3(sz.x + 0.02, 0.07, sz.z + 0.02), col, 1.0)


func _hvac(it: Dictionary) -> void:
	var s: Vector3 = it.size
	if it.kind == "cooler":   # a cooling tower: a squat drum, its fan deck dark on top
		put("cyl", dark(Color("3a4660")), Transform3D(Basis.from_scale(Vector3(s.x, s.y, s.x)), it.at))
		put("cyl", dark(Color("0b0e16")), Transform3D(Basis.from_scale(Vector3(s.x * 0.8, 0.05, s.x * 0.8)), it.at + Vector3(0, s.y / 2 + 0.02, 0)))
	else:
		box(dark(Color("4a5560")), it.at, s)
		box(dark(Color("1e2636")), it.at + Vector3(0, s.y / 2 + 0.03, 0), Vector3(s.x * 0.5, 0.06, s.z * 0.5))


func _gantry(it: Dictionary) -> void:
	var r: Rect2 = (it.rect as Rect2).grow(0.45)
	var y: float = it.at.y
	var grate := dark(Color("2a3448"))
	var rail := dark(Color("4e5c78"))
	for e in [[Vector3(r.get_center().x, 0, r.position.y), Vector3(r.size.x, 0, 0.9), true], [Vector3(r.get_center().x, 0, r.end.y), Vector3(r.size.x, 0, 0.9), true],
			[Vector3(r.position.x, 0, r.get_center().y), Vector3(0.9, 0, r.size.y), false], [Vector3(r.end.x, 0, r.get_center().y), Vector3(0.9, 0, r.size.y), false]]:
		var c: Vector3 = e[0]
		var sz: Vector3 = e[1]
		var horiz: bool = e[2]
		box(grate, c + Vector3(0, y + 0.04, 0), Vector3(sz.x, 0.08, sz.z))
		var out := Vector3(0, 0, 0.42 * signf(c.z - it.at.z)) if horiz else Vector3(0.42 * signf(c.x - it.at.x), 0, 0)
		box(rail, c + out + Vector3(0, y + 0.55, 0), Vector3(sz.x if horiz else 0.04, 0.04, 0.04 if horiz else sz.z))
		box(rail, c + out + Vector3(0, y + 0.3, 0), Vector3(sz.x if horiz else 0.03, 0.03, 0.03 if horiz else sz.z))
		var n := int((sz.x if horiz else sz.z) / 6.0)
		for k in n:   # small amber work lamps along it
			var t := (k + 0.5) / n - 0.5
			_light(c + out * 0.9 + (Vector3(t * sz.x, 0, 0) if horiz else Vector3(0, 0, t * sz.z)) + Vector3(0, y + 0.62, 0), Vector3(0.1, 0.06, 0.1), AMBER, 1.2)


# --- The crown --------------------------------------------------------------------------------

func _fin(it: Dictionary) -> void:
	var s: Vector3 = it.size
	_dk(it.at, s, _c("pier").lerp(Color("0b0e16"), 0.5))
	var out := Vector3(0, 0, -s.z / 2 - 0.01) if it.along_x else Vector3(-s.x / 2 - 0.01, 0, 0)
	_light(it.at + out, Vector3(0.05, s.y, 0.02) if it.along_x else Vector3(0.02, s.y, 0.05), it.color, 1.3)
	_light(it.at + Vector3(0, s.y / 2 + 0.04, 0), Vector3(0.1, 0.08, 0.1), it.color, 1.5)


## 5x7 pixel letters for crown logos and blade signs (rows top down, bit 4 the left column).
const FONT := {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14],
	"D": [28, 18, 17, 17, 17, 18, 28], "E": [31, 16, 16, 30, 16, 16, 31], "F": [31, 16, 16, 30, 16, 16, 16],
	"G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17], "I": [14, 4, 4, 4, 4, 4, 14],
	"J": [7, 2, 2, 2, 2, 18, 12], "K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 17, 25, 21, 19, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14],
	"P": [30, 17, 17, 30, 16, 16, 16], "Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17],
	"S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4], "U": [17, 17, 17, 17, 17, 17, 14],
	"V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 21, 10], "X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 17, 10, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31],
	"0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31],
	"3": [31, 2, 4, 2, 1, 17, 14], "4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14],
	"6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14],
	"9": [14, 17, 17, 15, 1, 2, 12], "&": [12, 18, 20, 8, 21, 18, 13], "-": [0, 0, 0, 31, 0, 0, 0],
	".": [0, 0, 0, 0, 0, 12, 12], " ": [0, 0, 0, 0, 0, 0, 0],
}


## A letter's lit runs: [[column, row, run length]] (merged along each row).
static func glyph_runs(ch: String) -> Array:
	var out := []
	var rows: Array = FONT.get(ch, FONT[" "])
	for r in 7:
		var bits := int(rows[r])
		var c := 0
		while c < 5:
			if bits & (16 >> c):
				var n := 1
				while c + n < 5 and bits & (16 >> (c + n)):
					n += 1
				out.append([c, r, n])
				c += n
			else:
				c += 1
	return out


## Pixel text on a plane: `origin` the top-left of the first letter, `right` / `down` unit
## vectors along the line and down a letter, `out` the facing (letters stand proud of it).
func _text(text: String, origin: Vector3, right: Vector3, down: Vector3, out: Vector3, px: float, col: Color, glow := 1.4, stacked := false) -> void:
	for i in text.length():
		var o := origin + (down * (i * 8 * px) if stacked else right * (i * 6 * px))
		for run in glyph_runs(text[i]):
			var c := o + right * (float(run[0]) + float(run[2]) / 2.0) * px + down * (float(run[1]) + 0.5) * px + out * 0.03
			var size := right.abs() * float(run[2]) * px * 0.98 + down.abs() * px * 0.9 + out.abs() * 0.06
			_light(c, size, col, glow)


func _logo(it: Dictionary) -> void:
	var s: Vector3 = it.size
	var along_x: bool = it.along_x
	var px: float = it.px
	_dk(it.at, s, Color("05060a"))
	var right := Vector3(1, 0, 0) if along_x else Vector3(0, 0, -1)   # read from the camera side
	var out := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var w: float = String(it.text).length() * 6 * px - px
	var origin: Vector3 = it.at + out * (0.1) - right * w / 2 + Vector3(0, 3.5 * px, 0)
	_text(String(it.text), origin, right, Vector3.DOWN, out, px, it.color, 1.5)
	for sg in [-1, 1]:   # legs down to the roof's edge
		var leg: Vector3 = it.at + right * (s.x if along_x else s.z) * 0.4 * sg
		var bottom: float = it.at.y - s.y / 2
		var base := rf * FH + 0.2
		_dk(Vector3(leg.x, (bottom + base) / 2, leg.z), Vector3(0.14, bottom - base, 0.14), Color("141a26"))


func _step(it: Dictionary) -> void:
	var s: Vector3 = it.size
	_dk(it.at, s, _c("spandrel"))
	var front := Vector3(0, 0, s.z / 2 + 0.01) if it.along_x else Vector3(s.x / 2 + 0.01, 0, 0)
	_light(it.at + front + Vector3(0, s.y / 2 - 0.05, 0), Vector3(s.x, 0.07, 0.03) if it.along_x else Vector3(0.03, 0.07, s.z), it.color, 1.3)


func _mast(it: Dictionary) -> void:
	var b: Vector3 = it.base
	var h: float = it.height
	var steel := Color("4e5c78")
	var legs := [Vector3(-0.25, 0, -0.18), Vector3(0.25, 0, -0.18), Vector3(0, 0, 0.26)]
	for l in legs:
		_dk(b + l + Vector3(0, h / 2, 0), Vector3(0.06, h, 0.06), steel)
	var y := 0.6
	while y < h - 0.3:   # the lattice: a triangle of bars every so often
		for i in 3:
			var a: Vector3 = legs[i]
			var c: Vector3 = legs[(i + 1) % 3]
			var mid := (a + c) / 2
			var d := c - a
			_dk(b + mid + Vector3(0, y, 0), Vector3(d.length(), 0.04, 0.04), steel, -atan2(d.z, d.x))
		y += 0.9
	_dk(b + Vector3(0, h + 1.0, 0), Vector3(0.05, 2.0, 0.05), steel)   # the whip on top
	for k in 3:
		_light(b + Vector3(0, h * (k + 1) / 3.0, 0) + Vector3(0.0, 0, 0.3), Vector3(0.14, 0.14, 0.14), RED, 1.6, 0.25 * k, 0.75, 0.55)
	_light(b + Vector3(0, h + 2.05, 0), Vector3(0.16, 0.16, 0.16), Color("fff4e0"), 1.6, 0.0, 1.1, 0.15)


func _dish(it: Dictionary) -> void:
	var r: float = it.r
	var yaw: float = it.yaw
	var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2 - 0.35)
	put("cyl", fx_mat(true), Transform3D(bs.scaled_local(Vector3(r * 2, 0.08, r * 2)), it.at), Color("8a96a0"), Color(0, 0, 1, 0))
	put("cyl", fx_mat(true), Transform3D(bs.scaled_local(Vector3(0.08, r * 1.2, 0.08)), it.at + bs.y * r * 0.5), Color("2a3448"), Color(0, 0, 1, 0))


# --- Greebles below ---------------------------------------------------------------------------

func _cradle(it: Dictionary) -> void:
	var s: Vector3 = it.size
	var at: Vector3 = it.at
	box(dark(Color("66717c")), at, Vector3(s.x, 0.12, s.z))
	box(dark(Color("8a96a0")), at + Vector3(0, 0.3, 0), s * Vector3(1, 0, 1) + Vector3(0, 0.05, 0))   # the rail
	box(dark(Color("3a4660")), at + Vector3(0, 0.15, 0), Vector3(s.x * 0.96, 0.2, s.z * 0.96))
	var along := Vector3(1, 0, 0) if it.along_x else Vector3(0, 0, 1)
	var lng := s.x if it.along_x else s.z
	for sg in [-1, 1]:   # the cables up under the band
		var c: Vector3 = at + along * lng * 0.42 * sg
		box(dark(Color("141a26")), Vector3(c.x, (c.y - 0.05) / 2, c.z), Vector3(0.03, -c.y - 0.05, 0.03))
	_light(at + Vector3(0, 0.45, 0) + along * lng * 0.3, Vector3(0.14, 0.1, 0.14), Color("fff0a0"), 1.5)
	_light(at + Vector3(0, 0.45, 0) - along * lng * 0.3, Vector3(0.1, 0.1, 0.1), AMBER, 1.4, 0.3, 0.9, 0.5)


func _pipe(it: Dictionary) -> void:
	var r: float = it.r
	var s: Vector3 = it.size
	put("cyl", dark(Color("3a4660")), Transform3D(Basis.from_scale(Vector3(r * 2, s.y, r * 2)), it.at))
	var y: float = it.at.y + s.y / 2 - 0.4
	while y > it.at.y - s.y / 2:   # brackets every couple of storeys
		box(dark(Color("141a26")), Vector3(it.at.x - r * 0.5, y, it.at.z), Vector3(r * 2 + 0.1, 0.08, r * 2 + 0.06))
		y -= FH * 2


func _bridge(it: Dictionary, stub: bool) -> void:
	var s: Vector3 = it.size
	var at: Vector3 = it.at
	var shell := dark(_c("spandrel") if not stub else Color("2a3448"))
	box(shell, at + Vector3(0, -s.y / 2 + 0.12, 0), Vector3(s.x, 0.24, s.z))   # deck
	box(shell, at + Vector3(0, s.y / 2 - 0.1, 0), Vector3(s.x + 0.1, 0.2, s.z + 0.1))   # roof
	var along_x: bool = it.along_x if stub else false
	var win := Color("fff4e0") if not stub else Color("aaf6ff")
	for sg in [-1, 1]:   # glazed sides, lit from inside, mullions every square
		var side: Vector3 = Vector3(0, 0, s.z / 2) * sg if along_x else Vector3(s.x / 2, 0, 0) * sg
		var lng := s.x if along_x else s.z
		_light(at + side, Vector3(lng, s.y - 0.5, 0.03) if along_x else Vector3(0.03, s.y - 0.5, lng), win, 0.55)
		var n := int(lng)
		for k in n + 1:
			var t := -lng / 2 + lng * k / maxf(n, 1)
			box(shell, at + side * 1.01 + (Vector3(t, 0, 0) if along_x else Vector3(0, 0, t)), Vector3(0.08, s.y - 0.4, 0.06) if along_x else Vector3(0.06, s.y - 0.4, 0.08))
	if stub:   # cut off at its far end: a dark cap and a red lamp
		box(dark(Color("0b0e16")), at - Vector3(s.x / 2, 0, 0), Vector3(0.1, s.y, s.z))
		_light(at - Vector3(s.x / 2 + 0.08, -s.y / 2 + 0.2, 0), Vector3(0.12, 0.12, 0.12), RED, 1.5, 0.6, 0.8, 0.5)


func _screen(it: Dictionary) -> void:
	var s: Vector3 = it.size
	var fx: bool = it.fx
	var frame := dark(Color("141a26"))
	var w := s.z if fx else s.x
	for sg in [-1, 1]:   # the frame
		box(frame, it.at + Vector3(0, s.y / 2 * sg, 0), Vector3(s.x + 0.1, 0.14, s.z + 0.1))
		box(frame, it.at + (Vector3(0, 0, w / 2 * sg) if fx else Vector3(w / 2 * sg, 0, 0)), Vector3(0.2, s.y, 0.12) if fx else Vector3(0.12, s.y, 0.2))
	var bs := Basis(Vector3.UP, PI / 2) if fx else Basis.IDENTITY
	var at: Vector3 = it.at + (Vector3(0.12, 0, 0) if fx else Vector3(0, 0, 0.12))
	var col: Color = it.color
	put("quad", holo_mat(false, col.lightened(0.5) if int(it.holo) != 2 else Color("ff2a6d")), Transform3D(bs.scaled_local(Vector3(w, s.y, 1)), at), col, Color(float(it.seed), float(it.holo), 1.0, 0))


func _blade(it: Dictionary) -> void:
	var s: Vector3 = it.size
	var at: Vector3 = it.at
	box(dark(Color("141a26")), at, s)
	var edge: Color = it.edge
	for sg in [-1, 1]:   # neon round the blade
		_light(at + Vector3(s.x / 2 * sg, s.y / 2 - 0.05, 0), Vector3(0.03, 0.06, s.z), edge, 1.4)
		_light(at + Vector3(s.x / 2 * sg, -s.y / 2 + 0.05, 0), Vector3(0.03, 0.06, s.z), edge, 1.4)
		_light(at + Vector3(s.x / 2 * sg, 0, s.z / 2 - 0.05), Vector3(0.03, s.y, 0.06), edge, 1.4)
		_light(at + Vector3(s.x / 2 * sg, 0, -s.z / 2 + 0.05), Vector3(0.03, s.y, 0.06), edge, 1.4)
		var px: float = it.px
		var right := Vector3(0, 0, -1) if sg > 0 else Vector3(0, 0, 1)
		var origin := at + Vector3(s.x / 2 * sg, s.y / 2 - 0.6, 0) - right * 2.5 * px
		_text(String(it.text), origin, right, Vector3.DOWN, Vector3(sg, 0, 0), px, it.color, 1.5, true)
	for y in [s.y / 2 - 0.3, -s.y / 2 + 0.3]:   # brackets back to the wall
		box(dark(Color("2a3448")), at + Vector3(0, y, -s.z / 2 - 0.1), Vector3(0.1, 0.1, 0.25))


func _pad(it: Dictionary) -> void:
	var s: Vector3 = it.size
	var at: Vector3 = it.at
	box(dark(Color("2a3448")), at, s)
	box(dark(Color("141a26")), at + Vector3(0, -0.25, 0), Vector3(s.x * 0.9, 0.2, s.z * 0.9))
	for sg in [-1, 1]:   # struts back to the facade
		var b := at + Vector3(-s.x / 2 + 0.3, -1.6, s.z * 0.3 * sg)
		var a := at + Vector3(s.x * 0.15, -0.2, s.z * 0.3 * sg)
		var d := a - b
		var bs := Basis(Vector3(0, 0, 1), atan2(d.y, d.x))
		put("box", dark(Color("1e2636")), Transform3D(bs.scaled_local(Vector3(d.length(), 0.18, 0.18)), (a + b) / 2))
	var paint := Color("b4bec6")   # an H
	box(dark(paint), at + Vector3(0, s.y / 2 + 0.01, -0.6), Vector3(1.8, 0.02, 0.3))
	box(dark(paint), at + Vector3(0, s.y / 2 + 0.01, 0.6), Vector3(1.8, 0.02, 0.3))
	box(dark(paint), at + Vector3(0, s.y / 2 + 0.01, 0), Vector3(0.3, 0.02, 1.5))
	var n := 16
	for k in n:   # landing lights round the rim, chasing
		var t := float(k) / n
		var p := Vector3.ZERO
		var q := t * 4.0
		var e := floori(q)
		var f := q - e
		match e:
			0: p = Vector3(lerpf(-1, 1, f), 0, -1)
			1: p = Vector3(1, 0, lerpf(-1, 1, f))
			2: p = Vector3(lerpf(1, -1, f), 0, 1)
			_: p = Vector3(-1, 0, lerpf(1, -1, f))
		var col := Color("39f0a0") if k % 2 == 0 else AMBER
		_light(at + Vector3(p.x * s.x * 0.47, s.y / 2 + 0.05, p.z * s.z * 0.47), Vector3(0.12, 0.08, 0.12), col, 1.5, t, 0.8, 0.3)


func _twin(it: Dictionary) -> void:
	var r: Rect2 = it.rect
	var s: Vector3 = it.size
	box(tower_mat(2, {"haze": 0.3}), it.at, s)
	var top: float = it.at.y + s.y / 2
	var off := PIER / 2 + 0.12 - FACE_IN
	for cx in [r.position.x + off, r.end.x - off]:
		for cz in [r.position.y + off, r.end.y - off]:
			box(dark(_c("pier")), Vector3(cx, it.at.y, cz), Vector3(PIER, s.y, PIER))
			_light(Vector3(cx, top + 0.15, cz), Vector3(0.18, 0.18, 0.18), RED, 1.6, randf_det(cx + cz), 0.8, 0.5)
	if TowerLook.has(lk, "trim"):
		var c := r.get_center()
		_light(Vector3(c.x, top - 0.1, r.end.y + 0.02), Vector3(r.size.x, 0.06, 0.03), _c("trim"), 1.0)
		_light(Vector3(r.end.x + 0.02, top - 0.1, c.y), Vector3(0.03, 0.06, r.size.y), _c("trim"), 1.0)


static func randf_det(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)


# --- The far city -----------------------------------------------------------------------------

func _far_mat(style_i: int) -> ShaderMaterial:
	var styles: Array = TowerLook.data().get("far", {}).get("styles", [{}])
	var st: Dictionary = styles[style_i % styles.size()]
	var over := {"per_instance": true, "haze": 0.75, "dark_floors": 0.25, "mech_every": 0, "flood": 0.0, "ledge": "", "seam": ""}
	for k in ["glass", "spandrel", "mullion", "slab"]:
		over[k] = String(st.get(k, "141a26"))
	return tower_mat(int(st.get("style", 1)), over)


func _far(it: Dictionary) -> void:
	var s: Vector3 = it.size
	var at: Vector3 = it.at
	var top: float = it.top
	var styles: Array = TowerLook.data().get("far", {}).get("styles", [{}])
	var st: Dictionary = styles[int(it.style) % styles.size()]
	var mt := _far_mat(int(it.style))
	var cus := Color(float(it.seed), float(it.lit), float(st.get("warm_share", 0.5)) * 0.5 + float(it.warm) * 0.5, float(st.get("style", 1)))
	var acc: Color = it.accent
	acc.a = 1.0 if it.seams else 0.0
	box(mt, at, s, acc, cus)
	var cap := dark(Color("0b0e16"))
	var p := Vector3(at.x, top, at.z)
	match String(it.cap):
		"step":   # a setback or two
			var h1 := FH * (2 + int(it.seed) % 4)
			box(mt, p + Vector3(0, h1 / 2, 0), Vector3(s.x * 0.68, h1, s.z * 0.68), acc, cus)
			box(cap, p + Vector3(0, h1 + 0.1, 0), Vector3(s.x * 0.5, 0.2, s.z * 0.5))
			p.y += h1
		"spire":
			var h2 := 4.0 + float(int(it.seed) % 7)
			box(cap, p + Vector3(0, h2 / 2, 0), Vector3(0.3, h2, 0.3))
			box(cap, p + Vector3(0, 0.6, 0), Vector3(s.x * 0.4, 1.2, s.z * 0.4))
			p.y += h2
		"band":   # a lit crown
			_light(Vector3(at.x, top - 0.6, at.z), Vector3(s.x + 0.06, 0.18, s.z + 0.06), acc, 1.2)
			box(cap, p + Vector3(0, 0.1, 0), Vector3(s.x * 0.8, 0.2, s.z * 0.8))
		"ad":   # a rooftop holo-ad on legs, facing the map
			var mid := face.get_center()
			var toward := Vector2(mid.x - at.x, mid.y - at.z)
			var yaw := atan2(toward.x, toward.y)
			var w := minf(s.x, s.z) * 0.9
			var c := p + Vector3(0, 0.6 + w * 0.3, 0)
			box(cap, p + Vector3(0, 0.3, 0), Vector3(w * 0.6, 0.6, 0.2), Color.WHITE, Color(0, 0, 0, 0), yaw)
			put("quad", holo_mat(false, Color("fff4e0")), Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(w, w * 0.55, 1)), c), acc, Color(float(it.seed), 3.0, 0.9, 0))
		"hvac":
			for k in 3:
				var o := Vector3(randf_det(it.seed + k) - 0.5, 0, randf_det(it.seed * 3 + k) - 0.5) * Vector3(s.x * 0.6, 0, s.z * 0.6)
				box(dark(Color("2a3448")), p + o + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 1.2))
		_:
			box(cap, p + Vector3(0, 0.15, 0), Vector3(s.x * 0.7, 0.3, s.z * 0.7))
	if it.beacon:
		_light(p + Vector3(0, 0.45, 0), Vector3(0.22, 0.22, 0.22), RED, 1.6, randf_det(at.x + at.z), 0.8, 0.5)
	if it.edge:   # a vertical neon edge so the mass has an outline
		_light(Vector3(at.x + s.x / 2, top - 4.0, at.z + s.z / 2), Vector3(0.16, 8.0, 0.16), acc, 1.4)
	if it.face_ad:   # a holo-ad on the face toward the map
		var mid2 := face.get_center()
		var toward2 := Vector2(mid2.x - at.x, mid2.y - at.z)
		var fx := absf(toward2.x) > absf(toward2.y)
		var w2 := minf(s.x, s.z) * 0.6
		var h2 := w2 * (1.6 if int(it.seed) % 2 == 0 else 0.6)
		var c2 := Vector3(at.x + (signf(toward2.x) * (s.x / 2 + 0.1) if fx else 0.0), top - 2.5 - h2 / 2, at.z + (0.0 if fx else signf(toward2.y) * (s.z / 2 + 0.1)))
		var bs := Basis(Vector3.UP, PI / 2) if fx else Basis.IDENTITY
		put("quad", holo_mat(false, Color("fff4e0")), Transform3D(bs.scaled_local(Vector3(w2, h2, 1)), c2), acc, Color(float(it.seed), 0.0 if h2 > w2 else 3.0, 1.0, 0))


func _holo_big(it: Dictionary) -> void:
	var s: Vector3 = it.size
	var col2: Color = it.color2
	put("quad", holo_mat(true, col2), Transform3D(Basis.from_scale(Vector3(s.x, s.y, 1)), it.at), it.color, Color(float(it.seed), float(it.holo), 1.25, 0))
	box(dark(Color("141a26")), Vector3(it.at.x, it.at.y - s.y / 2 - 0.4, it.at.z), Vector3(3.0, 0.8, 3.0))   # the projector


func _drone(it: Dictionary) -> void:
	if not _mats.has("drones"):
		var mt := ShaderMaterial.new()
		mt.shader = FX_SHADER
		_common(mt)
		mt.set_shader_parameter("kind", 1)
		_mats["drones"] = mt
	var d: Vector2 = it.dir
	box(_mats["drones"], it.at, it.size, it.color, Color(d.x, d.y, float(it.speed), float(it.phase)))


func _ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	var mt := ShaderMaterial.new()
	mt.shader = GROUND_SHADER
	mt.set_shader_parameter("glow_col", smog)
	mt.set_shader_parameter("day", daylight)
	mt.set_shader_parameter("seed", _seed())
	pm.material = mt
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c := face.get_center()
	mi.position = Vector3(c.x, floor_y, c.y)
	mi.name = "city_ground"
	_pending.append(mi)


var _pending: Array[Node3D] = []


## Smog: layers of haze under the band, each a little thicker, so the facade fades out storey by
## storey, lit from below by the city.
func _smog() -> void:
	for k in 3:
		var y := -5.0 - k * 12.0
		if y < floor_y + 1.0:
			break
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(900, 900)
		var mt := ShaderMaterial.new()
		mt.shader = SMOG_SHADER
		mt.set_shader_parameter("smog", smog)
		mt.set_shader_parameter("alpha", 0.1 + 0.05 * k)
		mt.set_shader_parameter("glow", 0.0 if daylight else 0.3 + 0.08 * k)
		mt.set_shader_parameter("seed", float(k) * 3.7 + _seed() * 0.01)
		mt.render_priority = k
		pm.material = mt
		mi.mesh = pm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var c := face.get_center()
		mi.position = Vector3(c.x, y, c.y)
		mi.name = "smog%d" % k
		_pending.append(mi)
