class_name StorageScreen
extends SafehouseScreen
## The Armory (owner-approved layout C): the CREW rail on the left (each member's gear at a
## glance, the squad's gaps at the bottom), the selected member's slots in the middle (weapons in
## draw order, head and body armour, consumable and utility), and STORAGE on the right, filtered to
## what fits the selected slot, with a THIS vs NOW comparison (and, for guns, an overlaid
## hit-chance-by-range chart) above one verb each way: EQUIP and STORE. Cyberware waits in storage
## until the Med Bay installs it; installed chrome weapons are changed there too. The WORKSHOP tab is
## the crew Tech's armour upgrades (Upgrade Expertise, CPR core p148); the same upgrade is offered
## in an armour slot's detail.
##
## Keys: Q/E crew, ↑/↓ slot, ←/→ storage item, Enter equip, Del store, Ctrl+↑/↓ reorder weapons,
## Esc back.

## Sort order of the storage list (Loadout.SORTS), kept for the session.
static var sort_mode := "damage"

var slot := "w0"          ## the selected slot (Loadout slot id)
var filter := ""          ## the storage filter chip; "" follows the slot
var pick := ""            ## the selected storage key
var _keys: Array[String] = []
var _scrolls := {}        ## name → the ScrollContainer built this time
var _saved := {}          ## name → scroll position before the rebuild
var _equip_btn: Button
var _store_btn: Button
var _sel_rows := {}       ## scroller name → the selected row in it (kept in view)

const SORT_NAMES := {"name": "NAME", "damage": "DAMAGE", "sp": "SP", "count": "COUNT"}
const FILTER_NAMES := {"all": "ALL", "weapons": "WEAPONS", "armor": "ARMOR", "consumable": "CONSUMABLE", "utility": "UTILITY"}


func setup(p_camp: Campaign, p_portraits: Portraits, p_tab := "", p_sel := 0) -> SafehouseScreen:
	super.setup(p_camp, p_portraits, p_tab, p_sel)
	if p_camp.has_meta("demo"):   # DEV ONLY review shots: --slot=head --pick=weapon/medium_pistol --filter=all
		for a in OS.get_cmdline_user_args():
			var k := a.trim_prefix("--").get_slice("=", 0)
			var val := a.get_slice("=", 1)
			match k:
				"slot": slot = val
				"pick": pick = val
				"filter": filter = val
	return self


func room_name() -> String:
	return "WORKSHOP" if tab == "workshop" else "ARMORY"


func title() -> String:
	return "Workshop" if tab == "workshop" else "Storage & Loadouts"


func tabs() -> Array:
	return [["loadouts", "STORAGE & LOADOUTS"], ["workshop", "WORKSHOP"]]


func build_body(body: VBoxContainer) -> void:
	if tab == "workshop":
		_workshop(body)
		return
	_save_scroll()
	var c := selected()
	_settle(c)
	var wide := is_inside_tree() and get_viewport_rect().size.x >= 1200.0
	var cols := UiKit.hbox(10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	cols.add_child(_crew_rail(wide))
	if c == null:
		cols.add_child(none("No crew. Hire at the Fixer Network."))
		return
	cols.add_child(_slots_panel(c, wide))
	cols.add_child(_storage_panel(c, wide))
	_restore_scroll()


## Keep the selection valid after any change: a slot the member has, the storage list for the
## filter, and a picked item from it (the first that fits the slot).
func _settle(c: Combatant) -> void:
	var all := Loadout.slots(c)
	if not slot in all:
		var wi := Loadout.weapon_index(slot)
		slot = ("w%d" % (c.weapons.size() - 1) if c and not c.weapons.is_empty() else "wadd") if wi >= 0 else (all[0] if not all.is_empty() else "wadd")
	_keys = Loadout.storage_keys(camp, _filter(), sort_mode)
	if not pick in _keys:
		pick = ""
		for k in _keys:
			if Loadout.fits(slot, k):
				pick = k
				break
		if pick == "" and not _keys.is_empty() and filter != "":
			pick = _keys[0]


func _filter() -> String:
	return filter if filter != "" else Loadout.filter_for(slot)


func _select_slot(id: String) -> void:
	if id != slot:
		slot = id
		filter = ""
		pick = ""
	_build()


func _select_crew(i: int) -> void:
	sel = posmod(i, maxi(1, camp.alive_crew().size()))
	pick = ""
	_build()


# --- Crew rail --------------------------------------------------------------------------------

func _crew_rail(wide: bool) -> PanelContainer:
	var p := UiKit.panel(Hud.CYAN, 8)
	p.custom_minimum_size.x = 236 if wide else 214
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(6)
	p.add_child(v)
	v.add_child(section("CREW · Q / E"))
	var cards := UiKit.vbox(6)
	var sc := UiKit.scroller(cards)
	_track("crew", sc)
	v.add_child(sc)
	var crew := camp.alive_crew()
	for i in crew.size():
		var card := _crew_card(crew[i], i == sel)
		var idx := i
		UiKit.clickable(card, func(): _select_crew(idx))
		card.mouse_filter = Control.MOUSE_FILTER_PASS   # the wheel still scrolls the list
		cards.add_child(card)
		if i == sel:
			_sel_rows["crew"] = card
	var warn := Loadout.warnings(camp)
	if not warn.is_empty():
		var box := UiKit.panel(Hud.CYAN, 6)
		var wl := UiKit.vbox(1)
		box.add_child(wl)
		for w in warn:
			wl.add_child(UiKit.body("⚠ " + w, 12, Hud.CYAN))
		v.add_child(box)
	return p


func _crew_card(c: Combatant, on: bool) -> PanelContainer:
	var card := UiKit.selected_panel(6) if on else UiKit.panel(Hud.CYAN, 6)
	var v := UiKit.vbox(3)
	card.add_child(v)
	var h := UiKit.hbox(8)
	v.add_child(h)
	h.add_child(UiKit.portrait(portraits, c, 1000 + maxi(0, c.look_seed), 34))
	var t := UiKit.vbox(-3)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	t.add_child(UiKit.fit(UiKit.head(c.display_name, 28, Hud.GOLD if on else Hud.TEXT)))
	var rh := UiKit.hbox(5)
	rh.add_child(UiKit.label(c.role + " ·", 12, Hud.DIM))
	rh.add_child(UiKit.label("HP %d/%d" % [c.hp, c.max_hp()], 12, UiKit.hp_colour(c)))
	t.add_child(rh)
	var chips := UiKit.hbox(3)
	v.add_child(chips)
	var nw := c.weapons.size()
	chips.add_child(_gear_chip("W·%d" % nw, "full" if nw > 0 else "missing"))
	for loc in ["head", "body"]:
		var a: ArmorPiece = c.armor.get(loc)
		chips.add_child(_gear_chip(loc.to_upper(), "empty" if a == null else ("bad" if a.sp < a.max_sp else "full")))
	chips.add_child(_gear_chip("CONS", "full" if c.kit[0] != "" else "missing"))
	chips.add_child(_gear_chip("UTIL", "full" if c.kit[1] != "" else "empty"))
	return card


## A gear chip on the crew rail: filled (text), empty (dim, dashed), missing (cyan: the squad
## should fix it) or bad (red: ablated armour).
static func _gear_chip(text: String, state: String) -> PanelContainer:
	var col: Color = {"full": Hud.TEXT, "empty": Color(Hud.DIM, 0.6), "missing": Hud.CYAN, "bad": Hud.RED}[state]
	var p := PanelContainer.new()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UiKit.label(text, 11, col))
	p.draw.connect(func():
		var r := Rect2(Vector2(0.5, 0.5), p.size - Vector2(1, 1))
		if state == "empty":
			for seg in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
					[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
				p.draw_dashed_line(seg[0], seg[1], Color(Hud.DIM, 0.55), 1.0, 3.0)
		else:
			p.draw_rect(r, Color(col, 0.75 if state != "full" else 0.35), false, 1.0))
	return p


# --- Slots ------------------------------------------------------------------------------------

func _slots_panel(c: Combatant, wide: bool) -> PanelContainer:
	var p := UiKit.panel(Hud.CYAN, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(4)
	p.add_child(v)
	var head := UiKit.hbox(10)
	v.add_child(head)
	head.add_child(UiKit.head(c.display_name, 30, Hud.GOLD))
	var who := UiKit.hbox(6)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(UiKit.label("%s · RANK %d ·" % [c.role, c.role_rank], 13, Hud.CYAN))
	who.add_child(UiKit.label("HP %d/%d" % [c.hp, c.max_hp()], 13, UiKit.hp_colour(c)))
	head.add_child(who)
	var list := UiKit.vbox(3)
	var sc := UiKit.scroller(list)
	_track("slots", sc)
	v.add_child(sc)
	list.add_child(_group("WEAPONS"))
	for i in c.weapons.size():
		list.add_child(_slot_row(c, "w%d" % i))
	list.add_child(_add_row())
	list.add_child(_group("ARMOR"))
	for loc in ["head", "body"]:
		list.add_child(_slot_row(c, loc))
	list.add_child(_group("KIT"))
	for i in c.kit.size():
		list.add_child(_slot_row(c, "k%d" % i))
	if wide:   # at 1600x900 (the tightest logical screen) the buttons carry the keys instead
		v.add_child(UiKit.label("↑↓ SLOT · CTRL+↑↓ ORDER · ←→ ITEM · Q/E CREW · ESC BACK", 11, Hud.DIM))
	return p


## A slot group's heading (WEAPONS, ARMOR, KIT).
static func _group(text: String) -> Label:
	var l := UiKit.label(text, 12, Hud.CYAN)
	l.custom_minimum_size.y = 18
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


## A row's panel: gold edge and accent when selected.
static func _row_panel(on: bool, edge := Hud.DIM) -> PanelContainer:
	var p := PanelContainer.new()
	var fill := Color(0.11, 0.09, 0.02, 0.95) if on else Color(0.035, 0.05, 0.065, 0.95)
	var s := CutBox.make(fill, Hud.GOLD if on else Color(edge, 0.35), 7, 0b0101, Hud.GOLD if on else Color(0, 0, 0, 0), 5)
	p.add_theme_stylebox_override("panel", s)
	return p


func _slot_row(c: Combatant, id: String) -> PanelContainer:
	var on := id == slot
	var key := Loadout.slot_key(c, id)
	var chrome := Loadout.is_chrome(c, id)
	var p := _row_panel(on, Hud.VIOLET if chrome else Hud.DIM)
	var h := UiKit.hbox(8)
	p.add_child(h)
	var l := UiKit.label(Loadout.slot_label(id), 12, Hud.GOLD if on else Hud.DIM)
	l.custom_minimum_size.x = 84
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var mid := UiKit.vbox(-2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mid)
	if key == "":
		mid.add_child(UiKit.fit(UiKit.body("— empty — click to fill", 14, Hud.DIM, false)))
	else:
		var nl := UiKit.hbox(6)
		mid.add_child(nl)
		var wi := Loadout.weapon_index(id)
		var nm := Items.display_name(key)
		if wi >= 0:
			nm = Loadout.chrome_name(c, c.weapons[wi]) if chrome else c.weapons[wi].display_name()
		elif Loadout.is_armor_slot(id):
			var a: ArmorPiece = c.armor[id]
			nm = a.name + (" +1" if a.upgraded else "")
		nl.add_child(UiKit.fit(QualityText.apply(UiKit.body(nm if nm != "" else Items.display_name(key), 14, Hud.TEXT, false), key)))
		if chrome:
			nl.add_child(UiKit.chip("◆ CHROME", Hud.VIOLET.lightened(0.3)))
		mid.add_child(_slot_stats(c, id))
	var btns := UiKit.hbox(4)
	btns.custom_minimum_size.x = 64
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(btns)
	var wi2 := Loadout.weapon_index(id)
	if on and wi2 >= 0 and c.weapons.size() > 1:
		var up := _small("▲", UiKit.NEUTRAL, func(_b): _reorder(-1), wi2 > 0)
		up.tooltip_text = "Draw earlier (Ctrl+↑)"
		btns.add_child(up)
		var dn := _small("▼", UiKit.NEUTRAL, func(_b): _reorder(1), wi2 < c.weapons.size() - 1)
		dn.tooltip_text = "Draw later (Ctrl+↓)"
		btns.add_child(dn)
	if chrome:
		var mb := _small("MED BAY", UiKit.CHROME, func(_b): navigate.emit("ripperdoc"))
		mb.tooltip_text = "Installed cyberware: change it at the Med Bay"
		btns.add_child(mb)
	elif key != "":
		var ids := id
		btns.add_child(_small("STORE", UiKit.NEUTRAL, func(b): _store(b, ids)))
	var idc := id
	UiKit.clickable(p, func(): _select_slot(idc))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	if on:
		_sel_rows["slots"] = p
	return p


## The stats line under a slot's item: ablated SP in red.
func _slot_stats(c: Combatant, id: String) -> Control:
	var h := UiKit.hbox(0)
	if Loadout.is_armor_slot(id):
		var a: ArmorPiece = c.armor[id]
		if a.sp < a.max_sp:
			h.add_child(UiKit.body("SP %d" % a.sp, 12, Hud.RED, false))
			h.add_child(UiKit.fit(UiKit.body("/%d · %s" % [a.max_sp, Loadout.repair_text(a)], 12, Hud.DIM, false)))
			return h
	h.add_child(UiKit.fit(UiKit.body(Loadout.slot_stats(c, id), 12, Hud.DIM, false)))
	return h


func _add_row() -> PanelContainer:
	var on := slot == "wadd"
	var p := _row_panel(on, Hud.CYAN)
	var l := UiKit.label("+ ADD WEAPON", 13, Hud.GOLD if on else Hud.CYAN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	UiKit.clickable(p, func(): _select_slot("wadd"))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	if on:
		_sel_rows["slots"] = p
	return p


# --- Storage ----------------------------------------------------------------------------------

func _storage_panel(c: Combatant, wide: bool) -> PanelContainer:
	var p := UiKit.panel(Hud.CYAN, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(5)
	p.add_child(v)
	var top := UiKit.hbox(6)
	v.add_child(top)
	var hl := section("STORAGE")
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hl)
	top.add_child(UiKit.spacer())
	top.add_child(_small("SORT: %s ▾" % SORT_NAMES[sort_mode], UiKit.NAV, func(_b):
		sort_mode = Loadout.SORTS[(Loadout.SORTS.find(sort_mode) + 1) % Loadout.SORTS.size()]
		_build()))
	var chips := UiKit.flow(4)
	v.add_child(chips)
	var f := _filter()
	for id in Loadout.FILTERS:
		var fid: String = id
		var b := _small(FILTER_NAMES[fid], UiKit.PRIMARY if fid == f else UiKit.NEUTRAL, func(_b): filter = fid; pick = ""; _build())
		b.add_theme_font_size_override("font_size", 12)
		if fid == f:
			b.add_theme_stylebox_override("normal", UiKit._btn_box(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, true))
		chips.add_child(b)
	var now := Loadout.slot_key(c, slot)
	var fits := "Fits %s · " % Loadout.slot_label(slot)
	fits += ("comparing with %s" % _slot_name(c, slot)) if now != "" else "the slot is empty"
	if f != Loadout.filter_for(slot):
		fits = "Showing %s · picking an item selects its slot" % FILTER_NAMES[f]
	v.add_child(UiKit.fit(UiKit.body(fits, 13, Hud.DIM, false)))
	var list := UiKit.vbox(4)
	var sc := UiKit.scroller(list)
	_track("storage", sc)
	v.add_child(sc)
	for k in _keys:
		list.add_child(_storage_row(c, k, now))
	if _keys.is_empty():
		list.add_child(none("Nothing in storage fits %s. Gear is bought at the Fixer Network: the Night Market's, and anything up to Premium any time." % Loadout.slot_label(slot)))
		var go := UiKit.button("NIGHT MARKET ›", UiKit.NAV, func(): navigate.emit("market"), true, 13, true)
		go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		list.add_child(go)
	v.add_child(_detail(c, now, wide))
	if not camp.leads.is_empty():
		v.add_child(leads_box(camp))
	return p


## The plot hooks found on bodies (Campaign.leads, CorpseLoot), newest first: a later fixer offer
## can follow one up. Up to LEADS_SHOWN, then how many more.
const LEADS_SHOWN := 6


static func leads_box(cp: Campaign) -> Control:
	var v := UiKit.vbox(3)
	var head := UiKit.hbox(8)
	v.add_child(head)
	head.add_child(UiKit.label("LEADS · %d" % cp.leads.size(), 12, Hud.MAGENTA))
	head.add_child(UiKit.label("found on bodies; a fixer may follow one up", 12, Hud.DIM))
	var flow := UiKit.flow(14)
	v.add_child(flow)
	var shown := 0
	for i in range(cp.leads.size() - 1, -1, -1):
		if shown >= LEADS_SHOWN:
			break
		var l: Dictionary = cp.leads[i]
		var where := String(l.get("gig", ""))
		flow.add_child(UiKit.body("%s%s" % [String(l.get("label", "")), (" (" + where + ")") if where != "" else ""], 13, Hud.TEXT, false))
		shown += 1
	if cp.leads.size() > shown:
		flow.add_child(UiKit.body("+%d more" % (cp.leads.size() - shown), 13, Hud.DIM, false))
	return v


## The name of what's in a slot, as the loadout shows it.
func _slot_name(c: Combatant, id: String) -> String:
	var wi := Loadout.weapon_index(id)
	if wi >= 0 and wi < c.weapons.size():
		var w: Weapon = c.weapons[wi]
		return Loadout.chrome_name(c, w) if w.builtin else w.display_name()
	if Loadout.is_armor_slot(id) and c.armor.get(id):
		return (c.armor[id] as ArmorPiece).name
	var key := Loadout.slot_key(c, id)
	return Items.display_name(key) if key != "" else "nothing"


func _storage_row(c: Combatant, key: String, now: String) -> PanelContainer:
	var on := key == pick
	var chrome := Items.is_cyberware(key)
	var p := _row_panel(on, Hud.VIOLET if chrome else Hud.DIM)
	var v := UiKit.vbox(-2)
	p.add_child(v)
	var l1 := UiKit.hbox(6)
	v.add_child(l1)
	var nm := UiKit.fit(QualityText.apply(UiKit.body(Items.display_name(key), 15, Hud.VIOLET.lightened(0.35) if chrome else Hud.TEXT, false), key))
	nm.size_flags_stretch_ratio = 1.6
	l1.add_child(nm)
	if chrome:
		l1.add_child(UiKit.chip("◆ CHROME", Hud.VIOLET.lightened(0.3)))
	var ct := UiKit.fit(UiKit.body(Loadout.count_text(camp, key), 12, Hud.DIM, false))
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l1.add_child(ct)
	var l2 := UiKit.hbox(8)
	v.add_child(l2)
	l2.add_child(UiKit.body(Loadout.stats(key) if not chrome else Campaign.item_info(key), 12, Hud.DIM, false))
	if Loadout.fits(slot, key):
		for d in Loadout.deltas(key, now):
			var col: Color = Hud.GREEN if int(d[1]) > 0 else (Hud.RED if int(d[1]) < 0 else Hud.DIM)
			l2.add_child(UiKit.body(String(d[0]), 12, col, false))
	l2.add_child(UiKit.spacer())
	var block := Loadout.equip_block(camp, c, slot if Loadout.fits(slot, key) else Loadout.best_slot(c, key), key) if not chrome else ""
	if block == "all assigned":
		p.modulate = Color(1, 1, 1, 0.5)
	var k := key
	UiKit.clickable(p, func(): _pick(k))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
			_equip(_equip_btn))
	if on:
		_sel_rows["storage"] = p
	return p


## Select a storage item; one that doesn't fit the selected slot selects the slot it goes in.
func _pick(key: String) -> void:
	pick = key
	var c := selected()
	if not Loadout.fits(slot, key):
		var to := Loadout.best_slot(c, key)
		if to != "":
			slot = to
	_build()


# --- Detail and comparison --------------------------------------------------------------------

func _detail(c: Combatant, now: String, wide: bool) -> PanelContainer:
	var p := UiKit.panel(Hud.GOLD, 9)
	var v := UiKit.vbox(3)
	p.add_child(v)
	_equip_btn = null
	_store_btn = null
	var show := pick if pick != "" else now
	if show == "":
		v.add_child(UiKit.head(Loadout.slot_label(slot), 28, Hud.DIM))
		v.add_child(UiKit.body("Empty, and nothing in storage fits it.", 13, Hud.DIM, false))
		return p
	v.add_child(UiKit.fit(QualityText.apply(UiKit.head(Items.display_name(show), 28, Hud.GOLD if pick != "" else Hud.TEXT), show)))
	v.add_child(UiKit.fit(UiKit.body(_subtitle(show), 12, Hud.DIM, false)))
	if Items.is_cyberware(show):
		v.add_child(UiKit.body("Waiting in storage: the Med Bay's ripperdoc installs it on whoever it's for.", 13, Hud.TEXT))
		var mb := UiKit.button("MED BAY ›", UiKit.CHROME, func(): navigate.emit("ripperdoc"), true, 13, true)
		mb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(mb)
		return p
	var row := UiKit.hbox(12)
	v.add_child(row)
	var table := _compare_table(pick, now) if pick != "" else _compare_table(now, "", true)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(table)
	row.add_child(_actions(c, now))
	if Items.is_weapon(show) or Items.is_weapon(now):
		v.add_child(_chart(c, now, wide))
	if Loadout.is_armor_slot(slot) and c.armor.get(slot):
		v.add_child(_workshop_strip(c))
	return p


## "Handgun · Premium 100 eb · CPR core p.94".
func _subtitle(key: String) -> String:
	var parts: Array[String] = []
	var cite := ""
	if Items.is_weapon(key):
		var w := Items.make_weapon(key)
		parts.append(String(RulesDB.skill(w.skill()).get("name", w.skill())) if w.skill() != "autofire" else "Autofire")
		parts.append("%d-handed" % int(w.def.get("hands", 1)))
		if w.quality != "standard":   # the name shows quality as typography only
			parts.insert(0, QualityText.quality_note(key))
		cite = String(w.def.get("cite", ""))
	elif Items.is_armor(key):
		parts.append("Armor · head or body")
		cite = String(RulesDB.armor(Items.base_id(key)).get("cite", ""))
	elif Items.is_item(key):
		parts.append("%s · %s" % [Items.kind(key).capitalize(), Items.use(key)])
		cite = String(Items.def(key).get("cite", ""))
	var eb := Items.price(key)
	if eb > 0:
		parts.append("%s %s eb" % [Items.price_tier(eb), UiKit.money(eb)])
	if cite != "":
		parts.append(cite.get_slice(" (", 0).get_slice(",", 0))
	return " · ".join(parts)


## THIS vs NOW. `solo`: only the slot's item (nothing in storage to compare).
func _compare_table(key: String, now: String, solo := false) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2 if solo else 3
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 0)
	g.add_child(Control.new())
	g.add_child(UiKit.label("NOW" if solo else "THIS", 11, Hud.GOLD if not solo else Hud.CYAN))
	if not solo:
		g.add_child(UiKit.label("NOW", 11, Hud.CYAN))
	for r in Loadout.compare_rows(key, now):
		g.add_child(UiKit.label(String(r[0]), 11, Hud.DIM))
		var s := int(r[3])
		var a := UiKit.fit(UiKit.body(String(r[1]), 13, Hud.GREEN if s > 0 else (Hud.RED if s < 0 else Hud.TEXT), false))
		g.add_child(a)
		if not solo:
			g.add_child(UiKit.fit(UiKit.body(String(r[2]), 13, Hud.TEXT, false)))
	return g


func _actions(c: Combatant, now: String) -> Control:
	var box := UiKit.vbox(4)
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	if pick != "":
		var block := Loadout.equip_block(camp, c, slot, pick)
		var eq := UiKit.button("EQUIP · ENTER" if block == "" else block.to_upper(), UiKit.PRIMARY, Callable(), block == "", 13, true)
		if block == "":
			eq.add_theme_stylebox_override("normal", UiKit._btn_box(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, true))
		eq.pressed.connect(func(): _equip(eq))
		_equip_btn = eq
		box.add_child(eq)
	if Loadout.is_chrome(c, slot):
		var mb := UiKit.button("MED BAY ›", UiKit.CHROME, func(): navigate.emit("ripperdoc"), true, 13, true)
		mb.tooltip_text = "Installed cyberware: change it at the Med Bay"
		box.add_child(mb)
	elif now != "":
		var st := UiKit.button("STORE CURRENT · DEL", UiKit.NEUTRAL, Callable(), true, 13, true)
		st.pressed.connect(func(): _store(st, slot))
		_store_btn = st
		box.add_child(st)
	return box


## The overlaid hit-chance-by-range chart for the selected crew member: THIS (gold) and the slot's
## weapon NOW (cyan).
func _chart(c: Combatant, now: String, wide: bool) -> RangeChart:
	var ch := RangeChart.new()
	ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.custom_minimum_size.y = 132 if wide else 104
	var series: Array = []
	if pick != "" and Items.is_weapon(pick):
		series.append({"tag": "THIS", "colour": Hud.GOLD, "width": 4.0, "data": RangeCurve.for_weapon(c, Items.make_weapon(pick))})
	var wi := Loadout.weapon_index(slot)
	if wi >= 0 and wi < c.weapons.size():
		series.append({"tag": "NOW", "colour": Hud.CYAN, "data": RangeCurve.for_weapon(c, c.weapons[wi])})
	ch.set_series(series)
	ch.tooltip_text = "%s's hit chance by range (single shot; dashed: autofire), from the book's range tables, smoothed" % c.display_name
	return ch


## Upgrade Expertise in an armour slot's detail (the Workshop tab lists every piece).
func _workshop_strip(c: Combatant) -> Control:
	var a: ArmorPiece = c.armor[slot]
	var h := UiKit.hbox(8)
	var t := camp.best_tech()
	var l := UiKit.label("WORKSHOP", 11, Hud.CYAN)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	if a.upgraded:
		h.add_child(UiKit.label("UPGRADED +1 SP", 12, Hud.GREEN))
	elif t == null:
		h.add_child(UiKit.fit(UiKit.body("Needs a Tech on the crew to upgrade armor.", 12, Hud.DIM, false)))
	else:
		var days := Campaign.maker_days(a.price())
		var loc := slot
		var b := UiKit.button("UPGRADE +1 SP · %s eb · %d day%s" % [UiKit.money(a.price()), days, "s" if days > 1 else ""], UiKit.PRIMARY, Callable(), camp.eb >= a.price(), 12, true)
		b.tooltip_text = "%s's Upgrade Expertise (CPR core p148): materials cost the piece's price; the crew rests meanwhile" % t.display_name
		b.pressed.connect(func():
			var r := {}
			act(b, func(): r.merge(camp.upgrade_armor(c, loc)), "")
			toast(b, "Upgraded" if r.get("success", false) else "The upgrade failed", Hud.GREEN if r.get("success", false) else Hud.TEXT))
		h.add_child(b)
	return h


# --- Actions and keys -------------------------------------------------------------------------

func _equip(b: Button) -> void:
	var c := selected()
	if c == null or pick == "" or Loadout.equip_block(camp, c, slot, pick) != "":
		return
	var key := pick
	var to := slot
	var ok := false
	var run := func():
		ok = Loadout.equip(camp, c, to, key)
		if ok and to == "wadd":
			slot = "w%d" % (c.weapons.size() - 1)
	if b and b.is_inside_tree():
		act(b, run, "%s equips it" % c.display_name)
	else:
		run.call()
		refresh()


func _store(b: Button, id: String) -> void:
	var c := selected()
	if c == null or Loadout.slot_key(c, id) == "" or Loadout.is_chrome(c, id):
		return
	var run := func():
		var key := Loadout.slot_key(c, id)
		if Loadout.store(camp, c, id):
			pick = Items.key_of_weapon(Items.make_weapon(key)) if Items.is_weapon(key) else key
	if b and b.is_inside_tree():
		act(b, run, "To storage")
	else:
		run.call()
		refresh()


func _reorder(step: int) -> void:
	var to := Loadout.reorder(camp, selected(), slot, step)
	if to != "":
		slot = to
		refresh()


func _move_slot(step: int) -> void:
	var all := Loadout.slots(selected())
	if all.is_empty():
		return
	_select_slot(all[clampi(all.find(slot) + step, 0, all.size() - 1)])


func _move_pick(step: int) -> void:
	if _keys.is_empty():
		return
	_pick(_keys[clampi(_keys.find(pick) + step, 0, _keys.size() - 1)])


func _unhandled_input(ev: InputEvent) -> void:
	if tab != "loadouts" or not ev is InputEventKey or not ev.pressed:
		return
	var k := ev as InputEventKey
	var ctrl := k.ctrl_pressed or k.meta_pressed
	match k.keycode:
		KEY_Q, KEY_E:
			if k.echo:
				return
			_select_crew(sel + (-1 if k.keycode == KEY_Q else 1))
		KEY_UP, KEY_DOWN:
			var step := -1 if k.keycode == KEY_UP else 1
			if ctrl:
				_reorder(step)
			else:
				_move_slot(step)
		KEY_LEFT, KEY_RIGHT:
			_move_pick(-1 if k.keycode == KEY_LEFT else 1)
		KEY_ENTER, KEY_KP_ENTER:
			_equip(_equip_btn)
		KEY_DELETE:
			_store(_store_btn, slot)
		KEY_ESCAPE:
			closed.emit()
		_:
			return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


# --- Scroll and focus across rebuilds ---------------------------------------------------------

func _track(name: String, sc: ScrollContainer) -> void:
	_scrolls[name] = sc


func _save_scroll() -> void:
	for n in _scrolls:
		var sc: ScrollContainer = _scrolls[n]
		if is_instance_valid(sc):
			_saved[n] = sc.scroll_vertical
	_scrolls.clear()
	_sel_rows.clear()


## Put each list back where it was, then bring the selected row into view (after the new layout
## has its sizes: two frames).
func _restore_scroll() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	tree.process_frame.connect(func():
		tree.process_frame.connect(_apply_scroll, CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)


func _apply_scroll() -> void:
	for n in _scrolls:
		var sc: ScrollContainer = _scrolls[n]
		if not is_instance_valid(sc) or sc.is_queued_for_deletion():
			continue
		sc.scroll_vertical = int(_saved.get(n, 0))
		var row: Control = _sel_rows.get(n)
		if is_instance_valid(row):
			sc.ensure_control_visible(row)


## A compact button for list rows; `cb` gets the button (for its toast).
func _small(text: String, style: String, cb: Callable, enabled := true) -> Button:
	var b := UiKit.button(text, style, Callable(), enabled, 13, true)
	b.pressed.connect(func(): cb.call(b))
	return b


## "Light Armorjack · SP 9/11 · repair 1/7 days".
static func armor_text(a: ArmorPiece) -> String:
	var s := "%s%s · SP %d/%d" % [a.name, " +1" if a.upgraded else "", a.sp, a.max_sp]
	if a.sp < a.max_sp:
		s += " · " + repair_text(a)
	return s


## The loadout line: the name, and SP only while it's ablated.
static func short_armor(a: ArmorPiece) -> String:
	return a.name + (" +1" if a.upgraded else "") + (" · SP %d/%d" % [a.sp, a.max_sp] if a.sp < a.max_sp else "")


## Repair progress (Item Repair, p140: time by Price Category; done during rest).
static func repair_text(a: ArmorPiece) -> String:
	return Loadout.repair_text(a)


# --- Workshop ---------------------------------------------------------------------------------

## Upgrade Expertise (p148): the crew's Tech gives a worn armor piece +1 SP, once per item; the
## materials cost the item's price and the work takes downtime by its Price Category.
func _workshop(body: VBoxContainer) -> void:
	var t := camp.best_tech()
	if t == null:
		body.add_child(none("The workshop is dark: it needs a Tech on the crew (hire one at the Fixer Network)."))
		return
	body.add_child(UiKit.body("%s upgrades worn armor: +1 SP, once per piece. Materials cost the piece's price; the crew rests while the work is done. A failed check wastes the time, not the materials." % t.display_name, 15, Hud.DIM))
	var list := UiKit.vbox(6)
	for c in camp.alive_crew():
		for loc in ["head", "body"]:
			var a: ArmorPiece = c.armor.get(loc)
			if a == null:
				continue
			var row := UiKit.hbox(10)
			var p := UiKit.panel(Hud.CYAN, 8)
			p.add_child(row)
			row.add_child(UiKit.fit(UiKit.label("%s · %s · %s" % [c.display_name, loc, armor_text(a)], 15, Hud.TEXT)))
			var l: String = loc
			var cc: Combatant = c
			if a.upgraded:
				row.add_child(UiKit.label("UPGRADED", 13, Hud.GREEN))
			else:
				var days := Campaign.maker_days(a.price())
				var b := UiKit.button("UPGRADE +1 SP · %s eb · %d day%s" % [UiKit.money(a.price()), days, "s" if days > 1 else ""], UiKit.NEUTRAL, Callable(), camp.eb >= a.price())
				b.pressed.connect(func():
					var r := {}
					act(b, func(): r.merge(camp.upgrade_armor(cc, l)), "")
					toast(b, "Upgraded" if r.get("success", false) else "The upgrade failed", Hud.GREEN if r.get("success", false) else Hud.TEXT))
				row.add_child(b)
			list.add_child(p)
	body.add_child(UiKit.scroller(list))
