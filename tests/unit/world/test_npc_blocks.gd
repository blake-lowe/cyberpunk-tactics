extends TestCase
## NPC stat blocks (data/rules/npcs.json, CPR core p.412-416): the data resolves, and a block
## becomes the combatant the book prints.


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
			assert_true(armor.has(a) or a in b.get("cyberware", []), "%s: armour %s" % [id, a])
		for cw in b.get("cyberware", []):
			assert_false(RulesDB.cyberware(String(cw)).is_empty(), "%s: cyberware %s" % [id, cw])
		for k in b.get("kit", []):
			assert_false(Items.def(String(k)).is_empty(), "%s: gear %s" % [id, k])
	for t in db.tiers:
		for id in db.tiers[t].blocks:
			assert_eq(String(db.blocks[id].tier), t, "the %s pool holds %s blocks" % [t, t])


func test_a_block_becomes_its_printed_stats() -> void:
	var db: Dictionary = RulesDB.load_json("npcs.json")
	for id in db.blocks:
		var b: Dictionary = db.blocks[id]
		var c := Recruit.from_block(Dice.new(3), id)
		assert_eq(c.max_hp(), int(b.hp), "%s: printed HP" % id)
		assert_eq(c.raw_stat("REF"), int(b.stats.REF), "%s: REF" % id)
		assert_eq(c.block, id)
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
		var g := World.npc(Dice.new(i), "wraiths", "mook", 1)
		assert_eq(g.block, "road_ganger", "the Wraiths field Road Gangers")
		assert_eq(g.role, "mook")
	var corp := World.npc(Dice.new(2), "militech", "lieutenant", 1)
	assert_eq(corp.block, "security_officer")
	var fallback := World.npc(Dice.new(2), "ncpd", "mini_boss", 1)
	assert_true(fallback.block in ["outrider", "pyro"], "no NCPD mini boss: the tier's default pool")
