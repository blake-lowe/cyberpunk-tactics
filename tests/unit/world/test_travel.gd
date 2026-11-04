extends TestCase
## Travel time between districts (NC2045 p.18) and the campaign clock it moves.


func test_drive_time_per_district_follows_the_band() -> void:
	assert_eq(Travel.band("little_china"), "mid")
	assert_eq(Travel.district_minutes("executive_zone"), 15, "code 6+: 15 min")
	assert_eq(Travel.district_minutes("little_china"), 20, "code 4-5: 20 min")
	assert_eq(Travel.district_minutes("hot_zone"), 30, "code 3-: 30 min")
	assert_eq(Travel.district_minutes("atlantis"), -1)
	for id in World.districts():
		assert_true(Travel.district_minutes(String(id)) > 0, "%s has a travel band" % id)


func test_a_drive_crosses_every_district_on_the_way_both_ends_included() -> void:
	assert_eq(Travel.route("little_china", "little_china"), ["little_china"] as Array[String])
	assert_eq(Travel.drive_minutes("little_china", "little_china"), 20, "across your own district")
	assert_eq(Travel.route("little_china", "heywood_docks"), ["little_china", "heywood_docks"] as Array[String])
	assert_eq(Travel.drive_minutes("little_china", "heywood_docks"), 35, "20 + 15 next door")
	assert_eq(Travel.drive_minutes("heywood_docks", "little_china"), 35, "the same both ways")


func test_the_route_goes_round_slow_districts_when_that_is_quicker() -> void:
	# Upper Marina → Old Japantown: straight through the Hot Zone (low, 30) is 15+30+20 = 65; round
	# by Little China (mid, 20) is 15+20+20 = 55.
	assert_eq(Travel.route("upper_marina", "old_japantown"), ["upper_marina", "little_china", "old_japantown"] as Array[String])
	assert_eq(Travel.drive_minutes("upper_marina", "old_japantown"), 55)
	assert_eq(Travel.drive_minutes("little_china", "downtown"), 65)
	assert_eq(Travel.drive_minutes("downtown", "rancho_coronado"), 90)
	# Kabuki → Executive Zone: Kabuki, New Westbrook, Charter Hill, Executive Zone, all high: 60.
	assert_eq(Travel.drive_minutes("kabuki", "executive_zone"), 60)
	for a in World.districts():
		for b in ["little_china", "rancho_coronado"]:
			var t := Travel.drive_minutes(String(a), b)
			assert_true(t >= Travel.district_minutes(String(a)) + (0 if a == b else Travel.district_minutes(b)),
				"%s → %s reachable (%d)" % [a, b, t])


func test_no_district_no_drive() -> void:
	assert_eq(Travel.drive_minutes("little_china", ""), -1)
	assert_eq(Travel.route("", "kabuki"), [] as Array[String])
	assert_eq(Travel.label(-1), "")


func test_labels() -> void:
	assert_eq(Travel.label(35), "~35 MIN DRIVE")
	assert_eq(Travel.label(60), "~1 HR DRIVE")
	assert_eq(Travel.label(75), "~1 HR 15 MIN DRIVE")


func test_taking_a_gig_drives_out_from_the_safehouse() -> void:
	var c := Campaign.new_game(7)
	assert_eq(c.safehouse_district, "little_china", "a new crew starts in Little China")
	c.board[0]["district"] = "heywood_docks"
	var day0 := c.day
	var gig := c.accept(0)
	assert_eq(int(gig.travel_minutes), 35)
	assert_eq(c.minutes, 35, "the clock moves on by the drive")
	assert_eq(c.day, day0)
	assert_true(c.log.any(func(l): return l.contains("35 minutes")), "the log says how long the drive took")


func test_the_clock_rolls_minutes_into_days() -> void:
	var c := Campaign.new_game(7)
	var day0 := c.day
	c.minutes = 23 * 60 + 50
	c.advance_minutes(25)
	assert_eq(c.day, day0 + 1, "past midnight is the next day")
	assert_eq(c.minutes, 15)
	assert_eq(c.time_label(), "00:15")
	c.advance_minutes(3 * 24 * 60)
	assert_eq(c.day, day0 + 4)
	assert_eq(c.minutes, 15)


func test_a_gig_with_no_district_takes_no_time() -> void:
	var c := Campaign.new_game(7)
	c.board[0]["district"] = ""
	var gig := c.accept(0)
	assert_false(gig.has("travel_minutes"))
	assert_eq(c.minutes, 0)
