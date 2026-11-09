class_name SecurityCode
extends RefCounted
## Night City 2045's Security and Utility Codes (NC2045 p.7-8), as the game plays them.
##
## A Security Code is `{n, faction, intensity, hardened}` (docs/world/city.md, locations.md), plus
## `or_faction` on a code printed with two responders and `responder` on a venue's (respondent): when
## an incident happens, roll 1d10; under `n`, `faction` responds (11 always does). Intensity sizes the
## response on the CPR p.399 encounter budget; Hardened responders use the Hardened stat blocks.
## A Utility Code is one number: roll 1d10 per utility (power, water, CitiNet); under it, that
## utility is out. Pure helpers: every roll goes through the Dice passed in.

const INTENSITIES := ["light", "medium", "heavy"]
const UTILITIES := ["power", "water", "citinet"]
const ALWAYS := 11                 ## NC2045 p.7 codes print 11: no d10 roll is under it
## HOUSE-RULE: one minute of response time is two rounds (owner decision, decisions log 2026-11-04);
## the book's own example counts 3 s rounds (NC2045 p.7-8), which would keep responders away for
## the whole gig.
const ROUNDS_PER_MINUTE := 2
## HOUSE-RULE: our reading of "a higher code usually responds faster" (NC2045 p.7): codes 7+ use the
## quick fallback (1d6 minutes), lower codes the slow one (1d10 minutes).
const QUICK_FROM := 7
## Codes for gigs with no location or district to read one from (OWNER-ACCEPTED fallback from the
## old 1-3 security level). An empty faction means the site's own people (the gig's target).
const FALLBACK := {
	1: {"n": 4, "faction": "", "intensity": "light", "hardened": false},
	2: {"n": 6, "faction": "", "intensity": "medium", "hardened": false},
	3: {"n": 8, "faction": "", "intensity": "heavy", "hardened": true},
}
## HOUSE-RULE: the street around a gig with no district yet (until M9 P3 puts every job in one):
## the most common district code on the NC2045 p.8 cheatsheet, NCPD at 6-8 Hardened Medium.
const STREET_FALLBACK := {"n": 6, "faction": "ncpd", "intensity": "medium", "hardened": true}
## HOUSE-RULE: utilities for a gig with no district yet: 3, the most common district Utility Code
## on the NC2045 p.8 cheatsheet (a 20% chance each utility is out).
const UTILITY_FALLBACK := 3
## guarded_by: faction kinds that sell protection (factions.json `kind`).
const PROVIDER_KINDS := ["police", "corp"]
## guarded_by: the public police, whose code at a private place is the city's interest in it.
const PUBLIC_POLICE := ["ncpd", "maxtac"]
## guarded_by: owners whose places the public police guard themselves.
const CITY_OWNERS := ["city_government"]
## utilities_happen: one gig in this many rolls its Utility Code (HOUSE-RULE pacing).
const UTILITY_CHANCE_IN := 3
## The one faction the book's venue placeholders ("Patrons", "Staff", "Various") are (factions.md);
## a code's `responder` says which of the venue's people answer (respondent).
const VENUE := "locals"
## CPR core p.399 encounter costs in Edgerunners' worth.
const COST := {"mook": 1, "lieutenant": 2, "mini_boss": 3}


## A code in the normal shape, or {} if `raw` isn't one. Takes the data dict (numbers may come back
## from JSON as floats) or the printed form "5: 6th Street, Hardened Light" / "Security Code 5: ...".
static func normalise(raw: Variant) -> Dictionary:
	if raw is String:
		return parse(raw)
	if not (raw is Dictionary) or not (raw as Dictionary).has("n"):
		return {}
	var d: Dictionary = raw
	var intensity := String(d.get("intensity", "medium")).to_lower()
	if not intensity in INTENSITIES:
		intensity = "medium"
	var out := {"n": clampi(int(d.n), 0, ALWAYS), "faction": String(d.get("faction", "")), "intensity": intensity,
		"hardened": bool(d.get("hardened", false))}
	for k in ["or_faction", "responder"]:   # a two-responder code's second; a venue code's printed responder
		if String(d.get(k, "")) != "":
			out[k] = String(d[k])
	return out


## The printed form (NC2045 p.7): "[Security Code] #: <Faction>, [Hardened] <Light|Medium|Heavy>".
## The faction name becomes an id (snake_case: "6th Street" → "6th_street"); a code printed with two
## responders, "Petrochem/SovOil", keeps the second as `or_faction`. {} if it doesn't parse.
static func parse(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t.to_lower().begins_with("security code"):
		t = t.substr(13).strip_edges()
	var colon := t.find(":")
	if colon < 0 or not t.substr(0, colon).strip_edges().is_valid_int():
		return {}
	var rest := t.substr(colon + 1)
	var comma := rest.rfind(",")
	var who := rest.substr(0, comma) if comma >= 0 else rest
	var how := rest.substr(comma + 1).strip_edges().to_lower() if comma >= 0 else ""
	var intensity := "medium"
	for i in INTENSITIES:
		if how.contains(i):
			intensity = i
	var ids: Array = Array(who.split("/", false)).map(func(x): return String(x).strip_edges().to_lower().replace(" ", "_").replace("'", "").replace("-", "_"))
	var out := {"n": int(t.substr(0, colon)), "faction": String(ids[0]) if not ids.is_empty() else "",
		"intensity": intensity, "hardened": how.contains("hardened")}
	if ids.size() > 1:
		out["or_faction"] = String(ids[1])
	return normalise(out)


## The fallback code for an old 1-3 security level, with `faction` (the site's own people) filled in.
static func from_level(level: int, faction := "") -> Dictionary:
	var c: Dictionary = (FALLBACK[clampi(level, 1, 3)] as Dictionary).duplicate()
	c.faction = faction
	return c


## The old 1-3 security level a code stands for (the site generators, pay and Reputation still use
## it): Light 1, Medium 2, Heavy 3.
static func level(code: Dictionary) -> int:
	return INTENSITIES.find(String(normalise(code).get("intensity", "medium"))) + 1


## Does the code's faction respond to an incident? 1d10 under `n` (NC2045 p.7; 11 always).
static func responds(dice: Dice, code: Dictionary) -> bool:
	return dice.d(10) < int(code.get("n", 0))


## Who answers when `code` responds: {faction, civilians}. Rolled each time the code responds
## (Encounter.call_it_in), through `dice`; `owner` is the location's owner faction ("" for none) and
## `gangs` the district's gangs, for the venue codes.
## - Two responders ("Kimen-Gumi/G3", `or_faction`): HOUSE-RULE (owner ruling 2026-11-04): the book
##   prints both and says no more, so either may answer: 1d2 each time the code responds.
## - A venue code (faction VENUE, NC2045 p.7: the Afterlife's patrons, p.69) by its printed
##   `responder`. HOUSE-RULE (owner ruling 2026-11-04: the venue's own people or the civilians about
##   answer): `patrons` and `residents` are armed locals (`civilians`: the district's civilian
##   blocks, Recruit.civilian_blocks); `staff` the owner's people, else armed locals; `gangs`
##   ("Various Gangs") one of the district's gangs, else armed locals; `various` and `unknown` ("??")
##   the owner's people or armed locals, 1d2 (armed locals if the owner is no faction).
## - Anything else: the code's faction.
static func respondent(dice: Dice, code: Dictionary, owner := "", gangs: Array = []) -> Dictionary:
	var fid := String(code.get("faction", ""))
	var alt := String(code.get("or_faction", ""))
	if alt != "" and dice.d(2) == 2:
		fid = alt
	if fid != VENUE:
		return {"faction": fid, "civilians": false}
	var locals := {"faction": VENUE, "civilians": true}
	var own: Dictionary = {"faction": owner, "civilians": false} if owner != "" and owner != VENUE and World.has_faction(owner) else {}
	match String(code.get("responder", "")):
		"staff":
			return own if not own.is_empty() else locals
		"gangs":
			var known: Array = gangs.filter(func(g): return World.has_faction(String(g)))
			if known.is_empty():
				return locals
			return {"faction": String(known[dice.d(known.size()) - 1]), "civilians": false}
		"various", "unknown":
			if not own.is_empty() and dice.d(2) == 2:
				return own
	return locals


## Is this a quick responder (see QUICK_FROM)?
static func quick(code: Dictionary) -> bool:
	return int(code.get("n", 0)) >= QUICK_FROM


## Rounds until a response arrives: 1d6 minutes if quick, 1d10 if slow (NC2045 p.7 fallback),
## at ROUNDS_PER_MINUTE.
static func response_rounds(dice: Dice, p_quick: bool) -> int:
	return dice.d(6 if p_quick else 10) * ROUNDS_PER_MINUTE


## The crew size to budget a response against (NC2045 p.7 intensity table, on the CPR p.399
## budget): Light treats the crew as 1-2 smaller (1d2, at least 1), Medium as it is, Heavy as at
## least 1 larger. Responses only: the guards on the posts get a code's intensity through the
## gig's security level instead (Campaign.location_levels), so it isn't counted twice.
static func budget_crew_size(crew_size: int, intensity: String, dice: Dice) -> int:
	match intensity:
		"light":
			return maxi(1, crew_size - dice.d(2))
		"heavy":
			return crew_size + 1
	return crew_size


## Who turns up when the code responds, strongest first: the intensity's budget (budget_crew_size
## Edgerunners' worth at p.399 costs) spent on officers the intensity allows, the rest Mooks.
## Light: Mooks and the odd Lieutenant; Medium: Lieutenants, occasionally a Mini Boss; Heavy:
## anything (NC2045 p.7). An officer is only taken if a Mook's worth of budget is left after it.
## HOUSE-RULE: "the odd" / "occasionally" is 1 in 5 (d10 <= 2).
static func response_roster(dice: Dice, code: Dictionary, crew_size: int) -> Array[String]:
	var intensity := String(code.get("intensity", "medium"))
	var budget := budget_crew_size(crew_size, intensity, dice)
	var officers: Array = []
	match intensity:
		"light":
			if dice.d(10) <= 2:
				officers = ["lieutenant"]
		"medium":
			officers = ["mini_boss", "lieutenant"] if dice.d(10) <= 2 else ["lieutenant"]
		"heavy":
			officers = ["mini_boss", "lieutenant"]
	var out: Array[String] = []
	for t in officers:
		if int(COST[t]) < budget:
			out.append(t)
			budget -= int(COST[t])
	for i in maxi(1, budget):
		out.append("mook")
	return out


## The stat blocks a faction draws its `tier` people from: its roster's own blocks, else the tier's
## default pool (npcs.json). Hardened prefers Hardened blocks (npcs.json blocks marked
## `hardened: true`): the roster's own Hardened ones, else its `hardened_blocks[tier]`, else the
## tier's `hardened_blocks`, and falls back to the ordinary pool if there are none yet.
static func tier_pool(faction: String, tier: String, hardened: bool) -> Array:
	return pool_from(World.faction(faction).get("roster", {}), RulesDB.load_json("npcs.json"), tier, hardened)


## tier_pool on given data (a faction roster and an npcs.json-shaped dict), for tests and tools.
static func pool_from(roster: Dictionary, npcs: Dictionary, tier: String, hardened: bool) -> Array:
	var blocks: Dictionary = npcs.get("blocks", {})
	var known := func(id: Variant) -> bool: return blocks.has(String(id))
	var is_h := func(id: Variant) -> bool: return bool((blocks.get(String(id), {}) as Dictionary).get("hardened", false))
	var own: Array = (roster.get("blocks", {}) as Dictionary).get(tier, [])
	var tdef: Dictionary = (npcs.get("tiers", {}) as Dictionary).get(tier, {})
	var plain_default: Array = tdef.get("blocks", [])
	if hardened:
		for cand in [own.filter(is_h), (roster.get("hardened_blocks", {}) as Dictionary).get(tier, []), tdef.get("hardened_blocks", [])]:
			var ok: Array = (cand as Array).filter(known)
			if not ok.is_empty():
				return ok
	for cand in [own.filter(func(id): return not is_h.call(id)), plain_default.filter(func(id): return not is_h.call(id)), own, plain_default]:
		if not (cand as Array).is_empty():
			return cand
	return []


## A gig's codes from where it happens: the location's own Security Code, else its district's, else
## the fallback for the old `level` (with the gig's target `faction` as the site's own people).
## Returns {security_code, utility_code, district_code, source: location|district|fallback}:
## district_code is the street-level code that can send a second response (the district's when
## the site code came from a location; none when the site code is the district's own; the
## STREET_FALLBACK otherwise). A location's code replaces its district's for that place (NC2045
## p.7: it is the on-site protection, or the district authority's own interest in the place), so
## when both name the same faction there is no street roll: that faction answers once.
## Utility: the location's override, else the district's, else UTILITY_FALLBACK.
static func for_gig(location: Dictionary, district: Dictionary, p_level: int, faction := "") -> Dictionary:
	var loc := normalise(location.get("security_code"))
	var dist := normalise(district.get("security_code"))
	var out := {}
	if not loc.is_empty():
		var street: Dictionary = dist if not dist.is_empty() else STREET_FALLBACK.duplicate()
		if String(street.faction) == String(loc.faction):
			street = {}
		out = {"security_code": loc, "district_code": street, "source": "location"}
	elif not dist.is_empty():
		out = {"security_code": dist, "district_code": {}, "source": "district"}
	else:
		out = {"security_code": from_level(p_level, faction), "district_code": STREET_FALLBACK.duplicate(), "source": "fallback"}
	var u := UTILITY_FALLBACK
	for src in [district.get("utility_code"), location.get("utility_code")]:   # the location overrides
		if src is int or src is float:
			u = int(src)
	out["utility_code"] = clampi(u, 0, 10)
	return out


## Who holds the posts at a site under `code` (NC2045 p.7: a location's code is either its on-site
## protection or the authorities' interest in it). `site` is the gig's target (whose place it is
## for the job), `owner` the location's owner ("" for none):
## - the code's faction is the target's own (or the code names nobody): the target's people;
## - the code's faction is a security provider (a police- or corp-kind faction) and the place has an
##   owner: that contractor guards it for the owner (Lazarus at Night Corp HQ, NC2045 p.61);
## - otherwise (the city's police, a gang, a bar's patrons): "" — the code is an outside
##   authority's interest; it only decides who answers a call, and the target's people hold the
##   posts at their ordinary strength.
## HOUSE-RULE: the book doesn't say which codes are a contractor's; we read a private provider at an
## owned place as one, and the public police (PUBLIC_POLICE) as the authority except on the city's
## own property (CITY_OWNERS: City Hall, the Hall of Justice), which they guard themselves.
static func guarded_by(code: Dictionary, site: String, owner := "") -> String:
	var c := normalise(code)
	if c.is_empty():
		return ""
	var fid := String(c.faction)
	if fid == "" or fid == site:
		return site
	if owner == "" or not World.has_faction(fid) or not World.kind(fid) in PROVIDER_KINDS:
		return ""
	if fid in PUBLIC_POLICE and not owner in CITY_OWNERS:
		return ""
	return fid


## The chance in percent that a code's roll comes up (1d10 under n, NC2045 p.7-8): 10 x (n - 1),
## 0 to 100. The same sum reads a Security Code (a response) and a Utility Code (each utility out).
static func chance(n: int) -> int:
	return clampi((n - 1) * 10, 0, 100)


## Intensity for a map label: "LGT", "MED", "HVY", with "H-" for Hardened ("H-MED").
static func short_intensity(code: Dictionary) -> String:
	var c := normalise(code)
	if c.is_empty():
		return ""
	return ("H-" if bool(c.hardened) else "") + String({"light": "LGT", "medium": "MED", "heavy": "HVY"}[String(c.intensity)])


## Does this gig roll its Utility Code? NC2045 p.8 offers utilities as an extra complication to
## raise a job's challenge, not a standing rule. HOUSE-RULE pacing: one gig in UTILITY_CHANCE_IN
## (the book's complications were paced the same until the Oracle took them over: Complication.likelihood).
static func utilities_happen(dice: Dice) -> bool:
	return dice.d(UTILITY_CHANCE_IN) == 1


## Which utilities are out: 1d10 per utility, under the code (NC2045 p.8). A code of 1 or less
## can't be rolled under, so nothing is rolled.
static func roll_utilities(dice: Dice, code: int) -> Array[String]:
	var out: Array[String] = []
	if code <= 1:
		return out
	for u in UTILITIES:
		if dice.d(10) < code:
			out.append(u)
	return out


## A faction's name for display: the World name, or the id prettified if it isn't in factions.json yet.
static func faction_name(id: String) -> String:
	if id == "":
		return ""
	return World.display_name(id) if World.has_faction(id) else id.replace("_", " ").capitalize()


## Who a code names, for display: "Petrochem/SovOil" for a two-responder code, "Patrons" for a
## venue's (an empty faction shows `own`, the site's own people).
static func responder_name(code: Dictionary, own := "") -> String:
	var c := normalise(code)
	if c.is_empty():
		return ""
	if String(c.faction) == VENUE and String(c.get("responder", "")) != "":
		return String(c.responder).capitalize()
	var who := faction_name(String(c.faction) if String(c.faction) != "" else own)
	if String(c.get("or_faction", "")) != "":
		who += "/" + faction_name(String(c.or_faction))
	return who


## "SECURITY 6 · NCPD · HARDENED MEDIUM" (an empty faction shows `own`, the site's own people).
static func label(code: Dictionary, own := "") -> String:
	var c := normalise(code)
	if c.is_empty():
		return ""
	var who := responder_name(c, own)
	return "SECURITY %d%s · %s%s" % [int(c.n), (" · " + who.to_upper()) if who != "" else "",
		"HARDENED " if bool(c.hardened) else "", String(c.intensity).to_upper()]
