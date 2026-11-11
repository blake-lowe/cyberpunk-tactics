class_name DemoState
extends RefCounted
## DEV ONLY (review screenshots, `--demo`): a campaign with something on every screen: a full crew,
## injuries, an addiction, lost Humanity, chrome, ablated armor under repair, storage, a Night
## Market with cyberware, a fallen crew member and a debrief. Marked with the "demo" meta so the
## screens never save it over the player's campaign.


static func make() -> Campaign:
	var c := Campaign.new_game(77)
	c.set_meta("demo", true)
	c.eb = 4250
	c.day = 12
	var dice := Dice.new(5)
	for role in ["medtech", "tech"]:
		c.crew.append(Recruit.generate(dice, role, "edgerunner", "", c.names_taken(), c.crew.size()))
	var a: Combatant = c.crew[0]
	var b: Combatant = c.crew[1]
	a.ip = 140
	a.reputation = 3
	b.ip = 65
	b.reputation = 1
	c.crew[2].ip = 30
	c.crew[3].ip = 30
	var crits: Dictionary = RulesDB.load_json("critical_injuries.json")
	a.add_injury(crits.body["6"], "body", false)   # Broken Arm
	c.crew[2].add_injury(crits.head["5"], "head", false)   # Concussion
	a.hp = maxi(1, a.max_hp() / 2 - 2)
	c.crew[2].hp = maxi(1, c.crew[2].max_hp() - 6)
	b.addictions.append("synthcoke")
	a.lose_humanity(mini(8, a.humanity / 4))   # a little lost Humanity for the therapy screen
	var body: ArmorPiece = a.armor.get("body")
	if body:
		body.sp = maxi(0, body.max_sp - 3)
		body.repair_work = 10
	# Night Market with cyberware on sale (the first roll that has it); --market=electronics: one
	# selling Personal Electronics with its Programs rows (netrunning review shots)
	var want := ["cyberware", "weapons_armor"]
	if "--market=electronics" in OS.get_cmdline_user_args():
		want = ["electronics"]
	for s in range(1, 400):
		var m := NightMarket.roll(Dice.new(s), c.day)
		if want.all(func(w): return w in m.categories) and (want.size() > 1 or m.listings.any(func(l): return String(l.name).begins_with("Programs") or String(l.name) == "Cyberdeck")):
			c.market = m
			break
	# storage
	var staples := NightMarket.staples()
	var picked := {"weapon": 2, "armor": 1}
	for k in staples:
		var sec := Items.section(k)
		if int(picked.get(sec, 0)) > 0:
			c.stash[k] = 1
			picked[sec] = int(picked[sec]) - 1
	var cons := staples.filter(func(k): return Items.fits(0, k))
	var util := staples.filter(func(k): return Items.fits(1, k))
	for k in cons.slice(0, 3):
		c.stash[k] = 2
	for k in util.slice(0, 1):
		c.stash[k] = 1
	if not cons.is_empty():
		a.kit[0] = cons[0]
	if not util.is_empty():
		b.kit[1] = util[0]
	# cyberware bought at the market, waiting in storage for the Med Bay
	for k in NightMarket.keys_of(c.market).filter(func(k): return Items.is_cyberware(k)).slice(0, 3):
		c.stash[k] = 1
	c.fallen.append({"name": "Wraith", "role": "solo", "day": 9, "gig": "Retire a Biotechnica manager"})
	for line in ["Rested 2 days.", "Bought %s" % Items.display_name(cons[0]) if not cons.is_empty() else "Bought gear", "Bought %s" % Items.display_name(cons[0]) if not cons.is_empty() else "Bought gear"]:
		c.say(line)
	c.debrief.assign(report(c).members)
	# The board as a crew with a name gets it, showing each kind of payment (MissionBuilder) and
	# a fixer's intel on every offer (Campaign.foresee).
	c.refresh_board()
	var ordinary := c.board.filter(func(g): return not g.get("unique", false))
	var kinds := ["goods", "favour:treatment", "information"]
	for i in mini(kinds.size(), ordinary.size()):
		var g: Dictionary = ordinary[i]
		g["pay"] = int((g.get("payment", {}) as Dictionary).get("base", g.get("pay", 0)))
		MissionBuilder.payment_step(dice, g, String(kinds[i]), func(v: int) -> Array: return c.goods_pool(v))
	c.intel = 1
	c.foresee()
	for l in report(c).leads:   # the sample debrief's leads, kept in storage
		c.leads.append(l)
	return c


## A sample debrief report (Campaign.resolve's shape) for the demo crew. `objective` (review shots:
## base --screen=debrief --objective=<id>): the sample gig plays that objective instead, its first
## Mission Types row and a focus item fitting it, so its debrief line shows.
static func report(c: Campaign, objective := "") -> Dictionary:
	var a: Combatant = c.crew[0]
	var b: Combatant = c.crew[1]
	var members: Array[Dictionary] = []
	members.append({"name": a.display_name, "role": a.role, "look_seed": a.look_seed, "dead": false, "ip": 30, "reputation": 3,
		"injuries": ["Broken Arm"], "wound": Campaign.WOUND_NAMES[a.wound_state()], "hp": a.hp, "max_hp": a.max_hp(),
		"kit": ["Flashbang"], "addicted": [], "episode": false, "humanity_lost": 0})
	members.append({"name": b.display_name, "role": b.role, "look_seed": b.look_seed, "dead": false, "ip": 30, "reputation": 0,
		"injuries": [], "wound": "Unhurt", "hp": b.max_hp(), "max_hp": b.max_hp(), "kit": [], "addicted": ["Synthcoke"], "episode": false, "humanity_lost": 2})
	members.append({"name": c.crew[2].display_name, "role": c.crew[2].role, "look_seed": 2, "dead": false, "ip": 30, "reputation": 0,
		"injuries": ["Concussion"], "wound": Campaign.WOUND_NAMES[c.crew[2].wound_state()], "hp": c.crew[2].hp, "max_hp": c.crew[2].max_hp(),
		"kit": [], "addicted": [], "episode": false, "humanity_lost": 0})
	members.append({"name": "Wraith", "role": "solo", "look_seed": 9, "dead": true, "ip": 0, "reputation": 0, "injuries": [], "wound": "Dead",
		"hp": 0, "max_hp": 40, "kit": ["Smoke Grenade"], "lost": ["Assault Rifle", "Heavy Pistol", "Light Armorjack", "Wolvers", "Smoke Grenade"],
		"addicted": [], "episode": false, "humanity_lost": 0})
	# A Mission Builder gig paid partly in a favour (SPM p.28 step 4).
	var gig := {"title": "Wetwork: Biotechnica Plaza", "fixer": "Mr. Blue", "security": 2, "kind": "assassination",
		"client": {"zone": "corporate", "roll": 9, "id": "corp_spy", "label": "a corporate spy"},
		"mission": {"roll": 99, "id": "wetwork", "label": "Wetwork", "objective": "assassinate"},
		"focus": {"category": "corporate", "roll": 1, "id": "key_exec", "label": "a key exec", "short": "key exec", "marker": "KEY EXEC", "as": ["captive", "mark"]},
		"payment": {"type": "favour", "base": 2000, "eb": 1500, "kind": "treatment"},
		"twist": {"row": 77, "roll": 78, "id": "target_fights_back", "label": "Mark Hits Back", "trigger": {"on": "alarm", "or_round": 6}}}
	var rows := MissionBuilder.rows_for(objective) if objective != "" else []
	if not rows.is_empty():
		var mt: Dictionary = rows[0]
		gig.kind = MissionBuilder.kind_of(mt)
		gig.mission = {"roll": int(mt.roll[0]), "id": String(mt.id), "label": String(mt.label), "objective": objective}
		gig.focus = MissionBuilder.roll_focus(Dice.new(3), "corporate", objective)
		gig.title = "%s: Biotechnica Plaza" % String(mt.label)
	var loot: Array = [
		{"label": "loaded credstick", "text": "loaded credstick · 500eb", "kind": "eb", "by": a.display_name, "from": "Guard 2", "keys": []},
		{"label": "stripped-down VH pistol", "text": "stripped-down VH pistol: Very Heavy Pistol", "kind": "item", "by": b.display_name, "from": "Lieutenant 1", "keys": ["weapon/very_heavy_pistol"]},
		{"label": "bottle of Synthcoke", "text": "bottle of Synthcoke: Synthcoke x3", "kind": "item", "by": a.display_name, "from": "Guard 4", "keys": ["drugs/synthcoke"]},
		{"label": "heist plans chip", "text": "heist plans chip", "kind": "lead", "by": b.display_name, "from": "Lieutenant 1", "keys": []},
		{"label": "Night Market invite", "text": "Night Market invite", "kind": "lead", "by": a.display_name, "from": "Guard 1", "keys": []}]
	return {"won": true, "gig": gig, "pay": 1500, "ip": 30, "payment": gig.payment, "paid_extra": MissionBuilder.payment_extra(gig.payment),
		"focus_line": MissionBuilder.debrief_line(gig, true), "client": MissionBuilder.client_text(gig),
		"twist": {"id": "target_fights_back", "row": 77, "label": "Mark Hits Back", "note": "the target is far tougher than briefed",
			"text": "Mara Voss fights like a Lieutenant.", "round": 4},
		"reputation": {a.display_name: 3}, "dead": ["Wraith"], "hurt": [], "episodes": [], "kit_used": ["Flashbang"], "addicted": [], "members": members,
		"loot": loot, "loot_eb": 500, "loot_lost": 1, "surrendered": 2, "fled": 1,
		"leads": loot.filter(func(f): return f.kind == "lead").map(func(f): return {"label": f.label, "hook": "heist" if String(f.label).contains("heist") else "night_market", "day": 9, "gig": String(gig.title)})}
