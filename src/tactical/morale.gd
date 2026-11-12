class_name Morale
extends RefCounted
## Morale (Cyberpunk RED: Single Player Mode, SPM p.20-21; the table is reprinted on p.32): not
## everyone fights to the last body. At a stress point an NPC rolls 1d10; at or under its
## mentality's threshold it stops fighting: it runs for the edge of the map, or, with no way off,
## hides out of the way. HOUSE-RULE (owner, playtest 2026-11-11: "get rid of surrendering and only
## let them flee or hide"): the book's surrender is not played; a broken NPC never gives itself up.
## Rules only: Encounter calls sweep() at every end check and does the state changes
## (Encounter.start_flight, start_hiding, flee_out); the AI runs the fleeing and the hiding
## (AI.flee, AI.hide).
##
## The odds per stress point are the book's table as written: 1d10 at or under the threshold, so a
## Mook breaks 90% of the time, a Hardened Mook 80%, a Lieutenant 60%, a Mini-Boss 40% and anyone
## fully committed 20% (break_chance). A Mook that reaches Seriously Wounded therefore almost
## always quits: that is the book's "unsure streetrat", not luck.
##
## Stress points (the owner's pick of the book's examples, SPM p.20):
##   wounded: the unit itself reaching Seriously Wounded;
##   half:    more than half of its side down (dead, out cold, or already quit: HOUSE-RULE, the book
##            says "incapacitated or dead", and a side whose people are running reads as beaten);
##   leader:  its side's leader down: the side's top tier above Mook, once no unit of that tier
##            still stands (two Lieutenants: both).
## Each unit rolls at most once per stress type, and never again once it has quit. No calming
## down (HOUSE-RULE, kept simple): a unit that holds its nerve at a stress point stays in the fight.
## Who rolls: anyone on a guard-run side (the opposition, their backup, police, a free-for-all's
## gangs) once they know there's a fight (alerted); Trauma Team only once the crew has shot at
## them. Never the mark on an assassination (it already runs for an exit: AI._vip), turrets,
## bystanders, the crew or a captive.

## SPM p.21 (Morale table, reprinted p.32): 1d10 at or under this ends the fight for them.
const THRESHOLD := {
	"committed": 2,       # lost to violence / fully dedicated: a raging cyberpsycho, a ganger on combat drugs, a Boss's last stand
	"mini_boss": 4,       # experienced combatant: hardened ganger or elite security, Mini-Boss
	"lieutenant": 6,      # trained combatant: experienced ganger or regular security, Lieutenant
	"hardened_mook": 8,   # inexperienced combatant: newbie ganger or security, Hardened Mook
	"mook": 9,            # unsure streetrat: cannon fodder, Mook
}
## Factions who are always fully committed. MaxTac: the owner's call ("MaxTac is committed").
const COMMITTED_FACTIONS := ["maxtac"]
const TIER_RANK := {"mook": 1, "lieutenant": 2, "mini_boss": 3, "boss": 4}
const STRESSES := ["wounded", "half", "leader"]
const STRESS_TEXT := {"wounded": "badly hurt", "half": "half their side down", "leader": "their leader down"}


## The mentality row for `u` (a THRESHOLD key). RULES: the book's rows map to our NPC tiers one to
## one (Mook, Hardened Mook, Lieutenant, Mini-Boss); Hardened Lieutenants and Mini Bosses keep their
## tier's row (HOUSE-RULE: the book's "hardened ganger" row is the Mini-Boss one, and moving every
## Hardened Lieutenant up to it would make them as steady as Mini Bosses). The Boss tier, the
## Cyberpsycho, anyone with a combat drug in their system (a complication's `drug` fx, or a dose
## from the crew) and MaxTac are fully committed.
static func mentality(e: Encounter, u: Dictionary) -> String:
	var c: Combatant = u.c
	if committed(c, e.faction_of(u)):
		return "committed"
	match String(c.role):
		"mini_boss":
			return "mini_boss"
		"lieutenant":
			return "lieutenant"
	return "hardened_mook" if hardened(c) else "mook"


static func threshold(e: Encounter, u: Dictionary) -> int:
	return int(THRESHOLD[mentality(e, u)])


## The chance a unit of this mentality breaks at one stress point: the threshold out of 10.
static func break_chance(mentality_id: String) -> float:
	return float(THRESHOLD.get(mentality_id, 0)) / 10.0


static func committed(c: Combatant, faction: String) -> bool:
	return String(c.role) == "boss" or c.block == "cyberpsycho" or not c.drugs_taken.is_empty() or faction in COMMITTED_FACTIONS \
		or c.psychosis_turns > 0


## A Hardened-series stat block (npcs.json `hardened`).
static func hardened(c: Combatant) -> bool:
	if c.block == "":
		return false
	var b: Dictionary = (RulesDB.load_json("npcs.json")["blocks"] as Dictionary).get(c.block, {})
	return bool(b.get("hardened", false))


## Whether `u` can roll for morale now.
static func eligible(e: Encounter, u: Dictionary) -> bool:
	if u.c.dead or not u.c.can_act() or u.has("broke") or u.has("turret") or u.get("vip", false) or u.get("civ", false) \
			or u.get("captive", false) or u.get("carried", false):
		return false
	var ai := String(e.sides[int(u.team)].ai)
	if ai == "trauma":
		return e.tt_hostile
	return ai == "guard" and bool(u.alerted)


## The side a unit counts with (breaking never moves it to another side).
static func side_of(u: Dictionary) -> int:
	return int(u.team)


## Out of the fight: dead (or gone off the map), down, or quit.
static func down(u: Dictionary) -> bool:
	return u.c.dead or not u.c.can_act() or u.c.wound_state() == Combatant.Wound.MORTAL or u.has("broke")


## The side-wide stress points standing right now for team `t`: {half, leader}.
static func side_stress(e: Encounter, t: int) -> Dictionary:
	var total := 0
	var out := 0
	var top := 0
	for u in e.units:
		if side_of(u) != t or u.has("turret") or u.get("civ", false):
			continue
		total += 1
		if down(u):
			out += 1
		top = maxi(top, int(TIER_RANK.get(String(u.c.role), 1)))
	var leader := false
	if top >= 2:
		leader = not e.units.any(func(u): return side_of(u) == t and not u.has("turret") and not down(u) \
			and int(TIER_RANK.get(String(u.c.role), 1)) == top)
	return {"half": total > 0 and out * 2 > total, "leader": leader}


## The stress points `u` hasn't rolled for yet that stand now, in STRESSES order.
static func pending(e: Encounter, u: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var rolled: Dictionary = u.get("morale_rolls", {})
	var side := side_stress(e, int(u.team))
	for s in STRESSES:
		if rolled.has(s):
			continue
		var on := false
		match s:
			"wounded":
				on = u.c.wound_state() >= Combatant.Wound.SERIOUS
			_:
				on = bool(side[s])
		if on:
			out.append(s)
	return out


## Roll for everyone at a stress point, in unit order (deterministic for the soak). A unit that
## breaks changes its side's count before the next one rolls. Returns the units that broke.
static func sweep(e: Encounter) -> Array:
	var broke: Array = []
	for u in e.units:
		if not eligible(e, u):
			continue
		for s in pending(e, u):
			if not u.has("morale_rolls"):
				u["morale_rolls"] = {}
			var r := e.dice.d(10)
			var thr := threshold(e, u)
			u.morale_rolls[s] = r
			if r <= thr:
				if choose(e, u) == "hide":
					e.start_hiding(u, s, r, thr)
				else:
					e.start_flight(u, s, r, thr)
				broke.append(u.id)
				break
	return broke


## Flee or hide (HOUSE-RULE, owner): run for the edge when there is a way off the map from here
## (a hold or a fall is dealt with on the way: AI.flee gets up and breaks free first), else hide.
## Trauma Team always pulls out.
static func choose(e: Encounter, u: Dictionary) -> String:
	if String(e.sides[int(u.team)].ai) == "trauma":
		return "flee"
	return "flee" if flee_field(e).has(u.pos) else "hide"


## Where a fleeing unit leaves the map: the map's walkable entrances (in a tower band, the ones
## marked as exits), the crew's deploy zone only when there is no other; walking distances to them.
static func flee_field(e: Encounter) -> Dictionary:
	var exits: Array = []
	var deploy: Array = []
	for en in e.m.entrances:
		var v := Vector3i(en.pos.x, en.pos.y, int(en.get("floor", 0)))
		if not e.m.walkable(v.z, en.pos) or not bool(en.get("exit", true)):
			continue
		if String(en.kind) == "deploy":
			deploy.append(v)
		else:
			exits.append(v)
	if exits.is_empty():
		exits = deploy
	if exits.is_empty():
		return {}
	return e._with_locks(func(): return e.nav.distance_field(exits, {}, 4000))


## "badly hurt", "half their side down", "their leader down".
static func why_text(stress: String) -> String:
	return String(STRESS_TEXT.get(stress, stress))
