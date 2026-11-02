class_name Encounter
extends RefCounted
## A gig on a generated scene: crew vs guards, turn by turn, with the Netrunner's NET session.
## Pure rules (no Nodes) so it runs headless; the M3b greybox drives it and draws the results.
##
## Objective (greybox): download the target building's most valuable File by Eye-Dee'ing it in the
## NET, or put every guard down. The crew loses if everyone is dead.

const JACK_IN_RANGE_M := 6.0      # p198
const GUARDS_BASE := 3
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
var objective := {}                 ## {structure, node, done}
var vision: Vision                  ## what the crew can see (drives fog and hidden guards)
## What happened, in order, for the view to animate: {type: move|attack|cover|alert, ...}.
## The view drains it; rules code never reads it.
var events: Array[Dictionary] = []
var disabled_devices := {}          ## device id → true (turrets/cameras under the runner's control)


static func setup(p_map: TacMap, p_dice: Dice, crew: Array[Combatant]) -> Encounter:
	var e := Encounter.new()
	e.m = p_map
	e.dice = p_dice
	e.nav = Nav.new(p_map)
	e.los = Los.new(p_map)
	e.init = Initiative.new(p_dice)
	var deploy: Dictionary = p_map.entrances.filter(func(x): return x.kind == "deploy")[0]
	var cells: Array = deploy.get("cells", [deploy.pos])
	for i in crew.size():
		var c: Vector2i = cells[i % cells.size()]
		e._add(crew[i], Vector3i(c.x, c.y, 0), 0)
	# Guards at posts, target building first.
	var target_sid := -1
	for st in p_map.structures:
		if st.target:
			target_sid = st.id
	var posts := p_map.posts.duplicate()
	posts.sort_custom(func(a, b): return int(a.structure == target_sid) > int(b.structure == target_sid))
	var sec := int(p_map.params.get("security", 1))
	var want := GUARDS_BASE + sec * 2
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
		var g := Recruit.generate(p_dice, "solo" if p_dice.d(3) > 1 else "lawman", "streetrat", "Guard %d" % (i + 1))
		g.team = 1
		g.awareness = {}
		g.tracks_humanity = false  # rank-and-file guards don't roll cyberpsychosis episodes
		e._add(g, Vector3i(posts[i].pos.x, posts[i].pos.y, posts[i].floor), 1)
	# Objective: the target NET's most valuable File.
	if p_map.architectures.has(target_sid):
		var a: NetArchitecture = p_map.architectures[target_sid]
		var best := -1
		for nd in a.nodes_of_type("file"):
			if best < 0 or int(nd.value) > int(a.nodes[best].value):
				best = nd.id
		e.objective = {"structure": target_sid, "node": best, "done": false}
	# M3 playtest verdict: guards only join the initiative order once they're alerted.
	for u in e.units:
		if u.alerted:
			e.init.add(u.c)
	e.vision = Vision.new(p_map, e.los)
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
		turn = TurnState.begin(dice, c)
		net_left = 0
		if not turn.survived:
			say("%s fails a Death Save and dies." % c.display_name)
		elif c.can_act():
			_ice_turn(cur)
			if cur.team == 1 or turn.psychotic:
				AI.act(self, cur)
				end_turn()
				continue
			if runs.has(cur.id):
				net_left = NetRun.net_actions(NetRun.interface_rank(c))
			return
		_check_end()


func end_turn() -> void:
	if turn != null:
		var dmg := turn.end()
		if dmg > 0:
			say("%s takes %d from strained injuries." % [cur.c.display_name, dmg])
	_check_end()


func _check_end() -> void:
	if state != "playing":
		return
	if alive(0).is_empty() and units.filter(func(u): return u.team == 0 and not u.c.dead).is_empty():
		state = "lost"
	elif alive(1).is_empty():
		state = "won"
		say("All guards are down.")
	elif objective.get("done", false):
		state = "won"
		say("The data is yours.")


# --- Alerts ------------------------------------------------------------------------

## Guards who can see a crew member (clear sight, within SPOT_RANGE) are alerted; every newly
## alerted guard shouts, rousing guards near it. Newly alerted guards roll Initiative and slot in
## (Initiative.add keeps the current turn). Returns the units alerted by this call.
func update_alerts() -> Array:
	var fresh := []
	for g in units:
		if g.alerted or g.c.dead:
			continue
		for u in alive(0):
			if u.pos.z == g.pos.z and Vector2(u.pos.x - g.pos.x, u.pos.y - g.pos.y).length() <= SPOT_RANGE \
					and los.trace(g.pos, u.pos).clear:
				fresh.append(g)
				say("%s spots %s!" % [g.c.display_name, u.c.display_name])
				break
	_rouse(fresh)
	return fresh


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
	if cur.team == 1:
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
	if runs.has(cur.id) and Los.distance_m(dest, _ap_pos(runs[cur.id])) > JACK_IN_RANGE_M:
		say("%s moves out of range and is dumped from the NET." % cur.c.display_name)
		runs.erase(cur.id)
	return true


# --- Combat ------------------------------------------------------------------------

func preview(target: Dictionary, weapon: Weapon, mode: Attack.Mode) -> Dictionary:
	var s := los.sight(cur.pos, target.pos)
	if not s.visible:
		return {"ok": false, "reason": "no line of sight", "chance": 0.0, "blocker": s.blocker}
	var p := Attack.preview(cur.c, weapon, target.c, mode, Los.distance_m(s.from, target.pos))
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
	var r := Attack.resolve(dice, cur.c, weapon, target.c, mode, Los.distance_m(p.from, target.pos))
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
	return {"ok": true, "damage": dmg, "left": hp}


# --- NET ---------------------------------------------------------------------------

## Access points within jack-in range of `u` (6 m, p198): [{index, structure, device}].
func jack_points(u: Dictionary) -> Array:
	var out := []
	for sid in m.architectures:
		var a: NetArchitecture = m.architectures[sid]
		for i in a.access_points.size():
			var d: Dictionary = m.devices[a.access_points[i].device]
			var dp := Vector3i(d.pos.x, d.pos.y, d.floor)
			if dp.z == u.pos.z and Los.distance_m(u.pos, dp) <= JACK_IN_RANGE_M:
				out.append({"index": i, "structure": sid, "device": d.id})
	return out


func jack_in(point: Dictionary) -> bool:
	if NetRun.interface_rank(cur.c) <= 0 or not turn.use_action():
		return false
	var run := NetRun.new(m.architectures[point.structure], cur.c)
	run.nets = m.architectures
	run.jack_in(point.index)
	runs[cur.id] = run
	say("%s jacks in." % cur.c.display_name)
	return true


## NET Actions (p198). kind: backdoor | control | eye_dee | zap | cross | jack_out. Moving between
## nodes is free (run.move_to). A turn spent in the NET forgoes the meat Action (p197).
func net_action(kind: String, arg: int = -1) -> Dictionary:
	var run: NetRun = runs.get(cur.id)
	if run == null or net_left <= 0:
		return {"ok": false, "reason": "no NET Actions left"}
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
			u.c.hp -= dmg
			say("%s hits %s for %d brain damage." % [ice.kind, u.c.display_name, dmg])


func _ap_pos(run: NetRun) -> Vector3i:
	for ap in run.arch.access_points:
		var d: Dictionary = m.devices[ap.device]
		return Vector3i(d.pos.x, d.pos.y, d.floor)
	return cur.pos
