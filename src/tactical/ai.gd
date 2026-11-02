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
		if e.turn.use_action():
			w.reload()
			e.say("%s reloads." % u.c.display_name)
		return
	if not _shoot(e, u, w):
		_advance(e, u)
		_shoot(e, u, w)


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
		var covered := false
		for d in MapGen.DIRS:
			if e.los.blocker(Vector3i(cell.x + d.x, cell.y + d.y, cell.z)) != "":
				covered = true
		var score := -dmin + (8.0 if sees else 0.0) + (3.0 if covered else 0.0)
		if score > best_score:
			best_score = score
			best = cell
	if best != u.pos:
		e.move_to(best)
