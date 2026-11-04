class_name Campaign
extends RefCounted
## The between-gig layer (spec: Gigs & Mission Structure, Meta Progression, Injury & Death).
## First slice (M6): a crew, eurobucks and a day count; a fixer board of parameterised gigs; gig
## results (pay, each crew member's Reputation, Improvement Points, persistent HP/injuries/armour,
## permadeath); downtime (rest heals BODY HP per day, p223; clinics treat Critical Injuries; the
## crew repairs ablated armour, p140; ammo resupply); the book's Night Market (p337-339) selling into
## safehouse storage, from which the crew equips weapons, armour and kit. Everything serialises to a
## JSON save.
##
## Economy numbers (pay, fees, prices) are HOUSE-RULE placeholders until checked against the book's
## job rates and price lists; they're kept together in ECON so they're easy to tune.

const SAVE_PATH := "user://campaign.json"
const ECON := {
	"start_eb": 1000,          # p98: 500eb per starting character, two characters
	"treat_injury": 200,       # HOUSE-RULE: a street clinic's Treatment for one Critical Injury
	"hire": 500,               # HOUSE-RULE: signing a new crew member
}
## IP per gig: the Group column of the Playstyle Improvement Point table (CPR core p410: a finished
## mission awards the Group value). RULES-UNVERIFIED reading of its qualitative tiers: a failed gig is
## "did not succeed, but tried valiantly" (10); a won gig that cost a crew member's life "barely
## accomplished" it (20); a won gig everyone came back from "worked together well ... with everyone
## taking part" (30). The 40-80 tiers ("extremely well", "stellar moments", side goals) need a GM's eye.
const IP_GROUP := {"failed": 10, "barely": 20, "together": 30}
## Gig kind → encounter objective (Encounter.setup).
const OBJECTIVES := {"data_theft": "data", "gang_hit": "eliminate", "corp_extraction": "snatch", "assassination": "assassinate", "rescue": "rescue", "sabotage": "sabotage"}
## Downtime assignments (spec: "assign downtime actions"): only what the book has a rule for.
## Recover: natural healing, BODY HP a day (p223). (The book has no rule for earning IP or eb in
## downtime: IP come from the GM after a session, p410.)
const DOWNTIME := {
	"recover": {"name": "Recover", "desc": "Heal BODY HP a day (p223)."},
}

static var current: Campaign   ## the running campaign (the board and the tactical view share it)

var seed_value := 1
var dice: Dice
var eb := 0
var day := 1
var crew: Array[Combatant] = []
var fallen: Array[Dictionary] = []   ## {name, role, day, gig}: the wall
var board: Array[Dictionary] = []    ## gig offers
var recruits: Array[Combatant] = []  ## for hire
var active_gig: Dictionary = {}
var stash := {}                      ## safehouse storage: Items key → how many (kit, weapons, armour)
var market := {}                     ## the Night Market that's up (NightMarket.roll)
var log: Array[String] = []
## What the last gig changed for each crew member (resolve's report "members"), shown on the
## debrief screen and as marks on crew cards until the next gig starts. Saved.
var debrief: Array[Dictionary] = []


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
	c.update_market()
	c.say("Day 1. %s and %s are looking for work." % [c.crew[0].display_name, c.crew[1].display_name])
	return c


## Add a log line. The same line again merges into the last one with a count ("Bought Flashbang ×2").
func say(s: String) -> void:
	if not log.is_empty():
		var last := log[-1]
		var n := 1
		var m := RegEx.create_from_string(" ×(\\d+)$").search(last)
		if m:
			n = int(m.get_string(1))
			last = last.substr(0, m.get_start())
		if last == s:
			log[-1] = "%s ×%d" % [s, n + 1]
			return
	log.append(s)


func alive_crew() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in crew:
		if not c.dead:
			out.append(c)
	return out


## The crew's best Reputation (p193, per character). The game's reading: a fixer offers work by the
## best-known name on the crew (the one most likely to have been heard of).
func best_reputation() -> int:
	var best := 0
	for c in alive_crew():
		best = maxi(best, c.reputation)
	return best


# --- Fixer board ------------------------------------------------------------------

## Three or four offers (M9 P3: jobs come from Night City's real places). Each offer is a job a
## Fixer working the district has at a canon location (data/world/locations.json, fixers.json):
## the gig kind comes from a template, its security level is rolled against the crew's best
## Reputation as before (better jobs need a name, p193) and picks a location of that level (the
## location's Security Code intensity, World.location) whose hooks name the kind (else whose `gigs`
## include it), weighted toward Security Codes near what the crew's name can take on
## (code_weight). The location's hook is the job's pitch; its owner (else its code's faction, else
## a district gang) is the target. When no location fits, the old generic offer stands in. Pay
## scales with security.
func refresh_board() -> void:
	var g := RulesDB.gen("gigs.json")
	board.clear()
	var known := best_reputation()
	var n := 3 + (1 if known >= 3 else 0)
	var used := {}
	for i in n:
		var t: Dictionary = g.templates[dice.d(g.templates.size()) - 1]
		var sec := _roll_security(g, known)
		var gig := _city_offer(g, t, sec, known, used)
		if gig.is_empty():
			gig = _generic_offer(g, t, sec, known)
		gig["id"] = "%d-%d" % [day, i]
		board.append(gig)
	_unique_offer(g)


## The security level for an offer: 1, or higher if the crew's best Reputation reaches it
## (rep_for_security) and a d10 comes up (2: 4 in 10, 3: 3 in 10).
func _roll_security(g: Dictionary, known: int) -> int:
	for s in [3, 2]:
		if known >= int(g.rep_for_security[str(s)]) and dice.d(10) <= (4 if s == 2 else 3):
			return s
	return 1


## An offer at a canon location, or {} if none fits the kind at `sec` or below.
func _city_offer(g: Dictionary, t: Dictionary, sec: int, known: int, used: Dictionary) -> Dictionary:
	var kind := String(t.kind)
	var lid := _pick_location(kind, sec, known, used)
	if lid == "":
		return {}
	used[lid] = true
	var l := World.location(lid)
	var did := String(l.get("district", ""))
	var rng: Array = l.get("security", [sec, sec])
	var level := clampi(sec, int(rng[0]), int(rng[1]))   # the place's own range (its code's intensity)
	var fid := _target_for(l, kind)
	var fx := _pick_fixer(did, kind, known)
	var hook := _hook_for(l, kind)
	var slots := _target_slots(kind)
	slots.merge({"target": World.display_name(fid), "data": _pick(g.data)}, true)
	var pitch := hook if hook != "" else _fill(String(t.get("pitch", "")), slots)
	pitch = pitch.left(1).to_upper() + pitch.substr(1)
	var where := String(World.district(did).get("name", did))
	var gig := {"kind": kind, "fixer": String(fx.get("name", "A fixer")), "fixer_id": String(fx.get("id", "")),
		"faction": fid, "location": lid, "district": did, "hook": hook,
		"title": "%s: %s" % [String(t.get("label", kind.capitalize())), String(l.name)],
		"blurb": "%s has work at %s (%s): %s" % [String(fx.get("name", "A fixer")), String(l.name), where, pitch],
		"security": level, "pay": int(g.pay[str(level)]), "seed": dice.rng.randi_range(1, 99999)}
	gig.merge(_place_at(lid))
	gig.merge(codes_for(gig, did), true)
	return gig


## The old generic offer (template slots, a scene picked by tags), with a Fixer from the data.
func _generic_offer(g: Dictionary, t: Dictionary, sec: int, known: int) -> Dictionary:
	var fx := _pick_fixer("", String(t.kind), known)
	var slots := {"fixer": String(fx.get("name", "A fixer")), "data": _pick(g.data),
		"place": _pick(t.get("places", ["site"])), "target": _pick(t.get("targets", ["target"]))}
	slots.merge(_target_slots(String(t.kind)))
	var gig := {"kind": t.kind, "fixer": slots.fixer, "fixer_id": String(fx.get("id", "")), "faction": slots.faction,
		"title": _fill(_pick(_titles_for(t, String(slots.faction))), slots), "blurb": _fill(String(t.blurb), slots),
		"security": sec, "pay": int(g.pay[str(sec)]), "seed": dice.rng.randi_range(1, 99999)}
	gig.merge(_place_for(String(t.kind), g, String(slots.faction)))
	_fit_location_security(gig)
	gig.pay = int(g.pay[str(int(gig.security))])
	_code_gig(gig)
	return gig


## HOUSE-RULE: the Security Code a crew's name can take on: 3 + best Reputation (a crew nobody
## knows works the Combat Zones' 2-3 codes; Reputation 5 reaches the 8s of the corporate districts).
## A location's weight falls off with the square of its code's distance from that (most of the
## city's places sit at codes 5-9, so a gentler falloff left nobodies working the Exec Zone).
static func code_weight(code_n: int, known: int) -> float:
	var d := 1.0 + absi(code_n - clampi(3 + known, 2, 10))
	return 1.0 / (d * d)


## A canon location for a `kind` job at security level `sec` (the highest level at or below it that
## has one), not already on the board: hooks naming the kind weigh 3, places whose `gigs` include
## it 1, times code_weight. "" if there is none.
func _pick_location(kind: String, sec: int, known: int, used: Dictionary) -> String:
	var all := World.locations()
	for lv in range(sec, 0, -1):
		var ids: Array = []
		var ws: Array = []
		for id in all:
			if used.has(id):
				continue
			var raw: Dictionary = all[id]
			var w := 0.0
			if (raw.get("hooks", []) as Array).any(func(h): return kind in (h.get("gigs", []) as Array)):
				w = 3.0
			elif kind in (raw.get("gigs", []) as Array):
				w = 1.0
			if w <= 0.0:
				continue
			var l := World.location(String(id))   # its 1-3 level, derived from its code's intensity
			var rng: Array = l.get("security", [])
			if rng.size() < 2 or lv < int(rng[0]) or lv > int(rng[1]):
				continue
			var code := SecurityCode.normalise(raw.get("security_code"))
			if code.is_empty():
				code = SecurityCode.normalise(World.district(String(raw.get("district", ""))).get("security_code"))
			ids.append(id)
			ws.append(w * code_weight(int(code.get("n", 5)), known))
		if not ids.is_empty():
			return String(ids[_weighted(ws)])
	return ""


## A hook of location `l` that names `kind` (its text without the page cite), else "".
func _hook_for(l: Dictionary, kind: String) -> String:
	var hs: Array = (l.get("hooks", []) as Array).filter(func(h): return kind in (h.get("gigs", []) as Array))
	if hs.is_empty():
		return ""
	return strip_cite(String((_pick(hs) as Dictionary).get("text", "")))


## "... a waterfront shootout (p.81)." → "... a waterfront shootout."
static func strip_cite(s: String) -> String:
	var re := RegEx.create_from_string("\\s*\\((NC2045 )?pp?\\.[0-9][0-9 ,.\\-p]*\\)")
	return re.sub(s, "", true).strip_edges()


## Who the job is against: the location's owner if it can be the target of this kind of job, else
## its Security Code's faction if that can, else a gang of the district that can, else any faction
## that can (factions.json `gigs`: only gangs take gang hits, gangs never take data theft).
func _target_for(l: Dictionary, kind: String) -> String:
	var owner := String(l.get("owner", ""))
	var coder := String(SecurityCode.normalise(l.get("security_code")).get("faction", ""))
	for f in [owner, coder]:
		if f != "" and World.has_faction(f) and kind in World.targets_for_any(f):
			return f
	var gangs: Array = (World.district(String(l.get("district", ""))).get("gangs", []) as Array).filter(
		func(f): return World.has_faction(String(f)) and kind in World.targets_for_any(String(f)))
	if not gangs.is_empty():
		return String(_pick(gangs))
	var ids := World.targets_for(kind)
	return String(_pick(ids)) if not ids.is_empty() else World.DEFAULT_OPFOR


## A Fixer for a `kind` job in district `did` ("" any district): one working the district, else
## one from a neighbouring district, else anyone. Those who deal in what the job needs
## (gigs.json fixer_tags) weigh 3, the rest 1. HOUSE-RULE: a Fixer whose rank is more than 5 over
## the crew's best Reputation weighs a quarter (the big names rarely call a crew nobody knows).
func _pick_fixer(did: String, kind: String, known: int) -> Dictionary:
	var ids: Array = World.fixers_in(did) if did != "" else []
	if ids.is_empty() and did != "":
		for nb in World.neighbours(did):
			for id in World.fixers_in(String(nb)):
				if not id in ids:
					ids.append(id)
	if ids.is_empty():
		ids = World.fixers().keys()
	if ids.is_empty():
		return {}
	var want: Array = RulesDB.gen("gigs.json").get("fixer_tags", {}).get(kind, [])
	var ws: Array = []
	for id in ids:
		var f := World.fixer(String(id))
		var w := 3.0 if (f.get("deals_in", []) as Array).any(func(t): return t in want) else 1.0
		if int(f.get("rank", 0)) > known + 5:
			w *= 0.25
		ws.append(w)
	return World.fixer(String(ids[_weighted(ws)]))


## An index into `ws` picked with probability proportional to its weight.
func _weighted(ws: Array) -> int:
	var total := 0.0
	for w in ws:
		total += float(w)
	var r := dice.rng.randf() * total
	for i in ws.size():
		r -= float(ws[i])
		if r < 0.0:
			return i
	return ws.size() - 1


## A gig at a named location keeps to that place's security range.
static func _fit_location_security(gig: Dictionary) -> void:
	var l := World.location(String(gig.get("location", "")))
	if l.has("security"):
		gig.security = clampi(int(gig.security), int(l.security[0]), int(l.security[1]))


## The gig's Night City 2045 codes (NC2045 p.7-8): its district (the location's, else one whose
## neighbourhood generator is the gig's profile, if the city has one) and the codes
## SecurityCode.for_gig reads from the location, else the district, else the fallback for the
## gig's security level.
func _code_gig(gig: Dictionary) -> void:
	var did := String(World.location(String(gig.get("location", ""))).get("district", ""))
	if did == "" and String(gig.get("profile", "")) != "":
		var ds := World.districts_with_profile(String(gig.profile))
		if not ds.is_empty():
			did = _pick(ds)
	gig.merge(codes_for(gig, did), true)


## {district, security_code, district_code, utility_code} for `gig` in district `did` ("" none).
## The fallback code names the gig's target as the site's own people.
static func codes_for(gig: Dictionary, did: String) -> Dictionary:
	var c := SecurityCode.for_gig(World.location(String(gig.get("location", ""))), World.district(did),
		int(gig.get("security", 1)), String(gig.get("faction", "")))
	return {"district": did, "security_code": c.security_code, "district_code": c.district_code, "utility_code": c.utility_code}


## The board's line for a gig's Security Code: "SECURITY 6 · NCPD · HARDENED MEDIUM".
static func code_label(gig: Dictionary) -> String:
	var c: Variant = gig.get("security_code")
	if SecurityCode.normalise(c).is_empty():
		c = SecurityCode.from_level(int(gig.get("security", 1)), String(gig.get("faction", "")))
	return SecurityCode.label(c, String(gig.get("faction", "")))


## Encounter.setup options for a gig: its target faction and its codes, and a roll for one of the
## book's complications at the start (Complication; never known on the board).
static func encounter_opts(gig: Dictionary) -> Dictionary:
	var o := {"complications": true}
	if String(gig.get("faction", "")) != "":
		o["faction"] = String(gig.faction)
	for k in ["security_code", "district_code", "utility_code"]:
		if gig.has(k):
			o[k] = gig[k]
	return o


## A crew with a name (best Reputation >= unique_rep) sometimes gets a fixer's personal job:
## security 3, double pay (spec: "occasional unique offers"). At most one on the board. The Fixer
## is one of the data's (any district); the place is picked as for a generic offer.
func _unique_offer(g: Dictionary) -> void:
	if best_reputation() < int(g.get("unique_rep", 3)) or dice.d(3) != 1:
		return
	var t: Dictionary = g.unique_templates[dice.d(g.unique_templates.size()) - 1]
	var fx := _pick_fixer("", String(t.kind), best_reputation())
	var slots := {"fixer": String(fx.get("name", "A fixer")), "data": _pick(g.data), "place": _pick(t.get("places", ["site"]))}
	slots.merge(_target_slots(String(t.kind)))
	var sec := int(t.security)
	board.append({"id": "%d-u" % day, "kind": t.kind, "fixer": slots.fixer, "fixer_id": String(fx.get("id", "")), "faction": slots.faction,
		"title": _fill(_pick(_titles_for(t, String(slots.faction))), slots), "blurb": _fill(String(t.blurb), slots), "security": sec,
		"unique": true, "pay": int(int(g.pay[str(sec)]) * float(t.pay_mult)), "seed": dice.rng.randi_range(1, 99999)})
	board[-1].merge(_place_for(String(t.kind), g, String(slots.faction)))
	_code_gig(board[-1])


## The gig's target (World faction able to be the target of this kind) and the {corp}/{gang}
## names its text uses: the target's own name in its slot, another faction's in the other.
func _target_slots(kind: String) -> Dictionary:
	var ids := World.targets_for(kind)
	var fid: String = _pick(ids) if not ids.is_empty() else World.DEFAULT_OPFOR
	var corps: Array = World.factions().keys().filter(func(f): return World.kind(f) in ["corp", "service"] and not World.targets_for_any(f).is_empty())
	var gangs: Array = World.factions().keys().filter(func(f): return World.kind(f) == "gang")
	var gang_target := World.kind(fid) == "gang"
	return {"faction": fid,
		"corp": World.display_name(fid if not gang_target else String(_pick(corps))),
		"gang": World.display_name(fid if gang_target else String(_pick(gangs)))}


## Titles that name the target's kind of slot (or neither): no "Wetwork: Militech" on a gang hit.
static func _titles_for(t: Dictionary, fid: String) -> Array:
	var other := "{corp}" if World.kind(fid) == "gang" else "{gang}"
	var ok: Array = (t.titles as Array).filter(func(x): return not String(x).contains(other))
	return ok if not ok.is_empty() else t.titles


static func objective_for(g: Dictionary) -> String:
	return String(OBJECTIVES.get(String(g.get("kind", "")), "data"))


## Cyberpsychosis outside combat (spec: episodes "can trigger in or out of combat"). After a gig, each
## crew member at risk rolls their combat episode chance once (approved HOUSE-RULE table); an
## episode means lashing out at someone close: a crewmate takes 2d6 (never below 1 HP). Returns the
## names of those who had one.
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


## Reputation for a finished gig (CPR core p193): the GM awards a Level from the "who knows about
## you" table for a notable deed; it replaces a character's Reputation only if it is higher.
## RULES-UNVERIFIED reading: a won gig is the deed, and how far word of it travels is set by the
## target's security (1 a street job, 2 a guarded business, 3 a fortress) and whether it got loud
## (backup called in): Level = 2 x security - 1, +1 if loud. Security 1: 1 "anyone who was there
## knows" / loud 2 "stories have gotten around to immediate friends"; security 2: 3 "co-workers and
## casual acquaintances" / 4 "all over the local area"; security 3: 5 "others beyond your local area
## recognize your name" / 6 "know you on sight". Levels 7+ (news stories, headlines) aren't awarded yet.
static func deed_level(gig: Dictionary, e: Encounter) -> int:
	if e.state != "won":
		return 0
	return 2 * clampi(int(gig.get("security", 1)), 1, 3) - 1 + (1 if e.alarm >= 2 else 0)


## Where a gig happens: any scene whose tags fit the job (gigs.json scene_tags / kind_tags), or
## (raid_chance) a raid on a single site picked for the job. Returns {scene, profile, site}.
func _place_for(kind: String, g: Dictionary, faction := "") -> Dictionary:
	var owned := World.locations_for(faction, kind)   # the target's own places first (data/world/locations.json)
	if not owned.is_empty() and dice.rng.randf() < float(g.get("location_chance", 0.6)):
		return _place_at(String(_pick(owned)))
	if dice.rng.randf() < float(g.get("raid_chance", 0.0)) and g.raid_sites.has(kind):
		return {"scene": "lone_building", "profile": "", "site": _pick(g.raid_sites[kind])}
	var want: Array = g.kind_tags.get(kind, [])
	var fits: Array = g.scene_tags.keys().filter(func(sc): return (g.scene_tags[sc] as Array).any(func(t): return t in want))
	var pick: String = _pick(fits) if not fits.is_empty() else "lone_building"
	if pick.begins_with("neighborhood:"):
		return {"scene": "neighborhood", "profile": pick.get_slice(":", 1), "site": ""}
	return {"scene": pick, "profile": "", "site": ""}


## Where a gig at canon location `lid` is played: {scene, profile, site, location}.
static func _place_at(lid: String) -> Dictionary:
	var l := World.location(lid)
	return {"scene": String(l.get("scene", "neighborhood" if l.has("profile") else "lone_building")),
		"profile": String(l.get("profile", "")), "site": String(l.get("site", "")), "location": lid}


## The district a gig is in, by name ("" if none).
static func district_name(gig: Dictionary) -> String:
	var did := String(gig.get("district", ""))
	return String(World.district(did).get("name", "")) if did != "" else ""


## The gig's place as the board shows it: a site, a neighbourhood or a scene.
static func place_name(gig: Dictionary) -> String:
	if String(gig.get("location", "")) != "":
		return String(World.location(String(gig.location)).get("name", gig.location))
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
	active_gig = board[index].duplicate()
	var before := {}   # for the debrief: what each crew member already had going in
	for c in crew:
		before[c.display_name] = {"injuries": c.injuries.size(), "humanity": c.humanity}
	active_gig["before"] = before
	debrief.clear()   # the last gig's marks come off the crew cards
	say("Took '%s' from %s." % [active_gig.title, active_gig.fixer])
	return active_gig


# --- After the gig ----------------------------------------------------------------

## Settle the active gig from the finished encounter. Returns a report for the results screen.
func resolve(e: Encounter) -> Dictionary:
	var gig := active_gig
	var won := e.state == "won"
	var report := {"gig": gig, "won": won, "pay": 0, "reputation": {}, "ip": 0, "dead": [], "hurt": [], "episodes": []}
	var kit_of := {}
	report["kit_used"] = _settle_kits(kit_of)
	var went := crew.duplicate()   # everyone who went, the fallen included (the debrief lists them)
	var hooked_before := {}
	for c in crew:
		hooked_before[c.display_name] = c.addictions.duplicate()
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
	eb += report.pay
	report.episodes = _downtime_episodes()
	report["addicted"] = _addiction_checks()
	report.ip = int(IP_GROUP["failed" if not won else ("barely" if not report.dead.is_empty() else "together")])   # p410
	for c in crew:
		c.ip += report.ip
	# Reputation (p193): those who were there earn the deed's Level if it beats what they had.
	var lvl := deed_level(gig, e)
	for c in crew:
		if lvl > c.reputation and e.units.any(func(u): return u.c == c):
			c.reputation = lvl
			report.reputation[c.display_name] = lvl
	var heard := ""
	for nm in report.reputation:
		heard += ", %s Reputation %d" % [nm, int(report.reputation[nm])]
	say("%s: %s. %+d eb, %d IP each%s%s." % [gig.get("title", "Gig"), "done" if won else "failed",
		report.pay, report.ip, heard, (", lost " + ", ".join(report.dead)) if not report.dead.is_empty() else ""])
	report["members"] = _debrief_members(went, gig.get("before", {}), report, kit_of, hooked_before)
	debrief.assign(report.members)
	active_gig = {}
	day += 1
	refresh_board()
	update_market()
	return report


## One crew member's debrief: {name, role, look_seed, dead, ip, reputation (the new Level, 0 if
## unchanged), injuries (Critical Injuries taken on this gig), wound (Wound State name), hp,
## max_hp, kit (used or lost), lost (everything a fallen member had on them), addicted (drug names newly hooked on), episode, humanity_lost}.
func _debrief_members(went: Array, before: Dictionary, report: Dictionary, kit_of: Dictionary, hooked_before: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Combatant in went:
		var b: Dictionary = before.get(c.display_name, {})
		var new_inj: Array = c.injuries.slice(int(b.get("injuries", c.injuries.size()))).map(func(i): return String(i.get("name", i.get("id", "injury"))))
		var hooked: Array = c.addictions.filter(func(d): return not d in hooked_before.get(c.display_name, [])).map(
			func(d): return String(RulesDB.gear("drugs", d).get("name", d)))
		out.append({"name": c.display_name, "role": c.role, "look_seed": c.look_seed, "dead": c.dead,
			"ip": 0 if c.dead else int(report.ip), "reputation": int(report.reputation.get(c.display_name, 0)),
			"injuries": new_inj, "wound": WOUND_NAMES[c.wound_state()], "hp": c.hp, "max_hp": c.max_hp(),
			"kit": kit_of.get(c.display_name, []), "lost": _lost_gear(c, kit_of) if c.dead else [], "addicted": hooked, "episode": c.display_name in report.episodes,
			"humanity_lost": maxi(0, int(b.get("humanity", c.humanity)) - c.humanity) if c.tracks_humanity else 0})
	return out


## Everything a crew member who didn't come back had on them, one name per item: weapons (not
## the built-in ones, which are cyberware), worn armour, installed cyberware, consumable and utility.
static func _lost_gear(c: Combatant, kit_of: Dictionary) -> Array:
	var out: Array = []
	for w in c.weapons:
		if not w.builtin:
			out.append(w.display_name())
	for loc in ["head", "body"]:
		var a: ArmorPiece = c.armor.get(loc)
		if a:
			out.append(a.name + (" +1" if a.upgraded else ""))
	for cw in c.cyberware:
		out.append(String(RulesDB.cyberware(String(cw)).get("name", cw)))
	out.append_array(kit_of.get(c.display_name, []))
	return out


## The book's Wound State names (p220), by Combatant.Wound.
const WOUND_NAMES := ["Unhurt", "Lightly Wounded", "Seriously Wounded", "Mortally Wounded", "Dead"]


## The debrief entry for `c` (empty after the next gig starts).
func debrief_for(c: Combatant) -> Dictionary:
	for m in debrief:
		if String(m.get("name", "")) == c.display_name:
			return m
	return {}


## Short marks for a crew card of what the last gig changed: "+30 IP", "REPUTATION 3", a new
## Critical Injury, "ADDICTED: Synthcoke". Empty once the next gig starts.
func marks_for(c: Combatant) -> Array[String]:
	var m := debrief_for(c)
	var out: Array[String] = []
	if m.is_empty():
		return out
	if int(m.get("ip", 0)) > 0:
		out.append("+%d IP" % int(m.ip))
	if int(m.get("reputation", 0)) > 0:
		out.append("REPUTATION %d" % int(m.reputation))
	for i in m.get("injuries", []):
		out.append(String(i))
	for d in m.get("addicted", []):
		out.append("ADDICTED: %s" % String(d))
	if int(m.get("humanity_lost", 0)) > 0:
		out.append("-%d HUMANITY" % int(m.humanity_lost))
	return out


# --- Downtime ---------------------------------------------------------------------

## Rest: everyone heals BODY HP per day (p223), up to full, and magazines are refilled. The crew's
## best hand at Basic Tech spends the days repairing ablated armour they wear (repair_armor_work).
func rest(days := 1) -> void:
	for c in crew:
		var heal: int = c.raw_stat("BODY") * days
		c.hp = mini(c.max_hp(), c.hp + heal)
		for w in c.weapons:
			w.reload()
	repair_armor_work(24 * days)
	day += days
	refresh_board()
	update_market()
	say("Rested %d day%s." % [days, "s" if days > 1 else ""])


## Days of rest until everyone is back to full HP (BODY HP a day, p223). Critical Injuries need
## Treatment, not rest.
func days_to_recover() -> int:
	var days := 0
	for c in alive_crew():
		if c.hp < c.max_hp():
			days = maxi(days, ceili(float(c.max_hp() - c.hp) / float(maxi(1, c.raw_stat("BODY")))))
	return days


## Rest until everyone is healed. Returns the days it took.
func recover_until_healed() -> int:
	var days := days_to_recover()
	if days > 0:
		rest(days)
	return days


## Who repairs the crew's armour: the best TECH + Basic Tech on the crew (armour falls under Basic
## Tech, "all other items not covered by another TECH Skill", CPR core p140). Null with no crew.
func best_repairer() -> Combatant:
	var best: Combatant = null
	for c in alive_crew():
		if best == null or c.skill_base("basic_tech") > best.skill_base("basic_tech"):
			best = c
	return best


## Item Repair (CPR core p140): repairing an item to perfect condition is a TECH Skill Check whose DV
## and time come from its Price Category (Cheap/Everyday DV9 1 hour, Costly DV13 6 hours, Premium
## DV17 1 day, Expensive DV21 1 week, Very Expensive DV24 2 weeks, Luxury DV29 1 month). A failure
## shows halfway through and the repair starts again from scratch. `hours` of the repairer's time go
## to ablated pieces, quickest first; unfinished work carries over to the next rest. The book lists
## no materials cost for a repair. Returns the "<owner>'s <armour>" pieces finished.
func repair_armor_work(hours: int) -> Array[String]:
	var done: Array[String] = []
	var t := best_repairer()
	if t == null:
		return done
	var queue: Array = []
	for c in alive_crew():
		for loc in c.armor:
			var a: ArmorPiece = c.armor[loc]
			if a and a.sp < a.max_sp:
				queue.append([c, a])
	queue.sort_custom(func(x, y): return (x[1] as ArmorPiece).price() < (y[1] as ArmorPiece).price())
	for q in queue:
		var a: ArmorPiece = q[1]
		var need := ArmorPiece.repair_hours(a.price())
		var half := (need + 1) / 2
		while hours > 0 and a.sp < a.max_sp:
			if a.repair_work < half:   # the first half: whether it holds shows at the halfway mark
				var step := mini(hours, half - a.repair_work)
				a.repair_work += step
				hours -= step
				if a.repair_work < half:
					break
				if not Check.vs_dv(dice, t.skill_base("basic_tech"), ArmorPiece.maker_dv(a.price())).success:
					a.repair_work = 0
					say("%s botches the repair on %s's %s and starts over." % [t.display_name, (q[0] as Combatant).display_name, a.name])
					continue
			var rest_of := mini(hours, need - a.repair_work)
			a.repair_work += rest_of
			hours -= rest_of
			if a.repair_work >= need:
				a.repair()
				done.append("%s's %s" % [(q[0] as Combatant).display_name, a.name])
		if hours <= 0:
			break
	if not done.is_empty():
		say("%s repairs %s." % [t.display_name, ", ".join(done)])
	return done


## Clinic price, halved while a Trauma Surgeon is on the crew (HOUSE-RULE perk).
func treat_cost() -> int:
	var mult := 1.0
	for c in alive_crew():
		var d := float(c.perk_fx("treat_discount"))
		if d > 0.0:
			mult = minf(mult, d)
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


# --- Night Market and safehouse storage ---------------------------------------------

## The Night Market that's up (CPR core p.337-339; NightMarket, data/rules/night_market.json): two
## categories of goods and the types of items each has on sale. When it closes a new one is rolled
## (HOUSE-RULE open_days: the book gives no schedule).
func update_market() -> void:
	if not market.is_empty() and day < int(market.get("closes", 0)):
		return
	market = NightMarket.roll(dice, day)
	say("A Night Market sets up (%s) until day %d." % [NightMarket.title(market), int(market.closes)])


## Whether `key` can be bought now: on the market's listings, or one of the fixer's staples.
func on_sale(key: String) -> bool:
	return key in NightMarket.keys_of(market) or key in NightMarket.staples()


## Everything for sale now, the market's listings first, then the fixer's staples:
## {key, name, cost, kind: weapon|armor|kit|cyberware, kit: consumable|utility|"", listing (the
## book's row it came from), staple, owned (in storage), info}. Prices are list prices (p385 Market
## Price). Cyberware is bought into storage like the rest; the Med Bay installs it free (p338).
func market_stock() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for l in market.get("listings", []):
		for k in l.get("keys", []):
			if not seen.has(k):
				seen[k] = true
				out.append(_stock_entry(String(k), String(l.name), false))
	for k in NightMarket.staples():
		if not seen.has(k):
			seen[k] = true
			out.append(_stock_entry(k, "Fixer's staples", true))
	return out


func _stock_entry(key: String, listing: String, staple: bool) -> Dictionary:
	var sec := Items.section(key)
	return {"key": key, "name": Items.display_name(key), "cost": Items.price(key), "kind": sec if sec in ["weapon", "armor", "cyberware"] else "kit",
		"kit": Items.kind(key), "listing": listing, "staple": staple, "owned": stored(key), "info": item_info(key)}


## One line on what an item does, for the market and storage lists.
static func item_info(key: String) -> String:
	match Items.section(key):
		"weapon":
			var w := Items.make_weapon(key)
			var d := w.def
			var info := "%dd6" % int(d.dice) + ("" if d.get("melee", false) else " · ROF %d · %d rds" % [int(d.rof), int(d.mag)])
			info += String({"poor": " · jams on a 1", "excellent": " · +1 to hit"}.get(w.quality, ""))
			var wfx: Dictionary = d.get("fx", {})
			if int(wfx.get("min_body", 0)) > 0:
				info += " · BODY %d" % int(wfx.min_body)
			if String(wfx.get("requires", "")) != "":
				info += " · smartgun link"
			return info
		"armor":
			var a := Items.make_armor(key)
			return "SP %d" % a.max_sp + (" · -%d REF/DEX/MOVE" % a.penalty if a.penalty > 0 else "")
		"cyberware":
			return String(RIPPERDOC.get(Items.base_id(key), ["", ""])[1])
	return String(Items.def(key).get("summary", ""))


## Buy one into safehouse storage at list price. Nothing is bought for anyone, and owning one never
## stops you buying another. Cyberware too: it waits in storage until the Med Bay installs it.
func buy(key: String) -> bool:
	if not Items.is_stored(key) or not on_sale(key) or eb < Items.price(key):
		return false
	eb -= Items.price(key)
	_put(key)
	say("Bought %s" % Items.display_name(key))
	return true


## How many of `key` storage holds (kit counts include equipped consumables and utilities;
## equipped weapons and armour are on the crew member, not in storage; installed cyberware is part
## of them).
func stored(key: String) -> int:
	return int(stash.get(key, 0))


func _put(key: String, n := 1) -> void:
	stash[key] = stored(key) + n


func _take(key: String) -> bool:
	if stored(key) <= 0:
		return false
	stash[key] = stored(key) - 1
	if stored(key) <= 0:
		stash.erase(key)
	return true


## Weapon keys in storage, each once, in storage order.
func weapon_options() -> Array[String]:
	var out: Array[String] = []
	for k in stash:
		if Items.is_weapon(String(k)) and stored(String(k)) > 0:
			out.append(String(k))
	return out


## Cyberware keys in storage, waiting to be installed.
func cyberware_options() -> Array[String]:
	var out: Array[String] = []
	for k in stash:
		if Items.is_cyberware(String(k)) and stored(String(k)) > 0:
			out.append(String(k))
	return out


## Armour keys in storage (a piece goes on the head or the body, p97).
func armor_options() -> Array[String]:
	var out: Array[String] = []
	for k in stash:
		if Items.is_armor(String(k)) and stored(String(k)) > 0:
			out.append(String(k))
	return out


## Why `c` can't take `key` from storage now ("" if they can); `loc` for armour (head or body).
func equip_block(c: Combatant, key: String, loc := "body") -> String:
	if c == null or not c in alive_crew():
		return "not on the crew"
	if not (Items.is_weapon(key) or Items.is_armor(key)):
		return "not a weapon or armour"
	if stored(key) <= 0:
		return "not in storage"
	if Items.is_armor(key) and not c.armor.has(loc):
		return "no such location"
	return ""


## Take a weapon from storage. They carry it after what they already have (weapons[0] is the
## primary), or at index `at` if given. The book sets no limit on weapons carried.
func equip_weapon(c: Combatant, key: String, at := -1) -> bool:
	if equip_block(c, key) != "" or not Items.is_weapon(key):
		return false
	_take(key)
	var w := Items.make_weapon(key)
	if at < 0 or at >= c.weapons.size():
		c.weapons.append(w)
	else:
		c.weapons.insert(at, w)
	say("%s takes %s." % [c.display_name, w.display_name()])
	return true


## Move a carried weapon to position `to` in their weapons (weapons[0] is the one drawn first).
func reorder_weapon(c: Combatant, index: int, to: int) -> bool:
	if c == null or index < 0 or index >= c.weapons.size() or to < 0 or to >= c.weapons.size() or index == to:
		return false
	var w: Weapon = c.weapons[index]
	c.weapons.remove_at(index)
	c.weapons.insert(to, w)
	return true


## Put a carried weapon back in storage. Built-in cyberware weapons stay where they are.
func unequip_weapon(c: Combatant, index: int) -> bool:
	if c == null or index < 0 or index >= c.weapons.size() or c.weapons[index].builtin:
		return false
	var w: Weapon = c.weapons[index]
	c.weapons.remove_at(index)
	_put(Items.key_of_weapon(w))
	return true


## Wear an armour piece from storage at `loc`; what they wore there goes back to storage (with its
## upgrade and any ablation: armour is repaired only while worn).
func equip_armor(c: Combatant, loc: String, key: String) -> bool:
	if equip_block(c, key, loc) != "" or not Items.is_armor(key):
		return false
	_take(key)
	var old: ArmorPiece = c.armor.get(loc)
	c.armor[loc] = Items.make_armor(key)
	if old:
		_put(Items.key_of_armor(old))
	say("%s wears %s (%s)." % [c.display_name, (c.armor[loc] as ArmorPiece).name, loc])
	return true


func unequip_armor(c: Combatant, loc: String) -> bool:
	if c == null or c.armor.get(loc) == null:
		return false
	_put(Items.key_of_armor(c.armor[loc]))
	c.armor[loc] = null
	return true


## Storage validation: drop keys it can't hold (old or unknown items) and empty counts, then
## clear consumable and utility slots storage no longer backs.
func check_stash() -> void:
	for k in stash.keys():
		if not Items.is_stored(String(k)) or int(stash[k]) <= 0:
			stash.erase(k)
	check_kits()


# --- Ripperdoc (cyberware) ----------------------------------------------------------------

## What the ripperdoc installs: pieces whose effects the rules use, with the foundation each needs
## (p111-116: neuralware needs a Neural Link, cyberoptics a Cybereye, chipware a Chipware Socket,
## arm options a Cyberarm). A piece is bought from the Night Market that has it on sale (with the
## foundations it needs, p338) into safehouse storage like any gear; installing it later at the Med
## Bay costs nothing more (a Night Market sale includes the install, p338; the price includes the
## surgery, p110). Short effect summaries are our paraphrase.
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
## Humanity Loss therapies (gear.json "therapy", CPR core p230).
const HUMANITY_THERAPY := {"standard": "standard_humanity_therapy", "extreme": "extreme_humanity_therapy"}


## Why `c` can't have this stored piece installed now ("" if they can): already installed (the
## benefits of a second don't stack, p111), none in storage, or its foundation missing (p111).
func install_block(c: Combatant, id: String) -> String:
	if c == null or not c in alive_crew():
		return "not on the crew"
	if c.has_cyberware(id):
		return "installed"
	if stored("cyberware/" + id) <= 0:
		return "not in storage"
	var need: String = String(RIPPERDOC.get(id, ["", ""])[0])
	if need != "" and not c.has_cyberware(need):
		return "needs " + String(RulesDB.cyberware(need).name)
	return ""


## Install a piece from storage. Free: it came from a Night Market, whose sale includes the
## install (p338). Rolls the Humanity Loss (p110) and arms any built-in melee weapon (a hand-held
## melee weapon it replaces goes to storage). From then on it's part of `c`: it can be removed
## (remove), never moved to someone else. Returns the Humanity lost, -1 if it can't be done.
func install(c: Combatant, id: String) -> int:
	if install_block(c, id) != "":
		return -1
	var d := RulesDB.cyberware(id)
	_take("cyberware/" + id)
	var before := c.weapons.duplicate()
	var loss := c.install_cyberware(id, dice)
	for w in before:
		if not w in c.weapons and not w.builtin:
			_put(Items.key_of_weapon(w))
	say("%s gets %s installed (-%d Humanity)." % [c.display_name, d.name, loss])
	return loss


## Why this installed piece can't come out now ("" if it can): an installed option still needs it
## as its foundation (p111).
func remove_block(c: Combatant, id: String) -> String:
	if c == null or not c.has_cyberware(id):
		return "not installed"
	for other in c.cyberware:
		if String(RIPPERDOC.get(other, [""])[0]) == id:
			return "%s needs it" % String(RulesDB.cyberware(other).get("name", other))
	return ""


## Take an installed piece out at the Med Bay. It is destroyed, not stored: harvested chrome is
## worthless without a Cybertech repair (p226), and installed chrome is never moved to someone else
## (owner's ruling). The book prices no removal (p226 prices installing supplied chrome only), so
## it costs nothing (HOUSE-RULE: the crew's ripperdoc does it). Humanity lost isn't returned
## (Combatant.remove_cyberware).
func remove(c: Combatant, id: String) -> bool:
	if remove_block(c, id) != "":
		return false
	var nm := String(RulesDB.cyberware(id).get("name", id))
	c.remove_cyberware(id)
	say("%s has %s taken out." % [c.display_name, nm])
	return true


# --- Safehouse storage and kits (owner's design: 2 slots, 1 consumable + 1 utility) ---

## How many of `key` in storage nobody has equipped as their consumable or utility (except
## `skip_c`'s `skip_slot`).
func unpacked(key: String, skip_c: Combatant = null, skip_slot := -1) -> int:
	var n := int(stash.get(key, 0))
	for m in alive_crew():
		for i in m.kit.size():
			if m.kit[i] == key and not (m == skip_c and i == skip_slot):
				n -= 1
	return n


## Equip (or with "" put back) a consumable or utility. The slot must accept the item's kind and
## storage must have one that nobody else has equipped.
func set_kit(c: Combatant, slot: int, key: String) -> bool:
	if slot < 0 or slot >= c.kit.size() or not Items.fits(slot, key):
		return false
	if key != "" and unpacked(key, c, slot) <= 0:
		return false
	c.kit[slot] = key
	return true


## Items each slot could take for `c` right now (owned, not equipped by anyone else, the right kind).
func kit_options(c: Combatant, slot: int) -> Array[String]:
	var out: Array[String] = []
	for key in stash:
		if Items.fits(slot, String(key)) and unpacked(String(key), c, slot) > 0:
			out.append(String(key))
	return out


## Clear equipped consumables and utilities storage can no longer back (spent or lost on the last gig).
func check_kits() -> void:
	for m in alive_crew():
		for i in m.kit.size():
			if m.kit[i] != "" and (not Items.fits(i, m.kit[i]) or unpacked(m.kit[i], m, i) <= 0):
				m.kit[i] = ""


## After a gig: spent consumables leave storage; whoever didn't come back loses what they carried.
## Returns the names of what was used or lost.
func _settle_kits(per: Dictionary = {}) -> Array:
	var gone := []
	for m in crew:
		for i in m.kit.size():
			var key := m.kit[i]
			if key == "":
				continue
			if m.dead or (m.kit_spent[i] and Items.kind(key) == "consumable"):
				stash[key] = maxi(0, int(stash.get(key, 0)) - 1)
				if int(stash[key]) == 0:
					stash.erase(key)
				gone.append(Items.display_name(key))
				per[m.display_name] = per.get(m.display_name, []) + [Items.display_name(key)]
	check_kits()
	return gone


const RELAPSE_DAYS := 365   ## p230: a year after Addiction Therapy

## Addiction (p.229): after the gig, each drug taken calls for WILL + Resist Torture/Drugs vs its
## Addiction DV; failing hooks them. Black Lace's Humanity comes back to those who resist (p.358).
func _addiction_checks() -> Array:
	var hooked := []
	for m in alive_crew():
		var seen := {}
		for drug in m.drugs_taken:
			if seen.has(drug):
				continue
			seen[drug] = true
			var fx: Dictionary = RulesDB.gear("drugs", drug).get("fx", {})
			# p230: for a year after getting clean of it, the roll against this drug fails automatically
			var relapse := m.clean_since.has(drug) and day < int(m.clean_since[drug]) + RELAPSE_DAYS
			var resisted := not relapse and Check.vs_dv(dice, m.skill_base("resist_torture_drugs"), int(fx.get("addiction_dv", 15))).success
			if resisted:
				if fx.get("humanity_refund_on_resist", false) and int(m.drug_humanity.get(drug, 0)) > 0:
					m.regain_humanity(int(m.drug_humanity[drug]))
			elif not drug in m.addictions:
				m.addictions.append(drug)
				hooked.append("%s (%s)" % [m.display_name, RulesDB.gear("drugs", drug).get("name", drug)])
				say("%s is hooked on %s." % [m.display_name, RulesDB.gear("drugs", drug).get("name", drug)])
		m.drug_humanity.clear()
	return hooked


## Who can give `patient` therapy (Addiction or Humanity Loss): the crew's best Medtech other than the patient (CPR
## core p229: a Medtech performs therapy with the Medical Tech Skill, only Medtechs have it (p150),
## and not on themselves). Null if nobody can.
func therapist_for(patient: Combatant) -> Combatant:
	var best: Combatant = null
	for m in alive_crew():
		if m != patient and m.role == "medtech" and (best == null or m.therapy_base() > best.therapy_base()):
			best = m
	return best


## Addiction Therapy (CPR core p229-230): a week in which doctor and patient do nothing else (the
## crew rests); the Medtech buys the materials (500eb) from Biotechnica and, at the end of the week,
## rolls TECH + Medical Tech vs DV15. Success frees the patient of one addiction, and for a year they
## automatically fail that drug's Secondary Effect roll; failure wastes the week and the materials.
## Returns {} if it can't be done, else {success}.
func treat_addiction(c: Combatant, drug: String) -> Dictionary:
	var fx: Dictionary = RulesDB.gear("therapy", "addiction_therapy").get("fx", {})
	var doc := therapist_for(c)
	var cost := int(fx.get("materials_cost", 500))
	if not drug in c.addictions or doc == null or eb < cost:
		return {}
	eb -= cost
	var ok := Check.vs_dv(dice, doc.therapy_base(), int(fx.get("dv", 15))).success
	var drug_name := String(RulesDB.gear("drugs", drug).get("name", drug))
	if ok:
		c.addictions.erase(drug)
		c.clean_since[drug] = day + 7
		say("%s spends a week with %s getting clean of %s." % [c.display_name, doc.display_name, drug_name])
	else:
		say("%s's week of therapy with %s doesn't take: still hooked on %s." % [c.display_name, doc.display_name, drug_name])
	rest(7)
	return {"success": ok}


## Materials for a Humanity Loss therapy ("standard" or "extreme"), eb.
static func humanity_therapy_cost(kind := "standard") -> int:
	return int(RulesDB.gear("therapy", String(HUMANITY_THERAPY.get(kind, ""))).get("fx", {}).get("materials_cost", 0))


## Humanity Loss Therapy (CPR core p229-230), the way Addiction Therapy works (treat_addiction): a
## week in which doctor and patient do nothing else (the crew rests); the crew's Medtech (not the
## patient) buys the materials from Biotechnica (Standard 100eb, Extreme 500eb) and at the end of
## the week rolls TECH + Medical Tech vs DV15 (Standard) or DV17 (Extreme). Success: the patient
## regains 2d6 (Standard) or 4d6 (Extreme) lost Humanity, never past their maximum (each piece of
## chrome lowers it, p230). Failure wastes the week and the materials.
## Returns {} if it can't be done, else {success, gained}.
func humanity_therapy(c: Combatant, kind := "standard") -> Dictionary:
	if not HUMANITY_THERAPY.has(kind):
		return {}
	var fx: Dictionary = RulesDB.gear("therapy", String(HUMANITY_THERAPY[kind])).get("fx", {})
	var doc := therapist_for(c)
	var cost := int(fx.get("materials_cost", 0))
	if not c.tracks_humanity or c.humanity >= c.max_humanity or doc == null or eb < cost:
		return {}
	eb -= cost
	var ok := Check.vs_dv(dice, doc.therapy_base(), int(fx.get("dv", 15))).success
	var gained := 0
	if ok:
		var before := c.humanity
		c.regain_humanity(Combatant.roll_hl(dice, String(fx.get("regain_humanity", "2d6"))))
		gained = c.humanity - before
		say("%s spends a week in therapy with %s (+%d Humanity)." % [c.display_name, doc.display_name, gained])
	else:
		say("%s's week of therapy with %s doesn't take." % [c.display_name, doc.display_name])
	rest(7)
	return {"success": ok, "gained": gained}


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


# --- Save / load ------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": SaveMigrations.CURRENT, "seed": seed_value, "eb": eb, "day": day, "crew": crew.map(func(c): return c.to_dict()),
		"fallen": fallen, "board": board, "recruits": recruits.map(func(c): return c.to_dict()), "log": log.slice(-50),
		"rng_state": dice.rng.state, "stash": stash, "market": market, "debrief": debrief}


## A campaign from a save dictionary, upgraded to the current format first (SaveMigrations).
## Null if the save is from a newer build.
static func from_dict(raw: Dictionary) -> Campaign:
	var d := SaveMigrations.migrate(raw)
	if d.is_empty():
		return null
	var c := Campaign.new()
	c.seed_value = int(d.seed)
	c.dice = Dice.new(c.seed_value)
	c.dice.rng.state = int(d.get("rng_state", c.dice.rng.state))
	c.eb = int(d.eb)
	c.day = int(d.day)
	for cd in d.crew:
		c.crew.append(Combatant.from_dict(cd))
	for f in d.fallen:
		c.fallen.append(f)
	for b in d.board:
		c.board.append(b)
	for r in d.get("recruits", []):
		c.recruits.append(Combatant.from_dict(r))
	for k in d.get("stash", {}):
		if Items.is_stored(String(k)) and int(d.stash[k]) > 0:
			c.stash[String(k)] = int(d.stash[k])
	c.market = d.get("market", {})
	for k in ["opened", "closes"]:   # JSON numbers come back as floats
		if c.market.has(k):
			c.market[k] = int(c.market[k])
	for l in d.get("log", []):
		c.log.append(String(l))
	for m in d.get("debrief", []):
		if m is Dictionary:
			c.debrief.append(m)
	c.update_market()   # a save from before markets (v5) gets one now
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
