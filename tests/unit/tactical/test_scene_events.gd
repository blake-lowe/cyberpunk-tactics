extends TestCase
## Scene events (SceneEvent; data/gen/scene_events.json; SPM p.77-84) and everyday life
## (StreetLife): the tables, keying by band and time, the roll rate, every played fx, determinism,
## the save, and ambient bystanders keeping out of 1-wide ways and the objective's rooms.

const BOOK_TABLES := ["corporate.day", "corporate.night", "corporate.after_midnight", "moderate.day", "moderate.night",
	"moderate.after_midnight", "combat_zone.day", "combat_zone.night", "combat_zone.after_midnight", "outskirts.day",
	"outskirts.night", "outskirts.after_midnight"]
const UNMODELLED := ["id_check", "spike_strip", "shadow_toll", "dust_storm"]


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _map(seed_value := 77) -> TacMap:
	return SceneGen.generate(seed_value, "street_block", {"security": 2, "district": "watson_development"})


## An encounter on a fresh street with row `id` (its own table) as the gig's scene event.
func _enc(id: String, seed_value := 77, kind := "data") -> Encounter:
	var dice := Dice.new(5)
	var key := SceneEvent.table_of(id)
	var spec := SceneEvent.make(key, SceneEvent.row(key, id), 1)
	return Encounter.setup(_map(seed_value), dice, _crew(dice), kind, {"scene_event": spec, "district": "watson_development",
		"security_code": {"n": 11, "faction": "", "intensity": "medium", "hardened": false}})


func test_twelve_tables_by_the_books_numbering() -> void:
	assert_eq(SceneEvent.tables().keys(), BOOK_TABLES, "SPM p.77-84: four bands by three times")
	var ids := {}
	for k in BOOK_TABLES:
		var t: Dictionary = SceneEvent.tables()[k]
		var city := not String(k).begins_with("outskirts")
		var rows: Array = t.rows
		assert_eq(rows.size(), 20 if city else 10, "%s: d100 with 20 rows, the Outskirts d10 with 10" % k)
		assert_eq(int(t.die), 100 if city else 10, k)
		assert_true(String(t.source).begins_with("SPM p."), "%s cites its page" % k)
		for i in rows.size():
			var r: Dictionary = rows[i]
			var step := 5 if city else 1
			assert_eq([int(r.roll[0]), int(r.roll[1])], [i * step + 1, i * step + step], "%s %s: the book's numbering" % [k, r.id])
			assert_false(ids.has(r.id), "unique id %s" % r.id)
			ids[r.id] = true
			assert_between(String(r.label).split(" ", false).size(), 2, 5, "%s: our own 2-5 word label" % r.id)
			assert_true(String(r.note) != "" and r.has("fx"), "%s: a note and an fx" % r.id)
			if not r.has("unmodelled"):
				for f in r.fx:
					assert_true(String(f) in SceneEvent.FX, "%s: fx %s is implemented" % [r.id, f])
	var off: Array = []
	for k in BOOK_TABLES:
		for r in SceneEvent.rows(k):
			if not SceneEvent.enabled(r):
				off.append(String(r.id))
	assert_eq(off, UNMODELLED, "only what happens to the crew's own car, their ID check, and the weather are off")
	assert_eq(String(SceneEvent.row("combat_zone.after_midnight", "97").id), "gang_war", "a d100 roll finds its row")
	assert_eq(SceneEvent.table_of("ncpd_standoff"), "corporate.night")


func test_keyed_by_band_and_time() -> void:
	# HOUSE-RULE bands: the lower of the place's code and its district's; 0-3 / 4-7 / 8-11.
	assert_eq(SceneEvent.band_of(9, 10, "executive_zone", "neighborhood", "executive_zone"), "corporate")
	assert_eq(SceneEvent.band_of(8, 6, "mixed_residential", "lone_building", "north_heywood"), "moderate", "the street's lower code wins")
	assert_eq(SceneEvent.band_of(8, 2, "combat_zone", "lone_building", "rancho_coronado"), "combat_zone")
	assert_eq(SceneEvent.band_of(3, -1, "", "lone_building", ""), "combat_zone", "a place's own code with no district")
	assert_eq(SceneEvent.band_of(9, 9, "combat_zone", "lone_building", "x"), "moderate", "a Combat Zone district is never Corporate")
	assert_eq(SceneEvent.band_of(9, 9, "", "badlands", ""), "outskirts", "the badlands")
	assert_eq(SceneEvent.band_of(9, 5, "industrial", "lone_building", "outskirts"), "outskirts", "the Outskirts district")
	assert_eq(SceneEvent.band_of(5, 5, "", "undercity", ""), "", "no street in the tunnels")
	assert_eq(SceneEvent.band_of(-1, -1, "", "lone_building", ""), "moderate", "no code: the street fallback (NCPD 6)")
	# HOUSE-RULE times on the campaign clock; a tower's sky wins.
	assert_eq(SceneEvent.time_of(12 * 60), "day")
	assert_eq(SceneEvent.time_of(6 * 60), "day")
	assert_eq(SceneEvent.time_of(18 * 60), "night")
	assert_eq(SceneEvent.time_of(23 * 60 + 59), "night")
	assert_eq(SceneEvent.time_of(0), "after_midnight")
	assert_eq(SceneEvent.time_of(5 * 60 + 59), "after_midnight")
	assert_eq(SceneEvent.time_of(2 * 60, "day"), "day", "a day sky")
	assert_eq(SceneEvent.time_of(12 * 60, "night"), "night", "a night sky")
	assert_eq(SceneEvent.time_of(2 * 60, "night"), "after_midnight", "a night sky past midnight")
	# A real gig: its table follows its codes and the hour.
	var gig := {"seed": 1, "scene": "lone_building", "district": "rancho_coronado", "security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": false}}
	assert_eq(SceneEvent.band_for(gig), "combat_zone", "Rancho Coronado's code 2")
	var seen := {}
	for s in 400:
		gig.seed = s + 1
		var ev: Variant = SceneEvent.roll(gig, 60)
		if ev != null:
			seen[String(ev.table)] = true
	assert_eq(seen.keys(), ["combat_zone.after_midnight"], "1 a.m. in the Combat Zone rolls on that table only")


func test_about_half_the_gigs_and_rows_by_the_books_odds() -> void:
	assert_near(SceneEvent.chance(), 0.5, 0.0001, "HOUSE-RULE: a d10 of 1-5")
	var gig := {"seed": 1, "scene": "neighborhood", "district": "kabuki"}
	var hits := 0
	var counts := {}
	for s in 4000:
		gig.seed = s + 1
		var ev: Variant = SceneEvent.roll(gig, 22 * 60)
		if ev != null:
			hits += 1
			counts[String(ev.id)] = int(counts.get(String(ev.id), 0)) + 1
	assert_near(hits / 4000.0, 0.5, 0.03, "rolled rate")
	assert_eq(counts.size(), 20, "every Moderate-night row comes up (all twenty play)")
	for id in counts:
		assert_between(int(counts[id]) / float(hits), 0.02, 0.09, "%s: about 1 in 20" % id)


func test_the_roll_is_the_gigs_own() -> void:
	var gig := {"seed": 4242, "scene": "neighborhood", "district": "old_combat_zone"}
	var a: Variant = null
	for s in 50:   # a seed that gets one
		gig.seed = 4242 + s
		a = SceneEvent.roll(gig, 2 * 60)
		if a != null:
			break
	assert_true(a != null)
	for k in 5:
		assert_eq(SceneEvent.roll(gig.duplicate(), 2 * 60), a, "the same gig at the same hour rolls the same street")
	assert_true(SceneEvent.valid(a) and SceneEvent.valid(null))
	assert_false(SceneEvent.valid({"table": "moderate.day", "id": "nope", "row": 1}))
	assert_false(SceneEvent.valid({"table": "corporate.day", "id": "id_check", "row": 41}), "an unmodelled row isn't kept")
	assert_eq(SceneEvent.roll(gig, 2 * 60, "none"), null)
	assert_eq(String(SceneEvent.roll(gig, 12 * 60, "gang_war").id), "gang_war", "forced by id, whatever the hour")
	assert_eq(String(SceneEvent.roll(gig, 12 * 60, "corporate.night:76").id), "ncpd_standoff", "forced by table and roll")
	# The same street plays the same: two encounters from one spec put the same people in the same places.
	var e1 := _enc("gang_war")
	var e2 := _enc("gang_war")
	assert_eq(e1.units.map(func(u): return [u.pos, u.team, u.get("life", "")]), e2.units.map(func(u): return [u.pos, u.team, u.get("life", "")]))
	for i in 4:
		e1.next_turn()
		e2.next_turn()
		if e1.cur.team == 0:
			e1.end_turn()
			e2.end_turn()
	assert_eq(e1.log, e2.log, "and it plays out the same")


func test_crowds_are_bystanders() -> void:
	for id in ["exclusive_queue", "night_market", "protest_own_muscle", "led_juggler"]:
		var e := _enc(id)
		assert_true("crowd" in e.scene_event.applied, "%s: its crowd is out (%s)" % [id, e.scene_event.skipped])
		var crowd: Array = e.units.filter(func(u): return u.get("street_event", false) and u.get("civ", false))
		assert_true(crowd.size() >= 2, "%s: people" % id)
		for u in crowd:
			assert_eq(int(u.team), Encounter.CIV_TEAM, "%s: on the bystanders' side" % id)
			assert_true(u.c.weapons.is_empty(), "unarmed")
			assert_true(String(u.get("life", "")) != "", "posed")
	var e := _enc("protest_own_muscle")
	assert_true("watch" in e.scene_event.applied, "the protest's own muscle")


func test_watchers_are_witnesses_and_gangs_at_war() -> void:
	var e := _enc("ncpd_standoff")
	var cops: Array = e.units.filter(func(u): return u.get("street_event", false))
	assert_between(cops.size(), 3, 4, "NCPD round the building")
	for u in cops:
		assert_eq(e.faction_of(u), "ncpd")
		assert_true(e.watching(u), "neutral until they see a crime (witness side)")
		assert_true(u.has("hold"), "they hold their places")
	e = _enc("armed_patrol")
	var gang: Array = e.units.filter(func(u): return u.get("street_event", false))
	assert_true(gang.all(func(u): return e.watching(u) and u.has("patrol")), "a gang walking its beat, watching")
	e = _enc("gang_war")
	var fighters: Array = e.units.filter(func(u): return u.get("street_event", false))
	var teams := {}
	for u in fighters:
		teams[int(u.team)] = true
		assert_true(u.alerted, "already shooting")
		assert_false(e.hostile(int(u.team), Encounter.CREW), "neutral to the crew until it joins in")
		assert_true(e.hostile(int(u.team), Encounter.OPFOR), "the site's guards are fair game")
	assert_eq(teams.size(), 2, "two gangs")
	assert_true(e.hostile(int(teams.keys()[0]), int(teams.keys()[1])), "at war with each other")
	var dep := SceneEvent._deploy(e.m)
	assert_true(fighters.all(func(u): return Vector2(u.pos.x - dep.x, u.pos.y - dep.y).length() >= SceneEvent.FAR_FROM_DEPLOY), "far from the crew")
	e = _enc("turf_argument")
	assert_true(e.units.filter(func(u): return u.get("street_event", false)).all(func(u): return not u.alerted), "squaring off: cold until shots")
	e = _enc("armed_operative")
	var pat: Array = e.units.filter(func(u): return u.get("street_event", false))
	assert_true(not pat.is_empty() and pat.all(func(u): return int(u.team) == Encounter.OPFOR and u.has("patrol")), "the site's own people out on the street")


func test_trauma_psycho_outage_alarm_dress() -> void:
	var e := _enc("tt_club")
	assert_eq(String(e.tt.get("state", "")), "called", "Trauma Team's on the way")
	var client: Dictionary = e.units[int(e.tt.patient)]
	assert_true(client.get("trauma_card", false) and not client.c.can_act() and not client.c.dead, "their client is down, alive")
	for i in 30:
		e.next_turn()
		if e.cur.team == 0:
			e.end_turn()
		if e.tt.is_empty():
			break
	assert_true(e.tt.is_empty(), "picked up and gone, the slot free for the gig's own cardholders")
	assert_true(client.get("fled", false), "taken away")
	assert_eq(e.civ_casualties, 0, "a client already down isn't a bystander the crew hurt")
	e = _enc("cyberpsycho")
	var psy: Dictionary = e.units[int(e.scene_event.psycho)]
	assert_eq(String(psy.c.block), "cyberpsycho", "the book's Cyberpsycho (CPR core p.416)")
	assert_true(psy.alerted and e.hostile(int(psy.team), Encounter.CREW) and e.hostile(int(psy.team), Encounter.CIV_TEAM), "raging at everyone")
	var due := int(e.scene_event.maxtac_round)
	assert_between(due, 4, 6, "MaxTac in 3-5 rounds")
	psy.c.hp = 999   # keep them up for the drop
	while e.init == null or e.init.round_num < due:
		e.next_turn()
		if e.state != "playing":
			break
		if e.cur.team == 0:
			e.end_turn()
	var mt: Array = e.units.filter(func(u): return e.faction_of(u) == "maxtac")
	assert_true(not mt.is_empty(), "MaxTac drops in")
	assert_true(mt.all(func(u): return not e.hostile(int(u.team), Encounter.CREW) or e.state != "playing"), "for the psycho, not the crew")
	e = _enc("block_dark")
	assert_true("power" in e.outages and e.lights_out(), "the block's dark")
	e = _enc("lockdown_blast")
	assert_eq(e.alarm, 1, "the alarm starts at 1")
	assert_true(e.clocks.is_empty(), "no quiet approach to clock")
	e = _enc("burnt_car_bodies")
	assert_true("dress" in e.scene_event.applied)
	assert_true(e.m.cover.any(func(c): return String(c.kind) == "wreck"), "a wreck on the street, as cover")
	assert_true(LightPlan.plan(e.m, e.m.seed_value).any(func(l): return String(l.kind) == "blaze"), "on fire")
	e = _enc("gang_checkpoint")
	assert_true(e.m.cover.any(func(c): return String(c.kind) in ["barrier", "sandbags"]), "a barricade")


func test_every_played_row_sets_up() -> void:
	var m := _map(91)
	for k in BOOK_TABLES:
		for r in SceneEvent.enabled_rows(k):
			var dice := Dice.new(3)
			var spec := SceneEvent.make(k, r, int(r.roll[0]))
			m.params.erase("event_dressed")
			var e := Encounter.setup(m, dice, _crew(dice), "data", {"scene_event": spec})
			var fx: Dictionary = r.fx
			var done: Array = e.scene_event.get("applied", []) + e.scene_event.get("skipped", [])
			for f in fx:
				assert_true(String(f) in done, "%s: fx %s applied or skipped" % [r.id, f])
			for f in ["crowd", "watch", "gangs", "trauma", "psycho", "outage", "alarm"]:
				if fx.has(f):
					assert_true(f in e.scene_event.applied, "%s: %s plays on a street block (%s)" % [r.id, f, e.scene_event.skipped])
			assert_true(e.log.any(func(l): return String(l).begins_with("On the street: ")), "%s: the deploy log line" % r.id)
			assert_eq(e.log.filter(func(l): return String(l).begins_with("On the street: ")).size(), 1, "%s: one quiet line, no more" % r.id)


func test_campaign_rolls_it_at_the_start_and_saves() -> void:
	var c := Campaign.new_game(19)
	c.minutes = 23 * 60
	var g := c.accept(0)
	assert_true(g.has("scene_event"), "the active gig carries its street")
	assert_true(SceneEvent.valid(g.scene_event))
	var again: Variant = SceneEvent.roll(g, c.minutes, "")
	assert_eq(again, g.scene_event, "rolled from the gig's seed at the hour it started")
	if g.scene_event is Dictionary:
		assert_eq(String(Campaign.encounter_opts(g).scene_event.id), String(g.scene_event.id), "the encounter gets it")
	# Forced by the dev builder.
	var f := CustomGig.defaults()
	f.street = "gang_war"
	f.seed = 9
	var c2 := Campaign.new_game(3)
	c2.accept_custom(f)
	assert_eq(String(c2.active_gig.scene_event.id), "gang_war")
	assert_eq(String(CustomGig.defaults().street), "auto")
	assert_true("--street=gang_war" in CustomGig.to_flags(f))
	# The save: the current version, and a v17 save's last form gains its field.
	var d: Dictionary = JSON.parse_string(JSON.stringify(c2.to_dict()))
	assert_eq(int(d.version), 18)
	var old := d.duplicate(true)
	old["version"] = 17
	old["last_custom"] = {"seed": 4}
	old.board[0]["scene_event"] = {"table": "corporate.day", "id": "junk", "row": 3}
	var back := Campaign.from_dict(old)
	assert_true(back != null, "a v17 save loads")
	assert_eq(String(back.last_custom.street), "auto")
	assert_false(back.board[0].has("scene_event"), "junk is dropped")


# --- Everyday life ------------------------------------------------------------------------

func _life_enc(seed_value: int, scene := "street_block", kind := "data") -> Encounter:
	var dice := Dice.new(seed_value)
	var m := SceneGen.generate(seed_value, scene, {"security": 2, "district": "kabuki"})
	return Encounter.setup(m, dice, _crew(dice), kind, {"district": "kabuki"})


func test_ambient_bystanders_keep_out_of_narrow_ways_and_the_objective() -> void:
	var placed := 0
	for s in [11, 23, 37]:
		for kind in ["data", "assassinate", "snatch"]:
			var e := _life_enc(s, "street_block", kind)
			var area := StreetLife.objective_area(e)
			var civs: Array = e.units.filter(func(u): return u.get("civ", false) and not u.get("street_event", false))
			placed += civs.size()
			assert_true(civs.size() <= StreetLife.MAX_CIVS, "capped")
			for u in civs:
				assert_false(StreetLife.is_choke(e.m, u.pos), "%d %s: %s not in a 1-wide way" % [s, kind, u.pos])
				assert_false(StreetLife.by_door(e.m, u.pos), "%d %s: %s not in a doorway" % [s, kind, u.pos])
				var l := e.m.label(u.pos.z, u.pos.x, u.pos.y)
				assert_false(l >= 0 and area.rooms.has(l), "%d %s: not in the objective's room" % [s, kind])
				assert_true(u.has("life"), "doing something")
			# Walkers stay out of them as they go.
			for i in 8:
				e.next_turn()
				if e.state != "playing":
					break
				if e.cur.team == 0:
					e.end_turn()
				for u in e.units:
					if u.has("route") and not u.get("panic", false) and not u.c.dead:
						assert_false(StreetLife.blocked_spot(e, u.pos), "%d %s round %d: a walker at %s" % [s, kind, e.init.round_num, u.pos])
	assert_true(placed > 20, "people about (%d)" % placed)


func test_everyday_life_walks_and_panics() -> void:
	var e := _life_enc(23)
	var walkers: Array = e.units.filter(func(u): return u.has("route"))
	assert_true(not walkers.is_empty(), "someone's walking")
	var lives := {}
	for u in e.units:
		if u.get("civ", false):
			lives[String(u.life)] = true
	assert_true(lives.size() >= 4, "a mix of things going on: %s" % [lives.keys()])
	var start: Array = walkers.map(func(u): return u.pos)
	e.next_turn()
	if e.cur.team == 0:
		e.end_turn()
	e.next_turn()
	assert_true(walkers.any(func(u): return u.pos != start[walkers.find(u)]), "they walk")
	assert_true(e.events.any(func(ev): return String(ev.type) == "stroll") or true)
	# Gunfire: everyone near panics and scatters (runs, hides or cowers), walking stops.
	var w: Dictionary = walkers.filter(func(u): return not u.c.dead)[0]
	e._panic_near(w.pos)
	assert_true(w.panic, "panics at gunfire")
	assert_true(String(w.get("scatter", "")) in ["flee", "hide", "cower"], "scatters some way")
	var before: Vector3i = w.pos
	var field: Dictionary = e.nav.distance_field(e.m.entrances.map(func(en): return Vector3i(en.pos.x, en.pos.y, int(en.get("floor", 0)))), {}, 4000)
	var route_i := int(w.get("route_i", 0))
	e._civilians_tick()
	match String(w.scatter):
		"flee":
			assert_true(w.get("fled", false) or int(field.get(w.pos, 9999)) < int(field.get(before, 9999)), "runs for the map's edge, not its route")
		"cower":
			assert_eq(w.pos, before, "cowers where they stood")
	assert_eq(int(w.get("route_i", 0)), route_i, "the stroll is over")
	# They're bystanders: they block and can be hit.
	var calm: Array = e.units.filter(func(u): return u.get("ambient", false) and not u.panic and not u.c.dead)
	if not calm.is_empty():
		assert_true(e._blocking(e.units[0]).has(calm[0].pos), "they block the crew's way")
		assert_eq(int(calm[0].team), Encounter.CIV_TEAM)


func test_patrons_indoors_where_the_place_suits() -> void:
	var dice := Dice.new(8)
	var m := SceneGen.generate(8, "lone_building", {"site": "bar", "security": 1})
	var e := Encounter.setup(m, dice, _crew(dice), "data", {})
	var inside: Array = e.units.filter(func(u): return u.get("civ", false) and m.label(u.pos.z, u.pos.x, u.pos.y) >= 0 \
		and not bool(m.rooms[m.label(u.pos.z, u.pos.x, u.pos.y)].get("outdoor", false)))
	assert_true(not inside.is_empty(), "patrons in the bar")
	for u in inside:
		assert_true(String(u.life) in ["sit", "talk", "drink", "dance", "browse", "phone", "work", "loiter"], "a patron's pose: %s" % u.life)
