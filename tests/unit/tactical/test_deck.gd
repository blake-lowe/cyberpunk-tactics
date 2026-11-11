extends TestCase
## Cyberdecks and Programs (Deck, NetRun.progs, Encounter's NET; CPR core p.196, p.201-209, p.364):
## slots by quality and the arm deck, loading at the Armory, each played Program in a NET fight,
## derez and recovery, Black ICE hunting Programs, Hardware, the sales gate and the save migration.


func _runner() -> Combatant:
	return Recruit.generate(Dice.new(4), "netrunner", "edgerunner", "Patch")


func _jacked(seed := 9) -> Array:
	var m := SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": 1})
	var dice := Dice.new(seed)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	var e := Encounter.setup(m, dice, crew)
	var runner: Dictionary = e.units[1]
	var ap_dev: Dictionary = m.devices[m.architecture.access_points[0].device]
	runner.pos = Vector3i(ap_dev.pos.x, ap_dev.pos.y, ap_dev.floor)
	e.cur = runner
	e.turn = TurnState.begin(dice, runner.c)
	assert_true(e.jack_in(e.jack_points(runner)[0]), "jacked in")
	return [e, runner, e.runs[runner.id]]


## A Black ICE of `kind` waiting on the runner's node, already met.
func _ice(r: Array, kind: String) -> Dictionary:
	var run: NetRun = r[2]
	for x in run.arch.ice_at(run.current):
		x["derezzed"] = true
	var ice := {"id": 900 + run.arch.ice.size(), "kind": kind, "node": run.current, "patrol": false}
	run.arch.ice.append(ice)
	run.met[run.met_key(ice)] = true
	(r[0] as Encounter).net_left = 5
	return ice


func _copy(run: NetRun, id: String) -> int:
	for i in run.progs.size():
		if String(run.progs[i].id) == id and not bool(run.progs[i].gone):
			return i
	return -1


func _next_round(e: Encounter) -> void:
	e.init.round_num += 1
	e.net_left = 5


# --- Slots and loading ------------------------------------------------------------------------

func test_deck_slots_by_quality_and_the_arm_deck() -> void:
	var c := _runner()
	for q in [["cyberdeck_poor", 5], ["cyberdeck_standard", 7], ["cyberdeck_excellent", 9]]:
		c.deck = String(q[0])
		assert_eq(Deck.slots(c), int(q[1]), "p196: %s" % q[0])
	c.deck = ""
	assert_eq(Deck.slots(c), 0, "no deck, no slots")
	c.deck = "cyberdeck_standard"
	c.install_cyberware("cyberarm", Dice.new(1), true, "right_arm")
	c.install_cyberware("cyberdeck", Dice.new(1), true, "right_arm")
	assert_true(Deck.in_arm(c))
	assert_eq(Deck.slots(c), 8, "p364: a Cyberdeck in a Cyberarm adds 1 slot")


func test_recruits_start_with_the_roles_deck() -> void:
	var c := _runner()
	assert_eq(c.deck, "cyberdeck_standard", "p103: a Cyberdeck with 7 slots")
	assert_eq(c.programs, Deck.STARTING_PROGRAMS, "Armor, Sword, See Ya, Sword, Worm")
	assert_eq(Deck.used(c), 5)
	assert_eq(Recruit.generate(Dice.new(4), "solo", "edgerunner", "Vex").deck, "", "only Netrunners carry one")


func test_loading_and_unloading_at_the_armory() -> void:
	var camp := Campaign.new_game(3)
	var c: Combatant = camp.alive_crew().filter(func(m): return m.role == "netrunner")[0]
	camp.stash["programs/worm"] = 3
	camp.stash["programs/ice_killer"] = 1
	camp.stash["hardware/backup_drive"] = 1
	assert_eq(camp.load_block(c, "programs/worm"), "", "a free slot")
	assert_true(camp.load_netware(c, "programs/worm"))
	assert_eq(Deck.used(c), 6)
	assert_eq(camp.load_block(c, "programs/ice_killer"), "no free slot", "p204: Black ICE takes 2 slots, one is free")
	assert_eq(camp.load_block(c, "hardware/backup_drive"), "no free slot", "p208: a Backup Drive takes 2")
	assert_true(camp.load_netware(c, "programs/worm"))
	assert_eq(Deck.free_slots(c), 0)
	assert_eq(camp.load_block(c, "programs/worm"), "no free slot")
	assert_true(camp.unload_program(c, c.programs.find("worm")))
	assert_eq(camp.stored("programs/worm"), 2, "back to storage")
	# a smaller deck: the overflow goes to storage
	camp.stash["gear/cyberdeck_poor"] = 1
	assert_true(camp.equip_deck(c, "gear/cyberdeck_poor"))
	assert_eq(Deck.slots(c), 5)
	assert_true(Deck.used(c) <= 5, "what doesn't fit comes off")
	assert_eq(camp.stored("gear/cyberdeck_standard"), 1, "the old deck to storage")
	assert_true(camp.store_deck(c))
	assert_eq(c.deck, "")
	assert_true(c.programs.is_empty(), "the Programs come off with it")
	assert_eq(NetRun.jack_block(c), "Needs a cyberdeck", "p196: plugs plug into a deck")
	var solo: Combatant = camp.alive_crew().filter(func(m): return m.role != "netrunner")[0]
	assert_eq(camp.deck_block(solo, "gear/cyberdeck_poor"), "netrunners only")


func test_the_loadout_model_shows_the_deck() -> void:
	var camp := Campaign.new_game(3)
	var c: Combatant = camp.alive_crew().filter(func(m): return m.role == "netrunner")[0]
	var sl := Loadout.slots(c)
	assert_true("deck" in sl and "p0" in sl and "padd" in sl)
	assert_eq(Loadout.slot_key(c, "deck"), "gear/cyberdeck_standard")
	assert_eq(Loadout.slot_key(c, "p1"), "programs/sword")
	assert_eq(Loadout.slot_label("p1"), "PROGRAM 2")
	camp.stash["programs/speedy_gonzalvez"] = 1
	assert_eq(Loadout.best_slot(c, "programs/speedy_gonzalvez"), "padd")
	assert_true(Loadout.equip(camp, c, "p2", "programs/speedy_gonzalvez"), "swap See Ya for Speedy")
	assert_eq(c.programs[c.programs.size() - 1], "speedy_gonzalvez")
	assert_eq(camp.stored("programs/see_ya"), 1)
	assert_true(Loadout.store(camp, c, "p0"))
	assert_true(Loadout.slot_stats(c, "deck").begins_with("4/7"))
	assert_false("head" in sl.filter(func(x): return Loadout.hardware_index(x) >= 0), "head isn't a hardware slot")


func test_bodyweight_suit_holds_one_hardware() -> void:
	var c := _runner()
	c.deck = "cyberdeck_poor"
	c.programs.assign(["sword", "sword", "armor", "worm"])
	assert_false(Deck.fits(c, "hardware/backup_drive"), "1 slot free, the drive needs 2")
	c.armor["body"] = ArmorPiece.from_id("bodyweight_suit")
	assert_true(Deck.fits(c, "hardware/backup_drive"), "p208: the suit adds a Hardware-only slot")
	assert_false(Deck.fits(c, "programs/ice_killer"), "not for Programs")


func test_the_arm_deck_needs_a_deck_and_breaks_coming_out() -> void:
	var camp := Campaign.new_game(3)
	var c: Combatant = camp.alive_crew().filter(func(m): return m.role == "netrunner")[0]
	c.install_cyberware("cyberarm", camp.dice, true, "left_arm")
	camp.stash["cyberware/cyberdeck"] = 1
	var deck := c.deck
	c.deck = ""
	assert_eq(camp.install_block(c, "cyberdeck"), "Needs a cyberdeck carried", "p364: the user provides the deck")
	c.deck = deck
	assert_eq(camp.install_block(c, "cyberdeck"), "")
	assert_true(camp.install(c, "cyberdeck") >= 0)
	assert_eq(Deck.slots(c), 8)
	assert_false(camp.store_deck(c), "it can't come out at the Armory")
	camp.stash["gear/cyberdeck_excellent"] = 1
	assert_false(camp.equip_deck(c, "gear/cyberdeck_excellent"), "nor be swapped")
	var progs := c.programs.size()
	assert_true(camp.remove(c, "cyberdeck"))
	assert_eq(c.deck, "", "p364: the deck breaks beyond repair")
	assert_eq(camp.stored("programs/sword"), 2, "its Programs are recovered")
	assert_eq(progs, Deck.STARTING_PROGRAMS.size())


# --- Programs in the NET ----------------------------------------------------------------------

func test_boosters_add_to_their_ability_while_rezzed() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	assert_eq(run.boost("pathfinder"), 0)
	e.net_left = 5
	assert_true(e.net_action("see_ya").ok)
	assert_eq(run.boost("pathfinder"), 2, "p203: See Ya +2 Pathfinder")
	assert_true(e.net_action("worm").ok)
	assert_eq(run.boost("backdoor"), 2, "p203: Worm +2 Backdoor")
	assert_eq(run.chance(14, "backdoor"), Check.chance_vs_dv(run.rank() + 2, 14))
	var w := _copy(run, "worm")
	assert_false(e.net_action("activate", w).ok, "a Rezzed copy can't be Activated again")
	assert_true(e.net_action("deactivate", w).ok)
	assert_eq(run.boost("backdoor"), 0)
	assert_false(e.net_action("activate", w).ok, "once per Round, even after Deactivating")
	_next_round(e)
	assert_true(e.net_action("activate", w).ok, "next Round it goes again")


func test_speedy_gonzalvez_adds_speed_when_meeting_ice() -> void:
	var c := _runner()
	c.programs.append("speedy_gonzalvez")
	var r := _jacked()
	var run := NetRun.new(r[2].arch, c)
	run.rez(_copy(run, "speedy_gonzalvez"), 1)
	assert_eq(run.boost("speed"), 2, "p203, p205: Interface + Speed bonus vs ICE SPD")


func test_armor_takes_4_off_brain_damage() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var u: Dictionary = r[1]
	var ice := _ice(r, "wisp")
	assert_true(e.net_action("armor").ok)
	for k in 20:
		u.c.hp = u.c.max_hp()
		run.wisp = 0
		e._ice_effect(u, run, ice)
		assert_true(u.c.max_hp() - u.c.hp <= 2, "p203: 1d6 - 4")


func test_sword_and_banhammer_damage_black_ice() -> void:
	for pid in ["sword", "banhammer"]:
		var r := _jacked()
		var e: Encounter = r[0]
		var run: NetRun = r[2]
		if pid == "banhammer":
			run.progs.append({"id": "banhammer", "on": false, "rez": 0, "round": -1, "used": false, "gone": false, "target": -1})
		var ice := _ice(r, "dragon")
		var hit := 0
		for k in 25:
			_next_round(e)
			var res := e.net_action("activate", _copy(run, pid))
			assert_true(res.ok, pid)
			assert_false(bool(run.progs[_copy(run, pid)].on), "p202: Attackers Deactivate on their own")
			if res.success:
				hit += 1
				assert_true(int(res.damage) >= (3 if pid == "sword" else 2) and int(res.damage) <= (18 if pid == "sword" else 12), "%s: 3d6 / 2d6 to Black ICE" % pid)
			if ice.get("derezzed", false):
				break
		assert_true(hit > 0, pid + " hits")


func test_two_copies_both_go_in_one_round() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	_ice(r, "dragon")
	assert_true(e.net_action("sword").ok)
	assert_true(e.net_action("sword").ok, "p201: a second copy gets round the once-a-Round limit")
	assert_false(e.net_action("sword").ok, "two copies, two attacks")


func test_your_black_ice_hunts_the_ice_it_was_set_on() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	run.progs.append({"id": "ice_killer", "on": false, "rez": 0, "round": -1, "used": false, "gone": false, "target": -1})
	var ice := _ice(r, "dragon")
	var k := _copy(run, "ice_killer")
	assert_true(e.net_action("activate", k).ok)
	assert_eq(int(run.progs[k].target), int(ice.id), "p205: set on a valid target")
	assert_eq(int(run.progs[k].rez), 20, "REZ is the Killer's")
	var before := int(ice.get("rez", 30))
	for n in 10:
		e._own_ice_turn(run)
	assert_true(int(ice.get("rez", 30)) < before, "it strikes on the runner's turns: 4d6 a hit")


func test_anti_program_ice_destroys_a_rezzed_program() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var u: Dictionary = r[1]
	var ice := _ice(r, "sabertooth")
	assert_true(e.net_action("see_ya").ok)
	var i := _copy(run, "see_ya")
	e._ice_effect(u, run, ice, false, i)   # 6d6 against REZ 7: derezzed means destroyed (p207)
	if int(run.progs[i].rez) <= 0:
		assert_true(bool(run.progs[i].gone), "destroyed")
		assert_false("see_ya" in u.c.programs, "p201: erased from the deck: rebuy it")
	assert_eq(run.boost("pathfinder"), 0 if bool(run.progs[i].gone) else 2)
	# it hunts only Rezzed Programs: none running, nothing to hit
	var r2 := _jacked()
	var ice2 := _ice(r2, "killer")
	var n0 := (r2[1].c as Combatant).programs.size()
	for n in 10:
		r2[0]._ice_attack(r2[1], r2[2], ice2)
	assert_eq((r2[1].c as Combatant).programs.size(), n0, "p205: Anti-Program ICE hits Rezzed Programs")


func test_asp_destroys_and_a_backup_drive_saves() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var u: Dictionary = r[1]
	var c: Combatant = u.c
	c.deck_hardware.append("backup_drive")
	var ice := _ice(r, "asp")
	var n0 := c.programs.size()
	e._ice_effect(u, run, ice)
	assert_eq(c.programs.size(), n0 - 1, "p206: one random Program destroyed")
	assert_eq(c.backup.size(), 1, "p208: the Backup Drive saved it")
	e.cur = u
	e.turn = TurnState.begin(e.dice, c)
	e._netting = false
	var res := e.restore_backup()
	assert_true(res.ok, "a Meat Action")
	assert_eq(c.programs.size(), n0)
	assert_false(e.turn.action_available)
	assert_eq(run.progs.filter(func(p): return bool(p.gone)).size(), 0, "back on the deck for this Netrun too")


func test_raven_derezzes_a_defender_and_restarting_restores_it() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var ice := _ice(r, "raven")
	assert_true(e.net_action("see_ya").ok)
	assert_true(e.net_action("armor").ok)
	e._ice_effect(r[1], run, ice)
	var a := _copy(run, "armor")
	assert_eq(int(run.progs[a].rez), 0, "p207: Raven derezzes a Rezzed Defender")
	assert_true(bool(run.progs[a].on), "p201: still running, but useless")
	assert_eq(run.brain_reduce(), 0)
	assert_eq(run.boost("pathfinder"), 2, "a Booster isn't a Defender")
	# See Ya: derez it by hand and bring it back with 2 NET Actions
	var s := _copy(run, "see_ya")
	run.progs[s].rez = 0
	_next_round(e)
	assert_true(e.net_action("deactivate", s).ok)
	assert_true(e.net_action("activate", s).ok)
	assert_eq(int(run.progs[s].rez), 7, "p201: deactivate + activate: full REZ")
	assert_false(e.net_action("activate", a).ok, "Armor stays spent this run")


func test_a_new_netrun_starts_programs_fresh() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var u: Dictionary = r[1]
	assert_true(e.net_action("armor").ok)
	e.net_action("jack_out")
	e.turn = TurnState.begin(e.dice, u.c)
	e._netting = false
	assert_true(e.jack_in(e.jack_points(u)[0]))
	var run: NetRun = e.runs[u.id]
	assert_eq(run.rezzed().size(), 0, "p198: your Programs left with you")
	assert_eq(run.activate_block(_copy(run, "armor"), e.init.round_num + 1), "", "Armor is once per Netrun: this is a new one")


func test_the_campaign_restores_backups_after_a_gig() -> void:
	var camp := Campaign.new_game(3)
	var c: Combatant = camp.alive_crew().filter(func(m): return m.role == "netrunner")[0]
	c.deck_hardware.append("backup_drive")
	Deck.destroy(c, "sword")
	assert_eq(c.backup, ["sword"] as Array[String])
	var back := camp._restore_backups()
	assert_eq(back.get(c.display_name, []), ["sword"] as Array[String])
	assert_true(c.backup.is_empty())
	Deck.destroy(c, "worm")
	camp.unload_hardware(c, 0)
	assert_true(c.backup.is_empty(), "p208: removed from the deck, the drive erases what it held")
	c.deck_hardware.clear()
	Deck.destroy(c, "armor")
	assert_true(c.backup.is_empty(), "no drive: destroyed is gone")


# --- Hardware ---------------------------------------------------------------------------------

func test_insulated_wiring_krash_barrier_and_range_upgrade() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var u: Dictionary = r[1]
	var c: Combatant = u.c
	c.deck_hardware.append("insulated_wiring")
	e._ice_effect(u, r[2], _ice(r, "hellhound"))
	assert_eq(c.burning, 0, "p208: no fire from a Program effect")
	c.deck_hardware.append("krash_barrier")
	e._ice_effect(u, r[2], _ice(r, "giant"))
	assert_true(e.runs.has(u.id), "p208: no forced Jack Out")
	c.deck_hardware.clear()
	assert_eq(Encounter.jack_range(c), 6.0)
	c.deck_hardware.append("range_upgrade")
	assert_eq(Encounter.jack_range(c), 8.0, "p208: 8 m")


func test_microwavers_knock_out_a_deck_unless_hardened() -> void:
	var c := _runner()
	var t := Attack.microwaver_targets(c)
	assert_eq(String(t[0].id), "deck", "p348: carried electronics, the deck first")
	c.cyber_off[Deck.OFF_KEY] = 20
	assert_true(Deck.offline(c))
	assert_eq(NetRun.jack_block(c), "Cyberdeck offline")
	c.cyber_off.clear()
	c.deck_hardware.append("hardened_circuitry")
	assert_false(Attack.microwaver_targets(c).any(func(p): return String(p.id) == "deck"), "p208: Hardened Circuitry")


func test_a_deck_knocked_out_mid_run_dumps_the_runner() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var u: Dictionary = r[1]
	u.c.cyber_off[Deck.OFF_KEY] = 20
	e._ice_turn(u)
	assert_false(e.runs.has(u.id))


# --- Sales gate and saves ---------------------------------------------------------------------

func test_only_netrunning_gear_that_plays_is_sold() -> void:
	var sold := Deck.all_sold()
	for k in sold:
		var d := Deck.entry(k)
		assert_false(d.has("unmodelled"), "%s is sold, so nothing about it may be unmodelled" % k)
		for f in d.get("fx", {}):
			assert_true(String(f) in Deck.IMPLEMENTED_FX, "%s: fx %s implemented" % [k, f])
		assert_true(NightMarket.on_sale(k), k)
		assert_true(Items.is_stored(k), k)
	for k in ["gear/cyberdeck_poor", "gear/cyberdeck_standard", "gear/cyberdeck_excellent", "programs/sword", "programs/armor",
			"programs/see_ya", "programs/worm", "programs/speedy_gonzalvez", "programs/banhammer", "programs/ice_killer",
			"hardware/backup_drive", "hardware/hardened_circuitry", "hardware/insulated_wiring", "hardware/krash_barrier", "hardware/range_upgrade"]:
		assert_true(k in sold, "%s plays, so it's sold" % k)
	for k in ["programs/eraser", "programs/flak", "programs/shield", "programs/hellbolt", "programs/vrizzbolt", "programs/deckkrash",
			"programs/ice_hellhound", "hardware/dna_lock"]:
		assert_false(NightMarket.on_sale(k), "%s waits for its system" % k)
		assert_true(Deck.entry(k).has("unmodelled"), k)
	var cheap := NightMarket.matching({"kind": "netrun", "cost_max": 100})
	assert_true("programs/sword" in cheap and "hardware/range_upgrade" in cheap and not "programs/ice_killer" in cheap)
	assert_eq(NightMarket.matching({"kind": "netrun", "cost": 500}), ["programs/ice_killer"] as Array[String], "p338: exactly 500eb")
	var st := NightMarket.staples()
	assert_true("gear/cyberdeck_poor" in st and not "gear/cyberdeck_standard" in st, "only Premium and under without a Night Market")
	assert_true(NightMarket.on_sale("cyberware/cyberdeck"), "the arm's Cyberdeck plays now")


func test_the_v21_migration_gives_netrunners_their_deck() -> void:
	var d := {"version": 20, "crew": [{"role": "netrunner", "programs": ["sword", "armor"]}, {"role": "solo"}],
		"recruits": [{"role": "netrunner"}]}
	SaveMigrations._v20_to_v21(d)
	assert_eq(String(d.crew[0].deck), "cyberdeck_standard")
	var progs: Array = d.crew[0].programs
	progs.sort()
	var want: Array = Deck.STARTING_PROGRAMS.duplicate()
	want.sort()
	assert_eq(progs, want, "the starting set, the Sword and Armor they had counted in")
	assert_eq(String(d.crew[1].deck), "")
	assert_eq((d.crew[1].programs as Array).size(), 0)
	assert_eq((d.recruits[0].programs as Array).size(), 5)
	var c := Combatant.from_dict(_full_dict(d.crew[0]))
	assert_eq(c.deck, "cyberdeck_standard")
	assert_eq(c.programs.size(), 5)
	var round := Combatant.from_dict(c.to_dict())
	assert_eq(round.programs, c.programs, "saves and loads")
	assert_eq(SaveMigrations.CURRENT, 21)


func _full_dict(over: Dictionary) -> Dictionary:
	var d := _runner().to_dict()
	d.erase("deck")
	for k in over:
		d[k] = over[k]
	return d
