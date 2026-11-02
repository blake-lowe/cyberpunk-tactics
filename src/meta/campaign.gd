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
}
## IP per gig (p410: the GM awards 10-80; AMBIGUITY: the tiers are qualitative). Our rubric:
## a failed gig 10, success 30, success without anyone going down +10, the NET objective +10.
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
	var n := 3 + (1 if rep >= 3 else 0)
	for i in n:
		var t: Dictionary = g.templates[dice.d(g.templates.size()) - 1]
		var sec := 1
		for s in [3, 2]:
			if rep >= int(g.rep_for_security[str(s)]) and dice.d(10) <= (4 if s == 2 else 3):
				sec = s
				break
		var slots := {"fixer": _pick(g.fixers), "corp": _pick(g.corps), "gang": _pick(g.gangs), "data": _pick(g.data),
			"place": _pick(t.get("places", ["site"]))}
		var title := _fill(_pick(t.titles), slots)
		board.append({"id": "%d-%d" % [day, i], "kind": t.kind, "fixer": slots.fixer, "title": title,
			"blurb": _fill(String(t.blurb), slots), "scene": _pick(t.scenes), "security": sec,
			"pay": int(int(g.pay[str(sec)]) * (1.0 + rep * 0.05)), "rep": sec, "seed": dice.rng.randi_range(1, 99999)})


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
	var report := {"gig": gig, "won": won, "pay": 0, "rep": 0, "ip": 0, "dead": [], "hurt": [], "fees": 0}
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
		report.ip = IP_WIN + (10 if not anyone_down else 0) + (10 if e.objective.get("done", false) else 0)
	else:
		report.rep = -1
		report.ip = IP_FAIL
		if not crew.is_empty():
			report.fees = int(ECON.rescue_fee)
	eb += report.pay - report.fees
	rep = maxi(0, rep + report.rep)
	for c in crew:
		c.ip += report.ip
	say("%s: %s. %+d eb, %+d rep, %d IP each%s." % [gig.get("title", "Gig"), "done" if won else "failed",
		report.pay - report.fees, report.rep, report.ip, (", lost " + ", ".join(report.dead)) if not report.dead.is_empty() else ""])
	active_gig = {}
	day += 1
	refresh_board()
	return report


# --- Downtime ---------------------------------------------------------------------

## Rest: everyone heals BODY HP per day (p223), up to full. Armour is patched and magazines
## refilled; frag grenades restocked to two each if there's cash.
func rest(days := 1) -> void:
	for c in crew:
		c.hp = mini(c.max_hp(), c.hp + c.raw_stat("BODY") * days)
		for loc in c.armor:
			if c.armor[loc]:
				(c.armor[loc] as ArmorPiece).repair()
		for w in c.weapons:
			w.reload()
		while c.grenades < 2 and eb >= int(ECON.grenade):
			c.grenades += 1
			eb -= int(ECON.grenade)
	day += days
	refresh_board()
	say("Rested %d day%s." % [days, "s" if days > 1 else ""])


## A clinic's Treatment for one Critical Injury (p223: Treatment removes it permanently).
func treat(c: Combatant, injury_index: int) -> bool:
	if injury_index < 0 or injury_index >= c.injuries.size() or eb < int(ECON.treat_injury):
		return false
	eb -= int(ECON.treat_injury)
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


# --- Save / load ------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": 1, "seed": seed_value, "eb": eb, "rep": rep, "day": day, "crew": crew.map(func(c): return c.to_dict()),
		"fallen": fallen, "board": board, "recruits": recruits.map(func(c): return c.to_dict()), "log": log.slice(-50),
		"rng_state": dice.rng.state}


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
