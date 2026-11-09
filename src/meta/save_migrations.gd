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
## v11: operations (M9 P4, Playland by the Sea): a gig may carry `legs` (maps played back to back;
##     offers without them are single-map gigs, as every older offer is), and the save keeps an
##     operation in progress between legs, `operation` (the active gig with its leg, the legs done,
##     the van and what the crew carries over; {} when none, which every older save gets).
## v12: an operation's per-member state is keyed by place in the crew, not by handle (two crew
##     members may share a handle). `operation.van` becomes a list of {crew (index), key, ammo, at}
##     (or {crew, key, slot} for a kit grenade); `operation.carry` a list in crew order (each entry
##     gains per-weapon jams/special rounds and armour rigging, which older saves simply lack);
##     `operation.present` a list of crew indices. A v11 handle maps to the first crew member with
##     it: a v11 save with a repeated handle had already merged their entries.
## v13: multi-map operations and Playland by the Sea are descoped (owner). The operation in progress
##     and what it carried between legs (`operation`) are dropped: the crew records already hold
##     how each member stood, and the leg being played was never saved (as a quit single gig).
##     Operation offers (gigs with `legs`) leave the board. Weapons the park's gate left in the van go
##     to safehouse storage so nothing is lost; a kit grenade in the van never left storage (a kit
##     slot only names what storage holds), so it goes back in its owner's slot if that is still empty.
## v14: every board offer is at a canon location (owner ruling 2026-11-04: no generic places). Offers
##     without a `location` (the old generic offers: a scene or site picked by tags) leave the board;
##     the save is marked `refill_board` and Campaign.from_dict tops the board up with canon offers
##     (the migration can't: it reads no city data and rolls no dice).
## v15: save slots. The campaign counts the gigs it has played to the end, `gigs_done`, for the
##     slot listing; an older save doesn't know how many it played and starts at 0.
## v16: the Mission Builder (SPM p.28). Board offers carry `client`, `mission`, `focus`, `payment`
##     ({type, base, eb, ...}: eb, information, a favour or goods) and `twist` (null until twists are
##     built). An older offer has none of the first three and keeps its title and blurb (the board
##     shows what it has); it gains an eb `payment` of its `pay` and twist null. The campaign gains
##     `intel` (information tokens, 0) and `favours` (favour tokens, none).
##     Corpse loot (Single Player Mode, CorpseLoot): the campaign keeps `leads`, the plot hooks
##     found on bodies ({label, hook, day, gig, faction, district, location, from}); an older save
##     found none and starts with an empty list. Loot itself lands in the stash, which is unchanged.
## v17: Plot Twists (SPM p.75-76, Twist). A board offer's `twist` is null (no twist: most jobs) or
##     a hidden {row, roll, id, label, trigger, oracle?}. Every v16 offer has twist null and loads as
##     a job with no twist; a twist in any other shape (junk, or a row the game no longer plays) is
##     dropped to null rather than sprung half-understood. The dev builder's last form gains its
##     `twist` field at "auto" (the form's defaults fill it on use).

const CURRENT := 17


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
			10: _v10_to_v11(d)
			11: _v11_to_v12(d)
			12: _v12_to_v13(d)
			13: _v13_to_v14(d)
			14: _v14_to_v15(d)
			15: _v15_to_v16(d)
			16: _v16_to_v17(d)
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


static func _v10_to_v11(d: Dictionary) -> void:
	if not d.has("operation"):
		d["operation"] = {}


static func _v11_to_v12(d: Dictionary) -> void:
	var op: Variant = d.get("operation", {})
	if not op is Dictionary or (op as Dictionary).is_empty():
		return
	var names: Array = (d.get("crew", []) as Array).map(func(c): return String(c.get("name", "")) if c is Dictionary else "")
	var van: Variant = op.get("van", [])
	if van is Dictionary:
		var out: Array = []
		for nm in van:
			for it in van[nm]:
				var e: Dictionary = (it as Dictionary).duplicate()
				e["crew"] = names.find(String(nm))
				out.append(e)
		op["van"] = out
	var carry: Variant = op.get("carry", [])
	if carry is Dictionary:
		op["carry"] = names.map(func(nm): return ((carry as Dictionary).get(nm, {}) as Dictionary).merged({"name": nm}))
	var present: Variant = op.get("present", [])
	if present is Dictionary:
		var idx: Array = []
		for i in names.size():
			if (present as Dictionary).has(names[i]):
				idx.append(i)
		op["present"] = idx


static func _v12_to_v13(d: Dictionary) -> void:
	var op: Variant = d.get("operation", {})
	if op is Dictionary:
		var stash: Dictionary = d.get("stash", {})
		d["stash"] = stash
		var crew: Array = d.get("crew", [])
		var van: Variant = (op as Dictionary).get("van", [])
		for it in (van if van is Array else []):
			if not it is Dictionary or String(it.get("key", "")) == "":
				continue
			var key := String(it.key)
			if not (it as Dictionary).has("slot"):
				stash[key] = int(stash.get(key, 0)) + 1   # the weapon comes home to storage
				continue
			var k := int(it.get("crew", -1))
			var s := int(it.slot)
			if k >= 0 and k < crew.size() and crew[k] is Dictionary:
				var kit: Array = crew[k].get("kit", [])
				if s >= 0 and s < kit.size() and String(kit[s]) == "":
					kit[s] = key
	d.erase("operation")
	var board: Array = d.get("board", [])
	d["board"] = board.filter(func(g): return not (g is Dictionary and g.get("legs") is Array and (g.legs as Array).size() > 1))


static func _v13_to_v14(d: Dictionary) -> void:
	var board: Array = d.get("board", [])
	var kept: Array = board.filter(func(g): return g is Dictionary and String(g.get("location", "")) != "")
	if kept.size() < board.size():
		d["refill_board"] = true
	d["board"] = kept


static func _v14_to_v15(d: Dictionary) -> void:
	if not d.has("gigs_done"):
		d["gigs_done"] = 0


static func _v15_to_v16(d: Dictionary) -> void:
	for g in d.get("board", []):
		if not g is Dictionary:
			continue
		if not (g as Dictionary).has("payment"):
			var pay := int(g.get("pay", 0))
			g["payment"] = {"type": "eb", "base": pay, "eb": pay}
		if not (g as Dictionary).has("twist"):
			g["twist"] = null
	if not d.has("intel"):
		d["intel"] = 0
	if not d.has("favours"):
		d["favours"] = []
	if not (d.get("leads") is Array):
		d["leads"] = []


static func _v16_to_v17(d: Dictionary) -> void:
	for g in d.get("board", []):
		if g is Dictionary and not Twist.valid((g as Dictionary).get("twist")):
			g["twist"] = null
		elif g is Dictionary and not (g as Dictionary).has("twist"):
			g["twist"] = null
	var lc: Variant = d.get("last_custom")
	if lc is Dictionary and not (lc as Dictionary).is_empty() and not (lc as Dictionary).has("twist"):
		lc["twist"] = "auto"
