extends TestCase
## Campaign saves upgrade across format versions (SaveMigrations).


## A save as the v1 build wrote it: no factions anywhere.
func _v1_save() -> Dictionary:
	var c := Campaign.new_game(9)
	var d := c.to_dict()
	d["version"] = 1
	for g in d.board:
		g.erase("faction")
	for cd in d.crew:
		cd.erase("faction")
	return JSON.parse_string(JSON.stringify(d))   # as it comes off disk


func test_a_v1_save_loads_into_the_current_format() -> void:
	var d := _v1_save()
	var c := Campaign.from_dict(d)
	assert_true(c != null, "loads")
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


func test_v3_carried_frags_move_into_storage_and_slot_2_keeps_only_utilities() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 3
	d["stash"] = {"drugs/synthcoke": 1}
	d.crew[0]["kit"] = ["", "drugs/synthcoke"]   # v3 allowed a consumable in slot 2
	d.crew[0]["grenades"] = 2
	d.crew[1]["kit"] = ["", ""]
	d.crew[1]["grenades"] = 1
	var raw: Dictionary = JSON.parse_string(JSON.stringify(d))
	var eb0 := int(raw.eb)
	var c := Campaign.from_dict(raw)
	assert_eq(c.crew[0].kit[0], "drugs/synthcoke", "the slot-2 drug moves to slot 1")
	assert_eq(c.crew[0].kit[1], "")
	assert_false(c.stash.has("ammo/frag_grenade"), "v5: the frags v4 put in storage are gone")
	assert_eq(c.crew[1].kit[0], "", "and unpacked")
	assert_eq(c.eb, eb0 + 3 * 50, "refunded at 50eb each")


## A save as the v4 build wrote it: campaign heat, crew-wide rep, fixer and faction standing,
## Train/Hustle downtime, frags in storage and kits, an Armory level.
func test_v4_drops_the_invented_systems() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 4
	d["rep"] = 4
	d["heat"] = 6
	d["fixer_rep"] = {"Padre": 2}
	d["faction_rep"] = {"militech": -1}
	d["stash"] = {"ammo/frag_grenade": 3, "ammo/flashbang_ammo": 1}
	d["facilities"] = {"armory": 1, "med_bay": 1}
	d.crew[0]["kit"] = ["ammo/frag_grenade", ""]
	d.crew[0]["downtime"] = "hustle"
	d.crew[1]["downtime"] = "train"
	d.board[0]["rep"] = 2
	var raw: Dictionary = JSON.parse_string(JSON.stringify(d))
	var eb0 := int(raw.eb)
	var c := Campaign.from_dict(raw)
	assert_true(c.crew.all(func(m): return m.reputation == 4), "the crew's rep becomes each member's Reputation")
	assert_true(c.crew.all(func(m): return m.downtime == "recover"))
	assert_eq(c.crew[0].kit[0], "")
	assert_eq(c.stash, {"ammo/flashbang_ammo": 1})
	assert_eq(c.level("armory"), 0)
	assert_eq(c.level("med_bay"), 1)
	assert_eq(c.eb, eb0 + 3 * 50 + 1000, "frags and the Armory level refunded")
	var out := c.to_dict()
	for k in ["rep", "heat", "fixer_rep", "faction_rep"]:
		assert_false(out.has(k), "%s is gone" % k)
	assert_false((out.board[0] as Dictionary).has("rep"))
