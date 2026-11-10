extends TestCase
## Weather (data/gen/atmospheres.json; Atmosphere picks it, Weather plays its rules, WeatherFx draws
## it): the Night City Weather odds (NCW p.3), every gig with sky over it carrying a mood, the sight
## and heat rules out in the open (NCW p.4-5), the blackout's outage, the dust storm scene event and
## the Weather Turns twist, and the view keeping indoors dry.

## The four seasonal Current Conditions tables (NCW p.3), 1d6 each: 6 is Strange Weather.
const SEASONS := [
	["clear", "drizzle", "overcast", "overcast", "heavy_rain", "strange"],    # December to February
	["clear", "drizzle", "overcast", "drizzle", "heavy_rain", "strange"],     # March to May
	["drizzle", "clear", "overcast", "overcast", "clear", "strange"],         # June to August
	["drizzle", "clear", "overcast", "overcast", "clear", "strange"],         # September to November
]
## Strange Weather (NCW p.3), 1d10; row 8 is a cold snap when the Temperature roll came up Cold or
## Cool, else a heat wave.
const STRANGE := ["rad_wind", "ash", "flood", "blood_rain", "acid_rain", "storm", "smog", "snap_or_wave", "dust", "blackout"]
## The Temperature rolls (NCW p.3) that are Cold or Cool, per season: 6, 4, 0 and 1 of 6.
const COLD := [6, 4, 0, 1]


## The year-round chance of each mood by the book: each season a quarter of the year.
func _book_odds() -> Dictionary:
	var out := {}
	for s in 4:
		for row in SEASONS[s]:
			if row != "strange":
				out[row] = float(out.get(row, 0.0)) + 1.0 / 24.0
				continue
			for st in STRANGE:
				if st != "snap_or_wave":
					out[st] = float(out.get(st, 0.0)) + 1.0 / 240.0
				else:
					out["cold_snap"] = float(out.get("cold_snap", 0.0)) + COLD[s] / 6.0 / 240.0
					out["heat_wave"] = float(out.get("heat_wave", 0.0)) + (6 - COLD[s]) / 6.0 / 240.0
	return out


func test_the_base_odds_are_the_books() -> void:
	var book := _book_odds()
	var base: Dictionary = Atmosphere.data().weights.base
	var total := 0
	for k in base:
		total += int(base[k])
	assert_eq(total, 1440, "in 1/1440ths")
	assert_eq(book.keys().size(), base.keys().size(), "every row of the tables is a mood")
	for k in book:
		assert_true(Atmosphere.has(String(k)), "%s is a mood" % k)
		assert_near(float(base.get(k, 0)) / total, float(book[k]), 0.000001, "%s at the book's odds" % k)
	var w := Atmosphere.weights("")   # no district: the base
	for k in base:
		assert_eq(int(w[k]), int(base[k]))
	var hits := {}
	var n := 6000
	for s in range(1, n + 1):
		var id := Atmosphere.pick(s, "")
		hits[id] = int(hits.get(id, 0)) + 1
	for k in ["clear", "overcast", "drizzle", "heavy_rain"]:
		assert_near(float(hits.get(k, 0)) / n, float(book[k]), 0.025, "%s comes up at about its odds" % k)
	var strange := 0
	for k in STRANGE:
		strange += int(hits.get(k, 0))
	strange += int(hits.get("cold_snap", 0)) + int(hits.get("heat_wave", 0))
	assert_near(float(strange) / n, 1.0 / 6.0, 0.025, "Strange Weather one roll in six")


func test_every_gig_with_sky_has_weather() -> void:
	var camp := Campaign.new_game(21)
	var seen := {}
	for i in 12:
		camp.refresh_board()
		for g in camp.board:
			var scene := String(g.scene)
			if Atmosphere.has_sky(scene):
				assert_true(Atmosphere.has(String(g.get("mood", ""))), "%s at %s: a mood" % [g.title, scene])
				assert_eq(String(g.mood), Campaign.gig_mood(int(g.seed), String(g.get("district", "")), scene), "the seed's and the district's")
				assert_eq(String(Campaign.scene_opts(g).get("mood", "")), String(g.mood), "handed to the map, tower or not")
				seen[String(g.mood)] = true
			else:
				assert_eq(String(g.get("mood", "")), "", "%s: no sky, no weather" % scene)
	assert_true(seen.size() >= 3, "street gigs see several kinds of weather (%s)" % str(seen.keys()))
	assert_eq(Campaign.gig_mood(5, "kabuki", "undercity"), "", "none under the city")
	var g0: Dictionary = camp.board[0].duplicate(true)
	var m := SceneGen.generate(int(g0.seed), String(g0.scene), Campaign.scene_opts(g0))
	assert_eq(Atmosphere.of(m), String(g0.get("mood", Atmosphere.default_id())), "the map keeps it")
	g0.erase("mood")   # an offer saved before the weather pass gets its weather when taken
	camp.refresh_board()
	camp.board.append(g0)
	var started := camp.accept(camp.board.size() - 1)
	assert_eq(String(started.get("mood", "")), Campaign.gig_mood(int(g0.seed), String(g0.get("district", "")), String(g0.scene)))


## A 24x10 lot: open street west of x 16, a roofed room east of it (its roof on floor 1).
func _lot(mood: String) -> TacMap:
	var m := TacMap.new(24, 10, 2)
	for y in 10:
		for x in 24:
			m.set_t(0, x, y, TacMap.T.OUTSIDE if x < 16 else TacMap.T.FLOOR)
			if x >= 16:
				m.set_t(1, x, y, TacMap.T.ROOF)
	m.entrances.append({"floor": 0, "pos": Vector2i(2, 5), "kind": "deploy", "main": false, "cells": [Vector2i(2, 5)]})
	m.params = {"mood": mood}
	return m


func _enc(mood: String, guard_at := Vector3i(10, 5, 0)) -> Encounter:
	var dice := Dice.new(5)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id("heavy_pistol"))
	var e := Encounter.setup(_lot(mood), dice, crew)
	e.units = e.units.filter(func(u): return u.team == 0)
	var g := Fixtures.unarmored("G", {"REF": 4})
	g.weapons.append(Weapon.from_id("heavy_pistol"))
	e._add(g, guard_at, 1)
	e.units[-1].alerted = true
	e.units[0].pos = Vector3i(2, 5, 0)
	e.cur = e.units[0]
	e.turn = TurnState.begin(e.dice, e.units[0].c)
	return e


func test_open_sky() -> void:
	var m := _lot("heavy_rain")
	assert_eq(Weather.surface(m, 3, 3), 0, "the street")
	assert_eq(Weather.surface(m, 20, 3), 1, "a building: its roof")
	assert_true(Weather.open_sky(m, Vector3i(3, 3, 0)))
	assert_false(Weather.open_sky(m, Vector3i(20, 3, 0)), "indoors under the roof")
	assert_true(Weather.open_sky(m, Vector3i(20, 3, 1)), "up on the roof")
	var real := SceneGen.generate(3, "street_block", {"security": 1})
	var inside := 0
	for y in real.h:
		for x in real.w:
			if real.label(real.street, x, y) >= 0:
				assert_false(Weather.open_sky(real, Vector3i(x, y, real.street)), "a room is never out in the weather (%d,%d)" % [x, y])
				inside += 1
	assert_true(inside > 0)


func test_sight_and_long_shots_in_heavy_weather() -> void:
	var m := _lot("smog")
	var out := Vector3i(3, 5, 0)
	var room := Vector3i(18, 5, 0)
	var room2 := Vector3i(20, 5, 0)
	assert_eq(Weather.sight_penalty(m, "smog", out, Vector3i(12, 5, 0)), 4, "inversion smog: -4 (NCW p.5)")
	assert_eq(Weather.sight_penalty(m, "heavy_rain", out, room), 2, "into the rain from indoors: -2")
	assert_eq(Weather.sight_penalty(m, "heavy_rain", room, room2), 0, "indoors: none")
	assert_eq(Weather.sight_penalty(m, "drizzle", out, Vector3i(12, 5, 0)), 0, "light rain hides nothing (NCW p.5)")
	assert_eq(Weather.sight_penalty(m, "clear", out, Vector3i(12, 5, 0)), 0)
	assert_eq(Weather.ranged_penalty(m, "dust", out, Vector3i(6, 5, 0), 6.0), 0, "the first range band: no penalty")
	assert_eq(Weather.ranged_penalty(m, "dust", out, Vector3i(6, 5, 0), 8.0), 2, "past it: -2")
	var wet := _enc("heavy_rain")
	var dry := _enc("clear")
	assert_eq(wet.weather, "heavy_rain", "the encounter takes the map's mood")
	var pw := wet.preview(wet.units[1], wet.units[0].c.weapons[0], Attack.Mode.SINGLE)
	var pd := dry.preview(dry.units[1], dry.units[0].c.weapons[0], Attack.Mode.SINGLE)
	assert_true(pw.ok and pd.ok)
	assert_eq(int(pw.weather), -2, "16 m through heavy rain")
	assert_eq(int(pw.base), int(pd.base) - 2, "the attacker's base takes it")
	assert_true(float(pw.chance) < float(pd.chance), "a lower hit chance")
	var close := _enc("heavy_rain", Vector3i(4, 5, 0))
	assert_eq(int(close.preview(close.units[1], close.units[0].c.weapons[0], Attack.Mode.SINGLE).weather), 0, "4 m: close enough to see")
	var off := Atmosphere.data().duplicate(true)
	Atmosphere.data()["effects"] = false   # the owner's switch
	assert_eq(Weather.sight("smog"), 0, "effects off: nothing")
	Atmosphere.data()["effects"] = off.effects


func test_heat_wave_and_blackout() -> void:
	var e := _enc("heat_wave")
	for u in e.units:
		assert_eq(int(u.c.heat), 2, "a heat wave: armor penalties 2 worse (NCW p.5)")
	var a: Combatant = e.units[0].c
	var bare := Fixtures.unarmored("B")
	bare.heat = 2
	assert_eq(bare.armor_penalty(), 0, "no armor penalty, nothing to make worse")
	a.gig_reset()
	assert_eq(a.heat, 0, "gone by the next gig")
	assert_true("power" in _enc("blackout").outages, "a blackout takes the power out")
	assert_false("power" in _enc("clear").outages)
	assert_eq(Weather.hud_line("dust"), "DUST STORM · SIGHT -2")
	assert_eq(Weather.hud_line("heat_wave"), "HEAT WAVE · ARMOR PENALTY +2")
	assert_eq(Weather.hud_line("drizzle"), "", "no rule, no line")
	for id in Atmosphere.ids():
		assert_false(Weather.hud_line(String(id)).contains("p."), "no page in the HUD")


func test_heat_makes_an_existing_armor_penalty_worse() -> void:
	var c := Fixtures.shooter("H")
	var heavy := ArmorPiece.new()
	heavy.penalty = 2
	c.armor["body"] = heavy
	c.armor["head"] = null
	assert_eq(c.armor_penalty(), 2)
	c.heat = 2
	assert_eq(c.armor_penalty(), 4, "a -2 penalty becomes -4 (NCW p.5)")
	assert_eq(c.stat("REF"), maxi(0, c.raw_stat("REF") - 4))


func test_the_weather_turns() -> void:
	var dice := Dice.new(5)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	var t := Twist.make(Dice.new(1), Twist.row("unexpected_weather"), -1, "round99")
	var e := Encounter.setup(_lot("clear"), dice, crew, "data", {"twist": t})
	e.next_turn()
	assert_eq(e.weather, "clear")
	Twist.spring(e)
	assert_true(e.weather in Weather.turn_pool("clear"), "a storm or hazard blows in (%s)" % e.weather)
	assert_true("weather" in e.twist.applied)
	var ev: Array = e.events.filter(func(x): return String(x.type) == "weather")
	assert_eq(ev.size(), 1, "the view hears of it")
	assert_eq(String(ev[0].mood), e.weather)
	assert_false(Weather.turn_pool("dust").has("dust"), "never the weather it already has")
	for id in Weather.turn_pool(""):
		var md: Dictionary = Atmosphere.data().moods[id]
		assert_false(md.has("heat") or md.has("outage"), "%s blows in within minutes (not a days-long row)" % id)
	var hot := _enc("clear")
	hot.set_weather("heat_wave")
	assert_eq(int(hot.units[0].c.heat), 2, "the heat reaches everyone at once")


func test_the_dust_storm_rolls_in() -> void:
	var r := SceneEvent.row(SceneEvent.table_of("dust_storm"), "dust_storm")
	assert_true(SceneEvent.enabled(r), "the row plays now")
	var gig := {"seed": 7, "district": "outskirts", "scene": "badlands", "mood": "clear"}
	var ev: Variant = SceneEvent.roll(gig, 2 * 60, "dust_storm")
	assert_eq(SceneEvent.mood_of(ev), "dust")
	var camp := Campaign.new_game(4)
	var started := camp.accept_custom({"district": "outskirts", "scene": "badlands", "street": "dust_storm", "mood": "clear", "seed": 9})
	assert_eq(String(started.get("mood", "")), "dust", "the gig plays in the storm the street brings")
	camp.active_gig = started
	var gs := GigSetup.for_campaign(camp)
	assert_eq(gs.enc.weather, "dust", "and so do its rules")
	assert_true("mood" in (gs.enc.scene_event.get("applied", []) as Array))


func test_the_view_keeps_indoors_dry() -> void:
	var m := SceneGen.generate(3, "street_block", {"security": 1, "mood": "heavy_rain"})
	var fx := WeatherFx.new()
	fx.build(m, "heavy_rain", false)
	assert_true(int(fx.counts.get("rain", 0)) > 1000, "rain over the street (%d)" % int(fx.counts.get("rain", 0)))
	assert_true(fx.counts.has("haze"))
	var img := fx.mask_tex.get_image()
	for y in m.h:
		for x in m.w:
			if m.label(m.street, x, y) >= 0:
				assert_true(img.get_pixel(x, y).r < 0.01, "no haze or wet street in a room (%d,%d)" % [x, y])
	assert_eq(WeatherFx.ground(Atmosphere.look("heavy_rain")), Vector4(1, 1, 0, 0), "the street soaked, rain rings in the puddles")
	assert_eq(WeatherFx.ground(Atmosphere.look("cold_snap")).z, 1.0, "frost")
	assert_eq(WeatherFx.ground(Atmosphere.look("flood")).w, 1.0, "standing water")
	var dry := WeatherFx.new()
	dry.build(m, "clear", false)
	assert_true(dry.counts.is_empty(), "clear: nothing in the air")
	var storm := WeatherFx.new()
	storm.build(m, "storm", true)
	assert_true(storm._rate > 0.0, "a thunderstorm flashes")
	fx.free()
	dry.free()
	storm.free()
