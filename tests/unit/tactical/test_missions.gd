extends TestCase
## Assassination and Rescue gigs (P2a).


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _enc(kind: String, seed_value := 11, sec := 2) -> Encounter:
	var m := SceneGen.generate(seed_value, "lone_building", {"security": sec, "site": "gang_hideout"})
	var dice := Dice.new(7)
	return Encounter.setup(m, dice, _crew(dice), kind)


func _target_sid(e: Encounter) -> int:
	for st in e.m.structures:
		if st.target:
			return st.id
	return -1


func test_the_mark_sits_deep_with_bodyguards() -> void:
	var e := _enc("assassinate")
	var vip: Dictionary = e.units[int(e.objective.target)]
	assert_true(vip.get("vip", false) and vip.team == 1, "the mark is a hostile VIP")
	var l := e.m.label(vip.pos.z, vip.pos.x, vip.pos.y)
	assert_true(l >= 0 and e.m.rooms[l].structure == _target_sid(e), "inside the target building")
	var guards := e.units.filter(func(u): return u.get("bodyguard", false) and e.adjacent(u.pos, vip.pos))
	assert_eq(guards.size(), 2, "two bodyguards beside the mark")
	assert_false((e.objective.exits as Array).is_empty(), "the mark has somewhere to run")
	assert_true(Names.is_person_name(String(e.objective.name)), "the mark has a generated Night City name (%s)" % e.objective.name)
	assert_eq(vip.c.display_name, String(e.objective.name))


func test_the_mark_runs_when_alerted_and_escape_fails_the_job() -> void:
	var e := _enc("assassinate")
	var vip: Dictionary = e.units[int(e.objective.target)]
	var exits: Array = e.objective.exits
	var field: Dictionary = e._with_locks(func(): return e.nav.distance_field(exits, {}, 4000))
	var d0 := int(field.get(vip.pos, 999))
	vip.alerted = true
	e.cur = vip
	e.turn = TurnState.begin(e.dice, vip.c)
	AI.act(e, vip)
	assert_true(int(field.get(vip.pos, 999)) < d0 or e.state == "lost", "the mark heads for an exit (%d -> %d)" % [d0, int(field.get(vip.pos, 999))])
	# put the mark on an exit square: next turn they're gone
	var ex: Vector3i = exits[0]
	vip.pos = ex
	e.turn = TurnState.begin(e.dice, vip.c)
	AI.act(e, vip)
	assert_eq(e.state, "lost")
	assert_true(e.objective.escaped, "escaped")


func test_downing_the_mark_then_withdrawing_wins() -> void:
	var e := _enc("assassinate")
	var vip: Dictionary = e.units[int(e.objective.target)]
	var home: Array = []
	for u in e.units:   # the crew is inside, near the mark
		if u.team == 0:
			home.append(u.pos)
			u.pos = vip.pos + Vector3i(0, 0, 0)
	vip.c.hp = -1
	vip.c.dead = true
	e._check_end()
	assert_true(e.objective.done, "the hit counts")
	assert_eq(e.state, "playing", "but the crew still has to get out")
	var i := 0
	for u in e.units:   # back to the extraction zone
		if u.team == 0:
			u.pos = home[i]
			i += 1
	e.cur = e.units[0]
	assert_true(e.can_withdraw())
	assert_true(e.withdraw())
	assert_eq(e.state, "won", "leaving after the hit is a success")


func test_captive_is_neutral_until_freed_then_follows_out() -> void:
	var e := _enc("rescue")
	var cap: Dictionary = e.units[int(e.objective.captive)]
	assert_eq(cap.team, 2, "neutral while held")
	assert_true(cap.c.weapons.is_empty(), "unarmed")
	assert_false(e.alive(0).has(cap), "doesn't see for the crew")
	var l := e.m.label(cap.pos.z, cap.pos.x, cap.pos.y)
	assert_true(l >= 0 and e.m.rooms[l].structure == _target_sid(e), "held in the target building")
	# a crew member next to them frees them
	var solo: Dictionary = e.units[0]
	e.cur = solo
	e.turn = TurnState.begin(e.dice, solo.c)
	assert_false(e.can_free(), "not from across the map")
	for d in MapGen.DIRS:
		var v: Vector3i = cap.pos + Vector3i(d.x, d.y, 0)
		if e.m.walkable(v.z, Vector2i(v.x, v.y)) and not e.occupied(solo).has(v):
			solo.pos = v
			break
	assert_true(e.can_free())
	assert_true(e.free_captive().ok)
	assert_eq(cap.team, 0, "on the crew's side")
	assert_true(e.objective.freed)
	# the follower stays with the crew
	solo.pos = cap.pos + Vector3i(4, 0, 0) if e.m.walkable(cap.pos.z, Vector2i(cap.pos.x + 4, cap.pos.y)) else solo.pos
	e.cur = cap
	e.turn = TurnState.begin(e.dice, cap.c)
	# the captive keeps up with whoever of the crew is nearest the way out (AI.follow's lead)
	var to_ex: Dictionary = e._with_locks(func(): return e.nav.distance_field(e.extract_cells.keys(), {}, 4000))
	var lead: Dictionary = solo
	for o in e.units:
		if int(o.team) == 0 and o != cap and o.c.can_act() and int(to_ex.get(o.pos, 9999)) < int(to_ex.get(lead.pos, 9999)):
			lead = o
	var walk: Dictionary = e._with_locks(func(): return e.nav.distance_field([lead.pos], {}, 4000))   # on foot, not as the crow flies
	var before := int(walk.get(cap.pos, 999))
	AI.follow(e, cap)
	var after := int(walk.get(cap.pos, 999))
	assert_true(after <= before, "follows (%d -> %d squares' walk)" % [before, after])
	# into the extraction zone = done
	cap.pos = e.extract_cells.keys()[0]
	e._check_end()
	walk_out(e)
	assert_eq(e.state, "won")


func test_a_dead_captive_fails_the_job() -> void:
	var e := _enc("rescue")
	var cap: Dictionary = e.units[int(e.objective.captive)]
	cap.c.dead = true
	e._check_end()
	assert_eq(e.state, "lost")


func test_new_gig_kinds_on_the_board() -> void:
	assert_eq(Campaign.objective_for({"kind": "assassination"}), "assassinate")
	assert_eq(Campaign.objective_for({"kind": "rescue"}), "rescue")
	var g := RulesDB.gen("gigs.json")
	assert_true(g.templates.any(func(t): return t.kind == "assassination") and g.templates.any(func(t): return t.kind == "rescue"))


func test_sabotage_plant_fuse_and_blast() -> void:
	var e := _enc("sabotage")
	var tc: Vector3i = e.objective.cell
	assert_true(e.m.has_cover_at(tc.z, Vector2i(tc.x, tc.y)), "the machine stands in the most secure room")
	assert_true(e.objective.target_kind in e.obj.cfg.targets, "a known machine")
	var solo: Dictionary = e.units[0]
	e.cur = solo
	e.turn = TurnState.begin(e.dice, solo.c)
	assert_false(e.can_plant(), "not from the deploy zone")
	for d in MapGen.DIRS:
		var v: Vector3i = tc + Vector3i(d.x, d.y, 0)
		if e.m.walkable(v.z, Vector2i(v.x, v.y)) and not e.occupied(solo).has(v):
			solo.pos = v
			break
	assert_true(e.can_plant())
	assert_true(e.plant_charge().ok)
	assert_eq(e.fuse_left(), int(e.obj.cfg.fuse_rounds))
	# the planter stays put: the blast catches them, wrecks the machine
	e.init.round_num += int(e.obj.cfg.fuse_rounds)
	var hp0: int = solo.c.hp
	e._tick_fuse()
	assert_true(e.objective.done, "the machine is wrecked")
	assert_false(e.m.has_cover_at(tc.z, Vector2i(tc.x, tc.y)), "nothing left of it")
	assert_true(e.events.any(func(ev): return ev.type == "blast" and ev.get("charge", false)), "a charge blast event")
	assert_true(solo.c.hp < hp0 or e.events.any(func(ev): return ev.type == "blast" and ev.hits.any(func(h): return h.id == solo.id and h.dodged)), "standing next to it hurts")


func test_civilians_scatter_on_gunfire_and_count_as_collateral() -> void:
	var m := SceneGen.generate(7, "neighborhood", {"security": 1, "profile": "market_streets"})
	var dice := Dice.new(4)
	var e := Encounter.setup(m, dice, _crew(dice), "eliminate")
	var civs := e.units.filter(func(u): return u.get("civ", false))
	assert_true(civs.size() >= 3, "bystanders in a market (%d)" % civs.size())
	var c0: Dictionary = civs[0]
	e._noise(c0.pos)
	assert_true(c0.panic, "gunfire panics them")
	var p0: Vector3i = c0.pos
	e._civilians_tick()
	assert_true(c0.pos != p0 or c0.get("fled", false) or Encounter.cowering(c0), "and they run, hide or cower")
	assert_false(e.init.entries.any(func(x): return x.c == c0.c), "bystanders never join the initiative")
	var c1: Dictionary = civs[1]
	c1.c.hp = -5
	c1.c.dead = true
	e._check_end()
	assert_eq(e.civ_casualties, 1, "a hurt bystander counts")


func test_trauma_team_lands_for_a_downed_cardholder_and_lifts_them() -> void:
	var m := SceneGen.generate(11, "lone_building", {"security": 2, "site": "corp_office"})
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), "assassinate")
	var vip: Dictionary = e.units[int(e.objective.target)]
	assert_true(vip.get("trauma_card", false), "a corp mark has a Trauma Team card")
	for u in e.units:   # the crew is inside, not at the extraction zone
		if u.team == 0:
			u.pos = vip.pos
	vip.c.hp = 4   # knocked out, not dead (a flatlined mark: the test below)
	vip.c.unconscious = true
	e._check_end()
	assert_false(e.tt.is_empty(), "the card pings")
	e.init.round_num += Encounter.TT_ROUNDS
	e._tick_trauma()
	assert_eq(String(e.tt.state), "landed", "the AV lands")
	var team := e.units.filter(func(u): return u.get("tt", false))
	assert_eq(team.size(), 3)
	assert_true(e.events.any(func(ev): return ev.type == "av_land" and ev.kind == "trauma"))
	# a medic beside the patient picks them up, carries them to the AV, and they're gone
	var medic: Dictionary = team[0]
	for d in MapGen.DIRS:   # (a bodyguard may stand there: fine for this test)
		var v: Vector3i = vip.pos + Vector3i(d.x, d.y, 0)
		if e.m.walkable(v.z, Vector2i(v.x, v.y)):
			medic.pos = v
			break
	e.cur = medic
	e.turn = TurnState.begin(e.dice, medic.c)
	AI.trauma(e, medic)
	assert_eq(int(e.tt.carrier), medic.id, "patient secured")
	medic.pos = e.tt.av
	e.turn = TurnState.begin(e.dice, medic.c)
	AI.trauma(e, medic)
	assert_eq(String(e.tt.state), "gone", "they lift off")
	assert_eq(e.state, "lost", "Trauma Team saved the mark: the hit failed")


func test_trauma_team_extracts_a_flatlined_cardholders_body() -> void:
	var m := SceneGen.generate(11, "lone_building", {"security": 2, "site": "corp_office"})
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), "assassinate")
	var vip: Dictionary = e.units[int(e.objective.target)]
	assert_false(vip.c.death_saves, "cardholders get no Death Saves (NPC_FLATLINE)")
	for u in e.units:   # the crew is inside, not at the extraction zone
		if u.team == 0:
			u.pos = vip.pos
	Attack.apply_damage(e.dice, vip.c, {"damage": vip.c.hp + 40, "location": "body"}, false, false, false)
	assert_true(vip.c.dead, "the mark flatlines below 1 HP")
	e._check_end()
	assert_eq(int(e.tt.get("patient", -1)), vip.id, "the card pings for the body")
	e.init.round_num += Encounter.TT_ROUNDS
	e._tick_trauma()
	assert_eq(String(e.tt.state), "landed", "Trauma Team still comes")
	var team := e.units.filter(func(u): return u.get("tt", false))
	assert_false(team.is_empty())
	var medic: Dictionary = team[0]
	e.cur = medic
	for k in 30:   # walk to the body (their own pathing), pick it up
		e.turn = TurnState.begin(e.dice, medic.c)
		AI.trauma(e, medic)
		if int(e.tt.carrier) == medic.id:
			break
	assert_eq(int(e.tt.carrier), medic.id, "they reach the body and pick it up")
	assert_true(vip.get("carried", false))
	for k in 30:   # and carry it back
		e.turn = TurnState.begin(e.dice, medic.c)
		AI.trauma(e, medic)
		if String(e.tt.state) == "gone":
			break
	assert_eq(String(e.tt.state), "gone", "they leave with it")
	assert_true(vip.get("extracted", false), "the body is extracted")
	assert_true(e.state != "lost", "a body flown out doesn't blow the hit")
	assert_true(e.objective.get("done", false), "the mark is down")


func test_maxtac_drop() -> void:   # no doctrine escalates to it (campaign heat is gone); dev renders call it
	var m := SceneGen.generate(7, "street_block", {"security": 2})
	var dice := Dice.new(5)
	var e := Encounter.setup(m, dice, _crew(dice), "eliminate")
	e._maxtac_drop()
	var mt := e.units.filter(func(u): return u.get("maxtac", false))
	assert_true(mt.size() >= 3, "a MaxTac squad (%d)" % mt.size())
	assert_true(mt.all(func(u): return e.hostile(u.team, Encounter.CREW) and e.is_guard(u) and u.c.sp("body") >= 18), "hostile, in heavy armour")
	assert_true(mt.all(func(u): return e.faction_of(u) == "maxtac" and e.opfor().has(u)), "their own side, and part of the fight to win")
	assert_true(e.events.any(func(ev): return ev.type == "av_land" and ev.kind == "maxtac"), "arriving by AV")


# --- Night City's civilians (NC2045 civilian blocks) ----------------------------------------

func _market(opts: Dictionary) -> Encounter:
	var m := SceneGen.generate(7, "neighborhood", {"security": 1, "profile": "market_streets"})
	var dice := Dice.new(4)
	return Encounter.setup(m, dice, _crew(dice), "eliminate", opts)


func test_bystanders_are_the_districts_civilians_and_unarmed() -> void:
	var e := _market({"district": "kabuki"})
	var civs := e.units.filter(func(u): return u.get("civ", false))
	assert_true(civs.size() >= 3)
	var all := Recruit.civilian_blocks()
	assert_true(civs.all(func(u): return String(u.c.block) in all), "every bystander is a civilian stat block")
	assert_true(civs.any(func(u): return String(u.c.block) in Recruit.civilian_blocks("kabuki")), "Kabuki's own people among them")
	assert_true(civs.all(func(u): return u.c.weapons.is_empty() and not u.get("local", false)), "bystanders carry nothing")
	assert_true(civs.all(func(u): return String(u.c.faction) == "bystanders" and int(u.team) == Encounter.CIV_TEAM))


func test_a_place_its_patrons_guard_keeps_their_weapons() -> void:
	var e := _market({"district": "kabuki", "security_code": {"n": 10, "faction": "locals", "intensity": "heavy", "hardened": false}})
	var civs := e.units.filter(func(u): return u.get("civ", false))
	assert_true(civs.size() >= 3)
	assert_true(civs.all(func(u): return u.get("local", false)), "they're the place's locals")
	assert_true(civs.any(func(u): return not u.c.weapons.is_empty()), "armed as printed")


func test_civilian_blocks_by_district_fall_back_to_the_city() -> void:
	var all := Recruit.civilian_blocks()
	assert_eq(all.size(), 32, "Night City 2045 prints 32 civilians")
	assert_eq(Recruit.civilian_blocks("kabuki"), ["delphi_x_dancer", "kabuki_market_vendor"] as Array[String])
	assert_eq(Recruit.civilian_blocks("charter_hill"), all, "a district with none: anyone in the city")
	assert_eq(Recruit.civilian_blocks(""), all)
	var c := Recruit.civilian(Dice.new(1), "minimallism_fixer", "Crux")
	assert_eq(c.display_name, "Crux")
	assert_eq(c.role, "mook", "an NPC's role is its tier, as printed")


func test_the_captive_is_a_civilian() -> void:
	var e := _enc("rescue")
	var cap: Dictionary = e.units[int(e.objective.captive)]
	assert_true(String(cap.c.block) in Recruit.civilian_blocks(), "one of Night City's civilians (%s)" % cap.c.block)
	assert_true(cap.c.weapons.is_empty(), "disarmed")
	assert_true(Names.is_person_name(String(cap.c.display_name)), "a generated Night City name (%s)" % cap.c.display_name)


func test_a_corp_mark_is_an_executive_and_a_police_mark_one_of_their_own() -> void:
	var cfg: Dictionary = RulesDB.gen("objectives.json").assassinate
	var dice := Dice.new(3)
	for i in 6:
		assert_true(_vip_block("militech", cfg, dice) in ["junior_executive", "rupture_fighter"], "a corp's mark is an exec")
		assert_eq(_vip_block("maelstrom", cfg, dice), "minimallism_fixer", "a gang's, a fixer")
	assert_eq(_vip_block("sk_securities", cfg, dice), "", "the police: one of their own")
	var e := _enc("assassinate")   # generic security: a corp
	var vip: Dictionary = e.units[int(e.objective.target)]
	assert_true(String(vip.c.block) in ["junior_executive", "rupture_fighter"], "the mark is an exec (%s)" % vip.c.block)
	assert_eq(String(vip.c.faction), e.opfor_faction)
	assert_true(vip.get("vip", false) and vip.team == Encounter.OPFOR)
	var m := SceneGen.generate(11, "lone_building", {"security": 2, "site": "gang_hideout"})
	var d2 := Dice.new(7)
	var pe := Encounter.setup(m, d2, _crew(d2), "assassinate", {"faction": "sk_securities"})
	var pv: Dictionary = pe.units[int(pe.objective.target)]
	assert_true(String(pv.c.block) in SecurityCode.tier_pool("sk_securities", "mini_boss", false), "SK's own Mini Boss (%s)" % pv.c.block)


func _vip_block(fid: String, cfg: Dictionary, dice: Dice) -> String:
	return (load("res://src/tactical/objectives/assassinate.gd") as GDScript).vip_block(fid, cfg, dice)
