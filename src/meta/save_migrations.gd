class_name SaveMigrations
extends RefCounted
## Campaign save format versions. Every change to what Campaign.to_dict writes bumps CURRENT and
## adds a step here that upgrades the previous version's dictionary in place, so old saves keep
## loading as the game grows (Night City 2047 will add a lot of world state). Steps are pure
## Dictionary → Dictionary edits with no game objects, so each is easy to test on its own.
##
## v1: the first slice (M6/M7): crew, board, fixer rep, heat, facilities.
## v2: factions. Board gigs name their target faction; the campaign tracks standing per faction.
## v3: inventory. Safehouse storage (stash); each crew member's two kit slots and addictions.
## v4: frags are kit. Carried frag grenades go into storage (one packed in slot 1); slot 2 holds
##     utilities only, so a consumable there moves to an empty slot 1 or back into storage.
## v5: core-book systems only. Campaign heat, per-faction standing and per-fixer rep are gone; the
##     campaign's rep becomes each crew member's Reputation (p193); Train/Hustle downtime becomes
##     Recover; the Frag Grenade (not in the book) leaves storage and kits, refunded at its 50eb; the
##     Armory no longer has levels, so what was spent building it comes back.
## v6: storage for everything and the book's Night Market. Safehouse rooms have no levels or
##     effects any more (Med Bay, Fixer Network, Training Room): what was spent building them comes
##     back. The stash may now hold weapons ("weapon/<id>[@quality]") and armour ("armor/<id>..."),
##     which old saves never had, so it carries over as is and the crew keep what they carry. The
##     campaign gains a Night Market (Campaign rolls one on load when it's empty).
## v7: cyberware is bought like other gear. The stash may now hold "cyberware/<id>" pieces waiting
##     to be installed at the Med Bay. A v6 stash never held any (chrome was installed as it was
##     bought), so any "cyberware/..." key in one is junk the v6 loader ignored; it is dropped here so
##     it can't turn into a free piece. Installed chrome stays installed. Debrief entries gain "lost"
##     (what a fallen member had on them): v6 entries list their lost kit there.
## v8: Night City 2045 Security and Utility Codes (NC2045 p.7-8). Board gigs carry `district`,
##     `security_code`, `district_code` and `utility_code`. Older offers get them on load, outside
##     the migration (it would have to read the city data): Campaign.from_dict → code_loaded_gig,
##     from their location, else the fallback for their 1-3 security level, which stays.
## v9: the book's complication tables replace our gig twists and fixer setups (M9). Board offers lose
##     `twist` and `setup` (an offer that was a setup becomes an honest job); new offers carry
##     `fixer_id`, `hook` and `district` from Night City's fixers and locations, which older offers
##     simply lack (the board shows what they have).
## v10: travel time (NC2045 p.18-20). The campaign has a safehouse district (every drive to a gig
##     starts there; older crews get Campaign.DEFAULT_SAFEHOUSE) and a clock within the day,
##     `minutes` (0 at midnight; older saves start the day fresh).

const CURRENT := 10


## Upgrade `d` (a parsed save) to CURRENT. Returns {} for a save from a newer build, which this
## one can't read safely.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v > CURRENT:
		push_warning("campaign save is version %d; this build reads up to %d" % [v, CURRENT])
		return {}
	while v < CURRENT:
		match v:
			1: _v1_to_v2(d)
			2: _v2_to_v3(d)
			3: _v3_to_v4(d)
			4: _v4_to_v5(d)
			5: _v5_to_v6(d)
			6: _v6_to_v7(d)
			7: _v7_to_v8(d)
			8: _v8_to_v9(d)
			9: _v9_to_v10(d)
		v += 1
		d["version"] = v
	return d


static func _v1_to_v2(d: Dictionary) -> void:
	for g in d.get("board", []):
		if not (g as Dictionary).has("faction"):
			g["faction"] = World.DEFAULT_OPFOR   # pre-faction gigs were against generic security
	if not d.has("faction_rep"):
		d["faction_rep"] = {}
	for c in d.get("crew", []) + d.get("recruits", []):
		if not (c as Dictionary).has("faction"):
			c["faction"] = "crew"


static func _v2_to_v3(d: Dictionary) -> void:
	if not d.has("stash"):
		d["stash"] = {}
	for c in d.get("crew", []) + d.get("recruits", []):
		if not (c as Dictionary).has("kit"):
			c["kit"] = ["", ""]
		if not (c as Dictionary).has("addictions"):
			c["addictions"] = []



const FRAG := "ammo/frag_grenade"


static func _v3_to_v4(d: Dictionary) -> void:
	var stash: Dictionary = d.get("stash", {})
	d["stash"] = stash
	for c in d.get("crew", []):
		var kit: Array = c.get("kit", ["", ""])
		c["kit"] = kit
		if kit.size() > 1 and kit[1] != "" and Items.kind(String(kit[1])) != "utility":
			if kit[0] == "":
				kit[0] = kit[1]
			kit[1] = ""   # still in storage: the stash counts packed items too
		var n := int(c.get("grenades", 0))
		if n > 0:
			stash[FRAG] = int(stash.get(FRAG, 0)) + n
			if kit[0] == "":
				kit[0] = FRAG
	for c in d.get("crew", []) + d.get("recruits", []):
		(c as Dictionary).erase("grenades")


const FRAG_PRICE := 50                    ## what v4 sold a frag for (refunded)
const ARMORY_COSTS := [1000, 3000]        ## what v4 charged per Armory level (refunded)


static func _v4_to_v5(d: Dictionary) -> void:
	var refund := 0
	# The old campaign rep was the crew's street name on the same 0-10ish scale the board and market
	# gate on, so each crew member keeps it as their Reputation Level (capped at the book's 10).
	var rep := clampi(int(d.get("rep", 0)), 0, 10)
	for c in d.get("crew", []):
		c["reputation"] = rep
	for c in d.get("crew", []) + d.get("recruits", []):
		if String(c.get("downtime", "recover")) != "recover":
			c["downtime"] = "recover"
		var kit: Array = c.get("kit", [])
		for i in kit.size():
			if kit[i] == FRAG:
				kit[i] = ""
	var stash: Dictionary = d.get("stash", {})
	refund += FRAG_PRICE * int(stash.get(FRAG, 0))
	stash.erase(FRAG)
	var fac: Dictionary = d.get("facilities", {})
	for i in mini(int(fac.get("armory", 0)), ARMORY_COSTS.size()):
		refund += int(ARMORY_COSTS[i])
	fac.erase("armory")
	d["eb"] = int(d.get("eb", 0)) + refund
	for k in ["rep", "heat", "fixer_rep", "faction_rep"]:
		d.erase(k)
	for g in d.get("board", []):
		(g as Dictionary).erase("rep")


## What v5 charged per level of each room (refunded): Campaign.FACILITIES as it was.
const FACILITY_COSTS := {"med_bay": [1500, 4000], "intel": [1500, 4000], "training": [1000, 3000]}


static func _v5_to_v6(d: Dictionary) -> void:
	var refund := 0
	var fac: Dictionary = d.get("facilities", {})
	for id in fac:
		var costs: Array = FACILITY_COSTS.get(String(id), [])
		for i in mini(int(fac[id]), costs.size()):
			refund += int(costs[i])
	d.erase("facilities")
	d["eb"] = int(d.get("eb", 0)) + refund
	if not d.has("market"):
		d["market"] = {}


static func _v6_to_v7(d: Dictionary) -> void:
	var stash: Dictionary = d.get("stash", {})
	for k in stash.keys():
		if String(k).begins_with("cyberware/"):
			stash.erase(k)
	for m in d.get("debrief", []):
		if m is Dictionary and not (m as Dictionary).has("lost"):
			m["lost"] = (m.get("kit", []) as Array).duplicate() if m.get("dead", false) else []


## The codes come from the city data, which a migration doesn't read: Campaign.from_dict gives any
## offer without a `security_code` its codes on load (Campaign.code_loaded_gig). Nothing to edit.
static func _v7_to_v8(_d: Dictionary) -> void:
	pass


static func _v8_to_v9(d: Dictionary) -> void:
	for g in d.get("board", []):
		if g is Dictionary:
			(g as Dictionary).erase("twist")
			(g as Dictionary).erase("setup")


static func _v9_to_v10(d: Dictionary) -> void:
	if not d.has("safehouse_district"):
		d["safehouse_district"] = Campaign.DEFAULT_SAFEHOUSE
	if not d.has("minutes"):
		d["minutes"] = 0
