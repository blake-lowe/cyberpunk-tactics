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
	if e.watching(u) and _enemies(e, u).is_empty():
		_investigate(e, u)
		return
	if u.c.weapons.is_empty():
		return
	var w: Weapon = u.c.weapons[0]
	if w.jammed or (w.uses_ammo() and w.ammo <= 0):
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
	var gslot := -1   # the first grenade it carries (a stat block's kit: Pyro, Cyberpsycho)
	for i in u.c.kit.size():
		if e.kit_action(i) == "grenade":
			gslot = i
			break
	if gslot >= 0:
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
					if e.allied(int(o.team), int(u.team)):
						friends += 1
					elif e.hostile(int(o.team), int(u.team)):
						n += 1
			if friends == 0 and n > best_n:
				best_n = n
				best_cell = cell
		if best_cell.x >= 0 and best_n * 21.0 * 0.5 > shot:
			return e.throw_grenade(best_cell, gslot).get("ok", false)
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
		if e.suppress_targets(u).size() >= 3:
			return e.suppress(w).get("ok", false)
	return false


static func _enemies(e: Encounter, u: Dictionary) -> Array:
	var psycho: bool = e.turn != null and e.turn.psychotic
	return e.units.filter(func(o): return o != u and not o.c.dead and (psycho or (e.hostile(int(u.team), int(o.team)) and not e.holds_fire(u, o))))


## `targets`: who to consider (null: every enemy).
static func _shoot(e: Encounter, u: Dictionary, w: Weapon, targets: Variant = null) -> bool:
	var best: Dictionary = {}
	var best_score := 0.0
	var best_mode := Attack.Mode.SINGLE
	for t in (_enemies(e, u) if targets == null else targets):
		for mode in [Attack.Mode.SINGLE, Attack.Mode.AUTOFIRE]:
			var p := e.preview(t, w, mode)
			if not p.ok or p.chance < MIN_CHANCE:
				continue
			var score: float = p.chance * (w.dice() * 3.5 if mode == Attack.Mode.SINGLE else 7.0 * w.autofire_mult() * 0.6)
			if t.c.wound_state() == Combatant.Wound.MORTAL:
				score *= 0.5
			score *= e.obj.ai_target_mult(t)   # e.g. stop the package leaving
			if int(t.id) == e.focus_id and e.hostile(int(u.team), Encounter.CREW):
				score *= 2.0   # a Lieutenant's focus_fire tactic (Complication)
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
		var score := -dmin + (8.0 if sees else 0.0) + e.obj.ai_pull(u, cell)
		if not u.get("reckless", false):   # a complication's reckless unit or wild charge ignores cover
			score += (5.0 if covered else 0.0) - exposed * 2.0
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



## An automated turret (Turret, CPR core p.214): fires on its own Combat Number at the best target
## it has and never moves; a flamethrower turret fires its shell at whoever is within 6 m (p174,
## p.348). Dead with the power out, idle while a Netrunner holds it (Encounter.fire_turret). Nobody
## reloads it (p.214 lists its rounds): when its magazine is empty it falls silent.
static func turret(e: Encounter, u: Dictionary) -> void:
	if e.turret_off(u) or u.has("held_by") or u.c.weapons.is_empty():
		return
	var w: Weapon = u.c.weapons[0]
	if w.jammed or (w.uses_ammo() and w.ammo <= 0):
		return
	var ts := turret_targets(e, u)
	if Turret.shells(w):
		var near := ts.filter(func(t): return Los.distance_m(u.pos, t.pos) <= Attack.SHOTGUN_SHELL_RANGE_M)
		if not near.is_empty():
			near.sort_custom(func(a, b): return Los.distance_m(u.pos, a.pos) < Los.distance_m(u.pos, b.pos))
			e.shotgun_shell(near[0], w)
	elif not ts.is_empty():
		_shoot(e, u, w, ts)


## What sets a turret off: an enemy in clear sight on its floor within 40 squares (the trigger is
## someone there without a pass, p.213, so the crew passing as visitors on a public floor is
## left alone).
const TURRET_REACH := 40.0


static func turret_targets(e: Encounter, u: Dictionary) -> Array:
	return e.units.filter(func(o): return o != u and o.c.can_act() and e.hostile(int(u.team), int(o.team)) and not e.holds_fire(u, o) \
			and o.pos.z == u.pos.z and not e.passing_as_public(o) \
			and Vector2(o.pos.x - u.pos.x, o.pos.y - u.pos.y).length() <= TURRET_REACH and e.los.sight(u.pos, o.pos).visible)


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



## Trauma Team: get to the patient (alive or flatlined: the body goes too), carry them back to the
## AV (or the entrance they walked in by), and leave. They ignore the fight
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
	var reach := 1.5 if tt.get("on_foot", false) else 3.5   # at the gate / beside the AV's door
	if carrier < 0:
		if e.adjacent(u.pos, patient.pos) or u.pos == patient.pos:
			tt.carrier = u.id
			patient["carried"] = true
			e.events.append({"type": "tt_pickup", "unit": u.id, "target": patient.id})
			e.say(("Trauma Team has %s." if not patient.c.dead else "Trauma Team bags %s's body.") % patient.c.display_name)
			return
		_go_toward(e, u, patient.pos)
	elif carrier == u.id:
		_go_toward(e, u, tt.av)
		patient.pos = u.pos
		if Vector2(u.pos.x - tt.av.x, u.pos.y - tt.av.y).length() <= reach and u.pos.z == tt.av.z:
			e.tt_depart()


## A responder neutral to the crew (Encounter.witness_side) with nobody to fight walks toward the
## nearest crew member to see what's going on (spotting rolls happen as they move).
static func _investigate(e: Encounter, u: Dictionary) -> void:
	var best: Dictionary = {}
	for o in e.units:
		if o.team == Encounter.CREW and o.c.can_act() and (best.is_empty() or Vector3(o.pos - u.pos).length() < Vector3(best.pos - u.pos).length()):
			best = o
	if not best.is_empty():
		_go_toward(e, u, best.pos)


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
