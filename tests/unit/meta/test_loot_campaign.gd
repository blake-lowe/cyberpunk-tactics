extends TestCase
## Corpse loot and morale in the campaign: finds go home (storage, eb, leads), leads save and load.


func _finish(c: Campaign, state: String) -> Encounter:
	var gig: Dictionary = c.accept(0)
	var m := SceneGen.generate(int(gig.seed), String(gig.scene), Campaign.scene_opts(gig))
	var e := Encounter.setup(m, c.dice, c.alive_crew())
	e.state = state
	return e


func _crew_unit(e: Encounter, i := 0) -> Dictionary:
	return e.units.filter(func(u): return int(u.team) == Encounter.CREW)[i]


func test_finds_go_into_storage_the_wallet_and_the_lead_list() -> void:
	var c := Campaign.new_game(6)
	var pay := int(c.board[0].pay)
	var e := _finish(c, "won")
	var by: int = _crew_unit(e).id
	e.loot.append({"by": by, "by_name": "Vex", "from": "Guard 1", "kind": "eb", "eb": 250, "label": "gemstone pouch", "fence": true})
	e.loot.append({"by": by, "by_name": "Vex", "from": "Guard 2", "kind": "item", "items": {"drugs/synthcoke": 3}, "label": "bottle of Synthcoke"})
	e.loot.append({"by": by, "by_name": "Vex", "from": "Guard 3", "kind": "lead", "hook": "heist", "label": "heist plans chip"})
	e.loot.append({"by": by, "by_name": "Vex", "from": "Guard 4", "kind": "nothing", "label": "nothing worth taking"})
	e.hid = 2
	e.fled = 1
	var before := c.stored("drugs/synthcoke")
	var r := c.resolve(e)
	assert_eq(c.eb, 1000 + pay + 250, "the gig's pay and what was found")
	assert_eq(int(r.loot_eb), 250)
	assert_eq(c.stored("drugs/synthcoke"), before + 3, "into safehouse storage")
	assert_eq(c.leads.size(), 1)
	assert_eq(String(c.leads[0].label), "heist plans chip")
	assert_eq(String(c.leads[0].hook), "heist")
	assert_eq(int(c.leads[0].day), 1, "the day it was found")
	assert_eq((r.loot as Array).size(), 3, "the debrief lists the finds (empty pockets aren't news)")
	assert_eq((r.leads as Array).size(), 1)
	assert_eq(int(r.hid), 2, "the debrief counts who hid")
	assert_eq(int(r.fled), 1, "and who ran")


func test_a_finder_left_behind_takes_the_find_with_them() -> void:
	var c := Campaign.new_game(7)
	var e := _finish(c, "fled")
	var u := _crew_unit(e)
	u.c.dead = true   # left behind (Encounter.withdraw)
	e.loot.append({"by": int(u.id), "kind": "eb", "eb": 500, "label": "loaded credstick"})
	var r := c.resolve(e)
	assert_eq(c.eb, 1000, "a withdrawal pays nothing, and the credstick stayed with the body")
	assert_eq(int(r.loot_lost), 1, "the debrief says one was left behind")


func test_leads_are_saved_and_loaded() -> void:
	var c := Campaign.new_game(8)
	c.leads.append({"label": "Night Market invite", "hook": "night_market", "day": 3, "gig": "A job", "faction": "maelstrom",
		"district": "watson", "location": "", "from": "Ganger 2"})
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back := Campaign.from_dict(d)
	assert_eq(back.leads.size(), 1)
	assert_eq(String(back.leads[0].label), "Night Market invite")
	assert_true(back.leads[0].day is int, "the day is an int again")
	assert_eq(JSON.stringify(back.to_dict()), JSON.stringify(c.to_dict()), "a round trip to the digit")


func test_an_older_save_without_leads_loads_with_none() -> void:
	var c := Campaign.new_game(9)
	var d := c.to_dict()
	d["version"] = 15
	d.erase("leads")
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_true(back != null)
	assert_true(back.leads.is_empty())
	assert_eq(int(back.to_dict().version), SaveMigrations.CURRENT)
