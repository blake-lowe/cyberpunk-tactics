class_name Campaign
extends RefCounted
## The between-gig layer (spec: Gigs & Mission Structure, Meta Progression, Injury & Death).
## First slice (M6): a crew, eurobucks, reputation and a day count; a fixer board of parameterised
## gigs; gig results (pay, reputation, Improvement Points, persistent HP/injuries/armour, permadeath);
## downtime (rest heals BODY HP per day, p223; clinics treat Critical Injuries; armour repair and
## ammo resupply). Everything serialises to a JSON save.
##
## Economy numbers (pay, fees, prices) are HOUSE-RULE placeholders until checked against the book's
## job rates and price lists; they're kept together in ECON so they're easy to tune.

const SAVE_PATH := "user://campaign.json"
const ECON := {
	"start_eb": 1000,          # p98: 500eb per starting character, two characters
	"rescue_fee": 500,         # HOUSE-RULE: a fixer drags the survivors of a failed gig out
	"treat_injury": 200,       # HOUSE-RULE: a street clinic's Treatment for one Critical Injury
	"armor_repair": 0,         # HOUSE-RULE: armour is patched up for free in downtime (for now)
	"grenade": 50,             # HOUSE-RULE: restock price per frag grenade
	"hire": 500,               # HOUSE-RULE: signing a new crew member
	"salvage": 0.25,           # HOUSE-RULE: a won gig strips the downed opposition's gear at a quarter of list
}
## IP per gig (p410: the GM awards 10-80; AMBIGUITY: the tiers are qualitative). Our rubric:
## a failed gig 10, success 30, success without anyone going down +10, the NET objective +10.
## Gig kind → encounter objective (Encounter.setup).
const OBJECTIVES := {"data_theft": "data", "gang_hit": "eliminate", "corp_extraction": "snatch"}
## Safehouse facilities (spec: Meta Progression, "a few upgradeable facilities"). HOUSE-RULE content:
## two levels each, costs per level; effects are read where they apply (rest, restock, board, IP).
const FACILITIES := {
	"med_bay": {"name": "Med Bay", "costs": [1500, 4000],
		"desc": ["Rest heals +2 HP a day per level.", "Level 2: clinic treatment costs a quarter less."]},
	"armory": {"name": "Armory", "costs": [1000, 3000],
		"desc": ["Frag grenades restock 10 eb cheaper per level.", "Level 2: everyone carries 3 grenades."]},
	"intel": {"name": "Fixer Network", "costs": [1500, 4000],
		"desc": ["+1 gig on the board per level.", "Better-security gigs show up one reputation earlier per level."]},
	"training": {"name": "Training Room", "costs": [1000, 3000],
		"desc": ["+5 IP per gig for each survivor per level.", ""]},
}
const FIXER_MARKUP := 1.2   ## HOUSE-RULE: spec "items >= 500 eb require a fixer": sourced at +20%
const IP_FAIL := 10
const IP_WIN := 30

static var current: Campaign   ## the running campaign (the board and the tactical view share it)

var seed_value := 1
var dice: Dice
var eb := 0
var rep := 0
var day := 1
var crew: Array[Combatant] = []
var fallen: Array[Dictionary] = []   ## {name, role, day, gig}: the wall
var board: Array[Dictionary] = []    ## gig offers
var recruits: Array[Combatant] = []  ## for hire
var active_gig: Dictionary = {}
var facilities := {}                 ## facility id → level (0 = not built)
var log: Array[String] = []


static func new_game(p_seed: int) -> Campaign:
	var c := Campaign.new()
	c.seed_value = p_seed
	c.dice = Dice.new(p_seed)
	c.eb = int(ECON.start_eb)
	c.crew.append(Recruit.generate(c.dice, "solo", "edgerunner"))
	c.crew.append(Recruit.generate(c.dice, "netrunner", "edgerunner"))
	for i in c.crew.size():
		c.crew[i].look_seed = i
	c.refresh_board()
	c.refresh_recruits()
	c.say("Day 1. %s and %s are looking for work." % [c.crew[0].display_name, c.crew[1].display_name])
	return c


func say(s: String) -> void:
	log.append(s)


func alive_crew() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in crew:
		if not c.dead:
			out.append(c)
	return out


# --- Fixer board ------------------------------------------------------------------

## Three or four offers. Security is weighted by reputation (better jobs need a name), pay scales
## with security and a little with reputation.
func refresh_board() -> void:
	var g := RulesDB.gen("gigs.json")
	board.clear()
	var n := 3 + (1 if rep >= 3 else 0) + level("intel")
	for i in n:
		var t: Dictionary = g.templates[dice.d(g.templates.size()) - 1]
		var sec := 1
		for s in [3, 2]:
			if rep + level("intel") >= int(g.rep_for_security[str(s)]) and dice.d(10) <= (4 if s == 2 else 3):
				sec = s
				break
		var slots := {"fixer": _pick(g.fixers), "corp": _pick(g.corps), "gang": _pick(g.gangs), "data": _pick(g.data),
			"place": _pick(t.get("places", ["site"]))}
		var title := _fill(_pick(t.titles), slots)
		board.append({"id": "%d-%d" % [day, i], "kind": t.kind, "fixer": slots.fixer, "title": title,
			"blurb": _fill(String(t.blurb), slots), "scene": _pick(t.scenes), "security": sec,
			"pay": int(int(g.pay[str(sec)]) * (1.0 + rep * 0.05)), "rep": sec, "seed": dice.rng.randi_range(1, 99999)})


static func objective_for(g: Dictionary) -> String:
	return String(OBJECTIVES.get(String(g.get("kind", "")), "data"))


func _pick(a: Array) -> Variant:
	return a[dice.d(a.size()) - 1]


static func _fill(s: String, slots: Dictionary) -> String:
	for k in slots:
		s = s.replace("{%s}" % k, String(slots[k]))
	return s


## Take a gig: it becomes the active one (the tactical view builds the map from it).
func accept(index: int) -> Dictionary:
	if index < 0 or index >= board.size() or alive_crew().filter(func(c): return c.can_act()).is_empty():
		return {}
	active_gig = board[index]
	say("Took '%s' from %s." % [active_gig.title, active_gig.fixer])
	return active_gig


# --- After the gig ----------------------------------------------------------------

## Settle the active gig from the finished encounter. Returns a report for the results screen.
func resolve(e: Encounter) -> Dictionary:
	var gig := active_gig
	var won := e.state == "won"
	var report := {"gig": gig, "won": won, "pay": 0, "rep": 0, "ip": 0, "dead": [], "hurt": [], "fees": 0, "salvage": 0}
	var anyone_down := false
	for c in crew:
		if c.dead or c.wound_state() >= Combatant.Wound.MORTAL or c.unconscious:
			anyone_down = true
	for c in crew:
		if c.dead and not fallen.any(func(f): return f.name == c.display_name):
			fallen.append({"name": c.display_name, "role": c.role, "day": day, "gig": gig.get("title", "")})
			report.dead.append(c.display_name)
	crew = alive_crew()   # permadeath (spec)
	for c in crew:
		if c.wound_state() >= Combatant.Wound.MORTAL:   # carried out and stabilized (p222-223)
			c.stabilize()
		c.unconscious = false
		c.wake_in = 0
		c.dsp = c.base_dsp
		if c.hp < c.max_hp() or not c.injuries.is_empty():
			report.hurt.append(c.display_name)
	if won:
		report.pay = int(gig.get("pay", 0))
		report.rep = int(gig.get("rep", 1))
		report.ip = IP_WIN + (10 if not anyone_down else 0) + (10 if e.objective.get("kind", "") == "data" and e.objective.get("done", false) else 0)
	else:
		report.rep = -1
		report.ip = IP_FAIL
		if not crew.is_empty():
			report.fees = int(ECON.rescue_fee)
	if won:   # loot: the opposition's guns and armour, fenced
		for u in e.units:
			if u.team == 1 and (u.c.dead or u.c.wound_state() >= Combatant.Wound.MORTAL or u.c.unconscious):
				var value := 0
				for w in u.c.weapons:
					value += int(w.def.get("cost", 0))
				for loc in u.c.armor:
					if u.c.armor[loc]:
						value += int(RulesDB.armor((u.c.armor[loc] as ArmorPiece).id).get("cost", 0))
				report.salvage += int(value * float(ECON.salvage))
	eb += report.pay - report.fees + report.salvage
	rep = maxi(0, rep + report.rep)
	report.ip += 5 * level("training")
	for c in crew:
		c.ip += report.ip
	say("%s: %s. %+d eb, %+d rep, %d IP each%s." % [gig.get("title", "Gig"), "done" if won else "failed",
		report.pay - report.fees + report.salvage, report.rep, report.ip, (", lost " + ", ".join(report.dead)) if not report.dead.is_empty() else ""])
	active_gig = {}
	day += 1
	refresh_board()
	return report


# --- Downtime ---------------------------------------------------------------------

## Rest: everyone heals BODY HP per day (p223), up to full. Armour is patched and magazines
## refilled; frag grenades restocked to two each if there's cash.
func rest(days := 1) -> void:
	for c in crew:
		c.hp = mini(c.max_hp(), c.hp + (c.raw_stat("BODY") + 2 * level("med_bay")) * days)
		for loc in c.armor:
			if c.armor[loc]:
				(c.armor[loc] as ArmorPiece).repair()
		for w in c.weapons:
			w.reload()
		var price := int(ECON.grenade) - 10 * level("armory")
		while c.grenades < (3 if level("armory") >= 2 else 2) and eb >= price:
			c.grenades += 1
			eb -= price
	day += days
	refresh_board()
	say("Rested %d day%s." % [days, "s" if days > 1 else ""])


## Clinic price, halved while a Trauma Surgeon is on the crew (HOUSE-RULE perk).
func treat_cost() -> int:
	var mult := 0.75 if level("med_bay") >= 2 else 1.0
	for c in alive_crew():
		var d := float(c.perk_fx("treat_discount"))
		if d > 0.0:
			mult = minf(mult, d * (0.75 if level("med_bay") >= 2 else 1.0))
	return int(int(ECON.treat_injury) * mult)


## A clinic's Treatment for one Critical Injury (p223: Treatment removes it permanently).
func treat(c: Combatant, injury_index: int) -> bool:
	if injury_index < 0 or injury_index >= c.injuries.size() or eb < treat_cost():
		return false
	eb -= treat_cost()
	var inj: Dictionary = c.injuries[injury_index]
	c.injuries.remove_at(injury_index)
	say("%s's %s treated." % [c.display_name, inj.get("name", "injury")])
	return true


func refresh_recruits() -> void:
	recruits.clear()
	for role in ["solo", "netrunner", "medtech"]:
		var r := Recruit.generate(dice, role, "edgerunner")
		r.look_seed = 10 + recruits.size() + day * 3
		recruits.append(r)


func hire(index: int) -> bool:
	if index < 0 or index >= recruits.size() or eb < int(ECON.hire) or crew.size() >= 4:
		return false
	eb -= int(ECON.hire)
	var r: Combatant = recruits[index]
	recruits.remove_at(index)
	crew.append(r)
	say("Hired %s (%s)." % [r.display_name, r.role.capitalize()])
	return true


# --- Night market (gear shop) ------------------------------------------------------

## What the market stocks, and the reputation it takes to get it (HOUSE-RULE: availability by
## reputation stands in for the book's Night Market rolls, p337). Prices are the book's list
## prices (weapons p92/p94, armour p97). Bows and launchers wait for their rules and models.
const SHOP_WEAPONS := {"medium_pistol": 0, "heavy_pistol": 0, "very_heavy_pistol": 0, "smg": 0, "heavy_smg": 1,
	"shotgun": 1, "assault_rifle": 1, "sniper_rifle": 2, "light_melee": 0, "medium_melee": 0, "heavy_melee": 0,
	"very_heavy_melee": 2}
const SHOP_ARMOR := {"leathers": 0, "kevlar": 0, "light_armorjack": 0, "medium_armorjack": 1, "heavy_armorjack": 2,
	"flak": 2, "bodyweight_suit": 3, "metalgear": 5}
const RESALE := 0.5   ## HOUSE-RULE: replaced gear sells back at half price
const MAX_GUNS := 2   ## HOUSE-RULE: a primary and a sidearm (plus one melee weapon)


## Shop entries available at the current reputation: {id, kind: weapon|armor, name, cost, info}.
func shop_stock() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in SHOP_WEAPONS:
		if rep >= int(SHOP_WEAPONS[id]):
			var d := RulesDB.weapon(id)
			var info := "%dd6" % int(d.dice) + ("" if d.get("melee", false) else " · ROF %d · %d rds" % [int(d.rof), int(d.mag)])
			out.append({"id": id, "kind": "weapon", "name": String(d.name), "cost": _price(int(d.cost)), "info": info, "fixer": int(d.cost) >= 500})
	for id in SHOP_ARMOR:
		if rep >= int(SHOP_ARMOR[id]):
			var a := RulesDB.armor(id)
			out.append({"id": id, "kind": "armor", "name": String(a.name), "cost": _price(int(a.cost)), "fixer": int(a.cost) >= 500,
				"info": "SP %d" % int(a.sp) + (" · -%d REF/DEX/MOVE" % int(a.penalty) if int(a.penalty) > 0 else "")})
	return out


static func _price(list: int) -> int:
	return int(list * FIXER_MARKUP) if list >= 500 else list


## Buy an item for a crew member. A gun becomes their primary (the oldest extra gun is sold); a melee
## weapon replaces their melee weapon; armour is bought for one location (head or body) and the old
## piece is sold. Returns false if they can't afford it.
func buy(c: Combatant, id: String, loc := "body") -> bool:
	var entry: Array = shop_stock().filter(func(x): return x.id == id)
	if entry.is_empty() or eb < int(entry[0].cost):
		return false
	var it: Dictionary = entry[0]
	var refund := 0
	if it.kind == "weapon":
		var w := Weapon.from_id(id)
		if w.is_melee():
			for old in c.weapons.filter(func(x): return x.is_melee()):
				refund += int(int(old.def.cost) * RESALE)
				c.weapons.erase(old)
			c.weapons.append(w)
		else:
			c.weapons.insert(0, w)
			var guns := c.weapons.filter(func(x): return not x.is_melee())
			while guns.size() > MAX_GUNS:
				var old: Weapon = guns.pop_back()
				refund += int(int(old.def.cost) * RESALE)
				c.weapons.erase(old)
	else:
		var old_a: ArmorPiece = c.armor.get(loc)
		if old_a:
			refund += int(int(RulesDB.armor(old_a.id).cost) * RESALE)
		c.armor[loc] = ArmorPiece.from_id(id)
	eb -= int(it.cost) - refund
	say("%s buys %s%s%s." % [c.display_name, it.name, " (%s)" % loc if it.kind == "armor" else "",
		", sells the old gear for %d eb" % refund if refund > 0 else ""])
	return true


# --- Ripperdoc (cyberware) ----------------------------------------------------------------

## What the ripperdoc installs: pieces whose effects the rules use, with the foundation each needs
## (p111-116: neuralware needs a Neural Link, cyberoptics a Cybereye, chipware a Chipware Socket,
## arm options a Cyberarm). Purchase price includes the surgery (p110). Short effect summaries are
## our paraphrase.
const RIPPERDOC := {
	"neural_link": ["", "Foundation for neuralware."],
	"kerenzikov": ["neural_link", "+2 Initiative."],
	"chipware_socket": ["neural_link", "Holds chipware."],
	"pain_editor": ["chipware_socket", "Ignore Seriously Wounded penalties."],
	"cybereye": ["", "Foundation for cyberoptics."],
	"targeting_scope": ["cybereye", "+1 to Aimed Shots."],
	"skin_weave": ["", "SP 7 under the skin, head and body."],
	"subdermal_armor": ["", "SP 11 under the skin, head and body."],
	"grafted_muscle_and_bone_lace": ["", "+2 BODY (max 10): more HP."],
	"cyberarm": ["", "Brawling hits for at least 2d6; holds arm options."],
	"big_knucks": ["cyberarm", "Medium melee weapon in the knuckles."],
	"wolvers": ["cyberarm", "Heavy melee claws."],
}
const THERAPY := {"cost": 600, "days": 7, "regain": "2d6"}   # p230 Standard Humanity Loss: 500eb + 100eb materials, a week


## Why `c` can't get this piece now ("" if they can).
func install_block(c: Combatant, id: String) -> String:
	if c.has_cyberware(id):
		return "installed"
	var need: String = RIPPERDOC[id][0]
	if need != "" and not c.has_cyberware(need):
		return "needs " + String(RulesDB.cyberware(need).name)
	if eb < int(RulesDB.cyberware(id).cost):
		return "%d eb" % int(RulesDB.cyberware(id).cost)
	return ""


## Install a piece: pay, roll the Humanity Loss (p110), and arm any built-in melee weapon.
func install(c: Combatant, id: String) -> int:
	if install_block(c, id) != "":
		return -1
	var d := RulesDB.cyberware(id)
	eb -= int(d.cost)
	var loss := c.install_cyberware(id, dice)
	say("%s gets %s installed (-%d Humanity)." % [c.display_name, d.name, loss])
	return loss


## A week of therapy (p230): pay, everyone else rests the week, the patient regains 2d6 Humanity
## up to their cap.
func therapy(c: Combatant) -> bool:
	if not c.tracks_humanity or c.humanity >= c.max_humanity or eb < int(THERAPY.cost):
		return false
	eb -= int(THERAPY.cost)
	var gain := Combatant.roll_hl(dice, THERAPY.regain)
	c.regain_humanity(gain)
	say("%s spends a week in therapy (+%d Humanity)." % [c.display_name, gain])
	rest(int(THERAPY.days))
	return true


# --- Safehouse ------------------------------------------------------------------------

func level(facility: String) -> int:
	return int(facilities.get(facility, 0))


## Cost of the next level, or -1 if maxed.
func upgrade_cost(facility: String) -> int:
	var costs: Array = FACILITIES[facility].costs
	return int(costs[level(facility)]) if level(facility) < costs.size() else -1


func upgrade(facility: String) -> bool:
	var cost := upgrade_cost(facility)
	if cost < 0 or eb < cost:
		return false
	eb -= cost
	facilities[facility] = level(facility) + 1
	say("Built %s level %d." % [FACILITIES[facility].name, level(facility)])
	if facility == "intel":
		refresh_board()
	return true


# --- Save / load ------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": 1, "seed": seed_value, "eb": eb, "rep": rep, "day": day, "crew": crew.map(func(c): return c.to_dict()),
		"fallen": fallen, "board": board, "recruits": recruits.map(func(c): return c.to_dict()), "log": log.slice(-50),
		"rng_state": dice.rng.state, "facilities": facilities}


static func from_dict(d: Dictionary) -> Campaign:
	var c := Campaign.new()
	c.seed_value = int(d.seed)
	c.dice = Dice.new(c.seed_value)
	c.dice.rng.state = int(d.get("rng_state", c.dice.rng.state))
	c.eb = int(d.eb)
	c.rep = int(d.rep)
	c.day = int(d.day)
	for cd in d.crew:
		c.crew.append(Combatant.from_dict(cd))
	for f in d.fallen:
		c.fallen.append(f)
	for b in d.board:
		c.board.append(b)
	for r in d.get("recruits", []):
		c.recruits.append(Combatant.from_dict(r))
	for k in d.get("facilities", {}):
		c.facilities[String(k)] = int(d.facilities[k])
	for l in d.get("log", []):
		c.log.append(String(l))
	return c


func save(path := SAVE_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return true


static func load_from(path := SAVE_PATH) -> Campaign:
	if not FileAccess.file_exists(path):
		return null
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return Campaign.from_dict(d) if d is Dictionary else null
