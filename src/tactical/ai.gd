class_name AI
extends RefCounted
## Simple combat AI for guards (and crew in auto-play tests): shoot the best visible target;
## otherwise advance toward the nearest enemy, preferring squares beside cover from which someone
## is visible, then shoot if possible. Cyberpsychotic units treat everyone as an enemy (approved
## house rule): they go for the nearest target of either team.

const MIN_CHANCE := 0.15


static func act(e: Encounter, u: Dictionary) -> void:
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
		var score := -dmin + (8.0 if sees else 0.0) + (5.0 if covered else 0.0) - exposed * 2.0
		if score > best_score:
			best_score = score
			best = cell
	if best != u.pos:
		e.move_to(best)



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
