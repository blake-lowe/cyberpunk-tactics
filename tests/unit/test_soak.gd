extends TestCase
## The integration soak (tools/soak_driver.gd), small: one campaign plays the Combat Zone (its
## contestants), Totentanz (neutral ground) and a fixer-board offer, built as the greybox builds
## them (GigSetup), with the AI on both sides, settled, saved and reloaded, under every invariant
## the wide run checks (tools/soak.sh). Then the first gig again: the same seed must play the same
## way. Short fights (a few rounds) keep it inside the suite's time.

const PLAN := ["setpiece:new_westbrook_5", "setpiece:hot_zone_11", "board"]


func test_the_gig_loop_holds_together() -> void:
	var d := SoakDriver.new()
	d.max_rounds = 4
	var camp := d.run_campaign(7, PLAN.size(), PLAN)
	for f in d.failures:
		failures.append(f)
	assert_true(camp != null)
	assert_eq(int(d.stats.gigs), PLAN.size(), "every gig on the plan was taken: %s" % "\n".join(d.trace))
	assert_eq(int((d.stats.setpieces as Dictionary).get("combat_zone", 0)), 1, "the Combat Zone was played")
	assert_eq(int((d.stats.setpieces as Dictionary).get("totentanz", 0)), 1, "Totentanz was played")


func test_the_same_seed_plays_the_same_way() -> void:
	var a := SoakDriver.new()
	a.max_rounds = 3
	a.run_campaign(11, 1, ["board"])
	var b := SoakDriver.new()
	b.max_rounds = 3
	b.run_campaign(11, 1, ["board"])
	assert_false(a.trace.is_empty())
	assert_eq(a.trace, b.trace, "deterministic")
	assert_true(a.failures.is_empty(), "\n".join(a.failures))


## Every set-piece location can be offered on the board (the wide soak forces a gig at each).
func test_every_set_piece_location_has_an_offer() -> void:
	var ids := {}
	var camp := Campaign.new_game(5)
	for sp in SoakDriver.setpiece_locations():
		ids[sp[0]] = true
		var gig := SoakDriver.forced_offer(camp, String(sp[1]))
		assert_false(gig.is_empty(), "an offer at %s" % sp[1])
		assert_eq(String(gig.get("setpiece", "")), String(sp[0]), "%s plays as %s" % [sp[1], sp[0]])
	assert_eq(ids.size(), SetPieces.ids().size(), "all the set pieces")
