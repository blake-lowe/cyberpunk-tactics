extends TestCase
## Loadout: the Armory's slots, one-verb EQUIP / STORE, comparison deltas, counts and warnings.


func _camp() -> Campaign:
	return DemoState.make()


func test_slots_in_screen_order() -> void:
	var camp := _camp()
	var c: Combatant = camp.alive_crew()[0]
	var s := Loadout.slots(c)
	assert_eq(s[0], "w0")
	assert_eq(s.slice(c.weapons.size()), ["wadd", "head", "body", "k0", "k1"])
	assert_eq(Loadout.slot_label("w1"), "WEAPON 2")
	assert_eq(Loadout.slot_label("k0"), "CONSUMABLE")
	assert_eq(Loadout.slot_label("k1"), "UTILITY")
	assert_eq(Loadout.filter_for("head"), "armor")
	assert_eq(Loadout.filter_for("wadd"), "weapons")


func test_equip_swaps_a_weapon_in_place_and_store_puts_it_back() -> void:
	var camp := _camp()
	var c: Combatant = camp.alive_crew()[0]
	var first := Items.key_of_weapon(c.weapons[0])
	var n := c.weapons.size()
	assert_true(Loadout.equip(camp, c, "w0", "weapon/medium_pistol"))
	assert_eq(c.weapons.size(), n, "a swap, not an extra weapon")
	assert_eq(c.weapons[0].id(), "medium_pistol", "in the slot that was clicked")
	assert_eq(camp.stored(first), 1, "the old one goes to storage")
	assert_true(Loadout.store(camp, c, "w0"))
	assert_eq(camp.stored("weapon/medium_pistol"), 1)
	assert_true(Loadout.equip(camp, c, "wadd", "weapon/medium_pistol"))
	assert_eq(c.weapons[c.weapons.size() - 1].id(), "medium_pistol", "+ ADD WEAPON carries it last")


func test_chrome_weapons_stay_and_never_store() -> void:
	var camp := _camp()
	var c: Combatant = camp.alive_crew()[0]
	var wi := -1
	for i in c.weapons.size():
		if c.weapons[i].builtin:
			wi = i
	assert_true(wi >= 0, "the demo Solo has chrome")
	var id := "w%d" % wi
	assert_true(Loadout.is_chrome(c, id))
	assert_eq(Loadout.chrome_name(c, c.weapons[wi]), "Wolvers")
	assert_false(Loadout.store(camp, c, id), "changed at the Med Bay, not stored")
	var n := c.weapons.size()
	assert_true(Loadout.equip(camp, c, id, "weapon/medium_pistol"))
	assert_eq(c.weapons.size(), n + 1, "equipping on a chrome slot adds the weapon; the chrome stays")


func test_armor_goes_to_the_selected_location() -> void:
	var camp := _camp()
	var c: Combatant = camp.alive_crew()[0]
	assert_true(Loadout.equip(camp, c, "head", "armor/leathers"))
	assert_eq((c.armor.head as ArmorPiece).id, "leathers")
	assert_eq((c.armor.body as ArmorPiece).id, "light_armorjack", "the body is untouched")
	assert_eq(Loadout.equip_block(camp, c, "head", "weapon/heavy_pistol"), "doesn't fit HEAD")


func test_kit_equip_respects_what_others_hold() -> void:
	var camp := _camp()
	var crew := camp.alive_crew()
	var key := "ammo/armor_piercing_ammo"   # 2 in storage, the demo Solo has one equipped
	assert_eq(Loadout.equip_block(camp, crew[0], "k0", key), "equipped")
	assert_true(Loadout.equip(camp, crew[1], "k0", key))
	assert_eq(Loadout.equip_block(camp, crew[2], "k0", key), "all assigned")
	assert_eq(Loadout.count_text(camp, key), "×2 · 2 with the crew · all assigned")
	assert_true(Loadout.store(camp, crew[1], "k0"))
	assert_eq(Loadout.count_text(camp, key), "×2 · 1 with %s" % crew[0].display_name)
	assert_false(Loadout.fits("k1", key), "a grenade isn't a utility")


func test_deltas_and_compare_rows() -> void:
	assert_eq(Loadout.deltas("weapon/very_heavy_pistol", "weapon/heavy_pistol"), [["+1d6", 1], ["ROF -1", -1]])
	assert_eq(Loadout.deltas("weapon/heavy_pistol", "weapon/heavy_pistol"), [["same", 0]])
	assert_eq(Loadout.deltas("weapon/heavy_pistol", ""), [], "nothing to compare with an empty slot")
	assert_eq(Loadout.deltas("armor/kevlar", "armor/light_armorjack@sp4"), [["SP +3", 1]], "against the ablated SP")
	var rows := Loadout.compare_rows("weapon/heavy_pistol", "weapon/assault_rifle")
	assert_eq(rows[0], ["DAMAGE", "3d6", "5d6", -1])
	assert_eq(rows[3], ["RANGE", "200 m", "800 m", 0])
	assert_eq(Loadout.compare_rows("weapon/light_melee", "")[3], ["RANGE", "2 m", "—", 0])


func test_storage_list_filters_and_sorts() -> void:
	var camp := _camp()
	var weapons := Loadout.storage_keys(camp, "weapons", "damage")
	assert_eq(weapons, ["weapon/heavy_pistol", "weapon/medium_pistol"] as Array[String], "most damage first")
	assert_eq(Loadout.storage_keys(camp, "weapons", "name"), ["weapon/heavy_pistol", "weapon/medium_pistol"] as Array[String])
	assert_true(Loadout.storage_keys(camp, "all", "name").any(func(k): return Items.is_cyberware(k)), "ALL lists chrome waiting for the Med Bay")
	assert_true(Loadout.storage_keys(camp, "consumable", "count").all(func(k): return Items.kind(k) == "consumable"))
	assert_eq(Loadout.best_slot(camp.alive_crew()[0], "ammo/flashbang_ammo"), "k0")
	assert_eq(Loadout.best_slot(camp.alive_crew()[0], "weapon/heavy_pistol"), "wadd")


func test_squad_warnings() -> void:
	var camp := _camp()
	var w := Loadout.warnings(camp)
	assert_true("3 crew have no CONSUMABLE" in w, str(w))
	assert_true(w.any(func(s): return s.ends_with("body armor is ablated")))
	var c: Combatant = camp.alive_crew()[2]
	c.weapons.clear()
	assert_true("%s has no ranged weapon" % c.display_name in Loadout.warnings(camp))


func test_kit_stats_are_short() -> void:
	assert_eq(Loadout.kit_stats("ammo/armor_piercing_ammo"), "6d6 · ablates 2")
	assert_true(Loadout.kit_stats("ammo/flashbang_ammo").begins_with("no damage · DV15"))
	assert_true(Loadout.kit_stats("drugs/synthcoke").begins_with("+1 REF"))
