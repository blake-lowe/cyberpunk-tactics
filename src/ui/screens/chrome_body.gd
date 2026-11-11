class_name ChromeBody
extends Control
## The cyberware body: a figure of the crew member's body with a callout card per location. Every
## shown location (LOCS) has a card joined by a leader line to its place on the body. A card is headed
## by the book's cyberware category (CPR core p.110: Neuralware, Cyberoptics, Cyberaudio, Internal and
## External Cyberware, Cyberlimbs, Fashionware; Chipware for the sockets' chips, p.359), with the side
## for an eye, arm or leg; then its Option Slots as pips (filled, empty or locked: no foundation yet),
## its foundation (greyed "not installed" without one) and the pieces in it. Every installed piece is
## named and filled, its effect played yet or not (owner, 2026-11-11). Chromed regions are violet,
## meat cyan, the selected location gold, external chrome a skin over the body.
## The cards stand in pair rows (ROWS, owner, playtest): the two eyes side by side, the two arms, the
## two legs, the Neural Link beside the Cyberaudio Suite, the Chipware beside the Fashionware, the
## External beside the Internal Cyberware. Borgware has no card while it is descoped (Cyber.SHOWN_LOCS).
## The figure is a real anatomical plate as light on the dark page (BodyAnatomy; owner, 2026-11-11:
## "Let's take that going forward and drop the ... other attempts"): a man (Milton's écorché, 1804)
## or a woman (Bell's superficial figure, 1798), as the crew member's body is (plate_of: the body
## their 3D model has), always as the skeleton hybrid (the bones through a faint body: owner,
## 2026-11-11, "drop the skin on versions"). Its glitch grows as their Humanity falls (glitch_of).
## The Med Bay's ripperdoc picks a location or an installed piece here (loc_pressed, piece_pressed;
## a click on the body picks the nearest place); the loadout screen shows it read-only (clicks only
## select). Built from Controls, so tests can read `cards` and each card's `pips` meta. header() is the
## name, EMP and Humanity bar both screens put over it.

signal loc_pressed(loc: String)
signal piece_pressed(loc: String, id: String)

## The locations shown, in the order ↑/↓ steps through them.
const LOCS: Array[String] = Cyber.SHOWN_LOCS
## The card rows, top to bottom: [the viewer's left column, the right]. Each row's two cards share a
## height; the anchors (BodyAnatomy.PLATES) run top to bottom in each column, so no leader lines cross.
const ROWS := [["neural_link", "cyberaudio"], ["right_eye", "left_eye"], ["chipware", "fashion"],
	["external", "internal"], ["right_arm", "left_arm"], ["right_leg", "left_leg"]]
const LEFT_COL: Array[String] = ["neural_link", "right_eye", "chipware", "external", "right_arm", "right_leg"]
const RIGHT_COL: Array[String] = ["cyberaudio", "left_eye", "fashion", "internal", "left_arm", "left_leg"]
## Each card's heading: the book's cyberware category (CPR core p.110-116; Chipware p.359).
const CATEGORY := {"neural_link": "Neuralware", "chipware": "Chipware", "right_eye": "Cyberoptics", "left_eye": "Cyberoptics",
	"cyberaudio": "Cyberaudio", "right_arm": "Cyberlimbs", "left_arm": "Cyberlimbs", "right_leg": "Cyberlimbs",
	"left_leg": "Cyberlimbs", "internal": "Internal Cyberware", "external": "External Cyberware", "fashion": "Fashionware"}
## The side, beside the heading, for the paired places.
const SIDE := {"right_eye": "right eye", "left_eye": "left eye", "right_arm": "right arm", "left_arm": "left arm",
	"right_leg": "right leg", "left_leg": "left leg"}
## The foundational cyberware a location's options go in (CPR core p.111: listed first, with its Option
## Slots); the Chipware's sockets (p.359). The open categories have none.
const FOUNDATION := {"neural_link": "neural_link", "chipware": "chipware_socket", "right_eye": "cybereye", "left_eye": "cybereye",
	"cyberaudio": "cyberaudio_suite", "right_arm": "cyberarm", "left_arm": "cyberarm", "right_leg": "cyberleg", "left_leg": "cyberleg"}
## Option Slots a location would hold once its foundation is in (shown as locked pips until then).
const LOCKED_SLOTS := {"neural_link": 5, "chipware": 1, "right_eye": 3, "left_eye": 3, "cyberaudio": 3}
const LIMBS: Array[String] = ["right_arm", "left_arm", "right_leg", "left_leg"]

const CHROME := Color("c77dff")       ## Hud.VIOLET lightened: chrome
const GAP := 26.0                      ## between a card column and the figure
const CARD_MIN := 150.0
const CARD_MAX := 232.0

## Body regions the figure tints (BodyAnatomy's bones); L_FORE is the left forearm and hand (tinted as
## the left arm).
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
	_art.psycho = glitch_of(c)
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


## How hard the figure glitches, 0 to 1, from the Humanity they have left (owner, playtest: full
## Humanity "some minor fuzz and glitch", low Humanity "crazy cyberpsycho effects"). It ramps smoothly
## with Humanity / max Humanity (gentle near full, steepest midway), and never reads calm in the
## cyberpsychosis range: Humanity 42 down to 22 ramps it to the full on its own (the risk starts at
## EMP 2, Humanity under 30: Combatant.psychosis_tier), so a crew member at risk always looks
## unsettling, and a full but low-EMP one already a little. 0 for anyone without Humanity.
static func glitch_of(p_c: Combatant) -> float:
	if p_c == null or not p_c.tracks_humanity or p_c.max_humanity <= 0:
		return 0.0
	var lost := 1.0 - clampf(float(p_c.humanity) / float(p_c.max_humanity), 0.0, 1.0)
	var ramp := lost * lost * (3.0 - 2.0 * lost)
	var t := clampf((42.0 - float(p_c.humanity)) / 20.0, 0.0, 1.0)
	return clampf(maxf(ramp, t * t * (3.0 - 2.0 * t)), 0.0, 1.0)


## Humanity's colour: green, gold at the edge of cyberpsychosis, red in it (Combatant.psychosis_tier).
static func hum_colour(p_c: Combatant) -> Color:
	return [Hud.GREEN, Hud.GOLD, Hud.RED, Hud.RED][clampi(p_c.psychosis_tier(), 0, 3)]


## The line over the figure on both screens (owner, playtest): the name, then EMP, then Humanity as a
## bar (current of max). Anyone without Humanity gets no bar.
static func header(p_c: Combatant, name_col := Hud.TEXT) -> HBoxContainer:
	var h := UiKit.hbox(18)
	h.name = "Header"
	var nm := UiKit.head(p_c.display_name, 30, name_col)
	nm.name = "Name"
	h.add_child(nm)
	var emp := _stat("EMP", str(p_c.raw_stat("EMP")), Hud.TEXT)
	emp.name = "EMP"
	h.add_child(emp)
	if p_c.tracks_humanity:
		var col := hum_colour(p_c)
		var v := UiKit.vbox(2)
		v.name = "Humanity"
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.custom_minimum_size.x = 190
		v.set_meta("value", p_c.humanity)
		v.set_meta("max", p_c.max_humanity)
		var t := UiKit.hbox(6)
		v.add_child(t)
		t.add_child(UiKit.label("HUMANITY", 12, Hud.DIM))
		t.add_child(UiKit.spacer())
		var n := UiKit.label("%d/%d" % [p_c.humanity, p_c.max_humanity], 15, col)
		n.name = "Value"
		t.add_child(n)
		var bar := Bar.new()
		bar.name = "Bar"
		bar.value = p_c.humanity
		bar.top = maxi(1, p_c.max_humanity)
		bar.col = col
		v.add_child(bar)
		h.add_child(v)
	return h


static func _stat(label: String, value: String, col: Color) -> VBoxContainer:
	var v := UiKit.vbox(-4)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UiKit.label(label, 12, Hud.DIM))
	var l := UiKit.label(value, 19, col)
	l.name = "Value"
	v.add_child(l)
	return v


## The Humanity bar: the track, the fill to current of max, a tick every 10 (each point of EMP).
class Bar extends Control:
	var value := 0
	var top := 1
	var col := Hud.GREEN

	func _init() -> void:
		custom_minimum_size = Vector2(150, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.03, 0.045, 0.06, 0.95))
		var f := clampf(float(value) / float(maxi(1, top)), 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), Color(col, 0.85))
		var k := 10
		while k < top:
			var x := r.size.x * float(k) / float(top)
			draw_line(Vector2(x, 0), Vector2(x, r.size.y), Color(0, 0, 0, 0.7), 1.0)
			k += 10
		draw_rect(r, Color(col, 0.5), false, 1.0)


## Every region's tint: [colour (a = how much; 0 = meat), plated]. The ear is the Cyberaudio
## Suite's; the left forearm and hand are the left arm's.
func region_tints() -> Array:
	var out: Array = []
	for r in REGIONS:
		out.append(_tint(r))
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
## Borgware (not shown): none.
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


## Everything at a location in a line: the foundation (or Meat / Empty) and the pieces in it,
## "Cybereye · Targeting Scope". A meat limb's Standard Hand/Foot isn't listed (it doesn't count
## there, Cyber.meat_pieces).
static func line(implants: Array, loc: String) -> String:
	var parts: Array[String] = []
	var f := Cyber.foundation_at(implants, loc)
	if f != "":
		parts.append(Cyber.display(f))
	elif loc in LIMBS or loc in Cyber.EYES:
		parts.append("Meat")
	var opts := options_line(implants, loc)
	if opts != "" and opts != "Empty":
		parts.append(opts)
	if parts.is_empty():
		parts.append("Empty")
	return " · ".join(parts)


## The card's foundation line: [text, installed]. "Neural Link", "Cybereye", "Chipware Socket ×2";
## without one its name, "not installed" (greyed on the card). "" for the open categories.
static func foundation_line(implants: Array, loc: String) -> Array:
	if not FOUNDATION.has(loc):
		return ["", false]
	var id: String = FOUNDATION[loc]
	var nm := Cyber.display(id)
	if loc == "chipware":
		var n := Cyber.count(implants, id)
		return ["%s ×%d" % [nm, n] if n > 1 else nm, true] if n > 0 else [nm + " · not installed", false]
	var f := Cyber.foundation_at(implants, loc)
	return [Cyber.display(f), true] if f != "" else [nm + " · not installed", false]


## The card's pieces line: what's in the location but the foundation ("Targeting Scope · Anti-Dazzle";
## a meat limb's one piece). "Empty" for an open category with nothing, "" otherwise.
static func options_line(implants: Array, loc: String) -> String:
	var f := Cyber.foundation_at(implants, loc)
	var ps := Cyber.meat_pieces(implants, loc) if Cyber.is_meat(implants, loc) else Cyber.pieces_at(implants, loc)
	var parts: Array[String] = []
	for p in ps:
		if String(p.id) != f:
			parts.append(Cyber.display(String(p.id)))
	if parts.is_empty():
		return "" if FOUNDATION.has(loc) else "Empty"
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
	var head := UiKit.fit(UiKit.label(String(CATEGORY.get(loc, Cyber.loc_name(loc))), 11 if compact else 12, Hud.GOLD if on else (CHROME if chrome else Hud.CYAN)))
	head.name = "Heading"
	top.add_child(head)
	var n := int(hints.get(loc, 0))
	if n > 0:   # the Med Bay: pieces in storage that can go in here now
		var h := UiKit.label("+%d" % n, 12, Hud.GREEN)
		h.name = "Hint"
		top.add_child(h)
	var ps := pips(c.implants, loc)
	p.set_meta("pips", ps)
	var row := UiKit.hbox(3)   # the pips, and at the right which eye, arm or leg
	v.add_child(row)
	if not ps.is_empty():
		var pips_row := UiKit.hbox(3)
		pips_row.name = "Pips"
		pips_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pips_row)
		for pp in ps:
			var pip := Pip.new()
			pip.state = String(pp.state)
			if compact:
				pip.custom_minimum_size = Vector2(9, 9)
			pip.on = String(pp.id) != "" and String(pp.id) == sel_id and on
			pips_row.add_child(pip)
	if SIDE.has(loc):
		row.add_child(UiKit.spacer())
		var sd := UiKit.label(String(SIDE[loc]), 10 if compact else 11, Hud.DIM)
		sd.name = "Side"
		row.add_child(sd)
	var fl := foundation_line(c.implants, loc)
	if String(fl[0]) != "":   # on a narrow card "not installed" goes on a line of its own (_fit_foundation)
		var fnd := UiKit.fit(UiKit.body(String(fl[0]), 12 if compact else 13, Hud.TEXT if fl[1] else Color(Hud.DIM, 0.6), false))
		fnd.name = "Foundation"
		fnd.set_meta("installed", bool(fl[1]))
		fnd.set_meta("line", String(fl[0]))
		v.add_child(fnd)
	var txt := options_line(c.implants, loc)
	if txt != "":
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
	if r == Reg.TORSO:   # the trunk: the chest's internal chrome
		return [Color(Hud.GOLD, 0.5), 0.0] if sel_loc == "internal" else [Color(0, 0, 0, 0), 0.0]
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
	for loc in LOCS:
		anchors[loc] = _art.anchor(loc)
	_rows(lx, rx, cw, h)
	_over.size = size
	_over.queue_redraw()


func _card_min() -> float:
	return 136.0 if compact else CARD_MIN


## Stand the pair rows top to bottom: each row's two cards at one height (the taller's) and one y, as
## near its anchors' mean height as it fits; no row overlaps the next, the last inside the bottom edge.
func _rows(lx: float, rx: float, cw: float, h: float) -> void:
	var ys: Array[float] = []
	var hs: Array[float] = []
	for row in ROWS:
		var rh := 0.0
		var ay := 0.0
		for loc: String in row:
			var card: Control = cards[loc]
			_fit_foundation(card, cw)
			card.size = Vector2(cw, 0)
			rh = maxf(rh, card.get_combined_minimum_size().y)
			ay += _anchor(loc).y / float(row.size())
		hs.append(rh)
		ys.append(ay - rh / 2.0)
	var gap := 3.0 if compact else 5.0
	for i in ys.size():   # down: no overlaps
		ys[i] = maxf(ys[i], 0.0 if i == 0 else ys[i - 1] + hs[i - 1] + gap)
	for i in range(ys.size() - 1, -1, -1):   # up: inside the bottom edge
		ys[i] = minf(ys[i], h - hs[i] if i == ys.size() - 1 else ys[i + 1] - hs[i] - gap)
	for i in ROWS.size():
		for k in 2:
			var card: Control = cards[ROWS[i][k]]
			card.position = Vector2(lx if k == 0 else rx, maxf(0.0, ys[i]))
			card.size = Vector2(cw, hs[i])


## A card's foundation line on one line if it fits the card's width, else broken at its " · "
## ("Cyberaudio Suite" over "not installed"), never cut off.
func _fit_foundation(card: Control, cw: float) -> void:
	var l := card.find_child("Foundation", true, false) as Label
	if l == null:
		return
	var full := String(l.get_meta("line", l.text))
	var font := l.get_theme_font("font")
	var w := font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x if font else 0.0
	var pad := card.get_theme_stylebox("panel").get_minimum_size().x + 4.0
	l.text = full.replace(" · ", "\n") if w > cw - pad else full


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
