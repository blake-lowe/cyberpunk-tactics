extends TestCase
## The attack stage's options follow the weapon (CPR core p.170-177) and drawing is free (p.128).


func test_modes_follow_the_weapon() -> void:
	var pistol := Encounter.attack_modes(Weapon.from_id("heavy_pistol"))
	assert_false("auto" in pistol, "a Heavy Pistol has no Autofire")
	assert_true("single" in pistol and "aim_head" in pistol and "cover" in pistol)
	var smg := Encounter.attack_modes(Weapon.from_id("smg"))
	assert_true("auto" in smg and "suppress" in smg, "an SMG autofires and suppresses (p.173-174)")
	var shotgun := Encounter.attack_modes(Weapon.from_id("shotgun"))
	assert_true("shell" in shotgun, "Shotgun Shell (p.174)")
	assert_true("aim_head" in shotgun, "slugs can be aimed; only shells can't (p.174)")
	assert_eq(Encounter.attack_modes(Weapon.from_id("heavy_melee")), ["melee"] as Array[String])
	assert_eq(Encounter.attack_modes(null), ["melee"] as Array[String], "Brawling")
	assert_false("single" in Encounter.attack_modes(Weapon.from_id("tsunami_helix")), "autofire only (p.349)")
	assert_false("aim_head" in Encounter.attack_modes(Weapon.from_id("rhinemetall_emg86")), "can't aim (p.349)")


func test_drawing_a_weapon_is_free() -> void:
	var m := SceneGen.generate(11, "skirmish", {"security": 1})
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner")]
	var e := Encounter.setup(m, dice, crew)
	e.next_turn()
	var c: Combatant = e.cur.c
	var second: Weapon = c.weapons[1]
	assert_true(e.draw(second))
	assert_eq(c.weapons[0], second, "now in hand")
	assert_true(e.turn.action_available, "no Action spent (p.128)")
