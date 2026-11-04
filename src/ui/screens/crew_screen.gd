class_name CrewScreen
extends SafehouseScreen
## The Bunks: each crew member's STATs, Skills, Role Rank, Improvement Points and Reputation; their
## condition (HP and Wound State, Critical Injuries, addictions, Humanity, chrome); their gear with
## armor repair progress; and what the last gig changed. Rest lives here: Recover heals BODY HP a
## day (CPR core p223) while the crew's best hand at Basic Tech repairs worn armor (p140).


func room_name() -> String:
	return "BUNKS"


func title() -> String:
	return "Crew"


func build_body(body: VBoxContainer) -> void:
	var crew := camp.alive_crew()
	var cols := UiKit.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var left := crew_picker(func(m): return "REPUTATION %d · %d IP" % [m.reputation, m.ip], 270, camp.marks_for)
	cols.add_child(left)
	if not camp.fallen.is_empty():
		left.add_child(section("FLATLINED", Hud.DIM))
		for f in camp.fallen.slice(-4):
			left.add_child(UiKit.body("%s · %s · day %d" % [String(f.name), String(f.role).capitalize(), int(f.day)], 13, Hud.DIM))
	if crew.is_empty():
		cols.add_child(none("Nobody is left on the crew."))
		return
	var c := selected()
	var right := UiKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var head := UiKit.hbox(14)
	right.add_child(head)
	head.add_child(UiKit.portrait(portraits, c, 1000 + maxi(0, c.look_seed), 64))
	var hv := UiKit.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(UiKit.head(c.display_name, 36))
	hv.add_child(UiKit.label("%s · RANK %d · %d IP · REPUTATION %d" % [c.role, c.role_rank, c.ip, c.reputation], 15, Hud.CYAN))
	head.add_child(_recover())
	var grid := UiKit.hbox(10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(grid)
	grid.add_child(_stats_col(c))
	grid.add_child(_condition_col(c))
	grid.add_child(_gear_col(c))


func _recover() -> VBoxContainer:
	var left := UiKit.vbox(4)
	left.custom_minimum_size.x = 300
	var days := camp.days_to_recover()
	var b := UiKit.button("RECOVER UNTIL HEALED · %d DAY%s" % [days, "" if days == 1 else "S"] if days > 0 else "EVERYONE IS AT FULL HP", UiKit.HEALTH, Callable(), days > 0)
	b.pressed.connect(func(): act(b, func(): camp.recover_until_healed(), "Rested %d day%s" % [days, "" if days == 1 else "s"]))
	left.add_child(b)
	var one := UiKit.button("RECOVER 1 DAY", UiKit.HEALTH, Callable())
	one.pressed.connect(func(): act(one, func(): camp.rest(1), "Rested 1 day"))
	left.add_child(one)
	left.add_child(UiKit.body("Rest heals BODY HP a day and the crew repairs worn armor. Critical Injuries need Treatment (Med Bay).", 12, Hud.DIM))
	return left


func _col(heading: String) -> Array:
	var p := UiKit.panel(Hud.CYAN, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(5)
	p.add_child(v)
	v.add_child(section(heading))
	var inner := UiKit.vbox(5)
	v.add_child(UiKit.scroller(inner))
	return [p, inner]


func _stats_col(c: Combatant) -> PanelContainer:
	var x := _col("STATS")
	var v: VBoxContainer = x[1]
	v.add_child(FixerScreen.stat_grid(c))
	v.add_child(section("SKILLS"))
	var sk: Array = c.skills.keys().filter(func(k): return int(c.skills[k]) > 0)
	sk.sort_custom(func(a, b): return c.skill_base(a) > c.skill_base(b))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 0)
	v.add_child(g)
	for k in sk:
		var nm := UiKit.fit(UiKit.label(String(RulesDB.skill(k).get("name", k)), 13, Hud.TEXT))
		nm.custom_minimum_size.x = 130
		g.add_child(nm)
		var n := UiKit.label("%d (%d)" % [int(c.skills[k]), c.skill_base(k)], 13, Hud.DIM)
		g.add_child(n)
	v.add_child(UiKit.body("Level (STAT + Level)", 12, Hud.DIM))
	return x[0]


func _condition_col(c: Combatant) -> PanelContainer:
	var x := _col("CONDITION")
	var v: VBoxContainer = x[1]
	v.add_child(UiKit.label("HP %d/%d · %s" % [c.hp, c.max_hp(), Campaign.WOUND_NAMES[c.wound_state()]], 17, UiKit.hp_colour(c)))
	v.add_child(UiKit.label("SERIOUSLY WOUNDED AT %d · DEATH SAVE %d" % [c.seriously_wounded_threshold(), c.death_save_target()], 12, Hud.DIM))
	v.add_child(section("CRITICAL INJURIES"))
	if c.injuries.is_empty():
		v.add_child(none("None."))
	for inj in c.injuries:
		v.add_child(UiKit.label("%s (%s)" % [String(inj.get("name", "injury")), String(inj.get("location", ""))], 14, Hud.RED))
	v.add_child(section("ADDICTION"))
	if c.addictions.is_empty():
		v.add_child(none("None."))
	for d in c.addictions:
		v.add_child(UiKit.label("Addicted to " + String(RulesDB.gear("drugs", d).get("name", d)), 14, Hud.RED))
	if c.tracks_humanity:
		v.add_child(section("HUMANITY"))
		v.add_child(UiKit.label("%d/%d · EMP %d" % [c.humanity, c.max_humanity, c.raw_stat("EMP")], 15, MedBayScreen._hum_colour(c)))
		if c.psychosis_tier() > 0:
			v.add_child(UiKit.body("At risk of cyberpsychosis. Therapy helps (Med Bay).", 13, Hud.RED))
	v.add_child(section("CYBERWARE"))
	if c.cyberware.is_empty():
		v.add_child(none("None."))
	for cw in c.cyberware:
		v.add_child(UiKit.label(String(RulesDB.cyberware(String(cw)).get("name", cw)), 14, Hud.VIOLET.lightened(0.35)))
	return x[0]


func _gear_col(c: Combatant) -> PanelContainer:
	var x := _col("WEAPONS")
	var v: VBoxContainer = x[1]
	for i in c.weapons.size():
		var w: Weapon = c.weapons[i]
		v.add_child(UiKit.fit(UiKit.label("%d · %s" % [i + 1, w.display_name()], 14, Hud.VIOLET.lightened(0.35) if w.builtin else Hud.TEXT)))
	v.add_child(section("ARMOR"))
	for loc in ["head", "body"]:
		var a: ArmorPiece = c.armor.get(loc)
		v.add_child(UiKit.fit(UiKit.label("%s · %s" % [loc, StorageScreen.short_armor(a) if a else "none"], 14, Hud.TEXT if a else Hud.DIM)))
		if a and a.sp < a.max_sp:
			v.add_child(UiKit.label("   " + StorageScreen.repair_text(a), 12, Hud.CYAN))
	for s in c.kit.size():
		v.add_child(section(Items.slot_name(s)))
		v.add_child(UiKit.fit(UiKit.label(Items.display_name(c.kit[s]) if c.kit[s] != "" else "none", 14, Hud.TEXT if c.kit[s] != "" else Hud.DIM)))
	var b := UiKit.button("LOADOUTS ›", UiKit.NAV, func(): navigate.emit("storage"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(b)
	return x[0]
