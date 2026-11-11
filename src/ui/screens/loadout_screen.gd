class_name LoadoutScreen
extends Control
## A crew member's whole loadout at a glance (owner: "a new in game load out screen" with the
## cyberware silhouette and the equipped weapons to the side): the ChromeBody silhouette, read-only,
## with their weapons in draw order, head and body armour and kit beside it, and what their chrome
## does. Opened in a gig (L, or a click on a crew card: the hotbar's or the Alt roster's) and from
## the Armory (FULL LOADOUT). Read-only: gear changes at the Armory, chrome at the Med Bay.
## Keys: Q/E crew, ↑/↓ body location, Esc (or L) closes (no hint line for them: owner, playtest).

signal closed

var crew: Array[Combatant] = []
var sel := 0
var loc := ""             ## the picked body location ("" lists all their chrome)
var note := "Gear changes at the Armory between gigs; chrome at the Med Bay."
var _content: Control


func setup(p_crew: Array, p_sel := 0, p_note := "") -> LoadoutScreen:
	crew.assign(p_crew)
	sel = clampi(p_sel, 0, maxi(0, crew.size() - 1))
	if p_note != "":
		note = p_note
	name = "LoadoutScreen"
	return self


func _ready() -> void:
	Hud._fonts()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.02, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build()


func selected() -> Combatant:
	return crew[sel] if sel < crew.size() else null


func close() -> void:
	closed.emit()


func _build() -> void:
	if _content:
		_content.queue_free()
	var c := selected()
	var root := UiKit.panel(Hud.CYAN, 12)
	_content = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 12
	root.offset_bottom = -12
	add_child(root)
	var v := UiKit.vbox(8)
	root.add_child(v)
	# the crew across the top, CLOSE at the right
	var top := UiKit.hbox(8)
	v.add_child(top)
	var t := UiKit.label("LOADOUT", 14, Hud.CYAN)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(t)
	for i in crew.size():
		var idx := i
		top.add_child(UiKit.tab(crew[i].display_name, i == sel, func(): _select_crew(idx), 15))
	top.add_child(UiKit.spacer())
	top.add_child(UiKit.button("CLOSE · ESC", UiKit.NAV, close, true, 15))
	if c == null:
		v.add_child(SafehouseScreen.none("Nobody on the crew."))
		return
	var cols := UiKit.hbox(10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	cols.add_child(_body_panel(c))
	cols.add_child(_gear_panel(c))
	var foot := UiKit.hbox(12)
	v.add_child(foot)
	foot.add_child(UiKit.spacer())
	foot.add_child(UiKit.body(note, 13, Hud.DIM, false))


func _body_panel(c: Combatant) -> PanelContainer:
	var p := UiKit.panel(Hud.VIOLET, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 1.6
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(2)
	p.add_child(v)
	var h := ChromeBody.header(c, Hud.GOLD)   # the name, EMP and the Humanity bar, as at the Med Bay
	v.add_child(h)
	h.add_child(UiKit.spacer())
	var who := UiKit.hbox(6)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(UiKit.label("%s · RANK %d ·" % [c.role, c.role_rank], 13, Hud.CYAN))
	who.add_child(UiKit.label("HP %d/%d" % [c.hp, c.max_hp()], 13, UiKit.hp_colour(c)))
	h.add_child(who)
	var fig := ChromeBody.new().setup(c, loc, "", {}, is_inside_tree() and get_viewport_rect().size.y < 700.0)
	fig.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fig.loc_pressed.connect(func(l: String): loc = "" if l == loc else l; _build())
	fig.piece_pressed.connect(func(l: String, _id: String): loc = l; _build())
	v.add_child(fig)
	return p


func _gear_panel(c: Combatant) -> PanelContainer:
	var p := UiKit.panel(Hud.CYAN, 10)
	p.name = "Gear"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size.x = 340
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := UiKit.vbox(4)
	p.add_child(UiKit.scroller(list))
	list.add_child(SafehouseScreen.section("WEAPONS"))
	for i in c.weapons.size():
		var w: Weapon = c.weapons[i]
		var nm := Loadout.chrome_name(c, w) if w.builtin else w.display_name()
		list.add_child(_row(Loadout.slot_label("w%d" % i), nm if nm != "" else w.display_name(), Items.key_of_weapon(w), Loadout.slot_stats(c, "w%d" % i), w.builtin))
	if c.weapons.is_empty():
		list.add_child(SafehouseScreen.none("Unarmed."))
	list.add_child(SafehouseScreen.section("ARMOR"))
	for l in ["head", "body"]:
		var a: ArmorPiece = c.armor.get(l)
		if a == null:
			list.add_child(_row(l.to_upper(), "", "", ""))
			continue
		var r := _row(l.to_upper(), a.name + (" +1" if a.upgraded else ""), Items.key_of_armor(a), "SP %d/%d" % [a.sp, a.max_sp])
		if a.sp < a.max_sp:   # ablated: the SP in red
			(r.find_child("Stats", true, false) as Label).add_theme_color_override("font_color", Hud.RED)
		list.add_child(r)
	list.add_child(SafehouseScreen.section("KIT"))
	for i in c.kit.size():
		var k := c.kit[i]
		list.add_child(_row(Loadout.slot_label("k%d" % i), Items.display_name(k) if k != "" else "", k, Loadout.kit_stats(k) if k != "" else ""))
	if Deck.can_carry(c) or c.deck != "":   # the cyberdeck and what's loaded on it (Deck)
		list.add_child(SafehouseScreen.section("CYBERDECK" + ("  ·  %d/%d SLOTS" % [Deck.used(c), Deck.slots(c)] if c.deck != "" else "")))
		if c.deck == "":
			list.add_child(SafehouseScreen.none("No cyberdeck: no netrunning."))
		else:
			list.add_child(_row("DECK", Items.display_name("gear/" + c.deck), "gear/" + c.deck, "in the cyberarm" if Deck.in_arm(c) else "", Deck.in_arm(c)))
			for i in c.programs.size():
				var pk := "programs/" + c.programs[i]
				list.add_child(_row(Loadout.slot_label("p%d" % i), Deck.name_of(c.programs[i]), pk, Deck.info(pk)))
			for i in c.deck_hardware.size():
				var hk := "hardware/" + c.deck_hardware[i]
				list.add_child(_row(Loadout.slot_label("h%d" % i), Items.display_name(hk), hk, Deck.info(hk)))
			if not c.backup.is_empty():
				list.add_child(SafehouseScreen.none("Backup drive holds: " + ", ".join(c.backup.map(func(x): return Deck.name_of(String(x))))))
	# chrome: what it does (all of it, or the picked location's)
	list.add_child(SafehouseScreen.section("CHROME" + ("  ·  " + Cyber.loc_name(loc).to_upper() if loc != "" else ""), ChromeBody.CHROME))
	var any := false
	for l in Cyber.LOCS:
		if loc != "" and l != loc:
			continue
		var seen := {}
		for pc in Cyber.pieces_at(c.implants, l):
			var id := String(pc.id)
			if seen.has(id):
				continue
			seen[id] = true
			any = true
			list.add_child(_chrome_row(c, pc))
	if not any:
		list.add_child(SafehouseScreen.none("No cyberware here." if loc != "" else "No cyberware."))
	return p


## A gear line: the slot, the item's name (quality as typography) and its stats; "— empty —".
func _row(slot: String, nm: String, key: String, stats: String, chrome := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", CutBox.make(Color(0.035, 0.05, 0.065, 0.95), Color(ChromeBody.CHROME if chrome else Hud.DIM, 0.35), 7, 0b0101, Color(0, 0, 0, 0), 5))
	var h := UiKit.hbox(8)
	p.add_child(h)
	var l := UiKit.label(slot, 12, Hud.DIM)
	l.custom_minimum_size.x = 92
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var mid := UiKit.vbox(-2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	if nm == "":
		mid.add_child(UiKit.body("— empty —", 14, Hud.DIM, false))
		return p
	var nl := UiKit.hbox(6)
	mid.add_child(nl)
	var name_l := UiKit.body(nm, 15, Hud.TEXT, false)
	nl.add_child(UiKit.fit(QualityText.apply(name_l, key) if key != "" else name_l))
	if chrome:
		nl.add_child(UiKit.chip("◆ CHROME", ChromeBody.CHROME))
	if stats != "":
		var s := UiKit.fit(UiKit.body(stats, 13, Hud.DIM, false))
		s.name = "Stats"
		mid.add_child(s)
	return p


## An installed piece players see: its name, where, what it does; OFFLINE while knocked out.
func _chrome_row(c: Combatant, piece: Dictionary) -> Control:
	var id := String(piece.id)
	var v := UiKit.vbox(0)
	v.name = "Chrome_" + id
	var h := UiKit.hbox(6)
	v.add_child(h)
	h.add_child(UiKit.label(Cyber.display(id), 14, ChromeBody.CHROME))
	if loc == "":
		h.add_child(UiKit.label("· " + Cyber.loc_name(String(piece.loc)), 12, Hud.DIM))
	if int(c.cyber_off.get(Cyber.key(piece), 0)) > 0:
		h.add_child(UiKit.chip("OFFLINE", Hud.RED))
	v.add_child(UiKit.body(Cyber.summary(id), 13, Hud.DIM))
	return v


func _select_crew(i: int) -> void:
	sel = posmod(i, maxi(1, crew.size()))
	_build()


func _unhandled_input(ev: InputEvent) -> void:
	if not visible or not ev is InputEventKey or not ev.pressed:
		return
	var k := ev as InputEventKey
	match k.keycode:
		KEY_Q, KEY_E:
			if not k.echo:
				_select_crew(sel + (-1 if k.keycode == KEY_Q else 1))
		KEY_UP, KEY_DOWN:
			var i := ChromeBody.LOCS.find(loc)
			if i < 0:
				i = -1 if k.keycode == KEY_DOWN else 0
			loc = ChromeBody.LOCS[posmod(i + (-1 if k.keycode == KEY_UP else 1), ChromeBody.LOCS.size())]
			_build()
		KEY_ESCAPE, KEY_L:
			close()
	if is_inside_tree():   # a modal screen: no key reaches the game under it
		get_viewport().set_input_as_handled()
