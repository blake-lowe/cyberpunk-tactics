class_name CityTab
extends HBoxContainer
## The Fixer Network's CITY tab (M9 P3): the CityMap and a side panel. The panel follows the
## mouse: a district's file (who runs it, its Security and Utility Codes, the gangs there, its NCART
## stations, the known locations by type, the jobs on offer there), a job pin's offer, or with
## nothing under the mouse the city overview (the offers and the map key). Clicking a district
## keeps the panel on it; clicking a pin (or an offer in the panel) opens that job in JOBS.

signal open_job(index: int)

const PANEL_W := 318

var camp: Campaign
var map: CityMap
var _panel: PanelContainer
var _shown := "~"


func setup(p_camp: Campaign) -> CityTab:
	camp = p_camp
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = CityMap.LAND
	box.border_color = Color(Hud.CYAN, 0.25)
	box.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", box)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(frame)
	map = CityMap.new().setup(camp)
	map.custom_minimum_size = Vector2(320, 240)
	frame.add_child(map)
	map.hovered.connect(func(_k, _i): _refresh())
	map.clicked.connect(_on_click)
	if camp.has_meta("demo"):   # DEV: --district=<id> keeps the panel on a district for review shots
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--district="):
				map.locked = a.get_slice("=", 1)
			if a.begins_with("--pin="):
				map.hover_kind = "pin"
				map.hover_id = a.get_slice("=", 1)
	_panel = UiKit.panel(Hud.CYAN, 12)
	_panel.custom_minimum_size.x = PANEL_W
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_panel)
	_refresh()
	return self


func _on_click(kind: String, id: String) -> void:
	if kind == "pin":
		open_job.emit(int(id))
	_refresh()


## What the panel shows: "pin:<i>", a district id, or "" (overview).
func showing() -> String:
	if map.hover_kind == "pin":
		return "pin:" + map.hover_id
	return map.focus()


func _refresh() -> void:
	var what := showing()
	if what == _shown:
		return
	_shown = what
	for c in _panel.get_children():
		c.queue_free()
	var v := UiKit.vbox(8)
	if what.begins_with("pin:"):
		_job(v, int(what.trim_prefix("pin:")))
	elif what != "":
		_district(v, what)
	else:
		_overview(v)
	var pad := MarginContainer.new()   # clear of the scroll bar
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_child(v)
	_panel.add_child(UiKit.scroller(pad))


# --- Panel contents -------------------------------------------------------------------------

func _overview(v: VBoxContainer) -> void:
	v.add_child(UiKit.head("NIGHT CITY", 32, Hud.TEXT))
	v.add_child(UiKit.body("Hover a district for its file; click to keep it here. Gold pins are the fixers' offers: click one to open the job.", 13, Hud.DIM))
	v.add_child(SafehouseScreen.section("JOB OFFERS"))
	if camp.board.is_empty():
		v.add_child(SafehouseScreen.none("No offers today."))
	for i in camp.board.size():
		v.add_child(_offer_row(i))
	v.add_child(SafehouseScreen.section("NCART"))
	var f := UiKit.flow(10)
	for k in CityMap.LINES:
		f.add_child(_swatch(Color(String(CityMap.LINES[k][1])), String(CityMap.LINES[k][0])))
	v.add_child(f)
	v.add_child(UiKit.body("Security Code (NC2045 p.7): the chance someone answers trouble, and who. At 2 help rarely comes; at 10 it nearly always does, and fast. H- means Hardened responders; LGT, MED, HVY how many. Utility Code (p.8): the chance each of power, water and CitiNet is out.", 13, Hud.DIM))


func _district(v: VBoxContainer, id: String) -> void:
	var d := World.district(id)
	var c: Dictionary = d.get("security_code", {})
	var n := int(c.get("n", 0))
	var col := CityMap.code_colour(n) if id != "outskirts" else Hud.DIM
	var head := UiKit.head(String(d.get("name", id)), 32, Hud.TEXT)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 100
	v.add_child(head)
	var m: Variant = d.get("manager")
	var who := ""
	if m is Dictionary and String(m.get("name", "")) != "":
		who = String(m.name) + ((" (%s)" % String(m.role)) if String(m.get("role", "")) != "" else "")
	v.add_child(UiKit.label("%s · %s" % [String(d.get("region", "")), ("Manager " + who) if who != "" else "No manager"], 13, Hud.CYAN))
	# the codes, big, one above the other so their lines don't wrap; each says what its number means
	var codes := UiKit.vbox(6)
	v.add_child(codes)
	codes.add_child(_code_box("SECURITY · RESPONDS %d%%" % SecurityCode.chance(n), n, col, "%s · %s%s" % [CityMap.short_faction(String(c.get("faction", ""))),
		"Hardened " if bool(c.get("hardened", false)) else "", String(c.get("intensity", "")).capitalize()]))
	var u: Variant = d.get("utility_code")
	var un := int(u) if (u is int or u is float) else -1
	codes.add_child(_code_box("UTILITY", un, CityMap.code_colour(un) if un >= 0 else Hud.DIM, utility_text(un)))
	if String(d.get("population", "")) != "":
		v.add_child(UiKit.body(String(d.population).left(1).to_upper() + String(d.population).substr(1) + ".", 13, Color(Hud.TEXT, 0.8)))
	var gangs: Array = d.get("gangs", [])
	if not gangs.is_empty():
		v.add_child(SafehouseScreen.section("GANGS"))
		var f := UiKit.flow(6)
		for g in gangs:
			f.add_child(_faction_chip(String(g)))
		v.add_child(f)
	var st: Array = d.get("ncart", [])
	var lines := lines_through(id)
	if not st.is_empty() or not lines.is_empty():
		v.add_child(SafehouseScreen.section("NCART"))
		var lf := UiKit.flow(10)
		for k in lines:
			lf.add_child(_swatch(Color(String(CityMap.LINES[k][1])), String(CityMap.LINES[k][0])))
		v.add_child(lf)
		var only := lines.filter(func(k): return k != "exec_monorail")
		for s in st:
			v.add_child(_station(String(s), String(only[0]) if only.size() == 1 else ""))
	var counts := location_counts(id)
	var total := 0
	for k in counts:
		total += int(counts[k])
	if total > 0:
		v.add_child(SafehouseScreen.section("%d KNOWN LOCATIONS" % total))
		var keys: Array = counts.keys()
		keys.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]) or (int(counts[a]) == int(counts[b]) and String(a) < String(b)))
		var f := UiKit.flow(6)
		for k in keys:
			f.add_child(UiKit.chip("%s %d" % [String(k).replace("_", " "), int(counts[k])], Hud.CYAN))
		v.add_child(f)
	var jobs: Array = []
	for i in camp.board.size():
		if String(camp.board[i].get("district", "")) == id:
			jobs.append(i)
	if not jobs.is_empty():
		v.add_child(SafehouseScreen.section("JOBS HERE", Hud.GOLD))
		for i in jobs:
			v.add_child(_offer_row(int(i)))
	if String(d.get("history", "")) != "":
		v.add_child(UiKit.body(String(d.history), 13, Hud.DIM))


func _job(v: VBoxContainer, i: int) -> void:
	if i < 0 or i >= camp.board.size():
		return
	var g: Dictionary = camp.board[i]
	v.add_child(UiKit.label("JOB OFFER %d" % (i + 1), 13, Hud.GOLD))
	if Campaign.is_operation(g):   # owner: a gig that chains maps reads as one before it's taken
		var tag := UiKit.hbox(8)
		tag.add_child(UiKit.chip(FixerScreen.op_tag(g), Hud.GOLD))
		v.add_child(tag)
	var t := UiKit.head(String(g.title), 28, Hud.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 100
	v.add_child(t)
	v.add_child(UiKit.label("%s · %s" % [String(g.fixer), Campaign.place_name(g)], 13, Hud.CYAN))
	var did := String(g.get("district", ""))
	if did != "":
		v.add_child(UiKit.label(String(World.district(did).get("name", did)), 13, Hud.DIM))
	v.add_child(code_block(g, 15, 12))
	v.add_child(UiKit.body(String(g.get("blurb", "")), 14))
	if Campaign.is_operation(g):   # each map's land in order, and what carries between them
		var legs: Array = g.legs
		for k in legs.size():
			v.add_child(UiKit.body("%d. %s" % [k + 1, String(legs[k].get("leg_title", ""))], 13, Hud.TEXT))
		v.add_child(UiKit.body(FixerScreen.CARRY_LINE, 13, Hud.GOLD))
	var obj := String(FixerScreen.OBJECTIVE_TEXT.get(Campaign.objective_for(g), ""))
	if obj != "" and not Campaign.is_operation(g):
		v.add_child(UiKit.body("★ " + obj, 14, Hud.TEXT))
	v.add_child(UiKit.label("PAY  %s eb" % UiKit.money(int(g.get("pay", 0))), 18, Hud.TEXT))
	v.add_child(UiKit.label("CLICK THE PIN TO OPEN IT IN JOBS", 12, Hud.DIM))


## Known locations in a district, counted by type (data/world/locations.json).
static func location_counts(id: String) -> Dictionary:
	var out := {}
	for lid in World.locations():
		var l: Dictionary = World.locations()[lid]
		if String(l.get("district", "")) == id:
			var t := String(l.get("type", "other"))
			out[t] = int(out.get(t, 0)) + 1
	return out


## What a Utility Code means (NC2045 p.8: 1d10 per utility, under the code it's out): "Power, water,
## CitiNet: each out 50% of the time". -1 for the book's "Variable" (the Outskirts).
static func utility_text(n: int) -> String:
	if n < 0:
		return "Power, water, CitiNet: varies place to place"
	return "Power, water, CitiNet: each out %d%% of the time" % SecurityCode.chance(n)


## A gig's Security Code in two lines, coloured like the map: "SECURITY 4" over
## "GOLD DRAGONS · HARDENED LIGHT" (the site's own people when the code names nobody).
static func code_block(gig: Dictionary, big: int, small: int) -> Control:
	var c := SecurityCode.normalise(gig.get("security_code"))
	if c.is_empty():
		c = SecurityCode.from_level(int(gig.get("security", 1)), String(gig.get("faction", "")))
	var who := String(c.faction) if String(c.faction) != "" else String(gig.get("faction", ""))
	var col := CityMap.code_colour(int(c.n))
	var v := UiKit.vbox(0)
	v.add_child(UiKit.label("SECURITY %d" % int(c.n), big, col))
	var how := ("HARDENED " if bool(c.hardened) else "") + String(c.intensity).to_upper()
	v.add_child(UiKit.label("%s · %s" % [CityMap.short_faction(who), how] if who != "" else how, small, col.lightened(0.25)))
	return v


func _code_box(name: String, n: int, col: Color, sub: String) -> Control:
	var p := PanelContainer.new()
	var s := CutBox.make(Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.95), Color(col, 0.6), 6, 0b0101, Color(0, 0, 0, 0), 6)
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UiKit.hbox(8)
	p.add_child(h)
	var big := UiKit.head(str(n) if n >= 0 else "–", 40, col)
	big.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(big)
	var t := UiKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	t.add_child(UiKit.label(name, 11, Hud.DIM))
	var sl := UiKit.body(sub, 12, Hud.TEXT)
	t.add_child(sl)
	return p


## A gang as a chip: its jacket colour as a swatch edged in its accent, then its name.
func _faction_chip(id: String) -> Control:
	var look := World.look(id)
	var jacket := Color(String(look.get("jacket", "3a3a3a")))
	var accent := Color(String(look.get("accent", "ff3030")))
	var h := UiKit.hbox(5)
	var sw := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = jacket
	sb.border_color = accent
	sb.set_border_width_all(2)
	sw.add_theme_stylebox_override("panel", sb)
	sw.custom_minimum_size = Vector2(12, 12)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	h.add_child(UiKit.label(SecurityCode.faction_name(id), 12, Hud.TEXT))
	return h


func _swatch(col: Color, text: String) -> Control:
	var h := UiKit.hbox(5)
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(14, 3)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)
	h.add_child(UiKit.label(text, 11, Hud.DIM))
	return h


## The NCART lines (city.json map.ncart keys) with a stop in the district, in data order.
static func lines_through(id: String) -> Array:
	var out := []
	var nc: Dictionary = CityMap.city_map().get("ncart", {})
	for k in nc:
		if id in (nc[k] as Array) and CityMap.LINES.has(k):
			out.append(String(k))
	return out


## "Charter Hill Station (Green Line)" → a dot in the line's colour (or `fallback`'s, when the name
## doesn't say) and the station's name.
func _station(s: String, fallback := "") -> Control:
	var line := ""
	var m := RegEx.create_from_string("\\(([^)]*)\\)").search(s)
	if m:
		line = m.get_string(1).to_lower()
	var key := "exec_monorail" if "monorail" in line else line.get_slice(" ", 0)
	if not CityMap.LINES.has(key):
		key = fallback
	var col := Color(String(CityMap.LINES.get(key, ["", "8796a4"])[1]))
	var h := UiKit.hbox(6)
	var dot := ColorRect.new()
	dot.color = col
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	h.add_child(UiKit.body(s, 13, Hud.TEXT))
	return h


## An offer as a clickable row: its pin number, title, district and pay.
func _offer_row(i: int) -> Control:
	var g: Dictionary = camp.board[i]
	var p := UiKit.panel(Hud.GOLD, 6)
	var h := UiKit.hbox(8)
	p.add_child(h)
	var num := UiKit.label(str(i + 1), 15, Hud.GOLD)
	num.custom_minimum_size.x = 14
	num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(num)
	var t := UiKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	t.add_child(UiKit.body(String(g.title), 13, Hud.TEXT))
	var did := String(g.get("district", ""))
	var sub := "%s · %s eb" % [String(World.district(did).get("name", "Night City")) if did != "" else "Night City", UiKit.money(int(g.get("pay", 0)))]
	if Campaign.is_operation(g):
		sub = FixerScreen.op_tag(g) + " · " + sub
	t.add_child(UiKit.label(sub, 11, Hud.GOLD if Campaign.is_operation(g) else Hud.DIM))
	UiKit.clickable(p, func(): open_job.emit(i))
	return p
