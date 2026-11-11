extends Objective
## Defend: hold a room of the target building while the target faction comes at it in waves.
## The crew is the one holding the place here: nobody is on its posts (manned), its turrets stand
## with the crew and its doors open to them (they're the client's people). The attack comes from
## the map's entries (the street edges, gates, doors) in escalating waves, the response spawning
## the site's backup uses (Encounter._spawn_wave); the attackers break and run as anyone does
## (Morale). The job is won at the end of the last round of the hold; lost if the attackers hold
## the room at the end of `lost_rounds` rounds running (more of them in it who can fight than of
## the crew who can act), or wreck what's kept there (the asset: a machine, steel cover, CPR core
## p.182: 50 HP). State: {cell (the asset), zone: [squares], room, sec, start, end, waves:
## [rounds], wave_n, entries: [squares], held, round}.
##
## HOUSE-RULE numbers (data/gen/objectives.json defend): the hold by security level, the first
## wave's round and the rounds between waves, each wave's size, the officers that join from the
## second wave, how many rounds the room may be theirs.


## The zone: the target building's most secure room with min_room squares to stand on
## (secure_cell), the squares of it within zone_radius of the asset, which stands on the room's
## square nearest its middle. The crew starts in it.
func setup(target_sid: int, origin: Vector2i, sec: int) -> void:
	e.nav.locked = {}   # the client's building: the crew has the keys (the attackers carry crowbars: guards ignore locks anyway)
	e.reinforcements = false   # nobody calls in the site's response: the waves are the response
	if e.m.devices.any(func(d): return String(d.type) == "turret"):   # the site's turrets are the crew's (Encounter._mount_turrets)
		e.turret_side = e.add_side("crew", "turret", false, {"stands_with": Encounter.CREW})
	var cell := e.secure_cell(target_sid, origin, "machine", int(cfg.get("min_room", 10)))
	var l := e.m.label(cell.z, cell.x, cell.y)
	cell = _middle(cell, l)
	var assets: Dictionary = cfg.assets
	var keys := assets.keys()
	var kind: String = keys[e.dice.d(keys.size()) - 1]
	var entry := Furnish.cover_entry("machine", cell.z, Vector2i(cell.x, cell.y), l)
	entry.kind = kind
	e.m.add_cover(entry)
	e.los.cover_hp[cell] = int(entry.hp)   # steel, thick: CPR core p.182
	var zone: Array = []
	var r := int(cfg.get("zone_radius", 3))
	for y in range(cell.y - r, cell.y + r + 1):
		for x in range(cell.x - r, cell.x + r + 1):
			if e.m.inb(x, y) and e.m.label(cell.z, x, y) == l and e.m.walkable(cell.z, Vector2i(x, y)) and not e.m.has_cover_at(cell.z, Vector2i(x, y)):
				zone.append(Vector3i(x, y, cell.z))
	# The crew is already holding the room when the job starts (they're the client's hired guns, not
	# raiders): placed on its squares nearest the asset. The deploy zone stays the way out.
	var spots := zone.duplicate()
	spots.sort_custom(func(a, b): return Vector2(a.x - cell.x, a.y - cell.y).length() < Vector2(b.x - cell.x, b.y - cell.y).length() or \
		(Vector2(a.x - cell.x, a.y - cell.y).length() == Vector2(b.x - cell.x, b.y - cell.y).length() and a < b))
	var aps := SceneGen.access_point_cells(e.m)   # not in jack-in reach of a terminal (a start never hands the NET over)
	var off := spots.filter(func(v): return not SceneGen.any_jack_reach(e.los, [v], aps))
	if off.size() >= e.units.filter(func(u): return int(u.team) == Encounter.CREW).size():
		spots = off
	var k := 0
	for u in e.units:
		if int(u.team) == Encounter.CREW and k < spots.size():
			u.pos = spots[k]
			k += 1
	var start := int(cfg.get("first_wave", 2))
	var end := start + int((cfg.hold_rounds as Dictionary).get(str(clampi(sec, 1, 3)), 6)) - 1
	var waves: Array = []
	var w := start
	while w <= end:
		waves.append(w)
		w += int(cfg.get("wave_every", 2))
	var room := String(e.m.rooms[l].get("kind", "")) if l >= 0 else ""
	o.merge({"cell": cell, "asset": kind, "asset_name": assets[kind], "zone": zone, "room": room, "sec": sec, "start": start, "end": end,
		"waves": waves, "wave_n": 0, "entries": _entries(zone), "held": 0, "round": 0})


## The standable square of room `l` (on `at`'s floor) nearest the room's middle, else `at`.
func _middle(at: Vector3i, l: int) -> Vector3i:
	if l < 0:
		return at
	var cells: Array = []
	var mid := Vector2.ZERO
	var b: Rect2i = e.m.rooms[l].bounds
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			if e.m.inb(x, y) and e.m.label(at.z, x, y) == l and e.m.walkable(at.z, Vector2i(x, y)) and not e.m.has_cover_at(at.z, Vector2i(x, y)):
				cells.append(Vector3i(x, y, at.z))
				mid += Vector2(x, y)
	if cells.is_empty():
		return at
	mid /= cells.size()
	var occ := e.occupied()
	var best := at
	var bd := INF
	for v in cells:
		var d := Vector2(v.x, v.y).distance_to(mid)
		if not occ.has(v) and d < bd:
			bd = d
			best = v
	return best


## Where the waves come in: the map's entries (not the deploy zone) and the target building's
## doors (they force their way in through the building), the two about arrive_walk squares' walk
## from the zone (near enough to matter, far enough to be seen coming: at least arrive_min), at
## least 6 squares apart, taken in turn. [] when none can be walked to: then the backup's own
## arrival point (Encounter.arrival_cell).
func _entries(zone: Array) -> Array:
	if zone.is_empty():
		return []
	var field: Dictionary = e.nav.distance_field(zone, {}, 4000)
	var deploy: Array = e.extract_cells.keys()
	var room := e.m.label(zone[0].z, zone[0].x, zone[0].y)
	var sid: int = e.m.rooms[room].structure if room >= 0 else -1
	var seen := {}
	var cand: Array = []
	var add := func(v: Vector3i) -> void:
		if seen.has(v) or not field.has(v) or deploy.has(v) or int(field[v]) < int(cfg.get("arrive_min", 6)) or e.m.label(v.z, v.x, v.y) == room:
			return
		seen[v] = true
		cand.append([absi(int(field[v]) - int(cfg.get("arrive_walk", 14))), v])
	for en in e.m.entrances:
		if en.kind != "deploy":
			add.call(Vector3i(en.pos.x, en.pos.y, int(en.get("floor", 0))))
	for v in field:
		if e.m.t(v.z, v.x, v.y) == TacMap.T.DOOR:
			var l := e.m.label(v.z, v.x, v.y)
			if l < 0 or e.m.rooms[l].structure == sid:
				add.call(v)
	cand.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array = []
	for c in cand:
		if out.size() >= 2:
			break
		if not out.any(func(p): return p.z == c[1].z and Vector2(p.x - c[1].x, p.y - c[1].y).length() < 6.0):
			out.append(c[1])
	return out


## The rounds of the hold still to go after this one.
func rounds_left() -> int:
	return maxi(0, int(o.end) - e.init.round_num)


## Rounds until the next wave (0: this round), or -1 when none is still to come.
func next_wave_in() -> int:
	for w in o.waves:
		if int(w) >= e.init.round_num and int(w) > int(o.get("last_wave", 0)):
			return int(w) - e.init.round_num
	return -1


## The attackers hold the room: more of them who can fight stand in it than the crew who can act
## (a ward, an escort's client, doesn't count). HOUSE-RULE: numbers in the room decide it.
func theirs() -> bool:
	var zone: Array = o.zone
	var them := e.opfor().filter(func(u): return zone.has(u.pos)).size()
	if them == 0:
		return false
	return them > e.units.filter(func(u): return int(u.team) == Encounter.CREW and not e.is_hostage(u) and u.c.can_act() and zone.has(u.pos)).size()


func asset_hp() -> int:
	return int(e.los.cover_hp.get(o.cell, 0))


## Every round: the last one's end is judged (theirs or not), the hold ends after its last round,
## and the waves come in on their rounds.
func tick() -> void:
	var r := e.init.round_num
	if r == int(o.round) or done() or e.state != "playing":
		return
	if int(o.round) > 0:
		o.held = int(o.held) + 1 if theirs() else 0
	o.round = r
	if int(o.held) >= int(cfg.get("lost_rounds", 2)):
		e._check_end()
		return
	if r > int(o.end):
		o.done = true
		e._check_end()
		return
	if int(o.waves.find(r)) >= 0:
		_wave()


## Wave k (from 0): wave_base + k * wave_grow Mooks, one more per crew member past two; from the
## second wave on, the security level's officers lead it (escalation).
func _wave() -> void:
	var k := int(o.wave_n)
	var crew_n := e.units.filter(func(u): return int(u.team) == Encounter.CREW and not e.is_hostage(u) and not u.c.dead).size()
	var roster: Array[String] = []
	if k >= 1:
		for t in ((cfg.get("officers", {}) as Dictionary).get(str(clampi(int(o.sec), 1, 3)), []) as Array):
			roster.append(String(t))
	for i in int(cfg.get("wave_base", 2)) + k * int(cfg.get("wave_grow", 1)) + maxi(0, crew_n - 2):
		roster.append("mook")
	var entries: Array = o.entries
	var at: Vector3i = entries[k % entries.size()] if not entries.is_empty() else Vector3i(-1, -1, -1)
	o.wave_n = k + 1
	o["last_wave"] = e.init.round_num
	e.alarm = 2   # no stealth here: they've come to fight
	e._spawn_wave(roster, "WAVE %d" % (k + 1), Encounter.OPFOR, e.opfor_faction, "", false, [] as Array[String], at)


func check_end() -> String:
	if asset_hp() <= 0:
		e.say("%s is wrecked. The gig's over." % String(_asset_text()).capitalize())
		return "lost"
	if int(o.held) >= int(cfg.get("lost_rounds", 2)):
		e.say("They've taken the %s. The gig's over." % _room_text().to_lower())
		return "lost"
	if done():
		e.say("The %s held." % _room_text().to_lower())
		return "won"
	return ""


## "SERVER ROOM" (the room's kind), else "ROOM".
func _room_text() -> String:
	var r := String(o.get("room", ""))
	return r.replace("_", " ").to_upper() if r != "" else "ROOM"


## What's kept there: the gig's focus item ("the tech prototype"), else the machine ("the server rack").
func _asset_text() -> String:
	var it := item_short("")
	return "the " + it if it != "" else String(o.get("asset_name", "the machine"))


func hud_text() -> String:
	var lines: Array[String] = ["HOLD THE %s" % _room_text()]
	lines.append("PROTECT %s" % _asset_text().to_upper())
	var nw := next_wave_in()
	if e.init.round_num < int(o.start):
		lines.append("TAKE COVER · THEY HIT IN %d" % maxi(1, int(o.start) - e.init.round_num))
	else:
		var left := rounds_left()
		lines.append(("HOLD %d MORE ROUND%s" % [left, "" if left == 1 else "S"]) if left > 0 else "LAST ROUND: HOLD ON")
		if nw > 0:
			lines.append("NEXT WAVE IN %d" % nw)
	if theirs():
		lines.append("THEY'RE IN THE %s" % _room_text())
	return "\n".join(lines)


func order() -> String:
	return "HOLD THE %s" % _room_text()


## Set up, then hold out the rounds; with the room theirs, take it back first.
func current_step() -> String:
	if e.init.round_num < int(o.start):
		return "TAKE COVER · THEY HIT IN %d" % maxi(1, int(o.start) - e.init.round_num)
	if theirs():
		return "TAKE THE ROOM BACK"
	var left := rounds_left()
	return "HOLD %s" % count_text(left, "MORE ROUND") if left > 0 else "LAST ROUND · HOLD ON"


func marks(_fog: bool) -> Array:
	var label := "★ HOLD · %s" % _room_text()
	return [{"cell": o.cell, "h": 1.8, "label": label, "tone": "red" if theirs() else "gold"}]


func zones() -> Array:
	return [{"cells": o.zone, "tone": "red" if theirs() else "gold"}]


func manned() -> bool:
	return false


var _zfield := {}
var _zround := -1


## Walking distance to the zone, worked out once a round (doors get shot open, cover wrecked).
func _zone_field() -> Dictionary:
	if _zround != e.init.round_num:
		_zround = e.init.round_num
		_zfield = e.nav.distance_field(o.zone, {}, 4000) if not (o.zone as Array).is_empty() else {}
	return _zfield


func _attacker(u: Dictionary) -> bool:
	return not u.is_empty() and e.is_guard(u) and bool(e.sides[int(u.team)].opfor) and not u.has("broke")


## Attackers press into the room: closer by walking distance is better, a square in it best.
func ai_pull(u: Dictionary, cell: Vector3i) -> float:
	if not _attacker(u):
		return 0.0
	var f := _zone_field()
	return -float(cfg.get("pull", 0.8)) * float(f.get(cell, 99)) + (6.0 if (o.zone as Array).has(cell) else 0.0)


## An attacker who is one of the wreckers (id a multiple of wreck_every) and has the asset in sight
## within wreck_range_m puts its attack into the asset instead (Encounter.shoot_cover).
## One with no shot worth taking (under rush_below expected damage) and the room still a way off
## runs for it (Move and a Run, as the mark does: AI._vip), instead of edging from cover to cover.
func ai_act(u: Dictionary) -> bool:
	if not _attacker(u) or e.turn == null:
		return false
	if _wreck(u):
		return true
	var f := _zone_field()
	if not e.turn.action_available or not e.turn.can_move() or int(f.get(u.pos, 0)) <= u.c.stat("MOVE"):
		return false
	if not u.c.weapons.is_empty() and AI._best_shot_value(e, u, u.c.weapons[0]) >= float(cfg.get("rush_below", 2.0)):
		return false   # a shot worth taking: fight as usual
	var budget: int = e.turn.squares_available() + e.turn.run_squares()
	var opts: Dictionary = e._with_locks(func(): return e.nav.reachable(u.pos, budget, e._blocking(u)))
	var best: Vector3i = u.pos
	var cells: Array = opts.keys()
	cells.sort()   # a stable pick among equals
	for cell in cells:
		if int(f.get(cell, 9999)) < int(f.get(best, 9999)) and not e.occupied(u).has(cell):
			best = cell
	return best != u.pos and e.move_to(best, true)


func _wreck(u: Dictionary) -> bool:
	if asset_hp() <= 0 or u.c.weapons.is_empty() or not e.turn.action_available:
		return false
	var w: Weapon = u.c.weapons[0]
	if w.jammed or (w.uses_ammo() and w.ammo <= 0) or w.is_melee():
		return false
	var cell: Vector3i = o.cell
	if cell.z != u.pos.z or Los.distance_m(u.pos, cell) > float(cfg.get("wreck_range_m", 30.0)) or not e.los.trace(u.pos, cell).clear:
		return false
	if int(u.id) % int(cfg.get("wreck_every", 3)) != 0:
		return false
	return bool(e.shoot_cover(cell, w).get("ok", false))


## Auto-play: into the room and fight from there.
func crew_goal(_u: Dictionary) -> Variant:
	return o.zone


func focus_cell() -> Vector3i:
	return o.cell
