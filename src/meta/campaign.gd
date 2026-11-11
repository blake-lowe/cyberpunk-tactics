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
const OBJECTIVES := {"data_theft": "data", "gang_hit": "eliminate", "corp_extraction": "snatch", "assassination": "assassinate", "rescue": "rescue", "sabotage": "sabotage",
	"escort": "escort", "defense": "defend", "delivery": "deliver", "plant": "plant", "distraction": "distraction"}
## Downtime assignments (spec: "assign downtime actions"): only what the book has a rule for.
## Recover: natural healing, BODY HP a day (p223). (The book has no rule for earning IP or eb in
## downtime: IP come from the GM after a session, p410.)
const DOWNTIME := {
	"recover": {"name": "Rest", "desc": "Heal BODY HP a day."},   # CPR core p.223
}

## Where a new crew holds up: Little China, a mid-band district (Security Code 4-5, NC2045 p.18) in
## the middle of the city, next to the Hot Zone and the Heywood docks: a warehouse there is cheap
## and every gig is a short drive. HOUSE-RULE: the book gives the crew no home district.
const DEFAULT_SAFEHOUSE := "little_china"
## Districts no gig is ever offered in. Playland by the Sea was descoped by the owner: its 52 canon
## locations stay in the world data (book facts) and the city map shows the district, but no job
## is placed there, at one of its locations or by its neighbourhood profile.
const NO_GIGS := ["playland"]
const DAY_MINUTES := 24 * 60

static var current: Campaign   ## the running campaign (the board and the tactical view share it)
## The save slot autosave writes (SaveSlots; the title screen picks it, 1 when launched directly).
static var slot := 1

var seed_value := 1
var dice: Dice
var eb := 0
var day := 1
## Minutes past the start of `day` (the drives to gigs, Travel; they roll over into days). Rest
## advances whole days and leaves the time of day as it is.
var minutes := 0
## The district the crew's safehouse is in: where every drive to a gig starts (Travel).
var safehouse_district := DEFAULT_SAFEHOUSE
var crew: Array[Combatant] = []
var fallen: Array[Dictionary] = []   ## {name, role, day, gig}: the wall
var board: Array[Dictionary] = []    ## gig offers
var recruits: Array[Combatant] = []  ## for hire
var active_gig: Dictionary = {}
var gigs_done := 0                   ## gigs played to the end (won or failed), for the save slot listing
var stash := {}                      ## safehouse storage: Items key → how many (kit, weapons, armour)
## Plot hooks found on bodies (CorpseLoot, SPM p.65-70): {label, hook, day, gig, faction, district,
## location, from}, oldest first. Kept for later follow-up offers; listed on the debrief and in storage.
var leads: Array[Dictionary] = []
var market := {}                     ## the Night Market that's up (NightMarket.roll)
var log: Array[String] = []
## What the last gig changed for each crew member (resolve's report "members"), shown on the
## debrief screen and as marks on crew cards until the next gig starts. Saved.
var debrief: Array[Dictionary] = []
## DEV ONLY: custom gigs taken (accept_custom), and the last one's form for REPEAT. Saved, so a
## save that has played dev gigs says so.
var dev_gigs := 0
var last_custom: Dictionary = {}
## Payment in information (MissionBuilder, SPM p.28 step 4): intel tokens. While the crew holds one,
## every offer on the board shows whether it runs into a complication (foresee); taking a gig
## spends one. Saved.
var intel := 0
## Payment in favours: tokens kept until used, {kind: "treatment" | "market", cap (market: the
## dearest item it covers), from (the fixer), day}. A treatment favour pays for one Med Bay
## Treatment (treat); a market favour for one Night Market item up to its cap (buy_cart). Saved.
var favours: Array[Dictionary] = []


## The running campaign: the one in memory, else the save, else a new game.
static func ensure_current() -> Campaign:
	if current == null:
		SaveSlots.migrate_legacy()
		current = load_from()
		if current == null or current.crew.is_empty():
			current = new_game(int(Time.get_unix_time_from_system()) % 100000)
	return current


static func new_game(p_seed: int) -> Campaign:
	var c := Campaign.new()
	c.seed_value = p_seed
	c.dice = Dice.new(p_seed)
	c.eb = int(ECON.start_eb)
	c.crew.append(Recruit.generate(c.dice, "solo", "edgerunner", "", [], 0))
	c.crew.append(Recruit.generate(c.dice, "netrunner", "edgerunner", "", c.names_taken(), 1))
	for i in c.crew.size():
		c.crew[i].look_seed = i
	c.update_market()   # first: a goods payment on the first board draws from what is on sale
	c.refresh_board()
	c.refresh_recruits()
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
## Fixer working the district has at a canon location (data/world/locations.json, fixers.json),
## built in the Mission Builder's steps (MissionBuilder, SPM p.28: client, mission type, focus,
## payment, a twist hook): the gig kind comes from the rolled mission type, its security level is rolled against the crew's best
## Reputation as before (better jobs need a name, p193) and picks a location of that level (the
## location's Security Code intensity, World.location) whose hooks name the kind (else whose `gigs`
## include it), weighted toward Security Codes near what the crew's name can take on
## (code_weight). The location's hook is the job's pitch; its owner (else its code's faction, else
## a district gang) is the target. Every offer is at a canon place (owner ruling 2026-11-04: no
## generic places): when no place fits the template's kind at the rolled level or below, the other
## kinds are tried in a shuffled order. Pay scales with security.
func refresh_board() -> void:
	var g := RulesDB.gen("gigs.json")
	board.clear()
	var used := {}
	_fill_board(g, used)
	_tower_offer(g, used)
	_unique_offer(g, used)
	foresee()


## Intel paid for an earlier job (MissionBuilder payment "information"): while the crew holds a
## token, every offer not yet foreseen has its complication question asked now, on the campaign's
## dice, with the same Oracle likelihood the gig itself would use (Complication.likelihood by its
## security level): the answer is kept on the offer as `intel` ("trouble" | "clean") and its
## `complication` (a forced roll, or none), which the encounter then plays (encounter_opts).
func foresee() -> void:
	if intel <= 0:
		return
	for b in board:
		if b.has("intel"):
			continue
		var ans := Complication.ask(dice, int(b.get("security", 1)))
		b["intel"] = "trouble" if bool(ans.yes) else "clean"
		b["complication"] = {"roll": dice.d(10)} if bool(ans.yes) else CustomGig.NONE


## How many ordinary offers the board holds: 3, 4 once the crew has a name (Reputation 3).
func board_size() -> int:
	return 3 + (1 if best_reputation() >= 3 else 0)


## Add offers at canon places until the board holds board_size() ordinary ones (refresh_board;
## Campaign.from_dict tops up a board whose generic offers the v14 migration dropped). `used`
## collects the places on the board, so no place has two offers.
func _fill_board(g: Dictionary, used: Dictionary) -> void:
	var known := best_reputation()
	var ids := {}
	for b in board:
		ids[String(b.get("id", ""))] = true
		if String(b.get("location", "")) != "":
			used[String(b.location)] = true
	var have := board.filter(func(b): return not b.get("unique", false)).size()
	var k := 0
	for i in maxi(0, board_size() - have):
		# Mission Builder step 2 first (SPM p.72): the mission type decides the kind of job, and the
		# kind which places can host it; the other steps follow once the place is known.
		var mt := MissionBuilder.roll_mission(dice)
		var kind := MissionBuilder.kind_of(mt)
		var sec := _roll_security(g, known)
		var gig := _city_offer(g, kind, sec, known, used, mt)
		if gig.is_empty():
			var others: Array = (g.templates as Array).filter(func(x): return String(x.kind) != kind)
			for j in range(others.size() - 1, 0, -1):   # Fisher-Yates on the campaign's dice
				var r := dice.rng.randi_range(0, j)
				var tmp: Variant = others[j]
				others[j] = others[r]
				others[r] = tmp
			for t2 in others:
				gig = _city_offer(g, String(t2.kind), sec, known, used)   # its mission rolled among the kind's rows
				if not gig.is_empty():
					break
		if gig.is_empty():
			push_warning("refresh_board: no canon place for any job at security %d" % sec)
			continue
		while ids.has("%d-%d" % [day, k]):
			k += 1
		gig["id"] = "%d-%d" % [day, k]
		ids[gig.id] = true
		board.append(gig)


## The security level for an offer: 1, or higher if the crew's best Reputation reaches it
## (rep_for_security) and a d10 comes up (2: 4 in 10, 3: 3 in 10).
func _roll_security(g: Dictionary, known: int) -> int:
	for s in [3, 2]:
		if known >= int(g.rep_for_security[str(s)]) and dice.d(10) <= (4 if s == 2 else 3):
			return s
	return 1


## An offer for a `kind` job at a canon location, or {} if none fits the kind at `sec` or below.
## The place, target, fixer, level and rate are the board's; the Mission Builder (MissionBuilder)
## then adds the client, the mission (`mt` if given), the focus, the payment and the twist hook,
## and its mission type and framing make the title and the pitch.
func _city_offer(g: Dictionary, kind: String, sec: int, known: int, used: Dictionary, mt: Dictionary = {}) -> Dictionary:
	var lid := _pick_location(kind, sec, known, used)
	if lid == "":
		return {}
	used[lid] = true
	var l := World.location(lid)
	var did := String(l.get("district", ""))
	var fid := _target_for(l, kind)
	var rng: Array = location_levels(l, fid)
	if rng.size() < 2:
		rng = [sec, sec]
	var level := clampi(sec, int(rng[0]), int(rng[1]))   # the place's own range (its code's intensity, if it guards the place)
	var fx := _pick_fixer(did, kind, known)
	var hook := _hook_for(l, kind)
	var where := String(World.district(did).get("name", did))
	var gig := {"kind": kind, "fixer": String(fx.get("name", "A fixer")), "fixer_id": String(fx.get("id", "")),
		"faction": fid, "location": lid, "district": did, "hook": hook,
		"security": level, "pay": int(g.pay[str(level)]), "seed": dice.rng.randi_range(1, 99999)}
	gig.merge(_place_at(lid))
	gig["mood"] = gig_mood(int(gig.seed), did, String(gig.scene))   # its weather (Atmosphere, NCW odds)
	gig.merge(codes_for(gig, did), true)
	if not mt.is_empty():
		gig["mission"] = mt
	build_mission(gig)
	var pitch := MissionBuilder.pitch(gig, World.display_name(fid))
	if hook != "":   # the place's own hook (NC2045) says why this job is here
		pitch = (pitch + " " if pitch != "" else "") + hook.left(1).to_upper() + hook.substr(1)
	gig["title"] = "%s: %s" % [String(gig.mission.get("label", kind.capitalize())), String(l.name)]
	gig["blurb"] = "%s has work at %s (%s): %s" % [String(gig.fixer), String(l.name), where, pitch]
	return gig


## Run the Mission Builder's steps on a placed offer (MissionBuilder.run) with the campaign's dice;
## goods payments draw from what is on sale today (goods_pool).
func build_mission(gig: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var o := {"goods": func(v: int) -> Array: return goods_pool(v)}
	o.merge(opts, true)
	return MissionBuilder.run(dice, gig, o)


## Storage keys a goods payment worth up to `value` eb may be (HOUSE-RULE: something the Night
## Market or the fixer sells today, worth at least a third of `value`), in storage-key order.
func goods_pool(value: int) -> Array:
	var out: Array = []
	for s in market_stock():
		var p := int(s.cost)
		if p <= value and p * 3 >= value and Items.is_stored(String(s.key)):
			out.append(String(s.key))
	out.sort()
	return out


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
			if String(raw.get("district", "")) in NO_GIGS or not place_fits(String(id), kind):
				continue
			var w := 0.0
			if (raw.get("hooks", []) as Array).any(func(h): return kind in (h.get("gigs", []) as Array)):
				w = 3.0
			elif kind in (raw.get("gigs", []) as Array) or hosted_at(raw, kind):
				w = 1.0
			if w <= 0.0:
				continue
			var rng: Array = location_levels(World.location(String(id)))   # its 1-3 levels

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


## The gig kinds whose places and targets a `kind` job borrows (gigs.json hosts: the canon world
## data names the first six kinds only), the kind itself first.
static func host_kinds(kind: String) -> Array:
	var out: Array = [kind]
	for k in ((RulesDB.gen("gigs.json").get("hosts", {}) as Dictionary).get(kind, []) as Array):
		if not String(k) in out:
			out.append(String(k))
	return out


## Does location `l` (raw or World.location) host a `kind` job through a kind it borrows from
## (host_kinds): its `gigs` or a hook names one?
static func hosted_at(l: Dictionary, kind: String) -> bool:
	var hk := host_kinds(kind)
	hk.remove_at(0)
	if hk.is_empty():
		return false
	if (l.get("gigs", []) as Array).any(func(k): return String(k) in hk):
		return true
	return (l.get("hooks", []) as Array).any(func(h): return (h.get("gigs", []) as Array).any(func(k): return String(k) in hk))


## The gig kinds a location offers: those its hooks and `gigs` name, then every kind that borrows
## one of them (host_kinds), in OBJECTIVES order.
static func kinds_at(l: Dictionary) -> Array:
	var out: Array = []
	for h in l.get("hooks", []):
		for k in h.get("gigs", []):
			if not String(k) in out:
				out.append(String(k))
	for k in l.get("gigs", []):
		if not String(k) in out:
			out.append(String(k))
	for k in OBJECTIVES:
		if not String(k) in out and hosted_at(l, String(k)):
			out.append(String(k))
	return out


## Can faction `fid` be the target of a `kind` job? Its factions.json `gigs` name the kind or one
## it borrows (host_kinds).
static func targetable(fid: String, kind: String) -> bool:
	var ts := World.targets_for_any(fid)
	return host_kinds(kind).any(func(k): return k in ts)


## Every faction that can be the target of a `kind` job (targetable).
static func targets_for(kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in World.factions():
		if targetable(String(id), kind):
			out.append(String(id))
	return out


## Can a `kind` job be played at canon location `lid`? A data theft (or a plant, which can go in by
## the NET) needs a NET, so never at a site generated without one (sites.json `networked: false`:
## shacks, squats).
static func place_fits(lid: String, kind: String) -> bool:
	if not String(OBJECTIVES.get(kind, "")) in ["data", "plant"]:
		return true
	var site := String(World.location(lid).get("site", ""))
	return site == "" or bool((RulesDB.gen("sites.json").get(site, {}) as Dictionary).get("networked", true))


## May a gig be offered at canon location `lid`? Not in a district on NO_GIGS.
static func offered_at(lid: String) -> bool:
	return not String(World.locations().get(lid, {}).get("district", "")) in NO_GIGS


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
		if f != "" and World.has_faction(f) and targetable(f, kind):
			return f
	var gangs: Array = (World.district(String(l.get("district", ""))).get("gangs", []) as Array).filter(
		func(f): return World.has_faction(String(f)) and targetable(String(f), kind))
	if not gangs.is_empty():
		return String(_pick(gangs))
	var ids := targets_for(kind)
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


## The 1-3 security levels a gig at location `l` against `target` can have: the entry's own
## `security` if it names one; else its Security Code's intensity (SecurityCode.level: Light 1,
## Medium 2, Heavy 3) when the code's faction guards the place (SecurityCode.guarded_by: the
## target's own people, or a contractor guarding it for the owner); else any level, because an
## outside authority's code (NCPD's interest in a private shop, NC2045 p.7) decides who answers a
## call, not how the place is guarded. With no target, the owner (else the code's faction) stands
## in. [] for a location with neither. This level is the one way a code's intensity reaches the
## guards on the posts (Encounter.setup): the crew-size shift sizes responses only.
static func location_levels(l: Dictionary, target := "") -> Array:
	var raw: Dictionary = World.locations().get(String(l.get("id", "")), {})
	if raw.has("security"):
		return raw.security
	var code := SecurityCode.normalise(l.get("security_code"))
	if code.is_empty():
		return l.get("security", [])
	var owner := String(l.get("owner", ""))
	var site := target if target != "" else (owner if owner != "" else String(code.faction))
	if SecurityCode.guarded_by(code, site, owner) == "":
		return [1, 3]
	var lv := SecurityCode.level(code)
	return [lv, lv]


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


## Encounter.setup options for a gig: its target faction and its codes, the location's owner, who
## holds the posts under the site code (SecurityCode.guarded_by, with that owner), and rolls at the start for
## one of the book's complications (Complication; never known on the board) and for whether the
## Utility Code comes into play (SecurityCode.utilities_happen); the detection clock on a stealth
## gig (Clocks, SPM p.25) and the offer's hidden plot twist (Twist, SPM p.75-76), if it has one.
static func encounter_opts(gig: Dictionary) -> Dictionary:
	var o := {"complications": true, "utilities": true, "clocks": "auto"}
	if gig.get("twist") is Dictionary:
		o["twist"] = (gig.twist as Dictionary).duplicate(true)
	if gig.get("scene_event") is Dictionary:   # the street round it (SceneEvent), rolled when the gig started
		o["scene_event"] = (gig.scene_event as Dictionary).duplicate(true)
	if String(gig.get("faction", "")) != "":
		o["faction"] = String(gig.faction)
	for k in ["security_code", "district_code", "utility_code", "district"]:
		if gig.has(k):
			o[k] = gig[k]
	var owner := String(World.location(String(gig.get("location", ""))).get("owner", ""))
	if owner != "":
		o["owner"] = owner   # a venue code's staff are the owner's people (SecurityCode.respondent)
	var code := SecurityCode.normalise(gig.get("security_code"))
	if not code.is_empty():
		o["guards"] = SecurityCode.guarded_by(code, String(gig.get("faction", World.DEFAULT_OPFOR)), owner)
	# A dev gig's dials (CustomGig): its complication and utilities as the builder set them.
	var cx: Variant = gig.get("complication")
	if cx is Dictionary:
		o["complication"] = cx
	elif cx is String and cx == CustomGig.NONE:
		o["complications"] = false
	var ut := String(gig.get("utility", ""))
	if ut == CustomGig.NONE:
		o["utilities"] = false
		o["utility_code"] = 0
	elif ut == "roll":
		o["utilities"] = false
	elif ut != "":
		o["outages"] = Array(ut.split(",", false))
	return o


## A crew with a name (best Reputation >= unique_rep) sometimes gets a fixer's personal job:
## security 3, double pay (spec: "occasional unique offers"). At most one on the board. The Fixer
## is one of the data's (any district). The place is canon, like every offer's: one of the target's
## own places for the job when it has one free, else a place for the job as the board picks them
## (_pick_location), whose target (_target_for) the job is then against.
func _unique_offer(g: Dictionary, used: Dictionary = {}) -> void:
	if best_reputation() < int(g.get("unique_rep", 3)) or dice.d(3) != 1:
		return
	var t: Dictionary = g.unique_templates[dice.d(g.unique_templates.size()) - 1]
	var sec := int(t.security)
	var kind := String(t.kind)
	var slots := _target_slots(kind)
	var owned: Array = World.locations_for(String(slots.faction), kind).filter(func(id): return offered_at(String(id)) and place_fits(String(id), kind) and not used.has(id))
	var lid: String = String(_pick(owned)) if not owned.is_empty() else _pick_location(kind, sec, best_reputation(), used)
	if lid == "":
		return
	used[lid] = true
	var l := World.location(lid)
	if owned.is_empty():
		slots = _target_slots(kind, _target_for(l, kind))
	var fx := _pick_fixer("", kind, best_reputation())
	slots.merge({"fixer": String(fx.get("name", "A fixer")), "place": String(l.name).trim_prefix("The ")}, true)
	var gig := {"id": "%d-u" % day, "kind": kind, "fixer": slots.fixer, "fixer_id": String(fx.get("id", "")), "faction": slots.faction,
		"security": sec, "unique": true, "pay": int(int(g.pay[str(sec)]) * float(t.pay_mult)), "seed": dice.rng.randi_range(1, 99999)}
	gig.merge(_place_at(lid))
	var did := String(l.get("district", ""))
	gig["mood"] = gig_mood(int(gig.seed), did, String(gig.scene))   # its weather (Atmosphere, NCW odds)
	gig.merge(codes_for(gig, did), true)
	build_mission(gig, {"payment": "eb", "focus": String(t.get("focus", ""))})   # a personal job pays its promised eb
	slots.merge(MissionBuilder.item_slots(gig.focus), true)
	gig["title"] = _fill(_pick(_titles_for(t, String(slots.faction))), slots)
	gig["blurb"] = "%s At %s (%s)." % [_fill(String(t.blurb), slots), String(l.name), district_name(gig)]
	board.append(gig)


## Tower gigs (docs/plans/towers.md; owner 2026-11-08: rare, gated to later progression, a good
## mix of high-rise and ordinary gigs). HOUSE-RULE: once the crew's best Reputation reaches
## gigs.json `tower.rep` (4: "all over the local area", CPR p.193; a corp's sky floors don't open
## to nobodies), a board has one chance in `tower.chance_in` (4) of one tower offer, which takes the
## place of its last ordinary offer, so the board keeps its size and most offers stay low-rise.
## Before the gate no board rolls for one (its dice are untouched: early boards are as they were).
## The other offers at a tower's location still play its street-level building.
func _tower_offer(g: Dictionary, used: Dictionary) -> void:
	var tw: Dictionary = g.get("tower", {})
	if tw.is_empty() or not tower_unlocked(g) or dice.d(int(tw.get("chance_in", 4))) != 1:
		return
	var ids: Array = World.towers().keys().filter(func(id): return offered_at(String(id)) and not used.has(id) \
		and not (World.tower(String(id)).get("bands", {}) as Dictionary).is_empty())
	if ids.is_empty():
		return
	ids.sort()
	var lid := String(ids[dice.d(ids.size()) - 1])
	var gig := tower_gig(g, lid, "", TowerGen.DEFAULT_BAND)
	if gig.is_empty():
		return
	used[lid] = true
	var ordinary: Array = board.filter(func(b): return not b.get("unique", false))
	if ordinary.size() >= board_size():   # the tower job takes the place of the last ordinary offer
		var last: Dictionary = ordinary[-1]
		gig["id"] = String(last.get("id", "%d-t" % day))
		used.erase(String(last.get("location", "")))
		board.erase(last)
	else:
		gig["id"] = "%d-t" % day
	board.append(gig)


## Tower offers are open to this crew: its best Reputation reaches gigs.json tower.rep.
func tower_unlocked(g: Dictionary = {}) -> bool:
	if g.is_empty():
		g = RulesDB.gen("gigs.json")
	return best_reputation() >= int(g.get("tower", {}).get("rep", 4))


## A tower gig at tower location `lid`: a `kind` job (else one of the band's, drawn) in band `bid`
## of the tower (TowerGen), offered by a Fixer working the district, against the place's target as
## any offer there (_target_for), at the place's own security level. Pay: the level's, times
## gigs.json tower.pay_mult (HOUSE-RULE: a job sixty storeys up pays for the ride). {} if the
## tower has no such band.
func tower_gig(g: Dictionary, lid: String, kind := "", bid := "sky") -> Dictionary:
	var t := World.tower(lid)
	var b: Dictionary = t.get("bands", {}).get(bid, {})
	if b.is_empty():
		return {}
	var kinds: Array = b.get("gigs", [])
	if kind == "":
		kind = String(kinds[dice.d(kinds.size()) - 1]) if not kinds.is_empty() else "data_theft"
	var l := World.location(lid)
	var did := String(l.get("district", ""))
	var known := best_reputation()
	var fid := _target_for(l, kind)
	var rng: Array = location_levels(l, fid)
	var level := clampi(int(rng[0]) if rng.size() >= 2 else 2, 1, 3)
	var fx := _pick_fixer(did, kind, known)
	var hook := _hook_for(l, kind)
	var floors := "floors %d-%d" % [int(b.storeys[0]), int(b.storeys[1])]
	var gig := {"kind": kind, "fixer": String(fx.get("name", "A fixer")), "fixer_id": String(fx.get("id", "")),
		"faction": fid, "location": lid, "district": did, "hook": hook,
		"security": level, "pay": int(int(g.pay[str(level)]) * float(g.get("tower", {}).get("pay_mult", 1.0))),
		"seed": dice.rng.randi_range(1, 99999)}
	gig.merge(tower_place(lid, bid))
	gig["sky"] = tower_sky(int(gig.seed))
	gig["mood"] = tower_mood(int(gig.seed), did)
	gig.merge(codes_for(gig, did), true)
	build_mission(gig)
	var pitch := MissionBuilder.pitch(gig, World.display_name(fid))
	var extra := hook if hook != "" else "the gig is %s up, on %s." % ["%d storeys" % int(b.storeys[0]), floors]
	pitch = (pitch + " " if pitch != "" else "") + extra.left(1).to_upper() + extra.substr(1)
	gig["title"] = "%s: %s %s" % [String(gig.mission.get("label", kind.capitalize())), String(l.name), floors.replace("floors ", "")]
	gig["blurb"] = "%s has work at %s (%s), %s: %s" % [String(gig.fixer), String(l.name), String(World.district(did).get("name", did)), floors, pitch]
	return gig


## Whether a tower gig with this seed plays by day or at night ("day" / "night"): one in gigs.json
## tower.day_in by day (owner, V1 verdicts: some tower gigs by day; night stays the campaign look).
## Kept on the gig (sky), so a save reloads the same light; scene_opts hands it to the map's params.
static func tower_sky(seed_value: int) -> String:
	var n := int(RulesDB.gen("gigs.json").get("tower", {}).get("day_in", 3))
	return "day" if n > 0 and posmod(hash(seed_value * 7 + 3), n) == 0 else "night"


## The weather over a tower gig with this seed in district `did` (Atmosphere.pick). Kept on the
## gig (mood) as its sky is.
static func tower_mood(seed_value: int, did: String) -> String:
	return Atmosphere.pick(seed_value, did)


## The weather over a gig with this seed in district `did` played as `scene` (Atmosphere.pick: the
## Night City Weather odds, leaned by the district; atmospheres.json). "" where there is no sky (the
## undercity's tunnels, the arcology's atrium). Every offer keeps it on the gig (mood).
static func gig_mood(seed_value: int, did: String, scene: String) -> String:
	return Atmosphere.pick(seed_value, did) if Atmosphere.has_sky(scene) else ""


## Where a tower gig at `lid` is played: its band of the tower (scene tower_top; TowerGen).
static func tower_place(lid: String, bid := "sky") -> Dictionary:
	var t := World.tower(lid)
	return {"scene": "tower_top", "profile": "", "site": TowerGen.recipe(t), "location": lid, "tower": lid, "band": bid}


## The gig's target (World faction able to be the target of this kind; `fid` if given) and the
## {corp}/{gang} names its text uses: the target's own name in its slot, another faction's in the other.
func _target_slots(kind: String, fid := "") -> Dictionary:
	var ids := targets_for(kind)
	if fid == "":
		fid = _pick(ids) if not ids.is_empty() else World.DEFAULT_OPFOR
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
		say("%s has a cyberpsychotic episode after the gig%s. Therapy helps." % [c.display_name, (" and hurts " + hurt) if hurt != "" else ""])
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


## Where a gig at canon location `lid` is played: {scene, profile, site, location}, plus its set
## piece (data/gen/setpieces.json) when the place has one: the famous places play as themselves.
static func _place_at(lid: String) -> Dictionary:
	var l := World.location(lid)
	var out := {"scene": String(l.get("scene", "neighborhood" if l.has("profile") else "lone_building")),
		"profile": String(l.get("profile", "")), "site": String(l.get("site", "")), "location": lid}
	if String(l.get("setpiece", "")) != "":
		out["setpiece"] = String(l.setpiece)
	return out


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


## SceneGen options for a gig dict. Its district gives the scene its look (DistrictLook).
static func scene_opts(gig: Dictionary) -> Dictionary:
	var o := {"security": int(gig.get("security", 1))}
	if String(gig.get("district", "")) != "":
		o["district"] = gig.district
	if String(gig.get("profile", "")) != "":
		o["profile"] = gig.profile
	if String(gig.get("site", "")) != "":
		o["site"] = gig.site
	if String(gig.get("setpiece", "")) != "":   # a famous place builds its own recipe
		o["setpiece"] = gig.setpiece
		o["location"] = String(gig.get("location", ""))
	if String(gig.get("tower", "")) != "":   # a tower gig: its band (TowerGen)
		o["tower"] = String(gig.tower)
		o["band"] = String(gig.get("band", TowerGen.DEFAULT_BAND))
		if String(gig.get("sky", "")) != "":   # by day or at night (tower_sky): the view's light (greybox _scene_look)
			o["sky"] = String(gig.sky)
	if String(gig.get("mood", "")) != "":   # its weather (gig_mood): the air, the rain (greybox scene_look, WeatherFx, TowerDress) and its rules (Weather)
		o["mood"] = String(gig.mood)
	if gig.has("hour"):   # the hour the crew arrives (_start_gig): the map's light by it (Daylight, greybox scene_look)
		o["hour"] = int(gig.hour)
	for k in ["variant", "deploy", "basement_storeys"]:   # a dev gig's overrides (CustomGig)
		if gig.has(k):
			o[k] = gig[k]
	return o


func _pick(a: Array) -> Variant:
	return a[dice.d(a.size()) - 1]


static func _fill(s: String, slots: Dictionary) -> String:
	for k in slots:
		s = s.replace("{%s}" % k, String(slots[k]))
	return s


## Take a gig: it becomes the active one (the tactical view builds the map from it).
func accept(index: int) -> Dictionary:
	if index < 0 or index >= board.size():
		return {}
	return _start_gig(board[index])


## DEV ONLY (the CUSTOM GIG (DEV) card, developer mode): take the gig the builder's form makes
## (CustomGig.build). It runs as a board offer does, marked dev; the form, its seed filled in, is
## kept as last_custom for REPEAT.
func accept_custom(form: Dictionary) -> Dictionary:
	var g := CustomGig.build(form, self)
	var out := _start_gig(g)
	if not out.is_empty():
		last_custom = (g.form as Dictionary).duplicate(true)
		dev_gigs += 1
	return out


## Those of the crew who go on `gig`: everyone alive who can act, or the ones a dev gig names.
func gig_crew(gig: Dictionary) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var names: Array = gig.get("crew", [])
	for c in alive_crew():
		if c.can_act() and (names.is_empty() or c.display_name in names):
			out.append(c)
	return out


func _start_gig(gig: Dictionary) -> Dictionary:
	if gig_crew(gig).is_empty():
		return {}
	active_gig = gig.duplicate(true)
	var drive := travel_minutes(active_gig)   # NC2045 p.18: the drive out from the safehouse district
	if drive > 0:
		active_gig["travel_minutes"] = drive
		advance_minutes(drive)
	if not active_gig.has("hour"):   # the hour the crew gets there: the map is lit by it (Daylight), as the street is rolled for it
		active_gig["hour"] = minutes / 60
	if not active_gig.has("mood"):   # an offer from before the weather pass: its weather now (gig_mood)
		active_gig["mood"] = gig_mood(int(active_gig.get("seed", 1)), String(active_gig.get("district", "")), String(active_gig.get("scene", "")))
	if not active_gig.has("scene_event"):   # the street round the gig, at the hour the crew gets there (SceneEvent, SPM p.77-84)
		active_gig["scene_event"] = SceneEvent.roll(active_gig, int(active_gig.hour) * 60 + minutes % 60, String(active_gig.get("street", "")))
	if SceneEvent.mood_of(active_gig.scene_event) != "" and String(active_gig.get("mood", "")) != "":   # the street brings its weather (a dust storm rolling in)
		active_gig["mood"] = SceneEvent.mood_of(active_gig.scene_event)
	var before := {}   # for the debrief: what each crew member already had going in
	for c in crew:
		before[c.display_name] = {"injuries": c.injuries.size(), "humanity": c.humanity}
	active_gig["before"] = before
	debrief.clear()   # the last gig's marks come off the crew cards
	say("%sTook '%s' from %s." % ["[DEV] " if active_gig.get("dev", false) else "", active_gig.title, active_gig.fixer])
	if intel > 0 and active_gig.has("intel"):   # the intel was on this board: taking a job spends it
		intel -= 1
		say("The fixer's intel said it would %s." % ("run into trouble" if String(active_gig.intel) == "trouble" else "run clean"))
	if drive > 0:
		say("Drove %d minutes from %s to %s." % [drive,
			String(World.district(safehouse_district).get("name", safehouse_district)), district_name(active_gig)])
	return active_gig


## Minutes to drive from the safehouse district to `gig`'s district (Travel.drive_minutes; -1 for
## a gig with no district on the map).
func travel_minutes(gig: Dictionary) -> int:
	return Travel.drive_minutes(safehouse_district, String(gig.get("district", "")))


## Move the clock on `n` minutes; whole days roll over into `day` (a new day can bring a new
## Night Market, update_market).
func advance_minutes(n: int) -> void:
	minutes += maxi(0, n)
	if minutes < DAY_MINUTES:
		return
	day += minutes / DAY_MINUTES
	minutes %= DAY_MINUTES
	update_market()


## The time of day as the safehouse shows it beside the day: "02:15" (the day starts at midnight).
func time_label() -> String:
	return "%02d:%02d" % [minutes / 60, minutes % 60]


# --- After the gig ----------------------------------------------------------------

## Settle the active gig from the finished encounter. Returns a report for the results screen.
func resolve(e: Encounter) -> Dictionary:
	var gig := active_gig
	var won := e.state == "won"
	var report := {"gig": gig, "won": won, "state": e.state, "pay": 0, "reputation": {}, "ip": 0, "dead": [], "hurt": [], "episodes": [],
		"dev": bool(gig.get("dev", false))}
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
		c.expire_brief_injuries()   # a flashbang's minute is long over by the time they're home
		if c.hp < c.max_hp() or not c.injuries.is_empty():
			report.hurt.append(c.display_name)
	if won:
		report.pay = int(gig.get("pay", 0))
	eb += report.pay
	report["shields"] = _replace_popup_shields()
	report["payment"] = (gig.get("payment", {}) as Dictionary).duplicate(true) if gig.get("payment") is Dictionary else {}
	report["paid_extra"] = _collect_payment(gig) if won else ""
	report["focus_line"] = MissionBuilder.debrief_line(gig, won)
	report["client"] = MissionBuilder.client_text(gig)
	report["twist"] = twist_report(e)
	report["street"] = {} if e.scene_event.is_empty() else {"id": String(e.scene_event.id), "label": String(e.scene_event.label), "note": String(e.scene_event.get("note", ""))}
	report["clocks"] = e.clocks.map(func(c): return (c as Clock).to_dict())
	_take_loot(e, gig, report)
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
	gigs_done += 1
	day += 1
	refresh_board()
	update_market()
	return report


## A Popup Shield that took hits gets a new Bulletproof Shield at the safehouse: the one in the arm
## is "easily removable and replaceable with another Bulletproof Shield" (CPR core p.365), at the
## shield's price (100eb, p.183), paid when the crew can. A destroyed one stays useless until then.
## Returns who got one.
func _replace_popup_shields() -> Array:
	var out: Array = []
	for c in crew:
		var p := c.shield_piece()
		if p.is_empty() or int(p.get("hp", 0)) >= Cyber.shield_max(String(p.id)):
			continue
		var cost := int(RulesDB.gear("shields", "bulletproof_shield").get("cost", 100))
		if eb < cost:
			say("%s's popup shield needs a new Bulletproof Shield (%d eb): not enough eb." % [c.display_name, cost])
			continue
		eb -= cost
		p["hp"] = Cyber.shield_max(String(p.id))
		out.append(c.display_name)
		say("%s's popup shield gets a new Bulletproof Shield (-%d eb)." % [c.display_name, cost])
	return out


## The plot twist that sprang on the gig, for the debrief: {id, row, label, note, text, round}, or
## {} when none did (an offer's twist that never came into play stays the fixer's secret).
static func twist_report(e: Encounter) -> Dictionary:
	if e.twist.is_empty() or not bool(e.twist.get("sprung", false)):
		return {}
	return {"id": String(e.twist.id), "row": int(e.twist.get("row", 0)), "label": String(e.twist.label), "note": String(e.twist.get("note", "")),
		"text": String(e.twist.get("text", "")), "round": int(e.twist.get("round", 0))}


## The part of a won gig's payment that isn't eb (MissionBuilder payment): an intel token, a favour
## token, or goods into safehouse storage. Returns what came in, in words ("" for eb only).
func _collect_payment(gig: Dictionary) -> String:
	var p: Dictionary = gig.get("payment", {}) if gig.get("payment") is Dictionary else {}
	var from := String(gig.get("fixer", "the fixer"))
	match String(p.get("type", "eb")):
		"information":
			intel += 1
			say("%s pays partly in information: the next board comes with intel." % from)
		"favour":
			var f := {"kind": String(p.get("kind", "treatment")), "from": from, "day": day}
			if f.kind == "market":
				f["cap"] = int(p.get("cap", 0))
			favours.append(f)
			say("%s owes the crew %s." % [from, MissionBuilder.payment_extra(p).trim_prefix("a favour: ")])
		"goods":
			var key := String(p.get("item", ""))
			if not Items.is_stored(key):
				return ""
			_put(key)
			say("%s pays partly in goods: %s, into storage." % [from, Items.display_name(key)])
		_:
			return ""
	return MissionBuilder.payment_extra(p)


## The first favour of `kind` the crew holds (its index in favours), -1 if none.
func favour_index(kind: String) -> int:
	for i in favours.size():
		if String(favours[i].get("kind", "")) == kind:
			return i
	return -1


## What the crew found on bodies and brought home (CorpseLoot.kept): items into storage, eb into
## the wallet, leads onto the lead list. The report gains loot ({label, text, kind, by, from}
## per find kept), loot_eb, loot_lost (finds left behind), leads (the new ones), and the Morale
## counts surrendered and fled.
func _take_loot(e: Encounter, gig: Dictionary, report: Dictionary) -> void:
	var kept := CorpseLoot.kept(e)
	var lines: Array = []
	var new_leads: Array = []
	var got := 0
	for f in kept:
		match String(f.kind):
			"eb":
				got += int(f.eb)
			"item":
				for k in f.items:
					if Items.is_stored(String(k)):
						_put(String(k), int(f.items[k]))
			"lead":
				var l := {"label": String(f.label), "hook": String(f.hook), "day": day, "gig": String(gig.get("title", "")),
					"faction": String(gig.get("faction", "")), "district": String(gig.get("district", "")),
					"location": String(gig.get("location", "")), "from": String(f.get("from", ""))}
				leads.append(l)
				new_leads.append(l)
		lines.append({"label": String(f.label), "text": CorpseLoot.describe(f, false), "kind": String(f.kind), "by": String(f.get("by_name", "")),
			"from": String(f.get("from", "")), "keys": (f.get("items", {}) as Dictionary).keys()})
	eb += got
	report["loot"] = lines
	report["loot_eb"] = got
	report["loot_lost"] = e.loot.filter(func(f): return String(f.kind) in ["eb", "item", "lead"]).size() - kept.size()
	report["leads"] = new_leads
	var mc := e.morale_counts()
	report["surrendered"] = int(mc.surrendered)
	report["fled"] = int(mc.fled)
	if not lines.is_empty():
		say("Found on bodies: %s." % ", ".join(kept.map(func(x): return CorpseLoot.describe(x))))


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
			"kit": kit_of.get(c.display_name, []), "lost": _lost_gear(c, kit_of) if c.dead else [], "lost_keys": _lost_gear_keys(c) if c.dead else [], "addicted": hooked, "episode": c.display_name in report.episodes,
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
	out.append_array(Cyber.names(c.implants))
	out.append_array(kit_of.get(c.display_name, []))
	return out


## The storage keys beside _lost_gear's names, in the same order ("" where a name has none), so
## the debrief can style them (QualityText).
static func _lost_gear_keys(c: Combatant) -> Array:
	var out: Array = []
	for w in c.weapons:
		if not w.builtin:
			out.append(Items.key_of_weapon(w))
	for loc in ["head", "body"]:
		if c.armor.get(loc):
			out.append("")
	for p in c.implants:
		out.append("cyberware/" + Cyber.spec_of(p))
	return out


## The book's Wound State names (p220), by Combatant.Wound.
const WOUND_NAMES := ["Unhurt", "Lightly Wounded", "Seriously Wounded", "Mortally Wounded", "Flatlined"]


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

## Rest: everyone heals BODY HP per day (p223), up to full, and magazines are refilled; Skin Weave
## and Subdermal Armor mend 1 SP a day (p.364). The crew's best hand at Basic Tech spends the days
## repairing ablated armour they wear (repair_armor_work).
func rest(days := 1) -> void:
	for c in crew:
		var heal: int = c.raw_stat("BODY") * days
		c.hp = mini(c.max_hp(), c.hp + heal)
		if not c.dead:
			c.mend_subdermal(days)
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


## Clinic price, halved while a Trauma Surgeon is on the crew (HOUSE-RULE perk); nothing while a
## fixer owes the crew a treatment favour (MissionBuilder payment).
func treat_cost() -> int:
	if favour_index("treatment") >= 0:
		return 0
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
	var fi := favour_index("treatment")
	var by := ""
	if fi >= 0:
		by = " on %s's favour" % String(favours[fi].get("from", "a fixer"))
		favours.remove_at(fi)
	var inj: Dictionary = c.injuries[injury_index]
	c.injuries.remove_at(injury_index)
	say("%s's %s treated%s." % [c.display_name, inj.get("name", "injury"), by])
	return true


func refresh_recruits() -> void:
	recruits.clear()
	for role in ["solo", "netrunner", "medtech", "tech"]:
		recruits.append(Recruit.generate(dice, role, "edgerunner", "", names_taken(), 10 + recruits.size() + day * 3))


## The handles and real names of the crew and the recruits, so a new recruit repeats none.
func names_taken() -> Array:
	var out: Array = []
	for c in crew + recruits:
		out.append(c.display_name)
		out.append(c.real_name)
	return out


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
			return Cyber.summary(Items.base_id(key))
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


## Buy a whole cart (the Night Market tab's cart) into safehouse storage at list price, all or
## nothing: `lines` is storage key → how many (lines of 0 or fewer are skipped). Nothing is bought
## unless every line is on sale now and the eb covers the lot. Returns {ok, reason: "" | "empty" |
## "off_sale" | "short", key (the line that is off sale), bought: {key: n}, count, total}.
func buy_cart(lines: Dictionary) -> Dictionary:
	var out := {"ok": false, "reason": "", "key": "", "bought": {}, "count": cart_count(lines), "total": 0, "favour": 0}
	for k in lines:
		if int(lines[k]) > 0 and (not Items.is_stored(String(k)) or not on_sale(String(k))):
			out.reason = "off_sale"
			out.key = String(k)
			return out
	out.favour = favour_discount(lines)
	out.total = cart_total(lines) - int(out.favour)
	if int(out.count) == 0:
		out.reason = "empty"
		return out
	if int(out.total) > eb:
		out.reason = "short"
		return out
	eb -= int(out.total)
	var bought := {}
	for k in lines:
		if int(lines[k]) > 0:
			_put(String(k), int(lines[k]))
			bought[String(k)] = int(lines[k])
	out.bought = bought
	out.ok = true
	if int(out.favour) > 0:
		var fi := _market_favour()
		say("%s's favour covers %s eb of it." % [String(favours[fi].get("from", "A fixer")), eb_text(int(out.favour))])
		favours.remove_at(fi)
	if bought.size() == 1 and int(out.count) == 1:
		say("Bought %s for %s eb" % [Items.display_name(String(bought.keys()[0])), eb_text(int(out.total))])
	else:
		say("Bought %d items for %s eb" % [int(out.count), eb_text(int(out.total))])
	return out


## The market favour that covers the most (the highest cap), as an index into favours; -1 if none.
func _market_favour() -> int:
	var best := -1
	for i in favours.size():
		if String(favours[i].get("kind", "")) == "market" and (best < 0 or int(favours[i].get("cap", 0)) > int(favours[best].get("cap", 0))):
			best = i
	return best


## What a market favour takes off this cart: the price of its dearest item the favour's cap covers
## (one of them), 0 without a market favour.
func favour_discount(lines: Dictionary) -> int:
	var fi := _market_favour()
	if fi < 0:
		return 0
	var cap := int(favours[fi].get("cap", 0))
	var best := 0
	for k in lines:
		var p := Items.price(String(k))
		if int(lines[k]) > 0 and p <= cap:
			best = maxi(best, p)
	return best


## What the crew pays for a cart: list price less a market favour (favour_discount).
func cart_due(lines: Dictionary) -> int:
	return cart_total(lines) - favour_discount(lines)


## What a cart costs at list price (`lines`: storage key → how many).
static func cart_total(lines: Dictionary) -> int:
	var t := 0
	for k in lines:
		t += Items.price(String(k)) * maxi(0, int(lines[k]))
	return t


## How many items a cart holds.
static func cart_count(lines: Dictionary) -> int:
	var n := 0
	for k in lines:
		n += maxi(0, int(lines[k]))
	return n


## "4,250": eb with thousands separators, for log lines.
static func eb_text(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


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
		return "not a weapon or armor"
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

## A piece is bought from a Night Market that has it on sale (with the foundations it needs, p338)
## into safehouse storage like any gear; installing it later at the Med Bay costs nothing more (a
## Night Market sale includes the install, p338; the price includes the surgery, p110). What's on
## sale is what the game plays (Cyber.modelled, NightMarket.on_sale); where a piece goes and whether
## it fits is the slot model's (Cyber, p111-116).

## Humanity Loss therapies (gear.json "therapy", CPR core p230).
const HUMANITY_THERAPY := {"standard": "standard_humanity_therapy", "extreme": "extreme_humanity_therapy"}


## Why `c` can't have this stored piece installed now ("" if they can), in a few plain words: none
## in storage, or the slot model's reason (Cyber.block: "No free slot in the left eye", "Needs two
## cybereyes", "Only one speedware"...). `loc` "" asks whether it fits anywhere.
## `id` may be a spec ("skill_chip@handgun": a piece made for one thing, Cyber.choices).
func install_block(c: Combatant, id: String, loc: String = "") -> String:
	if c == null or not c in alive_crew():
		return "Not on the crew"
	if stored("cyberware/" + id) <= 0 and not (Cyber.choice_of(id) == "" and stored_variants(id) > 0):
		return "Not in storage"
	var why := Cyber.block_any(c.implants, id) if loc == "" else Cyber.block(c.implants, id, loc)
	return why if why != "" else Cyber.stat_block(c, Cyber.base(id))   # a Linear Frame's BODY (p.367)


## Install a piece from storage at `loc` ("" = Cyber.auto_loc). Free: it came from a Night Market,
## whose sale includes the install (p338). Rolls the Humanity Loss (p110) and arms any built-in
## melee weapon (a hand-held melee weapon it replaces goes to storage). From then on it's part of
## `c`: it can be removed (remove), never moved to someone else. Returns the Humanity lost, -1 if it
## can't be done.
## `choice`: what a piece made for one thing was bought for (the Med Bay's options step,
## MedBayScreen._install_choices): the same as passing the spec "id@choice".
func install(c: Combatant, id: String, loc: String = "", choice: Variant = "") -> int:
	if String(choice) != "":
		id = "%s@%s" % [Cyber.base(id), String(choice)]
	if not Cyber.choices(Cyber.base(id)).is_empty() and Cyber.choice_of(id) == "":
		return -1   # a chip or popup goes in as what it was bought for
	if install_block(c, id, loc) != "":
		return -1
	var where := loc if loc != "" else Cyber.auto_loc(c.implants, id)
	_take("cyberware/" + id)
	var before := c.weapons.duplicate()
	var loss := c.install_cyberware(id, dice, false, where)
	for w in before:
		if not w in c.weapons and not w.builtin:
			_put(Items.key_of_weapon(w))
	say("%s gets %s installed (-%d Humanity)." % [c.display_name, Cyber.display(id), loss])
	return loss


## How many of a piece made for one thing are in storage, whatever they were made for.
func stored_variants(id: String) -> int:
	var n := 0
	for k in stash:
		if Items.section(String(k)) == "cyberware" and Items.base_id(String(k)) == id and Cyber.choice_of(String(k).get_slice("/", 1)) != "":
			n += stored(String(k))
	return n


## Chipware comes out of its socket whole and goes back to storage: chips are made to be swapped
## (CPR core p.359), here only at the safehouse (owner's ruling); putting it back in costs no
## Humanity Loss (Combatant.chips_used).
static func comes_out_whole(id: String) -> bool:
	return String(Cyber.def(id).get("host", "")) == "chipware"


## Why this installed piece can't come out now ("" if it can): a piece installed in it still needs
## it (p111: options come out before their foundation).
func remove_block(c: Combatant, id: String, loc: String = "") -> String:
	var piece := c.implant(id, loc) if c != null else {}
	if piece.is_empty():
		return "Not installed"
	return Cyber.remove_block(c.implants, piece)


## Take an installed piece out at the Med Bay. It is destroyed, not stored: harvested chrome is
## worthless without a Cybertech repair (p226), and installed chrome is never moved to someone else
## (owner's ruling). The book prices no removal (p226 prices installing supplied chrome only), so
## it costs nothing (HOUSE-RULE: the crew's ripperdoc does it). Humanity lost isn't returned
## (Combatant.remove_cyberware).
func remove(c: Combatant, id: String, loc: String = "") -> bool:
	if remove_block(c, id, loc) != "":
		return false
	var spec := Cyber.spec_of(c.implant(id, loc))
	c.remove_cyberware(id, loc)
	if comes_out_whole(id):
		_put("cyberware/" + spec)
	say("%s has %s taken out." % [c.display_name, Cyber.display(spec)])
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
	return {"version": SaveMigrations.CURRENT, "seed": seed_value, "eb": eb, "day": day, "minutes": minutes,
		"safehouse_district": safehouse_district, "crew": crew.map(func(c): return c.to_dict()),
		"fallen": fallen, "board": board, "recruits": recruits.map(func(c): return c.to_dict()), "log": log.slice(-50),
		"rng_state": str(dice.rng.state), "stash": stash, "market": market, "debrief": debrief, "gigs_done": gigs_done,
		"dev_gigs": dev_gigs, "last_custom": last_custom, "intel": intel, "favours": favours, "leads": leads}


## A campaign from a save dictionary, upgraded to the current format first (SaveMigrations).
## Null if the save is from a newer build.
static func from_dict(raw: Dictionary) -> Campaign:
	var d := SaveMigrations.migrate(raw)
	if d.is_empty():
		return null
	var c := Campaign.new()
	c.seed_value = int(d.seed)
	c.dice = Dice.new(c.seed_value)
	var st: Variant = d.get("rng_state")
	if st is String:   # a decimal string: a JSON number (a double) loses the 64-bit state's low bits
		c.dice.rng.state = (st as String).to_int()
	elif st != null:   # an older save's number, already rounded: the nearest state is the best there is
		c.dice.rng.state = int(st)
	c.eb = int(d.eb)
	c.day = int(d.day)
	c.gigs_done = int(d.get("gigs_done", 0))
	c.dev_gigs = int(d.get("dev_gigs", 0))
	if d.get("last_custom") is Dictionary:
		c.last_custom = _ints(d.last_custom)
	c.intel = maxi(0, int(d.get("intel", 0)))
	for f in d.get("favours", []):
		if f is Dictionary:
			c.favours.append(_ints(f))
	c.minutes = clampi(int(d.get("minutes", 0)), 0, DAY_MINUTES - 1)
	var sh := String(d.get("safehouse_district", DEFAULT_SAFEHOUSE))
	c.safehouse_district = sh if World.districts().has(sh) else DEFAULT_SAFEHOUSE
	for cd in d.crew:
		c.crew.append(Combatant.from_dict(cd))
	for f in d.fallen:
		c.fallen.append(_ints(f))   # the day they fell: an int again
	for b in d.board:
		c.board.append(code_loaded_gig(_ints(b)))   # pay, security, seed, codes: ints again, as offered
	for r in d.get("recruits", []):
		c.recruits.append(Combatant.from_dict(r))
	for k in d.get("stash", {}):
		if Items.is_stored(String(k)) and int(d.stash[k]) > 0:
			c.stash[String(k)] = int(d.stash[k])
	c.market = _ints(d.get("market", {}))   # JSON numbers come back as floats (opened, closes, rows)
	for l in d.get("log", []):
		c.log.append(String(l))
	for m in d.get("debrief", []):
		if m is Dictionary:
			c.debrief.append(_ints(m))   # hp, IP, Reputation: ints again
	for l in d.get("leads", []):
		if l is Dictionary:
			c.leads.append(_ints(l))   # the day found: an int again
	c.update_market()   # a save from before markets (v5) gets one now
	if bool(d.get("refill_board", false)):   # v14 dropped its generic offers: canon ones take their places
		c._fill_board(RulesDB.gen("gigs.json"), {})
		c.foresee()
	return c


## `v` with every whole-number float (as JSON hands numbers back) an int again, in Dictionaries and
## Arrays all the way down: a reloaded campaign holds what the saved one did.
static func _ints(v: Variant) -> Variant:
	if v is float and v == roundf(v) and absf(v) < 9.0e15:
		return int(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _ints(v[k])
		return out
	if v is Array:
		return (v as Array).map(func(x): return _ints(x))
	return v


## A loaded offer with its Night City 2045 codes: one saved before v8 has none, so it gets them
## now from the city data (codes_for: its location's own code and district, else the fallback for
## its 1-3 security level and target). Offers that have codes are returned as they are.
static func code_loaded_gig(g: Variant) -> Variant:
	if g is Dictionary and not (g as Dictionary).has("security_code"):
		var did := String(World.location(String(g.get("location", ""))).get("district", ""))
		(g as Dictionary).merge(codes_for(g, did), true)
	return g


## Save to `path`, by default the active slot (SaveSlots.write: a meta line, then to_dict).
func save(path := "") -> bool:
	return SaveSlots.write(self, path if path != "" else SaveSlots.path(slot))


static func load_from(path := "") -> Campaign:
	if path == "":
		path = SaveSlots.path(slot)
	if not FileAccess.file_exists(path):
		return null
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return Campaign.from_dict(d) if d is Dictionary else null
