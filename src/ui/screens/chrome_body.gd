class_name ChromeBody
extends Control
## The cyberware silhouette (owner: "a classic Cyberpunk 2077 style human silhouette with slots for
## cyberware"): an angular neon line figure, front view, with a callout card for every location
## (Cyber.LOCS) joined by a leader line to its place on the body. A card shows what's there (the
## foundation and the pieces) and its Option Slots as pips: filled, empty, locked (no foundation yet)
## or occupied (grey, hatched: chrome whose effect isn't played yet, Cyber.modelled false, is never
## named, but its slots stay taken). Body parts with a foundation in them glow violet (chrome);
## meat stays cyan; the selected location is gold.
## The Med Bay's ripperdoc picks a location or an installed piece here (loc_pressed, piece_pressed);
## the loadout screen shows it read-only (clicks only select). Built from Controls, so tests can read
## `cards` and each card's `pips` meta.

signal loc_pressed(loc: String)
signal piece_pressed(loc: String, id: String)

## The figure's drawing space (x 0..200, y 0..440); the character faces the viewer, so their right
## side is on the viewer's left.
const FIG := Vector2(200, 440)
const HEAD := [Vector2(90, 4), Vector2(110, 4), Vector2(121, 16), Vector2(121, 40), Vector2(111, 56), Vector2(89, 56), Vector2(79, 40), Vector2(79, 16)]
const NECK := [Vector2(92, 56), Vector2(108, 56), Vector2(111, 72), Vector2(89, 72)]
const TORSO := [Vector2(89, 72), Vector2(111, 72), Vector2(138, 78), Vector2(150, 92), Vector2(144, 150), Vector2(134, 198),
	Vector2(137, 224), Vector2(63, 224), Vector2(66, 198), Vector2(56, 150), Vector2(50, 92), Vector2(62, 78)]
## The character's right arm (the viewer's left); the left arm mirrors it.
const ARM := [Vector2(46, 82), Vector2(34, 96), Vector2(26, 158), Vector2(18, 226), Vector2(13, 240), Vector2(17, 264),
	Vector2(30, 264), Vector2(35, 240), Vector2(37, 226), Vector2(41, 160), Vector2(47, 110)]
const LEG := [Vector2(65, 228), Vector2(98, 228), Vector2(96, 246), Vector2(91, 318), Vector2(89, 332), Vector2(88, 408),
	Vector2(93, 430), Vector2(62, 434), Vector2(67, 408), Vector2(66, 332), Vector2(63, 318), Vector2(62, 246)]
const EAR := [Vector2(121, 26), Vector2(127, 30), Vector2(127, 44), Vector2(121, 47)]
## Where each location's leader line meets the body.
const ANCHORS := {"neural_link": Vector2(100, 18), "chipware": Vector2(100, 64), "right_eye": Vector2(92, 32),
	"left_eye": Vector2(108, 32), "cyberaudio": Vector2(125, 38), "right_arm": Vector2(33, 150), "left_arm": Vector2(167, 150),
	"right_leg": Vector2(79, 340), "left_leg": Vector2(121, 340), "internal": Vector2(100, 128), "external": Vector2(61, 180),
	"fashion": Vector2(172, 212), "borgware": Vector2(146, 86)}
## The callout columns, each in its anchors' top-to-bottom order so no leader lines cross.
const LEFT_COL: Array[String] = ["neural_link", "right_eye", "internal", "right_arm", "external", "right_leg"]
const RIGHT_COL: Array[String] = ["left_eye", "cyberaudio", "chipware", "borgware", "left_arm", "fashion", "left_leg"]
## Option Slots a location would hold once its foundation is in (shown as locked pips until then).
const LOCKED_SLOTS := {"neural_link": 5, "chipware": 1, "right_eye": 3, "left_eye": 3, "cyberaudio": 3}
const LIMBS: Array[String] = ["right_arm", "left_arm", "right_leg", "left_leg"]

const CHROME := Color("c77dff")       ## Hud.VIOLET lightened: chrome
const MEAT := Color(0.02, 0.85, 0.91, 0.75)   ## Hud.CYAN, a little dimmed: meat
const GAP := 26.0                      ## between a card column and the figure
const CARD_MIN := 150.0
const CARD_MAX := 232.0

var c: Combatant
var compact := false       ## short screens (1600x900 is ~600 logical lines): smaller cards
var sel_loc := ""
var sel_id := ""
var hints := {}            ## loc → storage pieces that can go in there now (the Med Bay's "+N")
var cards := {}            ## loc → its callout card
var _fig := Rect2()        ## the figure's rect in this control


func setup(p_c: Combatant, p_sel_loc := "", p_sel_id := "", p_hints := {}, p_compact := false) -> ChromeBody:
	c = p_c
	compact = p_compact
	sel_loc = p_sel_loc
	sel_id = p_sel_id
	hints = p_hints
	name = "ChromeBody"
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	custom_minimum_size = Vector2(2 * _card_min() + 2 * GAP + 120, 360 if compact else 440)
	for ch in get_children():
		ch.free()
	cards.clear()
	for loc in LEFT_COL + RIGHT_COL:
		var card := _card(loc)
		cards[loc] = card
		add_child(card)
	_layout()
	return self


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


# --- The model, as the cards show it (static: tests read it too) ------------------------------

## A location's Option Slots as pips: [{state, id}], state "filled" (a piece players see),
## "hidden" (a piece whose effect isn't played: never named), "empty" or "locked" (no foundation
## yet: what it would hold). A piece takes as many pips as Option Slots (a chip one; a Subdermal
## Grip also one of the Neural Link's). A meat arm or leg holds one piece: one pip. Borgware: none.
static func pips(implants: Array, loc: String) -> Array:
	var out: Array = []
	if loc == "borgware":
		return out
	if Cyber.is_meat(implants, loc):
		var mp := Cyber.meat_pieces(implants, loc)
		for p in mp:
			out.append({"state": "filled" if Cyber.modelled(String(p.id)) else "hidden", "id": String(p.id)})
		if mp.is_empty():
			out.append({"state": "empty", "id": ""})
		return out
	var cap := Cyber.capacity(implants, loc)
	var taken: Array = []
	for p in Cyber.pieces_at(implants, loc):
		var id := String(p.id)
		if Cyber.is_foundation(id):
			continue
		taken.append([id, 1 if loc == "chipware" else int(Cyber.def(id).get("slots", 1))])
	if loc == "neural_link":
		for p in implants:
			var ns := int(Cyber.def(String(p.id)).get("neural_slot", 0))
			if ns > 0 and String(p.loc) != "neural_link":
				taken.append([String(p.id), ns])
	if cap <= 0 and taken.is_empty() and Cyber.foundation_at(implants, loc) == "":
		for i in int(LOCKED_SLOTS.get(loc, 0)):
			out.append({"state": "locked", "id": ""})
		return out
	for t in taken:
		for i in int(t[1]):
			out.append({"state": "filled" if Cyber.modelled(String(t[0])) else "hidden", "id": String(t[0])})
	for i in maxi(0, cap - Cyber.used(implants, loc)):
		out.append({"state": "empty", "id": ""})
	return out


## The card's line: the foundation (or Meat / Empty) and the pieces players may see, "Cybereye ·
## Targeting Scope". A hidden foundation reads "Occupied"; hidden options aren't named (their pips say it).
static func line(implants: Array, loc: String) -> String:
	var parts: Array[String] = []
	var f := Cyber.foundation_at(implants, loc)
	if f != "":
		parts.append(Cyber.display(f) if Cyber.modelled(f) else "Occupied")
	elif loc in LIMBS or loc in Cyber.EYES:
		parts.append("Meat")
	for p in Cyber.pieces_at(implants, loc):
		var id := String(p.id)
		if id != f and Cyber.modelled(id) and not (Cyber.def(id).get("free_in_meat", false)):
			parts.append(Cyber.display(id))
	if parts.is_empty():
		var hidden := Cyber.pieces_at(implants, loc).any(func(p): return not Cyber.modelled(String(p.id)))
		parts.append("Occupied" if hidden else "Empty")
	return " · ".join(parts)


## Whether anything is installed at `loc` (seen or not): the card's violet edge.
static func chromed(implants: Array, loc: String) -> bool:
	return not Cyber.pieces_at(implants, loc).filter(func(p): return not Cyber.def(String(p.id)).get("free_in_meat", false)).is_empty()


# --- Cards ------------------------------------------------------------------------------------

func _card(loc: String) -> PanelContainer:
	var on := loc == sel_loc
	var chrome := chromed(c.implants, loc)
	var p := PanelContainer.new()
	p.name = "Card_" + loc
	var fill := Color(0.11, 0.09, 0.02, 0.96) if on else Color(0.025, 0.035, 0.05, 0.94)
	var edge := Hud.GOLD if on else (Color(CHROME, 0.7) if chrome else Color(Hud.DIM, 0.35))
	p.add_theme_stylebox_override("panel", CutBox.make(fill, edge, 6, 0b0101 if loc in LEFT_COL else 0b1010, Hud.GOLD if on else Color(0, 0, 0, 0), 4 if compact else 5))
	var v := UiKit.vbox(1 if compact else 2)
	p.add_child(v)
	var top := UiKit.hbox(4)
	v.add_child(top)
	var head := UiKit.label(Cyber.loc_name(loc), 11 if compact else 12, Hud.GOLD if on else (CHROME if chrome else Hud.CYAN))
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	var n := int(hints.get(loc, 0))
	if n > 0:   # the Med Bay: pieces in storage that can go in here now
		var h := UiKit.label("+%d" % n, 12, Hud.GREEN)
		h.name = "Hint"
		top.add_child(h)
	var ps := pips(c.implants, loc)
	p.set_meta("pips", ps)
	if not ps.is_empty():
		var row := UiKit.hbox(3)
		row.name = "Pips"
		v.add_child(row)
		for pp in ps:
			var pip := Pip.new()
			pip.state = String(pp.state)
			if compact:
				pip.custom_minimum_size = Vector2(9, 9)
			pip.on = String(pp.id) != "" and String(pp.id) == sel_id and on
			row.add_child(pip)
	var txt := line(c.implants, loc)
	var l := UiKit.fit(UiKit.body(txt, 12 if compact else 13, Hud.TEXT if chrome and txt != "Occupied" else Hud.DIM, false))
	l.name = "Line"
	v.add_child(l)
	var lc := loc
	UiKit.clickable(p, func(): loc_pressed.emit(lc))
	var pr := p.find_child("Pips", true, false)
	if pr:   # a filled pip picks its piece (after clickable, which mutes the children)
		for i in pr.get_child_count():
			var pid := String(ps[i].id)
			var pip: Pip = pr.get_child(i)
			if String(ps[i].state) == "filled":
				pip.mouse_filter = Control.MOUSE_FILTER_STOP
				pip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				pip.tooltip_text = Cyber.display(pid)
				pip.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						piece_pressed.emit(lc, pid)
						pip.accept_event())
	return p


## One Option Slot.
class Pip extends Control:
	var state := "empty"
	var on := false

	func _init() -> void:
		custom_minimum_size = Vector2(11, 11)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(0.5, 0.5), size - Vector2(1, 1))
		var k := 3.0   # a chamfered corner, like the panels
		var pts := PackedVector2Array([r.position + Vector2(k, 0), r.end - Vector2(0, r.size.y), Vector2(r.end.x, r.end.y - k),
			Vector2(r.end.x - k, r.end.y), Vector2(r.position.x, r.end.y), r.position + Vector2(0, k)])
		var col: Color = Hud.GOLD if on else ChromeBody.CHROME
		match state:
			"filled":
				draw_colored_polygon(pts, Color(col, 0.9))
			"hidden":   # occupied by chrome not in play: grey, hatched
				draw_colored_polygon(pts, Color(Hud.DIM, 0.35))
				draw_line(Vector2(2, size.y - 2), Vector2(size.x - 2, 2), Color(Hud.DIM, 0.9), 1.0)
			"empty":
				pts.append(pts[0])
				draw_polyline(pts, Color(col, 0.75), 1.0)
			"locked":
				pts.append(pts[0])
				draw_polyline(pts, Color(Hud.DIM, 0.3), 1.0)
				draw_line(Vector2(3, 3), Vector2(size.x - 3, size.y - 3), Color(Hud.DIM, 0.35), 1.0)


# --- Layout -----------------------------------------------------------------------------------

func _layout() -> void:
	if cards.is_empty():
		return
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	var fh := minf(h - 6.0, (w - 2.0 * _card_min() - 2.0 * GAP) * FIG.y / FIG.x)
	fh = maxf(fh, 120.0)
	var fw := fh * FIG.x / FIG.y
	var cw := clampf((w - fw) / 2.0 - GAP, _card_min(), CARD_MAX)
	_fig = Rect2(Vector2((w - fw) / 2.0, (h - fh) / 2.0), Vector2(fw, fh))
	_column(LEFT_COL, maxf(0.0, _fig.position.x - GAP - cw), cw, h)
	_column(RIGHT_COL, minf(w - cw, _fig.end.x + GAP), cw, h)
	queue_redraw()


func _card_min() -> float:
	return 136.0 if compact else CARD_MIN


## Stack a column's cards as near their anchors' heights as they fit, top to bottom.
func _column(locs: Array[String], x: float, cw: float, h: float) -> void:
	var ys: Array[float] = []
	var hs: Array[float] = []
	for loc in locs:
		var card: Control = cards[loc]
		card.size = Vector2(cw, 0)
		var ch := card.get_combined_minimum_size().y
		hs.append(ch)
		ys.append(_pt(ANCHORS[loc]).y - ch / 2.0)
	var gap := 3.0 if compact else 5.0
	for i in ys.size():   # down: no overlaps
		ys[i] = maxf(ys[i], 0.0 if i == 0 else ys[i - 1] + hs[i - 1] + gap)
	for i in range(ys.size() - 1, -1, -1):   # up: inside the bottom edge
		ys[i] = minf(ys[i], h - hs[i] if i == ys.size() - 1 else ys[i + 1] - hs[i] - gap)
	for i in locs.size():
		var card: Control = cards[locs[i]]
		card.position = Vector2(x, maxf(0.0, ys[i]))
		card.size = Vector2(cw, hs[i])


## A figure point in this control's space.
func _pt(p: Vector2) -> Vector2:
	return _fig.position + p * (_fig.size.x / FIG.x)


func _poly(pts: Array, mirror := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_pt(Vector2(FIG.x - p.x, p.y) if mirror else p))
	return out


# --- Drawing ----------------------------------------------------------------------------------

## The colour a body part is drawn in: gold selected, violet chrome, cyan meat.
func _col(locs: Array) -> Color:
	if sel_loc in locs:
		return Hud.GOLD
	for l in locs:
		if Cyber.foundation_at(c.implants, l) != "":
			return CHROME
	return MEAT


## An open location's mark (the skin's contour, the chest's core): gold selected, violet with
## anything installed, else clear.
func _open_col(loc: String) -> Color:
	if sel_loc == loc:
		return Hud.GOLD
	return CHROME if chromed(c.implants, loc) else Color(0, 0, 0, 0)


func _draw() -> void:
	if c == null or _fig.size.x <= 0:
		return
	var s := _fig.size.x / FIG.x
	# the scanner frame: corner brackets and faint scanlines behind the figure
	var fr := _fig.grow(10.0)
	var bc := Color(Hud.CYAN, 0.35)
	var bl := 18.0
	for corner in [[fr.position, Vector2(1, 1)], [Vector2(fr.end.x, fr.position.y), Vector2(-1, 1)], [fr.end, Vector2(-1, -1)], [Vector2(fr.position.x, fr.end.y), Vector2(1, -1)]]:
		var o: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_line(o, o + Vector2(bl * d.x, 0), bc, 1.5)
		draw_line(o, o + Vector2(0, bl * d.y), bc, 1.5)
	var y := fr.position.y + 2.0
	while y < fr.end.y:
		draw_line(Vector2(fr.position.x + 2, y), Vector2(fr.end.x - 2, y), Color(Hud.CYAN, 0.035), 1.0)
		y += 4.0
	# skin: an outer contour when there's external chrome (Skin Weave, Subdermal Armor)
	var ext := _open_col("external")
	# the body, back to front
	var parts := [[LEG, false, ["right_leg"]], [LEG, true, ["left_leg"]], [ARM, false, ["right_arm"]], [ARM, true, ["left_arm"]],
		[TORSO, false, ["internal"]], [NECK, false, ["chipware"]], [HEAD, false, ["neural_link"]], [EAR, true, ["cyberaudio"]]]
	for part in parts:
		var pts := _poly(part[0], part[1])
		var col := _col(part[2]) if part[2] != ["internal"] else (Hud.GOLD if sel_loc == "internal" else MEAT)
		if ext.a > 0 and part[2] != ["cyberaudio"]:
			for off in Geometry2D.offset_polygon(pts, 3.0 * s, Geometry2D.JOIN_MITER):
				_outline(off, Color(ext, 0.55), 1.0, false)
		draw_colored_polygon(pts, Color(col.r * 0.10, col.g * 0.10, col.b * 0.14, 0.92) if col != MEAT else Color(0.02, 0.05, 0.07, 0.9))
		_seams(part, col, s)
		_outline(pts, col, 1.4)
	# eyes
	for e in [["right_eye", 92.0], ["left_eye", 108.0]]:
		var ec := _col([e[0]])
		var cx: float = e[1]
		var eye := _poly([Vector2(cx - 5, 32), Vector2(cx, 29), Vector2(cx + 5, 32), Vector2(cx, 35)])
		draw_colored_polygon(eye, Color(ec, 0.9 if ec != MEAT else 0.45))
	# the internal core: a hexagon in the chest, lit when there's internal chrome
	var core := _open_col("internal")
	if core.a == 0:
		core = Color(MEAT, 0.35)
	var hx: Array = []
	for i in 6:
		hx.append(ANCHORS.internal + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * 9.0)
	_outline(_poly(hx), core, 1.2)
	# leader lines and their anchor marks
	for loc in cards:
		_leader(loc)


## A neon line: a soft glow under a crisp core.
func _outline(pts: PackedVector2Array, col: Color, width: float, glow := true) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	if glow:
		draw_polyline(closed, Color(col, 0.10), width + 6.0, true)
		draw_polyline(closed, Color(col, 0.22), width + 2.5, true)
	draw_polyline(closed, col, width, true)


## Panel seams: a chrome limb is cut into plates; meat gets a hint of joints.
func _seams(part: Array, col: Color, _s: float) -> void:
	var m: bool = part[1]
	var locs: Array = part[2]
	var chrome := col == CHROME or (col == Hud.GOLD and Cyber.foundation_at(c.implants, locs[0]) != "")
	var lines: Array = []
	match locs[0]:
		"right_arm", "left_arm":
			lines = [[Vector2(29, 158), Vector2(40, 160)], [Vector2(16, 238), Vector2(36, 238)]]
			if chrome:
				lines += [[Vector2(31, 120), Vector2(45, 124)], [Vector2(24, 192), Vector2(39, 194)], [Vector2(33, 98), Vector2(30, 150)]]
		"right_leg", "left_leg":
			lines = [[Vector2(64, 325), Vector2(90, 325)], [Vector2(66, 410), Vector2(88, 410)]]
			if chrome:
				lines += [[Vector2(63, 280), Vector2(94, 280)], [Vector2(67, 368), Vector2(89, 368)], [Vector2(80, 236), Vector2(78, 318)]]
		"internal":
			lines = [[Vector2(100, 84), Vector2(100, 110)], [Vector2(70, 96), Vector2(100, 112)], [Vector2(130, 96), Vector2(100, 112)],
				[Vector2(84, 160), Vector2(116, 160)], [Vector2(86, 180), Vector2(114, 180)], [Vector2(68, 206), Vector2(100, 218)], [Vector2(132, 206), Vector2(100, 218)]]
		"neural_link":
			if chrome:   # the link's traces over the skull
				lines = [[Vector2(100, 8), Vector2(100, 22)], [Vector2(88, 14), Vector2(100, 22)], [Vector2(112, 14), Vector2(100, 22)], [Vector2(100, 22), Vector2(100, 52)]]
	for ln in lines:
		var a: Vector2 = ln[0]
		var b: Vector2 = ln[1]
		if m:
			a.x = FIG.x - a.x
			b.x = FIG.x - b.x
		draw_line(_pt(a), _pt(b), Color(col, 0.45 if chrome else 0.22), 1.0, true)


func _leader(loc: String) -> void:
	var card: Control = cards[loc]
	var a := _pt(ANCHORS[loc])
	var left := loc in LEFT_COL
	var r := card.get_rect()
	var edge := Vector2(r.end.x if left else r.position.x, r.position.y + minf(10.0, r.size.y / 2.0))
	var elbow := Vector2(edge.x + (12.0 if left else -12.0), edge.y)
	var on := loc == sel_loc
	var col := Hud.GOLD if on else (Color(CHROME, 0.75) if chromed(c.implants, loc) else Color(Hud.CYAN, 0.35))
	draw_polyline(PackedVector2Array([edge, elbow, a]), col, 1.6 if on else 1.0, true)
	var d := 3.5 if on else 2.5
	draw_colored_polygon(PackedVector2Array([a + Vector2(0, -d), a + Vector2(d, 0), a + Vector2(0, d), a + Vector2(-d, 0)]), col)
