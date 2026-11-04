extends TestCase
## Exotic weapon rules (CPR core p.347-349) driven by weapons.json fx.


func _hit(a: Combatant, w: Weapon, d: Combatant, mode := Attack.Mode.SINGLE, dist := 4.0, fresh := Callable()) -> Dictionary:
	for s in 300:
		if fresh.is_valid():
			fresh.call()
		w.ammo = w.mag()
		var r := Attack.resolve(Dice.new(s), a, w, d, mode, dist)
		if r.get("hit", false):
			return r
	return {}


func _armored(sp_armor: String, overrides := {}) -> Combatant:
	var t := Fixtures.unarmored("T", overrides)
	t.armor["body"] = ArmorPiece.from_id(sp_armor)
	t.armor["head"] = ArmorPiece.from_id(sp_armor)
	return t


func test_stun_weapons_knock_out_at_one_hp_without_crits_or_ablation() -> void:
	var a := Fixtures.shooter("A", {"REF": 8})
	var w := Weapon.from_id("stun_gun")
	var t := _armored("leathers")
	var r := _hit(a, w, t, Attack.Mode.SINGLE, 4.0, func(): t.hp = 1; t.unconscious = false; t.armor["body"] = ArmorPiece.from_id("leathers"))
	assert_false(r.is_empty())
	if r.through > 0:   # at 1 HP, any damage would take them under: out cold at 1 HP instead
		assert_eq(t.hp, 1, "a stun gun never kills (p349)")
		assert_true(t.unconscious, "out cold")
	assert_eq(t.sp("body"), 4, "doesn't ablate armour")
	assert_true(r.crits.is_empty(), "no Critical Injuries")


func test_cutting_weapons_ignore_armour_under_sp11() -> void:
	var a := Fixtures.shooter("A", {"BODY": 11, "REF": 8})
	a.skills["heavy_weapons"] = 6
	var w := Weapon.from_id("rhinemetall_emg86")
	var soft := _armored("kevlar")   # SP 7: ignored
	var r := _hit(a, w, soft, Attack.Mode.SINGLE, 20.0, func(): soft.hp = 200)
	assert_false(r.is_empty())
	assert_eq(r.through, r.damage, "SP7 counts for nothing against the railgun")
	var hard := _armored("metalgear")   # SP 18: interacts as normal
	var r2 := _hit(a, w, hard, Attack.Mode.SINGLE, 20.0, func(): hard.hp = 200; hard.armor["body"] = ArmorPiece.from_id("metalgear"))
	assert_eq(r2.through, maxi(0, r2.damage - 18), "SP18 still stops 18")


func test_heavy_exotics_need_body_11_and_no_aimed_shots() -> void:
	var weak := Fixtures.shooter("W", {"BODY": 6})
	var w := Weapon.from_id("rhinemetall_emg86")
	var t := Fixtures.unarmored()
	assert_eq(Attack.preview(weak, w, t, Attack.Mode.SINGLE, 20.0).reason, "needs BODY 11")
	var strong := Fixtures.shooter("S", {"BODY": 11})
	assert_true(Attack.preview(strong, w, t, Attack.Mode.SINGLE, 20.0).ok)
	assert_eq(Attack.preview(strong, w, t, Attack.Mode.AIMED_HEAD, 20.0).reason, "can't aim")


func test_the_helix_only_autofires_and_spends_20_rounds() -> void:
	var a := Fixtures.shooter("A", {"BODY": 11})
	var w := Weapon.from_id("tsunami_helix")
	var t := Fixtures.unarmored()
	assert_eq(Attack.preview(a, w, t, Attack.Mode.SINGLE, 20.0).reason, "autofire only")
	assert_true(Attack.preview(a, w, t, Attack.Mode.AUTOFIRE, 20.0).ok)
	var before := w.ammo
	Attack.resolve(Dice.new(1), a, w, t, Attack.Mode.AUTOFIRE, 20.0)
	assert_eq(before - w.ammo, 20, "20 bullets an attack (p349)")
	assert_eq(w.autofire_mult(), 5, "multiplier up to 5")


func test_the_flamethrower_fires_shells_and_sets_people_alight() -> void:
	var a := Fixtures.shooter("A")
	a.skills["heavy_weapons"] = 6
	var w := Weapon.from_id("flamethrower")
	var t := Fixtures.unarmored()
	assert_eq(Attack.preview(a, w, t, Attack.Mode.SINGLE, 4.0).reason, "shells only")
	var lit := false
	for s in 200:
		w.ammo = w.mag()
		t.hp = 200
		t.burning = 0
		var r := Attack.shotgun_shell(Dice.new(s), a, w, [t])
		if r.hit and not r.results.is_empty() and int(r.results[0].through) > 0:
			assert_eq(t.burning, 4, "on fire: 4 a turn until put out (p348)")
			assert_true(r.results[0].crits.is_empty(), "no Critical Injuries")
			lit = true
			break
	assert_true(lit)


func test_the_malorian_needs_its_smartgun_link() -> void:
	var a := Fixtures.shooter("A")
	var w := Weapon.from_id("malorian_arms_3516")
	var t := Fixtures.unarmored()
	assert_true(Attack.preview(a, w, t, Attack.Mode.SINGLE, 8.0).reason.begins_with("needs"), "won't fire unlinked (p348)")
	a.cyberware.append("neural_link")
	a.cyberware.append("interface_plugs")
	var std := Weapon.from_id("very_heavy_pistol")
	assert_eq(Attack.attack_base(a, w, Attack.Mode.SINGLE), Attack.attack_base(a, std, Attack.Mode.SINGLE) + 2, "Excellent +1, smartgun +1")


func test_acid_paintballs_strip_armour_and_do_no_damage() -> void:
	var a := Fixtures.shooter("A", {"REF": 8})
	var w := Weapon.from_id("air_pistol")
	var t := _armored("light_armorjack")
	var r := _hit(a, w, t, Attack.Mode.SINGLE, 4.0)
	assert_false(r.is_empty())
	assert_eq(t.hp, t.max_hp(), "no damage")
	assert_eq(t.sp("body"), 10, "acid takes 1 SP off (p347)")


func test_the_shrieker_deafens_both_ends() -> void:
	var a := Fixtures.shooter("A", {"REF": 8})
	var w := Weapon.from_id("shrieker")
	var t := Fixtures.unarmored("T", {"WILL": 2})
	var deafened := false
	for s in 300:
		t.injuries.clear()
		t.hp = t.max_hp()
		w.ammo = w.mag()
		var r := Attack.resolve(Dice.new(s), a, w, t, Attack.Mode.SINGLE, 4.0)
		if r.hit and r.get("status", {}).get("resisted", true) == false:
			assert_true(t.has_injury("damaged_ear"))
			assert_eq(t.hp, t.max_hp(), "no Bonus Damage from it")
			deafened = true
			break
	assert_true(deafened)
	assert_true(a.has_injury("damaged_ear"), "the shooter, without ear protection, too (p349)")
	var b := Fixtures.shooter("B")
	b.cyberware.append("level_damper")
	Attack.resolve(Dice.new(2), b, Weapon.from_id("shrieker"), Fixtures.unarmored(), Attack.Mode.SINGLE, 4.0)
	assert_false(b.has_injury("damaged_ear"), "a Level Damper protects the shooter (HOUSE-RULE)")


func test_the_microwaver_knocks_out_two_pieces_of_chrome() -> void:
	var a := Fixtures.shooter("A", {"REF": 8})
	var w := Weapon.from_id("microwaver")
	var t := Fixtures.unarmored("T", {"TECH": 2})
	t.cyberware.append_array(["kerenzikov", "neural_link", "sandevistan"])
	var before := t.initiative_bonus()
	var done := false
	for s in 300:
		t.cyber_off.clear()
		w.ammo = w.mag()
		var r := Attack.resolve(Dice.new(s), a, w, t, Attack.Mode.SINGLE, 4.0)
		if r.hit and r.get("status", {}).get("resisted", true) == false:
			assert_eq(t.cyber_off.size(), 2, "two pieces (p348)")
			assert_true(t.initiative_bonus() < before, "and they stop working")
			done = true
			break
	assert_true(done)


func test_heavy_exotics_reload_over_two_actions() -> void:
	var m := SceneGen.generate(11, "skirmish", {"security": 1})
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner")]
	var e := Encounter.setup(m, dice, crew)
	e.next_turn()
	var w := Weapon.from_id("rhinemetall_emg86")
	w.ammo = 0
	e.cur.c.weapons.insert(0, w)
	assert_true(e.reload(w))
	assert_eq(w.ammo, 0, "one Action in: still empty")
	e.turn.action_available = true   # next turn
	assert_true(e.reload(w))
	assert_eq(w.ammo, 4, "two Actions: loaded (p349)")


func test_the_market_now_sells_the_exotics_that_play() -> void:
	var camp := Campaign.new_game(4)
	camp.rep = 6
	var ids := camp.shop_stock().map(func(x): return String(x.id))
	for id in ["stun_gun", "stun_baton", "air_pistol", "flamethrower", "malorian_arms_3516", "tsunami_helix"]:
		assert_true(id in ids, "%s for sale" % id)
	assert_false("battleglove" in ids, "the Battleglove waits for cyberarm options in gloves")
	assert_false("dartgun" in ids, "the Dartgun waits for special arrows")
