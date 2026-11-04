extends TestCase
## Weapon quality (CPR core p.342): Excellent +1 to attack, Poor jams on a 1 and takes an Action
## to clear; prices by base cost; exotics are as listed.


func test_excellent_adds_one_to_the_attack() -> void:
	var a := Fixtures.shooter()
	var std := Weapon.from_id("heavy_pistol")
	var exc := Weapon.from_id("heavy_pistol", "excellent")
	assert_eq(Attack.attack_base(a, exc, Attack.Mode.SINGLE), Attack.attack_base(a, std, Attack.Mode.SINGLE) + 1)
	assert_eq(exc.display_name(), "Excellent Heavy Pistol")


func test_prices_follow_the_quality_table() -> void:
	assert_eq(Weapon.from_id("heavy_pistol", "poor").cost(), 50, "100eb base -> 50 (p.342)")
	assert_eq(Weapon.from_id("heavy_pistol", "excellent").cost(), 500)
	assert_eq(Weapon.from_id("medium_pistol", "excellent").cost(), 100, "50eb base -> 100")
	assert_eq(Weapon.from_id("assault_rifle", "excellent").cost(), 1000, "500eb base -> 1000")
	assert_eq(Weapon.from_id("assault_rifle").cost(), 500)


func test_exotics_have_no_quality_variants() -> void:
	var w := Weapon.from_id("stun_gun", "excellent")
	assert_eq(w.quality, "standard", "exotics are as listed (p.342)")


func test_a_poor_weapon_jams_on_a_one_and_an_action_clears_it() -> void:
	var a := Fixtures.shooter()
	var d := Fixtures.unarmored()
	var jammed_once := false
	for seed_value in 400:   # find a roll whose Attack Check die shows a 1
		var w := Weapon.from_id("heavy_pistol", "poor")
		var r := Attack.resolve(Dice.new(seed_value), a, w, d, Attack.Mode.SINGLE, 5.0)
		if r.check != null and r.check.natural == 1:
			assert_true(w.jammed and r.get("jammed", false), "a 1 jams it")
			assert_eq(Attack.preview(a, w, d, Attack.Mode.SINGLE, 5.0).reason, "jammed", "and it won't fire")
			jammed_once = true
			break
		assert_false(w.jammed, "anything but a 1 leaves it working")
	assert_true(jammed_once)
	# a standard gun never jams
	for seed_value in 200:
		var s := Weapon.from_id("heavy_pistol")
		Attack.resolve(Dice.new(seed_value), a, s, d, Attack.Mode.SINGLE, 5.0)
		assert_false(s.jammed)


func test_clearing_a_jam_takes_the_action_and_no_ammo() -> void:
	var m := SceneGen.generate(11, "skirmish", {"security": 1})
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner")]
	var e := Encounter.setup(m, dice, crew)
	e.next_turn()
	var w := Weapon.from_id("heavy_pistol", "poor")
	w.ammo = 3
	w.jammed = true
	e.cur.c.weapons.insert(0, w)
	assert_true(e.reload(w), "clearing the jam")
	assert_false(w.jammed)
	assert_eq(w.ammo, 3, "clearing isn't reloading")
	assert_false(e.turn.action_available, "it took the Action")


func test_quality_survives_a_save() -> void:
	var c := Recruit.generate(Dice.new(2), "solo", "edgerunner")
	c.weapons[0] = Weapon.from_id("assault_rifle", "excellent")
	var back := Combatant.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.weapons[0].quality, "excellent")


func test_the_market_sells_qualities_and_excellent_needs_a_name() -> void:
	var camp := Campaign.new_game(4)
	camp.rep = 0
	var ids := camp.shop_stock().map(func(x): return String(x.id))
	assert_true("heavy_pistol@poor" in ids and "heavy_pistol" in ids)
	assert_false("heavy_pistol@excellent" in ids, "excellent guns need a little rep")
	camp.rep = 1
	camp.eb = 5000
	ids = camp.shop_stock().map(func(x): return String(x.id))
	assert_true("heavy_pistol@excellent" in ids)
	var c: Combatant = camp.crew[0]
	assert_true(camp.buy(c, "heavy_pistol@excellent"))
	assert_eq(c.weapons[0].quality, "excellent")
	assert_eq(c.weapons[0].id(), "heavy_pistol")


func test_factions_field_their_quality() -> void:
	var poor := 0
	var mooks := 0
	for i in 40:
		var g := World.npc(Dice.new(i), "bozos", "mook", 1)
		mooks += 1
		if g.weapons.any(func(w): return w.quality == "poor"):
			poor += 1
	assert_between(float(poor) / mooks, 0.35, 0.85, "most Bozos carry printed junk (%d/%d)" % [poor, mooks])
	var officer := World.npc(Dice.new(1), "militech", "lieutenant", 1)
	assert_true(officer.weapons.all(func(w): return w.quality == "excellent"), "Militech officers carry the good stuff")
