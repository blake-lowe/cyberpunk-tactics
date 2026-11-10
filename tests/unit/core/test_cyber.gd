extends TestCase
## The cyberware slot model (Cyber; CPR core p.111-116, entries p.358-367): where pieces go, how
## many Option Slots they take, pairs, meat limbs, one-per-character pieces, the reasons an install
## is blocked, Skin Weave mending and what players are shown.


func _with(ids: Array) -> Array[Dictionary]:
	return Cyber.place_ids(ids)


func _fill(implants: Array, id: String, loc: String, n: int) -> void:
	for i in n:
		implants.append({"id": id, "loc": loc})


func test_foundations_hold_their_book_slot_counts() -> void:
	var im := _with(["neural_link", "cybereye", "cybereye", "cyberaudio_suite", "cyberarm", "cyberleg"])
	assert_eq(Cyber.capacity(im, "neural_link"), 5, "Neural Link: 5 (p.359)")
	assert_eq(Cyber.capacity(im, "right_eye"), 3, "Cybereye: 3 per eye (p.361)")
	assert_eq(Cyber.capacity(im, "left_eye"), 3)
	assert_eq(Cyber.capacity(im, "cyberaudio"), 3, "Cyberaudio Suite: 3 (p.362)")
	assert_eq(Cyber.capacity(im, "right_arm"), 4, "Cyberarm: 4 (p.364)")
	assert_eq(Cyber.capacity(im, "right_leg"), 3, "Cyberleg: 3 (p.366)")
	assert_eq(Cyber.capacity(im, "left_arm"), 0, "the other arm is meat")
	for loc in ["fashion", "internal", "external"]:
		assert_eq(Cyber.capacity([], loc), 7, "%s: 7 slots, no foundation (p.111)" % loc)
	assert_eq(Cyber.capacity([], "neural_link"), 0, "no Neural Link, no neuralware")


func test_options_fill_slots_and_then_are_blocked() -> void:
	var im := _with(["cybereye"])
	assert_eq(Cyber.block(im, "targeting_scope", "right_eye"), "")
	im.append({"id": "microvideo", "loc": "right_eye"})   # 2 slots (p.361)
	assert_eq(Cyber.used(im, "right_eye"), 2)
	assert_eq(Cyber.block(im, "dartgun", "right_eye"), "Needs 3 free slots in the right eye", "Dartgun takes 3 (p.360)")
	im.append({"id": "targeting_scope", "loc": "right_eye"})
	assert_eq(Cyber.block(im, "teleoptics", "right_eye"), "No free slot in the right eye")
	assert_eq(Cyber.block(im, "teleoptics", "left_eye"), "Needs a cybereye in the left eye")
	assert_eq(Cyber.block_any(im, "teleoptics"), "No free slot in the right eye", "the reason for the first place it could go")
	var arm := _with(["cyberarm"])
	_fill(arm, "popup_shield", "right_arm", 1)   # 3 slots
	assert_eq(Cyber.block(arm, "popup_melee_weapon", "right_arm"), "Needs 2 free slots in the right arm")
	assert_eq(Cyber.block(arm, "plastic_covering", "right_arm"), "", "a covering takes no slot (p.367)")
	var body: Array[Dictionary] = []
	_fill(body, "toxin_binders", "internal", 1)
	_fill(body, "nasal_filters", "internal", 1)
	_fill(body, "gills", "internal", 5)
	assert_eq(Cyber.block(body, "cybersnake", "internal"), "No free slot in the body", "7 Internal slots (p.111)")


func test_chipware_takes_no_neural_slot_but_a_socket_each() -> void:
	var im := _with(["neural_link", "chipware_socket"])
	assert_eq(Cyber.used(im, "neural_link"), 1, "the socket takes a Neural Link slot")
	assert_eq(Cyber.block(im, "pain_editor", "chipware"), "")
	im.append({"id": "pain_editor", "loc": "chipware"})
	assert_eq(Cyber.used(im, "neural_link"), 1, "the chip doesn't (p.359)")
	assert_eq(Cyber.block(im, "tactile_boost", "chipware"), "Every chipware socket is full", "one chip per socket (p.359)")
	assert_eq(Cyber.block(im, "chipware_socket", "neural_link"), "", "several sockets may be installed (p.359)")
	assert_eq(Cyber.block([], "pain_editor", "chipware"), "Needs a Chipware Socket")
	assert_eq(Cyber.block([], "kerenzikov", "neural_link"), "Needs a Neural Link")


func test_two_eyes_two_arms_two_legs_left_and_right() -> void:
	var im: Array[Dictionary] = []
	for id in ["cybereye", "cybereye", "cyberarm", "cyberarm", "cyberleg", "cyberleg"]:
		var loc := Cyber.auto_loc(im, id)
		assert_true(loc != "", "%s fits" % id)
		im.append({"id": id, "loc": loc})
	assert_eq(im.map(func(p): return String(p.loc)), ["right_eye", "left_eye", "right_arm", "left_arm", "right_leg", "left_leg"])
	assert_eq(Cyber.block_any(im, "cybereye"), "The right eye is already a cybereye", "no third eye without Borgware")
	assert_eq(Cyber.block(im, "cyberarm", "left_arm"), "The left arm is already a cyberarm")


func test_paired_options_need_both_and_work_only_with_both() -> void:
	var one := _with(["cybereye"])
	assert_eq(Cyber.block(one, "anti_dazzle", "right_eye"), "Needs two cybereyes", "Requires two Cybereyes (p.360)")
	var im := _with(["cybereye", "cybereye"])
	assert_eq(Cyber.free_locs(im, "anti_dazzle"), ["right_eye", "left_eye"] as Array[String])
	im.append({"id": "anti_dazzle", "loc": "right_eye"})
	assert_false("anti_dazzle" in Cyber.active_ids(im), "one half does nothing: must be paired to work (p.361)")
	assert_eq(Cyber.auto_loc(im, "anti_dazzle"), "left_eye", "the second half goes to the other eye")
	assert_eq(Cyber.block(im, "anti_dazzle", "right_eye"), "Already in the right eye")
	im.append({"id": "anti_dazzle", "loc": "left_eye"})
	assert_true("anti_dazzle" in Cyber.active_ids(im))
	assert_false("anti_dazzle" in Cyber.active_ids(im, {"anti_dazzle@left_eye": 3}), "a knocked-out half breaks the pair")
	im.append({"id": "targeting_scope", "loc": "right_eye"})
	assert_eq(Cyber.block(im, "low_light_infrared_uv", "right_eye"), "Needs 2 free slots in the right eye", "2 slots per eye (p.360)")
	var legs := _with(["cyberleg"])
	assert_eq(Cyber.block(legs, "jump_booster", "right_leg"), "Needs two cyberlegs", "p.367")
	for id in ["grip_foot", "jump_booster", "skate_foot", "web_foot", "image_enhance", "virtuality", "low_light_infrared_uv", "anti_dazzle"]:
		assert_true(Cyber.def(id).get("paired", false), "%s is paired" % id)


func test_each_half_of_a_pair_costs_humanity() -> void:
	var c := Fixtures.unarmored("A", {"EMP": 8})
	c.init_humanity()
	c.install_cyberware("cybereye", null, true)
	c.install_cyberware("cybereye", null, true)
	var h := c.humanity
	c.install_cyberware("anti_dazzle", null, true)
	c.install_cyberware("anti_dazzle", null, true)
	assert_eq(h - c.humanity, 4, "HL paid for each purchase (p.361): 2 + 2")
	assert_eq(c.implants.filter(func(p): return p.id == "anti_dazzle").map(func(p): return p.loc), ["right_eye", "left_eye"])


func test_only_one_speedware_and_one_cyberaudio_suite() -> void:
	var im := _with(["neural_link", "kerenzikov"])
	assert_eq(Cyber.block(im, "sandevistan", "neural_link"), "Only one speedware", "p.359-360")
	assert_eq(Cyber.block(im, "kerenzikov", "neural_link"), "Only one speedware")
	var au := _with(["cyberaudio_suite"])
	assert_eq(Cyber.block(au, "cyberaudio_suite", "cyberaudio"), "Only one Cyberaudio Suite", "p.362")


func test_meat_arm_and_leg_pieces() -> void:
	for id in ["big_knucks", "rippers", "scratchers", "wolvers", "slice_n_dice", "tool_hand", "standard_hand"]:
		assert_eq(Cyber.block([], id, "right_arm"), "", "%s fits a meat arm (p.364-366)" % id)
	assert_eq(Cyber.block([], "talon_foot", "left_leg"), "", "Talon Foot fits a meat leg (p.367)")
	assert_eq(Cyber.block([], "standard_foot", "left_leg"), "")
	assert_eq(Cyber.block([], "popup_melee_weapon", "right_arm"), "Needs a cyberarm in the right arm")
	assert_eq(Cyber.block([], "grip_foot", "left_leg"), "Needs two cyberlegs")
	var im: Array[Dictionary] = [{"id": "wolvers", "loc": "right_arm"}]
	assert_eq(Cyber.block(im, "big_knucks", "right_arm"), "The meat arm already holds Wolvers", "the only piece in a meat arm")
	assert_eq(Cyber.block(im, "standard_hand", "right_arm"), "", "a Standard Hand doesn't count there (p.364)")
	assert_eq(Cyber.block(im, "big_knucks", "left_arm"), "", "the other arm is free")
	assert_eq(Cyber.block(im, "cyberarm", "right_arm"), "Take the Wolvers out of the right arm first")
	assert_eq(Cyber.block([], "subdermal_grip", "right_arm"), "Needs a Neural Link", "Subdermal Grip: Neural Link slot (p.366)")
	var nl := _with(["neural_link", "cyberarm"])
	assert_eq(Cyber.block(nl, "subdermal_grip", "left_arm"), "", "in a meat arm")
	nl.append({"id": "subdermal_grip", "loc": "left_arm"})
	assert_eq(Cyber.used(nl, "neural_link"), 1, "it takes a Neural Link slot")
	assert_eq(Cyber.remove_block(nl, nl[0]), "Subdermal Grip needs it", "the Neural Link can't come out under it")
	assert_eq(Cyber.block(_with(["cyberarm"]), "standard_hand", "right_arm"), "The cyberarm comes with one")


func test_wolvers_and_big_knucks_install_in_a_meat_arm_from_the_med_bay() -> void:
	var c := Campaign.new_game(5)
	var solo: Combatant = c.crew[0]
	solo.implants.clear()
	solo.weapons = solo.weapons.filter(func(w): return not w.is_melee())
	c.stash["cyberware/wolvers"] = 1
	c.stash["cyberware/big_knucks"] = 1
	assert_eq(c.install_block(solo, "wolvers"), "", "no Cyberarm needed (p.366)")
	assert_true(c.install(solo, "wolvers") >= 0)
	assert_eq(solo.implant("wolvers").loc, "right_arm")
	assert_eq(c.install_block(solo, "big_knucks", "right_arm"), "The meat arm already holds Wolvers")
	assert_true(c.install(solo, "big_knucks") >= 0, "the other arm takes it")
	assert_eq(solo.implant("big_knucks").loc, "left_arm")
	assert_eq(c.install_block(solo, "big_knucks"), "Not in storage")


func test_options_come_out_before_their_host() -> void:
	var im := _with(["cybereye", "cybereye", "targeting_scope"])
	assert_eq(Cyber.remove_block(im, im[0]), "Targeting Scope needs it", "the scope sits in the right eye")
	assert_eq(Cyber.remove_block(im, im[1]), "", "the left eye holds nothing")
	var ch := _with(["neural_link", "chipware_socket", "chipware_socket", "pain_editor"])
	assert_eq(Cyber.remove_block(ch, ch[1]), "", "the other socket still holds the chip")


func test_effects_count_once_per_piece() -> void:
	var c := Fixtures.unarmored()
	c.install_cyberware("cybereye")
	c.install_cyberware("cybereye")
	c.install_cyberware("targeting_scope", null, false, "right_eye")
	c.install_cyberware("targeting_scope", null, false, "left_eye")
	assert_eq(c.cyber_fx_sum("aimed_bonus"), 1, "a second Targeting Scope adds nothing (p.360)")


func test_every_role_and_npc_block_fits_the_slot_rules() -> void:
	var lists: Dictionary = {}
	var blocks: Dictionary = RulesDB.load_json("npcs.json")["blocks"]
	for id in blocks:
		lists["block " + id] = blocks[id].get("cyberware", [])
	var roles: Dictionary = RulesDB.load_json("roles.json")["roles"]
	for r in roles:
		var all: Array = []
		for choice in roles[r].cyberware:
			all.append_array(choice)
		lists["role " + r] = all
	for k in lists:
		var im: Array[Dictionary] = []
		var ids: Array = lists[k]
		if k.begins_with("role "):   # each choice on its own alongside the rest
			ids = []
			for choice in roles[k.substr(5)].cyberware:
				ids.append(choice[0])
		for id in Cyber.foundations_first(ids):
			var loc := Cyber.auto_loc(im, id)
			assert_true(loc != "", "%s: %s fits (%s)" % [k, id, Cyber.block_any(im, id)])
			im.append({"id": id, "loc": loc if loc != "" else Cyber.fallback_loc(id)})


func test_skin_weave_and_subdermal_armor_mend_a_point_a_day_of_rest() -> void:
	var c := Campaign.new_game(5)
	var m: Combatant = c.crew[0]
	m.implants.clear()
	m.subdermal.clear()
	m.install_cyberware("skin_weave")
	for i in 4:
		m.ablate("body")
	m.ablate("head")
	assert_eq(m.subdermal.body.sp, 3)
	c.rest(1)
	assert_eq(m.subdermal.body.sp, 4, "1 SP a day of natural healing (p.364)")
	assert_eq(m.subdermal.head.sp, 7, "both locations, up to full")
	c.rest(5)
	assert_eq(m.subdermal.body.sp, 7)


func test_vampyres_are_excellent() -> void:
	var c := Fixtures.unarmored()
	c.weapons.clear()
	c.install_cyberware("vampyres")
	var w: Weapon = c.weapons.filter(func(x): return x.builtin)[0]
	assert_eq(w.quality, "excellent", "an Excellent Quality Light Melee Weapon (p.363)")


## Pieces whose effect isn't played stay in the data but players never see them: cards, rosters,
## the HUD inspector, the debrief and the Med Bay all list Cyber.shown.
func test_inert_pieces_are_hidden_from_cards() -> void:
	var im := _with(["biomonitor", "neural_link", "interface_plugs", "cybereye", "cybereye", "anti_dazzle", "anti_dazzle", "kerenzikov"])
	var names := Cyber.shown_names(im)
	assert_true("Neural Link" in names and "Cybereye" in names)
	for hidden in ["Biomonitor", "Interface Plugs", "Anti-Dazzle"]:
		assert_false(hidden in names, "%s isn't played yet: hidden" % hidden)
	assert_eq(names.count("Cybereye"), 2, "two eyes, two pieces")
	var m := Fixtures.unarmored()
	m.implants.assign(im)
	var lost: Array = Campaign._lost_gear(m, {})
	assert_false("Biomonitor" in lost, "the debrief's lost gear hides it too")
	assert_false(Cyber.modelled("interface_plugs"))
	assert_true(Cyber.modelled("kerenzikov"))
