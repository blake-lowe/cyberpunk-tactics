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
	assert_eq(c.eb, eb0 + 3 * 50 + 1000 + 1500, "frags and the Armory level refunded (v5), then the Med Bay level (v6)")
	var out := c.to_dict()
	for k in ["rep", "heat", "fixer_rep", "faction_rep", "facilities"]:
		assert_false(out.has(k), "%s is gone" % k)
	assert_false((out.board[0] as Dictionary).has("rep"))


## A save as the v5 build wrote it: built rooms with levels, kit-only storage, no Night Market.
func test_v5_refunds_room_levels_and_gets_a_market() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 5
	d.erase("market")
	d["facilities"] = {"med_bay": 2, "intel": 1, "training": 2, "armory": 0}
	d["stash"] = {"ammo/flashbang_ammo": 2}
	var raw: Dictionary = JSON.parse_string(JSON.stringify(d))
	var eb0 := int(raw.eb)
	var weapons0: Array = raw.crew[0].weapons.map(func(w): return w.id)
	var c := Campaign.from_dict(raw)
	assert_eq(c.eb, eb0 + (1500 + 4000) + 1500 + (1000 + 3000), "every level refunded at what it cost to build")
	assert_false(c.to_dict().has("facilities"))
	assert_eq(c.stash, {"ammo/flashbang_ammo": 2}, "storage carries over")
	assert_eq(c.crew[0].weapons.map(func(w): return w.id()), weapons0, "the crew keep what they carry")
	assert_eq((c.market.categories as Array).size(), 2, "a Night Market is up")
	assert_eq(int(c.to_dict().version), SaveMigrations.CURRENT)


func test_storage_keys_for_weapons_and_armor_survive_a_save() -> void:
	var c := Campaign.new_game(4)
	c.stash = {"weapon/assault_rifle@poor": 1, "armor/kevlar@upgraded@sp3": 2, "drugs/synthcoke": 1, "weapon/nonsense": 1}
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.stash, {"weapon/assault_rifle@poor": 1, "armor/kevlar@upgraded@sp3": 2, "drugs/synthcoke": 1}, "unknown keys are dropped")
	assert_eq(NightMarket.keys_of(back.market), NightMarket.keys_of(c.market), "the same market is up")
	assert_eq(back.market.closes, c.market.closes)


## A save as the v6 build wrote it: chrome was installed as it was bought, so storage never held
## any; a stray "cyberware/" key there was ignored on load.
func test_v6_drops_stray_cyberware_from_storage_and_keeps_installed_chrome() -> void:
	var c0 := Campaign.new_game(4)
	c0.crew[0].install_cyberware("neural_link")
	var d := c0.to_dict()
	d["version"] = 6
	d["stash"] = {"ammo/flashbang_ammo": 2, "cyberware/neural_link": 1}
	d["debrief"] = [{"name": "Wraith", "dead": true, "kit": ["Smoke Grenade"]}, {"name": "Nix", "dead": false, "kit": ["Flashbang"]}]
	var c := Campaign.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(c.stash, {"ammo/flashbang_ammo": 2}, "no free chrome out of an old save")
	assert_true(c.crew[0].has_cyberware("neural_link"), "installed chrome stays installed")
	assert_eq(c.debrief[0].lost, ["Smoke Grenade"], "a fallen member's lost kit is their lost gear")
	assert_eq(c.debrief[1].lost, [], "the living lost nothing")
	assert_eq(int(c.to_dict().version), SaveMigrations.CURRENT)


func test_stored_cyberware_survives_a_save() -> void:
	var c := Campaign.new_game(4)
	c.stash = {"cyberware/wolvers": 2, "cyberware/nonsense": 1, "cyberware/wolvers@x": 1}
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.stash, {"cyberware/wolvers": 2}, "a stored piece keeps; unknown ones are dropped")
	assert_eq(back.cyberware_options(), ["cyberware/wolvers"])


func test_v8_board_twists_and_setups_are_dropped() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 8
	d.board[0]["twist"] = "heavy"
	d.board[0]["setup"] = true
	var c := Campaign.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_true(c != null)
	assert_false(c.board[0].get("twist") != null or c.board[0].has("setup"), "the book's complications replaced them (v9); v16's twist hook is null")
	assert_eq(int(c.to_dict().version), SaveMigrations.CURRENT)


func test_v9_save_gets_a_safehouse_district_and_a_clock() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 9
	d.erase("safehouse_district")
	d.erase("minutes")
	var c := Campaign.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_true(c != null)
	assert_eq(c.safehouse_district, Campaign.DEFAULT_SAFEHOUSE, "an old crew lives in the default district (v10)")
	assert_eq(c.minutes, 0)
	assert_eq(int(c.to_dict().version), SaveMigrations.CURRENT)


func test_safehouse_district_and_clock_survive_a_save() -> void:
	var c := Campaign.new_game(4)
	c.safehouse_district = "kabuki"
	c.minutes = 95
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.safehouse_district, "kabuki")
	assert_eq(back.minutes, 95)
	assert_eq(back.time_label(), "01:35")
	var d := c.to_dict()
	d["safehouse_district"] = "atlantis"
	assert_eq(Campaign.from_dict(JSON.parse_string(JSON.stringify(d))).safehouse_district, Campaign.DEFAULT_SAFEHOUSE,
		"a district the city doesn't have falls back to the default")


# --- v13: multi-map operations descoped ---------------------------------------------------

const GRENADE := "ammo/flashbang_ammo"
var _gun := ""   ## the van's weapon in _operation_save (its storage key)


## A save from the operations builds (v11/v12) with an operation under way between legs: an
## operation offer on the board, the active operation with a weapon and a kit grenade left in the
## van at the park's gate, what the crew carried between legs and who went. v11 keyed the van,
## carry-over and presence by handle; v12 by place in the crew.
func _operation_save(version: int) -> Dictionary:
	var c := Campaign.new_game(4)
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var names: Array = d.crew.map(func(m): return String(m.name))
	var gun := Items.key_of_weapon(c.crew[0].weapons[0])
	_gun = gun
	d.crew[1].kit[0] = ""   # the gate took the grenade out of this slot
	d.stash[GRENADE] = 1   # it never left storage
	var legs := [{"leg_title": "Thrill Hill · Eco-Coaster", "kind": "data_theft", "security": 1, "pay": 1000},
		{"leg_title": "Grand Junction · Trolley Yard", "kind": "rescue", "security": 2, "pay": 2000}]
	var offer: Dictionary = (d.board[0] as Dictionary).duplicate(true)
	offer["id"] = "1-playland"
	offer["op"] = "playland"
	offer["legs"] = legs
	d.board.append(offer)
	var op: Dictionary = offer.duplicate(true)
	op["leg"] = 1
	op["done"] = [{"title": "Thrill Hill · Eco-Coaster", "line": "", "pay": 1000}]
	if version == 11:
		op["van"] = {names[0]: [{"key": gun, "ammo": 3, "at": 0}], names[1]: [{"key": GRENADE, "slot": 0}]}
		op["carry"] = {names[0]: {"kit_spent": [true, false]}}
		op["present"] = {names[0]: true, names[1]: true}
	else:
		op["van"] = [{"crew": 0, "key": gun, "ammo": 3, "at": 0}, {"crew": 1, "key": GRENADE, "slot": 0}]
		op["carry"] = [{"name": names[0], "kit_spent": [true, false]}, {"name": names[1]}]
		op["present"] = [0, 1]
	d["operation"] = op
	d["version"] = version
	return JSON.parse_string(JSON.stringify(d))   # as it comes off disk


func test_v11_and_v12_saves_with_an_operation_load_without_it() -> void:
	assert_eq(Items.use(GRENADE), "grenade", "the test's kit grenade is one")
	for v in [11, 12]:
		var d := _operation_save(v)
		var gun := _gun
		var stored := int(d.get("stash", {}).get(gun, 0))
		var board_n := (d.board as Array).size()
		var c := Campaign.from_dict(d)
		assert_true(c != null, "v%d loads" % v)
		assert_true(c.active_gig.is_empty(), "v%d: the operation in progress is dropped" % v)
		assert_eq(c.board.size(), board_n - 1, "v%d: the operation offer leaves the board" % v)
		assert_false(c.board.any(func(g): return g.has("legs")), "v%d: no gig with legs" % v)
		assert_eq(c.stored(gun), stored + 1, "v%d: the van's weapon is back in storage" % v)
		assert_eq(c.crew[1].kit[0], GRENADE, "v%d: the van's grenade is back in its slot" % v)
		var out := c.to_dict()
		assert_eq(int(out.version), SaveMigrations.CURRENT, "v%d saves back as the current version" % v)
		assert_false(out.has("operation"), "v%d: no between-legs state is saved" % v)


func test_v12_migration_leaves_a_save_without_an_operation_alone() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 12
	d["operation"] = {}
	var c := Campaign.from_dict(JSON.parse_string(JSON.stringify(d)))
	for k in d.stash:
		assert_eq(c.stored(String(k)), int(d.stash[k]), "storage unchanged: " + String(k))
	assert_eq(c.board.size(), (d.board as Array).size(), "the board unchanged")
	assert_false(c.to_dict().has("operation"))


# --- v14: every offer at a canon place --------------------------------------------------------

## A v13 save whose board has old generic offers (a scene picked by tags, no location): they leave the
## board and canon offers take their places on load; the canon offer it had stays as it was.
func test_v13_generic_offers_are_dropped_and_the_board_refilled() -> void:
	var c0 := Campaign.new_game(31)
	var d: Dictionary = JSON.parse_string(JSON.stringify(c0.to_dict()))
	var kept: Dictionary = (d.board[0] as Dictionary).duplicate(true)
	for i in range(1, (d.board as Array).size()):
		var g: Dictionary = d.board[i]
		for k in ["location", "district", "hook", "setpiece"]:
			g.erase(k)
		g["scene"] = "shipyard"
		g["site"] = ""
		g["title"] = "Clear the Maelstrom out of the docks"
	d["version"] = 13
	var raw: Dictionary = JSON.parse_string(JSON.stringify(d))
	var mig := SaveMigrations.migrate(raw.duplicate(true))
	assert_eq((mig.board as Array).size(), 1, "the generic offers leave the board")
	assert_true(bool(mig.get("refill_board", false)), "and the save asks for a refill")
	var c := Campaign.from_dict(raw)
	assert_true(c != null, "loads")
	assert_eq(c.board.size(), c.board_size(), "the board is full again")
	assert_true(c.board.all(func(g): return String(g.get("location", "")) != "" and World.locations().has(String(g.location))), "every offer at a canon place")
	assert_eq(String(c.board[0].id), String(kept.id), "the canon offer stays")
	assert_eq(String(c.board[0].location), String(kept.location))
	var ids := {}
	var places := {}
	for g in c.board:
		ids[String(g.id)] = true
		places[String(g.location)] = true
	assert_eq(ids.size(), c.board.size(), "offer ids stay unique")
	assert_eq(places.size(), c.board.size(), "no place has two offers")
	var out := c.to_dict()
	assert_eq(int(out.version), SaveMigrations.CURRENT)
	assert_false(out.has("refill_board"), "the flag isn't saved")
	var d2 := Campaign.new_game(31).to_dict()
	d2["version"] = 13
	var c2 := Campaign.from_dict(JSON.parse_string(JSON.stringify(d2)))
	assert_eq(c2.board.map(func(g): return [String(g.id), String(g.location)]), Campaign.new_game(31).board.map(func(g): return [String(g.id), String(g.location)]), "a v13 board of canon offers loads as it was")
