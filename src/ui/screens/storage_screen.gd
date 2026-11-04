class_name StorageScreen
extends SafehouseScreen
## The Armory: safehouse storage on the left, a loadout per crew member on the right (weapons
## carried in order, head and body armor, kit slot 1 a consumable and slot 2 a utility). Pick a crew
## member, then take gear from storage; STORE puts it back. The WORKSHOP tab is the crew Tech's
## armor upgrades (Upgrade Expertise, CPR core p148), opened from the Workshop room.


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
	var cols := UiKit.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	cols.add_child(_storage())
	var right := UiKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.55
	cols.add_child(right)
	var c := selected()
	right.add_child(UiKit.body("Loadouts. Storage gear goes to the selected crew member: %s." % (c.display_name if c else "nobody"), 15, Hud.DIM, false))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var crew := camp.alive_crew()
	for i in crew.size():
		grid.add_child(_loadout(crew[i], i))
	right.add_child(UiKit.scroller(grid))


# --- Storage ----------------------------------------------------------------------------------

func _storage() -> PanelContainer:
	var p := UiKit.panel(Hud.CYAN, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(6)
	p.add_child(v)
	v.add_child(UiKit.head("Storage", 30))
	var list := UiKit.vbox(4)
	v.add_child(UiKit.scroller(list))
	var c := selected()
	var groups := [["WEAPONS", camp.weapon_options()], ["ARMOR", camp.armor_options()],
		["KIT 1 · CONSUMABLES", _kit_keys(0)], ["KIT 2 · UTILITIES", _kit_keys(1)]]
	var any := false
	for g in groups:
		if (g[1] as Array).is_empty():
			continue
		any = true
		list.add_child(section(String(g[0])))
		for k in g[1]:
			list.add_child(_storage_row(String(k), c))
	if not any:
		list.add_child(none("Storage is empty. The Night Market and the always-on-sale stock are at the Fixer Network."))
	var go := UiKit.button("NIGHT MARKET ›", UiKit.NAV, func(): navigate.emit("market"))
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(go)
	return p


func _kit_keys(slot: int) -> Array[String]:
	var out: Array[String] = []
	for k in camp.stash:
		if Items.fits(slot, String(k)) and camp.stored(String(k)) > 0:
			out.append(String(k))
	return out


func _storage_row(key: String, c: Combatant) -> Control:
	var row := UiKit.hbox(6)
	var v := UiKit.vbox(-2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var n := camp.stored(key)
	var kit := Items.is_item(key)
	var packed := n - camp.unpacked(key) if kit else 0
	v.add_child(UiKit.fit(UiKit.label("%s  ×%d" % [Items.display_name(key), n], 15, Hud.TEXT)))
	var info := Campaign.item_info(key)
	if packed > 0:
		info = ("%d packed · " % packed) + info
	v.add_child(UiKit.fit(UiKit.body(info, 13, Hud.DIM, false)))
	if c == null:
		return row
	if Items.is_weapon(key):
		row.add_child(_small("CARRY", UiKit.NEUTRAL, func(b): act(b, func(): camp.equip_weapon(c, key), "%s carries it" % c.display_name), camp.equip_block(c, key) == ""))
	elif Items.is_armor(key):
		for loc in ["head", "body"]:
			var l: String = loc
			row.add_child(_small("WEAR " + l, UiKit.NEUTRAL, func(b): act(b, func(): camp.equip_armor(c, l, key), "%s wears it" % c.display_name), camp.equip_block(c, key, l) == ""))
	elif kit:
		var slot := 0 if Items.fits(0, key) else 1
		var has := c.kit[slot] == key
		var free := camp.unpacked(key, c, slot) > 0 and not has
		row.add_child(_small("PACK" if free else ("PACKED" if has else "ALL PACKED"), UiKit.NEUTRAL,
			func(bt): act(bt, func(): camp.set_kit(c, slot, key), "Packed in kit %d" % (slot + 1)), free))
	return row


## A compact button for list rows; `cb` gets the button (for its toast).
func _small(text: String, style: String, cb: Callable, enabled := true) -> Button:
	var b := UiKit.button(text, style, Callable(), enabled, 13, true)
	b.pressed.connect(func(): cb.call(b))
	return b


# --- Loadouts ---------------------------------------------------------------------------------

func _loadout(c: Combatant, i: int) -> PanelContainer:
	var on := i == sel
	var p := UiKit.selected_panel(9) if on else UiKit.panel(Hud.CYAN, 9)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(3)
	p.add_child(v)
	var head := UiKit.hbox(8)
	v.add_child(head)
	head.add_child(UiKit.portrait(portraits, c, 1000 + maxi(0, c.look_seed), 34))
	head.add_child(UiKit.fit(UiKit.head(c.display_name, 28, Hud.GOLD if on else Hud.TEXT)))
	var st := UiKit.label("SELECTED" if on else "SELECT", 12, Hud.GOLD if on else Hud.CYAN)
	head.add_child(st)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	v.add_child(grid)
	for wi in c.weapons.size():
		var w: Weapon = c.weapons[wi]
		var idx := wi
		var btns := UiKit.hbox(4)
		if wi > 0:
			btns.add_child(_small("▲", UiKit.NEUTRAL, func(_b): camp.reorder_weapon(c, idx, idx - 1); refresh()))
		if not w.builtin:
			btns.add_child(_small("STORE", UiKit.NEUTRAL, func(b): act(b, func(): camp.unequip_weapon(c, idx), "To storage")))
		_slot_row(grid, "WEAPON %d" % (wi + 1), w.display_name() + (" (chrome)" if w.builtin else ""), btns, Hud.VIOLET.lightened(0.3) if w.builtin else Hud.TEXT)
	if c.weapons.is_empty():
		_slot_row(grid, "WEAPON", "none", Control.new(), Hud.DIM)
	for loc in ["head", "body"]:
		var l: String = loc
		var a: ArmorPiece = c.armor.get(l)
		var btns := UiKit.hbox(4)
		if a:
			btns.add_child(_small("STORE", UiKit.NEUTRAL, func(b): act(b, func(): camp.unequip_armor(c, l), "To storage")))
		_slot_row(grid, l, short_armor(a) if a else "none", btns, Hud.TEXT if a else Hud.DIM)
	for slot in c.kit.size():
		var s: int = slot
		var key: String = c.kit[slot]
		var btns := UiKit.hbox(4)
		if key != "":
			btns.add_child(_small("UNPACK", UiKit.NEUTRAL, func(b): act(b, func(): camp.set_kit(c, s, ""), "Unpacked")))
		_slot_row(grid, "KIT %d" % (slot + 1), Items.display_name(key) if key != "" else "empty",
			btns, Hud.TEXT if key != "" else Hud.DIM)
	var idx2 := i
	UiKit.clickable(p, func(): sel = idx2; _build())
	return p


func _slot_row(grid: GridContainer, slot: String, item: String, btns: Control, col: Color) -> void:
	var l := UiKit.label(slot, 12, Hud.DIM)
	l.custom_minimum_size.x = 64
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	var n := UiKit.fit(UiKit.label(item, 14, col))
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(n)
	btns.custom_minimum_size.y = 28
	grid.add_child(btns)


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
	var need := ArmorPiece.repair_hours(a.price())
	if need > 72:
		return "repair %d/%d days" % [a.repair_work / 24, need / 24]
	return "repair %d/%d h" % [a.repair_work, need]


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
