class_name ChromeBody
extends Control
## The cyberware body: a figure of the crew member's body with a callout card per location. Every
## location (Cyber.LOCS) has a card joined by a leader line to its place on the body (head, eyes,
## ear, neck, chest, arms, legs). A card shows what's there (the foundation and the pieces) and its
## Option Slots as pips: filled, empty or locked (no foundation yet). Every installed piece is named
## and filled, its effect played yet or not (owner, 2026-11-11). Chromed regions are violet, meat
## cyan, the selected location gold, external chrome a skin over the body.
## The figure is a real anatomical plate as light on the dark page (BodyAnatomy; owner, 2026-11-11:
## "Let's take that going forward and drop the ... other attempts"): a man (Milton's écorché, 1804)
## or a woman (Bell's superficial figure, 1798), as the crew member's body is (plate_of: the body
## their 3D model has).
## The Med Bay's ripperdoc picks a location or an installed piece here (loc_pressed, piece_pressed;
## a click on the body picks the nearest place); the loadout screen shows it read-only (clicks only
## select). Built from Controls, so tests can read `cards` and each card's `pips` meta.

signal loc_pressed(loc: String)
signal piece_pressed(loc: String, id: String)

## The callout columns (each stacked in its anchors' top-to-bottom order, so no leader lines cross).
const LEFT_COL: Array[String] = ["neural_link", "right_eye", "internal", "right_arm", "external", "right_leg"]
const RIGHT_COL: Array[String] = ["left_eye", "cyberaudio", "chipware", "borgware", "left_arm", "fashion", "left_leg"]
## Option Slots a location would hold once its foundation is in (shown as locked pips until then).
const LOCKED_SLOTS := {"neural_link": 5, "chipware": 1, "right_eye": 3, "left_eye": 3, "cyberaudio": 3}
const LIMBS: Array[String] = ["right_arm", "left_arm", "right_leg", "left_leg"]

const CHROME := Color("c77dff")       ## Hud.VIOLET lightened: chrome
const GAP := 26.0                      ## between a card column and the figure
const CARD_MIN := 150.0
const CARD_MAX := 232.0

## Body regions the figure tints (BodyAnatomy's bones); L_FORE is the left forearm and hand
## (fashionware's).
enum Reg { TORSO, HEAD, NECK, R_ARM, L_ARM, R_LEG, L_LEG, R_EYE, L_EYE, EAR, L_FORE }
const REGIONS := 11
const REGION_LOCS := {Reg.HEAD: "neural_link", Reg.NECK: "chipware", Reg.R_ARM: "right_arm", Reg.L_ARM: "left_arm",
	Reg.R_LEG: "right_leg", Reg.L_LEG: "left_leg", Reg.R_EYE: "right_eye", Reg.L_EYE: "left_eye", Reg.EAR: "cyberaudio"}

var c: Combatant
var compact := false       ## short screens (1600x900 is ~600 logical lines): smaller cards
var sel_loc := ""
var sel_id := ""
var hints := {}            ## loc → storage pieces that can go in there now (the Med Bay's "+N")
var cards := {}            ## loc → its callout card
var anchors := {}          ## loc → where its leader line meets the body, in this control
var _fig := Rect2()        ## the figure's frame in this control
var _over: Control         ## leader lines and anchor marks, over the figure, under the cards
var _art: BodyAnatomy      ## the figure


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
	anchors.clear()
	_art = BodyAnatomy.new()
	_art.name = "Figure"
	_art.body = self
	_art.plate = plate_of(c)
	_art.motion = not GameSettings.reduced_motion()
	_art.tints = region_tints()
	_art.shell = _shell()
	add_child(_art)
	_over = Overlay.new()
	_over.body = self
	_over.name = "Leaders"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_over)
	for loc in LEFT_COL + RIGHT_COL:
		var card := _card(loc)
		cards[loc] = card
		add_child(card)
	_layout()
	return self


## The plate for a crew member (a BodyAnatomy.PLATES key): the woman for a female body, else the
## man. The body is their 3D model's: CharModel rolls it from the look seed (Recruit.body_of), and
## the safehouse builds crew from maxi(0, look_seed).
static func plate_of(p_c: Combatant) -> String:
	return "female" if Recruit.body_of(maxi(0, p_c.look_seed)) == "female" else "male"


## Every region's tint: [colour (a = how much; 0 = meat), plated]. The ear is the Cyberaudio
## Suite's; the left forearm and hand are fashionware's when it has any (else the arm's).
func region_tints() -> Array:
	var out: Array = []
	for r in REGIONS:
		out.append(_tint(r))
	if sel_loc == "fashion":
		out[Reg.L_FORE] = [Color(Hud.GOLD, 0.8), 0.0]
	elif chromed(c.implants, "fashion"):
		out[Reg.L_FORE] = [Color(CHROME, 0.75), 0.0]
	else:
		out[Reg.L_FORE] = out[Reg.L_ARM]
	return out


## External chrome (skin): a second skin at the body's edge, gold when it's the selected location.
func _shell() -> Color:
	if sel_loc == "external":
		return Color(Hud.GOLD, 0.85)
	if chromed(c.implants, "external"):
		return Color(CHROME, 0.75)
	return Color(0, 0, 0, 0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


# --- The model, as the cards show it (static: tests read it too) ------------------------------

## A location's Option Slots as pips: [{state, id}], state "filled" (a piece), "empty" or "locked"
## (no foundation yet: what it would hold). A piece takes as many pips as Option Slots (a chip one;
## a Subdermal Grip also one of the Neural Link's). A meat arm or leg holds one piece: one pip.
## Borgware: none.
static func pips(implants: Array, loc: String) -> Array:
	var out: Array = []
	if loc == "borgware":
		return out
	if Cyber.is_meat(implants, loc):
		var mp := Cyber.meat_pieces(implants, loc)
		for p in mp:
			out.append({"state": "filled", "id": String(p.id)})
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
			out.append({"state": "filled", "id": String(t[0])})
	for i in maxi(0, cap - Cyber.used(implants, loc)):
		out.append({"state": "empty", "id": ""})
	return out


## The card's line: the foundation (or Meat / Empty) and the pieces in it, "Cybereye · Targeting
## Scope". A meat limb's Standard Hand/Foot isn't listed (it doesn't count there, Cyber.meat_pieces).
static func line(implants: Array, loc: String) -> String:
	var parts: Array[String] = []
	var f := Cyber.foundation_at(implants, loc)
	if f != "":
		parts.append(Cyber.display(f))
	elif loc in LIMBS or loc in Cyber.EYES:
		parts.append("Meat")
	var ps := Cyber.meat_pieces(implants, loc) if Cyber.is_meat(implants, loc) else Cyber.pieces_at(implants, loc)
	for p in ps:
		if String(p.id) != f:
			parts.append(Cyber.display(String(p.id)))
	if parts.is_empty():
		parts.append("Empty")
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
	var l := UiKit.fit(UiKit.body(txt, 12 if compact else 13, Hud.TEXT if chrome else Hud.DIM, false))
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
			"empty":
				pts.append(pts[0])
				draw_polyline(pts, Color(col, 0.75), 1.0)
			"locked":
				pts.append(pts[0])
				draw_polyline(pts, Color(Hud.DIM, 0.3), 1.0)
				draw_line(Vector2(3, 3), Vector2(size.x - 3, size.y - 3), Color(Hud.DIM, 0.35), 1.0)


## A region's tint [colour (a = how much), plated]: gold where the selected location is, violet
## chrome where a foundation (or anything, for the open places) is in, else meat (a = 0).
func _tint(r: int) -> Array:
	if r == Reg.TORSO:   # the trunk: the chest's internal chrome and borgware
		if sel_loc in ["internal", "borgware"]:
			return [Color(Hud.GOLD, 0.5), 0.0]
		if chromed(c.implants, "borgware"):
			return [Color(CHROME, 0.6), 1.0]
		return [Color(0, 0, 0, 0), 0.0]
	if not REGION_LOCS.has(r):
		return [Color(0, 0, 0, 0), 0.0]
	var loc: String = REGION_LOCS[r]
	var found := Cyber.foundation_at(c.implants, loc) != "" if loc != "chipware" else chromed(c.implants, loc)
	var eye := r == Reg.R_EYE or r == Reg.L_EYE
	if sel_loc == loc:
		return [Color(Hud.GOLD, 1.0 if eye else 0.8), 1.0 if found else 0.0]
	if found:
		return [Color(CHROME, 1.0 if eye else (0.6 if r == Reg.HEAD else 0.85)), 1.0]
	return [Color(0, 0, 0, 0), 0.0]



# --- Layout -----------------------------------------------------------------------------------

## The figure fills the height between the card columns; the columns take what's left.
func _layout() -> void:
	if cards.is_empty():
		return
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	var aspect := _art.aspect()
	var fh := maxf(minf(h - 6.0, (w - 2.0 * _card_min() - 2.0 * GAP) / aspect), 120.0)
	var fw := fh * aspect
	var cw := clampf((w - fw) / 2.0 - GAP, _card_min(), CARD_MAX)
	_fig = Rect2(Vector2((w - fw) / 2.0, (h - fh) / 2.0), Vector2(fw, fh))
	var lx := maxf(0.0, _fig.position.x - GAP - cw)
	var rx := minf(w - cw, _fig.end.x + GAP)
	_art.position = Vector2.ZERO
	_art.size = size
	_art.place(_fig, Rect2(Vector2(lx + cw, 0), Vector2(rx - lx - cw, h)))
	for loc in Cyber.LOCS:
		anchors[loc] = _art.anchor(loc)
	_column(LEFT_COL, lx, cw, h)
	_column(RIGHT_COL, rx, cw, h)
	_over.size = size
	_over.queue_redraw()


func _card_min() -> float:
	return 136.0 if compact else CARD_MIN


## Stack a column's cards in their anchors' top-to-bottom order, each as near its anchor's height
## as it fits.
func _column(col: Array[String], x: float, cw: float, h: float) -> void:
	var locs := col.duplicate()
	locs.sort_custom(func(a: String, b: String) -> bool: return _anchor(a).y < _anchor(b).y)
	var ys: Array[float] = []
	var hs: Array[float] = []
	for loc in locs:
		var card: Control = cards[loc]
		card.size = Vector2(cw, 0)
		var ch := card.get_combined_minimum_size().y
		hs.append(ch)
		ys.append(_anchor(loc).y - ch / 2.0)
	var gap := 3.0 if compact else 5.0
	for i in ys.size():   # down: no overlaps
		ys[i] = maxf(ys[i], 0.0 if i == 0 else ys[i - 1] + hs[i - 1] + gap)
	for i in range(ys.size() - 1, -1, -1):   # up: inside the bottom edge
		ys[i] = minf(ys[i], h - hs[i] if i == ys.size() - 1 else ys[i + 1] - hs[i] - gap)
	for i in locs.size():
		var card: Control = cards[locs[i]]
		card.position = Vector2(x, maxf(0.0, ys[i]))
		card.size = Vector2(cw, hs[i])



## A location's anchor in this control (the figure's centre before the first layout).
func _anchor(loc: String) -> Vector2:
	return anchors.get(loc, _fig.get_center())


# --- Drawing ----------------------------------------------------------------------------------

## The colour of a location's mark and line: gold selected, violet with anything installed, else
## a dim cyan.
func _loc_col(loc: String) -> Color:
	if loc == sel_loc:
		return Hud.GOLD
	return CHROME if chromed(c.implants, loc) else Color(Hud.CYAN, 0.45)


## Over the figure: each card's leader line and its mark on the body (a chromed place is a lit
## node, as the book's art studs chrome with lights; the chest's internal chrome a core).
func _draw_over(o: Control) -> void:
	if c == null:
		return
	for loc: String in cards:
		var card: Control = cards[loc]
		var a := _anchor(loc)
		var left := loc in LEFT_COL
		var r := card.get_rect()
		var edge := Vector2(r.end.x if left else r.position.x, r.position.y + minf(10.0, r.size.y / 2.0))
		var elbow := Vector2(edge.x + (12.0 if left else -12.0), edge.y)
		var on := loc == sel_loc
		var col := _loc_col(loc)
		var lc := col if on else Color(col, 0.6 if chromed(c.implants, loc) else 0.4)
		o.draw_polyline(PackedVector2Array([edge, elbow, a]), lc, 1.6 if on else 1.0, true)
	for loc: String in cards:
		var a := _anchor(loc)
		var on := loc == sel_loc
		var chrome := chromed(c.implants, loc)
		var col := _loc_col(loc)
		if loc == "internal":   # the core: a hexagon in the chest
			var hx := PackedVector2Array()
			for i in 7:
				hx.append(a + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * (7.0 if on else 6.0))
			if chrome or on:
				o.draw_polyline(hx, Color(col, 0.25), 5.0, true)
			o.draw_polyline(hx, col if chrome or on else Color(Hud.CYAN, 0.35), 1.3, true)
			continue
		if on or chrome:   # a lit node: halo, ring, core
			o.draw_circle(a, 7.0 if on else 5.5, Color(col, 0.16))
			o.draw_arc(a, 4.5 if on else 3.5, 0, TAU, 16, col, 1.2, true)
			o.draw_circle(a, 2.0, Color(1, 1, 1, 0.9).lerp(col, 0.35))
		else:
			o.draw_circle(a, 1.8, col)


## The leader lines' layer.
class Overlay extends Control:
	var body: ChromeBody

	func _draw() -> void:
		if body:
			body._draw_over(self)
