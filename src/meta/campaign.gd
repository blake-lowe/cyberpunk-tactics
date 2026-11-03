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
const OBJECTIVES := {"data_theft": "data", "gang_hit": "eliminate", "corp_extraction": "snatch", "assassination": "assassinate", "rescue": "rescue", "sabotage": "sabotage"}
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
## Downtime assignments (spec: "assign downtime actions"), HOUSE-RULE numbers, per day of rest:
## recover heals BODY (p223); train heals half and earns IP; hustle heals half and earns eb from side
## work (more with reputation) but can draw attention.
const DOWNTIME := {
	"recover": {"name": "Recover", "desc": "Heal BODY HP a day (p223)."},
	"train": {"name": "Train", "desc": "Half healing; +6 IP a day."},
	"hustle": {"name": "Hustle", "desc": "Half healing; 60 eb a day (+10 per rep); 1 in 10 days adds heat."},
}
const FIXER_MARKUP := 1.2   ## HOUSE-RULE: spec "items >= 500 eb require a fixer": sourced at +20%
const IP_FAIL := 10
const IP_WIN := 30

static var current: Campaign   ## the running campaign (the board and the tactical view share it)

var seed_value := 1
var dice: Dice
var eb := 0
var rep := 0                         ## street cred: the overall name (market access, crew size of the board)
var heat := 0                        ## 0-10: how hard NCPD is looking for the crew (spec: consequences, heat)
var fixer_rep := {}                  ## fixer name → reputation with them (spec: per-fixer reputation)
var day := 1
var crew: Array[Combatant] = []
var fallen: Array[Dictionary] = []   ## {name, role, day, gig}: the wall
var board: Array[Dictionary] = []    ## gig offers
var recruits: Array[Combatant] = []  ## for hire
var active_gig: Dictionary = {}
var facilities := {}                 ## facility id → level (0 = not built)
var log: Array[String] = []


## The running campaign: the one in memory, else the save, else a new game.
static func ensure_current() -> Campaign:
	if current == null:
		current = load_from()
		if current == null or current.crew.is_empty():
			current = new_game(int(Time.get_unix_time_from_system()) % 100000)
	return current


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
		var willing: Array = g.fixers.filter(func(f): return rep_with(String(f)) >= 0)   # not the ones who sold you out
		var slots := {"fixer": _pick(willing if not willing.is_empty() else g.fixers), "corp": _pick(g.corps), "gang": _pick(g.gangs), "data": _pick(g.data),
			"place": _pick(t.get("places", ["site"])), "target": _pick(t.get("targets", ["target"]))}
		var frep := maxi(0, rep_with(String(slots.fixer)))   # better jobs come from fixers who know you
		var sec := 1
		for s in [3, 2]:
			if frep + level("intel") >= int(g.rep_for_security[str(s)]) and dice.d(10) <= (4 if s == 2 else 3):
				sec = s
				break
		var twist := ""
		if dice.rng.randf() < float(g.get("twist_chance", 0.0)) + heat * 0.04:   # heat: corps are expecting trouble
			var keys: Array = g.twists.keys()
			twist = keys[dice.d(keys.size()) - 1]
		var mult := float(g.twists[twist].pay) if twist != "" else 1.0
		var title := _fill(_pick(t.titles), slots)
		board.append({"id": "%d-%d" % [day, i], "kind": t.kind, "fixer": slots.fixer, "title": title,
			"blurb": _fill(String(t.blurb), slots), "security": sec, "twist": twist,
			"pay": int(int(g.pay[str(sec)]) * (1.0 + frep * 0.05) * mult), "rep": sec, "seed": dice.rng.randi_range(1, 99999),
			"setup": frep == 0 and dice.rng.randf() < float(g.get("betrayal_chance", 0.0))})
		board[-1].merge(_place_for(String(t.kind), g))
	_unique_offer(g)


## A fixer who trusts the crew (rep >= unique_rep) sometimes has a personal job: security 3, double
## pay, extra reputation (spec: "occasional unique offers"). At most one on the board.
func _unique_offer(g: Dictionary) -> void:
	var trusted: Array = g.fixers.filter(func(f): return rep_with(String(f)) >= int(g.get("unique_rep", 3)))
	if trusted.is_empty() or dice.d(3) != 1:
		return
	var t: Dictionary = g.unique_templates[dice.d(g.unique_templates.size()) - 1]
	var slots := {"fixer": _pick(trusted), "corp": _pick(g.corps), "gang": _pick(g.gangs), "data": _pick(g.data),
		"place": _pick(t.get("places", ["site"]))}
	var sec := int(t.security)
	board.append({"id": "%d-u" % day, "kind": t.kind, "fixer": slots.fixer, "title": _fill(_pick(t.titles), slots),
		"blurb": _fill(String(t.blurb), slots), "security": sec, "twist": "", "unique": true,
		"pay": int(int(g.pay[str(sec)]) * float(t.pay_mult)), "rep": int(t.rep), "seed": dice.rng.randi_range(1, 99999), "setup": false})
	board[-1].merge(_place_for(String(t.kind), g))


static func objective_for(g: Dictionary) -> String:
	return String(OBJECTIVES.get(String(g.get("kind", "")), "data"))


## Cyberpsychosis outside combat (spec: episodes "can trigger in or out of combat"). After a gig, each
## crew member at risk rolls their combat episode chance once (approved HOUSE-RULE table); an
## episode means lashing out at someone close: a crewmate takes 2d6 (never below 1 HP), and the
## mess adds heat. Returns the names of those who had one.
func _downtime_episodes() -> Array:
	var out := []
	for c in alive_crew():
		if c.episode_chance() <= 0.0 or dice.rng.randf() >= c.episode_chance():
			continue
		var others := alive_crew().filter(func(o): return o != c)
		var hurt := ""
		if not others.is_empty():
			var o: Combatant = others[dice.d(others.size()) - 1]
			o.hp = maxi(1, o.hp - dice.roll(2, 6))
			hurt = o.display_name
		out.append(c.display_name)
		say("%s has a cyberpsychotic episode after the job%s. Therapy would help." % [c.display_name, (" and hurts " + hurt) if hurt != "" else ""])
	return out


## Heat from how a gig went (HOUSE-RULE): in and out unseen cools things down; an alarm, NCPD
## showing up, and bodies left behind warm them up.
static func gig_heat(e: Encounter) -> int:
	var h := 0
	if e.alarm == 0:
		h -= 1
	if e.alarm >= 2:
		h += 1
	if e.ncpd_in == -2:
		h += 1
	var bodies := e.units.filter(func(u): return u.team == 1 and u.c.dead).size()
	h += bodies / 4
	return h


func _salvage_mult() -> float:
	var m := 1.0
	for c in alive_crew():
		m = maxf(m, float(c.perk_fx("salvage_mult")))
	return m


## Where a gig happens: any scene whose tags fit the job (gigs.json scene_tags / kind_tags), or
## (raid_chance) a raid on a single site picked for the job. Returns {scene, profile, site}.
func _place_for(kind: String, g: Dictionary) -> Dictionary:
	if dice.rng.randf() < float(g.get("raid_chance", 0.0)) and g.raid_sites.has(kind):
		return {"scene": "lone_building", "profile": "", "site": _pick(g.raid_sites[kind])}
	var want: Array = g.kind_tags.get(kind, [])
	var fits: Array = g.scene_tags.keys().filter(func(sc): return (g.scene_tags[sc] as Array).any(func(t): return t in want))
	var pick: String = _pick(fits) if not fits.is_empty() else "lone_building"
	if pick.begins_with("neighborhood:"):
		return {"scene": "neighborhood", "profile": pick.get_slice(":", 1), "site": ""}
	return {"scene": pick, "profile": "", "site": ""}


## The gig's place as the board shows it: a site, a neighbourhood or a scene.
static func place_name(gig: Dictionary) -> String:
	if String(gig.get("site", "")) != "":
		return String(RulesDB.gen("sites.json").get(gig.site, {}).get("name", String(gig.site).replace("_", " ")))
	if String(gig.get("profile", "")) != "":
		return String(RulesDB.gen("districts.json").get("profiles", RulesDB.gen("districts.json")).get(gig.profile, {}).get("name", String(gig.profile).replace("_", " ")))
	return String(RulesDB.gen("scenes.json").get(gig.get("scene", ""), {}).get("name", gig.get("scene", "")))


## SceneGen options for a gig dict.
static func scene_opts(gig: Dictionary) -> Dictionary:
	var o := {"security": int(gig.get("security", 1))}
	if String(gig.get("profile", "")) != "":
		o["profile"] = gig.profile
	if String(gig.get("site", "")) != "":
		o["site"] = gig.site
	return o


func rep_with(fixer: String) -> int:
	return int(fixer_rep.get(fixer, 0))


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
	var report := {"gig": gig, "won": won, "pay": 0, "rep": 0, "ip": 0, "dead": [], "hurt": [], "fees": 0, "salvage": 0, "heat": 0, "episodes": []}
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
	if won and gig.get("setup", false):   # sold out: no pay, and that fixer is dead to the crew
		report.rep = 0
		report.ip = IP_WIN
		fixer_rep[String(gig.fixer)] = -5
		say("%s sold you out. No pay; you won't work for them again soon." % gig.fixer)
	elif won:
		report.pay = int(gig.get("pay", 0))
		report.rep = int(gig.get("rep", 1))
		report.ip = IP_WIN + (10 if not anyone_down else 0) + (10 if e.objective.get("kind", "") == "data" and e.objective.get("done", false) else 0)
	else:
		report.rep = -1
		report.ip = IP_FAIL
		if not crew.is_empty() and e.state != "fled":   # a crew that walked out needs no rescue
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
				report.salvage += int(value * float(ECON.salvage) * _salvage_mult())
	eb += report.pay - report.fees + report.salvage
	report.episodes = _downtime_episodes()
	report.heat = gig_heat(e) + report.episodes.size()
	heat = clampi(heat + report.heat, 0, 10)
	rep = maxi(0, rep + report.rep)
	var fx_name := String(gig.get("fixer", ""))
	if fx_name != "" and not (won and gig.get("setup", false)):
		fixer_rep[fx_name] = maxi(0, rep_with(fx_name) + report.rep)
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
		var heal: int = (c.raw_stat("BODY") + 2 * level("med_bay")) * days
		match c.downtime:
			"train":
				heal /= 2
				c.ip += 6 * days
			"hustle":
				heal /= 2
				eb += (60 + 10 * rep) * days
				for dd in days:
					if dice.d(10) == 1:
						heat = mini(10, heat + 1)
		c.hp = mini(c.max_hp(), c.hp + heal)
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
	heat = maxi(0, heat - days)   # HOUSE-RULE: lying low cools heat by 1 a day
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
	for role in ["solo", "netrunner", "medtech", "tech"]:
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
			if c.weapons.any(func(x): return x.builtin):
				return false   # cyberware claws/knuckles already fill the melee slot
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


# --- Tech workshop (Upgrade Expertise, p148) ------------------------------------------------

## Days an upgrade takes by price (Maker table p149): Premium a day, Expensive a week...
static func maker_days(price: int) -> int:
	if price <= 50: return 1      # Cheap-Costly: hours; we round up to a day of downtime
	if price <= 100: return 1
	if price <= 500: return 7
	if price <= 1000: return 14
	return 30


func best_tech() -> Combatant:
	var best: Combatant = null
	for c in alive_crew():
		if c.role == "tech" and int(c.maker.get("upgrade", 0)) > 0 and (best == null or int(c.maker.upgrade) > int(best.maker.upgrade)):
			best = c
	return best


## The crew's Tech upgrades an armour piece: +1 SP, once per item (p148). Materials cost the item's
## price; TECH + Basic Tech + Upgrade rank + 1d10 vs the price's DV; the work takes its time in
## downtime (the crew rests meanwhile). Failure wastes the time, not the materials (p148).
## Returns {} if not possible, else {ok, success, days}.
func upgrade_armor(owner: Combatant, loc: String) -> Dictionary:
	var t := best_tech()
	var a: ArmorPiece = owner.armor.get(loc)
	if t == null or a == null or a.upgraded or eb < a.price():
		return {}
	var dv := ArmorPiece.maker_dv(a.price())
	var check := Check.vs_dv(dice, t.skill_base("basic_tech") + int(t.maker.upgrade) + int(t.perk_fx("upgrade_bonus")), dv)
	var days := maker_days(a.price())
	if check.success:
		eb -= a.price()
		a.upgraded = true
		a.max_sp += 1
		a.sp = a.max_sp
	say("%s %s %s's %s (%s, %d day%s)." % [t.display_name, "upgrades" if check.success else "fails to upgrade", owner.display_name, a.name,
		loc, days, "s" if days > 1 else ""])
	rest(days)
	return {"ok": true, "success": check.success, "days": days}


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
		"rng_state": dice.rng.state, "facilities": facilities, "fixer_rep": fixer_rep, "heat": heat}


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
	c.heat = int(d.get("heat", 0))
	for k in d.get("fixer_rep", {}):
		c.fixer_rep[String(k)] = int(d.fixer_rep[k])
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
