extends TestCase
## NPC stat blocks (data/rules/npcs.json: CPR core p.412-416, the Hardened DLCs, Night City 2045's
## district blocks): the data resolves, and a block becomes the combatant the book prints.


func test_every_block_resolves_against_the_rules_data() -> void:
	var db: Dictionary = RulesDB.load_json("npcs.json")
	var weapons: Dictionary = RulesDB.load_json("weapons.json")["weapons"]
	var armor: Dictionary = RulesDB.load_json("armor.json")["armor"]
	var cyber: Dictionary = RulesDB.load_json("cyberware.json")
	var skills: Dictionary = RulesDB.load_json("skills.json")["skills"]
	for id in db.blocks:
		var b: Dictionary = db.blocks[id]
		assert_true(db.tiers.has(String(b.tier)), "%s: a real tier" % id)
		assert_true(String(b.get("cite", "")).contains("p."), "%s: cited" % id)
		for s in ["INT", "REF", "DEX", "TECH", "COOL", "WILL", "LUCK", "MOVE", "BODY", "EMP"]:
			assert_true(b.stats.has(s), "%s: %s" % [id, s])
		for s in b.skills:
			assert_true(skills.has(String(s).get_slice(":", 0)), "%s: skill %s" % [id, s])
		for w in b.weapons:
			assert_true(weapons.has(w), "%s: weapon %s" % [id, w])
		for loc in b.armor:
			var a := String(b.armor[loc])
			assert_true(a == "" or armor.has(a) or a in b.get("cyberware", []), "%s: armour %s" % [id, a])
		for cw in b.get("cyberware", []):
			assert_false(RulesDB.cyberware(String(cw)).is_empty(), "%s: cyberware %s" % [id, cw])
		for k in b.get("kit", []):
			assert_false(Items.def(String(k)).is_empty(), "%s: gear %s" % [id, k])
	for t in db.tiers:
		for id in db.tiers[t].blocks:
			assert_eq(String(db.blocks[id].tier), t, "the %s pool holds %s blocks" % [t, t])
			assert_false(bool(db.blocks[id].get("hardened", false)), "%s: hardened blocks stay out of the default pool" % id)
		for id in db.tiers[t].get("hardened_blocks", []):
			assert_eq(String(db.blocks[id].tier), t, "the %s hardened list holds %s blocks" % [t, t])
			assert_true(bool(db.blocks[id].get("hardened", false)), "%s: a hardened block" % id)


func test_a_block_becomes_its_printed_stats() -> void:
	var db: Dictionary = RulesDB.load_json("npcs.json")
	for id in db.blocks:
		var b: Dictionary = db.blocks[id]
		var c := Recruit.from_block(Dice.new(3), id)
		assert_eq(c.max_hp(), int(b.hp), "%s: printed HP" % id)
		assert_eq(c.raw_stat("REF"), int(b.stats.REF), "%s: REF" % id)
		assert_eq(c.block, id)
		if b.weapons.is_empty():   # unarmed (Martial Arts, Brawling) or the GM's choice
			assert_true(c.weapons.is_empty(), "%s: no weapons" % id)
		else:
			assert_eq(c.weapons[0].id(), String(b.weapons[0]), "%s: primary weapon first" % id)
		for s in b.skills:
			if not String(s).contains(":"):
				# the book prints STAT + skill (before armour penalties; the Security Officer's bracketed
				# figures are after them, and the game applies the penalty itself)
				var level := maxi(0, int(b.skills[s]) - int(b.stats[RulesDB.skill_stat(String(s))]))
				assert_eq(int(c.skills.get(String(s), 0)), level, "%s: %s" % [id, s])


func test_printed_armour_and_kit() -> void:
	var op := Recruit.from_block(Dice.new(1), "security_operative")
	assert_eq(op.sp("body"), 7, "Kevlar (p.413)")
	var pyro := Recruit.from_block(Dice.new(1), "pyro")
	assert_true("ammo/incendiary_ammo" in pyro.kit and "ammo/flashbang_ammo" in pyro.kit, "an incendiary and a flashbang (p.416)")
	assert_eq(pyro.weapons[0].id(), "flamethrower")
	var psycho := Recruit.from_block(Dice.new(1), "cyberpsycho")
	assert_eq(psycho.sp("body"), 11, "Subdermal Armor")
	assert_true(psycho.weapons.any(func(w): return w.id() == "grenade_launcher"), "popup grenade launcher")


func test_factions_field_their_roster_blocks() -> void:
	for i in 10:
		var g := World.npc(Dice.new(i), "nomads", "mook", 1)
		assert_eq(g.block, "road_ganger", "the nomads field Road Gangers")
		assert_eq(g.role, "mook")
	var corp := World.npc(Dice.new(2), "militech", "lieutenant", 1)
	assert_eq(corp.block, "militech_security_guard", "Militech's own printed block (NC2045 p.231)")
	var fallback := World.npc(Dice.new(2), "ncpd", "mini_boss", 1)
	assert_true(fallback.block in ["outrider", "pyro"], "no NCPD mini boss: the tier's default pool")


func test_hardened_and_night_city_blocks() -> void:
	var db: Dictionary = RulesDB.load_json("npcs.json")
	var hardened := 0
	var district := 0
	for id in db.blocks:
		var b: Dictionary = db.blocks[id]
		if bool(b.get("hardened", false)) and not b.has("district"):
			hardened += 1
			assert_true(String(id).begins_with("hardened_"), "%s: hardened_<name>" % id)
			assert_true(String(b.cite).begins_with("RTG Hardened"), "%s: cites the Hardened DLC" % id)
			assert_true(String(id) in db.tiers[b.tier].hardened_blocks, "%s: listed in its tier's hardened_blocks" % id)
		if b.has("district"):
			district += 1
			assert_true(String(b.cite).begins_with("NC2045 p."), "%s: cites NC2045" % id)
			assert_true(b.faction is String and b.has("hardened") and b.has("com"), "%s: faction, hardened, com" % id)
			assert_eq(int(b.stats.BODY) + (2 if "grafted_muscle_and_bone_lace" in b.cyberware else 0), int(b.death_save), "%s: BODY = Death Save" % id)
			assert_eq(int(b.seriously_wounded), ceili(int(b.hp) / 2.0), "%s: Seriously Wounded = half HP" % id)
			assert_true(b.unverified.size() > 0, "%s: its derived stats are recorded" % id)
			if bool(b.get("civilian", false)):
				assert_eq(String(b.tier), "mook", "%s: a civilian is a mook" % id)
			for w in b.weapons:   # one Combat Number for every attack
				assert_eq(int(b.skills[RulesDB.load_json("weapons.json")["weapons"][w]["skill"]]), int(b.com), "%s: %s at COM #" % [id, w])
	assert_eq(hardened, 16, "4 Hardened Mooks, 6 Lieutenants, 6 Mini Bosses")
	assert_eq(district, 112, "Night City 2045's 112 district blocks")
	var arasaka := Recruit.from_block(Dice.new(1), "hardened_executive_protection")
	assert_eq(arasaka.max_hp(), 60)
	assert_eq(arasaka.death_save_target(), 12, "BODY 12 as printed")
	var nc := Recruit.from_block(Dice.new(1), "consortium_mook")
	assert_eq(nc.death_save_target(), 9, "Grafted Muscle & Bone Lace brings BODY back to the printed Death Save")
	assert_eq(nc.max_hp(), 50)


func test_complication_tables() -> void:
	var db: Dictionary = RulesDB.load_json("npcs.json")
	var skills: Dictionary = RulesDB.load_json("skills.json")["skills"]
	var armor: Dictionary = RulesDB.load_json("armor.json")["armor"]
	for t in ["mook", "lieutenant", "mini_boss"]:
		var rows: Array = db.complications[t]
		assert_eq(rows.size(), 10, "%s: a d10 table" % t)
		assert_true(String(db.complications._cite[t]).contains("p."), "%s: cited" % t)
		for i in rows.size():
			var r: Dictionary = rows[i]
			assert_eq(int(r.roll), i + 1)
			assert_false(String(r.text).is_empty())
			var fxs: Array = [r.fx]
			fxs.append_array(r.fx.get("choose", []))
			for fx in fxs:
				if fx.has("kit"):
					assert_false(Items.def(String(fx.kit)).is_empty(), "%s %d: kit %s" % [t, r.roll, fx.kit])
				for s in fx.get("skill_base", {}):
					assert_true(skills.has(s), "%s %d: skill %s" % [t, r.roll, s])
				for loc in fx.get("armor", {}):
					var a := String(fx.armor[loc])
					assert_true(a == "" or armor.has(a), "%s %d: armour %s" % [t, r.roll, a])
				var drugs: Array = fx.drug if fx.get("drug") is Array else ([fx.drug] if fx.has("drug") else [])
				for d in drugs:
					assert_false(Items.def("drugs/" + String(d)).is_empty(), "%s %d: drug %s" % [t, r.roll, d])
