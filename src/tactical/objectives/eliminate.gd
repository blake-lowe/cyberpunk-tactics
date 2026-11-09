extends Objective
## Elimination (a gang hit): put every guard down, backup included.


func check_end() -> String:
	if e.opfor().is_empty() and e.backup_in > 0:
		return ""   # HOUSE-RULE: a gang hit isn't done while backup is still on its way
	return _cleared()


## Half the opposition fielded so far is down (HOUSE-RULE: a gang hit has no package; this is where
## it turns).
func near_done() -> bool:
	var fielded := e.units.filter(func(u): return bool(e.sides[int(u.team)].opfor)).size()
	return done() or (fielded > 0 and e.opfor().size() * 2 <= fielded)


func hud_text() -> String:
	return "ELIMINATE %s\n%d HOSTILES LEFT" % [target_name(String(World.faction(e.opfor_faction).get("name", ""))), e.opfor().size()]


## The gang as the order names it: "THE TYGER CLAWS", "MAELSTROM", "THE BOZOS"; plural names
## take "the", one already starting with it keeps it, and no name falls back to "ALL HOSTILES".
static func target_name(name: String) -> String:
	if name.strip_edges() == "":
		return "ALL HOSTILES"
	var n := name.strip_edges().to_upper()
	if n.begins_with("THE ") or not n.ends_with("S"):
		return n
	return "THE " + n


func before_check() -> void:   # every sighting updates the crew's fix on the hostiles
	for u in e.opfor():
		_sighted(u)


## While no hostile is in sight, an arrow to the nearest one the crew has a fix on (where they were
## last seen), so the last few can be hunted down; nothing for hostiles never seen (no intel). In
## sight, the hostiles themselves are the markers.
func marks(fog: bool) -> Array:
	var left := e.opfor()
	if left.is_empty() or (fog and left.any(func(u): return _in_sight(u))):
		return []
	var from: Vector3i = e.cur.pos if not e.cur.is_empty() else e.units[0].pos
	var best := Vector3i(-1, -1, -1)
	var bd := INF
	var bid := -1
	for u in left:
		var at: Vector3i = _sighted(u) if fog else u.pos
		if at.x < 0:
			continue
		var d := Vector3(at - from).length()
		if d < bd:
			bd = d
			best = at
			bid = u.id
	if best.x < 0:
		return []
	var label := "★ HOSTILE · %d LEFT" % left.size()
	if fog:
		return [{"cell": best, "h": 1.6, "label": label + " · LAST SEEN", "tone": "red"}]
	return [{"cell": best, "h": 1.6, "label": label, "tone": "red", "unit": bid}]
