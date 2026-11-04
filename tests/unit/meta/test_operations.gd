extends TestCase
## M9 P4: operations, gigs of several maps played back to back (Playland by the Sea).


## A campaign whose crew has a name (Reputation 5: every security level, p193) and a Playland
## operation of `legs` legs on the board, taken.
func _taken(seed_value: int, legs := 0) -> Campaign:
	var c := Campaign.new_game(seed_value)
	c.crew[0].reputation = 5
	var op := {}
	for k in 40:
		op = c.operation_offer("playland", 5)
		if legs == 0 or (op.legs as Array).size() == legs:
			break
	c.board = [op]
	c.accept(0)
	return c


## The encounter for the leg being played, as the greybox builds it (no 3D).
func _leg(c: Campaign) -> Encounter:
	var g := c.active_gig
	var m := SceneGen.generate(int(g.seed), String(g.scene), Campaign.scene_opts(g))
	var crew: Array[Combatant] = []
	for x in c.alive_crew():
		if x.can_act():
			crew.append(x)
	return Encounter.setup(m, c.dice, crew, Campaign.objective_for(g), Campaign.encounter_opts(g))


func test_offers_are_deterministic_and_follow_the_park() -> void:
	var a := Campaign.new_game(21)
	var b := Campaign.new_game(21)
	assert_eq(JSON.stringify(a.operation_offer("playland", 5)), JSON.stringify(b.operation_offer("playland", 5)), "same seed, same offer")
	var od: Dictionary = RulesDB.gen("operations.json").playland
	var lands: Dictionary = RulesDB.world("playland.json").lands
	var pay: Dictionary = RulesDB.gen("gigs.json").pay
	for k in 25:
		var g := a.operation_offer("playland", 5)
		var legs: Array = g.legs
		assert_between(float(legs.size()), 2.0, 3.0, "two or three legs")
		var total := 0
		var codes := []
		for leg in legs:
			var land: Dictionary = lands[leg.land]
			assert_true(int(String(leg.location).get_slice("_", 1)) in (land.locations as Array).map(func(n): return int(n)), "the leg's place is in its land: %s" % leg.location)
			assert_eq(String(leg.district), "playland")
			assert_eq(String(leg.profile), String(land.profile), "played on the land's own generator")
			assert_eq(int(leg.security_code.n), int(World.location(String(leg.location)).security_code.n), "under the place's own Security Code")
			assert_eq(int(leg.pay), int(pay[str(int(leg.security))]), "each leg pays the book rate for its level")
			total += int(leg.pay)
			codes.append(int(leg.security_code.n))
		assert_eq(int(g.pay), total, "the shares sum to the operation's pay")
		assert_true(codes[0] < codes[-1], "the way in is a land with a lower Security Code than the target's")
		var job: Dictionary = (od.jobs as Array).filter(func(j): return j.title == g.title)[0]
		assert_true(String(legs[-1].land) in job.lands, "the target leg is in a land that suits the job")
		assert_eq(String(legs[-1].kind), String(job.kind))
		assert_true(String(g.blurb).begins_with(String(g.fixer)))
		if String(legs[-1].faction) == "piranhas":
			assert_true(String(g.fixer_id) != "ricky_hamilton", "the park's Piranha boss doesn't hire hits on his own gang")


func test_a_crew_nobody_knows_gets_no_operation() -> void:
	var c := Campaign.new_game(22)
	assert_true(c.operation_offer("playland", 0).is_empty(), "every land past the gate is Medium or Heavy: a name is needed (p193)")


func test_operations_are_rare_on_the_board() -> void:
	var c := Campaign.new_game(23)
	c.crew[0].reputation = 5
	var ops := 0
	for d in 120:
		c.day += 1
		c.refresh_board()
		ops += c.board.filter(func(g): return Campaign.is_operation(g)).size()
	assert_between(float(ops), 3.0, 30.0, "about one board in ten (operations.json chance)")


func test_weapons_banned_at_the_gate_wait_in_the_van() -> void:
	var c := Campaign.new_game(24)
	var a: Combatant = c.crew[0]
	a.weapons.clear()
	a.weapons.append(Weapon.from_id("assault_rifle"))
	a.weapons.append(Weapon.from_id("heavy_pistol"))
	a.weapons[0].ammo = 7
	assert_false(Campaign.smuggles(a.weapons[0]), "an assault rifle can't be hidden (conceal: false)")
	assert_true(Campaign.smuggles(a.weapons[1]), "a heavy pistol can (conceal: true)")
	assert_eq(Campaign.banned_weapons(a), [a.weapons[0].display_name()])
	a.reputation = 5
	c.board = [c.operation_offer("playland", 5)]
	c.accept(0)
	assert_eq(a.weapons.size(), 1, "only the pistol goes in")
	assert_eq(a.weapons[0].id(), "heavy_pistol")
	assert_eq(c.van_list().size(), 1)
	var e := _leg(c)
	e.state = "fled"
	c.resolve(e)
	assert_eq(a.weapons.size(), 2, "the rifle comes back after the operation")
	assert_eq(a.weapons[0].id(), "assault_rifle", "where it was")
	assert_eq(a.weapons[0].ammo, 7)


func test_a_won_leg_goes_straight_on_with_everything_as_it_stands() -> void:
	var c := _taken(25, 3)
	var a: Combatant = c.alive_crew()[0]
	var eb0 := c.eb
	var t0 := c.day * Campaign.DAY_MINUTES + c.minutes
	var e := _leg(c)
	assert_eq(int(c.active_gig.leg), 0)
	a.hp = maxi(1, a.hp - 6)
	a.kit_spent[0] = true
	a.drugs_taken.append("synthcoke")
	var hp := a.hp
	var ammo := a.weapons[0].ammo - 1 if not a.weapons.is_empty() else 0
	if not a.weapons.is_empty():
		a.weapons[0].ammo = ammo
	if a.armor.get("body"):
		a.armor.body.sp = maxi(0, a.armor.body.sp - 2)
	var sp := a.sp("body")
	e.state = "won"
	var r := c.next_leg(e)
	assert_eq(int(r.leg), 0)
	assert_eq(int(c.active_gig.leg), 1, "on to the second leg")
	assert_eq(String(c.active_gig.location), String(c.active_gig.legs[1].location), "its map is the active gig's")
	assert_eq(c.day * Campaign.DAY_MINUTES + c.minutes - t0, int(RulesDB.gen("operations.json").playland.streetcar_minutes), "a streetcar ride, no rest")
	assert_eq(c.eb, eb0, "paid at the end")
	var e2 := _leg(c)
	assert_eq(a.hp, hp, "no healing between legs")
	assert_true(a.kit_spent[0], "kit used stays used")
	assert_true("synthcoke" in a.drugs_taken, "the dose is still in the system")
	if not a.weapons.is_empty():
		assert_eq(a.weapons[0].ammo, ammo, "no reload from the safehouse")
	assert_eq(a.sp("body"), sp, "armour stays ablated")
	assert_true(e2.units.any(func(u): return u.c == a))


func test_the_dying_are_carried_and_come_round_on_the_ride() -> void:
	var c := _taken(26, 2)
	var crew := c.alive_crew()
	var e := _leg(c)
	crew[1].hp = -2
	e.state = "won"
	c.next_leg(e)
	assert_eq(crew[1].hp, 1, "stabilized (p222-223)")
	assert_false(crew[1].unconscious, "a minute out (p223): awake by the end of the ride")


func test_completing_every_leg_pays_the_whole_operation() -> void:
	var c := _taken(27, 3)
	var eb0 := c.eb
	var pay := int(c.active_gig.pay)
	var n := (c.active_gig.legs as Array).size()
	var r := {}
	for i in n:
		var e := _leg(c)
		e.state = "won"
		if c.has_next_leg():
			c.next_leg(e)
		else:
			r = c.resolve(e)
	assert_true(r.won, "the last leg won the operation")
	assert_eq(int(r.pay), pay)
	assert_eq(c.eb, eb0 + pay, "every leg's share")
	assert_eq((r.legs as Array).size(), n, "the debrief covers every leg")
	assert_eq(c.crew[0].ip, int(Campaign.IP_GROUP.together), "one mission's IP (p410), not one per map")
	assert_true(c.active_gig.is_empty())


func test_withdrawing_ends_the_whole_operation() -> void:
	var c := _taken(28, 3)
	var eb0 := c.eb
	var first := int(c.active_gig.legs[0].pay)
	var e := _leg(c)
	e.state = "won"
	c.next_leg(e)
	var e2 := _leg(c)
	e2.state = "fled"
	var r := c.resolve(e2)
	assert_false(r.won)
	assert_eq(int(r.pay), first, "the leg done is paid, the rest isn't")
	assert_eq(c.eb, eb0 + first)
	assert_true(c.active_gig.is_empty(), "no third leg")
	assert_eq(c.crew[0].ip, int(Campaign.IP_GROUP.failed))
	assert_eq(c.crew[1].reputation, 0, "no deed for a job not done")
	# Between legs: a won leg and then home.
	var d := _taken(29, 2)
	var eb1 := d.eb
	var e3 := _leg(d)
	e3.state = "won"
	var r2 := d.resolve(e3)
	assert_false(r2.won, "withdrew before the target")
	assert_eq(d.eb, eb1 + int(r2.pay))
	assert_eq((r2.legs as Array).size(), 1)


func test_an_operation_survives_a_save_between_legs() -> void:
	var c := _taken(30, 3)
	var a: Combatant = c.alive_crew()[0]
	var e := _leg(c)
	e.state = "won"
	c.next_leg(e)
	a.kit_spent[1] = true
	a.drugs_taken.append("blue_glass")
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(int(back.active_gig.leg), 1, "the operation carries on at its second leg")
	assert_eq(JSON.stringify(back.active_gig.legs), JSON.stringify(c.active_gig.legs))
	assert_eq(int(back.active_gig.security), int(c.active_gig.security))
	assert_eq(int(back.active_gig.security_code.n), int(c.active_gig.security_code.n), "codes come back as numbers")
	var b: Combatant = back.alive_crew()[0]
	assert_true(b.kit_spent[1], "kit used is remembered")
	assert_true("blue_glass" in b.drugs_taken)
	assert_eq(back.van_list(), c.van_list(), "and so is the van")
	assert_true(back.has_next_leg())
	assert_true(Campaign.new_game(31).to_dict().operation.is_empty(), "no operation, nothing saved")


func test_a_v10_save_loads_with_no_operation() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 10
	d.erase("operation")
	var c := Campaign.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_true(c != null)
	assert_true(c.active_gig.is_empty())
	assert_eq(int(c.to_dict().version), SaveMigrations.CURRENT)
	assert_eq(c.to_dict().operation, {})


func test_the_haunted_woods_blind_the_drones() -> void:
	var leg := {"scene": "neighborhood", "profile": "haunted_woods", "site": "club", "security": 2, "no_drones": true}
	var m := SceneGen.generate(77, "neighborhood", Campaign.scene_opts(leg))
	assert_false(m.devices.any(func(d): return d.type in ["camera", "turret"]), "the fake trees blind the drones (NC2045 p.308)")
	leg.erase("no_drones")
	var m2 := SceneGen.generate(77, "neighborhood", Campaign.scene_opts(leg))
	assert_true(m2.devices.any(func(d): return d.type == "camera"), "elsewhere the park is watched")


func test_a_theme_park_land_has_midways_rides_and_the_sea() -> void:
	var m := SceneGen.generate(5, "neighborhood", {"profile": "theme_park", "site": "club", "security": 2})
	var water := 0
	var dock := 0
	var asphalt := 0
	for y in m.h:
		for x in m.w:
			if m.t(0, x, y) == TacMap.T.WATER:
				water += 1
			match m.ground[y * m.w + x]:
				TacMap.G.DOCK: dock += 1
				TacMap.G.ASPHALT: asphalt += 1
	assert_true(water > 0 and dock > 0, "a boardwalk on the sea")
	assert_eq(asphalt, 0, "midways, not roads")
	assert_true(m.rooms.any(func(r): return r.kind == "ride"), "fenced ride enclosures")
	assert_true(m.structures.any(func(s): return s.target), "the attraction is the target building")


func test_event_effects_reach_the_encounter() -> void:
	var c := _taken(32, 2)
	c.active_gig["police"] = 2
	c.active_gig["civilians"] = ["junior_executive"]
	c.active_gig["lights_off"] = true
	var e := _leg(c)
	assert_eq(e.units.filter(func(u): return e.faction_of(u) == "ncpd").size(), 2, "NCPD Night: uniformed cops in the crowd")
	assert_true(e.units.filter(func(u): return e.faction_of(u) == "ncpd").all(func(u): return not u.alerted))
	assert_true(e.units.any(func(u): return u.get("civ", false) and u.c.block == "junior_executive"), "the job fair's recruiters")
	assert_true(e.lights_out(), "Fright Nights: the lights are down")
