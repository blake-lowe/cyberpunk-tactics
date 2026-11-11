class_name MedBayScreen
extends SafehouseScreen
## The Med Bay: the RIPPERDOC (cyberware bought at a Night Market waits in storage; installing it
## costs nothing more, CPR core p338, the price includes the surgery, p110; Humanity Loss on install;
## installed chrome can be removed, which destroys it, never moved to someone else), THERAPY
## (Addiction and Humanity Loss Therapy by a Medtech, p229-230) and Treatment for Critical
## Injuries (p223). The crew cards here show each member's last-gig health marks.

var _confirm := ""   ## the installed piece ("id@loc") whose REMOVE waits for DESTROY IT
var loc := ""        ## the ripperdoc's selected body location (Cyber.LOCS)
var _pick := ""      ## the picked action there: "remove:<id>" or "install:<id>" (gold; Enter acts on it)
var _choose := ""    ## a storage piece whose install waits for its option (_install_choices)
var _actions: Array[String] = []   ## the selected location's actions in panel order (←/→)


func setup(p_camp: Campaign, p_portraits: Portraits, p_tab := "", p_sel := 0) -> SafehouseScreen:
	super.setup(p_camp, p_portraits, p_tab, p_sel)
	if p_camp.has_meta("demo"):   # DEV ONLY review shots: --loc=right_eye --pick=remove:cybereye --confirm=1
		for a in OS.get_cmdline_user_args():
			var k := a.trim_prefix("--").get_slice("=", 0)
			var val := a.get_slice("=", 1)
			match k:
				"loc": loc = val
				"pick": _pick = val
				"confirm": _confirm = "%s@%s" % [_pick.get_slice(":", 1), loc] if _pick.begins_with("remove:") else ""
	return self


func room_name() -> String:
	return "MED BAY"


func title() -> String:
	return {"ripperdoc": "Ripperdoc", "therapy": "Therapy", "injuries": "Critical Injuries"}.get(tab, "Med Bay")


func tabs() -> Array:
	return [["ripperdoc", "RIPPERDOC"], ["therapy", "THERAPY"], ["injuries", "CRITICAL INJURIES"]]


func build_body(body: VBoxContainer) -> void:
	if camp.alive_crew().is_empty():
		body.add_child(none("Nobody on the crew."))
		return
	match tab:
		"ripperdoc": _ripperdoc(body)
		"therapy": _therapy(body)
		"injuries": _injuries(body)


func _humanity_line(c: Combatant) -> String:
	return "HUMANITY %d/%d · EMP %d" % [c.humanity, c.max_humanity, c.raw_stat("EMP")] if c.tracks_humanity else ""


# --- Ripperdoc --------------------------------------------------------------------------------

## The crew cards' chips here: each member's conditions now (Critical Injuries, addictions) and
## the last gig's health marks (a Humanity loss), not IP or Reputation.
func _health_marks(m: Combatant) -> Array:
	var out: Array = camp.marks_for(m).filter(func(x): return not (x.begins_with("+") or x.begins_with("REPUTATION")))
	for inj in m.injuries:
		var nm := String(inj.get("name", "injury"))
		if not nm in out:
			out.append(nm)
	for d in m.addictions:
		var a := "ADDICTED: %s" % String(RulesDB.gear("drugs", d).get("name", d))
		if not a in out:
			out.append(a)
	return out


func _ripperdoc(body: VBoxContainer) -> void:
	var cols := UiKit.hbox(10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var vs := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var wide := vs.x >= 1500.0
	var narrow := vs.x < 1200.0   # 1600x900 is ~1066x600 logical
	cols.add_child(crew_picker(_humanity_line, 270 if wide else (196 if narrow else 230), _health_marks))
	var c := selected()
	_settle(c)
	# the silhouette: name and Humanity on top, the body with its slots below
	var mid := UiKit.panel(Hud.VIOLET, 10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var mv := UiKit.vbox(2)
	mid.add_child(mv)
	var hl := UiKit.hbox(14)
	mv.add_child(hl)
	hl.add_child(UiKit.fit(UiKit.head(c.display_name, 30, Hud.TEXT)))
	if c.tracks_humanity:
		var hu := UiKit.label(_humanity_line(c), 15, _hum_colour(c))
		hu.name = "Humanity"
		hu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hl.add_child(hu)
	var fig := ChromeBody.new().setup(c, loc, _piece(), _hints(c), vs.y < 700.0)
	fig.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fig.loc_pressed.connect(_select_loc)
	fig.piece_pressed.connect(func(l: String, id: String): loc = l; _pick = "remove:" + id; _confirm = ""; _choose = ""; _build())
	mv.add_child(fig)
	if not narrow:   # at 1600x900 the buttons carry it (as in the Armory)
		mv.add_child(UiKit.label("↑↓ PLACE · ←→ CHOICE · ENTER INSTALL · DEL REMOVE · Q/E CREW", 11, Hud.DIM))
	cols.add_child(_slot_panel(c, 400 if wide else (290 if narrow else 340)))


## Keep the selection valid: a location (the first where something in storage fits now, else the
## first with chrome in it), and a picked action in its panel (the first, if none).
func _settle(c: Combatant) -> void:
	if not loc in Cyber.LOCS:
		var h := _hints(c)
		loc = ""
		for l in Cyber.LOCS:
			if int(h.get(l, 0)) > 0:
				loc = l
				break
		if loc == "":
			for l in Cyber.LOCS:
				if not Cyber.pieces_at(c.implants, l).is_empty():
					loc = l
					break
		if loc == "":
			loc = "neural_link"
	_actions = _actions_for(c)
	if not _pick in _actions:
		_pick = _actions[0] if not _actions.is_empty() else ""
	if _confirm != "" and _pick != "remove:" + _confirm.get_slice("@", 0):
		_confirm = ""


## The installed piece picked at `loc` ("" if the pick is a storage piece).
func _piece() -> String:
	return _pick.trim_prefix("remove:") if _pick.begins_with("remove:") else ""


## Storage pieces that can go in each location now: loc → count (the cards' "+N").
func _hints(c: Combatant) -> Dictionary:
	var out := {}
	for k in camp.cyberware_options():
		var id := Items.base_id(k)
		for l in Cyber.free_locs(c.implants, id):
			if camp.install_block(c, id, l) == "":
				out[l] = int(out.get(l, 0)) + 1
	return out


## The selected location's actions in panel order (keyboard ←/→): "remove:<id>" for each piece
## installed there, "install:<id>" for each storage piece that goes there.
func _actions_for(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for p in Cyber.pieces_at(c.implants, loc):
		if not "remove:" + String(p.id) in out:
			out.append("remove:" + String(p.id))
	for id in _stored_here():
		out.append("install:" + id)
	return out


## Storage pieces that go in the selected location at all (fitting now or not).
func _stored_here() -> Array[String]:
	var out: Array[String] = []
	for k in camp.cyberware_options():
		var id := Items.base_id(k)
		if loc in Cyber.locs_for(id) and not id in out:
			out.append(id)
	return out


func _select_loc(l: String) -> void:
	if l != loc:
		loc = l
		_pick = ""
		_confirm = ""
		_choose = ""
	_build()


## The selected location's panel: what it holds and what in storage goes there.
func _slot_panel(c: Combatant, width: int) -> PanelContainer:
	var p := UiKit.panel(Hud.VIOLET, 10)
	p.name = "SlotPanel"
	p.custom_minimum_size.x = width
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(6)
	p.add_child(v)
	v.add_child(UiKit.head(Cyber.loc_name(loc), 28, ChromeBody.CHROME))
	var st := UiKit.body(slot_status(c.implants, loc), 14, Hud.TEXT)
	st.name = "Status"
	v.add_child(st)
	var list := UiKit.vbox(6)
	v.add_child(UiKit.scroller(list))
	list.add_child(section("INSTALLED", ChromeBody.CHROME))
	var seen := {}
	for pc in Cyber.pieces_at(c.implants, loc):
		if seen.has(String(pc.id)):
			continue
		seen[String(pc.id)] = true
		list.add_child(_installed_row(c, String(pc.id)))
	if seen.is_empty():
		list.add_child(none("Nothing installed."))
	for pc in c.implants:   # a Subdermal Grip takes one of the Neural Link's slots from its arm
		if loc == "neural_link" and String(pc.loc) != loc and int(Cyber.def(String(pc.id)).get("neural_slot", 0)) > 0:
			list.add_child(UiKit.body("%s (%s) takes a slot here." % [Cyber.display(String(pc.id)), Cyber.loc_name(String(pc.loc))], 13, Hud.DIM))
	list.add_child(section("FROM STORAGE", ChromeBody.CHROME))
	var ids := _stored_here()
	for id in ids:
		list.add_child(_stored_row(c, id))
	if ids.is_empty():
		list.add_child(none("Nothing in storage goes in the %s." % Cyber.loc_name(loc)))
	# what else is in storage, and where it goes: one click away
	var other: Array[String] = []
	for k in camp.cyberware_options():
		var id := Items.base_id(k)
		if not id in ids and not id in other:
			other.append(id)
	if not other.is_empty():
		list.add_child(section("ELSEWHERE", Hud.DIM))
		var f := UiKit.flow(4)
		list.add_child(f)
		for id in other:
			var to := Cyber.auto_loc(c.implants, id)
			if to == "" and not Cyber.locs_for(id).is_empty():
				to = Cyber.locs_for(id)[0]
			if to == "":
				continue
			var tl := to
			f.add_child(UiKit.button("%s › %s" % [Cyber.display(id), Cyber.loc_name(to)], UiKit.NAV, func(): _select_loc(tl), true, 12, true))
	v.add_child(UiKit.body("Installing is free; every piece costs Humanity. Removing a piece destroys it.", 13, Hud.DIM))
	var go := UiKit.button("NIGHT MARKET ›", UiKit.NAV, func(): navigate.emit("market"), true, 13, true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(go)
	return p


## The selected location in a line: its foundation and free slots, or what opens it.
static func slot_status(implants: Array, l: String) -> String:
	var f := Cyber.foundation_at(implants, l)
	var fname := Cyber.display(f) if f != "" else ""
	if l == "borgware":
		return "Borgware takes no option slots."
	if Cyber.is_meat(implants, l):
		var what := "cyberleg" if l in Cyber.LEGS else "cyberarm"
		return "Meat. Holds one piece, or a %s with %d slots." % [what, int(Cyber.def(what).get("capacity", 0))]
	var cap := Cyber.capacity(implants, l)
	if cap <= 0:
		match l:
			"neural_link": return "Needs a Neural Link: it holds %d option slots." % int(Cyber.def("neural_link").get("capacity", 5))
			"chipware": return "Each Chipware Socket holds one chip. The socket goes in the Neural Link."
			"cyberaudio": return "Needs a Cyberaudio Suite: it holds %d option slots." % int(Cyber.def("cyberaudio_suite").get("capacity", 3))
			"right_eye", "left_eye": return "Meat. A Cybereye holds %d option slots." % int(Cyber.def("cybereye").get("capacity", 3))
		return "No slots."
	var free := Cyber.free_slots(implants, l)
	if l == "chipware":
		return "%d socket%s · %d free" % [cap, "" if cap == 1 else "s", maxi(0, free)]
	return ("%s · " % fname if fname != "" else "") + "%d of %d slots free" % [maxi(0, free), cap]


## Why a row's action can't be done, on its own line under the piece.
static func _blocked(why: String) -> Label:
	var l := UiKit.label("⚠ " + why, 12, Hud.CYAN)
	l.name = "Blocked"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 60
	return l


## A row's panel: gold edge when it's the pick (keyboard or click), red while a removal waits.
static func _row_panel(on: bool, danger := false) -> PanelContainer:
	var p := PanelContainer.new()
	var edge := Hud.RED if danger else (Hud.GOLD if on else Color(ChromeBody.CHROME, 0.35))
	var fill := Color(0.12, 0.03, 0.04, 0.95) if danger else (Color(0.11, 0.09, 0.02, 0.95) if on else Color(0.035, 0.05, 0.065, 0.95))
	p.add_theme_stylebox_override("panel", CutBox.make(fill, edge, 7, 0b0101, edge if on or danger else Color(0, 0, 0, 0), 6))
	return p


func _chrome_text(v: VBoxContainer, id: String, extra := "") -> void:
	var nm := UiKit.label(Cyber.display(id), 15, ChromeBody.CHROME)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.custom_minimum_size.x = 60
	v.add_child(nm)
	v.add_child(UiKit.body(chrome_summary(id) + extra, 13, Hud.DIM))


## An installed piece: REMOVE, which asks first (removal destroys it), or why it can't come out yet.
func _installed_row(c: Combatant, id: String) -> Control:
	var key := "%s@%s" % [id, loc]
	var on := _pick == "remove:" + id
	var asking := _confirm == key
	var p := _row_panel(on, asking)
	p.name = "Installed_" + id
	var v := UiKit.vbox(4)
	p.add_child(v)
	var row := UiKit.hbox(10)
	v.add_child(row)
	var t := UiKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	_chrome_text(t, id)
	var why := camp.remove_block(c, id, loc)
	var nm := Cyber.display(id)
	if why != "":
		v.add_child(_blocked(why))
	elif asking:   # the confirmation, in the row: what removal costs, then the two answers
		v.add_child(UiKit.body("Removing destroys the %s. It can't be sold or refitted, and Humanity already lost stays lost." % nm, 13, Hud.RED))
		var bh := UiKit.hbox(8)
		v.add_child(bh)
		var b := UiKit.button("DESTROY IT", UiKit.DANGER, Callable(), true, 14, true)
		b.pressed.connect(func(): _remove(b, c, id))
		bh.add_child(b)
		bh.add_child(UiKit.button("KEEP IT · ESC", UiKit.NAV, func(): _confirm = ""; _build(), true, 14, true))
	elif Campaign.comes_out_whole(id):   # a chip goes back to storage: nothing to confirm
		var b := UiKit.button("TAKE OUT", UiKit.NAV, Callable(), true, 14, true)
		b.pressed.connect(func(): _remove(b, c, id))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	else:
		var b := UiKit.button("REMOVE", UiKit.DANGER, func(): _ask_remove(id), true, 14, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	var pick := "remove:" + id
	UiKit.clickable(p, func(): _pick = pick; _build())
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


## A stored piece that goes here: INSTALL, or the reason it can't go in now.
func _stored_row(c: Combatant, id: String) -> Control:
	var d := Cyber.def(id)
	var on := _pick == "install:" + id
	var p := _row_panel(on)
	p.name = "Stored_" + id
	var v := UiKit.vbox(4)
	p.add_child(v)
	var row := UiKit.hbox(10)
	v.add_child(row)
	var t := UiKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var need := Cyber.needs(id)
	var extra := " Humanity Loss %s." % String(d.get("hl_dice", ""))
	if d.get("paired", false):
		extra += " Paired: one in each %s." % ("leg" if String(d.get("host", "")) == "leg" else "eye")
	elif need != "":
		extra += " Needs %s." % Cyber.display(need)
	var n := camp.stored("cyberware/" + id)
	if n > 1:
		extra += "  ·  %d in storage" % n
	_chrome_text(t, id, extra)
	var why := camp.install_block(c, id, loc)
	if why != "":
		v.add_child(_blocked(why))
	elif _choose == id:   # the install's options step (phase 1: a chip's skill, a popup weapon)
		var f := UiKit.flow(4)
		v.add_child(f)
		for ch in _install_choices(c, id):
			var val: Variant = ch[0]
			var b := UiKit.button(String(ch[1]), UiKit.CHROME, Callable(), true, 13, true)
			b.pressed.connect(func(): _install(b, c, id, val))
			f.add_child(b)
		f.add_child(UiKit.button("CANCEL", UiKit.NAV, func(): _choose = ""; _build(), true, 13, true))
	else:
		var b := UiKit.button("INSTALL", UiKit.CHROME, Callable(), true, 14, true)
		b.custom_minimum_size.x = 96
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): _start_install(b, c, id))
		row.add_child(b)
	var pick := "install:" + id
	UiKit.clickable(p, func(): _pick = pick; _build())
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


## The choices a piece asks for before it goes in, [[value, label], ...]; [] installs at once.
## Phase 1's hook (a Skill Chip's skill, a popup weapon's weapon): return them here, and
## _install hands the picked value to Campaign.install as a fourth argument.
func _install_choices(_c: Combatant, id: String) -> Array:
	var out: Array = []
	for k in camp.cyberware_options():   # what each stored one was bought for ("cyberware/skill_chip@handgun")
		var ch := Cyber.choice_of(k.get_slice("/", 1))
		if Items.base_id(k) == id and ch != "":
			out.append([ch, Cyber.choice_name(id, ch)])
	return out


func _start_install(b: Button, c: Combatant, id: String) -> void:
	if _install_choices(c, id).is_empty():
		_install(b, c, id, null)
	else:
		_choose = id
		_pick = "install:" + id
		_build()


func _install(b: Button, c: Combatant, id: String, choice: Variant) -> void:
	var lost := [0]
	var where := loc
	_choose = ""
	act(b, func(): lost[0] = camp.install(c, id, where) if choice == null else int(camp.callv("install", [c, id, where, choice])), "")
	toast(b, "%s installed · -%d Humanity" % [Cyber.display(id), lost[0]], ChromeBody.CHROME)


func _ask_remove(id: String) -> void:
	_pick = "remove:" + id
	if Campaign.comes_out_whole(id):   # a chip: straight back to storage, no confirmation
		var b := _find_button(_pick)
		_remove(b if b != null else Button.new(), selected(), id)
		return
	_confirm = "%s@%s" % [id, loc]
	_build()


func _remove(b: Button, c: Combatant, id: String) -> void:
	_confirm = ""
	var where := loc
	var whole := Campaign.comes_out_whole(id)
	act(b, func(): camp.remove(c, id, where), Cyber.display(id) + (" back in storage" if whole else " destroyed"), Hud.CYAN if whole else Hud.RED)


## Keys (like the Armory's): Q/E crew, ↑/↓ body location, ←/→ the location's choices, Enter
## installs or removes the picked one (removal asks first: Enter again destroys it), Del removes,
## Esc cancels a waiting removal, else goes back.
func _unhandled_input(ev: InputEvent) -> void:
	if tab != "ripperdoc" or not ev is InputEventKey or not ev.pressed:
		return
	var k := ev as InputEventKey
	var c := selected()
	if c == null:
		return
	match k.keycode:
		KEY_Q, KEY_E:
			if k.echo:
				return
			sel = posmod(sel + (-1 if k.keycode == KEY_Q else 1), maxi(1, camp.alive_crew().size()))
			_pick = ""
			_confirm = ""
			_choose = ""
			_build()
		KEY_UP, KEY_DOWN:
			var i := Cyber.LOCS.find(loc)
			_select_loc(Cyber.LOCS[posmod(i + (-1 if k.keycode == KEY_UP else 1), Cyber.LOCS.size())])
		KEY_LEFT, KEY_RIGHT:
			if not _actions.is_empty():
				_pick = _actions[posmod(_actions.find(_pick) + (-1 if k.keycode == KEY_LEFT else 1), _actions.size())]
				_confirm = ""
				_choose = ""
				_build()
		KEY_ENTER, KEY_KP_ENTER, KEY_DELETE:
			_press_pick(c, k.keycode == KEY_DELETE)
		KEY_ESCAPE:
			if _confirm != "" or _choose != "":
				_confirm = ""
				_choose = ""
				_build()
			else:
				closed.emit()
		_:
			return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## Enter (or Del, removals only) on the picked action: install it, or ask, then destroy.
func _press_pick(c: Combatant, del: bool) -> void:
	var id := _pick.get_slice(":", 1)
	var b := _find_button(_pick)
	if b == null:
		b = Button.new()   # headless: no row button to toast at
	if _pick.begins_with("install:") and not del:
		if _choose == "" and camp.install_block(c, id, loc) == "":
			_start_install(b, c, id)
	elif _pick.begins_with("remove:") and camp.remove_block(c, id, loc) == "":
		if _confirm == "%s@%s" % [id, loc]:
			_remove(b, c, id)
		else:
			_ask_remove(id)


## The live action button of a pick (INSTALL / DESTROY IT), for the toast's place.
func _find_button(pick: String) -> Button:
	var row := find_child(("Stored_" if pick.begins_with("install:") else "Installed_") + pick.get_slice(":", 1), true, false)
	if row == null:
		return null
	for b in row.find_children("*", "Button", true, false):
		if (b as Button).text in ["INSTALL", "DESTROY IT", "TAKE OUT"] and not (b as Button).is_queued_for_deletion():
			return b
	return null


## What a piece does, in a line (the data's summary: player text, no cites).
static func chrome_summary(id: String) -> String:
	return Cyber.summary(id)


static func _hum_colour(c: Combatant) -> Color:
	return [Hud.GREEN, Hud.GOLD, Hud.RED, Hud.RED][clampi(c.psychosis_tier(), 0, 3)]


# --- Therapy ----------------------------------------------------------------------------------

func _therapy(body: VBoxContainer) -> void:
	var cols := UiKit.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	cols.add_child(crew_picker(_humanity_line, 290, _health_marks))
	var c := selected()
	var p := UiKit.panel(Hud.CYAN, 12)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(p)
	var v := UiKit.vbox(10)
	p.add_child(v)
	v.add_child(UiKit.head(c.display_name, 30))
	var doc := camp.therapist_for(c)
	v.add_child(UiKit.body(("Therapy is a week with %s. The crew rests meanwhile; you pay even if it fails." % doc.display_name)
		if doc else "Therapy needs a Medtech on the crew, and a Medtech can't treat themselves.", 15, Hud.DIM if doc else Hud.GOLD))
	# Addiction (p229)
	v.add_child(section("ADDICTION"))
	if c.addictions.is_empty():
		v.add_child(none("Not addicted to anything."))
	var afx: Dictionary = RulesDB.gear("therapy", "addiction_therapy").get("fx", {})
	for drug in c.addictions:
		var dg: String = drug
		var row := UiKit.hbox(10)
		v.add_child(row)
		row.add_child(UiKit.fit(UiKit.label("Addicted to " + String(RulesDB.gear("drugs", dg).get("name", dg)), 16, Hud.RED)))
		var cost := int(afx.get("materials_cost", 500))
		var b := UiKit.button("ADDICTION THERAPY · %s eb · 1 WEEK" % UiKit.money(cost), UiKit.NEUTRAL, Callable(), doc != null and camp.eb >= cost)
		b.pressed.connect(func():
			var r := {}
			act(b, func(): r.merge(camp.treat_addiction(c, dg)), "")
			toast(b, "Clean" if r.get("success", false) else "The therapy didn't take", Hud.GREEN if r.get("success", false) else Hud.TEXT))
		row.add_child(b)
	# Humanity Loss (p229-230)
	v.add_child(section("HUMANITY"))
	if not c.tracks_humanity:
		v.add_child(none("—"))
		return
	v.add_child(UiKit.label(_humanity_line(c) + ("" if c.psychosis_tier() == 0 else " · AT RISK OF CYBERPSYCHOSIS"), 16, _hum_colour(c)))
	if c.humanity >= c.max_humanity:
		v.add_child(none("Humanity is at its maximum."))
		return
	for kind in ["standard", "extreme"]:
		var k: String = kind
		var fx: Dictionary = RulesDB.gear("therapy", String(Campaign.HUMANITY_THERAPY[k])).get("fx", {})
		var row := UiKit.hbox(10)
		v.add_child(row)
		row.add_child(UiKit.fit(UiKit.body("%s: regain %s Humanity, DV%d." % [String(RulesDB.gear("therapy", String(Campaign.HUMANITY_THERAPY[k])).get("name", k)), String(fx.get("regain_humanity", "")), int(fx.get("dv", 15))], 15, Hud.TEXT, false)))
		var cost := Campaign.humanity_therapy_cost(k)
		var b := UiKit.button("%s · %s eb · 1 WEEK" % [k, UiKit.money(cost)], UiKit.NEUTRAL, Callable(), doc != null and camp.eb >= cost)
		b.custom_minimum_size.x = 230
		b.pressed.connect(func():
			var r := {}
			act(b, func(): r.merge(camp.humanity_therapy(c, k)), "")
			toast(b, ("+%d Humanity" % int(r.get("gained", 0))) if r.get("success", false) else "The therapy didn't take", Hud.GREEN if r.get("success", false) else Hud.TEXT))
		row.add_child(b)


# --- Critical Injuries ------------------------------------------------------------------------

func _injuries(body: VBoxContainer) -> void:
	var fi := camp.favour_index("treatment")
	if fi >= 0:   # a fixer's favour (payment, MissionBuilder): the next Treatment is on them
		body.add_child(UiKit.body("Rest doesn't heal a Critical Injury; Treatment does. %s owes the crew a favour: the next one is free." % String(camp.favours[fi].get("from", "A fixer")), 15, Hud.GOLD))
	else:
		body.add_child(UiKit.body("Rest doesn't heal a Critical Injury; Treatment does. A street clinic charges %s eb each." % UiKit.money(camp.treat_cost()), 15, Hud.DIM))
	var list := UiKit.vbox(8)
	body.add_child(UiKit.scroller(list))
	var any := false
	for c in camp.alive_crew():
		if c.injuries.is_empty():
			continue
		any = true
		var p := UiKit.panel(Hud.CYAN, 10)
		list.add_child(p)
		var v := UiKit.vbox(6)
		p.add_child(v)
		var h := UiKit.hbox(12)
		v.add_child(h)
		h.add_child(UiKit.portrait(portraits, c, 1000 + maxi(0, c.look_seed), 40))
		h.add_child(UiKit.head(c.display_name, 28))
		var hp := UiKit.label("HP %d/%d · %s" % [c.hp, c.max_hp(), Campaign.WOUND_NAMES[c.wound_state()]], 14, UiKit.hp_colour(c))
		hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(hp)
		for i in c.injuries.size():
			var inj: Dictionary = c.injuries[i]
			var row := UiKit.hbox(10)
			v.add_child(row)
			var t: Dictionary = inj.get("treatment") if inj.get("treatment") is Dictionary else {}
			var txt := "%s (%s)" % [String(inj.get("name", "injury")), String(inj.get("location", ""))]
			row.add_child(UiKit.fit(UiKit.label(txt, 16, Hud.RED)))
			if not t.is_empty():
				row.add_child(UiKit.label("Treatment: %s DV%d" % [String(RulesDB.load_json("skills.json")["skills"].get(String(t.get("skill", "")), {}).get("name", t.get("skill", ""))), int(t.get("dv", 0))], 13, Hud.DIM))
			var idx := i
			var cc: Combatant = c
			var nm := String(inj.get("name", "injury"))
			var b := UiKit.button(UiKit.price_text("TREAT", camp.treat_cost()), UiKit.NEUTRAL, Callable(), camp.eb >= camp.treat_cost())
			b.pressed.connect(func(): act(b, func(): camp.treat(cc, idx), nm + " treated"))
			row.add_child(b)
	if not any:
		list.add_child(none("Nobody has a Critical Injury."))
