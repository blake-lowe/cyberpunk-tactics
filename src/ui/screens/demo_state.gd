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
		var r := Recruit.generate(dice, role, "edgerunner")
		r.look_seed = c.crew.size()
		c.crew.append(r)
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
	# Night Market with cyberware on sale (the first roll that has it)
	for s in range(1, 200):
		var m := NightMarket.roll(Dice.new(s), c.day)
		if "cyberware" in m.categories and "weapons_armor" in m.categories:
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
	return c


## A sample debrief report (Campaign.resolve's shape) for the demo crew.
static func report(c: Campaign) -> Dictionary:
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
	return {"won": true, "gig": {"title": "Retire a Biotechnica manager", "fixer": "Mr. Blue", "security": 2}, "pay": 1500, "ip": 30,
		"reputation": {a.display_name: 3}, "dead": ["Wraith"], "hurt": [], "episodes": [], "kit_used": ["Flashbang"], "addicted": [], "members": members}
