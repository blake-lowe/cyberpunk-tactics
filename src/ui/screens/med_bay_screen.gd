class_name MedBayScreen
extends SafehouseScreen
## The Med Bay: the RIPPERDOC (cyberware bought at a Night Market waits in storage; installing it
## costs nothing more, CPR core p338, the price includes the surgery, p110; Humanity Loss on install;
## installed chrome can be removed, which destroys it, never moved to someone else), THERAPY
## (Addiction and Humanity Loss Therapy by a Medtech, p229-230) and Treatment for Critical
## Injuries (p223). The crew cards here show each member's last-gig health marks.
## The ripperdoc (owner, playtest): the name, EMP and a Humanity bar over the body (ChromeBody.header);
## the selected location's panel lists what's installed, then a card per free Option Slot (a + that
## opens storage filtered to what goes in it), and for a place with no foundation yet a button to put
## one in (INSTALL CYBEREYE, INSTALL CYBERLIMB...). Removing asks first, in a popup.

var _confirm := ""   ## the installed piece ("id@loc") whose removal waits in the popup for DESTROY IT
var loc := ""        ## the ripperdoc's selected body location (ChromeBody.LOCS)
var _pick := ""      ## the picked action: "remove:<id>", "slot", "foundation", or in the picker "install:<id>" (gold; Enter acts on it)
var _choose := ""    ## a storage piece whose install waits for its option (_install_choices)
var _picker := ""    ## the open storage picker: "slot" (options for a free slot), "foundation" (the INSTALL button's), "" none
var _actions: Array[String] = []   ## the panel's actions in order (←/→), or the picker's (↑/↓)
var _popup: Control  ## the open popup (the picker or the removal's confirmation)
var _armed := ""     ## the INSTALL armed to CONFIRM: a piece's id, or "id@choice" for an options-step choice
var last_install := {}   ## the last install's presentation: {id, loc} (tests, shots)


func setup(p_camp: Campaign, p_portraits: Portraits, p_tab := "", p_sel := 0) -> SafehouseScreen:
	super.setup(p_camp, p_portraits, p_tab, p_sel)
	if p_camp.has_meta("demo"):   # DEV ONLY review shots: --loc=right_eye --pick=remove:cybereye --confirm=1 --picker=slot
		for a in OS.get_cmdline_user_args():
			var k := a.trim_prefix("--").get_slice("=", 0)
			var val := a.get_slice("=", 1)
			match k:
				"loc": loc = val
				"pick": _pick = val
				"confirm": _confirm = "%s@%s" % [_pick.get_slice(":", 1), loc] if _pick.begins_with("remove:") else ""
				"picker": _picker = val
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


## The screen, then the ripperdoc's popup over it (the picker or the removal's confirmation).
func _build() -> void:
	super._build()
	if _popup:
		_popup.name = "Closed"   # frees its name for the next popup while it waits to be freed
		_popup.queue_free()
		_popup = null
	var c := selected()
	if tab != "ripperdoc" or c == null:
		return
	if _confirm != "":
		_popup = _confirm_popup(c, _confirm.get_slice("@", 0))
	elif _picker != "":
		_popup = _picker_popup(c)
	if _popup:
		add_child(_popup)


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
	# the crew cards carry no Humanity or EMP here: the header over the body does (owner, playtest)
	cols.add_child(crew_picker(Callable(), 270 if wide else (196 if narrow else 230), _health_marks))
	var c := selected()
	_settle(c)
	var mid := UiKit.panel(Hud.VIOLET, 10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var mv := UiKit.vbox(2)
	mid.add_child(mv)
	mv.add_child(ChromeBody.header(c))
	var fig := ChromeBody.new().setup(c, loc, _piece(), _hints(c), vs.y < 700.0)
	fig.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fig.loc_pressed.connect(_select_loc)
	fig.piece_pressed.connect(func(l: String, id: String): loc = l; _pick = "remove:" + id; _shut(); _build())
	mv.add_child(fig)
	cols.add_child(_slot_panel(c, 380 if wide else (280 if narrow else 300)))


## Close the popups and the options step, and disarm INSTALL.
func _shut() -> void:
	_confirm = ""
	_choose = ""
	_picker = ""
	_armed = ""


## Keep the selection valid: a location (the first where something in storage fits now, else the
## first with chrome in it), and a picked action (the first, if none).
func _settle(c: Combatant) -> void:
	if not loc in ChromeBody.LOCS:
		var h := _hints(c)
		loc = ""
		for l in ChromeBody.LOCS:
			if int(h.get(l, 0)) > 0:
				loc = l
				break
		if loc == "":
			for l in ChromeBody.LOCS:
				if not Cyber.pieces_at(c.implants, l).is_empty():
					loc = l
					break
		if loc == "":
			loc = "neural_link"
	if _picker == "foundation" and foundation_offer(c.implants, loc) == "":
		_picker = ""
	_actions = _actions_for(c)
	if not _pick in _actions:
		_pick = _actions[0] if not _actions.is_empty() else ""
	if _confirm != "" and _pick != "remove:" + _confirm.get_slice("@", 0):
		_confirm = ""


## The installed piece picked at `loc` ("" if the pick isn't one).
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


## The actions in order: in the picker, "install:<id>" for each piece it lists (↑/↓); else the
## panel's (←/→): "remove:<id>" for each piece installed, "slot" with a free slot, "foundation" for
## the INSTALL button.
func _actions_for(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	if _picker != "":
		for id in _picked_ids(c):
			out.append("install:" + id)
		return out
	for p in Cyber.pieces_at(c.implants, loc):
		if not "remove:" + String(p.id) in out:
			out.append("remove:" + String(p.id))
	if open_slots(c.implants, loc) > 0:
		out.append("slot")
	if foundation_offer(c.implants, loc) != "":
		out.append("foundation")
	return out


## The free slots a location shows as + cards: its free Option Slots; a meat arm or leg's one place
## for a meat-limb piece while it's empty (owner: "a meat arm or leg already has 1 slot").
static func open_slots(implants: Array, l: String) -> int:
	if Cyber.is_meat(implants, l):
		return 1 if Cyber.meat_pieces(implants, l).is_empty() else 0
	return maxi(0, Cyber.free_slots(implants, l))


## The foundation a location's INSTALL button puts in ("" if none: it has one, or takes none here; a
## Chipware Socket goes in a Neural Link slot).
static func foundation_offer(implants: Array, l: String) -> String:
	if l == "chipware" or not ChromeBody.FOUNDATION.has(l) or Cyber.foundation_at(implants, l) != "":
		return ""
	return String(ChromeBody.FOUNDATION[l])


## The INSTALL button's words: a meat eye's "Install cybereye", a meat limb's "Install cyberlimb".
static func foundation_verb(l: String) -> String:
	if l in ChromeBody.LIMBS:
		return "Install cyberlimb"
	return "Install " + Cyber.display(String(ChromeBody.FOUNDATION.get(l, ""))).to_lower()


## Storage pieces the open picker lists: for a free slot, the options that go in this location (in a
## meat limb, only what a meat limb takes); for the INSTALL button, the foundations that go here.
func _picked_ids(c: Combatant) -> Array[String]:
	return stored_for(camp, c, loc, _picker)


static func stored_for(p_camp: Campaign, c: Combatant, l: String, kind: String) -> Array[String]:
	var out: Array[String] = []
	for k in p_camp.cyberware_options():
		var id := Items.base_id(k)
		if id in out or not l in Cyber.locs_for(id):
			continue
		var found := Cyber.is_foundation(id)
		if kind == "foundation" and not found:
			continue
		if kind == "slot" and (found or (Cyber.is_meat(c.implants, l) and not Cyber.def(id).get("meat_ok", false))):
			continue
		out.append(id)
	return out


func _select_loc(l: String) -> void:
	if l != loc:
		loc = l
		_pick = ""
		_shut()
	_build()


## The selected location's panel: its category and place, what it holds, a card per free slot and
## the INSTALL button for a missing foundation.
func _slot_panel(c: Combatant, width: int) -> PanelContainer:
	var p := UiKit.panel(Hud.VIOLET, 10)
	p.name = "SlotPanel"
	p.custom_minimum_size.x = width
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(6)
	p.add_child(v)
	if ChromeBody.SIDE.has(loc):
		v.add_child(UiKit.label(String(ChromeBody.CATEGORY[loc]), 13, Hud.DIM))
	v.add_child(UiKit.head(String(ChromeBody.SIDE.get(loc, ChromeBody.CATEGORY.get(loc, Cyber.loc_name(loc)))), 28, ChromeBody.CHROME))
	var st := UiKit.body(slot_status(c.implants, loc), 14, Hud.TEXT)
	st.name = "Status"
	v.add_child(st)
	var f := foundation_offer(c.implants, loc)
	if f != "":   # a meat eye's INSTALL CYBEREYE, a meat limb's INSTALL CYBERLIMB...
		var have := not stored_for(camp, c, loc, "foundation").is_empty()
		var b := UiKit.button(foundation_verb(loc), UiKit.CHROME, func(): _open_picker("foundation"), have, 14, true)
		b.name = "InstallFoundation"
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if _pick == "foundation":
			b.add_theme_stylebox_override("normal", UiKit._btn_box(Color(0.11, 0.09, 0.02, 0.95), Hud.GOLD, true))
		v.add_child(b)
		if not have:
			var why := UiKit.body("No %s in storage." % ("cyberlimb" if loc in ChromeBody.LIMBS else Cyber.display(f).to_lower()), 13, Hud.DIM)
			why.name = "FoundationWhy"
			v.add_child(why)
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
	for i in open_slots(c.implants, loc):   # each free slot: a + card that opens storage filtered to it
		list.add_child(_slot_card(i))
	# what else is in storage, and where it goes: one click away
	var other: Array[String] = []
	for k in camp.cyberware_options():
		var id := Items.base_id(k)
		if not loc in Cyber.locs_for(id) and not id in other:
			other.append(id)
	var to_go: Array = []
	for id in other:
		var to := Cyber.auto_loc(c.implants, id)
		if to == "" and not Cyber.locs_for(id).is_empty():
			to = Cyber.locs_for(id)[0]
		if to in ChromeBody.LOCS:
			to_go.append([id, to])
	if not to_go.is_empty():
		list.add_child(section("ELSEWHERE", Hud.DIM))
		var fl := UiKit.flow(4)
		list.add_child(fl)
		for pair in to_go:
			var tl: String = pair[1]
			fl.add_child(UiKit.button("%s › %s" % [Cyber.display(String(pair[0])), Cyber.loc_name(tl)], UiKit.NAV, func(): _select_loc(tl), true, 12, true))
	return p   # (no reminder line or NIGHT MARKET link at the foot: owner, playtest)


## The selected location in a line (owner, playtest: a meat eye just "Meat."; a Cybereye "Cybereye. 3
## option slots available", fewer as options go in): the foundation and the free slots, or what's
## missing.
static func slot_status(implants: Array, l: String) -> String:
	var n := open_slots(implants, l)
	if Cyber.is_meat(implants, l):
		return "Meat. " + ("1 slot available." if n > 0 else "No slot available.")
	var avail := "No option slots available." if n <= 0 else ("1 option slot available." if n == 1 else "%d option slots available." % n)
	var fl := ChromeBody.foundation_line(implants, l)
	if ChromeBody.FOUNDATION.has(l) and not fl[1]:
		match l:
			"right_eye", "left_eye": return "Meat."
			"chipware": return "No Chipware Socket. A socket goes in a Neural Link slot."
		return "No %s." % Cyber.display(String(ChromeBody.FOUNDATION[l]))
	return ("%s. " % String(fl[0]) if fl[1] else "") + avail


## Why a row's action can't be done, on its own line under the piece.
static func _blocked(why: String) -> Label:
	var l := UiKit.label("⚠ " + why, 12, Hud.CYAN)
	l.name = "Blocked"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 60
	return l


## A row's panel: gold edge when it's the pick (keyboard or click).
static func _row_panel(on: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var edge := Hud.GOLD if on else Color(ChromeBody.CHROME, 0.35)
	var fill := Color(0.11, 0.09, 0.02, 0.95) if on else Color(0.035, 0.05, 0.065, 0.95)
	p.add_theme_stylebox_override("panel", CutBox.make(fill, edge, 7, 0b0101, edge if on else Color(0, 0, 0, 0), 6))
	return p


func _chrome_text(v: VBoxContainer, id: String, extra := "") -> void:
	var nm := UiKit.label(Cyber.display(id), 15, ChromeBody.CHROME)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.custom_minimum_size.x = 60
	v.add_child(nm)
	v.add_child(UiKit.body(chrome_summary(id) + extra, 13, Hud.DIM))


## An installed piece: REMOVE, which asks first in a popup (removal destroys it); a chip's TAKE OUT
## (back to storage, nothing to confirm); or why it can't come out yet.
func _installed_row(c: Combatant, id: String) -> Control:
	var p := _row_panel(_pick == "remove:" + id)
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
	if why != "":
		v.add_child(_blocked(why))
	elif Campaign.comes_out_whole(id):
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


## A free slot: a card like the installed ones, a + in a small square at its centre. A click opens
## storage filtered to what goes in it.
func _slot_card(i: int) -> Control:
	var p := _row_panel(_pick == "slot" and i == 0)
	p.name = "Slot_%d" % i
	p.custom_minimum_size.y = 44
	var cc := CenterContainer.new()
	p.add_child(cc)
	var sq := PanelContainer.new()
	sq.name = "Plus"
	sq.custom_minimum_size = Vector2(26, 26)
	sq.add_theme_stylebox_override("panel", CutBox.make(Color(0.03, 0.04, 0.055, 0.95), Color(ChromeBody.CHROME, 0.7), 4, 0b0101, Color(0, 0, 0, 0), 2))
	var l := UiKit.label("+", 18, ChromeBody.CHROME)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sq.add_child(l)
	cc.add_child(sq)
	p.tooltip_text = "Install from storage"
	UiKit.clickable(p, func(): _pick = "slot"; _open_picker("slot"))
	return p


func _open_picker(kind: String) -> void:
	_picker = kind
	_choose = ""
	_confirm = ""
	_pick = ""
	_build()


## A dimmed screen with a panel at its centre (the picker, the removal's confirmation); a click
## outside the panel closes it.
func _modal(edge: Color, width: float) -> Array:
	var root := Control.new()
	root.name = "Popup"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 5
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_shut()
			_build())
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var p := UiKit.panel(edge, 14)
	p.name = "Dialog"
	p.custom_minimum_size.x = width
	cc.add_child(p)
	var v := UiKit.vbox(8)
	p.add_child(v)
	return [root, v]


## Storage, filtered to the free slot or to the INSTALL button's foundations: each piece with INSTALL,
## its options step, or why it can't go in; a plain line when nothing fits.
func _picker_popup(c: Combatant) -> Control:
	var m := _modal(ChromeBody.CHROME, 470.0)
	var v: VBoxContainer = m[1]
	(m[0] as Control).name = "Picker"
	var place := String(ChromeBody.SIDE.get(loc, ChromeBody.CATEGORY.get(loc, "")))
	v.add_child(UiKit.label(("%s · option slot" % place) if _picker == "slot" else foundation_verb(loc) + (" · " + place if ChromeBody.SIDE.has(loc) else ""), 16, ChromeBody.CHROME))
	var ids := _picked_ids(c)
	var list := UiKit.vbox(6)
	if ids.is_empty():
		list.add_child(none("Nothing in storage fits."))
	for id in ids:
		list.add_child(_stored_row(c, id))
	var sc := UiKit.scroller(list)
	var vs := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	sc.custom_minimum_size.y = clampf(ids.size() * 86.0, 40.0, vs.y * 0.55)
	v.add_child(sc)
	var bh := UiKit.hbox(8)
	v.add_child(bh)
	if ids.is_empty():
		bh.add_child(UiKit.button("NIGHT MARKET ›", UiKit.NAV, func(): _shut(); navigate.emit("market"), true, 14, true))
	bh.add_child(UiKit.spacer())
	bh.add_child(UiKit.button("CANCEL · ESC", UiKit.NAV, func(): _shut(); _build(), true, 14, true))
	return m[0]


## The removal's confirmation: what it costs, DESTROY IT or KEEP IT.
func _confirm_popup(c: Combatant, id: String) -> Control:
	var m := _modal(Hud.RED, 440.0)
	var v: VBoxContainer = m[1]
	(m[0] as Control).name = "Confirm"
	var nm := Cyber.display(id)
	var both := ""
	if Cyber.paired(id) and not c.implant(id, Cyber.pair_of(id, loc)).is_empty():
		both = " in both %ss" % ("leg" if Cyber.pair_locs(id) == Cyber.LEGS else "eye")
	v.add_child(UiKit.label("Remove the %s?" % nm, 16, Hud.RED))
	v.add_child(UiKit.body("Removing destroys the %s%s. It can't be sold or refitted, and Humanity already lost stays lost." % [nm, both], 14, Hud.TEXT))
	var bh := UiKit.hbox(8)
	v.add_child(bh)
	var b := UiKit.button("DESTROY IT", UiKit.DANGER, Callable(), true, 14, true)
	b.pressed.connect(func(): _remove(b, c, id))
	bh.add_child(b)
	bh.add_child(UiKit.spacer())
	bh.add_child(UiKit.button("KEEP IT · ESC", UiKit.NAV, func(): _confirm = ""; _build(), true, 14, true))
	return m[0]


## A stored piece in the picker: INSTALL, or the reason it can't go in now.
func _stored_row(c: Combatant, id: String) -> Control:
	var d := Cyber.def(id)
	var p := _row_panel(_pick == "install:" + id)
	p.name = "Stored_" + id
	var v := UiKit.vbox(4)
	p.add_child(v)
	var row := UiKit.hbox(10)
	v.add_child(row)
	var t := UiKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var extra := " Humanity Loss %s." % String(d.get("hl_dice", ""))
	if Cyber.paired(id):
		extra += " Paired: goes into both %ss, two from storage." % ("leg" if Cyber.pair_locs(id) == Cyber.LEGS else "eye")
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
			var armed := _armed == "%s@%s" % [id, String(val)]
			var b := UiKit.button("CONFIRM" if armed else String(ch[1]), UiKit.PRIMARY if armed else UiKit.CHROME, Callable(), true, 13, true)
			b.pressed.connect(func(): _install_press(b, c, id, val))
			f.add_child(b)
		f.add_child(UiKit.button("BACK", UiKit.NAV, func(): _choose = ""; _armed = ""; _build(), true, 13, true))
	else:
		var armed := _armed == id
		var b := UiKit.button("CONFIRM" if armed else "INSTALL", UiKit.PRIMARY if armed else UiKit.CHROME, Callable(), true, 14, true)
		b.name = "InstallButton"
		b.custom_minimum_size.x = 96
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): _start_install(b, c, id))
		row.add_child(b)
	var pick := "install:" + id
	UiKit.clickable(p, func(): _pick = pick; _armed = ""; _build())
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


## INSTALL: arms it (CONFIRM), or with the piece's options step, shows its choices.
func _start_install(b: Button, c: Combatant, id: String) -> void:
	if _install_choices(c, id).is_empty():
		_install_press(b, c, id, null)
	else:
		_choose = id
		_armed = ""
		_pick = "install:" + id
		_build()


## Install takes two presses (owner, playtest): the first arms the button (CONFIRM), the second
## installs. Esc, another click or key disarms it.
func _install_press(b: Button, c: Combatant, id: String, choice: Variant) -> void:
	var key := id if choice == null else "%s@%s" % [id, String(choice)]
	if _armed == key:
		_install(b, c, id, choice)
	else:
		_armed = key
		_pick = "install:" + id
		_build()


## The install itself goes into the campaign at once (deterministic); the surgery plays over it as
## presentation (_present).
func _install(b: Button, c: Combatant, id: String, choice: Variant) -> void:
	var lost := [0]
	var where := loc
	_shut()
	_pick = ""
	act(b, func(): lost[0] = camp.install(c, id, where) if choice == null else int(camp.callv("install", [c, id, where, choice])), "")
	if lost[0] >= 0:
		_present(Cyber.base(id), where)
	toast(b, "%s installed · -%d Humanity" % [Cyber.display(id), lost[0]], ChromeBody.CHROME)


## The surgery, as presentation (owner, playtest): a progress bar slides across the new piece's card
## while sfx_surgery plays, and its place on the figure flares, scan-tears and resolves into violet
## chrome (ChromeBody.flare), all over ChromeBody.INSTALL_SECS. Reduced motion: the bar shown full
## and a still glow, briefly.
func _present(id: String, where: String) -> void:
	var still := GameSettings.reduced_motion()
	last_install = {"id": id, "loc": where}
	if AudioDirector.I and is_instance_valid(AudioDirector.I):
		AudioDirector.I.ui("sfx_surgery", -2.0)
	var fig := _live_one("ChromeBody") as ChromeBody
	if fig:
		fig.flare(where, still, Cyber.pair_of(id, where))
	var row := _live_one("Installed_" + id)
	if row == null:
		return
	var bar := InstallBar.new()
	bar.name = "InstallBar"
	row.add_child(bar)
	if not is_inside_tree():
		bar.t = 1.0
		return
	if still:
		bar.t = 1.0
		get_tree().create_timer(0.6).timeout.connect(func(): if is_instance_valid(bar): bar.queue_free())
	else:
		var tw := bar.create_tween()
		tw.tween_property(bar, "t", 1.0, ChromeBody.INSTALL_SECS)
		tw.tween_property(bar, "modulate:a", 0.0, 0.25)
		tw.tween_callback(bar.queue_free)


## A node under the screen that a rebuild hasn't thrown away (by name), or null.
func _live_one(pattern: String) -> Control:
	for n in find_children(pattern, "", true, false):
		var gone := false
		var a: Node = n
		while a:
			if a.is_queued_for_deletion():
				gone = true
				break
			a = a.get_parent()
		if not gone:
			return n as Control
	return null


## The install's progress across a card: a violet fill with a bright leading edge.
class InstallBar extends Control:
	var t := 0.0:
		set(v):
			t = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x * clampf(t, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, size.y)), Color(ChromeBody.CHROME, 0.22))
		draw_rect(Rect2(Vector2(maxf(0.0, w - 3.0), 0), Vector2(3.0, size.y)), Color(1, 0.95, 1, 0.85 * (1.0 - t * 0.5)))
		draw_rect(Rect2(Vector2(0, size.y - 3.0), Vector2(w, 3.0)), Color(ChromeBody.CHROME, 0.9))


func _ask_remove(id: String) -> void:
	_pick = "remove:" + id
	if Campaign.comes_out_whole(id):   # a chip: straight back to storage, no confirmation
		var b := _find_button(_pick)
		_remove(b if b != null else Button.new(), selected(), id)
		return
	_confirm = "%s@%s" % [id, loc]
	_build()


func _remove(b: Button, c: Combatant, id: String) -> void:
	_shut()
	var where := loc
	var whole := Campaign.comes_out_whole(id)
	act(b, func(): camp.remove(c, id, where), Cyber.display(id) + (" back in storage" if whole else " destroyed"), Hud.CYAN if whole else Hud.RED)


## Keys (like the Armory's): Q/E crew, ↑/↓ body location (in the picker: its pieces), ←/→ the
## location's actions, Enter acts on the picked one (a + opens the picker, REMOVE asks first and
## Enter again destroys it), Del removes, Esc closes a popup, else goes back.
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
			_shut()
			_build()
		KEY_UP, KEY_DOWN:
			if _picker != "":
				_step(k.keycode == KEY_DOWN)
			elif _confirm == "":
				var i := ChromeBody.LOCS.find(loc)
				_select_loc(ChromeBody.LOCS[posmod(i + (-1 if k.keycode == KEY_UP else 1), ChromeBody.LOCS.size())])
		KEY_LEFT, KEY_RIGHT:
			if _picker == "" and _confirm == "":
				_step(k.keycode == KEY_RIGHT)
		KEY_ENTER, KEY_KP_ENTER, KEY_DELETE:
			_press_pick(c, k.keycode == KEY_DELETE)
		KEY_ESCAPE:
			if _armed != "":   # first, disarm a CONFIRM (the picker stays open)
				_armed = ""
				_build()
			elif _confirm != "" or _choose != "" or _picker != "":
				_shut()
				_build()
			else:
				closed.emit()
		_:
			return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## The next (or previous) action.
func _step(fwd: bool) -> void:
	if _actions.is_empty():
		return
	_pick = _actions[posmod(_actions.find(_pick) + (1 if fwd else -1), _actions.size())]
	_choose = ""
	_armed = ""
	_build()


## Enter (or Del, removals only) on the picked action: destroy what the popup asks about, install
## the picker's pick, open the picker, or ask before a removal.
func _press_pick(c: Combatant, del: bool) -> void:
	var id := _pick.get_slice(":", 1)
	var b := _find_button(_pick)
	if b == null:
		b = Button.new()   # headless: no row button to toast at
	if _confirm != "":
		if camp.remove_block(c, _confirm.get_slice("@", 0), loc) == "":
			_remove(b, c, _confirm.get_slice("@", 0))
		return
	if del:
		if _pick.begins_with("remove:") and _picker == "" and camp.remove_block(c, id, loc) == "":
			_ask_remove(id)
		return
	if _pick.begins_with("install:"):
		if _choose == "" and camp.install_block(c, id, loc) == "":
			_start_install(b, c, id)
	elif _pick == "slot" or _pick == "foundation":
		if _pick == "slot" or not stored_for(camp, c, loc, "foundation").is_empty():
			_open_picker(_pick)
	elif _pick.begins_with("remove:") and camp.remove_block(c, id, loc) == "":
		_ask_remove(id)


## The live action button of a pick (INSTALL / DESTROY IT / TAKE OUT), for the toast's place.
func _find_button(pick: String) -> Button:
	var at: Node = _popup if _confirm != "" and _popup != null else _live_one(("Stored_" if pick.begins_with("install:") else "Installed_") + pick.get_slice(":", 1))
	if at == null:
		return null
	for b in at.find_children("*", "Button", true, false):
		if (b as Button).text in ["INSTALL", "CONFIRM", "DESTROY IT", "TAKE OUT"] and not (b as Button).is_queued_for_deletion():
			return b
	return null


## What a piece does, in a line (the data's summary: player text, no cites).
static func chrome_summary(id: String) -> String:
	return Cyber.summary(id)


static func _hum_colour(c: Combatant) -> Color:
	return ChromeBody.hum_colour(c)


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
