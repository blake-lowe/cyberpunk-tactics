class_name AI
extends RefCounted
## Simple combat AI for guards (and crew in auto-play tests): shoot the best visible target;
## otherwise advance toward the nearest enemy, preferring squares beside cover from which someone
## is visible, then shoot if possible. Cyberpsychotic units treat everyone as an enemy (approved
## house rule): they go for the nearest target of either team.

const MIN_CHANCE := 0.15


static func act(e: Encounter, u: Dictionary) -> void:
	if u.get("vip", false):
		_vip(e, u)
		return
	if u.c.weapons.is_empty():
		return
	var w: Weapon = u.c.weapons[0]
	if w.uses_ammo() and w.ammo <= 0:
		for f in _enemies(e, u):   # empty with an enemy in reach: hit them rather than reload
			if e.adjacent(u.pos, f.pos):
				e.melee(f)
				return
		e.reload(w)
		return
	if _special(e, u, w):   # a grenade, a shotgun shell, suppression or a punch beats the best shot
		return
	if not _shoot(e, u, w):
		_advance(e, u)
		if not _special(e, u, w):
			_shoot(e, u, w)


## Expected damage of the best plain shot this turn (for comparing with the area options).
static func _best_shot_value(e: Encounter, u: Dictionary, w: Weapon) -> float:
	var best := 0.0
	for t in _enemies(e, u):
		var p := e.preview(t, w, Attack.Mode.SINGLE)
		if p.ok:
			best = maxf(best, p.chance * w.dice() * 3.5 * mini(2, w.rof()))
		var pa := e.preview(t, w, Attack.Mode.AUTOFIRE)
		if pa.ok:
			best = maxf(best, pa.chance * 7.0 * w.autofire_mult() * 0.6)
	return best


## The M5 options, taken when they're clearly better than shooting:
## - grenade: two or more enemies (and no friends) in a 5x5 blast within throwing range;
## - shotgun shell: two or more enemies in the cone;
## - melee: an enemy next to us and the gun is empty or hopeless;
## - suppression: three or more enemies in sight and every shot is a long shot.
static func _special(e: Encounter, u: Dictionary, w: Weapon) -> bool:
	if not e.turn.action_available:
		return false
	var foes := _enemies(e, u)
	var shot := _best_shot_value(e, u, w)
	if u.c.grenades > 0:
		var best_cell := Vector3i(-1, -1, -1)
		var best_n := 1
		for f in foes:
			var cell: Vector3i = f.pos
			if cell.z != u.pos.z or Los.distance_m(u.pos, cell) > Encounter.THROW_RANGE_M or not e.los.trace(u.pos, cell).clear:
				continue
			var n := 0
			var friends := 0
			for o in e.units:
				if not o.c.dead and o.pos.z == cell.z and maxi(absi(o.pos.x - cell.x), absi(o.pos.y - cell.y)) <= Encounter.BLAST_HALF:
					if o.team == u.team:
						friends += 1
					else:
						n += 1
			if friends == 0 and n > best_n:
				best_n = n
				best_cell = cell
		if best_cell.x >= 0 and best_n * 21.0 * 0.5 > shot:
			return e.throw_grenade(best_cell).get("ok", false)
	if w.def.get("shotgun_shell", false) and w.ammo > 0:
		for f in foes:
			var cone := 0
			for o in foes:
				var d := Vector2(o.pos.x - u.pos.x, o.pos.y - u.pos.y)
				var a := Vector2(f.pos.x - u.pos.x, f.pos.y - u.pos.y)
				if o.pos.z == u.pos.z and Los.distance_m(u.pos, o.pos) <= Attack.SHOTGUN_SHELL_RANGE_M and rad_to_deg(absf(a.angle_to(d))) <= Encounter.SHELL_HALF_ANGLE:
					cone += 1
			if cone >= 2:
				return e.shotgun_shell(f, w).get("ok", false)
	for f in foes:
		if e.adjacent(u.pos, f.pos) and ((w.uses_ammo() and w.ammo <= 0) or shot < 4.0):
			return e.melee(f).get("ok", false)
	if w.def.get("suppressive", false) and w.ammo >= Attack.AUTOFIRE_AMMO and shot < 5.0:
		var seen := foes.filter(func(f): return Los.distance_m(u.pos, f.pos) <= Attack.SUPPRESSIVE_RANGE_M and e.los.sight(u.pos, f.pos).visible)
		if seen.size() >= 3:
			return e.suppress(w).get("ok", false)
	return false


static func _enemies(e: Encounter, u: Dictionary) -> Array:
	var psycho: bool = e.turn != null and e.turn.psychotic
	return e.units.filter(func(o): return o != u and not o.c.dead and (psycho or o.team != u.team))


static func _shoot(e: Encounter, u: Dictionary, w: Weapon) -> bool:
	var best: Dictionary = {}
	var best_score := 0.0
	var best_mode := Attack.Mode.SINGLE
	for t in _enemies(e, u):
		for mode in [Attack.Mode.SINGLE, Attack.Mode.AUTOFIRE]:
			var p := e.preview(t, w, mode)
			if not p.ok or p.chance < MIN_CHANCE:
				continue
			var score: float = p.chance * (w.dice() * 3.5 if mode == Attack.Mode.SINGLE else 7.0 * w.autofire_mult() * 0.6)
			if t.c.wound_state() == Combatant.Wound.MORTAL:
				score *= 0.5
			if int(e.objective.get("carrier", -1)) == t.id:
				score *= 1.6   # stop the package leaving
			if score > best_score:
				best_score = score
				best = t
				best_mode = mode
	if best.is_empty():
		return false
	var shots := 1 if best_mode != Attack.Mode.SINGLE else mini(2, w.rof())
	for i in shots:
		if best.c.dead or (w.uses_ammo() and w.ammo <= 0):
			break
		var r := e.attack(best, w, best_mode)
		if not r.get("ok", false):
			break
	return true


static func _advance(e: Encounter, u: Dictionary) -> void:
	var foes := _enemies(e, u)
	if foes.is_empty() or not e.turn.can_move():
		return
	var opts := e.move_options()
	# Walking distance to the nearest foe (not straight-line), so walls don't trap the AI.
	var field: Dictionary = e._with_locks(func(): return e.nav.distance_field(foes.map(func(f): return f.pos), {}))
	var best: Vector3i = u.pos
	var best_score := -INF
	for cell in opts:
		var dmin: float = float(field.get(cell, 999))
		var sees := false
		for f in foes:
			if not sees and absi(cell.x - f.pos.x) + absi(cell.y - f.pos.y) < 30 and e.los.sight(cell, f.pos).visible:
				sees = true
		var covered := covered_from(e, cell, foes)
		var exposed := 0   # foes with a clear shot at the square from where they stand
		for f in foes:
			if f.pos.z == cell.z and Vector2(cell.x - f.pos.x, cell.y - f.pos.y).length() < 25 and e.los.trace(f.pos, cell).clear and not covered:
				exposed += 1
		var score := -dmin + (8.0 if sees else 0.0) + (5.0 if covered else 0.0) - exposed * 2.0 + _objective_pull(e, u, cell)
		if score > best_score:
			best_score = score
			best = cell
	if best != u.pos:
		e.move_to(best)



## Snatch gigs: guards close on whoever carries the package, and a few hang back to guard it while
## it's still on the floor.
static func _objective_pull(e: Encounter, u: Dictionary, cell: Vector3i) -> float:
	if u.team != 1 or e.objective.get("kind", "") != "snatch":
		return 0.0
	var carrier: int = e.objective.get("carrier", -1)
	if carrier >= 0:
		var cp: Vector3i = e.units[carrier].pos
		return -0.6 * Vector2(cp.x - cell.x, cp.y - cell.y).length() if cp.z == cell.z else 0.0
	var pk: Vector3i = e.objective.cell
	if u.id % 3 == 0 and pk.z == cell.z and Vector2(pk.x - cell.x, pk.y - cell.y).length() <= 3.0:
		return 10.0   # one guard in three keeps watch over the package
	return 0.0


## Cover that faces the threat (the reviewer's catch: any solid square beside us used to count):
## something solid on the square next to `cell` toward the nearest foe (diagonals check both
## orthogonal neighbours), the way the crew's cover shields work.
static func covered_from(e: Encounter, cell: Vector3i, foes: Array) -> bool:
	var near: Dictionary = {}
	var nd := INF
	for f in foes:
		var d := Vector2(f.pos.x - cell.x, f.pos.y - cell.y).length()
		if f.pos.z == cell.z and d < nd:
			nd = d
			near = f
	if near.is_empty():
		return false
	var sx := signi(near.pos.x - cell.x)
	var sy := signi(near.pos.y - cell.y)
	var steps: Array[Vector2i] = []
	if absi(near.pos.x - cell.x) >= absi(near.pos.y - cell.y) * 2:
		steps.append(Vector2i(sx, 0))
	elif absi(near.pos.y - cell.y) >= absi(near.pos.x - cell.x) * 2:
		steps.append(Vector2i(0, sy))
	else:
		steps.append(Vector2i(sx, 0))
		steps.append(Vector2i(0, sy))
	for s in steps:
		if e.los.blocker(Vector3i(cell.x + s.x, cell.y + s.y, cell.z)) != "":
			return true
	return false



## The mark: stays put while it's quiet; once they or the site are alerted, runs (Move and a Run)
## for the nearest exit, and is gone on reaching it. Bodyguards fight normally.
static func _vip(e: Encounter, u: Dictionary) -> void:
	if not (u.alerted or e.alarm >= 1):
		return
	var exits: Array = e.objective.get("exits", [])
	if exits.is_empty():
		return
	var field: Dictionary = e._with_locks(func(): return e.nav.distance_field(exits, {}, 4000))
	if int(field.get(u.pos, 999)) == 0:
		e._vip_escapes(u)
		return
	var budget: int = e.turn.squares_available() + (u.c.stat("MOVE") if e.turn.action_available else 0)
	var opts: Dictionary = e._with_locks(func(): return e.nav.reachable(u.pos, budget, e._blocking(u)))
	var best: Vector3i = u.pos
	for cell in opts:
		if int(field.get(cell, 999)) < int(field.get(best, 999)) and not e.occupied(u).has(cell):
			best = cell
	if best != u.pos and e.move_to(best, true) and int(field.get(best, 999)) == 0:
		e._vip_escapes(u)


## A freed captive: keep beside the crew member nearest to the extraction zone; step into the zone
## when they're there. Unarmed, so that's all.
static func follow(e: Encounter, u: Dictionary) -> void:
	var crew := e.units.filter(func(o): return o.team == 0 and o != u and not o.get("captive", false) and o.c.can_act())
	if crew.is_empty() or not e.turn.can_move():
		return
	var ex: Array = e.extract_cells.keys()
	var to_ex: Dictionary = e._with_locks(func(): return e.nav.distance_field(ex, {}, 4000))
	crew.sort_custom(func(a, b): return int(to_ex.get(a.pos, 9999)) < int(to_ex.get(b.pos, 9999)))
	var lead: Dictionary = crew[0]
	var opts := e.move_options()
	var best: Vector3i = u.pos
	var best_s := INF
	var lead_out: bool = e.extract_cells.has(lead.pos)
	for cell in opts.keys() + [u.pos]:
		var d := Vector2(cell.x - lead.pos.x, cell.y - lead.pos.y).length() + absi(cell.z - lead.pos.z) * 4.0
		var sc := maxf(d - 1.5, 0.0) * 2.0 + float(to_ex.get(cell, 999)) * 0.15
		if lead_out and e.extract_cells.has(cell):
			sc -= 50.0
		if sc < best_s:
			best_s = sc
			best = cell
	if best != u.pos:
		e.move_to(best)



## Trauma Team: get to the patient, carry them back to the AV, lift off. They ignore the fight
## unless someone on the crew shoots at them (then they shoot back, still doing the job).
static func trauma(e: Encounter, u: Dictionary) -> void:
	var tt: Dictionary = e.tt
	if tt.get("state", "") != "landed":
		return
	var patient: Dictionary = e.units[int(tt.patient)]
	if e.tt_hostile and not u.c.weapons.is_empty():
		var w: Weapon = u.c.weapons[0]
		var best: Dictionary = {}
		var bc := 0.0
		for t in e.alive(0):
			var p := e.preview(t, w, Attack.Mode.SINGLE)
			if p.ok and p.chance > bc:
				bc = p.chance
				best = t
		if not best.is_empty() and bc >= MIN_CHANCE:
			e.attack(best, w, Attack.Mode.SINGLE)
	var carrier: int = int(tt.get("carrier", -1))
	if carrier < 0 and not patient.c.dead:
		if e.adjacent(u.pos, patient.pos) or u.pos == patient.pos:
			tt.carrier = u.id
			patient["carried"] = true
			e.events.append({"type": "tt_pickup", "unit": u.id, "target": patient.id})
			e.say("Trauma Team has %s." % patient.c.display_name)
			return
		_go_toward(e, u, patient.pos)
	elif carrier == u.id:
		_go_toward(e, u, tt.av)
		patient.pos = u.pos
		if Vector2(u.pos.x - tt.av.x, u.pos.y - tt.av.y).length() <= 1.5:
			e.tt_depart()
	elif patient.c.dead:
		_go_toward(e, u, tt.av)   # nothing to save: back to the AV
		if Vector2(u.pos.x - tt.av.x, u.pos.y - tt.av.y).length() <= 1.5 and e.units.filter(func(o): return o.get("tt", false) and not o.c.dead).all(func(o): return Vector2(o.pos.x - tt.av.x, o.pos.y - tt.av.y).length() <= 1.5):
			e.tt_depart()


static func _go_toward(e: Encounter, u: Dictionary, goal: Vector3i) -> void:
	if not e.turn.can_move():
		return
	var field: Dictionary = e._with_locks(func(): return e.nav.distance_field([goal], {}, 4000))
	var budget: int = e.turn.squares_available() + (u.c.stat("MOVE") if e.turn.action_available else 0)
	var opts: Dictionary = e._with_locks(func(): return e.nav.reachable(u.pos, budget, e._blocking(u)))
	var best: Vector3i = u.pos
	for cell in opts:
		if int(field.get(cell, 9999)) < int(field.get(best, 9999)) and not e.occupied(u).has(cell):
			best = cell
	if best != u.pos:
		e.move_to(best, true)
