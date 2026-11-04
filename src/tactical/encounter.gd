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

var m: TacMap
var dice: Dice
var nav: Nav
var los: Los
var init: Initiative
var units: Array[Dictionary] = []   ## {id, c, pos: Vector3i, team (a side: see `sides`), alerted}
## Sides in this encounter, indexed by a unit's `team`. Each is a World faction playing a part:
## {faction, ai: crew|guard|captive|civilian|trauma, opfor: counts as the opposition to beat}.
## The first five are always there (CREW, OPFOR, CAPTIVE, CIV_TEAM, TT_TEAM); responders and
## third parties (NCPD, MaxTac, a rival gang) get their own side when they turn up. Who fights
## whom comes from World.relation, never from comparing team numbers.
var sides: Array[Dictionary] = []
var _rel := {}                      ## Vector2i(a, b) → "hostile" | "neutral" | "ally" (both orders)
var opfor_faction := World.DEFAULT_OPFOR   ## the gig's target faction: whose guards these are
var doctrine: Dictionary = {}       ## how they guard and answer trouble (Security.doctrine: data/world/security.json)
var cur: Dictionary = {}
var turn: TurnState
var log: Array[String] = []
var state := "playing"              ## playing | won | lost
var runs := {}                      ## unit id → NetRun
var net_left := 0                   ## NET Actions left this turn (runner only)
var _slid_this_turn := false
var _ice_round := -1
var _met_memory := {}               ## unit id → ICE met this gig: re-jacking doesn't re-ambush (playtest Giant loop)
var _netting := false               ## this turn went to the NET (the meat Action is forgone, p197)
var objective := {}                 ## the objective's state: {kind, done, + per-kind fields} (obj.o)
var obj: Objective                  ## the gig's goal as a module (src/tactical/objectives/)
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


## opts: {faction: the gig's target faction id (World), default generic private security}.
static func setup(p_map: TacMap, p_dice: Dice, crew: Array[Combatant], kind := "data", p_twists: Array = [], opts: Dictionary = {}) -> Encounter:
	var e := Encounter.new()
	e.twists = p_twists.duplicate()
	e.opfor_faction = String(opts.get("faction", World.DEFAULT_OPFOR))
	if not World.has_faction(e.opfor_faction):
		e.opfor_faction = World.DEFAULT_OPFOR
	e._init_sides()
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
	var site := ""
	for st in p_map.structures:
		if st.target:
			site = String(st.get("site", ""))
	e.doctrine = Security.for_site(e.opfor_faction, site, String(p_map.params.get("scene", "")))
	var posts := p_map.posts.duplicate()
	posts.sort_custom(func(a, b): return int(a.structure == target_sid) > int(b.structure == target_sid))
	var sec := mini(3, int(p_map.params.get("security", 1)) + (1 if "heavy" in p_twists else 0))
	var roster := Security.roster(e.doctrine, crew.size(), sec)   # CPR p399 budget, strongest first (target building posts)
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
		var g := World.npc(p_dice, e.opfor_faction, tier, i + 1)
		e._add(g, Vector3i(posts[i].pos.x, posts[i].pos.y, posts[i].floor), OPFOR)
	# Objective: a module per kind (data/gen/objectives.json) places what the job needs.
	e.obj = Objective.make(kind, e)
	e.objective = e.obj.o
	e.obj.setup(target_sid, cells[0], sec)
	if "setup" in p_twists:   # HOUSE-RULE: a fixer sold the crew out; the guards are waiting
		for u in e.units:
			if u.team == OPFOR:
				u.alerted = true
		e.alarm = 1
		e.say("It's a setup. They knew you were coming.")
	# M3 playtest verdict: guards only join the initiative order once they're alerted.
	for u in e.units:
		if u.alerted:
			e.init.add(u.c)
	e.vision = Vision.new(p_map, e.los)
	e._compute_light()
	e._outer_patrols(cells[0])
	e._post_guards()
	if bool(e.doctrine.get("keycards", true)):
		e._hand_out_keycards()
	e._trauma_cards()
	e._place_civilians(cells[0])
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


# --- Sides and relations ---------------------------------------------------------------

const CREW := 0
const OPFOR := 1
const CAPTIVE := 2


func _init_sides() -> void:
	sides.clear()
	_rel.clear()
	add_side("crew", "crew", false)                  # CREW
	add_side(opfor_faction, "guard", true)           # OPFOR: the gig's target, hostile to the crew
	add_side("captive", "captive", false)            # CAPTIVE (rescue)
	add_side("bystanders", "civilian", false)        # CIV_TEAM
	add_side("trauma_team", "trauma", false)         # TT_TEAM (responders, neutral until shot)


## A new side for `faction` playing `ai`; returns its team index. Relations to every existing side
## come from World.relation, except that the gig's opposition is always hostile to the crew.
func add_side(faction: String, ai: String, opfor: bool) -> int:
	var t := sides.size()
	sides.append({"faction": faction, "ai": ai, "opfor": opfor})
	for o in t + 1:
		var r := "ally" if o == t else World.relation(faction, String(sides[o].faction))
		if (o == CREW and opfor) or (t == CREW and bool(sides[o].opfor)):
			r = "hostile"
		_rel[Vector2i(t, o)] = r
		_rel[Vector2i(o, t)] = r
	return t


## The side a faction plays `ai` on, added if it isn't here yet (NCPD and MaxTac turning up).
func side_for(faction: String, ai: String, opfor: bool) -> int:
	for t in sides.size():
		if String(sides[t].faction) == faction and String(sides[t].ai) == ai:
			return t
	return add_side(faction, ai, opfor)


func relation(a: int, b: int) -> String:
	return String(_rel.get(Vector2i(a, b), "neutral"))


func set_relation(a: int, b: int, r: String) -> void:
	_rel[Vector2i(a, b)] = r
	_rel[Vector2i(b, a)] = r


func hostile(a: int, b: int) -> bool:
	return relation(a, b) == "hostile"


func allied(a: int, b: int) -> bool:
	return a == b or relation(a, b) == "ally"


## Run by the guard AI (the opposition, police, MaxTac): patrols, spots, raises alarms, fights.
func is_guard(u: Dictionary) -> bool:
	return String(sides[int(u.team)].ai) == "guard"


func faction_of(u: Dictionary) -> String:
	return String(sides[int(u.team)].faction)


## The opposition still standing: what "put every guard down" means (the gig's guards, their
## backup, and police or MaxTac who join in against the crew).
func opfor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in units:
		if bool(sides[int(u.team)].opfor) and not u.c.dead and u.c.wound_state() != Combatant.Wound.MORTAL:
			out.append(u)
	return out


## Everyone still standing who would shoot `u`.
func foes(u: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in units:
		if o != u and hostile(int(u.team), int(o.team)) and not o.c.dead and o.c.wound_state() != Combatant.Wound.MORTAL:
			out.append(o)
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
		if init.round_num != _ice_round:
			_ice_round = init.round_num
			_patrol_ice()
		if "shift_change" in twists and init.round_num >= SHIFT_CHANGE_ROUND and alarm < 2:
			var gs := opfor()
			if not gs.is_empty():
				say("Shift change: the new shift finds the place wrong.")
				_call_it_in(gs[0])
		_tick_backup()
		obj.tick()
		if init.round_num != _civ_round:
			_civ_round = init.round_num
			_civilians_tick()
			_tick_trauma()
		if state != "playing":
			return
		turn = TurnState.begin(dice, c)
		net_left = 0
		_netting = false
		_slid_this_turn = false
		if cur.team == OPFOR and cur.alerted and turn.survived and c.can_act():
			_call_it_in(cur)
		if not turn.survived:
			say("%s fails a Death Save and dies." % c.display_name)
			events.append({"type": "death", "unit": cur.id})   # so the view plays the death, not a snap
		elif c.can_act():
			_ice_turn(cur)
			if cur.has("suppressed_by"):
				_take_cover(cur)
			if String(sides[cur.team].ai) == "trauma":
				AI.trauma(self, cur)
				end_turn()
				continue
			if cur.get("captive", false):   # a freed captive follows the crew on their own
				AI.follow(self, cur)
				end_turn()
				continue
			if is_guard(cur) or turn.psychotic:
				AI.act(self, cur)
				end_turn()
				continue
			if runs.has(cur.id) and turn.action_available:   # no Action this turn (e.g. Spinal Injury): no NET either
				net_left = net_actions_for(c)
				var r0: NetRun = runs[cur.id]
				if r0.wisp > 0:   # Wisp (p207): -1 NET Action this turn, never below 2
					net_left = maxi(mini(2, net_left), net_left - r0.wisp)
					r0.wisp = 0
			if runs.has(cur.id):
				var r1: NetRun = runs[cur.id]
				r1.no_deeper = r1.kraken_until >= init.round_num
			return
		_check_end()


func end_turn() -> void:
	if turn != null and not cur.is_empty() and cur.team == 0 and alarm < 2 and init.round_num != _patrol_round:
		_patrol_round = init.round_num   # once a round, not once per crew member
		patrol_step()
	if turn != null and not cur.is_empty() and cur.c.burning > 0:   # on fire: Hellhound (p207), flamethrower (p348)
		if not _netting and not turn.action_available:   # spent the meat Action beating it out
			cur.c.burning = 0
			say("%s puts out the fire." % cur.c.display_name)
		else:
			var b0: int = cur.c.wound_state()
			cur.c.hp -= cur.c.burning
			events.append({"type": "harm", "unit": cur.id, "damage": cur.c.burning, "source": "BURNING", "wound_before": b0, "wound_after": cur.c.wound_state()})
	if turn != null and not cur.is_empty():   # knocked-out cyberware comes back a round at a time
		for cid in cur.c.cyber_off.keys():
			cur.c.cyber_off[cid] = int(cur.c.cyber_off[cid]) - 1
			if int(cur.c.cyber_off[cid]) <= 0:
				cur.c.cyber_off.erase(cid)
		for inj in cur.c.injuries.duplicate():   # a flashbang's or teargas's injuries last a minute (p.346-347)
			if inj.has("expires_in"):
				inj.expires_in = int(inj.expires_in) - 1
				if int(inj.expires_in) <= 0:
					cur.c.injuries.erase(inj)
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
	_count_civ_harm()
	_watch_cardholders()
	if int(tt.get("carrier", -1)) >= 0 and not units[int(tt.carrier)].c.can_act():   # the carrier went down: the patient drops
		var pt: Dictionary = units[int(tt.patient)]
		pt.erase("carried")
		pt.pos = units[int(tt.carrier)].pos
		tt.carrier = -1
	obj.before_check()
	if units.filter(func(u): return u.team == 0 and u.c.can_act()).is_empty() \
			and units.filter(func(u): return u.team == 0 and not u.c.dead and u.c.wake_in > 0).is_empty():
		state = "lost"   # nobody on the crew can act or will wake up (the loop would otherwise spin)
		return
	var r := obj.check_end()
	if r != "":
		state = r


# --- Locks: bypass and keycards -----------------------------------------------------------

## Electronics/Security Tech vs the lock (CPR p209: devices off the NET are countered with the
## skill; DVs by the site's security are ours, RULES-UNVERIFIED). Missing by 5+ makes noise.
const BYPASS_DV := {0: 13, 1: 13, 2: 15, 3: 17}
var keycards := {}                  ## lock zone → true: the crew holds that zone's keycard


## A locked door next to `u` (same floor, including diagonals), or (-1,-1,-1).
func lock_in_reach(u: Dictionary) -> Vector3i:
	for cell in nav.locked:
		if cell.z == u.pos.z and maxi(absi(cell.x - u.pos.x), absi(cell.y - u.pos.y)) <= 1:
			return cell
	return Vector3i(-1, -1, -1)


func bypass_dv(cell: Vector3i) -> int:
	var sec := 1
	for d in m.devices:
		if String(d.type) == "door_lock" and d.floor == cell.z and d.pos == Vector2i(cell.x, cell.y):
			sec = int(m.structures[int(d.structure)].security) if int(d.get("structure", -1)) >= 0 else 1
	return int(BYPASS_DV.get(clampi(sec, 0, 3), 15))


func bypass_base(c: Combatant) -> int:
	return c.skill_base("electronics_security_tech") + int(c.maker.get("field", 0)) - c.action_penalty()


func bypass_lock() -> Dictionary:
	var cell := lock_in_reach(cur)
	if cell.x < 0:
		return {"ok": false, "reason": "no locked door next to you"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	var dv := bypass_dv(cell)
	var check := Check.vs_dv(dice, bypass_base(cur.c), dv)
	var loud := not check.success and check.total <= dv - 5
	if check.success:
		_unlock(cell)
	elif loud:
		_noise(cur.pos)
	events.append({"type": "bypass", "unit": cur.id, "cell": cell, "ok": check.success, "loud": loud})
	say("%s %s the lock%s." % [cur.c.display_name, "bypasses" if check.success else "fails to bypass", " and sets off a buzzer" if loud else ""])
	return {"ok": true, "success": check.success, "loud": loud}


func _unlock(cell: Vector3i) -> void:
	nav.locked.erase(cell)
	for d in m.devices:
		if String(d.type) == "door_lock" and d.floor == cell.z and d.pos == Vector2i(cell.x, cell.y):
			disabled_devices[d.id] = true


## One guard per locked zone carries its keycard: the highest-tier guard posted in that zone's
## building, else any guard.
func _hand_out_keycards() -> void:
	var zones := {}
	for d in m.devices:
		if String(d.type) == "door_lock":
			zones[int(d.zone)] = int(d.get("structure", -1))
	var given := {}
	var rank := {"mini_boss": 3, "lieutenant": 2, "mook": 1}
	for z in zones:
		var best: Dictionary = {}
		for g in units:
			if g.team != OPFOR or given.has(g.id):
				continue
			var l := m.label(g.pos.z, g.pos.x, g.pos.y)
			var here: bool = l >= 0 and m.rooms[l].structure == zones[z]
			var score: int = int(rank.get(g.c.role, 1)) * 10 + (5 if here else 0)
			if best.is_empty() or score > int(best.get("_score", -1)):
				best = g
				best["_score"] = score
		if not best.is_empty():
			best.erase("_score")
			best["keycard"] = maxi(int(best.get("keycard", -1)), z)
			given[best.id] = true
	for g in units:
		g.erase("_score")


## A downed guard next to `u` still holding a keycard.
func keycard_in_reach(u: Dictionary) -> Dictionary:
	for g in units:
		if g.has("keycard") and (g.c.dead or g.c.unconscious or g.c.wound_state() == Combatant.Wound.MORTAL) and adjacent(u.pos, g.pos) and g.pos.z == u.pos.z:
			return g
	return {}


## Take a keycard off a downed guard (an Action): every lock of that zone or below opens.
func loot_keycard() -> Dictionary:
	var g := keycard_in_reach(cur)
	if g.is_empty():
		return {"ok": false, "reason": "no keycard on anyone next to you"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	var z: int = g.keycard
	g.erase("keycard")
	keycards[z] = true
	var opened := 0
	for d in m.devices:
		if String(d.type) == "door_lock" and int(d.zone) <= z:
			var cell := Vector3i(d.pos.x, d.pos.y, d.floor)
			if nav.locked.has(cell):
				_unlock(cell)
				opened += 1
	events.append({"type": "keycard", "unit": cur.id, "from": g.id, "zone": z, "opened": opened})
	say("%s takes a %s keycard: %d door%s unlocked." % [cur.c.display_name, TacMap.ZONE_NAMES[z], opened, "" if opened == 1 else "s"])
	return {"ok": true, "opened": opened}


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
		if u.get("captive", false):
			continue
		u.c.dead = true
		say("%s is left behind." % u.c.display_name)
	if obj.withdraw_wins():
		state = "won"   # the hit is done: leaving is the rest of the job
		say("The crew pulls out. The job's done.")
		return true
	state = "fled"
	say("The crew pulls out.")
	return true


# --- Objective helpers ------------------------------------------------------------------------

## Every crew member still standing is in the extraction zone.
func _crew_out() -> bool:
	var up := units.filter(func(u): return u.team == 0 and not u.get("captive", false) and u.c.can_act())
	return not up.is_empty() and up.all(func(u): return extract_cells.has(u.pos))


## The mark reached an exit (assassination: the AI calls this).
func _vip_escapes(u: Dictionary) -> void:
	if obj.has_method("escape"):
		obj.escape(u)


## Crew actions the objective offers the active unit now ("grab", "free", "plant").
func obj_actions() -> Array[String]:
	return obj.actions() if state == "playing" else []


func obj_act(action: String) -> Dictionary:
	return obj.act(action)


func can_grab() -> bool:
	return "grab" in obj_actions()


func grab() -> Dictionary:
	return obj.act("grab")


func can_free() -> bool:
	return "free" in obj_actions()


func free_captive() -> Dictionary:
	return obj.act("free")


func can_plant() -> bool:
	return "plant" in obj_actions()


func plant_charge() -> Dictionary:
	return obj.act("plant")


## Rounds until a planted charge goes off (sabotage), or -1.
func fuse_left() -> int:
	return obj.fuse_left() if obj.has_method("fuse_left") else -1


func _tick_fuse() -> void:
	obj.tick()


## Replace the objective (review reels stage one by hand).
func set_objective(kind: String, fields: Dictionary) -> void:
	obj = Objective.make(kind, self)
	obj.o.merge(fields, true)
	objective = obj.o


# --- Civilians, Trauma Team, MaxTac ---------------------------------------------------------

const CIV_TEAM := 3
const TT_TEAM := 4
const TT_ROUNDS := 2              ## HOUSE-RULE: Trauma Team lands two rounds after a cardholder goes down
var civ_casualties := 0
var tt_hostile := false             ## someone on the crew shot at Trauma Team: they shoot back
var tt := {}                        ## the Trauma Team call: {patient, round, av, units, carrier, state}
var _civ_round := -1
var _counted := {}


## Civilians (HOUSE-RULE): bystanders in the public rooms and on the street, more where people
## gather (bars, clubs, markets), few in the badlands or the tunnels. They take no turns: each round
## the ones that have panicked run for the map edge. Hurting one costs the crew rep and heat.
func _place_civilians(deploy: Vector2i) -> void:
	var scene := String(m.params.get("scene", ""))
	if scene in ["badlands", "undercity"]:
		return
	var cand: Array = []
	for y in m.h:
		for x in m.w:
			var v := Vector3i(x, y, 0)
			if not m.walkable(0, Vector2i(x, y)) or occupied().has(v) or Vector2(x - deploy.x, y - deploy.y).length() < 10:
				continue
			var l := m.label(0, x, y)
			var ok := false
			if l >= 0:
				var r: Dictionary = m.rooms[l]
				ok = int(r.zone) == TacMap.Zone.PUBLIC and String(r.kind) not in ["roof", "corridor"]
			else:
				ok = m.t(0, x, y) == TacMap.T.OUTSIDE and m.ground[y * m.w + x] == TacMap.G.SIDEWALK
			if ok:
				cand.append(v)
	if cand.is_empty():
		return
	var n := clampi(int(m.w * m.h / 650.0) + (3 if scene == "arcology" else 0), 3, 12)
	var placed: Array = []
	for k in n * 6:
		if placed.size() >= n:
			break
		var v: Vector3i = cand[dice.d(cand.size()) - 1]
		if placed.any(func(q): return Vector2(q.x - v.x, q.y - v.y).length() < 4.0):
			continue
		var c := Recruit.generate(dice, ["media", "fixer", "exec", "rockerboy", "tech"][dice.d(5) - 1], "edgerunner", "Bystander")
		c.weapons.clear()
		c.faction = "bystanders"
		_add(c, v, CIV_TEAM)
		var u: Dictionary = units[-1]
		u.alerted = false
		u["civ"] = true
		u["panic"] = false
		placed.append(v)


func _panic_near(at: Vector3i) -> void:
	var fresh := []
	for u in units:
		if u.get("civ", false) and not u.panic and not u.c.dead and Vector2(at.x - u.pos.x, at.y - u.pos.y).length() <= GUNFIRE_RANGE:
			u.panic = true
			fresh.append(u.id)
	if not fresh.is_empty():
		events.append({"type": "panic", "unit": fresh[0], "units": fresh})


## Panicked bystanders run (up to 10 squares a round) for the nearest map exit and are gone there.
func _civilians_tick() -> void:
	var exits: Array = []
	for en in m.entrances:
		if m.walkable(int(en.get("floor", 0)), en.pos):
			exits.append(Vector3i(en.pos.x, en.pos.y, int(en.get("floor", 0))))
	if exits.is_empty():
		return
	var field: Dictionary = nav.distance_field(exits, {}, 4000)
	for u in units:
		if not u.get("civ", false) or not u.panic or u.c.dead or not u.c.can_act():
			continue
		var reach: Dictionary = nav.reachable(u.pos, 10, occupied(u))
		var best: Vector3i = u.pos
		for cell in reach:
			if int(field.get(cell, 9999)) < int(field.get(best, 9999)) and not occupied(u).has(cell):
				best = cell
		if best != u.pos:
			var path: Array[Vector3i] = nav.path(u.pos, best, occupied(u))
			var full: Array = [u.pos]
			full.append_array(path)
			u.pos = best
			events.append({"type": "move", "unit": u.id, "path": full, "run": true})
		if int(field.get(u.pos, 9999)) == 0:
			u.c.dead = true   # gone off the map, unharmed
			u["fled"] = true
			events.append({"type": "civ_gone", "unit": u.id})


func _count_civ_harm() -> void:
	for u in units:
		if u.get("civ", false) and not u.get("fled", false) and not _counted.has(u.id) and (u.c.dead or not u.c.can_act()):
			_counted[u.id] = true
			civ_casualties += 1
			say("A bystander is down. That will cost you.")


## Trauma Team subscribers: the mark on an assassination, and a Lieutenant or Mini Boss at corp sites
## half the time (HOUSE-RULE).
func _trauma_cards() -> void:
	var tc: Dictionary = doctrine.get("trauma_cards", {})
	var p := float(tc.get("officers", 0.0))
	for u in units:
		if u.team != OPFOR:
			continue
		if u.get("vip", false):
			if bool(tc.get("mark", false)):
				u["trauma_card"] = true
		elif String(u.c.role) in ["lieutenant", "mini_boss"] and p > 0.0:
			u["trauma_card"] = p >= 1.0 or dice.rng.randf() < p


## A cardholder going down (alive) calls Trauma Team, who land TT_ROUNDS rounds later.
func _watch_cardholders() -> void:
	if not tt.is_empty():
		return
	for u in units:
		if u.get("trauma_card", false) and not u.c.dead and not u.c.can_act():
			tt = {"patient": u.id, "round": init.round_num + TT_ROUNDS, "state": "called"}
			events.append({"type": "tt_call", "unit": u.id})
			say("%s's Trauma Team card pings. An AV is on its way." % u.c.display_name)
			return


func _tick_trauma() -> void:
	if tt.get("state", "") != "called" or init.round_num < int(tt.round):
		return
	var patient: Dictionary = units[int(tt.patient)]
	if patient.c.dead:
		tt.state = "cancelled"
		return
	var spot := av_spot(patient.pos, 2, 30)
	if spot.x < 0:
		tt.state = "cancelled"
		return
	var ids := _responders("trauma_team", TT_TEAM, _av_exits(spot, 3), 3)
	for id in ids:
		units[id]["tt"] = true
	tt.merge({"state": "landed", "av": spot, "av_fit": av_fit.duplicate(), "units": ids, "carrier": -1}, true)
	events.append({"type": "av_land", "unit": ids[0] if not ids.is_empty() else 0, "kind": "trauma", "cell": spot, "units": ids, "yaw": av_fit.yaw, "scale": av_fit.scale})
	say("Trauma Team lands. Stay out of their way.")


## Trauma Team got the patient aboard: everyone climbs in and the AV lifts off.
func tt_depart() -> void:
	for id in tt.get("units", []):
		units[id].c.dead = true
		units[id]["fled"] = true
	var patient: Dictionary = units[int(tt.patient)]
	patient.c.dead = true
	patient["fled"] = true
	patient["extracted"] = true
	tt.state = "gone"
	events.append({"type": "av_leave", "unit": int(tt.patient), "kind": "trauma", "cell": tt.av})
	say("The Trauma Team AV lifts off with %s." % patient.c.display_name)
	obj.on_evacuated(int(tt.patient))


## MaxTac (HOUSE-RULE stats, RULES-UNVERIFIED against the book's MaxTac block): four operatives,
## Mini Boss stats, heavy armour and assault rifles, dropped by AV near the crew.
func _maxtac_drop() -> void:
	var crew := alive(0)
	if crew.is_empty():
		return
	var spot := av_spot(crew[0].pos, 6, 40)
	if spot.x < 0:
		_ncpd_wave()
		return
	var ids := _responders("maxtac", side_for("maxtac", "guard", true), _av_exits(spot, 3), 4)
	for id in ids:
		units[id]["maxtac"] = true
	events.append({"type": "av_land", "unit": ids[0] if not ids.is_empty() else 0, "kind": "maxtac", "cell": spot, "units": ids, "yaw": av_fit.yaw, "scale": av_fit.scale})
	say("MaxTac drops in. This just became a very bad night.")


## Where an AV sets down: the open ground nearest `near` (between lo and hi squares away). The
## craft is about 5 m wide and 7 m long, so it lands square to the grid on a clear 5x7 patch
## (either way round) and records which way it faces in `av_fit`; failing that it lands on a 5x5
## or 3x3 patch at a smaller scale rather than clip into the buildings. Spots with a multi-storey
## building toward the default camera (+x +y, greybox cam_yaw 45°) count as farther, so the
## landing is seen. Returns (-1, -1, -1) if nowhere fits.
const AV_FITS := [[2, 3, 0.0, 1.0], [3, 2, PI / 2.0, 1.0], [2, 2, 0.0, 0.75], [1, 1, 0.0, 0.55]]   ## [half x, half y, yaw, scale]
const AV_HIDDEN_COST := 25.0           ## squares a hidden landing counts as farther

var av_fit := {"yaw": 0.0, "scale": 1.0}   ## how the last av_spot landing faces and scales


func av_spot(near: Vector3i, lo: int, hi: int) -> Vector3i:
	var occ := occupied()
	var best: Array = [Vector3i(-1, -1, -1), INF]
	for i in AV_FITS.size():
		var f: Array = AV_FITS[i]
		var got := _av_clearing(near, lo, hi, int(f[0]), int(f[1]), occ)
		if float(got[1]) < float(best[1]):
			best = got
			av_fit = {"yaw": float(f[2]), "scale": float(f[3])}
		if i == 1 and best[0].x >= 0:   # a full-size fit either way round beats any smaller one
			break
		if i >= 2 and best[0].x >= 0:
			break
	return best[0]


func _av_hidden(x: int, y: int) -> bool:
	if m.floors < 2:
		return false
	for k in range(2, 9):   # a wedge toward the camera, about 25° either side
		for c in [Vector2i(x + k, y + k), Vector2i(x + k, y + k / 2), Vector2i(x + k / 2, y + k)]:
			if m.inb(c.x, c.y) and m.t(1, c.x, c.y) in [TacMap.T.FLOOR, TacMap.T.WALL, TacMap.T.DOOR, TacMap.T.STAIRS]:   # a second storey
				return true
	return false


## The best clear (2rx+1) x (2ry+1) patch: [centre, score], score INF if none.
func _av_clearing(near: Vector3i, lo: int, hi: int, rx: int, ry: int, occ: Dictionary) -> Array:
	var best := Vector3i(-1, -1, -1)
	var bd := INF
	for y in range(ry, m.h - ry):
		for x in range(rx, m.w - rx):
			var d := Vector2(x - near.x, y - near.y).length()
			if d < lo or d > hi or d >= bd:
				continue
			if _av_hidden(x, y):
				d += AV_HIDDEN_COST
				if d >= bd:
					continue
			var ok := true
			for dy in range(-ry, ry + 1):
				for dx in range(-rx, rx + 1):
					var v := Vector2i(x + dx, y + dy)
					if m.t(0, v.x, v.y) != TacMap.T.OUTSIDE or m.label(0, v.x, v.y) >= 0 or not m.walkable(0, v) or occ.has(Vector3i(v.x, v.y, 0)):
						ok = false
						break
				if not ok:
					break
			if ok:
				bd = d
				best = Vector3i(x, y, 0)
	return [best, bd]


## Where the people aboard an AV at `c` step out: beside the side doors (square to the craft's
## heading), clear of its hull and pods.
func _av_exits(c: Vector3i, n: int) -> Array:
	var side := Vector2i(1, 0) if is_zero_approx(float(av_fit.yaw)) else Vector2i(0, 1)
	var along := Vector2i(side.y, side.x)
	var reach := 3 if float(av_fit.scale) >= 1.0 else 2
	var out: Array = []
	for dist in [reach, reach + 1]:
		for off in [0, 1, -1]:
			for sgn in [1, -1]:
				var d: Vector2i = side * dist * sgn + along * off
				var v := c + Vector3i(d.x, d.y, 0)
				if m.inb(v.x, v.y) and m.walkable(0, Vector2i(v.x, v.y)) and not occupied().has(v) and not out.has(v):
					out.append(v)
				if out.size() >= n + 1:
					return out
	for v in _around(c, n):   # cramped landing: fill up from the squares beside it
		if out.size() >= n + 1:
			break
		if not out.has(v):
			out.append(v)
	return out


func _around(c: Vector3i, n: int) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var v := c + Vector3i(d.x, d.y, 0)
		if m.walkable(0, Vector2i(v.x, v.y)) and not occupied().has(v):
			out.append(v)
		if out.size() >= n + 1:
			break
	return out


# --- Explosions -----------------------------------------------------------------------------

## A big explosion at `center`: cover in the square breaks first, then everyone in it with a line to
## the blast takes the damage (dodge as for grenades, against a fixed DV-like total: HOUSE-RULE 17).
func _detonate(center: Vector3i, half: int, n_dice: int, by: int, total := 17) -> void:
	var faces := dice.roll_each(n_dice, 6)
	var dmg := 0
	for f in faces:
		dmg += f
	var destroyed: Array = []
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var v := center + Vector3i(dx, dy, 0)
			if los.cover_hp.get(v, 0) > 0:
				los.cover_hp[v] = maxi(0, los.cover_hp[v] - dmg)
				if los.cover_hp[v] == 0 or v == center:
					los.cover_hp[v] = 0
					m.destroy_cover_at(v.z, Vector2i(v.x, v.y))
					destroyed.append(v)
	var caught: Array = []
	for o in units:
		if o.c.dead or o.pos.z != center.z or maxi(absi(o.pos.x - center.x), absi(o.pos.y - center.y)) > half:
			continue
		if o.pos != center and not los.trace(center, o.pos).clear and maxi(absi(o.pos.x - center.x), absi(o.pos.y - center.y)) > 1:
			continue
		caught.append(o)
	var before := {}
	for o in caught:
		before[o.id] = [o.c.hp, o.c.wound_state()]
	var results := Attack.explosion_rolled(dice, total, faces, caught.map(func(o): return o.c))
	_rouse(caught.filter(func(o): return is_guard(o)))
	_noise(center)
	var hits: Array = []
	for res in results:
		var u := unit_of(res.target)
		hits.append({"id": u.id, "dodged": res.dodged, "damage": int(before[u.id][0]) - u.c.hp, "dead": u.c.dead,
			"killed": u.c.dead or u.c.wound_state() == Combatant.Wound.MORTAL, "wound_before": before[u.id][1], "wound_after": u.c.wound_state()})
	events.append({"type": "blast", "unit": by, "cell": center, "center": center, "hit": true, "damage": dmg, "hits": hits,
		"destroyed": destroyed, "charge": true, "half": half})


# --- Placement ---------------------------------------------------------------------------

## The objective's square (the package, the mark, the captive, the machine): indoors in the target
## building's most secure zone, as far from the deploy zone as walking gets (upper floors count
## through the distance field), off guard posts and cover.
func secure_cell(target_sid: int, origin: Vector2i) -> Vector3i:
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


# --- Alerts ------------------------------------------------------------------------

## Guards who can see a crew member (clear sight, within SPOT_RANGE) are alerted; every newly
## alerted guard shouts, rousing guards near it. Newly alerted guards roll Initiative and slot in
## (Initiative.add keeps the current turn). Returns the units alerted by this call.
func update_alerts() -> Array:
	var fresh := []
	for g in units:
		if g.alerted or g.c.dead or not is_guard(g) or not hostile(int(g.team), CREW):
			continue
		for u in alive(0):
			if _spots(g, u):
				fresh.append(g)
				say("%s spots %s!" % [g.c.display_name, u.c.display_name])
				break
	var cam_guard := _camera_spots()
	if not cam_guard.is_empty() and cam_guard not in fresh:
		fresh.append(cam_guard)
	_rouse(fresh)
	return fresh


## The nearest live camera close enough to tamper with (3 squares, same floor, no wall between).
func camera_in_reach(u: Dictionary) -> Dictionary:
	var best := {}
	for d in m.devices:
		if String(d.type) != "camera" or disabled_devices.has(d.id) or int(d.floor) != u.pos.z:
			continue
		var cp := Vector3i(d.pos.x, d.pos.y, d.floor)
		if maxi(absi(cp.x - u.pos.x), absi(cp.y - u.pos.y)) <= 3 and not _wall_between(u.pos, cp):
			best = d
	return best


## Kill a camera by hand (p209): an Action, TECH + Electronics/Security Tech vs DV13. A fail
## leaves it running.
func tamper_camera() -> Dictionary:
	var d := camera_in_reach(cur)
	if d.is_empty():
		return {"ok": false, "reason": "no live camera within 3 squares"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	var check := Check.vs_dv(dice, cur.c.skill_base("electronics_security_tech") - cur.c.action_penalty(), CAMERA_TAMPER_DV)
	if check.success:
		disabled_devices[d.id] = true
	events.append({"type": "tamper", "unit": cur.id, "device": d.id, "ok": check.success})
	say("%s %s a camera." % [cur.c.display_name, "kills" if check.success else "fumbles with"])
	return {"ok": true, "success": check.success}


var _cam_facing := {}

## Which way a camera points: into the open space around its mount (away from walls).
func camera_facing(d: Dictionary) -> Vector2:
	if _cam_facing.has(d.id):
		return _cam_facing[d.id]
	var f := Vector2.ZERO
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and m.inb(d.pos.x + dx, d.pos.y + dy) and m.walkable(int(d.floor), Vector2i(d.pos.x + dx, d.pos.y + dy)):
				f += Vector2(dx, dy).normalized()
	_cam_facing[d.id] = f.normalized() if f.length() > 0.3 else Vector2.ZERO
	return _cam_facing[d.id]


## Does camera `d` see square `v` (range, cone, no wall between)?
func camera_sees(d: Dictionary, v: Vector3i) -> bool:
	var cp := Vector3i(d.pos.x, d.pos.y, d.floor)
	var off := Vector2(v.x - cp.x, v.y - cp.y)
	if v.z != cp.z or off.length() > CAMERA_RANGE or off.length() < 0.5:
		return false
	var f := camera_facing(d)
	if f != Vector2.ZERO and rad_to_deg(absf(f.angle_to(off))) > CAMERA_HALF_ANGLE:
		return false
	return not _wall_between(cp, v)


## Squares a live camera watches (for the stealth overlay).
func camera_cells(d: Dictionary) -> Dictionary:
	var out := {}
	var cp := Vector3i(d.pos.x, d.pos.y, d.floor)
	var r := int(CAMERA_RANGE)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var v := Vector3i(cp.x + dx, cp.y + dy, cp.z)
			if m.inb(v.x, v.y) and m.walkable(v.z, Vector2i(v.x, v.y)) and camera_sees(d, v):
				out[v] = true
	return out


## Security cameras (HOUSE-RULE): a live camera watches its floor within CAMERA_RANGE squares, no
## wall between; whoever minds the feed rolls CAMERA_PERCEPTION (-4 in the dark) vs Stealth, once
## per camera, crew member and round. A hit rouses the nearest unalerted guard. Holding the
## cameras' Control Node in the NET turns them off - the netrunner's job in a stealth gig.
const CAMERA_RANGE := 6.0   ## HOUSE-RULE (playtest: 8 squares caught every approach)
const CAMERA_TAMPER_DV := 13   # RULES-UNVERIFIED: Electronics/Security Tech counters devices (p209), DV not given; "everyday" DV13 (p129)
const CAMERA_HALF_ANGLE := 45.0   ## HOUSE-RULE: a 90° view, pointed away from the wall it's mounted on
const CAMERA_PERCEPTION := 8   ## HOUSE-RULE: a bored guard watching the feeds
func _camera_spots() -> Dictionary:
	if alarm >= 2:
		return {}
	for d in m.devices:
		if String(d.type) != "camera" or disabled_devices.has(d.id):
			continue
		var cp := Vector3i(d.pos.x, d.pos.y, d.floor)
		for u in alive(0):
			if not camera_sees(d, u.pos):
				continue
			var key := ["cam", d.id, u.id, init.round_num if init else 0]
			if not _spot_rolls.has(key):
				var base := CAMERA_PERCEPTION - (0 if lit.has(u.pos) else DARK_PENALTY)
				_spot_rolls[key] = Check.opposed(dice, base, u.c.skill_base("stealth") - u.c.action_penalty()).success
			if _spot_rolls[key]:
				var best: Dictionary = {}
				for g in units:
					if is_guard(g) and hostile(int(g.team), CREW) and not g.alerted and not g.c.dead and (best.is_empty() or Vector3(g.pos - cp).length() < Vector3(best.pos - cp).length()):
						best = g
				if not best.is_empty():
					say("A camera catches %s. %s is on the way." % [u.c.display_name, best.c.display_name])
					events.append({"type": "camera", "unit": best.id, "device": d.id, "target": u.id})
					return best
	return {}


# --- Stealth (M7): facing, light, Perception vs Stealth, patrols, alarm -------------------

const VIEW_HALF_ANGLE := 60.0   ## HOUSE-RULE: a guard watches a 120° cone ahead...
const AWARE_RANGE := 2.0        ## ...but notices anyone within 2 squares, any direction
const DARK_PENALTY := 4         ## "Task obscured by smoke or darkness" (CPR p? task modifiers)
const SHIFT_CHANGE_ROUND := 6    ## HOUSE-RULE twist: the next shift arrives and raises the alarm
## Radio range, backup timing and escalation come from the doctrine (data/world/security.json).


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
## Big maps get patrol pairs outside the target building (HOUSE-RULE, owner-approved after the
## procgen survey: the guard budget was the same on a 30x24 skirmish and a 220x170 district, so big
## maps were empty walks). One pair per ~2500 squares past the first 1500, up to four; Mooks,
## posted far from the deploy zone, every one walking a beat.
func _outer_patrols(deploy: Vector2i) -> void:
	var pairs := Security.patrol_pairs(doctrine, m.w * m.h)
	if pairs == 0:
		return
	var tsid := -1
	for st in m.structures:
		if st.target:
			tsid = st.id
	var field: Dictionary = _keys(func(): return nav.distance_field([Vector3i(deploy.x, deploy.y, 0)], {}, 4000))
	var cand: Array = []
	for v in field:
		var l := m.label(v.z, v.x, v.y)
		if v.z == 0 and int(field[v]) > 16 and (l < 0 or m.rooms[l].structure != tsid) and not m.has_cover_at(0, Vector2i(v.x, v.y)):
			cand.append(v)
	if cand.is_empty():
		return
	var taken: Array = units.map(func(u): return u.pos)
	var n := 0
	for p in pairs:
		var anchor: Vector3i = cand[dice.d(cand.size()) - 1]
		for k in 2:
			var spot := Vector3i(-1, -1, -1)
			for d in ([Vector2i.ZERO] if k == 0 else MapGen.DIRS + [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]):
				var s2 := anchor + Vector3i(d.x, d.y, 0)
				if m.inb(s2.x, s2.y) and m.walkable(s2.z, Vector2i(s2.x, s2.y)) and not (s2 in taken):
					spot = s2
					break
			if spot.x < 0:
				continue
			n += 1
			var g := World.npc(dice, opfor_faction, "mook", n, "Patrol")
			_add(g, spot, OPFOR)
			taken.append(spot)
			units[-1]["outer"] = true


func _post_guards() -> void:
	for g in units:
		if not is_guard(g):
			continue
		var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
		var l := m.label(g.pos.z, g.pos.x, g.pos.y)
		if l >= 0:   # face the middle of the room
			var b: Rect2i = m.rooms[l].bounds
			var to := Vector2(b.position.x + b.size.x / 2.0 - g.pos.x, b.position.y + b.size.y / 2.0 - g.pos.y)
			g.facing = to.normalized() if to.length() > 0.5 else dirs[dice.d(8) - 1]
		else:
			g.facing = dirs[dice.d(8) - 1]
		if dice.d(10) <= 4 or g.get("outer", false):   # ~40% patrol; outer pairs always walk a beat
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
		if not is_guard(g) or g.alerted or g.c.dead or not g.has("patrol"):
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
	backup_in = int(doctrine.backup.rounds)
	# The radio call rouses guards within the doctrine's radio range of the caller: the rest hold posts.
	var radio := float(doctrine.alarm.radio_range)
	_rouse(units.filter(func(o): return is_guard(o) and allied(int(o.team), int(g.team)) and not o.alerted and not o.c.dead and Vector2(o.pos.x - g.pos.x, o.pos.y - g.pos.y).length() <= radio))
	_backup_round = init.round_num
	say("%s calls it in. Backup in %d rounds." % [g.c.display_name, backup_in])
	events.append({"type": "alarm", "unit": g.id, "rounds": backup_in})


func _tick_backup() -> void:
	if ncpd_in > 0 and init.round_num != _ncpd_round:
		_ncpd_round = init.round_num
		ncpd_in -= 1
		if ncpd_in == 0:
			ncpd_in = -2   # once per gig
			if heat >= int(doctrine.escalation.maxtac_heat):
				_maxtac_drop()
			else:
				_ncpd_wave(String(doctrine.escalation.responder))
	if backup_in < 0 or init.round_num == _backup_round:
		return
	_backup_round = init.round_num
	backup_in -= 1
	if backup_in > 0:
		return
	backup_in = -1
	var bk: Dictionary = doctrine.backup
	var sec := int(m.params.get("security", 1)) + (1 if "heavy" in twists else 0)
	var roster: Array[String] = []
	for i in int(bk.per_level) * sec + int(bk.get("extra", 0)):
		roster.append(String(bk.tier))
	_spawn_wave(roster, "BACKUP", OPFOR, opfor_faction, "Backup")
	# Escalation: keep fighting and the city notices, if the site matters or the crew is already
	# wanted (the doctrine's min_security / min_heat; MaxTac instead above maxtac_heat).
	var esc: Dictionary = doctrine.escalation
	if ncpd_in == -1 and (sec >= int(esc.min_security) or heat >= int(esc.min_heat)):
		ncpd_in = maxi(2, int(esc.rounds) - heat / 2)
		_ncpd_round = init.round_num


## Reinforcements enter at the entrance farthest from the crew, alerted and in the initiative order.
## People a faction sends when called (World.responder: Trauma Team, MaxTac), placed on `cells`
## on side `team`, alerted and in the initiative order. Returns their unit ids.
func _responders(fid: String, team: int, cells: Array, cap: int) -> Array:
	var r := World.responder(fid)
	var tiers: Array = r.tiers
	var ids := []
	for i in mini(mini(cap, tiers.size()), cells.size()):
		var g := World.npc(dice, fid, String(tiers[i]), i + 1, String(r.get("rank", "")))
		if r.has("armor"):
			g.armor["body"] = ArmorPiece.from_id(String(r.armor))
			g.armor["head"] = ArmorPiece.from_id(String(r.armor))
		_add(g, cells[i], team)
		var u: Dictionary = units[-1]
		u.alerted = true
		init.add(g)
		ids.append(u.id)
	return ids


## The NCPD answering the escalation: their responder squad, on their own side (World.relation
## decides whether they also go after the guards: police and gangs don't mix).
func _ncpd_wave(fid := "ncpd") -> void:
	var r := World.responder(fid)
	var tiers: Array[String] = []
	for t in r.tiers:
		tiers.append(String(t))
	_spawn_wave(tiers, World.display_name(fid).to_upper(), side_for(fid, "guard", true), fid, String(r.get("rank", "")))


## Reinforcements for side `team` (faction `fid`), named "<rank> <n>".
func _spawn_wave(roster: Array[String], label: String, team: int, fid: String, rank := "") -> void:
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
		var g := World.npc(dice, fid, roster[i], i + 1, rank)
		_add(g, cells[i], team)
		var u: Dictionary = units[-1]
		u.alerted = true
		init.add(g)
		arrived.append(u.id)
	say("%s arrives: %d more." % [label.capitalize(), arrived.size()])
	if not arrived.is_empty():
		events.append({"type": "backup", "unit": arrived[0], "units": arrived, "label": label})


## Gunfire at `at` alerts guards within GUNFIRE_RANGE on any floor.
func _noise(at: Vector3i) -> void:
	_panic_near(at)
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
		if g.alerted or not is_guard(g):   # bystanders panic instead; captives and medics don't fight
			continue
		g.alerted = true
		alarm = maxi(alarm, 1)
		init.add(g.c)
		events.append({"type": "alert", "unit": g.id})
		for o in units:
			if not o.alerted and not o.c.dead and is_guard(o) and allied(int(o.team), int(g.team)) and o.pos.z == g.pos.z \
					and Vector2(o.pos.x - g.pos.x, o.pos.y - g.pos.y).length() <= float(doctrine.alarm.shout_range):
				q.append(o)


func engaged() -> bool:
	return units.any(func(u): return is_guard(u) and hostile(int(u.team), CREW) and u.alerted and not u.c.dead)


# --- Movement ----------------------------------------------------------------------

## Guards carry the keys to their own security doors; the crew needs them hacked or shot open.
func _with_locks(callable: Callable) -> Variant:
	var saved := nav.locked
	if not cur.is_empty() and is_guard(cur):
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
	var opts: Dictionary = _with_locks(func(): return nav.reachable(cur.pos, turn.squares_available(), _blocking(cur)))
	for v in occupied(cur):   # you can pass allies but not stop on them
		opts.erase(v)
	return opts


## Squares that block movement for `u`: other teams' units. HOUSE-RULE (playtest: a Solo in a
## doorway stalled the runner): allies can be passed through, though not stopped on.
func _blocking(u: Dictionary) -> Dictionary:
	var occ := {}
	for o in units:
		if o != u and not o.c.dead and not allied(int(o.team), int(u.team)):
			occ[o.pos] = true
	return occ


## Move along the shortest path. With `allow_run`, a path longer than the remaining move may
## spend the Action on Run (p127/p169: "Take an additional Move Action"), which in the book
## requires a Move Action already taken this turn: the first leg uses it, then Run covers the rest.
func move_to(dest: Vector3i, allow_run := false) -> bool:
	if occupied(cur).has(dest):
		return false
	var p: Array[Vector3i] = _with_locks(func(): return nav.path(cur.pos, dest, _blocking(cur)))
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
		_drop_run(cur.id, true)
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
	if int(target.team) == TT_TEAM and cur.team == CREW:
		tt_hostile = true
		set_relation(TT_TEAM, CREW, "hostile")
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
		"mode": mode, "weapon": weapon.id(), "dead": target.c.dead, "killed": target.c.dead or target.c.wound_state() == Combatant.Wound.MORTAL,
		"jammed": r.get("jammed", false), "no_damage": r.get("no_damage", false), "ignited": r.get("ignited", false),
		"stunned": r.get("stunned", false), "status": r.get("status", {}), "self_hurt": String(r.get("self_hurt", ""))})
	if r.get("jammed", false):
		say("%s's %s jams." % [cur.c.display_name, weapon.display_name()])
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
const FRAG := "ammo/frag_grenade"   ## the plain grenade (HOUSE-RULE kit item; new crews start with some)
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
	for o in foes(cur):
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
	_rouse(cone.filter(func(o): return not allied(int(o.team), int(cur.team))))
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
## The grenade is the one packed in kit slot `slot` (Items: Frag, Armor-Piercing, Incendiary,
## Flashbang, Teargas): its fx ride the blast (ablate 2, ignite, or no damage and a forced check for
## everyone caught, p.345-347).
func throw_grenade(cell: Vector3i, slot := 0) -> Dictionary:
	var why := _kit_ready(slot, "grenade")
	if why != "":
		return {"ok": false, "reason": why}
	var key: String = cur.c.kit[slot]
	var fx := Items.fx(key)
	if not turn.action_available:
		return {"ok": false, "reason": "no action left"}
	var dist := Los.distance_m(cur.pos, cell)
	if dist > THROW_RANGE_M or cell.z != cur.pos.z or not los.trace(cur.pos, cell).clear:
		return {"ok": false, "reason": "can't throw there"}
	turn.use_action()
	cur.c.kit_spent[slot] = true
	var base: int = cur.c.skill_base("athletics") - cur.c.action_penalty()
	var check := Check.vs_dv(dice, base, maxi(10, RulesDB.range_dv("grenade_launcher", dist)))
	var center := cell
	if not check.success:   # p174: the GM places it somewhere in the 10x10 area around the aim
		for k in 12:
			var c := cell + Vector3i(dice.rng.randi_range(-BLAST_HALF, BLAST_HALF), dice.rng.randi_range(-BLAST_HALF, BLAST_HALF), 0)
			if m.inb(c.x, c.y) and los.blocker(c) == "":
				center = c
				break
	var no_damage: bool = fx.get("no_damage", false)
	var faces := PackedInt32Array() if no_damage else dice.roll_each(GRENADE_DICE, 6)
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
	var results: Array = []
	if no_damage:   # gas, flash: everyone caught who doesn't dive clear makes the check
		for o in caught:
			var res := {"target": o.c, "dodged": false, "damage": 0, "location": "head", "through": 0, "crits": []}
			if o.c.can_dodge_ranged():
				res.dodged = Check.roll_die(dice).die + o.c.skill_base("evasion") - o.c.action_penalty() > check.total
			if not res.dodged:
				Attack.apply_status(dice, o.c, fx.status, fx, res)
			results.append(res)
	else:
		results = Attack.explosion_rolled(dice, check.total, faces, caught.map(func(o): return o.c), fx)
	_rouse(caught.filter(func(o): return not allied(int(o.team), int(cur.team))))
	_noise(center)
	var hits: Array = []
	for res in results:
		var u := unit_of(res.target)
		hits.append({"id": u.id, "dodged": res.dodged, "damage": int(before[u.id][0]) - u.c.hp, "dead": u.c.dead,
			"killed": u.c.dead or u.c.wound_state() == Combatant.Wound.MORTAL, "wound_before": before[u.id][1], "wound_after": u.c.wound_state(),
			"status": res.get("status", {}), "ignited": res.get("ignited", false)})
	var gname := Items.display_name(key)
	events.append({"type": "blast", "unit": cur.id, "cell": cell, "center": center, "hit": check.success, "damage": dmg, "hits": hits,
		"destroyed": destroyed, "payload": key})
	say("%s throws %s%s: %s, %d caught." % [cur.c.display_name, "a " + gname.to_lower(), "" if check.success else " (off target)",
		"%d damage" % dmg if not no_damage else "no damage", hits.filter(func(h): return h.damage > 0 or not h.status.is_empty()).size()])
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
	if not allied(int(target.team), int(cur.team)) or target.c.dead or (target != cur and not adjacent(cur.pos, target.pos)):
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
	if not allied(int(target.team), int(cur.team)) or target.c.dead or (target != cur and not adjacent(cur.pos, target.pos)):
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
		_:   # Antibiotic, Rapidetox, Surge (p149-150) act over hours or days, not in a firefight
			return {"ok": false, "reason": "%s does nothing in a fight" % drug.capitalize()}
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
	if not can_reach_to_stabilize(cur, target) or not allied(int(target.team), int(cur.team)) or target.c.dead:
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


# --- Kit (safehouse gear packed for the gig) -------------------------------------------

## Why the active unit can't use kit slot `slot` as `how` ("grenade" | "dose"), or "". Guards
## carry kit too (a frag), packed by their roster rather than from storage.
func _kit_ready(slot: int, how: String) -> String:
	if cur.is_empty():
		return "not your turn"
	if slot < 0 or slot >= cur.c.kit.size() or cur.c.kit[slot] == "":
		return "nothing in that slot"
	if cur.c.kit_spent[slot]:
		return "already used"
	if Items.use(cur.c.kit[slot]) != how:
		return "can't use it that way"
	if not turn.action_available:
		return "no action left"
	return ""


## What a kit slot does in the field: "grenade" (pick a square), "dose" (on yourself), "carried"
## (works while on you), or "" if empty or spent.
func kit_action(slot: int) -> String:
	if cur.is_empty() or slot < 0 or slot >= cur.c.kit.size() or cur.c.kit[slot] == "" or cur.c.kit_spent[slot]:
		return ""
	return Items.use(cur.c.kit[slot])


## Take a drug from a kit slot (an Action, p.357: dosing yourself). Effects last the gig
## (HOUSE-RULE: their 4-24 hours outlast any gig); Black Lace costs 2d6 Humanity now (p.358).
func take_dose(slot: int) -> Dictionary:
	var why := _kit_ready(slot, "dose")
	if why != "":
		return {"ok": false, "reason": why}
	turn.use_action()
	var key: String = cur.c.kit[slot]
	var drug: String = key.get_slice("/", 1)
	var fx := Items.fx(key)
	cur.c.kit_spent[slot] = true
	cur.c.drugs_taken.append(drug)
	var eff := {}
	for k in ["stat_bonus", "skill_bonus", "ignore_seriously_wounded"]:
		if fx.has(k):
			eff[k] = fx[k]
	cur.c.drug_fx.append(eff)
	var hl := 0
	if String(fx.get("humanity_loss", "")) != "":
		hl = Combatant.roll_hl(dice, String(fx.humanity_loss))
		cur.c.lose_humanity(hl)
		cur.c.drug_humanity[drug] = int(cur.c.drug_humanity.get(drug, 0)) + hl
	events.append({"type": "dose", "unit": cur.id, "target": cur.id, "drug": drug, "healed": 0, "name": Items.display_name(key)})
	say("%s takes %s%s." % [cur.c.display_name, Items.display_name(key), " (-%d Humanity)" % hl if hl > 0 else ""])
	return {"ok": true, "humanity": hl}


## Reload (an Action, p169) as an event, so the view can play it. A jammed Poor Quality weapon
## is cleared instead (an Action, no Check, p.342).
func reload(weapon: Weapon) -> bool:
	if weapon.jammed:
		if not turn.use_action():
			return false
		weapon.jammed = false
		events.append({"type": "reload", "unit": cur.id, "weapon": weapon.id(), "unjam": true})
		say("%s clears the jam." % cur.c.display_name)
		return true
	if not weapon.uses_ammo() or weapon.ammo >= weapon.mag() or not turn.use_action():
		return false
	weapon.reload_done += 1
	if weapon.reload_done < weapon.reload_actions():   # the heavy exotics reload over two Actions (p348-349)
		events.append({"type": "reload", "unit": cur.id, "weapon": weapon.id(), "partial": true})
		say("%s starts reloading (%d more Action%s)." % [cur.c.display_name, weapon.reload_actions() - weapon.reload_done, "" if weapon.reload_actions() - weapon.reload_done == 1 else "s"])
		return true
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
			if dp.z == u.pos.z and Los.distance_m(u.pos, dp) <= jack_range(u.c) and not _wall_between(u.pos, dp):
				out.append({"index": i, "structure": sid, "device": d.id})
	return out


## Jacking in reaches through open space and windows but not through walls (p198). Furniture
## doesn't block a cable.
func _wall_between(a: Vector3i, b: Vector3i) -> bool:
	for v in Los.ray(a, b):
		if los.blocker(v) == "wall":
			return true
	return false


func jack_in(point: Dictionary) -> bool:
	if NetRun.interface_rank(cur.c) <= 0 or (not _netting and not turn.action_available):
		return false
	turn.action_available = false   # the turn goes to the NET (p197); jacking in is its first NET Action
	_netting = true
	net_left = net_actions_for(cur.c) - 1
	var run := NetRun.new(m.architectures[point.structure], cur.c)
	run.nets = m.architectures
	run.jack_in(point.index)
	runs[cur.id] = run
	run.met = _met_memory.get(cur.id, {}).duplicate()
	var dev: Dictionary = m.devices[point.device]
	jack_pos[cur.id] = Vector3i(dev.pos.x, dev.pos.y, dev.floor)
	say("%s jacks in." % cur.c.display_name)
	_meet_ice(cur, run)
	return true


## NET Actions (p198). kind: backdoor | control | eye_dee | zap | cross | jack_out. Moving between
## nodes is free (run.move_to). A turn spent in the NET forgoes the meat Action (p197).
func net_action(kind: String, arg: int = -1) -> Dictionary:
	var run: NetRun = runs.get(cur.id)
	if kind == "jack_out_unsafe" and run != null:   # pull the plug: no Action needed, Kraken or not, but every ICE met hits (p198)
		say("%s pulls the plug." % cur.c.display_name)
		_drop_run(cur.id, true)
		return {"ok": true}
	if kind not in ["backdoor", "control", "eye_dee", "zap", "cross", "jack_out", "sword", "armor", "slide", "pathfinder"]:
		return {"ok": false, "reason": "unknown action"}
	if run == null or net_left <= 0:
		return {"ok": false, "reason": "no NET Actions left"}
	if not _netting and not turn.action_available:   # the meat Action is spent: no NET this turn (p197)
		return {"ok": false, "reason": "your Action is spent"}
	var why := run.action_block(kind)
	if why != "":
		return {"ok": false, "reason": why}
	if kind in ["zap", "sword", "slide"] and run.arch.ice_at(run.current).is_empty():   # check before spending anything
		return {"ok": false, "reason": "no ICE here"}
	if kind in ["sword", "armor"] and not run.has_program(kind):
		return {"ok": false, "reason": "no %s Program" % kind.capitalize()}
	if kind == "armor" and (run.armor_used or run.armor_rez > 0):
		return {"ok": false, "reason": "Armor already used this run"}
	if kind == "slide" and (_slid_this_turn or arg < 0 or arg not in run.slide_targets()):
		return {"ok": false, "reason": "Slide once a turn, to a neighbouring node"}
	if kind == "jack_out" and run.kraken_until >= init.round_num:
		return {"ok": false, "reason": "a Kraken holds you: no safe Jack Out until its next turn"}
	if kind == "cross" and (run.current < 0 or String(run.cur_node().type) != "socket" or not run.nets.has(run.cur_node().get("target_structure", -1))):
		return {"ok": false, "reason": "no socket here"}
	turn.action_available = false
	_netting = true
	net_left -= 1
	if kind == "jack_out":   # a safe Jack Out is a NET Action (p198)
		_drop_run(cur.id, false)
		say("%s jacks out." % cur.c.display_name)
		return {"ok": true}
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
			var crossed := run.cross()
			if crossed:
				_meet_ice(cur, run)
			return {"ok": crossed}
		"sword":   # Anti-Program Attacker: Interface + ATK 1 + d10 vs DEF + d10; 3d6 REZ to Black ICE (p201, p203)
			var tgt2: Dictionary = run.arch.ice_at(run.current)[0]
			var st2: Dictionary = RulesDB.load_json("black_ice.json")["ice"][tgt2.kind]
			var hit2 := Check.opposed(dice, run.rank() + 1, int(st2.def))
			if hit2.success:
				tgt2["rez"] = int(tgt2.get("rez", st2.rez)) - dice.roll(3, 6)
				if tgt2.rez <= 0:
					tgt2["derezzed"] = true
					say("%s derezzed." % tgt2.kind)
			return {"ok": true, "success": hit2.success}
		"armor":   # Defender: -4 brain damage while Rezzed (REZ 7), once per Netrun (p203)
			run.armor_rez = 7
			run.armor_used = true
			say("%s runs Armor." % cur.c.display_name)
			return {"ok": true, "success": true}
		"slide":   # Interface + d10 vs the ICE's PER + d10, -2 per Skunk (p200, p207)
			var ice3: Dictionary = run.arch.ice_at(run.current)[0]
			var st3: Dictionary = RulesDB.load_json("black_ice.json")["ice"][ice3.kind]
			var skunks := run.skunks.keys().filter(func(id): return run.arch.ice.any(func(x): return x.id == id and not x.get("derezzed", false))).size()
			_slid_this_turn = true
			var ok := Check.opposed(dice, run.rank() - 2 * skunks, int(st3.per)).success
			if ok:   # the ICE stays where it was (p200)
				run.current = arg
				run.revealed[arg] = true
				for nb in run.arch.neighbors(arg):
					run.revealed[nb] = true
				_meet_ice(cur, run)
			say("%s %s." % [cur.c.display_name, "slides away" if ok else "fails to slide"])
			return {"ok": true, "success": ok}
		"pathfinder":   # reveal the map out to the check total (p199-200, graph adaptation)
			var shown := run.pathfinder(dice)
			say("Pathfinder reveals %d nodes." % shown.size())
			return {"ok": true, "success": not shown.is_empty(), "revealed": shown}
	return {"ok": false, "reason": "unknown"}


## Patrolling Black ICE (complex NETs) moves one node a round along its subnet's links, never
## through a firewall or onto a port; landing on a runner means a meeting (p205). ICE already
## engaged with a runner (on their node) stays.
func _patrol_ice() -> void:
	var occupied_by := {}   # arch, node → runner unit
	for uid in runs:
		var r: NetRun = runs[uid]
		occupied_by[[r.arch.structure, r.current]] = uid
	for sid in m.architectures:
		var a: NetArchitecture = m.architectures[sid]
		for ice in a.ice:
			if not ice.get("patrol", false) or ice.get("derezzed", false) or occupied_by.has([sid, ice.node]):
				continue
			var subnet: int = a.nodes[ice.node].subnet
			var opts := a.neighbors(ice.node).filter(func(nb): return a.nodes[nb].subnet == subnet and String(a.nodes[nb].type) not in ["firewall", "port", "socket"])
			if opts.is_empty():
				continue
			ice.node = opts[dice.d(opts.size()) - 1]
			if occupied_by.has([sid, ice.node]):
				var uid: int = occupied_by[[sid, ice.node]]
				_meet_ice(units[uid], runs[uid])


## Move inside the NET (free, p198); new Black ICE there gets its speed contest (p205).
func net_move(id: int) -> bool:
	var run: NetRun = runs.get(cur.id)
	if run == null or not run.move_to(id):
		return false
	_meet_ice(cur, run)
	return true


## Meeting Black ICE lying in wait (p205): Interface + 1d10 vs its SPD + 1d10; if the ICE wins,
## its Effect lands at once.
func _meet_ice(u: Dictionary, run: NetRun) -> void:
	for ice in run.meet():
		var st: Dictionary = RulesDB.load_json("black_ice.json")["ice"][ice.kind]
		if not Check.opposed(dice, run.rank(), int(st.spd)).success:
			say("%s is faster: it strikes first." % String(ice.kind).capitalize())
			_ice_effect(u, run, ice)
			if not runs.has(u.id):
				return


## Leave the NET: every node the runner held is lost (p199), so turrets, cameras and door locks
## go back to the site. An unsafe exit (dumped by range) also suffers every Black ICE met this
## session (p198).
func _drop_run(uid: int, unsafe: bool, keep_met := Vector2i(-1, -1)) -> void:
	var run: NetRun = runs.get(uid)
	if run == null:
		return
	for did in run.controlled_devices():
		disabled_devices.erase(did)
		var dev: Dictionary = m.devices[did]
		var cell := Vector3i(dev.pos.x, dev.pos.y, dev.floor)
		if dev.type == "door_lock" and not los.open_doors.has(cell) and m.t(cell.z, cell.x, cell.y) == TacMap.T.DOOR:
			nav.locked[cell] = true
	_met_memory[uid] = run.met.duplicate()
	if keep_met.x >= 0:   # a Giant that threw you out stays met (it doesn't re-ambush)
		_met_memory[uid][keep_met] = true
	if unsafe:
		var u: Dictionary = units[uid]
		for ice in run.arch.ice:
			if run.met.has(run.met_key(ice)) and not ice.get("derezzed", false):
				_ice_effect(u, run, ice, true)
	runs.erase(uid)


## Black ICE on the runner's node attacks at the start of their turn: ATK + 1d10 vs Interface +
## 1d10 (p205); anti-personnel hits deal their brain damage straight to HP (p206-207).
func _ice_turn(u: Dictionary) -> void:
	var run: NetRun = runs.get(u.id)
	if run == null:
		return
	for ice in run.arch.ice_at(run.current):
		_ice_attack(u, run, ice)


## `auto`: the Effect lands without a roll (an unsafe jack-out "suffers" every ICE met, p198).
func _ice_attack(u: Dictionary, run: NetRun, ice: Dictionary, auto := false) -> void:
	var stats: Dictionary = RulesDB.load_json("black_ice.json")["ice"][ice.kind]
	if String(stats["class"]) == "anti_program" and not auto:   # hunts Rezzed Programs: vs their DEF (0)
		if run.armor_rez > 0 and Check.opposed(dice, int(stats.atk), 0).success:
			_ice_effect(u, run, ice)
		return
	if auto or Check.opposed(dice, int(stats.atk), run.rank()).success:
		_ice_effect(u, run, ice, auto)


## A Black ICE Effect landing on the runner (p206-207). `quiet_giant`: an unsafe jack-out doesn't
## chain another forced jack-out.
func _ice_effect(u: Dictionary, run: NetRun, ice: Dictionary, from_dump := false) -> void:
	var stats: Dictionary = RulesDB.load_json("black_ice.json")["ice"][ice.kind]
	var kind := String(ice.kind)
	if String(stats["class"]) == "anti_program":   # Dragon, Killer, Sabertooth: wreck the running Defender
		if run.armor_rez > 0:
			run.armor_rez = 0
			run.lost["armor"] = true
			say("%s destroys the Armor program." % kind.capitalize())
		return
	match kind:
		"asp":   # destroys one random Program on the deck
			var have: Array = u.c.programs.filter(func(p): return not run.lost.has(p))
			if not have.is_empty():
				var p: String = have[dice.d(have.size()) - 1]
				run.lost[p] = true
				if p == "armor":
					run.armor_rez = 0
				say("Asp destroys %s's %s." % [u.c.display_name, p.capitalize()])
		"raven":   # derezzes a Rezzed Defender first
			run.armor_rez = 0
		"liche":
			for s in ["INT", "REF", "DEX"]:
				u.c.temp_mods[s] = int(u.c.temp_mods.get(s, 0)) + dice.roll(1, 6)
			say("Liche scrambles %s: INT, REF and DEX down." % u.c.display_name)
		"scorpion":
			u.c.temp_mods["MOVE"] = int(u.c.temp_mods.get("MOVE", 0)) + dice.roll(1, 6)
			say("Scorpion: %s's MOVE drops." % u.c.display_name)
		"skunk":
			run.skunks[ice.id] = true
		"wisp":
			run.wisp = 1
		"hellhound":
			u.c.burning = maxi(u.c.burning, 2)   # Hellhound: 2 a turn (p207); a stronger fire stays
		"kraken":   # HOUSE-RULE cap (playtest death loop): a lock can't be renewed back to back
			if init.round_num > run.kraken_until + 1:
				run.kraken_until = init.round_num + 1
				run.no_deeper = true
	if String(stats.brain) != "":
		var parts := String(stats.brain).split("d")
		var dmg := dice.roll(int(parts[0]), int(parts[1]))
		if run.armor_rez > 0:   # Armor: -4 brain damage (p203)
			dmg = maxi(0, dmg - 4)
		var before: int = u.c.wound_state()
		u.c.hp -= dmg
		say("%s hits %s for %d brain damage." % [kind.capitalize(), u.c.display_name, dmg])
		events.append({"type": "harm", "unit": u.id, "damage": dmg, "source": kind.to_upper(), "wound_before": before, "wound_after": u.c.wound_state()})
	if kind == "giant" and not from_dump and runs.has(u.id):   # forced unsafe Jack Out (the Giant itself excepted)
		var gk := run.met_key(ice)
		run.met.erase(gk)   # its own hit is the Effect; the dump suffers the others (p207)
		say("The Giant throws %s out of the NET." % u.c.display_name)
		_drop_run(u.id, true, gk)


## Where the runner is physically jacked in (the device they used, not the NET's first port).
func _ap_pos(run: NetRun) -> Vector3i:
	for uid in runs:
		if runs[uid] == run and jack_pos.has(uid):
			return jack_pos[uid]
	return cur.pos
