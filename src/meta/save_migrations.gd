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

const CURRENT := 4


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
