class_name SaveMigrations
extends RefCounted
## Campaign save format versions. Every change to what Campaign.to_dict writes bumps CURRENT and
## adds a step here that upgrades the previous version's dictionary in place, so old saves keep
## loading as the game grows (Night City 2047 will add a lot of world state). Steps are pure
## Dictionary → Dictionary edits with no game objects, so each is easy to test on its own.
##
## v1: the first slice (M6/M7): crew, board, fixer rep, heat, facilities.
## v2: factions. Board gigs name their target faction; the campaign tracks standing per faction.

const CURRENT := 2


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
