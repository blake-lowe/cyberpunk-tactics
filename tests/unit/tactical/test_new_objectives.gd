extends TestCase
## The objectives built for the Mission Builder's disabled rows (owner: "new objectives, all five
## over time"): escort, defend, deliver, plant, distraction. Each one: success and failure, the HUD
## order, its markers, the AI's interest in it, its Mission Types rows, and a board offer that
## saves and loads.


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _job(kind: String, site := "corp_office", seed := 11, scene := "lone_building") -> Encounter:
	var m := SceneGen.generate(seed, scene, {"security": 2, "site": site})
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), kind)
	e.next_turn()
	return e


## The HUD's objective text: an upper-case order under 40 characters on line 1 (owner style).
func _hud_ok(e: Encounter, what: String) -> void:
	var ht: String = e.obj.hud_text()
	assert_true(ht != "" and ht == ht.to_upper(), "%s: upper case: %s" % [what, ht])
	assert_true(ht.split("\n")[0].length() < 40, "%s: the order fits: %s" % [what, ht.split("\n")[0]])
	assert_false(ht.contains("FLOOR") or ht.contains("STOREY"), "%s: never spells out floors" % what)


func _marks_ok(e: Encounter, what: String) -> void:
	for fog in [false, true]:
		for mk in e.obj.marks(fog):
			assert_true(mk.get("extract", false) or (mk.cell is Vector3i and e.m.inb(mk.cell.x, mk.cell.y) and String(mk.label).begins_with("★ ")
				and String(mk.tone) in ["gold", "red", "cyan"]), "%s: a well-formed marker %s" % [what, mk])


## A guard of the opposition whose id is (or isn't) a multiple of `every`.
func _guard(e: Encounter, every: int, hunter: bool) -> Dictionary:
	for u in e.units:
		if e.is_guard(u) and e.hostile(int(u.team), Encounter.CREW) and not u.c.dead and ((int(u.id) % every == 0) == hunter):
			return u
	return {}


## The rows of `objective` in the Mission Types table, and each maps back to a gig kind.
func _rows_ok(objective: String, ids: Array) -> void:
	var rows := MissionBuilder.rows_for(objective)
	var got: Array = rows.map(func(r): return String(r.id))
	got.sort()
	ids.sort()
	assert_eq(got, ids, "%s plays these Mission Types rows (SPM p.72)" % objective)
	for r in rows:
		assert_eq(String(Campaign.OBJECTIVES.get(MissionBuilder.kind_of(r), "")), objective, "%s: a gig kind that plays %s" % [r.id, objective])
		assert_true(String(r.get("framing", "")) != "", "%s: framed" % r.id)
	assert_true(MissionBuilder.plays(objective).size() > 0, "%s: plays some focus items" % objective)
	assert_eq((MissionBuilder.data().focus.debrief as Dictionary).get(objective, []).size(), 2, "%s: debrief lines, won and not" % objective)


## A board offer of `kind` made by the board's own code, put on a campaign's board, saves and loads
## unchanged, and plays as its objective.
func _offer_saves(kind: String, objective: String) -> void:
	var c := Campaign.new_game(31)
	var g := RulesDB.gen("gigs.json")
	var gig := c._city_offer(g, kind, 2, 2, {})
	assert_false(gig.is_empty(), "%s: a canon place hosts it" % kind)
	if gig.is_empty():
		return
	gig["id"] = "test-%s" % kind
	assert_eq(Campaign.objective_for(gig), objective)
	assert_true(Campaign.kinds_at(World.location(String(gig.location))).has(kind), "%s: at a place that offers it" % kind)
	assert_true(Campaign.targetable(String(gig.faction), kind), "%s: against a faction it can be against" % kind)
	assert_eq(String(gig.mission.objective), objective, "its mission type plays %s" % objective)
	assert_true(MissionBuilder.fits(MissionBuilder.focus_def("%s/%s" % [gig.focus.category, gig.focus.id]), objective), "a focus %s plays" % objective)
	assert_false(String(gig.blurb).contains("{"), "slots filled: %s" % gig.blurb)
	c.board.append(gig)
	var before := JSON.stringify(c.to_dict())
	var back := Campaign.from_dict(JSON.parse_string(before))
	assert_true(back != null, "%s: the save loads" % kind)
	if back == null:
		return
	assert_eq(JSON.stringify(back.to_dict()), before, "%s: the board round-trips" % kind)
	assert_eq(String(back.board[-1].kind), kind)
	var idx := back.board.size() - 1
	assert_false(back.accept(idx).is_empty(), "%s: the reloaded offer can be taken" % kind)
	var s := GigSetup.for_campaign(back)
	assert_eq(String(s.enc.objective.kind), objective, "%s: and plays as %s" % [kind, objective])


# --- Escort ------------------------------------------------------------------------------------

func test_escort_the_client_is_a_ward_beside_the_crew_with_a_far_rendezvous() -> void:
	var e := _job("escort")
	var o := e.objective
	assert_eq(String(o.mode), "through", "a map with a far exit: walk them across")
	var cu: Dictionary = e.units[int(o.client)]
	assert_eq(int(cu.team), Encounter.CREW, "on the crew's side")
	assert_true(e.is_hostage(cu), "a ward: the player's to move, not one of the crew")
	assert_eq(Hud.crew_tag(cu), "CLIENT")
	assert_true(cu.c.weapons.is_empty(), "unarmed")
	assert_true(e.init.order().has(cu.c), "takes turns")
	assert_true(e.extract_cells.has(cu.pos) or Vector2(cu.pos.x - e.units[0].pos.x, cu.pos.y - e.units[0].pos.y).length() < 6.0, "starts with the crew")
	var walk: Dictionary = e.nav.distance_field([cu.pos], {}, 4000)
	assert_true(int(walk.get(o.at, 0)) >= 12, "the rendezvous is a real walk away (%d)" % int(walk.get(o.at, 0)))
	assert_true((o.dest as Array).has(o.at), "and its squares include it")
	assert_eq(e.obj.ward_goal(), o.dest, "the ward heads there (AI.follow)")
	assert_eq(e.obj.zones().size(), 1, "the view tints the rendezvous")
	_hud_ok(e, "escort")
	assert_true(e.obj.hud_text().begins_with("GET %s TO THE RENDEZVOUS" % String(o.name).to_upper()), e.obj.hud_text())
	_marks_ok(e, "escort")
	var labels: Array = e.obj.marks(true).map(func(mk): return String(mk.get("label", "")))
	assert_true(labels.has("★ RENDEZVOUS"), "the rendezvous is marked: %s" % [labels])
	assert_true(labels.has("★ CLIENT · %s" % String(o.name).to_upper()), "and so is the client")
	assert_eq(e.obj.focus_unit(), int(o.client))
	assert_true(Objective.kinds().has("escort"))


func test_escort_wins_at_the_rendezvous_and_fails_if_the_client_flatlines() -> void:
	var e := _job("escort")
	var cu: Dictionary = e.units[int(e.objective.client)]
	cu.pos = e.objective.at
	e._check_end()
	assert_eq(e.state, "won", "the client made it")
	assert_true(e.obj.done())
	var e2 := _job("escort")
	var cu2: Dictionary = e2.units[int(e2.objective.client)]
	cu2.c.dead = true
	e2._check_end()
	assert_eq(e2.state, "lost", "the client flatlined")
	var e3 := _job("escort")
	var cu3: Dictionary = e3.units[int(e3.objective.client)]
	cu3.c.hp = -1   # Mortally Wounded: still with us, and the HUD says so
	assert_true(e3.obj.hud_text().contains("BLEEDING OUT"), e3.obj.hud_text())
	e3._check_end()
	assert_eq(e3.state, "playing", "dying isn't dead yet")


func test_escort_guards_hunt_the_client_sometimes() -> void:
	var e := _job("escort", "gang_hideout")
	var every := int(e.obj.cfg.hunt_every)
	var cu: Dictionary = e.units[int(e.objective.client)]
	var hunter := _guard(e, every, true)
	var other := _guard(e, every, false)
	assert_false(hunter.is_empty() or other.is_empty(), "both kinds of guard on the posts")
	if hunter.is_empty() or other.is_empty():
		return
	e.cur = hunter
	assert_eq(e.obj.ai_target_mult(cu), float(e.obj.cfg.hunt_mult), "a hunter wants the client")
	assert_eq(e.obj.ai_target_mult(e.units[0]), 1.0, "the crew as usual")
	var near := Vector3i(cu.pos.x + 1, cu.pos.y, cu.pos.z)
	var far := Vector3i(cu.pos.x + 9, cu.pos.y, cu.pos.z)
	assert_true(e.obj.ai_pull(hunter, near) > e.obj.ai_pull(hunter, far), "and closes on them")
	e.cur = other
	assert_eq(e.obj.ai_target_mult(cu), float(e.obj.cfg.client_mult), "the rest weigh them a little over the crew")
	assert_eq(e.obj.ai_pull(other, near), 0.0)
	assert_true(float(e.obj.cfg.hunt_mult) > float(e.obj.cfg.client_mult) and float(e.obj.cfg.client_mult) > 1.0)


func test_escort_with_no_way_across_waits_at_a_pickup_point() -> void:
	var m := SceneGen.generate(11, "lone_building", {"security": 2, "site": "corp_office"})
	m.entrances = m.entrances.filter(func(en): return en.kind == "deploy")
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), "escort")
	e.next_turn()
	var o := e.objective
	assert_eq(String(o.mode), "pickup")
	var cu: Dictionary = e.units[int(o.client)]
	assert_eq(int(cu.team), Encounter.CAPTIVE, "waiting inside, nobody's side yet")
	assert_false(e.init.order().has(cu.c))
	assert_true(e.obj.hud_text().begins_with("MEET "), e.obj.hud_text())
	_hud_ok(e, "pickup")
	assert_true(e.obj_actions().is_empty(), "nothing to do from the deploy zone")
	e.cur.pos = cu.pos + Vector3i(1, 0, 0) if e.m.walkable(cu.pos.z, Vector2i(cu.pos.x + 1, cu.pos.y)) else cu.pos + Vector3i(-1, 0, 0)
	assert_eq(e.obj_actions(), ["meet"] as Array[String], "beside them: meet")
	assert_eq(Hud.interact_here(e)[1], "MEET CLIENT", "the interact slot names it")
	assert_true(e.obj_act("meet").ok)
	assert_eq(int(cu.team), Encounter.CREW, "with the crew now")
	assert_true(e.init.order().has(cu.c))
	assert_true(bool(e.obj.marks(true)[0].get("extract", false)), "and the way out is the extraction zone")
	cu.pos = e.extract_cells.keys()[0]
	e._check_end()
	assert_eq(e.state, "won")


func test_escort_rows_are_enabled() -> void:
	_rows_ok("escort", ["escort_client", "protect_client", "protect_vip", "smuggle_people"])
	assert_eq(Campaign.host_kinds("escort"), ["escort", "rescue", "assassination"], "plays where rescues and hits do")


func test_escort_offers_save_and_load() -> void:
	_offer_saves("escort", "escort")


# --- Defend ------------------------------------------------------------------------------------

## Play the round clock forward to round `r`, a round at a time (Defend.tick judges each end).
func _to_round(e: Encounter, r: int) -> void:
	while e.init.round_num < r and e.state == "playing":
		e.init.round_num += 1
		e.obj.tick()


func test_defend_the_crew_holds_an_unguarded_room() -> void:
	var e := _job("defend")
	var o := e.objective
	assert_false(e.obj.manned())
	assert_true(e.opfor().is_empty(), "nobody on the posts: the attack comes in waves")
	var zone: Array = o.zone
	assert_true(zone.size() >= 4, "a room to hold (%d squares)" % zone.size())
	var l := e.m.label(o.cell.z, o.cell.x, o.cell.y)
	assert_true(zone.all(func(v): return e.m.label(v.z, v.x, v.y) == l and e.m.walkable(v.z, Vector2i(v.x, v.y))), "squares of one room, all standable")
	assert_eq(int(e.los.cover_hp.get(o.cell, 0)), 50, "the asset is thick steel (CPR core p.182)")
	assert_true(e.nav.locked.is_empty(), "the client's doors open for the crew")
	assert_false(e.reinforcements, "nobody calls the site's response in: the waves are it")
	assert_eq(int(o.end), 2 + 6 - 1, "security 2: six rounds from the first wave (HOUSE-RULE)")
	assert_eq(o.waves, [2, 4, 6])
	_hud_ok(e, "defend")
	assert_true(e.obj.hud_text().begins_with("HOLD THE "), e.obj.hud_text())
	assert_true(e.obj.hud_text().contains("TAKE COVER"), "a round to set up first")
	assert_true(e.units.filter(func(u): return int(u.team) == Encounter.CREW).all(func(u): return zone.has(u.pos)), "the crew starts in the room")
	_marks_ok(e, "defend")
	assert_eq(e.obj.marks(true).size(), 1)
	assert_true(String(e.obj.marks(true)[0].label).begins_with("★ HOLD · "))
	assert_eq((e.obj.zones()[0].cells as Array).size(), zone.size(), "the view tints the room")
	assert_eq(e.obj.crew_goal(e.cur), zone, "auto-play heads in")


func test_defend_waves_escalate_and_the_hold_wins() -> void:
	var e := _job("defend")
	var o := e.objective
	_to_round(e, 2)
	var first := e.opfor().size()
	assert_true(first >= 2, "the first wave (%d)" % first)
	assert_eq(e.alarm, 2, "loud from the first wave")
	assert_true(e.opfor().all(func(u): return u.alerted and e.init.order().has(u.c)), "in the fight at once")
	var after_1 := e.units.filter(func(u): return bool(e.sides[int(u.team)].opfor)).size()
	_to_round(e, 4)
	var second := e.units.filter(func(u): return bool(e.sides[int(u.team)].opfor)).size() - after_1
	assert_true(second > first, "the second wave is bigger (%d after %d)" % [second, first])
	assert_true(e.obj.hud_text().contains("MORE ROUND"), e.obj.hud_text())
	for u in e.opfor():   # they don't get in
		u.c.dead = true
	_to_round(e, int(o.end) + 1)
	assert_eq(e.state, "won", "the room held through the last round")


func test_defend_is_lost_when_they_hold_the_room_or_wreck_the_asset() -> void:
	var e := _job("defend")
	var o := e.objective
	_to_round(e, 2)
	var a: Dictionary = e.opfor()[0]
	a.pos = (o.zone as Array)[0]
	for u in e.units:
		if int(u.team) == Encounter.CREW and (o.zone as Array).has(u.pos):
			u.pos = e.extract_cells.keys()[0]
	assert_true(e.obj.theirs(), "an attacker in the room, nobody of ours")
	assert_true(e.obj.hud_text().contains("THEY'RE IN THE"), e.obj.hud_text())
	assert_eq(String(e.obj.marks(true)[0].tone), "red")
	_to_round(e, 3)
	assert_eq(e.state, "playing", "one round theirs: still in it")
	_to_round(e, 4)
	assert_eq(e.state, "lost", "two round ends theirs: lost")
	var e2 := _job("defend")
	e2.los.cover_hp[e2.objective.cell] = 0
	e2._check_end()
	assert_eq(e2.state, "lost", "the asset wrecked")
	var e3 := _job("defend")
	_to_round(e3, 2)
	var a3: Dictionary = e3.opfor()[0]
	a3.pos = (e3.objective.zone as Array)[0]
	e3.units[0].pos = (e3.objective.zone as Array)[1]   # one of ours in there: contested, not theirs
	assert_false(e3.obj.theirs())


func test_defend_attackers_press_in_and_shoot_the_asset() -> void:
	var e := _job("defend")
	var o := e.objective
	_to_round(e, 2)
	var a: Dictionary = {}
	for u in e.opfor():
		if int(u.id) % int(e.obj.cfg.wreck_every) == 0:
			a = u
	assert_false(a.is_empty(), "a wrecker in the wave")
	if a.is_empty():
		return
	var zone: Array = o.zone
	var outside := Vector3i(-1, -1, -1)
	var f: Dictionary = e.nav.distance_field(zone, {}, 4000)
	for v in f:
		if int(f[v]) == 6 and v.z == zone[0].z:
			outside = v
			break
	assert_true(e.obj.ai_pull(a, zone[0]) > e.obj.ai_pull(a, outside), "the room pulls harder than the hall outside")
	assert_eq(e.obj.ai_pull(e.units[0], zone[0]), 0.0, "the crew isn't pulled")
	var spot := Vector3i(-1, -1, -1)   # a square with a clear line to the asset: the wrecker shoots it
	for v in zone:
		if e.los.trace(v, o.cell).clear and Los.distance_m(v, o.cell) > 2.0 and not e.occupied().has(v):
			spot = v
			break
	assert_true(spot.x >= 0, "a square with a line to the asset")
	a.pos = spot
	e.cur = a
	e.turn = TurnState.begin(e.dice, a.c)
	var w: Weapon = a.c.weapons[0]
	w.ammo = w.mag()
	w.jammed = false
	assert_true(e.obj.ai_act(a), "it spends its attack on the asset")
	assert_true(e.obj.asset_hp() < 50, "and the asset takes it (%d)" % e.obj.asset_hp())


func test_defend_turrets_stand_with_the_crew() -> void:
	var m := SceneGen.generate(11, "lone_building", {"security": 2, "site": "corp_office"})
	m.devices.append({"id": m.devices.size(), "type": "turret", "pos": Vector2i(m.entrances[0].pos), "floor": m.street})
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), "defend")
	var t: Array = e.units.filter(func(u): return u.has("turret"))
	assert_eq(t.size(), 1)
	if t.is_empty():
		return
	assert_true(e.allied(int(t[0].team), Encounter.CREW), "the site's turrets are the client's: the crew's")


func test_defend_rows_are_enabled() -> void:
	_rows_ok("defend", ["cover_exit", "defend_location", "emergency", "secure_route"])


func test_defend_offers_save_and_load() -> void:
	_offer_saves("defense", "defend")
