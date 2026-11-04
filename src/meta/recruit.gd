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

const HANDLES := ["Ghost", "Razor", "Mox", "Static", "Jinx", "Bones", "Echo", "Vex", "Kilo", "Neon",
	"Rook", "Saint", "Dice", "Wraith", "Chrome", "Lotus", "Patch", "Hex", "Torque", "Sable"]


static func generate(dice: Dice, role: String, method: String = "edgerunner", handle: String = "") -> Combatant:
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

	if handle == "":
		handle = HANDLES[dice.d(HANDLES.size()) - 1]
	var c := Combatant.new(handle, stats, skills)
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
	for choice in rd["cyberware"]:
		c.install_cyberware(choice[dice.d(choice.size()) - 1], dice, true)
	c.hp = c.max_hp()
	c.armor["body"] = ArmorPiece.from_id("light_armorjack")  # p98
	c.armor["head"] = ArmorPiece.from_id("light_armorjack")
	# HOUSE-RULE: pared-down loadouts carry frag grenades (two for Solos, one otherwise) until the
	# gear/inventory system lands (M6+).
	c.grenades = 2 if role == "solo" else 1
	if role == "solo":
		_default_awareness(c)
	return c


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


## An NPC from the book's tiers (npcs.json: mook, lieutenant, mini_boss; CPR p399, p411-415).
## The book prints Skill Bases (STAT + skill), so each skill level is the base minus its stat.
## `gear` overrides the tier's kit list and armour (a faction's roster: World.npc):
## {kits: [[weapon ids]], armor: armour id}.
static func npc(dice: Dice, tier: String, handle: String = "", gear: Dictionary = {}) -> Combatant:
	var td: Dictionary = (RulesDB.load_json("npcs.json")["tiers"][tier] as Dictionary).duplicate()
	if gear.has("kits"):
		td["weapons"] = gear.kits
	if gear.has("armor"):
		td["armor"] = gear.armor
	var stats: Dictionary = (td["stats"] as Dictionary).duplicate()
	var skills := {}
	for s in td["skills"]:
		skills[s] = maxi(0, int(td["skills"][s]) - int(stats.get(RulesDB.skill_stat(s), 0)))
	var c := Combatant.new(handle if handle != "" else String(td["name"]), stats, skills)
	c.armor["body"] = ArmorPiece.from_id(String(td["armor"]))
	c.armor["head"] = ArmorPiece.from_id(String(td["armor"]))
	var kits: Array = td["weapons"]
	for w in kits[dice.d(kits.size()) - 1]:
		c.weapons.append(Weapon.from_id(String(w)))
	c.grenades = int(td.get("grenades", 0))
	c.role = tier
	c.tracks_humanity = false
	return c


## Opposition for a gig (CPR p399 budget: 1 Mook = 1 Edgerunner, a Lieutenant 2, a Mini Boss 3).
## The site holds crew_size x (0.5 + security) edgerunners' worth (HOUSE-RULE; was 1.5 + security,
## which a headless campaign run showed the crew rarely survives), spread over its posts:
## security 1 is all Mooks, 2 adds a Lieutenant, 3 adds a Mini Boss. Alerts are local, so the
## crew rarely meets the whole budget at once (XCOM-style pods).
static func opposition(crew_size: int, security: int) -> Array[String]:
	return Security.roster(Security.doctrine("default"), crew_size, security)