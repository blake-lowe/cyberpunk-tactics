extends TestCase
## Names, handles and the people of Night City (src/meta/names.gd, people.gd; data/gen/names.json,
## handles.json, name_filter.json, people.json).


func test_the_generator_is_deterministic_per_seed() -> void:
	for s in [1, 7, 99, 4242]:
		assert_eq(Names.person(Dice.new(s)), Names.person(Dice.new(s)), "seed %d: the same person" % s)
		assert_eq(Names.handle(Dice.new(s), "Rosa"), Names.handle(Dice.new(s), "Rosa"), "seed %d: the same handle" % s)
		var a := Recruit.generate(Dice.new(s), "solo")
		var b := Recruit.generate(Dice.new(s), "solo")
		assert_eq([a.display_name, a.real_name], [b.display_name, b.real_name], "seed %d: the same recruit" % s)
	var c1 := Campaign.new_game(31)
	var c2 := Campaign.new_game(31)
	assert_eq((c1.crew + c1.recruits).map(func(c): return c.display_name + "/" + c.real_name),
		(c2.crew + c2.recruits).map(func(c): return c.display_name + "/" + c.real_name), "a campaign seed gives the same people")
	var seen := {}
	for s in range(1, 41):
		seen[Names.full_name(Dice.new(s))] = true
	assert_true(seen.size() >= 38, "different seeds, different people (%d of 40)" % seen.size())


func test_naming_keeps_the_rest_of_a_recruit_s_rolls() -> void:
	# naming draws one number from the dice where the old handle list drew one die: the same stats
	var d := Dice.new(12)
	var r := Recruit.generate(d, "netrunner")
	var d2 := Dice.new(12)
	var fixed := Recruit.generate(d2, "netrunner", "edgerunner", "Patch")
	assert_eq(r.stats, fixed.stats, "the handle draw comes after the stats")
	assert_eq(fixed.display_name, "Patch")
	assert_true(Names.is_person_name(fixed.real_name), "a fixed handle still gets a real name (%s)" % fixed.real_name)


func test_no_empty_or_duplicate_names_in_a_crew() -> void:
	for s in range(1, 26):
		var c := Campaign.new_game(s)
		for day in 3:
			c.day += 1
			c.refresh_recruits()
			var people: Array = c.crew + c.recruits
			var handles := {}
			var names := {}
			for p in people:
				assert_true(String(p.display_name).strip_edges() != "", "seed %d: a handle" % s)
				assert_true(Names.is_person_name(p.real_name), "seed %d: a real name (%s)" % [s, p.real_name])
				assert_false(handles.has(p.display_name), "seed %d: handle %s used once" % [s, p.display_name])
				assert_false(names.has(p.real_name), "seed %d: name %s used once" % [s, p.real_name])
				handles[p.display_name] = true
				names[p.real_name] = true
	# taken names are rolled again
	var taken: Array = []
	for i in 30:
		var h := Names.handle(Dice.new(5), "", taken)
		assert_false(h in taken, "%s is new" % h)
		taken.append(h)


func test_the_filter_blocks_bad_words() -> void:
	for bad in ["shit", "Fuck", "CUNT", "Bitch Hound", "Asshole", "Wetback", "Retard", "Faggot", "Nazi", "Fück", "Shit-Fox"]:
		assert_false(Names.is_clean(bad), "%s is blocked" % bad)
	for bad in ["Shitfox", "Neonfuck", "Cuntjaw"]:
		assert_false(Names.is_clean(bad, true), "%s: a handle compound holding one is blocked" % bad)
	for ok in ["Cassandra Dickens", "Scunthorpe", "Rosa Hancock", "Kenji Sato", "Glass Jaw", "Torque"]:
		assert_true(Names.is_clean(ok), "%s is fine" % ok)
	assert_true(Names.is_reserved("Johnny Silverhand") and Names.is_reserved("grease") and Names.is_reserved("Rex Royale"), "canon handles are reserved")
	assert_true(Names.is_famous("Michael Jordan") and Names.is_famous("maroon-5") and Names.is_famous("Kevlar"), "famous names and brands")
	assert_false(Names.is_famous("Michael Okafor"))


func test_every_generated_name_and_handle_passes_the_filter() -> void:
	var patterns := {}
	for s in range(1, 401):
		var d := Dice.new(s)
		var p := Names.person(d)
		assert_true(Names.is_clean(p.full) and not Names.is_famous(p.full), "%s" % p.full)
		var h := Names.handle(d, String(p.given))
		assert_true(h.strip_edges() != "" and Names.is_clean(h, true) and not Names.is_reserved(h) and not Names.is_famous(h), "handle %s" % h)
		patterns[h] = true
	assert_true(patterns.size() >= 330, "handles vary (%d distinct of 400)" % patterns.size())
	# every word in the data passes too (the builder filtered them)
	for pool in Names.handles_data().words:
		for w in Names.handles_data().words[pool].list:
			assert_true(Names.is_clean(String(w), true), "%s: %s" % [pool, w])
	for w in Names.handles_data().curated:
		assert_true(Names.is_clean(String(w), true) and not Names.is_reserved(String(w)), "curated %s" % w)


func test_list_sizes_and_cultures() -> void:
	var given := {}
	var family := {}
	var nd := Names.names_data()
	assert_true(nd.cultures.size() >= 10, "Night City's mix (%d cultures)" % nd.cultures.size())
	var total_w := 0.0
	for cid in nd.cultures:
		var c: Dictionary = nd.cultures[cid]
		total_w += float(c.weight)
		for g in ["masc", "femme"]:
			assert_true((c.given[g] as Array).size() >= 20, "%s: %s given names (%d)" % [cid, g, (c.given[g] as Array).size()])
		for g in c.given:
			for n in c.given[g]:
				given[n] = true
		for k in ["family", "family_masc", "family_femme"]:
			for n in c.get(k, []):
				family[n] = true
		assert_true((c.get("family", []) as Array).size() + (c.get("family_masc", []) as Array).size() >= 20, "%s: family names" % cid)
	assert_true(given.size() >= 2000, "a few thousand given names (%d)" % given.size())
	assert_true(family.size() >= 2000, "a few thousand family names (%d)" % family.size())
	var words := 0
	for pool in Names.handles_data().words:
		words += (Names.handles_data().words[pool].list as Array).size()
	assert_true(words >= 900, "handle words (%d)" % words)
	assert_true((Names.handles_data().curated as Array).size() >= 300, "curated handles")
	# every culture comes up in proportion to its weight
	var counts := {}
	var d := Dice.new(3)
	for i in 3000:
		var c := Names.roll_culture(d)
		counts[c] = int(counts.get(c, 0)) + 1
	for cid in nd.cultures:
		var want := 3000.0 * float(nd.cultures[cid].weight) / total_w
		assert_between(float(counts.get(cid, 0)), want * 0.6 - 10.0, want * 1.4 + 10.0, "%s's share" % cid)


func test_gendered_surnames_fit() -> void:
	var c: Dictionary = Names.names_data().cultures.eastern_european
	assert_false((c.family_femme as Array).is_empty() or (c.family_masc as Array).is_empty(), "Slavic surnames have both forms")
	var d := Dice.new(8)
	for i in 200:
		assert_false(String(Names.family_name(d, "masc", "eastern_european")) in c.family_femme, "a man gets no -ova name")
		assert_false(String(Names.family_name(d, "femme", "eastern_european")) in c.family_masc, "a woman gets no -ov name")


func test_a_recruit_s_name_fits_their_body() -> void:
	var nd := Names.names_data()
	var masc := {}
	var femme := {}
	for cid in nd.cultures:
		for n in nd.cultures[cid].given.masc:
			masc[n] = true
		for n in nd.cultures[cid].given.femme:
			femme[n] = true
	var wrong := 0
	for look in 120:
		var r := Recruit.generate(Dice.new(look + 1), "solo", "edgerunner", "", [], look)
		assert_eq(r.look_seed, look)
		var given := r.real_name.split(" ")[0]
		var body := Recruit.body_of(look)
		if (body == "male" and femme.has(given) and not masc.has(given)) or (body == "female" and masc.has(given) and not femme.has(given)):
			wrong += 1
	assert_true(wrong <= 12, "a name that fits the body, bar the odd nonbinary pick (%d of 120)" % wrong)


func test_real_names_save_and_old_saves_load() -> void:
	var r := Recruit.generate(Dice.new(4), "tech")
	var back := Combatant.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	assert_eq(back.real_name, r.real_name)
	assert_eq(back.display_name, r.display_name)
	var old := r.to_dict()
	old.erase("real_name")   # a save from before names
	assert_eq(Combatant.from_dict(old).real_name, "", "an old save keeps its recruit as they were")
	assert_eq(Combatant.from_dict(old).display_name, r.display_name)


func test_every_data_file_has_provenance() -> void:
	for f in ["names.json", "handles.json", "name_filter.json", "people.json"]:
		var d := RulesDB.gen(f)
		assert_true(d.has("_provenance") and str(d._provenance) != "", "%s has provenance" % f)
	var readme := FileAccess.get_file_as_string("res://assets/third_party/names/README.md")
	for must in ["CC0", "public domain", "CC BY 4.0", "Wikidata", "Census", "corpora", "LDNOOBW", "SPM"]:
		assert_true(readme.contains(must), "the third-party note covers %s" % must)
	assert_true(FileAccess.file_exists("res://assets/third_party/names/LICENSE-ldnoobw-cc-by-4.0.txt"), "the CC BY licence travels with the list")
	for pool in Names.handles_data().words:
		assert_true(String(Names.handles_data().words[pool].get("source", "")) != "", "%s: a source" % pool)


func test_the_objectives_use_the_generator() -> void:
	var cfg: Dictionary = RulesDB.gen("objectives.json")
	for kind in ["assassinate", "rescue"]:
		assert_false(cfg[kind].has("names"), "%s: no fixed name list" % kind)
		assert_true(String(cfg[kind].get("name_gen", "")).contains("Names"), "%s: names from the generator" % kind)
	var script := load("res://src/tactical/objectives/assassinate.gd") as GDScript
	var seen := {}
	for s in range(1, 21):
		var n: String = script.mark_name(Dice.new(s), cfg.assassinate)
		assert_true(Names.is_person_name(n), "a mark: %s" % n)
		assert_eq(n, script.mark_name(Dice.new(s), cfg.assassinate), "the same seed, the same mark")
		seen[n] = true
	assert_true(seen.size() >= 18, "marks vary")


# --- People of Night City (SPM p.50-51) ---------------------------------------------------------

func test_people_tables_cover_their_dice() -> void:
	var zone_cover := {}
	for z in People.zones():
		var zd: Dictionary = People.data().zones[z]
		for r in range(int(zd.zone_roll[0]), int(zd.zone_roll[1]) + 1):
			zone_cover[r] = z
		assert_true(String(zd.cite).begins_with("SPM p.5"), "%s cited" % z)
		var lo := 2 if String(zd.die) == "2d10" else 1
		var hi := 20 if String(zd.die) == "2d10" else 10
		for r in range(lo, hi + 1):
			var hits := (zd.types as Array).filter(func(t): return r >= int(t.roll[0]) and r <= int(t.roll[1]))
			assert_eq(hits.size(), 1, "%s: roll %d has one type" % [z, r])
		for t in zd.types:
			assert_true(String(t.label) != "" and String(t.id) != "" and String(t.kind) != "", "%s.%s" % [z, t.get("id", "?")])
	assert_eq(zone_cover.size(), 10, "the zone d10 is covered")


func test_people_roll() -> void:
	var zones := {}
	var d := Dice.new(6)
	for i in 400:
		var p := People.roll(d)
		assert_false(p.is_empty())
		zones[p.zone] = int(zones.get(p.zone, 0)) + 1
	assert_eq(zones.size(), 4, "every zone comes up")
	assert_true(int(zones.street) > int(zones.outskirts), "3 in 10 street, 1 in 10 outskirts")
	for i in 30:
		assert_eq(String(People.roll(d, "corporate").zone), "corporate", "a fixed zone")
	assert_eq(People.roll(Dice.new(11)), People.roll(Dice.new(11)), "deterministic")
