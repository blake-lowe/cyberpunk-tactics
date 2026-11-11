class_name AI
extends RefCounted
## Simple combat AI for guards (and crew in auto-play tests): shoot the best visible target;
## otherwise advance toward the nearest enemy, preferring squares beside cover from which someone
## is visible, then shoot if possible. Cyberpsychotic units treat everyone as an enemy (approved
## house rule): they go for the nearest target of either team.

const MIN_CHANCE := 0.15


static func act(e: Encounter, u: Dictionary) -> void:
	if u.c.touching and e.turn != null and u == e.cur:   # the fight's on: the Tactile Boost's hand comes off the wall (free, p.359)
		e.use_chrome("tactile_boost")
	if put_out(e, u):   # the Action's gone on the flames: the Move Action is still theirs
		_advance(e, u)
		return
	if _grapple_first(e, u):
		return
	_fight(e, u)
	if u.c.is_grappled() and e.turn.action_available:   # nothing else worth doing: try to break the hold
		e.escape_grapple()


## Put Out Fire (CPR core p.180) when it's sensible: burning low enough that the flames would take
## them down within a few Turns, or no good shot to spend the Action on instead (nothing to shoot,
## an empty or jammed gun, every shot under PUT_OUT_SHOT). True if they did. Cyberpsychos don't.
const PUT_OUT_SHOT := 0.6


static func put_out(e: Encounter, u: Dictionary) -> bool:
	var c: Combatant = u.c
	if c.burning <= 0 or e.turn == null or not e.turn.action_available or e.turn.psychotic or u.has("turret"):
		return false
	var sensible := c.hp <= c.burning * 3 or c.weapons.is_empty()
	if not sensible:
		var w: Weapon = c.weapons[0]
		sensible = w.jammed or (w.uses_ammo() and w.ammo <= 0)
		if not sensible:
			sensible = not _enemies(e, u).any(func(t):
				var p := e.preview(t, w, Attack.Mode.SINGLE)
				return p.ok and float(p.chance) >= PUT_OUT_SHOT)
	return sensible and bool(e.put_out_fire().get("ok", false))


## Grappling for the AI (CPR core p.168, p.177). Returns true when that was the turn:
## - Prone: Get Up (the Action), then close in with the Move Action it gives back;
## - held: break free when the odds are fair (else fight on with a one-handed weapon, and try at the end);
## - holding someone still fighting: Throw them if it puts them down, else Choke; let go of anyone
##   out cold (free) and fight on, a corpse shield is kept (it's cover);
## - beside a lone foe (nobody of theirs within ISOLATED squares): a brawler (Brawling 6+, or no gun
##   worth using) or anyone next to a jacked-in Netrunner Grabs them when the odds are fair.
const GRAB_MIN_CHANCE := 0.45
const ESCAPE_MIN_CHANCE := 0.4
const ISOLATED := 3


static func _grapple_first(e: Encounter, u: Dictionary) -> bool:
	var c: Combatant = u.c
	if e.turn == null:
		return false
	if c.prone and e.turn.action_available:
		e.get_up()
		_advance(e, u)
		return true
	if c.is_grappled():
		var p := e.escape_preview()
		if p.ok and (p.chance >= ESCAPE_MIN_CHANCE or not _has_one_hander(c)):
			e.escape_grapple()
			return true
		return false
	if c.is_grappling():
		var g: Grapple = c.grapple
		if not g.live():
			return false
		var t := e.unit_of(g.held)
		if not t.c.can_act() or not e.hostile(int(u.team), int(t.team)):
			e.release()
			return false
		if not e.turn.action_available:
			return false
		if t.c.hp > 1 and t.c.hp <= c.stat("BODY"):
			e.throw_foe()
		else:
			e.choke()
		return true
	if not e.turn.action_available or (e.turn != null and e.turn.psychotic):
		return false
	for f in e.grab_targets(u):
		var runner: bool = e.runs.has(f.id)
		if not (runner or _brawler(c)) or not _isolated(e, f):
			continue
		var p := e.grab_preview(f)
		if p.ok and p.chance >= GRAB_MIN_CHANCE:
			e.grapple(f)
			return true
	return false


static func _has_one_hander(c: Combatant) -> bool:
	return c.weapons.any(func(w): return int(w.def.get("hands", 1)) < 2)


static func _brawler(c: Combatant) -> bool:
	return c.skill_level("brawling") >= 6 or c.weapons.is_empty() or c.weapons[0].is_melee()


## Nobody else on `f`'s side who could help them (standing, on their floor) within ISOLATED squares.
static func _isolated(e: Encounter, f: Dictionary) -> bool:
	for o in e.units:
		if o != f and o.c.can_act() and not o.has("turret") and e.allied(int(o.team), int(f.team)) and o.pos.z == f.pos.z \
				and maxi(absi(o.pos.x - f.pos.x), absi(o.pos.y - f.pos.y)) <= ISOLATED:
			return false
	return true


static func _fight(e: Encounter, u: Dictionary) -> void:
	if u.get("vip", false) and not u.get("fights", false):   # a mark who turned out tough stands and fights (Twist)
		_vip(e, u)
		return
	if e.obj.ai_act(u):   # the objective's own move (defend: wreck the asset)
		return
	if e.watching(u) and _enemies(e, u).is_empty():
		_investigate(e, u)
		return
	if u.c.weapons.is_empty():
		return
	if _chrome(e, u):   # the Action went on the Sandevistan: the Move Action closes in
		_advance(e, u)
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
		if _grapple_up(e, u):   # no shot from down here: the Grapple Hand to a ledge that has one
			return
		_advance(e, u)
		if not _special(e, u, w):
			_shoot(e, u, w)


## The Grapple Hand for the AI (p.365): with no shot from where they stand, fire the line (the Action)
## to the ledge within reach of this turn's movement from which the most enemies are in sight (then
## the nearest to one), if any is. True if they went up.
static func _grapple_up(e: Encounter, u: Dictionary) -> bool:
	if not u.c.has_cyberware("grapple_hand") or e.grapple_hand_block(u) != "":
		return false
	var foes := _enemies(e, u)
	var best := Vector3i(-1, -1, -1)
	var best_score := 0.0
	var opts := e.grapple_targets(u)
	for cell in opts:
		if int(opts[cell]) > e.turn.squares_available():
			continue
		var seen := 0.0
		var near := INF
		for f in foes:
			if f.pos.z == cell.z and e.los.sight(cell, f.pos).visible:
				seen += 1.0
				near = minf(near, Vector2(f.pos.x - cell.x, f.pos.y - cell.y).length())
		var score := seen * 100.0 - (near if seen > 0.0 else 0.0)
		if seen > 0.0 and score > best_score:
			best_score = score
			best = cell
	return best.x >= 0 and bool(e.grapple_line(best).get("ok", false))


## Chrome for the AI (CPR core p.359, p.365), before the turn's attack: the best weapon in hand, a
## popup included (drawn and stowed for free, p.365); the Popup Shield out whenever that weapon leaves
## the arm free, away when it needs both hands (free); the Sandevistan kicked in on first contact (an
## Action) when no shot this turn is worth taking (best chance under SANDY_SHOT). True if the Action
## went on the Sandevistan.
const SANDY_SHOT := 0.5


static func _chrome(e: Encounter, u: Dictionary) -> bool:
	var c: Combatant = u.c
	var foes := _enemies(e, u)
	if foes.is_empty() or e.turn == null:
		return false
	_pick_weapon(e, u, foes)
	var w: Weapon = c.weapons[0]
	if not c.shield_piece().is_empty() and c.shield_block() == "":
		var two := int(w.def.get("hands", 1)) >= 2 or (w.popup != "" and w.popup.get_slice("@", 1).get_slice(":", 0) == String(c.shield_piece().loc))
		if c.shield_out == two:   # out with a one-hander, away for a two-hander or a popup in the shield arm
			e.use_chrome("popup_shield")
	var sandy: Array = e.chrome_options(u).filter(func(o): return String(o.id) == "sandevistan" and o.ok)
	if sandy.is_empty() or e.turn.attacks_left > 0:
		return false
	var best := 0.0
	for t in foes:
		var p := e.preview(t, w, Attack.Mode.SINGLE)
		if p.ok:
			best = maxf(best, float(p.chance))
	return best < SANDY_SHOT and bool(e.use_chrome("sandevistan").get("ok", false))


## Draw the weapon worth most this turn (drawing is free with a hand free, p.128; a popup, p.365):
## a loaded one with the best shot (_best_shot_value), else keep what's in hand. Only popups (and
## the way back from one) are weighed, so chrome-free fighters keep their primary.
static func _pick_weapon(e: Encounter, u: Dictionary, foes: Array) -> void:
	var c: Combatant = u.c
	if e.turn.attacks_left > 0 or c.weapons.size() < 2:
		return   # mid-attack (a ROF 2 second shot) or nothing to choose from
	var cur_w: Weapon = c.weapons[0]
	var best: Weapon = null
	var best_v := -1.0
	for w in c.weapons:
		if w != cur_w and w.popup == "" and cur_w.popup == "":
			continue   # chrome-free choices stay as they were: the primary, or back to it from a spent popup
		if w.jammed or (w.uses_ammo() and w.ammo <= 0) or (w.is_melee() and w != cur_w):
			continue   # a popup blade comes out by itself when they close in (melee_weapon)
		var v := _best_shot_value(e, u, w)
		if v > best_v + (0.0 if w == cur_w else 0.5):   # a clear gain to switch
			best_v = v
			best = w
	if best != null and best != cur_w and best_v > 0.0:
		e.draw(best)


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
## - grenade (_grenade): smoke to cover themselves when pinned in the open; else two or more enemies it
##   works on (and no friends) in a 5x5 blast within throwing range;
## - shotgun shell: two or more enemies in the cone;
## - melee: an enemy next to us and the gun is empty or hopeless;
## - suppression: three or more enemies in sight and every shot is a long shot.
static func _special(e: Encounter, u: Dictionary, w: Weapon) -> bool:
	if not e.turn.action_available:
		return false
	var foes := _enemies(e, u)
	var shot := _best_shot_value(e, u, w)
	if _grenade(e, u, w, foes, shot):
		return true
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


## Throw a grenade from the kit (a stat block's, a complication's, the crew's) when it beats the best
## shot (`shot`, expected damage): smoke first, when they're pinned (_smoke_cell); then the others, each
## valued per enemy it would work on: a blast's 6d6 half the time, a poison's dice half the time, a
## flash's or teargas's injuries. Enemies immune to it (Attack.status_immune: two Cybereyes against
## teargas, Anti-Dazzle and a Level Damper against a flashbang, Nasal Filters against gas) don't count.
static func _grenade(e: Encounter, u: Dictionary, w: Weapon, foes: Array, shot: float) -> bool:
	for i in u.c.kit.size():
		if e.kit_action(i) != "grenade":
			continue
		var fx := Items.fx(String(u.c.kit[i]))
		if fx.has("obscure"):
			var sc := _smoke_cell(e, u, w, foes)
			if sc.x >= 0 and e.throw_grenade(sc, i).get("ok", false):
				return true
			continue
		var st: Dictionary = (fx.get("status", {}) as Dictionary).duplicate()
		if fx.has("grenade_hazard"):
			st["hazard"] = String(fx.grenade_hazard)
		var per := 21.0 * 0.5
		if fx.get("no_damage", false):
			per = float(st.get("hp_dice", 0)) * 3.5 * 0.5 if int(st.get("hp_dice", 0)) > 0 else (st.get("crit_injuries", []) as Array).size() * 4.0
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
					elif e.hostile(int(o.team), int(u.team)) and not (fx.get("no_damage", false) and Attack.status_immune(st, fx, o.c)):
						n += 1
			if friends == 0 and n > best_n:
				best_n = n
				best_cell = cell
		if best_cell.x >= 0 and best_n * per > shot and e.throw_grenade(best_cell, i).get("ok", false):
			return true
	return false


## Smoke (CPR core p.347) when pinned: two or more enemies have a clear, uncovered shot at them and
## would be obscured by it (Low Light/Infrared/UV sees through, p.360), they're not in smoke already,
## and their own best shot is poor (under SMOKE_SHOT). Thrown two squares toward those enemies, so the
## cloud covers them and the lines in. (-1,-1,-1) when it isn't worth it.
const SMOKE_SHOT := 0.45
const SMOKE_PINNED := 2


static func _smoke_cell(e: Encounter, u: Dictionary, w: Weapon, foes: Array) -> Vector3i:
	var none := Vector3i(-1, -1, -1)
	if e.smoke.covers(u.pos):
		return none
	var lookers: Array = foes.filter(func(f): return f.c.can_act() and f.pos.z == u.pos.z and not f.c.sees_through_obscurement() \
		and Vector2(f.pos.x - u.pos.x, f.pos.y - u.pos.y).length() < 25 and e.los.trace(f.pos, u.pos).clear and not covered_from(e, u.pos, [f]))
	if lookers.size() < SMOKE_PINNED:
		return none
	for t in foes:
		var p := e.preview(t, w, Attack.Mode.SINGLE)
		if p.ok and float(p.chance) >= SMOKE_SHOT:
			return none
	var d := Vector2.ZERO
	for f in lookers:
		d += Vector2(f.pos.x - u.pos.x, f.pos.y - u.pos.y).normalized()
	d = d.normalized() * 2.0 if d.length() > 0.01 else Vector2.ZERO
	for cell in [Vector3i(u.pos.x + roundi(d.x), u.pos.y + roundi(d.y), u.pos.z), u.pos]:
		if e.m.inb(cell.x, cell.y) and e.los.blocker(cell) == "" and (cell == u.pos or e.los.trace(u.pos, cell).clear):
			return cell
	return none


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
			if p.has("shield") and not e.hostile(int(u.team), int(e.units[int(p.shield)].team)):
				continue   # a friend held up as a Human Shield (p.184) would take it
			var score: float = p.chance * (w.dice() * 3.5 if mode == Attack.Mode.SINGLE else 7.0 * w.autofire_mult() * 0.6)
			if t.c.wound_state() == Combatant.Wound.MORTAL:
				score *= 0.5
			if t.has("broke"):   # running for the edge (Morale): no threat any more
				score *= 0.25
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
		var exposed := 0.0   # foes with a clear shot at the square from where they stand; through smoke, half (-4: p.347)
		for f in foes:
			if f.pos.z == cell.z and Vector2(cell.x - f.pos.x, cell.y - f.pos.y).length() < 25 and e.los.trace(f.pos, cell).clear and not covered:
				exposed += 0.5 if e.smoke.on_line(f.pos, cell) and not f.c.sees_through_obscurement() else 1.0
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
	var budget: int = e.turn.squares_available() + (e.turn.run_squares() if e.turn.action_available else 0)
	var opts: Dictionary = e._with_locks(func(): return e.nav.reachable(u.pos, budget, e._blocking(u)))
	var best: Vector3i = u.pos
	for cell in opts:
		if int(field.get(cell, 999)) < int(field.get(best, 999)) and not e.occupied(u).has(cell):
			best = cell
	if best != u.pos and e.move_to(best, true) and int(field.get(best, 999)) == 0:
		e._vip_escapes(u)


## A unit that broke and runs (Morale): up off the floor or out of a hold first, then Move and a
## Run for the nearest way off the map (Morale.flee_field), gone on reaching it (Encounter.flee_out).
## It never fights back. With nowhere left to run it gives up instead.
static func flee(e: Encounter, u: Dictionary) -> void:
	if e.turn == null:
		return
	if u.c.prone and e.turn.action_available:
		e.get_up()
	if u.c.is_grappled():
		if e.turn.action_available:
			e.escape_grapple()
		if u.c.is_grappled():
			return
	var field := Morale.flee_field(e)
	if not field.has(u.pos):
		e.surrender(u, "cornered", 0, 0)
		return
	if int(field[u.pos]) == 0:
		e.flee_out(u)
		return
	if not e.turn.can_move():
		return
	var budget: int = e.turn.squares_available() + (e.turn.run_squares() if e.turn.action_available else 0)
	var opts: Dictionary = e._with_locks(func(): return e.nav.reachable(u.pos, budget, e._blocking(u)))
	var best: Vector3i = u.pos
	for cell in opts:
		if int(field.get(cell, 9999)) < int(field.get(best, 9999)) and not e.occupied(u).has(cell):
			best = cell
	if best != u.pos:
		e.move_to(best, true)
	if int(field.get(u.pos, 9999)) == 0:
		e.flee_out(u)


## A freed captive: keep beside the crew member nearest to the extraction zone; step into the zone
## when they're there. Unarmed, so that's all. The player moves a freed hostage in a real gig; this
## stands in for them in auto-play (the soak). Distances are walking ones: a straight line to the
## lead (the old score) pulled them into the corner of a room nearest the lead through the wall.
static func follow(e: Encounter, u: Dictionary) -> void:
	var crew := e.units.filter(func(o): return o.team == 0 and o != u and not e.is_hostage(o) and o.c.can_act())
	if crew.is_empty() or not e.turn.can_move():
		return
	var ex: Array = e.obj.ward_goal()   # escort: the rendezvous; else the extraction zone
	if not ex.is_empty():
		_lead_on(e, u, crew, ex)
		return
	ex = e.extract_cells.keys()
	var to_ex: Dictionary = e._with_locks(func(): return e.nav.distance_field(ex, {}, 4000))
	crew.sort_custom(func(a, b): return int(to_ex.get(a.pos, 9999)) < int(to_ex.get(b.pos, 9999)))
	var lead: Dictionary = crew[0]
	var to_lead: Dictionary = e._with_locks(func(): return e.nav.distance_field([lead.pos], {}, 4000))
	var opts := e.move_options()
	var best: Vector3i = u.pos
	var best_s := INF
	var lead_out: bool = ex.has(lead.pos)
	for cell in opts.keys() + [u.pos]:
		var d := float(to_lead.get(cell, 999))
		var sc := maxf(d - 1.5, 0.0) * 2.0 + float(to_ex.get(cell, 999)) * 0.15
		if lead_out and ex.has(cell):
			sc -= 50.0
		if sc < best_s:
			best_s = sc
			best = cell
	if best != u.pos:
		e.move_to(best)



## An escort's client in auto-play: make for `goal` (Move, then a Run: they carry nothing to use
## the Action on), never more than WARD_LEAD squares' walk ahead of the nearest of the crew.
const WARD_LEAD := 4.0


static func _lead_on(e: Encounter, u: Dictionary, crew: Array, goal: Array) -> void:
	var to_goal: Dictionary = e._with_locks(func(): return e.nav.distance_field(goal, {}, 4000))
	var to_crew: Dictionary = e._with_locks(func(): return e.nav.distance_field(crew.map(func(o): return o.pos), {}, 4000))
	var opts := e.move_options()
	if e.turn.action_available:
		opts.merge(e._with_locks(func(): return e.nav.reachable(u.pos, e.turn.squares_available() + e.turn.run_squares(), e._blocking(u))))
		for v in e.occupied(u):
			opts.erase(v)
	var best: Vector3i = u.pos
	var best_s := INF
	var cells: Array = opts.keys() + [u.pos]
	cells.sort()   # a stable pick among equals
	for cell in cells:
		var sc := float(to_goal.get(cell, 9999)) + 3.0 * maxf(0.0, float(to_crew.get(cell, 9999)) - WARD_LEAD)
		if sc < best_s:
			best_s = sc
			best = cell
	if best != u.pos:
		e.move_to(best, true)


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
	var budget: int = e.turn.squares_available() + (e.turn.run_squares() if e.turn.action_available else 0)
	var opts: Dictionary = e._with_locks(func(): return e.nav.reachable(u.pos, budget, e._blocking(u)))
	var best: Vector3i = u.pos
	for cell in opts:
		if int(field.get(cell, 9999)) < int(field.get(best, 9999)) and not e.occupied(u).has(cell):
			best = cell
	if best != u.pos:
		e.move_to(best, true)
