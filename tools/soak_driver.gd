class_name SoakDriver
extends RefCounted
## Integration soak for the whole gig loop, headless: campaigns over several seeds take gigs (Night
## City fixer-board offers, and forced gigs at every set-piece location), build the map and
## Encounter exactly as the greybox does (GigSetup.for_campaign), play them out with the AI on both
## sides, settle them (Campaign.resolve), save and reload the campaign, and go on. Invariants are
## checked all the way; every breach is a line in `failures`. `trace` holds one line per gig: the
## same seed must give the same trace (determinism).
## Used by tools/soak.gd (wide runs, tools/soak.sh) and tests/unit/test_soak.gd (a small, fast pass).
##
## Stand-ins for the player, so the AI crew can get anywhere a player could:
## - locked doors are open (a player bypasses or shoots them; the AI crew can't);
## - the crew's turn: a Netrunner on a data job jacks in and goes for the File (taking Control
##   Nodes and firing held turrets on the way); everyone else moves toward the objective (its
##   square, its mark or captive, then the extraction zone), takes the objective's action when it
##   is in reach, else shoots what it sees; with no objective to go for, the guards' AI (AI.act); a
##   freed hostage keeps with the crew (AI.follow);
## - after `max_rounds` rounds the crew pulls out (state "fled").

const SAVE_DIR := "user://soak"
const OFFER_KINDS := ["data_theft", "gang_hit", "corp_extraction", "assassination", "rescue", "sabotage"]
## The skills the crew trains with its IP between gigs, as a player would.
const TRAIN := ["handgun", "shoulder_arms", "autofire", "evasion", "stealth", "perception"]
const BAD_TILES := [TacMap.T.VOID, TacMap.T.WALL, TacMap.T.WATER]

var max_rounds := 12
var verbose := false
var debug := false        ## every crew Move, for chasing a stuck crew
var failures: Array[String] = []
var trace: Array[String] = []
var stats := {"gigs": 0, "won": 0, "fled": 0, "lost": 0, "rounds": 0, "turret_units": 0, "turret_shots": 0, "device_ops": 0,
	"complications": 0, "utilities": 0, "neutral": 0, "peace_broken": 0, "setpieces": {}, "towers": {}, "sides": {}, "kinds": {}, "offers": {}, "looks": {}}

var _ctx := ""            ## "seed 3 gig 2 (title)": prefixed to failures
var _seen_fail := {}      ## one report per kind of breach per gig


## Every set-piece location: [[setpiece id, location id], ...] in a stable order.
static func setpiece_locations() -> Array:
	var out := []
	var ids := SetPieces.ids()
	ids.sort()
	for id in ids:
		var locs: Array = (SetPieces.get_def(id).get("locations", {}) as Dictionary).keys()
		locs.sort()
		for lid in locs:
			out.append([String(id), String(lid)])
	return out


## The gig kinds a location's hooks or `gigs` name (what the board would offer there).
static func kinds_at(lid: String) -> Array:
	var l := World.location(lid)
	var out := []
	for h in l.get("hooks", []):
		for k in h.get("gigs", []):
			if not k in out and k in OFFER_KINDS:
				out.append(k)
	for k in l.get("gigs", []):
		if not k in out and k in OFFER_KINDS:
			out.append(k)
	return out


## Plays `gigs` gigs of a campaign started with `seed_value`. `plan` picks each gig: an Array of
## "board", "setpiece" (the next set-piece location in turn), "setpiece:<location>[:<kind>]", "tower"
## (the next tower in turn: its sky band, TowerGen) or "tower:<tower id or location>[:<kind>]",
## cycled through; empty for the default rotation (board, board, setpiece). Returns the campaign
## as it ends.
func run_campaign(seed_value: int, gigs: int, plan: Array = []) -> Campaign:
	var camp := Campaign.new_game(seed_value)
	var sps := setpiece_locations()
	for n in gigs:
		_ctx = "seed %d gig %d" % [seed_value, n + 1]
		_seen_fail.clear()
		_downtime(camp)
		if camp.alive_crew().filter(func(c): return c.can_act()).is_empty():
			trace.append("%s: crew gone" % _ctx)
			break
		var pick: String = plan[n % plan.size()] if not plan.is_empty() else ["board", "board", "setpiece"][n % 3]
		if pick == "setpiece":
			pick = "setpiece:%s" % sps[(seed_value * 3 + n) % sps.size()][1]
		elif pick == "tower":
			var tws := tower_locations()
			pick = "tower:%s" % tws[(seed_value * 3 + n) % tws.size()]
		var idx := _offer(camp, pick, seed_value + n)
		if idx < 0:
			continue
		_play_gig(camp, idx)
		_check_campaign(camp, "after the gig")
		camp = _round_trip(camp, seed_value)
	return camp


## Heal up (a few days at most), treat Critical Injuries at the clinic while the money lasts, hire
## to three, IP into the fighting skills.
func _downtime(camp: Campaign) -> void:
	for c in camp.crew:
		while not c.injuries.is_empty() and camp.treat(c, 0):
			pass
	var guard := 0
	while camp.crew.any(func(c): return c.hp < c.max_hp()) and guard < 6:
		camp.rest(1)
		guard += 1
	while camp.crew.size() < 3 and not camp.recruits.is_empty() and camp.eb >= int(Campaign.ECON.hire):
		if not camp.hire(0):
			break
	for c in camp.crew:
		for s in TRAIN:
			c.raise_skill(s)


## Put the offer `pick` names on the board (if it isn't there) and return its index, or -1.
func _offer(camp: Campaign, pick: String, k: int) -> int:
	if pick == "board":
		if camp.board.is_empty():
			_fail("the board is empty")
			return -1
		var i: int = k % camp.board.size()
		var b: Dictionary = camp.board[i]
		_count("offers", "unique" if b.get("unique", false) else ("city" if String(b.get("location", "")) != "" else "generic"))
		return i
	if pick.begins_with("setpiece:"):
		var lid := pick.get_slice(":", 1)
		var kind := pick.get_slice(":", 2) if pick.get_slice_count(":") > 2 else ""
		var gig := forced_offer(camp, lid, kind, k)
		if gig.is_empty():
			_fail("no offer at %s" % pick)
			return -1
		if String(gig.get("setpiece", "")) == "":
			_fail("an offer at %s has no set piece" % lid)
		camp.board.append(gig)
		_count("setpieces", String(gig.get("setpiece", "")))
		_count("offers", "setpiece")
		return camp.board.size() - 1
	if pick.begins_with("tower:"):
		var tid := World.tower_location(pick.get_slice(":", 1))
		var tkind := pick.get_slice(":", 2) if pick.get_slice_count(":") > 2 else ""
		if tid == "":
			_fail("no tower %s" % pick)
			return -1
		var tgig := camp.tower_gig(RulesDB.gen("gigs.json"), tid, tkind)
		if tgig.is_empty():
			_fail("no tower offer at %s" % pick)
			return -1
		tgig["id"] = "%d-%s-soak" % [camp.day, tid]
		camp.board.append(tgig)
		_count("towers", String(World.tower(tid).get("id", tid)))
		_count("offers", "tower")
		return camp.board.size() - 1
	_fail("unknown plan entry %s" % pick)
	return -1


## Every tower location (World.towers), sorted: what the "tower" plan entry cycles through.
static func tower_locations() -> Array:
	var out: Array = World.towers().keys().filter(func(id): return Campaign.offered_at(String(id)))
	out.sort()
	return out


## A board offer at canon location `lid` (a `kind` job, else one its hooks name, picked by `k`),
## made by the board's own offer code (Campaign._city_offer) with every other place taken, so it
## is what the fixer would have offered there. {} if the place offers no such job.
static func forced_offer(camp: Campaign, lid: String, kind := "", k := 0) -> Dictionary:
	var kinds := kinds_at(lid)
	if kinds.is_empty():
		return {}
	if kind == "":
		kind = String(kinds[k % kinds.size()])
	var g := RulesDB.gen("gigs.json")
	var ts: Array = (g.templates as Array).filter(func(x): return String(x.kind) == kind)
	if ts.is_empty():
		return {}
	var used := {}
	for id in World.locations():
		if String(id) != lid:
			used[id] = true
	var known := camp.best_reputation()
	var gig := camp._city_offer(g, kind, camp._roll_security(g, known), known, used)
	if gig.is_empty():   # the place starts above the rolled level: the top level reaches it
		gig = camp._city_offer(g, kind, 3, known, used)
	if not gig.is_empty():
		gig["id"] = "%d-%s-soak" % [camp.day, lid]
	return gig


## Take board offer `idx` and play it to its settling.
func _play_gig(camp: Campaign, idx: int) -> void:
	_ctx += " (%s)" % String(camp.board[idx].get("title", "?"))
	var gig := camp.accept(idx)
	if gig.is_empty():
		_fail("accept refused")
		return
	stats.gigs += 1
	_count("kinds", Campaign.objective_for(gig))
	_count("looks", String(gig.get("district", "")) if String(gig.get("district", "")) != "" else "(none)")
	var e := _play(camp)
	if e == null:
		camp.active_gig = {}
		return
	var line := "%s %s/%s %s sec %d: %s r%d" % [_ctx, String(gig.scene), String(gig.get("setpiece", "")),
		Campaign.objective_for(gig), int(gig.security), e.state, e.init.round_num]
	var crew_before := camp.crew.duplicate()
	var rep := camp.resolve(e)
	if rep.is_empty():
		_fail("resolve refused the encounter")
		return
	stats[e.state] = int(stats.get(e.state, 0)) + 1
	trace.append(line + " · pay %d ip %d dead %d eb %d day %d" % [int(rep.pay), int(rep.ip), (rep.dead as Array).size(), camp.eb, camp.day])
	if int(rep.pay) < 0 or int(rep.ip) < 0:
		_fail("negative pay %d or IP %d" % [int(rep.pay), int(rep.ip)])
	if not camp.active_gig.is_empty():
		_fail("the gig is still active after it was settled")
	for c in crew_before:
		if not c.dead and c.injuries.any(func(i): return i.has("expires_in")):
			_fail("%s came home with a minute's injury" % c.display_name, "brief")


## Set up the active gig's encounter as the greybox does and play it out. Null if it couldn't start.
func _play(camp: Campaign) -> Encounter:
	var t0 := Time.get_ticks_msec()
	var gs := GigSetup.for_campaign(camp)
	var e := gs.enc
	if e == null or e.units.is_empty():
		_fail("no encounter for %s" % String(camp.active_gig.get("scene", "")))
		return null
	if gs.map.street < 0 or gs.map.street >= gs.map.floors:
		_fail("the street (m.street %d) is not a floor of %d" % [gs.map.street, gs.map.floors])
	e.nav.locked = {}   # stand-in for a player who bypasses or shoots the locks
	var sp := String(gs.map.params.get("setpiece", ""))
	if String(camp.active_gig.get("setpiece", "")) != sp:
		_fail("the gig's set piece %s built as '%s'" % [camp.active_gig.get("setpiece", ""), sp])
	if String(camp.active_gig.get("tower", "")) != "":
		_check_tower(camp, e)
	stats.turret_units += e.units.filter(func(u): return u.has("turret")).size()
	if not e.complication_waves.is_empty() or e.events.any(func(ev): return String(ev.get("type", "")) == "complication"):
		stats.complications += 1
	if not e.outages.is_empty():
		stats.utilities += 1
	for sd in e.sides:
		_count("sides", String(sd.ai) + (" at war" if sd.has("at_war") else ""))
	if e.neutral != null:
		stats.neutral += 1
	_check_units(e, "at setup")
	_check_start(e)
	e.next_turn()
	var turns := 0
	var last_round := e.init.round_num
	var same_round := 0
	while e.state == "playing":
		_check_units(e, "round %d" % e.init.round_num)
		if e.init.round_num > max_rounds:
			e.state = "fled"   # time's up: the crew pulls out
			break
		if e.cur.is_empty() or int(e.cur.team) != Encounter.CREW:
			_fail("next_turn returned on a non-crew turn (%s)" % ("none" if e.cur.is_empty() else e.cur.c.display_name))
			break
		_crew_turn(e)
		if e.state == "playing":
			e.end_turn()
		if e.state == "playing":
			e.next_turn()
		turns += 1
		if e.init.round_num == last_round:
			same_round += 1
			if same_round > 60:
				_fail("stuck: 60 crew turns in round %d" % last_round)
				e.state = "fled"
				break
		else:
			last_round = e.init.round_num
			same_round = 0
	_check_units(e, "at the end (%s)" % e.state)
	if e.neutral != null and not e.neutral.holds:
		stats.peace_broken += 1
	stats.rounds += e.init.round_num
	if verbose:
		print("  %s %s: %s after %d rounds, %d crew turns, %.1fs; alarm %d, opfor %d, units %d" % [_ctx,
			String(camp.active_gig.scene), e.state, e.init.round_num, turns, (Time.get_ticks_msec() - t0) / 1000.0,
			e.alarm, e.opfor().size(), e.units.size()])
		if debug:
			for l in e.log.slice(-40):
				print("    | " + l)
	return e


# --- The crew's turn ---------------------------------------------------------------------

func _crew_turn(e: Encounter) -> void:
	var u := e.cur
	AI.put_out(e, u)   # burning: beat the flames out first when it's sensible (p.180)
	if e.is_hostage(u):   # a freed hostage is the player's to move: keep them with the crew
		AI.follow(e, u)
		return
	if _net_turn(e, u):
		return
	var goal := _goal(e, u)
	if goal.is_empty():
		_obj_step(e)
		if e.state == "playing" and e.turn.action_available:
			AI.act(e, u)
		return
	_obj_step(e)
	_step_toward(e, u, goal)
	if e.state != "playing":
		return
	if _obj_step(e):
		return
	if e.obj.withdraw_wins() and e.can_withdraw():
		e.withdraw()
		return
	if not e.turn.action_available or u.c.weapons.is_empty():
		return
	var w: Weapon = u.c.weapons[0]
	if w.jammed or (w.uses_ammo() and w.ammo <= 0):
		e.reload(w)
	elif not AI._shoot(e, u, w) and e.turn.run():   # nothing to shoot: Run on (p169)
		_step_toward(e, u, goal)
		_obj_step(e)


## Where this crew member is headed: the extraction zone once the job is done (or they carry the
## package, or the captive is free), else the objective's square or person; [] to just fight.
func _goal(e: Encounter, u: Dictionary) -> Array:
	var o := e.objective
	if _runs_for_data(e, u):   # the Netrunner heads for a jack point into the target's NET
		var a: NetArchitecture = e.m.architectures[int(o.structure)]
		var pts := []
		for ap in a.access_points:
			var d: Dictionary = e.m.devices[ap.device]
			pts.append(Vector3i(d.pos.x, d.pos.y, int(d.floor)))
		if not pts.is_empty():
			return pts
	if bool(o.get("freed", false)) and not e.obj.done():   # escort: stay by the captive, who follows the crew out
		var cap: Dictionary = e.units[int(o.captive)]
		if Vector2(cap.pos.x - u.pos.x, cap.pos.y - u.pos.y).length() + absi(cap.pos.z - u.pos.z) * 4 > 3.0:
			return [cap.pos]
	var home: bool = e.obj.done() or int(o.get("carrier", -1)) == int(u.id) or bool(o.get("freed", false)) or bool(o.get("planted", false))
	if home:
		return e.extract_cells.keys()
	var fu := e.obj.focus_unit()
	if fu >= 0 and not e.units[fu].c.dead:
		return [e.units[fu].pos]
	var fc := e.obj.focus_cell()
	if fc.x >= 0 and int(o.get("carrier", -1)) < 0:
		return [fc]
	return []


## A data job this crew member can do in the NET: a Netrunner, the File not yet theirs.
func _runs_for_data(e: Encounter, u: Dictionary) -> bool:
	var o := e.objective
	return String(o.kind) == "data" and not e.obj.done() and int(o.get("node", -1)) >= 0 \
		and e.m.architectures.has(int(o.get("structure", -1))) and NetRun.interface_rank(u.c) > 0


## The Netrunner's turn in the NET (p197-199): jack in at a point into the target's NET when one is
## in reach, then spend the NET Actions: fight ICE on the node (Sword, else Zap), Backdoor a
## firewall, take a Control Node (and fire any turret it holds at someone in its sights), Eye-Dee
## the File; between them move (free) toward the File. Jacks out once the File is theirs or the
## way is shut. False if the turn is a meat one.
func _net_turn(e: Encounter, u: Dictionary) -> bool:
	if not e.runs.has(u.id):
		if not _runs_for_data(e, u) or not e.turn.action_available:
			return false
		var pts := e.jack_points(u).filter(func(p): return int(p.structure) == int(e.objective.structure))
		if pts.is_empty() or not e.jack_in(pts[0]):
			return false
	var run: NetRun = e.runs.get(u.id)
	var target := int(e.objective.get("node", -1)) if run != null and run.arch.structure == int(e.objective.get("structure", -2)) else -1
	for guard in 12:
		if e.state != "playing" or not e.runs.has(u.id) or e.net_left <= 0:
			break
		run = e.runs[u.id]
		var n := run.cur_node()
		if not run.arch.ice_at(run.current).is_empty():
			if not e.net_action("sword").get("ok", false):
				e.net_action("zap")
			continue
		if String(n.type) == "firewall" and run.action_block("backdoor") == "" and not run.movable().has(target):
			e.net_action("backdoor")
			continue
		if run.action_block("control") == "":
			e.net_action("control")
			continue
		if _fire_held_turret(e, u):
			continue
		if _work_device(e, u):
			continue
		if run.current == target and run.action_block("eye_dee") == "":
			e.net_action("eye_dee")
			continue
		var step := _net_step(run, target)
		if step >= 0 and e.net_move(step):
			continue
		if e.obj.done() or target < 0 or step < 0:
			e.net_action("jack_out")
		break
	return true


## A held turret with someone in its sights fires (Encounter.fire_turret, a NET Action).
func _fire_held_turret(e: Encounter, u: Dictionary) -> bool:
	for t in e.held_turrets(int(u.id)):
		if String(t.why) == "" and not (t.targets as Array).is_empty():
			stats.turret_shots += 1
			return bool(e.fire_turret(int(t.id), int(t.targets[0].id)).get("ok", false))
	return false


## Work a held node's device (Encounter.net_device, a NET Action): loop live cameras, open a door
## the NET still has locked. Once per node a turn (p199), like the turrets.
func _work_device(e: Encounter, u: Dictionary) -> bool:
	for row in e.device_ops(int(u.id)):
		for op in row.ops:
			if String(op.why) == "" and ((op.op == "loop" and not op.on) or (op.op == "lock" and op.on)):
				var r := e.net_device(int(op.node), int(op.device))
				if bool(r.get("ok", false)):
					stats.device_ops += 1
					return true
	return false


## The node to move to next toward `target` (the movable one nearest it by links), or -1.
static func _net_step(run: NetRun, target: int) -> int:
	if target < 0:
		return -1
	var dist := {target: 0}
	var q := [target]
	while not q.is_empty():
		var n: int = q.pop_front()
		for nb in run.arch.neighbors(n):
			if not dist.has(nb):
				dist[nb] = int(dist[n]) + 1
				q.append(nb)
	var best := -1
	var bd := int(dist.get(run.current, 9999))
	for id in run.movable():
		if int(dist.get(id, 9999)) < bd:
			bd = int(dist[id])
			best = int(id)
	return best


## The objective's action if it's offered (grab, free, plant). True if one was taken.
func _obj_step(e: Encounter) -> bool:
	if e.state != "playing" or not e.turn.action_available:
		return false
	var acts := e.obj_actions()
	if acts.is_empty():
		return false
	return bool(e.obj_act(acts[0]).get("ok", false))


## A Move toward the nearest of `goal` (walking distance), keeping the Action.
func _step_toward(e: Encounter, u: Dictionary, goal: Array) -> void:
	if not e.turn.can_move():
		return
	var field: Dictionary = e._with_locks(func(): return e.nav.distance_field(goal, {}, 4000))
	var best: Vector3i = u.pos
	var best_d := int(field.get(u.pos, 99999))
	var opts := e.move_options()
	var cells := opts.keys()
	cells.sort()   # a stable pick among equals
	for cell in cells:
		var d := int(field.get(cell, 99999))
		if d < best_d:
			best_d = d
			best = cell
	if debug:
		print("    %s r%d at %s: %d to go, best %s %d of %d options" % [u.c.display_name, e.init.round_num, u.pos, int(field.get(u.pos, 99999)), best, best_d, opts.size()])
	if best != u.pos:
		e.move_to(best)


# --- Invariants ----------------------------------------------------------------------------

## Every unit on a floor of the map, inside it, on a tile one can stand on; turret ammo never below
## zero; the Initiative order never without someone alive while any of the crew live (once the
## crew are all dead the order may run dry: that is how a gig is lost).
func _check_units(e: Encounter, when: String) -> void:
	var m := e.m
	var in_order := {}
	for c in e.init.order():
		in_order[c] = true
	var crew_up := false
	for u in e.units:
		var p: Vector3i = u.pos
		var who := "%s (%s)" % [u.c.display_name, e.sides[int(u.team)].ai]
		if p.z < 0 or p.z >= m.floors:
			_fail("%s on floor %d of %d, %s" % [who, p.z, m.floors, when], "floor")
			continue
		if not m.inb(p.x, p.y):
			_fail("%s off the map at %s, %s" % [who, p, when], "offmap")
			continue
		var t := m.t(p.z, p.x, p.y)
		if t in BAD_TILES and not u.has("turret"):
			_fail("%s stands in %s at %s, %s" % [who, TacMap.T.keys()[t], p, when], "tile:" + str(u.id))
		if u.has("turret"):
			for w in u.c.weapons:
				if w.ammo < 0:
					_fail("%s has %d rounds" % [who, w.ammo], "ammo")
		if not u.c.dead:
			crew_up = crew_up or (int(u.team) == Encounter.CREW and not bool(u.get("captive", false)))
			if int(u.team) == Encounter.CREW and not bool(u.get("captive", false)) and not in_order.has(u.c):
				_fail("%s is crew but not in the Initiative order, %s" % [who, when], "order")
	if crew_up and e.init.order().filter(func(c): return not c.dead).is_empty():
		var up := e.units.filter(func(u): return not u.c.dead).map(func(u): return "%s/%s%s" % [u.c.display_name, e.sides[int(u.team)].ai, "" if u.c.can_act() else " (down)"])
		_fail("the Initiative order is empty while the crew live, %s: %s" % [when, ", ".join(up)], "order-empty")


## Money, IP and storage never negative; no offer pays less than nothing.
## No NET access point within jack-in reach of the deploy zone or a crew start square
## (SceneGen.AP_CLEAR_M, no wall between): the crew infiltrates before it jacks in.
func _check_start(e: Encounter) -> void:
	for cl in SceneGen.deploy_ap_clashes(e.m):
		_fail("deploy square %s is in jack-in reach of the access point at %s" % [cl[0], cl[1]], "ap-deploy")
	var los := Los.new(e.m)
	var aps := SceneGen.access_point_cells(e.m)
	for u in e.units:
		if u.team == Encounter.CREW and SceneGen.any_jack_reach(los, [u.pos], aps):
			_fail("%s starts in jack-in reach of an access point at %s" % [u.c.display_name, u.pos], "ap-start")


## A tower gig (TowerGen) built as one: its band's map, the floors named by storey, the crew in the
## lift lobby with the lift car among their squares, and arrival points (the lift and the fire stair)
## for responders.
func _check_tower(camp: Campaign, e: Encounter) -> void:
	var m := e.m
	if not m.is_tower() or String(m.tower.get("location", "")) != String(camp.active_gig.tower):
		_fail("tower gig %s built as no tower" % camp.active_gig.tower, "tower")
		return
	var b: Dictionary = m.bands[0]
	if m.floor_name(int(b.from_floor)) != str(int(b.storey_from)):
		_fail("the band's lowest floor is named %s, not storey %d" % [m.floor_name(int(b.from_floor)), int(b.storey_from)], "tower-storey")
	var car := TowerGen.car(m)
	var dep: Array = SceneGen.deploy_cells(m)
	if car.is_empty() or not dep.has(Vector3i(car.pos.x, car.pos.y, m.street)):
		_fail("the crew does not start in the lift car", "tower-deploy")
	for u in e.units:
		if u.team == Encounter.CREW:
			var l := m.label(u.pos.z, u.pos.x, u.pos.y)
			if l < 0 or String(m.rooms[l].kind) != "lift_lobby":
				_fail("%s starts outside the lift lobby" % u.c.display_name, "tower-deploy")
	if not m.entrances.any(func(en): return String(en.get("arrival", "")) == "lift") or not m.entrances.any(func(en): return String(en.get("arrival", "")) == "stairs"):
		_fail("the band has no lift or fire-stair arrival point", "tower-arrival")


func _check_campaign(camp: Campaign, when: String) -> void:
	if camp.eb < 0:
		_fail("eb %d %s" % [camp.eb, when], "eb")
	for c in camp.crew:
		if c.ip < 0:
			_fail("%s has %d IP %s" % [c.display_name, c.ip, when], "ip")
	for k in camp.stash:
		if int(camp.stash[k]) < 0:
			_fail("storage holds %d of %s %s" % [int(camp.stash[k]), k, when], "stash")
	for g in camp.board:
		if int(g.get("pay", 0)) < 0:
			_fail("an offer pays %d" % int(g.pay), "offer-pay")
		# The Mission Builder's offer (MissionBuilder): a playable mission of the job's objective,
		# a focus it can play, the eb part of its payment as its pay, no twist yet.
		var m: Dictionary = g.get("mission", {}) if g.get("mission") is Dictionary else {}
		if m.is_empty() or not MissionBuilder.enabled(MissionBuilder.mission_def(String(m.get("id", "")))) or String(m.get("objective", "")) != Campaign.objective_for(g):
			_fail("offer %s: mission %s doesn't play as its objective" % [g.get("title", "?"), m.get("id", "none")], "offer-mission")
		var f: Dictionary = g.get("focus", {}) if g.get("focus") is Dictionary else {}
		if f.is_empty() or not MissionBuilder.fits(MissionBuilder.focus_def("%s/%s" % [f.get("category", ""), f.get("id", "")]), Campaign.objective_for(g)):
			_fail("offer %s: focus %s doesn't fit the objective" % [g.get("title", "?"), f.get("id", "none")], "offer-focus")
		if not g.get("payment") is Dictionary or int(g.payment.get("eb", -1)) != int(g.get("pay", 0)) or g.get("twist") != null:
			_fail("offer %s: payment or twist out of shape" % g.get("title", "?"), "offer-payment")
	if camp.intel < 0 or camp.favours.any(func(x): return not String(x.get("kind", "")) in MissionBuilder.FAVOURS):
		_fail("intel %d or a favour out of shape %s" % [camp.intel, when], "tokens")


## Save, load, and compare: the reloaded campaign's to_dict must be the saved one's, and it must
## roll the same next.
func _round_trip(camp: Campaign, tag: int) -> Campaign:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := "%s/soak_%d_%d.json" % [SAVE_DIR, OS.get_process_id(), tag]
	var before := camp.to_dict()
	if not camp.save(path):
		_fail("save failed")
		return camp
	var back := Campaign.load_from(path)
	DirAccess.remove_absolute(path)
	if back == null:
		_fail("the save didn't load")
		return camp
	var a := JSON.stringify(before, "", true)
	var b := JSON.stringify(back.to_dict(), "", true)
	if a != b:
		_fail("save round trip differs: %s" % _first_diff(a, b), "roundtrip")
	if back.dice.rng.state != camp.dice.rng.state:
		_fail("the reloaded dice state differs (%d vs %d)" % [back.dice.rng.state, camp.dice.rng.state], "rng")
	return back


static func _first_diff(a: String, b: String) -> String:
	var i := 0
	while i < mini(a.length(), b.length()) and a[i] == b[i]:
		i += 1
	return "…%s… vs …%s…" % [a.substr(maxi(0, i - 80), 140), b.substr(maxi(0, i - 80), 140)]


func _fail(msg: String, key := "") -> void:
	var k: String = key if key != "" else msg
	if _seen_fail.has(k):
		return
	_seen_fail[k] = true
	failures.append("%s: %s" % [_ctx, msg])


func _count(group: String, key: String) -> void:
	var d: Dictionary = stats[group]
	d[key] = int(d.get(key, 0)) + 1
