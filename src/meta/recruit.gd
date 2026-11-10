class_name Recruit
extends RefCounted
## Procedural edgerunners for the recruit pool, built with the book's creation methods (p73-90):
## - "streetrat": one d10 row from the Role's STAT table, fixed skill levels.
## - "edgerunner": d10 per STAT column, 86 skill points over the Role's 20 skills (min 2, max 6,
##   x2 skills cost double), weighted toward Role skills.
## Both start at Role Rank 4 with the Role's starting cyberware at flat Humanity Loss (p111, p117).

const EDGERUNNER_SKILL_POINTS := 86  # p88
const ROLE_SKILL_WEIGHT := 3

## Starting kit. HOUSE-RULE: the book's per-Role gear lists (p98-103) are pared down to the
## tactical essentials; full lists come with the inventory system.
const LOADOUT := {
	"solo": ["assault_rifle", "heavy_pistol"],
	"netrunner": ["heavy_pistol"],
	"medtech": ["shotgun"],
	"tech": ["shotgun", "heavy_pistol"],
	"rockerboy": ["heavy_pistol", "medium_melee"],
	"media": ["heavy_pistol"],
	"lawman": ["assault_rifle", "heavy_pistol"],
	"exec": ["heavy_pistol"],
	"fixer": ["heavy_pistol"],
	"nomad": ["shotgun", "heavy_melee"],
}

## The share of bodies drawn female (CharModel's look roll, body_of). HOUSE-RULE.
const FEMALE_BODY := 0.45
## A recruit's name given their body (Names.GENDERS): HOUSE-RULE, mostly the matching list, now and
## then nonbinary.
const NAME_GENDER := {"female": {"femme": 0.88, "nonbinary": 0.12}, "male": {"masc": 0.88, "nonbinary": 0.12}}


## A recruit of `role` built by `method`, with a real name (Combatant.real_name) and a street
## handle (Names, data/gen/names.json and handles.json). `handle` fixes the handle; `taken` lists
## names and handles already in use (the crew and the other recruits: none is repeated); `look` is
## their look seed (Combatant.look_seed: their body, so the name fits it; -1 leaves it unset).
## Naming draws one number from `dice` for its own sub-roll (Names.sub_dice), as the old fixed
## handle list drew one die, so the rest of the build rolls as before; with a fixed `handle` it
## draws none (the name is seeded from the dice's state).
static func generate(dice: Dice, role: String, method: String = "edgerunner", handle: String = "", taken: Array = [], look := -1) -> Combatant:
	var rd: Dictionary = RulesDB.load_json("roles.json")["roles"][role]
	var rows: Array = rd["stat_rows"]
	var stats := {}
	if method == "streetrat":
		stats = (rows[dice.d(10) - 1] as Dictionary).duplicate()
	else:
		for s in rows[0]:
			stats[s] = int(rows[dice.d(10) - 1][s])
	var skills: Dictionary = (rd["skills"] as Dictionary).duplicate() if method == "streetrat" else _edgerunner_skills(dice, rd)
	for s in skills:
		skills[s] = int(skills[s])

	var nd: Dice   # naming: where the old handle roll was, so the rolls after it are unchanged
	if handle == "":
		nd = Names.sub_dice(dice)
	else:
		var hs := hash([dice.rng.state, handle, role])
		nd = Dice.new(hs if hs != 0 else 1)
	var gender := Names.pick_weighted(nd, NAME_GENDER[body_of(look)]) if look >= 0 else Names.roll_gender(nd)
	var who := Names.person(nd, gender, "", taken)
	if handle == "":
		handle = Names.handle(nd, String(who.given), taken)
	var c := Combatant.new(handle, stats, skills)
	c.real_name = String(who.full)
	if look >= 0:
		c.look_seed = look
	c.role = role
	c.role_rank = 4  # p142
	if role == "netrunner":   # starting deck Programs (p98: Armor, Sword, and one more; ours: those two)
		c.programs.assign(["sword", "armor"])
	if role == "tech":   # Rank 4 = 8 Specialty ranks (p147): HOUSE-RULE split for the game's uses
		c.maker = {"field": 3, "upgrade": 3, "fabrication": 2, "invention": 0}
	if role == "medtech":   # Rank 4 = 4 Specialty points (p149): HOUSE-RULE split, 2 Surgery / 2 Pharmaceuticals
		c.medicine = {"surgery": 2, "pharma": 2, "cryo": 0}
	c.init_humanity()
	for w in LOADOUT.get(role, []):   # guns first: weapons[0] is the primary
		c.weapons.append(Weapon.from_id(w))
	var chrome: Array = []
	for choice in rd["cyberware"]:   # the Role's list names options before their foundation at times
		chrome.append(choice[dice.d(choice.size()) - 1])
	for cid in Cyber.foundations_first(chrome):
		c.install_cyberware(cid, dice, true)
	c.hp = c.max_hp()
	c.armor["body"] = ArmorPiece.from_id("light_armorjack")  # p98
	c.armor["head"] = ArmorPiece.from_id("light_armorjack")
	if role == "solo":
		_default_awareness(c)
	return c


## The body a crew member's look seed gives them on team `team` ("female" or "male"): the roll
## CharModel makes for their model, here so a recruit's name can fit it.
static func body_of(look: int, team := 0) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(look * 131 + team * 7 + 3)
	return "female" if rng.randf() < FEMALE_BODY else "male"


static func _edgerunner_skills(dice: Dice, rd: Dictionary) -> Dictionary:
	var role_skills: Dictionary = rd["skills"]
	var levels := {}
	var spent := 0
	for s in role_skills:
		levels[s] = 2
		spent += 2 * _cost(s)
	var remaining := EDGERUNNER_SKILL_POINTS - spent
	while true:
		var options := []
		var weights := []
		for s in levels:
			if levels[s] < 6 and _cost(s) <= remaining:
				options.append(s)
				weights.append(1 if RulesDB.skill(s)["basic"] else ROLE_SKILL_WEIGHT)
		if options.is_empty():
			break
		var pick: String = options[dice.rng.rand_weighted(PackedFloat32Array(weights))]
		levels[pick] += 1
		remaining -= _cost(pick)
	return levels


static func _cost(skill_id: String) -> int:
	return 2 if RulesDB.skill(skill_id)["x2"] else 1


## A sensible starting Combat Awareness spread for AI and new recruits (Rank 4).
static func _default_awareness(c: Combatant) -> void:
	c.set_awareness({"precision_attack": 3, "initiative_reaction": c.role_rank - 3})


## An NPC at `tier` (mook, lieutenant, mini_boss, boss; CPR p.399): one of the printed stat blocks
## from `pool` (a faction's roster: World.npc), or the tier's default pool in npcs.json.
static func npc(dice: Dice, tier: String, handle: String = "", pool: Array = []) -> Combatant:
	var tiers: Dictionary = RulesDB.load_json("npcs.json")["tiers"]
	var ids: Array = pool if not pool.is_empty() else tiers[tier]["blocks"]
	var c := from_block(dice, String(ids[dice.d(ids.size()) - 1]), handle)
	c.role = tier
	return c


## Night City's civilians (NC2045 district chapters: npcs.json blocks flagged `civilian`, each
## printed for a `district`): the ones from district `did`, or every civilian block when `did` has
## none (or is ""). In data order.
static func civilian_blocks(did := "") -> Array[String]:
	var blocks: Dictionary = RulesDB.load_json("npcs.json")["blocks"]
	var all: Array[String] = []
	var local: Array[String] = []
	for id in blocks:
		var b: Dictionary = blocks[id]
		if bool(b.get("civilian", false)):
			all.append(String(id))
			if did != "" and String(b.get("district", "")) == did:
				local.append(String(id))
	return local if not local.is_empty() else all


## A civilian block (civilian_blocks) as a combatant, its role its tier as for any NPC (npc). With
## no `handle`, the block's name ("Kabuki Market Vendor").
static func civilian(dice: Dice, id: String, handle := "") -> Combatant:
	var c := from_block(dice, id, handle)
	c.role = String(RulesDB.load_json("npcs.json")["blocks"][id].get("tier", "mook"))
	return c


## The stat block `id` (npcs.json blocks, CPR core p.412-416) as a combatant: the printed stats,
## Skill Bases (the book prints STAT + skill, so each skill level is the base minus its stat),
## armour, weapons with their printed quality, cyberware, and the kit items it carries. Skills
## with a specialisation (language:streetslang) are skipped until the game models them.
static func from_block(dice: Dice, id: String, handle: String = "") -> Combatant:
	var b: Dictionary = RulesDB.load_json("npcs.json")["blocks"][id]
	var stats: Dictionary = {}
	for s in b.stats:
		stats[s] = int(b.stats[s])
	var known: Dictionary = RulesDB.load_json("skills.json")["skills"]
	var skills := {}
	for s in b.skills:
		if known.has(s):
			skills[s] = maxi(0, int(b.skills[s]) - int(stats.get(RulesDB.skill_stat(s), 0)))
	var c := Combatant.new(handle if handle != "" else String(b.name), stats, skills)
	c.block = id
	c.tracks_humanity = false
	for loc in ["body", "head"]:
		var aid := String(b.armor[loc])
		if (RulesDB.load_json("armor.json")["armor"] as Dictionary).has(aid):
			c.armor[loc] = ArmorPiece.from_id(aid)
	for cw in Cyber.foundations_first(b.get("cyberware", [])):   # every piece printed: two Cybereyes are two
		c.install_cyberware(cw, dice, true)
	var builtin: Array = c.weapons.duplicate()
	c.weapons.clear()
	var q: Dictionary = b.get("weapon_quality", {})
	for wid in b.weapons:   # primary first, as printed
		var have: Array = builtin.filter(func(x): return x.id() == String(wid))
		if not have.is_empty():
			c.weapons.append(have[0])
			builtin.erase(have[0])
			continue
		var w := Weapon.from_id(String(wid), String(q.get(wid, "standard")))
		w.builtin = (b.get("weapon_sources", {}) as Dictionary).has(wid)
		c.weapons.append(w)
	c.weapons.append_array(builtin)
	var slot := 0
	for key in b.get("kit", []):   # the kit items among the printed gear, one per slot
		if Items.is_item(String(key)) and slot < c.kit.size():
			c.kit[slot] = String(key)
			slot += 1
	if int(b.get("hp", 0)) > 0 and int(b.hp) != c.max_hp():
		c.hp_max_override = int(b.hp)   # printed HP that doesn't follow the formula (Boosterganger)
	c.hp = c.max_hp()
	return c


## Opposition for a gig (CPR p399 budget: 1 Mook = 1 Edgerunner, a Lieutenant 2, a Mini Boss 3).
## The site holds crew_size x (0.5 + security) edgerunners' worth (HOUSE-RULE; was 1.5 + security,
## which a headless campaign run showed the crew rarely survives), spread over its posts:
## security 1 is all Mooks, 2 adds a Lieutenant, 3 adds a Mini Boss. Alerts are local, so the
## crew rarely meets the whole budget at once (XCOM-style pods).
static func opposition(crew_size: int, security: int) -> Array[String]:
	return Security.roster(Security.doctrine("default"), crew_size, security)