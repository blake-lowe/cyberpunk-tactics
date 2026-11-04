extends TestCase
## Campaign saves upgrade across format versions (SaveMigrations).


## A save as the v1 build wrote it: no factions anywhere.
func _v1_save() -> Dictionary:
	var c := Campaign.new_game(9)
	var d := c.to_dict()
	d["version"] = 1
	d.erase("faction_rep")
	for g in d.board:
		g.erase("faction")
	for cd in d.crew:
		cd.erase("faction")
	return JSON.parse_string(JSON.stringify(d))   # as it comes off disk


func test_a_v1_save_loads_into_the_current_format() -> void:
	var d := _v1_save()
	var c := Campaign.from_dict(d)
	assert_true(c != null, "loads")
	assert_eq(c.faction_rep, {}, "no standing with anyone yet")
	assert_true(c.board.all(func(g): return String(g.get("faction", "")) == World.DEFAULT_OPFOR), "old gigs were against private security")
	assert_true(c.crew.all(func(m): return m.faction == "crew"))
	assert_eq(int(c.to_dict().version), SaveMigrations.CURRENT, "and saves back as the current version")


func test_migration_steps_run_in_order_and_are_idempotent_on_current_saves() -> void:
	var d := Campaign.new_game(4).to_dict()
	var before := JSON.stringify(d)
	var after := SaveMigrations.migrate(d)
	assert_eq(JSON.stringify(after), before, "a current save passes through untouched")


func test_a_save_from_a_newer_build_is_refused() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = SaveMigrations.CURRENT + 1
	assert_true(Campaign.from_dict(d) == null, "refused rather than half-read")


func test_faction_standing_round_trips() -> void:
	var c := Campaign.new_game(6)
	c.faction_rep["militech"] = -2
	var d := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(int(d.faction_rep.militech), -2)


func test_a_won_job_costs_standing_with_its_target() -> void:
	var c := Campaign.new_game(6)
	c.active_gig = c.board[0]
	var fid := String(c.active_gig.faction)
	var m := SceneGen.generate(int(c.active_gig.seed), "street_block", {"security": 1})
	var crew: Array[Combatant] = c.alive_crew()
	var e := Encounter.setup(m, c.dice, crew, Campaign.objective_for(c.active_gig), [], {"faction": fid})
	e.state = "won"
	var r := c.resolve(e)
	assert_eq(int(c.faction_rep.get(fid, 0)), -1, "%s remembers" % fid)
	assert_eq(r.get("standing", {}), {fid: -1}, "and the report says so")


func test_v3_carried_frags_move_into_storage_and_slot_2_keeps_only_utilities() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 3
	d["stash"] = {"drugs/synthcoke": 1}
	d.crew[0]["kit"] = ["", "drugs/synthcoke"]   # v3 allowed a consumable in slot 2
	d.crew[0]["grenades"] = 2
	d.crew[1]["kit"] = ["", ""]
	d.crew[1]["grenades"] = 1
	var c := Campaign.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(int(c.stash["ammo/frag_grenade"]), 3, "three carried frags, now in storage")
	assert_eq(c.crew[0].kit[0], "drugs/synthcoke", "the slot-2 drug moves to slot 1")
	assert_eq(c.crew[0].kit[1], "")
	assert_eq(c.crew[1].kit[0], "ammo/frag_grenade", "an empty slot 1 gets a frag")
