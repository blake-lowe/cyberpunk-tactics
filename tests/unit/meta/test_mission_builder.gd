extends TestCase
## The Mission Builder (MissionBuilder; SPM p.28, sheet p.102): board offers built in the book's
## steps (client, mission, focus, payment, twist hook), its tables (data/gen/mission_builder.json),
## the non-eb payments and their tokens, the save migration and the dev card's fields.

const SLOTS := ["target", "item", "the_item", "The_item", "item_short"]


func _won(c: Campaign, gig: Dictionary) -> Dictionary:
	c.active_gig = gig.duplicate(true)
	var m := SceneGen.generate(int(gig.seed), String(gig.scene), Campaign.scene_opts(gig))
	var e := Encounter.setup(m, c.dice, c.alive_crew())
	e.state = "won"
	return c.resolve(e)


func _words(s: String) -> int:
	return s.split(" ", false).size()


# --- The pipeline -----------------------------------------------------------------------------

func test_the_steps_run_in_the_books_order_with_a_twist_step() -> void:
	assert_eq(MissionBuilder.STEPS, ["client", "mission", "focus", "payment", "twist"], "SPM p.28 steps 1-5")
	var c := Campaign.new_game(12)
	for g in c.board:
		for k in MissionBuilder.STEPS:
			assert_true(g.has(k), "%s: has %s" % [g.title, k])
		assert_true(Twist.valid(g.twist), "null or a hidden twist (Twist.roll)")
	assert_eq(MissionBuilder.twist(c.dice, c.board[0], "none"), null)
	assert_eq(String(MissionBuilder.twist(c.dice, c.board[0], "hired_muscle").id), "hired_muscle")


func test_board_offers_are_new_style() -> void:
	var c := Campaign.new_game(21)
	var g := RulesDB.gen("gigs.json")
	var seen := 0
	for day in 6:
		c.refresh_board()
		for gig in c.board:
			seen += 1
			var m: Dictionary = gig.mission
			assert_true(MissionBuilder.enabled(MissionBuilder.mission_def(String(m.id))), "%s: a playable mission type" % m.id)
			assert_eq(String(m.objective), Campaign.objective_for(gig), "the mission type is the job's objective")
			if not gig.get("unique", false):
				assert_true(String(gig.title).begins_with(String(m.label) + ": "), "titled by its mission type: %s" % gig.title)
				assert_false(String(gig.title).contains("{") or String(gig.blurb).contains("{"), "slots filled: %s" % gig.blurb)
				assert_true(String(gig.blurb).contains(MissionBuilder.pitch(gig, World.display_name(String(gig.faction)))), "the framing is the pitch")
			assert_eq(String(gig.client.zone), MissionBuilder.zone_for(gig), "the client from the place's zone")
			assert_true(MissionBuilder.fits(MissionBuilder.focus_def("%s/%s" % [gig.focus.category, gig.focus.id]), String(m.objective)), "%s fits %s" % [gig.focus.id, m.objective])
			var p: Dictionary = gig.payment
			assert_eq(int(gig.pay), int(p.eb), "pay is the payment's eb")
			var rate := int(g.pay[str(int(gig.security))])
			if gig.get("unique", false):
				assert_eq(String(p.type), "eb", "a personal job pays its promised eb")
			elif String(gig.get("scene", "")) != "tower_top":
				assert_eq(int(p.base), rate, "the job's rate (CPR p.381)")
	assert_true(seen >= 18, "%d offers" % seen)


func test_the_board_is_deterministic() -> void:
	var a := Campaign.new_game(33)
	var b := Campaign.new_game(33)
	assert_eq(JSON.stringify(a.board), JSON.stringify(b.board), "the same seed, the same offers")
	a.refresh_board()
	b.refresh_board()
	assert_eq(JSON.stringify(a.board), JSON.stringify(b.board))


func test_location_gating_still_decides_the_kind() -> void:
	var c := Campaign.new_game(8)
	for day in 6:
		c.refresh_board()
		for gig in c.board:
			if gig.get("unique", false) or String(gig.get("scene", "")) == "tower_top":
				continue
			var l := World.location(String(gig.location))
			var kinds: Array = (l.get("gigs", []) as Array).duplicate()
			for h in l.get("hooks", []):
				kinds.append_array(h.gigs)
			# a newer kind plays where the kinds it borrows from do (gigs.json hosts)
			assert_true(Campaign.host_kinds(String(gig.kind)).any(func(k): return k in kinds), "%s plays at %s" % [gig.kind, l.name])
			assert_true(Campaign.kinds_at(l).has(String(gig.kind)))


# --- Step 1: who's hiring ---------------------------------------------------------------------

func test_client_tables_are_the_books_dice() -> void:
	var dies := {"corporate": [1, 10], "moderate": [1, 10], "street": [2, 20], "outskirts": [1, 10]}
	for z in MissionBuilder.ZONES:
		var rows := MissionBuilder.client_rows(z)
		var rolls: Array = rows.map(func(r): return int(r.roll))
		assert_eq(rolls, range(int(dies[z][0]), int(dies[z][1]) + 1), "%s: one row per roll" % z)
		for r in rows:
			assert_between(float(_words(String(r.label))), 2.0, 5.0, "%s: a short paraphrase" % r.label)
		var d := Dice.new(5)
		for i in 200:
			var cl := MissionBuilder.roll_client(d, z)
			assert_eq(String(cl.zone), z)
			assert_between(float(cl.roll), float(dies[z][0]), float(dies[z][1]))
			assert_false(MissionBuilder.client_def("%s/%s" % [z, cl.id]).is_empty(), "a row of %s" % z)


func test_the_zone_comes_from_the_place() -> void:
	var z: Dictionary = MissionBuilder.data().zones
	var all := World.locations()
	var seen := {}
	for id in all:
		var l := World.location(String(id))
		var zone := MissionBuilder.zone_of(String(id))
		seen[zone] = true
		var code := SecurityCode.normalise(l.get("security_code"))
		if code.is_empty():
			code = SecurityCode.normalise(World.district(String(l.district)).get("security_code"))
		if String(l.district) in z.outskirts_districts or String(l.get("scene", "")) in z.outskirts_scenes:
			assert_eq(zone, "outskirts", "%s: in the outskirts" % id)
		elif int(code.n) <= int(z.street_max):
			assert_eq(zone, "street", "%s: code %d" % [id, int(code.n)])
		elif int(code.n) >= int(z.corporate_min):
			assert_eq(zone, "corporate", "%s: code %d" % [id, int(code.n)])
		else:
			assert_true(zone in ["street", "moderate", "corporate"])
	for zz in MissionBuilder.ZONES:
		assert_true(seen.has(zz), "some place is %s" % zz)
	assert_eq(MissionBuilder.zone_of("", "outskirts"), "outskirts")
	assert_eq(MissionBuilder.zone_of("", "rancho_coronado"), "street", "a code-2 district")
	assert_eq(MissionBuilder.zone_of("", "executive_zone"), "corporate")
	assert_eq(MissionBuilder.zone_of("", "little_china"), "moderate", "code 5, market streets")
	assert_eq(MissionBuilder.zone_of("", "new_westbrook"), "street", "code 6 in a combat zone")


# --- Step 2: the mission ------------------------------------------------------------------------

func test_mission_types_cover_the_d100_and_every_enabled_row_plays() -> void:
	var rows := MissionBuilder.mission_rows()
	assert_eq(rows.size(), 50, "SPM p.72: 50 rows")
	var covered := {}
	var kinds: Array = (RulesDB.gen("gigs.json").templates as Array).map(func(t): return String(t.kind))
	var by := {}
	var on := 0
	var re := RegEx.create_from_string("\\{(\\w+)\\}")
	for r in rows:
		assert_eq(int(r.roll[1]) - int(r.roll[0]), 1, "%s: two points" % r.id)
		for x in range(int(r.roll[0]), int(r.roll[1]) + 1):
			assert_false(covered.has(x), "roll %d once" % x)
			covered[x] = true
		assert_between(float(_words(String(r.label))), 1.0, 5.0, "%s: a short label" % r.label)
		if MissionBuilder.enabled(r):
			on += 1
			assert_true(String(r.objective) in Objective.kinds(), "%s: a real objective" % r.id)
			assert_true(MissionBuilder.kind_of(r) in kinds, "%s: a gig kind" % r.id)
			assert_true(String(r.get("framing", "")) != "", "%s: framed" % r.id)
			for m in re.search_all(String(r.framing)):
				assert_true(m.get_string(1) in SLOTS, "%s: slot {%s} is known" % [r.id, m.get_string(1)])
			by[String(r.objective)] = int(by.get(String(r.objective), 0)) + 1
		else:
			assert_true(r.objective == null, "%s: disabled rows say so" % r.id)
			assert_true(String(r.get("needs", "")) != "", "%s: names what it needs" % r.id)
	assert_eq(covered.size(), 100, "1-100 covered")
	assert_eq(on, 37, "37 rows play today, 13 wait for social, driving and psycho-hunt systems")
	for ob in Campaign.OBJECTIVES.values():
		assert_true(int(by.get(String(ob), 0)) > 0, "%s has a mission type" % ob)


func test_rolling_a_mission_skips_rows_we_cant_play() -> void:
	var d := Dice.new(9)
	var ids := {}
	for i in 500:
		var m := MissionBuilder.roll_mission(d)
		assert_true(MissionBuilder.enabled(MissionBuilder.mission_def(String(m.id))))
		assert_eq(MissionBuilder.mission_def(String(m.id)).roll[0] <= int(m.roll) and int(m.roll) <= MissionBuilder.mission_def(String(m.id)).roll[1], true, "the roll that came up")
		ids[m.id] = true
	assert_eq(ids.size(), 37, "every playable row comes up")
	for ob in Campaign.OBJECTIVES.values():
		for i in 30:
			assert_eq(String(MissionBuilder.roll_mission(d, String(ob)).objective), String(ob))
	assert_eq(MissionBuilder.roll_mission(Dice.new(4)), MissionBuilder.roll_mission(Dice.new(4)), "seeded")


# --- Step 3: the focus --------------------------------------------------------------------------

func test_focus_items_fit_the_zone_and_the_objective() -> void:
	var tags := ["data", "object", "captive", "mark", "wreck", "vehicle", "site"]
	var fb: Dictionary = MissionBuilder.data().zones.fallback
	var dies := {"corporate": 10, "moderate": 10, "street": 19, "outskirts": 10}
	for z in MissionBuilder.ZONES:
		var rows := MissionBuilder.focus_rows(z)
		assert_eq(rows.size(), int(dies[z]), "SPM p.73: %s" % z)
		for r in rows:
			assert_true((r.as as Array).all(func(t): return t in tags), "%s: known tags" % r.id)
			assert_between(float(_words(String(r.get("short", r.label)))), 1.0, 5.0, "%s: short" % r.id)
	var d := Dice.new(11)
	for ob in Campaign.OBJECTIVES.values():
		for z in MissionBuilder.ZONES:
			var want := ""
			for cat in fb[z]:
				if MissionBuilder.focus_rows(String(cat)).any(func(r): return MissionBuilder.fits(r, String(ob))):
					want = String(cat)
					break
			assert_true(want != "", "%s has items somewhere" % ob)
			for i in 40:
				var f := MissionBuilder.roll_focus(d, z, String(ob))
				assert_eq(String(f.category), want, "%s in %s: the zone's own items when any fit" % [ob, z])
				assert_true(MissionBuilder.fits(MissionBuilder.focus_def("%s/%s" % [f.category, f.id]), String(ob)), "%s plays %s" % [f.id, ob])
	assert_eq(String(MissionBuilder.roll_focus(d, "corporate", "data").category), "corporate")
	assert_eq(String(MissionBuilder.roll_focus(d, "outskirts", "data").category), "street", "no data in the Outskirts: the next zone's")
	assert_eq(String(MissionBuilder.roll_focus(d, "moderate", "rescue").category), "street", "no person in Moderate")
	assert_eq(String(MissionBuilder.roll_focus(d, "corporate", "snatch", ["prototype"]).id), "prototype", "a preferred item")


func test_focus_names_the_marker_and_the_debrief() -> void:
	var f := MissionBuilder._focus("corporate", MissionBuilder.focus_def("corporate/prototype"), 8)
	var slots := MissionBuilder.item_slots(f)
	assert_eq(String(slots.item), "a tech prototype")
	assert_eq(String(slots.the_item), "the tech prototype")
	assert_eq(String(slots.item_short), "tech prototype")
	var gig := {"kind": "corp_extraction", "focus": f}
	assert_eq(MissionBuilder.debrief_line(gig, true), "The tech prototype went home with the crew.")
	assert_eq(MissionBuilder.debrief_line(gig, false), "The tech prototype stayed behind.")
	assert_eq(MissionBuilder.debrief_line({"kind": "corp_extraction"}, true), "", "an old offer has no focus line")
	# On the map: the snatch's package is the focus item.
	var c := Campaign.new_game(4)
	c.active_gig = {"kind": "corp_extraction", "scene": "lone_building", "site": "corp_office", "security": 1, "seed": 7, "focus": f}
	var s := GigSetup.for_campaign(c)
	assert_eq(String(s.enc.obj.marks(false)[0].label), "★ PROTOTYPE", "the marker names it")
	assert_eq(s.enc.obj.hud_text(), "RECOVER THE PROTOTYPE")


# --- Step 4: payment ----------------------------------------------------------------------------

func test_payment_rates_and_types() -> void:
	var rates: Dictionary = RulesDB.gen("gigs.json").pay
	assert_eq([int(rates["1"]), int(rates["2"]), int(rates["3"])], [1000, 2000, 4000], "CPR p.381 per person (500/1,000/2,000) for a crew of two")
	var staple := String(NightMarket.staples()[0])
	var pool := func(v: int) -> Array: return [staple] if v >= 100 else []
	var eb := MissionBuilder.roll_payment(Dice.new(1), 2000, "eb", pool)
	assert_eq(eb, {"type": "eb", "base": 2000, "eb": 2000})
	var info := MissionBuilder.roll_payment(Dice.new(1), 2000, "information", pool)
	assert_eq(int(info.eb), 1500, "information keeps three quarters of the eb")
	var fav := MissionBuilder.roll_payment(Dice.new(1), 2000, "favour:market", pool)
	assert_eq(String(fav.kind), "market")
	assert_eq(int(fav.cap), 1000, "a market item up to half the rate")
	assert_eq(int(fav.eb), 1500)
	assert_eq(String(MissionBuilder.roll_payment(Dice.new(1), 2000, "favour:treatment", pool).kind), "treatment")
	var goods := MissionBuilder.roll_payment(Dice.new(1), 2000, "goods", pool)
	assert_eq(String(goods.item), staple)
	assert_eq(int(goods.eb), 1000, "goods: half the eb")
	var none := MissionBuilder.roll_payment(Dice.new(1), 2000, "goods", func(_v: int) -> Array: return [])
	assert_eq(String(none.type), "eb", "no goods to be had: eb")
	assert_eq(int(none.eb), 2000)
	var d := Dice.new(3)
	var n := {}
	for i in 3000:
		var p := MissionBuilder.roll_payment(d, 1000, "", pool)
		n[p.type] = int(n.get(p.type, 0)) + 1
	assert_near(float(n.eb) / 3000.0, 0.7, 0.04, "mostly eb (HOUSE-RULE 7 in 10)")
	for t in ["information", "favour", "goods"]:
		assert_near(float(n.get(t, 0)) / 3000.0, 0.1, 0.03, "%s: 1 in 10" % t)
	assert_eq(MissionBuilder.payment_text(info), "1,500 eb + intel on the next board")
	assert_eq(MissionBuilder.payment_text(fav), "1,500 eb + a favour: a Night Market item up to 1,000 eb")
	assert_eq(MissionBuilder.payment_text(eb), "2,000 eb")


func test_goods_come_from_what_is_on_sale() -> void:
	var c := Campaign.new_game(5)
	var pool := c.goods_pool(1000)
	assert_false(pool.is_empty())
	for k in pool:
		assert_true(c.on_sale(String(k)) and Items.price(String(k)) <= 1000 and Items.price(String(k)) * 3 >= 1000, "%s: on sale, worth a third to all of it" % k)
	var gig: Dictionary = c.board[0].duplicate(true)
	gig["pay"] = int(gig.payment.base)
	MissionBuilder.payment_step(c.dice, gig, "goods", func(v: int) -> Array: return c.goods_pool(v))
	var key := String(gig.payment.item)
	var had := c.stored(key)
	var r := _won(c, gig)
	assert_eq(c.stored(key), had + 1, "the goods go into storage")
	assert_eq(String(r.paid_extra), Items.display_name(key))


func test_information_shows_the_next_boards_complications() -> void:
	var c := Campaign.new_game(6)
	assert_false(c.board.any(func(g): return g.has("intel") or g.has("complication")), "no intel: the board doesn't know")
	var gig: Dictionary = c.board[0].duplicate(true)
	gig["pay"] = int(gig.payment.base)
	MissionBuilder.payment_step(c.dice, gig, "information")
	var eb := c.eb
	var r := _won(c, gig)
	assert_eq(c.eb, eb + int(gig.payment.eb), "the eb part")
	assert_eq(c.intel, 1, "an intel token")
	assert_eq(String(r.paid_extra), "intel on the next board")
	for g in c.board:
		assert_true(String(g.intel) in ["clean", "trouble"], "every offer foreseen")
		var eo := Campaign.encounter_opts(g)
		if String(g.intel) == "trouble":
			assert_true(eo.complication is Dictionary and int(eo.complication.roll) >= 1, "a complication it will play")
		else:
			assert_false(bool(eo.get("complications", true)), "none")
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.intel, 1, "saved")
	assert_eq(String(back.board[0].intel), String(c.board[0].intel))
	c.accept(0)
	assert_eq(c.intel, 0, "taking a job spends it")
	# The foreseen answer is what the encounter plays.
	var s := GigSetup.for_campaign(c)
	assert_eq(s.enc.complication.is_empty(), String(c.active_gig.intel) == "clean" or Complication.top_tier(s.enc) == "")


func test_favours_are_kept_and_spent() -> void:
	var c := Campaign.new_game(7)
	var gig: Dictionary = c.board[0].duplicate(true)
	gig["pay"] = int(gig.payment.base)
	MissionBuilder.payment_step(c.dice, gig, "favour:treatment")
	_won(c, gig)
	assert_eq(c.favours.size(), 1)
	assert_eq(c.treat_cost(), 0, "the next Treatment is on the fixer")
	var crits: Dictionary = RulesDB.load_json("critical_injuries.json")
	var a: Combatant = c.crew[0]
	a.add_injury(crits.body["6"], "body", false)
	a.add_injury(crits.body["6"], "body", false)
	var eb := c.eb
	assert_true(c.treat(a, 0))
	assert_eq(c.eb, eb, "free")
	assert_true(c.favours.is_empty(), "spent")
	assert_true(c.treat_cost() > 0)
	# A market favour: one item up to its cap off the cart.
	c.favours.append({"kind": "market", "cap": 1000, "from": "Mr. Blue", "day": 1})
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.favours, c.favours, "saved")
	var key := ""
	for s in c.market_stock():
		if int(s.cost) <= 1000 and int(s.cost) > 0 and Items.is_stored(String(s.key)):
			key = String(s.key)
			break
	assert_true(key != "")
	c.eb = 10000
	var lines := {key: 2}
	assert_eq(c.favour_discount(lines), Items.price(key))
	assert_eq(c.cart_due(lines), Items.price(key))
	var r := c.buy_cart(lines)
	assert_true(bool(r.ok))
	assert_eq(c.eb, 10000 - Items.price(key), "one of the two free")
	assert_true(c.favours.is_empty())
	assert_eq(c.favour_discount(lines), 0)


# --- Save migration -----------------------------------------------------------------------------

func test_v15_offers_load_with_an_eb_payment_and_no_twist() -> void:
	var d: Dictionary = JSON.parse_string(JSON.stringify(Campaign.new_game(31).to_dict()))
	d["version"] = 15
	d.erase("intel")
	d.erase("favours")
	for g in d.board:   # an old-style offer: no client, mission, focus, payment or twist
		for k in ["client", "mission", "focus", "payment", "twist"]:
			g.erase(k)
	var titles: Array = (d.board as Array).map(func(g): return String(g.title))
	var mig := SaveMigrations.migrate(JSON.parse_string(JSON.stringify(d)))
	assert_eq(int(mig.version), SaveMigrations.CURRENT)
	for g in mig.board:
		assert_eq(String(g.payment.type), "eb")
		assert_eq(int(g.payment.eb), int(g.pay))
		assert_true(g.has("twist") and g.twist == null)
	assert_eq(int(mig.intel), 0)
	assert_eq(mig.favours, [])
	var c := Campaign.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_true(c != null, "loads")
	assert_eq(c.board.map(func(g): return String(g.title)), titles, "the old offers keep their titles")
	assert_eq(MissionBuilder.client_text(c.board[0]), "", "no client on an old offer")
	assert_eq(MissionBuilder.payment_extra(c.board[0].payment), "")
	Hud._fonts()
	var fs := FixerScreen.new()
	fs.camp = c
	var card := fs._gig_card(0, true)
	assert_true(card != null, "an old offer still makes a card")
	card.free()
	fs.free()


# --- The dev card -------------------------------------------------------------------------------

func test_custom_gig_builder_fields() -> void:
	var form := {"location": "hot_zone_11", "client": "street/gang_boss", "mission": "rescue_hostages", "item": "street/student",
		"payment": "favour:market", "seed": 4242, "pay": 3000}
	var flags := CustomGig.to_flags(form)
	for f in ["--client=street/gang_boss", "--mission=rescue_hostages", "--item=street/student", "--payment=favour:market"]:
		assert_true(f in flags, f)
	var back := CustomGig.from_flags(flags)
	var want := CustomGig.defaults()
	want.merge(form, true)
	assert_eq(back, want, "flags read back to the form")
	var g := CustomGig.build(form, Campaign.new_game(1))
	assert_eq(g, CustomGig.build(back, Campaign.new_game(2)), "the same gig from the flags, in any campaign")
	assert_eq(String(g.kind), "rescue", "the mission type sets the objective when it's auto")
	assert_eq(String(g.mission.id), "rescue_hostages")
	assert_eq(String(g.client.label), "a gang boss")
	assert_eq(String(g.focus.id), "student")
	assert_eq(String(g.payment.type), "favour")
	assert_eq(String(g.payment.kind), "market")
	assert_eq(int(g.pay), 3000, "Pay (eb) sets the eb part")
	assert_eq(int(g.payment.eb), 3000)
	assert_true(String(g.title).begins_with("DEV · Hostage rescue: "), g.title)
	assert_true(Twist.valid(g.twist), "auto: the Oracle's twist or none, in the saved shape")
	# A set objective wins over a mission type of another objective; a disabled row is never used.
	var g2 := CustomGig.build({"objective": "data", "mission": "rescue_hostages", "seed": 5}, Campaign.new_game(1))
	assert_eq(Campaign.objective_for(g2), "data")
	assert_eq(String(g2.mission.objective), "data")
	var g3 := CustomGig.build({"mission": "escort_client", "seed": 5}, Campaign.new_game(1))
	assert_true(MissionBuilder.enabled(MissionBuilder.mission_def(String(g3.mission.id))), "a disabled row is rolled past")
	# The card shows the sheet's rows.
	Hud._fonts()
	var card := CustomGigCard.new().setup(Campaign.new_game(3), true, CustomGig.defaults())
	var mb := card.find_child("MissionBuilder", true, false) as GridContainer
	assert_true(mb != null and mb.get_child_count() == 5, "who's hiring, payment, mission type, focus, twist")
	card.free()
