class_name Encounter
extends RefCounted
## A gig on a generated scene: crew vs guards, turn by turn, with the Netrunner's NET session.
## Pure rules (no Nodes) so it runs headless; the M3b greybox drives it and draws the results.
##
## Objectives (gig kinds, M7):
## - "data": download the target building's most valuable File by Eye-Dee'ing it in the NET, or put
##   every guard down;
## - "eliminate": put every guard down (backup included);
## - "snatch": grab the package in the target building and carry it back to the deploy zone. A
##   carrier who goes down drops it where they fall.
## The crew loses if nobody can act.

const JACK_IN_RANGE_M := 6.0      # p198
const SPOT_RANGE := 15            # squares a guard notices the crew at (clear sight)
const GUNFIRE_RANGE := 12         # squares within which gunfire alerts guards (any floor)
const SHOUT_RANGE := 8            # an alerted guard rouses others this close on its floor

var m: TacMap
var dice: Dice
var nav: Nav
var los: Los
var init: Initiative
var units: Array[Dictionary] = []   ## {id, c, pos: Vector3i, team (0 crew, 1 guards), alerted}
var cur: Dictionary = {}
var turn: TurnState
var log: Array[String] = []
var state := "playing"              ## playing | won | lost
var runs := {}                      ## unit id → NetRun
var net_left := 0                   ## NET Actions left this turn (runner only)
var objective := {}                 ## {kind, done, + data: structure, node | snatch: cell, carrier}
var twists: Array = []             ## gig complications: heavy, blackout, shift_change (data/gen/gigs.json)
var extract_cells := {}             ## Vector3i → true: the deploy zone, where a snatch is carried out
var vision: Vision                  ## what the crew can see (drives fog and hidden guards)
## What happened, in order, for the view to animate: {type: move|attack|cover|alert, ...}.
## The view drains it; rules code never reads it.
var events: Array[Dictionary] = []
var lit := {}                       ## Vector3i → true where a light reaches (darkness: -4 to spot, p? task table)
var alarm := 0                      ## 0 quiet, 1 a guard is onto the crew, 2 backup called
var backup_in := -1                 ## rounds until reinforcements arrive (-1 none scheduled)
var _backup_round := 0
var _patrol_round := -1
var heat := 0                       ## campaign heat: NCPD answers faster (HOUSE-RULE: -1 round per 2 heat)
var reinforcements := true          ## backup/NCPD on (balance tests switch them off)
var ncpd_in := -1                   ## rounds until the NCPD response (after backup has arrived)
var _ncpd_round := 0
var _spot_rolls := {}               ## [guard id, crew id, round] → result: one stealth roll per pair per round
var jack_pos := {}                  ## runner unit id → the square of the device they jacked in at
var disabled_devices := {}          ## device id → true (turrets/cameras under the runner's control)


static func setup(p_map: TacMap, p_dice: Dice, crew: Array[Combatant], kind := "data", p_twists: Array = []) -> Encounter:
	var e := Encounter.new()
	e.twists = p_twists.duplicate()
	e.m = p_map
	e.dice = p_dice
	e.nav = Nav.new(p_map)
	e.los = Los.new(p_map)
	e.init = Initiative.new(p_dice)
	var deploy: Dictionary = p_map.entrances.filter(func(x): return x.kind == "deploy")[0]
	var cells: Array = deploy.get("cells", [deploy.pos])
	for c0 in cells:
		e.extract_cells[Vector3i(c0.x, c0.y, 0)] = true
	for i in crew.size():
		crew[i].gig_reset()
		var c: Vector2i = cells[i % cells.size()]
		e._add(crew[i], Vector3i(c.x, c.y, 0), 0)
	# Guards at posts, target building first.
	var target_sid := -1
	for st in p_map.structures:
		if st.target:
			target_sid = st.id
	var posts := p_map.posts.duplicate()
	posts.sort_custom(func(a, b): return int(a.structure == target_sid) > int(b.structure == target_sid))
	var sec := mini(3, int(p_map.params.get("security", 1)) + (1 if "heavy" in p_twists else 0))
	var roster := Recruit.opposition(crew.size(), sec)   # CPR p399 budget, strongest first (target building posts)
	var want := roster.size()
	if posts.size() < want:
		# Not enough posts (small sites with no guard rooms or security doors): spread the rest over
		# the target building, farthest from the deploy zone first, at least 3 squares apart.
		var origin: Vector2i = cells[0]
		var cand: Array = []
		for f in p_map.floors:
			for y in p_map.h:
				for x in p_map.w:
					var l := p_map.label(f, x, y)
					if l >= 0 and p_map.rooms[l].structure == target_sid and p_map.walkable(f, Vector2i(x, y)) and not p_map.has_cover_at(f, Vector2i(x, y)):
						cand.append(Vector3i(x, y, f))
		cand.sort_custom(func(a, b): return Vector2(a.x - origin.x, a.y - origin.y).length() > Vector2(b.x - origin.x, b.y - origin.y).length())
		var taken: Array = posts.map(func(q): return Vector3i(q.pos.x, q.pos.y, q.floor))
		for v in cand:
			if posts.size() >= want:
				break
			if taken.any(func(t): return t.z == v.z and Vector2(t.x - v.x, t.y - v.y).length() < 3.0):
				continue
			taken.append(v)
			posts.append({"floor": v.z, "pos": Vector2i(v.x, v.y), "structure": target_sid, "zone": 1, "kind": "patrol"})
	var n := mini(posts.size(), want)
	for i in n:
		var tier: String = roster[i]
		var g := Recruit.npc(p_dice, tier, "%s %d" % [RulesDB.load_json("npcs.json")["tiers"][tier]["name"], i + 1])
		g.team = 1
		if tier == "mook" and p_dice.d(3) == 1:
			g.grenades = 1   # HOUSE-RULE: about a third of Mooks carry a frag grenade
		e._add(g, Vector3i(posts[i].pos.x, posts[i].pos.y, posts[i].floor), 1)
	# Objective: the target NET's most valuable File (data), everyone down, or the package.
	e.objective = {"kind": kind, "done": false}
	if kind == "data" and p_map.architectures.has(target_sid):
		var a: NetArchitecture = p_map.architectures[target_sid]
		var best := -1
		for nd in a.nodes_of_type("file"):
			if best < 0 or int(nd.value) > int(a.nodes[best].value):
				best = nd.id
		e.objective.merge({"structure": target_sid, "node": best})
	elif kind == "snatch":
		e.objective.merge({"cell": e._package_cell(target_sid, cells[0]), "carrier": -1})
	if "setup" in p_twists:   # HOUSE-RULE: a fixer sold the crew out; the guards are waiting
		for u in e.units:
			if u.team == 1:
				u.alerted = true
		e.alarm = 1
		e.say("It's a setup. They knew you were coming.")
	# M3 playtest verdict: guards only join the initiative order once they're alerted.
	for u in e.units:
		if u.alerted:
			e.init.add(u.c)
	e.vision = Vision.new(p_map, e.los)
	e._compute_light()
	e._post_guards()
	e.refresh_vision()
	e.update_alerts()
	return e


## Recompute crew sight. Returns true if new cells were explored.
func refresh_vision() -> bool:
	return vision.update(alive(0).map(func(u): return u.pos))


func _add(c: Combatant, pos: Vector3i, team: int) -> void:
	c.team = team
	units.append({"id": units.size(), "c": c, "pos": pos, "team": team, "alerted": team == 0})


func unit_of(c: Combatant) -> Dictionary:
	for u in units:
		if u.c == c:
			return u
	return {}


func alive(team: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in units:
		if u.team == team and not u.c.dead and u.c.wound_state() != Combatant.Wound.MORTAL:
			out.append(u)
	return out


func occupied(except: Dictionary = {}) -> Dictionary:
	var occ := {}
	for u in units:
		if u != except and not u.c.dead:
			occ[u.pos] = true
	return occ


func say(s: String) -> void:
	log.append(s)


# --- Turn flow -------------------------------------------------------------------

## Advance to the next combatant. Guards act automatically; returns when it's a crew turn or over.
func next_turn() -> void:
	while state == "playing":
		var c := init.next_turn()
		if c == null:
			state = "lost"
			return
		cur = unit_of(c)
		if "shift_change" in twists and init.round_num >= SHIFT_CHANGE_ROUND and alarm < 2:
			var gs := alive(1)
			if not gs.is_empty():
				say("Shift change: the new shift finds the place wrong.")
				_call_it_in(gs[0])
		_tick_backup()
		turn = TurnState.begin(dice, c)
		net_left = 0
		if cur.team == 1 and cur.alerted and turn.survived and c.can_act():
			_call_it_in(cur)
		if not turn.survived:
			say("%s fails a Death Save and dies." % c.display_name)
			events.append({"type": "death", "unit": cur.id})   # so the view plays the death, not a snap
		elif c.can_act():
			_ice_turn(cur)
			if cur.has("suppressed_by"):
				_take_cover(cur)
			if cur.team == 1 or turn.psychotic:
				AI.act(self, cur)
				end_turn()
				continue
			if runs.has(cur.id):
				net_left = net_actions_for(c)
			return
		_check_end()


func end_turn() -> void:
	if turn != null and not cur.is_empty() and cur.team == 0 and alarm < 2 and init.round_num != _patrol_round:
		_patrol_round = init.round_num   # once a round, not once per crew member
		patrol_step()
	if turn != null:
		var before: int = cur.c.wound_state()
		var dmg := turn.end()
		if dmg > 0:
			say("%s takes %d from strained injuries." % [cur.c.display_name, dmg])
			events.append({"type": "harm", "unit": cur.id, "damage": dmg, "source": "STRAIN", "wound_before": before, "wound_after": cur.c.wound_state()})
	_check_end()


func _check_end() -> void:
	if state != "playing":
		return
	if objective.get("kind", "data") == "snatch":
		_drop_package()
	if units.filter(func(u): return u.team == 0 and u.c.can_act()).is_empty() \
			and units.filter(func(u): return u.team == 0 and not u.c.dead and u.c.wake_in > 0).is_empty():
		state = "lost"   # nobody on the crew can act or will wake up (the loop would otherwise spin)
		return
	if objective.get("kind", "data") == "snatch":
		var carrier: int = objective.carrier
		if carrier >= 0 and extract_cells.has(units[carrier].pos):
			objective.done = true
			state = "won"
			say("%s gets the package out." % units[carrier].c.display_name)
		return
	if alive(1).is_empty():
		if objective.get("kind", "data") == "eliminate" and backup_in > 0:
			return   # HOUSE-RULE: a gang hit isn't done while backup is still on its way
		state = "won"
		say("All guards are down.")
	elif objective.get("done", false):
		state = "won"
		say("The data is yours.")


# --- Withdrawal ------------------------------------------------------------------------

## The crew can cut and run: on their turn, if everyone still on their feet stands in the deploy
## zone. The gig fails (state "fled"); anyone left behind (down or elsewhere) is lost
## (HOUSE-RULE: nobody comes back for them).
func can_withdraw() -> bool:
	if state != "playing" or cur.is_empty() or cur.team != 0:
		return false
	var up := units.filter(func(u): return u.team == 0 and u.c.can_act())
	return not up.is_empty() and up.all(func(u): return extract_cells.has(u.pos))


func left_behind() -> Array:
	return units.filter(func(u): return u.team == 0 and not u.c.dead and not (u.c.can_act() and extract_cells.has(u.pos)))


func withdraw() -> bool:
	if not can_withdraw():
		return false
	for u in left_behind():
		u.c.dead = true
		say("%s is left behind." % u.c.display_name)
	state = "fled"
	say("The crew pulls out.")
	return true


# --- Snatch objective ------------------------------------------------------------------

## The package sits indoors in the target building's most secure zone, as far from the deploy zone
## as walking gets (upper floors count through the distance field), off guard posts and cover.
func _package_cell(target_sid: int, origin: Vector2i) -> Vector3i:
	var field: Dictionary = nav.distance_field([Vector3i(origin.x, origin.y, 0)], {})
	var best := Vector3i(origin.x, origin.y, 0)
	var best_d := -1.0
	var occ := occupied()
	for cell in field:
		var l := m.label(cell.z, cell.x, cell.y)
		if l < 0 or m.rooms[l].structure != target_sid or m.rooms[l].get("kind", "") == "roof" or occ.has(cell) \
				or m.has_cover_at(cell.z, Vector2i(cell.x, cell.y)):
			continue
		var score := float(field[cell]) + 20.0 * int(m.rooms[l].get("zone", 0))   # the most secure rooms first
		if score > best_d:
			best_d = score
			best = cell
	return best


## Grab the package (an Action) from its square or a neighbouring one.
func grab() -> Dictionary:
	if objective.get("kind", "") != "snatch" or int(objective.carrier) >= 0:
		return {"ok": false, "reason": "nothing to grab"}
	var cell: Vector3i = objective.cell
	if cur.pos != cell and not adjacent(cur.pos, cell):
		return {"ok": false, "reason": "get next to the package"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	objective.carrier = cur.id
	events.append({"type": "grab", "unit": cur.id, "cell": cell})
	say("%s grabs the package. Get it to the extraction point." % cur.c.display_name)
	_check_end()
	return {"ok": true}


func can_grab() -> bool:
	return objective.get("kind", "") == "snatch" and int(objective.carrier) < 0 and not cur.is_empty() \
		and cur.team == 0 and (cur.pos == objective.cell or adjacent(cur.pos, objective.cell))


## A carrier who can't act any more drops the package on their square.
func _drop_package() -> void:
	var carrier: int = objective.get("carrier", -1)
	if carrier < 0 or units[carrier].c.can_act():
		return
	objective.cell = units[carrier].pos
	objective.carrier = -1
	events.append({"type": "drop", "unit": carrier, "cell": objective.cell})
	say("%s drops the package." % units[carrier].c.display_name)


# --- Alerts ------------------------------------------------------------------------

## Guards who can see a crew member (clear sight, within SPOT_RANGE) are alerted; every newly
## alerted guard shouts, rousing guards near it. Newly alerted guards roll Initiative and slot in
## (Initiative.add keeps the current turn). Returns the units alerted by this call.
func update_alerts() -> Array:
	var fresh := []
	for g in units:
		if g.alerted or g.c.dead or g.team != 1:
			continue
		for u in alive(0):
			if _spots(g, u):
				fresh.append(g)
				say("%s spots %s!" % [g.c.display_name, u.c.display_name])
				break
	_rouse(fresh)
	return fresh


# --- Stealth (M7): facing, light, Perception vs Stealth, patrols, alarm -------------------

const VIEW_HALF_ANGLE := 60.0   ## HOUSE-RULE: a guard watches a 120° cone ahead...
const AWARE_RANGE := 2.0        ## ...but notices anyone within 2 squares, any direction
const DARK_PENALTY := 4         ## "Task obscured by smoke or darkness" (CPR p? task modifiers)
const SHIFT_CHANGE_ROUND := 6    ## HOUSE-RULE twist: the next shift arrives and raises the alarm
const BACKUP_ROUNDS := 3        ## HOUSE-RULE: reinforcements arrive 3 rounds after the call
const NCPD_ROUNDS := 8          ## HOUSE-RULE: still fighting this long after backup arrives, NCPD rolls in


## Can guard `g` spot crew member `u` right now? Inside the guard's view (cone or close), in clear
## sight within SPOT_RANGE, the guard's Perception beats the crew member's Stealth (opposed, p? ;
## Stealth is opposed by Perception, p85), at -4 if the crew member stands in darkness and -2 per
## 5 squares beyond 5 (HOUSE-RULE: distance).
func _spots(g: Dictionary, u: Dictionary) -> bool:
	if u.pos.z != g.pos.z:
		return false
	var d := Vector2(u.pos.x - g.pos.x, u.pos.y - g.pos.y)
	var dist := d.length()
	if dist > SPOT_RANGE or not los.trace(g.pos, u.pos).clear:
		return false
	var facing: Vector2 = g.get("facing", Vector2.ZERO)
	if dist > AWARE_RANGE and facing != Vector2.ZERO and rad_to_deg(absf(facing.angle_to(d))) > VIEW_HALF_ANGLE:
		return false
	var base: int = g.c.skill_base("perception") + g.c.awareness_level("threat_detection") - g.c.action_penalty()
	if not lit.has(u.pos):
		base -= DARK_PENALTY
	base -= 2 * int(maxf(0.0, dist - 5.0) / 5.0)
	var sneak: int = u.c.skill_base("stealth") - u.c.action_penalty()
	var key := [g.id, u.id, init.round_num if init else 0]   # HOUSE-RULE: one contest per guard, sneaker and round
	if not _spot_rolls.has(key):
		_spot_rolls[key] = Check.opposed(dice, base, sneak).success
	return _spot_rolls[key]


## Squares an unalerted guard is watching (view-side helper, no dice): within SPOT_RANGE on their
## floor, inside the view cone or within AWARE_RANGE, with a clear line. Used to draw sight cones.
func watched_cells(g: Dictionary) -> Dictionary:
	var out := {}
	var facing: Vector2 = g.get("facing", Vector2.ZERO)
	var r := SPOT_RANGE
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := Vector2(dx, dy)
			var dist := d.length()
			if dist > r or (dx == 0 and dy == 0):
				continue
			if dist > AWARE_RANGE and facing != Vector2.ZERO and rad_to_deg(absf(facing.angle_to(d))) > VIEW_HALF_ANGLE:
				continue
			var v := Vector3i(g.pos.x + dx, g.pos.y + dy, g.pos.z)
			if m.inb(v.x, v.y) and m.walkable(v.z, Vector2i(v.x, v.y)) and los.trace(g.pos, v).clear:
				out[v] = true
	return out


## Which squares have light: within each light's reach (a little short of its glow) with nothing
## solid between. Open-sky scenes in daylight (params.daylight) are lit everywhere outdoors.
func _compute_light() -> void:
	lit.clear()
	var day: bool = bool(m.params.get("daylight", false)) or String(m.params.get("scene", "")) == "badlands"
	for e in ([] if "blackout" in twists else LightPlan.plan(m, m.seed_value)):
		var c: Vector3i = e.cell
		var r := float(e.range) * 0.6
		for dy in range(-int(r), int(r) + 1):
			for dx in range(-int(r), int(r) + 1):
				var v := Vector3i(c.x + dx, c.y + dy, c.z)
				if Vector2(dx, dy).length() <= r and m.inb(v.x, v.y) and not lit.has(v) and los.trace(c, v).clear:
					lit[v] = true
	if day:
		for y in m.h:
			for x in m.w:
				if m.t(0, x, y) == TacMap.T.OUTSIDE and m.label(0, x, y) < 0:
					lit[Vector3i(x, y, 0)] = true


## Unalerted guards face somewhere sensible (into their room, or along the street) and some walk a
## patrol between their post and a spot a few squares away.
func _post_guards() -> void:
	for g in units:
		if g.team != 1:
			continue
		var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
		var l := m.label(g.pos.z, g.pos.x, g.pos.y)
		if l >= 0:   # face the middle of the room
			var b: Rect2i = m.rooms[l].bounds
			var to := Vector2(b.position.x + b.size.x / 2.0 - g.pos.x, b.position.y + b.size.y / 2.0 - g.pos.y)
			g.facing = to.normalized() if to.length() > 0.5 else dirs[dice.d(8) - 1]
		else:
			g.facing = dirs[dice.d(8) - 1]
		if dice.d(10) <= 4:   # ~40% patrol
			var reach: Dictionary = _keys(func(): return nav.reachable(g.pos, 9, occupied(g)))
			var far := []
			for v in reach:
				if v.z == g.pos.z and int(reach[v]) >= 4:
					far.append(v)
			if not far.is_empty():
				g.patrol = [g.pos, far[dice.d(far.size()) - 1]]
				g.patrol_i = 1


## Between crew turns, patrolling guards who haven't noticed anything walk up to 3 squares along
## their route (and look where they're going), then look around.
func patrol_step() -> void:
	for g in units:
		if g.team != 1 or g.alerted or g.c.dead or not g.has("patrol"):
			continue
		var goal: Vector3i = g.patrol[g.patrol_i]
		if g.pos == goal:
			g.patrol_i = (int(g.patrol_i) + 1) % g.patrol.size()
			goal = g.patrol[g.patrol_i]
		var p: Array[Vector3i] = _keys(func(): return nav.path(g.pos, goal, occupied(g)))
		if p.is_empty():
			continue
		var steps: Array = p.slice(0, mini(3, p.size()))
		var from: Vector3i = g.pos
		var path: Array = [from]
		for s in steps:
			if s.z != from.z:
				break
			path.append(s)
		if path.size() < 2:
			continue
		var last: Vector3i = path[-1]
		g.facing = Vector2(last.x - from.x, last.y - from.y).normalized()
		g.pos = last
		events.append({"type": "move", "unit": g.id, "path": path, "run": false, "patrol": true})
	update_alerts()


## A guard who knows the crew is here calls it in; backup arrives a few rounds later at the
## entrance farthest from the crew (spec: alarm levels, reinforcements).
func _call_it_in(g: Dictionary) -> void:
	if alarm >= 2 or g.c.dead or not reinforcements:
		return
	alarm = 2
	backup_in = BACKUP_ROUNDS
	_rouse(units.filter(func(o): return o.team == 1 and not o.alerted and not o.c.dead))   # the radio call reaches everyone
	_backup_round = init.round_num
	say("%s calls it in. Backup in %d rounds." % [g.c.display_name, backup_in])
	events.append({"type": "alarm", "unit": g.id, "rounds": backup_in})


func _tick_backup() -> void:
	if ncpd_in > 0 and init.round_num != _ncpd_round:
		_ncpd_round = init.round_num
		ncpd_in -= 1
		if ncpd_in == 0:
			ncpd_in = -2   # once per gig
			var waves: Array[String] = ["lieutenant", "mook", "mook"]
			_spawn_wave(waves, "NCPD Officer", "NCPD")
	if backup_in < 0 or init.round_num == _backup_round:
		return
	_backup_round = init.round_num
	backup_in -= 1
	if backup_in > 0:
		return
	backup_in = -1
	var roster: Array[String] = []
	for i in 1 + int(m.params.get("security", 1)) + (1 if "heavy" in twists else 0):
		roster.append("mook")
	_spawn_wave(roster, "Backup", "BACKUP")
	if ncpd_in == -1:   # escalation: keep fighting and the city notices
		ncpd_in = maxi(2, NCPD_ROUNDS - heat / 2)
		_ncpd_round = init.round_num


## Reinforcements enter at the entrance farthest from the crew, alerted and in the initiative order.
func _spawn_wave(roster: Array[String], prefix: String, label: String) -> void:
	var crew_c := Vector2.ZERO
	for u in alive(0):
		crew_c += Vector2(u.pos.x, u.pos.y)
	crew_c /= maxf(1.0, alive(0).size())
	var spawn := Vector3i(-1, -1, -1)
	var best := -1.0
	for en in m.entrances:
		var v := Vector3i(en.pos.x, en.pos.y, int(en.floor))
		var dd := Vector2(v.x, v.y).distance_to(crew_c)
		if en.kind != "deploy" and dd > best and m.walkable(v.z, Vector2i(v.x, v.y)):
			best = dd
			spawn = v
	if spawn.x < 0:
		return
	var arrived := []
	var reach: Dictionary = _keys(func(): return nav.reachable(spawn, 6, occupied()))
	var cells: Array = reach.keys().filter(func(v): return v.z == spawn.z)
	cells.sort_custom(func(a, b): return int(reach[a]) < int(reach[b]))
	for i in mini(roster.size(), cells.size()):
		var g := Recruit.npc(dice, roster[i], "%s %d" % [prefix, i + 1])
		g.team = 1
		_add(g, cells[i], 1)
		var u: Dictionary = units[-1]
		u.alerted = true
		init.add(g)
		arrived.append(u.id)
	say("%s arrives: %d more." % [label.capitalize(), arrived.size()])
	if not arrived.is_empty():
		events.append({"type": "backup", "unit": arrived[0], "units": arrived, "label": label})


## Gunfire at `at` alerts guards within GUNFIRE_RANGE on any floor.
func _noise(at: Vector3i) -> void:
	var fresh := []
	for g in units:
		if not g.alerted and not g.c.dead and Vector2(at.x - g.pos.x, at.y - g.pos.y).length() <= GUNFIRE_RANGE \
				and absi(at.z - g.pos.z) <= 1:
			fresh.append(g)
	_rouse(fresh)


func _rouse(fresh: Array) -> void:
	var q := fresh.duplicate()
	while not q.is_empty():
		var g: Dictionary = q.pop_front()
		if g.alerted:
			continue
		g.alerted = true
		alarm = maxi(alarm, 1)
		init.add(g.c)
		events.append({"type": "alert", "unit": g.id})
		for o in units:
			if not o.alerted and not o.c.dead and o.team == g.team and o.pos.z == g.pos.z \
					and Vector2(o.pos.x - g.pos.x, o.pos.y - g.pos.y).length() <= SHOUT_RANGE:
				q.append(o)


func engaged() -> bool:
	return units.any(func(u): return u.team == 1 and u.alerted and not u.c.dead)


# --- Movement ----------------------------------------------------------------------

## Guards carry the keys to their own security doors; the crew needs them hacked or shot open.
func _with_locks(callable: Callable) -> Variant:
	var saved := nav.locked
	if not cur.is_empty() and cur.team == 1:
		nav.locked = {}
	var r: Variant = callable.call()
	nav.locked = saved
	return r


## Paths for guards outside their own turn (patrols, posting): they have the keys.
func _keys(callable: Callable) -> Variant:
	var saved := nav.locked
	nav.locked = {}
	var r: Variant = callable.call()
	nav.locked = saved
	return r


func move_options() -> Dictionary:
	return _with_locks(func(): return nav.reachable(cur.pos, turn.squares_available(), occupied(cur)))


## Move along the shortest path. With `allow_run`, a path longer than the remaining move may
## spend the Action on Run (p127/p169: "Take an additional Move Action"), which in the book
## requires a Move Action already taken this turn: the first leg uses it, then Run covers the rest.
func move_to(dest: Vector3i, allow_run := false) -> bool:
	var p: Array[Vector3i] = _with_locks(func(): return nav.path(cur.pos, dest, occupied(cur)))
	if p.is_empty():
		return false
	var cost := nav.cost_of(cur.pos, p)
	var ran := false
	if cost > turn.squares_available():
		var avail := turn.squares_available()
		if not allow_run or not turn.action_available or cost > avail + cur.c.stat("MOVE"):
			return false
		turn.move(avail)
		if not turn.run():
			return false
		if not turn.move(cost - avail):
			return false
		ran = true
	elif not turn.move(cost):
		return false
	var from: Vector3i = cur.pos
	cur.pos = dest
	var full: Array = [from]
	full.append_array(p)
	events.append({"type": "move", "unit": cur.id, "path": full, "run": ran})
	if ran:
		say("%s runs." % cur.c.display_name)
	for v in p:
		if m.t(v.z, v.x, v.y) == TacMap.T.DOOR:
			los.open_doors[v] = true  # doors stay open once someone walks through
	update_alerts()
	if runs.has(cur.id) and Los.distance_m(dest, _ap_pos(runs[cur.id])) > jack_range(cur.c):
		say("%s moves out of range and is dumped from the NET." % cur.c.display_name)
		runs.erase(cur.id)
	_check_end()   # a carrier reaching the extraction point
	return true


# --- Combat ------------------------------------------------------------------------

func preview(target: Dictionary, weapon: Weapon, mode: Attack.Mode) -> Dictionary:
	var s := los.sight(cur.pos, target.pos)
	if not s.visible:
		return {"ok": false, "reason": "no line of sight", "chance": 0.0, "blocker": s.blocker}
	if weapon.is_melee():   # melee is from where you stand, never from a lean-out square
		s.from = cur.pos
	var dist := _attack_distance(weapon, s.from, target.pos)
	var p := Attack.preview(cur.c, weapon, target.c, mode, dist)
	p["from"] = s.from
	p["blocker"] = s.blocker
	return p


func attack(target: Dictionary, weapon: Weapon, mode: Attack.Mode) -> Dictionary:
	var p := preview(target, weapon, mode)
	if not p.ok:
		return {"ok": false, "reason": p.reason}
	if turn.attacks_left <= 0 and not turn.start_attack(weapon, mode != Attack.Mode.SINGLE or weapon.rof() < 2):
		return {"ok": false, "reason": "no action left"}
	turn.use_attack()
	_rouse([target])
	_noise(cur.pos)
	var hp_before: int = target.c.hp
	var loc := "head" if mode == Attack.Mode.AIMED_HEAD else "body"
	var sp_before: int = target.c.sp(loc)
	var wound_before: int = target.c.wound_state()
	var ammo_before := weapon.ammo
	var r := Attack.resolve(dice, cur.c, weapon, target.c, mode, _attack_distance(weapon, p.from, target.pos))
	var mult := 1
	if mode == Attack.Mode.AUTOFIRE and r.hit and r.check != null:
		mult = mini(r.check.total - r.check.dv, weapon.autofire_mult())   # rounds that connect (p173)
	events.append({"type": "attack", "unit": cur.id, "target": target.id, "from": p.from, "hit": r.hit, "dodged": r.dodged,
		"damage": hp_before - target.c.hp, "through": r.through, "location": r.location, "sp_before": sp_before,
		"sp_after": target.c.sp(r.location), "crit": not r.crits.is_empty(), "crit_names": r.crits.map(func(c): return String(c.get("name", ""))),
		"wound_before": wound_before, "wound_after": target.c.wound_state(), "mult": mult, "rounds": maxi(1, ammo_before - weapon.ammo),
		"mode": mode, "weapon": weapon.id(), "dead": target.c.dead, "killed": target.c.dead or target.c.wound_state() == Combatant.Wound.MORTAL})
	var who := "%s → %s" % [cur.c.display_name, target.c.display_name]
	if r.dodged:
		say("%s: DODGE" % who)
	elif not r.hit:
		say("%s: miss (%d%%)" % [who, roundi(p.chance * 100)])
	else:
		say("%s: hit for %d, %d through%s" % [who, r.damage, r.through, (", " + ", ".join(r.crits.map(func(x): return x.name))) if not r.crits.is_empty() else ""])
	_check_end()
	return r


# --- Close quarters and area attacks (M5) -------------------------------------------

## HOUSE-RULE: on the grid every neighbouring square, diagonals included, is within melee reach
## (2 m, p176); a diagonal neighbour is 2.8 m centre to centre, which would rule out half of them.
const MELEE_ADJACENT_M := 2.0
const BLAST_HALF := 2            ## 5x5 squares = 10x10 m (p174)
const THROW_RANGE_M := 25.0      ## p177
const GRENADE_DICE := 6          ## thrown grenades deal their launcher's damage (p177; Grenade Launcher 6d6, p94)
const SHELL_HALF_ANGLE := 45.0   ## "every target in front of you" (p174): a 90° cone toward the aimed target


func _attack_distance(weapon: Weapon, from: Vector3i, to: Vector3i) -> float:
	if weapon.is_melee() and adjacent(from, to):
		return MELEE_ADJACENT_M
	return Los.distance_m(from, to)


## Neighbouring squares on the same floor with nothing solid between them.
func adjacent(a: Vector3i, b: Vector3i) -> bool:
	return a.z == b.z and maxi(absi(a.x - b.x), absi(a.y - b.y)) == 1 and los.trace(a, b).clear


## The unit's best close-quarters weapon: a melee weapon if it carries one, else its fists.
func melee_weapon(c: Combatant) -> Weapon:
	for w in c.weapons:
		if w.is_melee():
			return w
	return Weapon.brawling(c)


## A melee attack on a neighbouring enemy (uses the normal attack, so ROF 2 means two swings).
func melee(target: Dictionary) -> Dictionary:
	if not adjacent(cur.pos, target.pos):
		return {"ok": false, "reason": "out of reach"}
	return attack(target, melee_weapon(cur.c), Attack.Mode.SINGLE)


## Suppressive Fire (p174): everyone on the other side in sight within 25 m contests WILL +
## Concentration; losers must get into cover on their next turn.
func suppress(weapon: Weapon) -> Dictionary:
	if not turn.action_available:
		return {"ok": false, "reason": "no action left"}
	var targets: Array = []
	for o in alive(1 - cur.team):
		if Los.distance_m(cur.pos, o.pos) <= Attack.SUPPRESSIVE_RANGE_M and los.sight(cur.pos, o.pos).visible:
			targets.append(o)
	if targets.is_empty():
		return {"ok": false, "reason": "nobody in sight within 25 m"}
	var r := Attack.suppressive_fire(dice, cur.c, weapon, targets.map(func(o): return o.c))
	if not r.ok:
		return r
	turn.use_action()
	_rouse(targets)
	_noise(cur.pos)
	var hit: Array = []
	for t in r.suppressed:
		var u := unit_of(t)
		u.suppressed_by = cur.id
		hit.append(u.id)
	events.append({"type": "suppress", "unit": cur.id, "weapon": weapon.id(), "targets": targets.map(func(o): return o.id), "suppressed": hit})
	say("%s lays down suppressive fire: %d pinned." % [cur.c.display_name, hit.size()])
	return {"ok": true, "suppressed": hit}


## Shotgun Shell (p174): one attack vs DV13; on a hit everyone in front within 6 m (a cone toward
## `target`) takes the same 3d6, dodging individually.
func shotgun_shell(target: Dictionary, weapon: Weapon) -> Dictionary:
	if not turn.action_available:
		return {"ok": false, "reason": "no action left"}
	var aim := Vector2(target.pos.x - cur.pos.x, target.pos.y - cur.pos.y)
	var cone: Array = []
	for o in units:
		if o == cur or o.c.dead or o.pos.z != cur.pos.z or Los.distance_m(cur.pos, o.pos) > Attack.SHOTGUN_SHELL_RANGE_M:
			continue
		var d := Vector2(o.pos.x - cur.pos.x, o.pos.y - cur.pos.y)
		if rad_to_deg(absf(aim.angle_to(d))) <= SHELL_HALF_ANGLE and los.sight(cur.pos, o.pos).visible:
			cone.append(o)
	var before := {}
	for o in cone:
		before[o.id] = [o.c.hp, o.c.wound_state()]
	var r := Attack.shotgun_shell(dice, cur.c, weapon, cone.map(func(o): return o.c))
	if not r.ok:
		return r
	turn.use_action()
	_rouse(cone.filter(func(o): return o.team != cur.team))
	_noise(cur.pos)
	var hits: Array = []
	for res in r.results:
		var u := unit_of(res.target)
		hits.append({"id": u.id, "dodged": res.dodged, "damage": int(before[u.id][0]) - u.c.hp, "dead": u.c.dead,
			"killed": u.c.dead or u.c.wound_state() == Combatant.Wound.MORTAL, "wound_before": before[u.id][1], "wound_after": u.c.wound_state()})
	events.append({"type": "shell", "unit": cur.id, "target": target.id, "weapon": weapon.id(), "hit": r.hit, "hits": hits})
	say("%s fires a shotgun shell: %s" % [cur.c.display_name, "%d caught" % hits.filter(func(h): return h.damage > 0).size() if r.hit else "miss"])
	_check_end()
	return {"ok": true, "hit": r.hit, "hits": hits}


## Throw a frag grenade at a square (p174, p177): DEX + Athletics vs the Grenade Launcher DV for
## the range; a miss scatters the blast somewhere in the 5x5 around the aim point. Damage (6d6) is
## rolled once; cover the blast can't destroy shields whoever is behind it; cover it can destroy is
## destroyed and shields nobody; REF 8+ may dive clear.
func throw_grenade(cell: Vector3i) -> Dictionary:
	if cur.c.grenades <= 0:
		return {"ok": false, "reason": "no grenades"}
	if not turn.action_available:
		return {"ok": false, "reason": "no action left"}
	var dist := Los.distance_m(cur.pos, cell)
	if dist > THROW_RANGE_M or cell.z != cur.pos.z or not los.trace(cur.pos, cell).clear:
		return {"ok": false, "reason": "can't throw there"}
	turn.use_action()
	cur.c.grenades -= 1
	var base: int = cur.c.skill_base("athletics") - cur.c.action_penalty()
	var check := Check.vs_dv(dice, base, maxi(10, RulesDB.range_dv("grenade_launcher", dist)))
	var center := cell
	if not check.success:   # p174: the GM places it somewhere in the 10x10 area around the aim
		for k in 12:
			var c := cell + Vector3i(dice.rng.randi_range(-BLAST_HALF, BLAST_HALF), dice.rng.randi_range(-BLAST_HALF, BLAST_HALF), 0)
			if m.inb(c.x, c.y) and los.blocker(c) == "":
				center = c
				break
	var faces := dice.roll_each(GRENADE_DICE, 6)
	var dmg := 0
	for f in faces:
		dmg += f
	# cover in the blast takes the damage first: what breaks no longer covers anyone
	var destroyed: Array = []
	for dy in range(-BLAST_HALF, BLAST_HALF + 1):
		for dx in range(-BLAST_HALF, BLAST_HALF + 1):
			var v := center + Vector3i(dx, dy, 0)
			if los.cover_hp.get(v, 0) > 0:
				los.cover_hp[v] = maxi(0, los.cover_hp[v] - dmg)
				if los.cover_hp[v] == 0:
					m.destroy_cover_at(v.z, Vector2i(v.x, v.y))
					destroyed.append(v)
	var caught: Array = []
	for o in units:
		if o.c.dead or o.pos.z != center.z or maxi(absi(o.pos.x - center.x), absi(o.pos.y - center.y)) > BLAST_HALF:
			continue
		if o.pos != center and not los.trace(center, o.pos).clear:
			continue   # behind cover the blast couldn't break
		caught.append(o)
	var before := {}
	for o in caught:
		before[o.id] = [o.c.hp, o.c.wound_state()]
	var results := Attack.explosion_rolled(dice, check.total, faces, caught.map(func(o): return o.c))
	_rouse(caught.filter(func(o): return o.team != cur.team))
	_noise(center)
	var hits: Array = []
	for res in results:
		var u := unit_of(res.target)
		hits.append({"id": u.id, "dodged": res.dodged, "damage": int(before[u.id][0]) - u.c.hp, "dead": u.c.dead,
			"killed": u.c.dead or u.c.wound_state() == Combatant.Wound.MORTAL, "wound_before": before[u.id][1], "wound_after": u.c.wound_state()})
	events.append({"type": "blast", "unit": cur.id, "cell": cell, "center": center, "hit": check.success, "damage": dmg, "hits": hits, "destroyed": destroyed})
	say("%s throws a grenade%s: %d damage, %d caught." % [cur.c.display_name, "" if check.success else " (off target)", dmg, hits.filter(func(h): return h.damage > 0).size()])
	_check_end()
	return {"ok": true, "hit": check.success, "center": center, "damage": dmg, "hits": hits}


## Tech Field Expertise (p147): jury-rig an ally's (or your own) armour back to full SP as an Action.
## TECH + Basic Tech + Field rank vs the repair DV for its price (Maker table p149, RULES-UNVERIFIED:
## the p140 repair sidebar may differ). Lasts 10 minutes per Rank: the rest of the gig. Once per piece
## until it's properly repaired. Fixes the most-worn location.
func rig_target_loc(target: Dictionary) -> String:
	var best := ""
	var worst := 0
	for loc in ["body", "head"]:
		var a: ArmorPiece = target.c.armor.get(loc)
		if a and not a.rigged and a.max_sp - a.sp > worst:
			worst = a.max_sp - a.sp
			best = loc
	return best


func jury_rig(target: Dictionary) -> Dictionary:
	var c: Combatant = cur.c
	if int(c.maker.get("field", 0)) < 1:
		return {"ok": false, "reason": "needs a Tech's Field Expertise"}
	if target.team != cur.team or target.c.dead or (target != cur and not adjacent(cur.pos, target.pos)):
		return {"ok": false, "reason": "pick yourself or an ally next to you"}
	var loc := rig_target_loc(target)
	if loc == "":
		return {"ok": false, "reason": "no worn armour to rig"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	var a: ArmorPiece = target.c.armor[loc]
	var check := Check.vs_dv(dice, rig_base(c), ArmorPiece.maker_dv(a.price()))
	a.rigged = true   # one try per piece
	if check.success:
		a.sp = a.max_sp
	events.append({"type": "rig", "unit": cur.id, "target": target.id, "loc": loc, "ok": check.success})
	say("%s %s %s's %s armour." % [c.display_name, "jury-rigs" if check.success else "fails to fix", target.c.display_name, loc])
	return {"ok": true, "success": check.success}


static func rig_base(c: Combatant) -> int:
	return c.skill_base("basic_tech") + int(c.maker.get("field", 0)) - c.action_penalty()


## Medtech Pharmaceuticals (p150): giving a dose is an Action, to an ally next to you (or yourself).
## Speedheal: a non-Mortally-Wounded target heals BODY + WILL HP, once per day. Stim: ignore
## Seriously Wounded penalties for an hour (the rest of the gig), once per day.
func dose(target: Dictionary, drug: String) -> Dictionary:
	var c: Combatant = cur.c
	if not c.knows_drug(drug) or c.doses <= 0:
		return {"ok": false, "reason": "no %s doses" % drug}
	if target.team != cur.team or target.c.dead or (target != cur and not adjacent(cur.pos, target.pos)):
		return {"ok": false, "reason": "pick yourself or an ally next to you"}
	var t: Combatant = target.c
	match drug:
		"speedheal":
			if t.wound_state() == Combatant.Wound.MORTAL:
				return {"ok": false, "reason": "Mortally Wounded: stabilize first"}
			if t.speedhealed:
				return {"ok": false, "reason": "already had Speedheal today"}
			if t.hp >= t.max_hp():
				return {"ok": false, "reason": "not hurt"}
		"stim":
			if t.stimmed:
				return {"ok": false, "reason": "already stimmed"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	c.doses -= 1
	var healed := 0
	if drug == "speedheal":
		var before := t.hp
		t.hp = mini(t.max_hp(), t.hp + t.raw_stat("BODY") + t.raw_stat("WILL"))
		t.speedhealed = true
		healed = t.hp - before
	else:
		t.stimmed = true
	events.append({"type": "dose", "unit": cur.id, "target": target.id, "drug": drug, "healed": healed})
	say("%s gives %s %s%s." % [c.display_name, t.display_name, drug.capitalize(), " (+%d HP)" % healed if healed > 0 else ""])
	return {"ok": true, "healed": healed}


## The drug a Medtech would give this ally now ("" if none helps): Speedheal for the hurt, Stim for
## the Seriously Wounded who already had it.
func best_dose(target: Dictionary) -> String:
	var c: Combatant = cur.c
	var t: Combatant = target.c
	if c.doses <= 0 or t.dead or t.wound_state() == Combatant.Wound.MORTAL:
		return ""
	if c.knows_drug("speedheal") and not t.speedhealed and t.hp < t.max_hp():
		return "speedheal"
	if c.knows_drug("stim") and not t.stimmed and t.wound_state() == Combatant.Wound.SERIOUS:
		return "stim"
	return ""


## Next to them, or within a Triage perk's reach (HOUSE-RULE) on the same floor.
func can_reach_to_stabilize(u: Dictionary, target: Dictionary) -> bool:
	var reach := int(u.c.perk_fx("stabilize_reach"))
	if reach > 0 and target.pos.z == u.pos.z:
		return maxi(absi(target.pos.x - u.pos.x), absi(target.pos.y - u.pos.y)) <= reach and (los == null or los.trace(u.pos, target.pos).clear)
	return adjacent(u.pos, target.pos)


## Stabilize (p169, p222): TECH + First Aid (or Paramedic, whichever is better) vs the wound's DV
## on a neighbouring ally. Mortally Wounded → 1 HP, Unconscious, no more Death Saves.
func stabilize(target: Dictionary) -> Dictionary:
	if not can_reach_to_stabilize(cur, target) or target.team != cur.team or target.c.dead:
		return {"ok": false, "reason": "not next to a wounded ally"}
	if target.c.wound_state() != Combatant.Wound.MORTAL:
		return {"ok": false, "reason": "not Mortally Wounded"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	var base: int = maxi(cur.c.skill_base("first_aid"), cur.c.skill_base("paramedic")) - cur.c.action_penalty()
	var check := Check.vs_dv(dice, base, target.c.stabilization_dv())
	if check.success:
		target.c.stabilize()
		if cur.c.perk_fx("revive") > 0:   # HOUSE-RULE perk: back on their feet
			target.c.unconscious = false
			target.c.wake_in = 0
			target.c.hp = maxi(target.c.hp, target.c.raw_stat("BODY"))
	events.append({"type": "stabilize", "unit": cur.id, "target": target.id, "ok": check.success})
	say("%s %s %s." % [cur.c.display_name, "stabilizes" if check.success else "fails to stabilize", target.c.display_name])
	return {"ok": true, "success": check.success}


## Suppressed (p174): the unit's next Move Action goes into cover from the suppressor, running
## if it needs to; if nothing reachable is out of sight, it gets as close to cover as it can.
func _take_cover(u: Dictionary) -> void:
	var from: Dictionary = units[int(u.suppressed_by)]
	u.erase("suppressed_by")
	if from.c.dead or not los.sight(from.pos, u.pos).visible:
		return
	var reach: Dictionary = _with_locks(func(): return nav.reachable(u.pos, turn.squares_available() + u.c.stat("MOVE"), occupied(u)))
	var best := Vector3i(-1, -1, -1)
	var best_d := INF
	var near := Vector3i(-1, -1, -1)
	var near_d := INF
	for cell in reach:
		var d := float(reach[cell])
		if not los.sight(from.pos, cell).visible:
			if d < best_d:
				best_d = d
				best = cell
		elif d < near_d:   # fallback: the closest square with something solid beside it
			for dir in MapGen.DIRS:
				if los.blocker(Vector3i(cell.x + dir.x, cell.y + dir.y, cell.z)) != "":
					near_d = d
					near = cell
					break
	var dest := best if best.x >= 0 else near
	say("%s is pinned down and dives for cover." % u.c.display_name)
	if dest.x >= 0 and dest != u.pos:
		move_to(dest, true)


## Reload (an Action, p169) as an event, so the view can play it.
func reload(weapon: Weapon) -> bool:
	if not weapon.uses_ammo() or weapon.ammo >= weapon.mag() or not turn.use_action():
		return false
	weapon.reload()
	events.append({"type": "reload", "unit": cur.id, "weapon": weapon.id()})
	say("%s reloads." % cur.c.display_name)
	return true


## Shoot the cover (or wall, door, window) in the way: damage dice vs its HP; at 0 it's gone.
func shoot_cover(cell: Vector3i, weapon: Weapon) -> Dictionary:
	if turn.attacks_left <= 0 and not turn.start_attack(weapon, true):
		return {"ok": false, "reason": "no action left"}
	turn.use_attack()
	_noise(cur.pos)
	var dmg := dice.roll(weapon.dice(), 6)
	events.append({"type": "cover", "unit": cur.id, "cell": cell, "damage": dmg, "weapon": weapon.id()})
	if los.cover_hp.has(cell) and los.cover_hp[cell] > 0:
		los.cover_hp[cell] = maxi(0, los.cover_hp[cell] - dmg)
		if los.cover_hp[cell] == 0:
			m.destroy_cover_at(cell.z, Vector2i(cell.x, cell.y))
			say("Cover destroyed.")
		events[-1]["left"] = los.cover_hp[cell]
		events[-1]["is_cover"] = true
		return {"ok": true, "damage": dmg, "left": los.cover_hp[cell]}
	var wc := m.wall_cover(cell.z, cell.x, cell.y)
	if wc.is_empty():
		return {"ok": false, "reason": "nothing to shoot"}
	var hp: int = los.wall_hp.get(cell, maxi(1, int(wc.hp)))
	hp = maxi(0, hp - dmg)
	los.wall_hp[cell] = hp
	if hp == 0:
		m.set_t(cell.z, cell.x, cell.y, TacMap.T.FLOOR if cell.z > 0 or m.label(cell.z, cell.x, cell.y) >= 0 else TacMap.T.OUTSIDE)
		nav.locked.erase(cell)
		say("The %s gives way." % wc.material)
	events[-1]["left"] = hp
	return {"ok": true, "damage": dmg, "left": hp}


# --- NET ---------------------------------------------------------------------------

## NET Actions per turn: by Interface Rank (p197), plus an Overclock perk.
static func net_actions_for(c: Combatant) -> int:
	return NetRun.net_actions(NetRun.interface_rank(c)) + int(c.perk_fx("net_actions"))


## Meatspace jack-in range: 6 m (p198), or a Long Leash perk's (HOUSE-RULE).
static func jack_range(c: Combatant) -> float:
	return maxf(JACK_IN_RANGE_M, float(c.perk_fx("jack_range_m")))


## Access points within jack-in range of `u` (6 m, p198): [{index, structure, device}].
func jack_points(u: Dictionary) -> Array:
	var out := []
	for sid in m.architectures:
		var a: NetArchitecture = m.architectures[sid]
		for i in a.access_points.size():
			var d: Dictionary = m.devices[a.access_points[i].device]
			var dp := Vector3i(d.pos.x, d.pos.y, d.floor)
			if dp.z == u.pos.z and Los.distance_m(u.pos, dp) <= jack_range(u.c):
				out.append({"index": i, "structure": sid, "device": d.id})
	return out


func jack_in(point: Dictionary) -> bool:
	if NetRun.interface_rank(cur.c) <= 0 or not turn.use_action():
		return false
	var run := NetRun.new(m.architectures[point.structure], cur.c)
	run.nets = m.architectures
	run.jack_in(point.index)
	runs[cur.id] = run
	var dev: Dictionary = m.devices[point.device]
	jack_pos[cur.id] = Vector3i(dev.pos.x, dev.pos.y, dev.floor)
	say("%s jacks in." % cur.c.display_name)
	return true


## NET Actions (p198). kind: backdoor | control | eye_dee | zap | cross | jack_out. Moving between
## nodes is free (run.move_to). A turn spent in the NET forgoes the meat Action (p197).
func net_action(kind: String, arg: int = -1) -> Dictionary:
	var run: NetRun = runs.get(cur.id)
	if run == null or net_left <= 0:
		return {"ok": false, "reason": "no NET Actions left"}
	if kind == "zap" and run.arch.ice_at(run.current).is_empty():   # check before spending anything
		return {"ok": false, "reason": "no ICE here"}
	if kind == "cross" and (run.current < 0 or String(run.cur_node().type) != "socket" or not run.nets.has(run.cur_node().get("target_structure", -1))):
		return {"ok": false, "reason": "no socket here"}
	turn.action_available = false
	net_left -= 1
	var n := run.cur_node()
	match kind:
		"backdoor":
			var c := run.backdoor(dice)
			say("Backdoor %s." % ("succeeds" if c.success else "fails"))
			return {"ok": true, "success": c.success}
		"control":
			var c2 := run.control(dice)
			if c2.success:
				for did in n.get("devices", []):
					disabled_devices[did] = true
					var dev: Dictionary = m.devices[did]
					if dev.type == "door_lock":
						nav.locked.erase(Vector3i(dev.pos.x, dev.pos.y, dev.floor))
				say("Control of %s." % String(n.group).replace("_", " "))
			return {"ok": true, "success": c2.success}
		"eye_dee":
			var c3 := run.eye_dee(dice)
			if c3.success and objective.get("node", -2) == n.id and run.arch.structure == objective.structure:
				objective.done = true
			_check_end()
			return {"ok": true, "success": c3.success}
		"zap":
			var ice: Array = run.arch.ice_at(run.current)
			if ice.is_empty():
				return {"ok": false, "reason": "no ICE here"}
			var tgt: Dictionary = ice[0]
			var stats: Dictionary = RulesDB.load_json("black_ice.json")["ice"][tgt.kind]
			var hit := Check.opposed(dice, run.rank(), int(stats.def))
			if hit.success:
				tgt["rez"] = int(tgt.get("rez", stats.rez)) - dice.roll(1, 6)
				if tgt.rez <= 0:
					tgt["derezzed"] = true
					say("%s derezzed." % tgt.kind)
			return {"ok": true, "success": hit.success}
		"cross":
			return {"ok": run.cross()}
		"jack_out":
			runs.erase(cur.id)
			say("%s jacks out." % cur.c.display_name)
			return {"ok": true}
	return {"ok": false, "reason": "unknown"}


## Black ICE on the runner's node attacks at the start of their turn: ATK + 1d10 vs Interface +
## 1d10 (p205); anti-personnel hits deal their brain damage straight to HP (p206-207).
func _ice_turn(u: Dictionary) -> void:
	var run: NetRun = runs.get(u.id)
	if run == null:
		return
	for ice in run.arch.ice_at(run.current):
		var stats: Dictionary = RulesDB.load_json("black_ice.json")["ice"][ice.kind]
		var hit := Check.opposed(dice, int(stats.atk), run.rank())
		if hit.success and String(stats.brain) != "":
			var parts := String(stats.brain).split("d")
			var dmg := dice.roll(int(parts[0]), int(parts[1]))
			var before: int = u.c.wound_state()
			u.c.hp -= dmg
			say("%s hits %s for %d brain damage." % [ice.kind, u.c.display_name, dmg])
			events.append({"type": "harm", "unit": u.id, "damage": dmg, "source": String(ice.kind).to_upper(), "wound_before": before, "wound_after": u.c.wound_state()})


## Where the runner is physically jacked in (the device they used, not the NET's first port).
func _ap_pos(run: NetRun) -> Vector3i:
	for uid in runs:
		if runs[uid] == run and jack_pos.has(uid):
			return jack_pos[uid]
	return cur.pos
