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
var district := ""                  ## the gig's district (World), "" for none: who's in the crowd
var opfor_faction := World.DEFAULT_OPFOR   ## the gig's target faction: whose place and people these are
## Whose people hold the posts and walk the patrols: the target's own, or the contractor its
## Security Code names (SecurityCode.guarded_by: Lazarus at Night Corp HQ). They play on the
## OPFOR side either way; the target's own people stay the staff and VIPs objectives place.
var post_faction := World.DEFAULT_OPFOR
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
var complication := {}              ## the book's complication rolled at gig start: {tier, roll, text, applied, skipped} (Complication)
var complication_waves: Array = []  ## its extra units still to come: {round, n, tier, unit, crit}
var focus_id := -1                  ## Lieutenant tactic focus_fire: the crew unit the opposition shoots first
var extract_cells := {}             ## Vector3i → true: the deploy zone, where a snatch is carried out
var vision: Vision                  ## what the crew can see (drives fog and hidden guards)
## What happened, in order, for the view to animate: {type: move|attack|cover|alert, ...}.
## The view drains it; rules code never reads it.
var events: Array[Dictionary] = []
var lit := {}                       ## Vector3i → true where a light reaches (darkness: -4 to spot, p? task table)
var alarm := 0                      ## 0 quiet, 1 a guard is onto the crew, 2 backup called
## Security Codes (NC2045 p.7, SecurityCode): the site's code answers the call (its roll, faction,
## intensity, Hardened); the district's code can send a second, street-level response after it.
var code: Dictionary = {}
var street_code: Dictionary = {}    ## {} when there is no separate street roll
var utility_code := 0               ## NC2045 p.8: 1d10 per utility, under it that utility is out
var outages: Array[String] = []     ## utilities out this gig: power, water, citinet
var backup_in := -1                 ## rounds until the site code's response arrives (-1 none coming)
var backup_label := "BACKUP"        ## who that is, for the HUD
var _backup_round := 0
var _patrol_round := -1
var reinforcements := true          ## responses on (balance tests switch them off)
var ncpd_in := -1                   ## rounds until the street-level (district code) response; -2 once it came
var ncpd_label := "NCPD"
var _ncpd_round := 0
var _response: Dictionary = {}      ## the planned responses: {code, fid, own, label, rank}
var _street: Dictionary = {}
var _hardened_posts := false        ## the posts use Hardened blocks (a Hardened code of the people holding them)
var _spot_rolls := {}               ## [guard id, crew id, round] → result: one stealth roll per pair per round
var jack_pos := {}                  ## runner unit id → the square of the device they jacked in at
var disabled_devices := {}          ## device id → true (turrets/cameras under the runner's control)
var lights_off := false             ## the site's lights are down for the whole gig (opts.lights_off)
var leg := -1                       ## the operation leg this encounter is for (opts.leg), -1 for a single gig
var hazard: HazardZone = null       ## a shrinking safe circle (the Combat Zone's MIST), null for none
var neutral: NeutralGround = null   ## a house where nobody fights (Totentanz's club floor), null for none
var turret_side := -1               ## the site's automated turrets (Turret); -1 until the map has one
var _crew_turret_side := -1         ## turrets a Netrunner holds; -1 until one does
var _gunner: Combatant = null       ## who aims this attack when not `cur` itself: a Netrunner firing a held turret (fire_turret)


## opts: {faction: the gig's target faction id (World), default generic private security;
## security_code: the site's Security Code (SecurityCode; default the fallback for the map's
## security level); district_code: the street's code ({} for none; default SecurityCode.STREET_FALLBACK);
## guards: whose people hold the posts under the site code (SecurityCode.guarded_by: the target's,
## a contractor's, or "" when the code is an outside authority's; default worked out from the code
## and the target alone); utility_code: the Utility Code (default 0, nothing goes out), rolled
## every time unless utilities: true, which rolls it only on one gig in SecurityCode.UTILITY_CHANCE_IN;
## complications: true to roll for one of the book's complications (Complication.CHANCE_IN);
## complication: {tier?, roll?} to force one; district: the gig's district, whose civilians make up
## the crowd and the people the objectives need (Recruit.civilian_blocks); carry: true for the next
## leg of an operation (Campaign), where the crew comes straight from the last map: kit already
## used, drugs in the system and doses spent carry over (no Combatant.gig_reset); crowd: extra
## bystanders; civilians: stat blocks (npcs.json) added to the crowd, one each; police: uniformed
## NCPD officers among the crowd, unalerted, who answer trouble as the police do; lights_off: the
## site's lights are down; leg: which leg of an operation this is (Campaign checks it when settling);
## hazard_zone / neutral_ground / free_for_all: a set piece's rules for any map (HazardZone,
## NeutralGround, FreeForAll; by default the map's set piece's own)}.
static func setup(p_map: TacMap, p_dice: Dice, crew: Array[Combatant], kind := "data", opts: Dictionary = {}) -> Encounter:
	var e := Encounter.new()
	opts = SetPieces.encounter_opts(p_map, opts)   # a set piece's per-seed variant (an estate's owner) brings its own code
	e.opfor_faction = String(opts.get("faction", World.DEFAULT_OPFOR))
	e.district = String(opts.get("district", ""))
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
		e.extract_cells[Vector3i(c0.x, c0.y, p_map.street)] = true
	e.lights_off = bool(opts.get("lights_off", false))   # HOUSE-RULE: Playland's Fright Nights (NC2045 p.306) read as lights down
	e.leg = int(opts.get("leg", -1))
	for i in crew.size():
		if bool(opts.get("carry", false)):
			crew[i].leg_reset()
		else:
			crew[i].gig_reset()
		var c: Vector2i = cells[i % cells.size()]
		e._add(crew[i], Vector3i(c.x, c.y, p_map.street), 0)
	# Guards at posts, target building first.
	var target_sid := -1
	for st in p_map.structures:
		if st.target:
			target_sid = st.id
	var site := ""
	for st in p_map.structures:
		if st.target:
			site = String(st.get("site", ""))
	var posts := p_map.posts.duplicate()
	# A set piece's own posts (roof snipers, AA gunners: SetPieceGen.posts) are manned first.
	var post_rank := func(q: Dictionary) -> int: return int(q.get("priority", false)) * 2 + int(q.structure == target_sid)
	posts.sort_custom(func(a, b): return post_rank.call(a) > post_rank.call(b))
	var sec := mini(3, int(p_map.params.get("security", 1)))
	e.code = SecurityCode.normalise(opts.get("security_code"))
	if e.code.is_empty():
		e.code = SecurityCode.from_level(int(p_map.params.get("security", 1)))
	if String(e.code.faction) == "":
		e.code.faction = e.opfor_faction   # the fallback's "the site's own people"
	e.street_code = SecurityCode.normalise(opts.get("district_code")) if opts.has("district_code") else SecurityCode.STREET_FALLBACK.duplicate()
	e.utility_code = int(opts.get("utility_code", 0))
	# Who holds the posts (NC2045 p.7): the target's people, or the contractor the site code names.
	# An outside authority's code ("") leaves the target's people on the posts, not Hardened.
	var guards := String(opts.get("guards", SecurityCode.guarded_by(e.code, e.opfor_faction)))
	e.post_faction = guards if World.has_faction(guards) else e.opfor_faction
	e._hardened_posts = bool(e.code.hardened) and guards != ""
	e.doctrine = Security.for_site(e.post_faction, site, String(p_map.params.get("scene", "")))
	# CPR p399 budget, strongest first (target building posts), at the map's 1-3 security level. A
	# site code's intensity reaches the posts through that level once (Campaign: a gig keeps to its
	# location's level, SecurityCode.level, only when the code guards the place); the intensity
	# table's crew-size shift (budget_crew_size, NC2045 p.7) sizes the responses alone.
	var roster := Security.roster(e.doctrine, crew.size(), sec)
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
		var g := World.npc(p_dice, e.post_faction, tier, i + 1, "", e._hardened_posts)
		# HOUSE-RULE: a set piece's post can hand its guard a weapon the printed block lacks (roof snipers' rifles)
		if posts[i].has("weapon"):
			g.weapons.insert(0, Weapon.from_id(String(posts[i].weapon)))
		e._add(g, Vector3i(posts[i].pos.x, posts[i].pos.y, posts[i].floor), OPFOR)
		if posts[i].has("facing"):   # a nest: stays put, watching out over the parapet
			e.units[-1]["hold"] = Vector2(posts[i].facing)
	e._neutral_ground(opts.get("neutral_ground", SetPieces.rule(p_map, "neutral_ground", {})))
	# Objective: a module per kind (data/gen/objectives.json) places what the job needs.
	e.obj = Objective.make(kind, e)
	e.objective = e.obj.o
	e.obj.setup(target_sid, cells[0], sec)
	# M3 playtest verdict: guards only join the initiative order once they're alerted.
	for u in e.units:
		if u.alerted:
			e.init.add(u.c)
	e.vision = Vision.new(p_map, e.los)
	if not bool(opts.get("utilities", false)) or SecurityCode.utilities_happen(p_dice):
		e.outages = SecurityCode.roll_utilities(p_dice, e.utility_code)
	e._apply_outages()
	e._compute_light()
	e._outer_patrols(cells[0])
	FreeForAll.place(e, opts.get("free_for_all", SetPieces.rule(p_map, "free_for_all", {})), cells[0])
	e._post_guards()
	if opts.has("complication") or bool(opts.get("complications", false)):
		Complication.start(e, opts.get("complication", {}))
	if bool(e.doctrine.get("keycards", true)):
		e._hand_out_keycards()
	e._trauma_cards()
	e._place_civilians(cells[0], int(opts.get("crowd", 0)), opts.get("civilians", []))
	e._place_police(cells[0], int(opts.get("police", 0)))
	e.hazard = HazardZone.from_spec(opts.get("hazard_zone", SetPieces.rule(p_map, "hazard_zone", {})), p_map, p_dice)
	e._mount_turrets()
	for line in SetPieces.briefs(String(p_map.params.get("setpiece", ""))):   # the place's house rules, for the briefing
		e.say(line)
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
## `extra` keys ride on the side: `stands_with` (a team whose relations it shares, kept shared by
## set_relation: the site's turrets stand with the guards, the crew's with the crew, Totentanz's
## bouncers with Maelstrom), `at_war` (hostile to every side that fights: the crew, guards and
## turrets; FreeForAll).
func add_side(faction: String, ai: String, opfor: bool, extra: Dictionary = {}) -> int:
	var t := sides.size()
	var side := {"faction": faction, "ai": ai, "opfor": opfor}
	side.merge(extra)
	sides.append(side)
	for o in t + 1:
		var r := "ally" if o == t else World.relation(faction, String(sides[o].faction))
		if o != t and side.has("stands_with"):
			r = "ally" if o == int(side.stands_with) else relation(int(side.stands_with), o)
		elif o != t and sides[o].has("stands_with"):
			r = relation(t, int(sides[o].stands_with))
		if o != t and _at_war(side, sides[o]):
			r = "hostile"
		if (o == CREW and opfor) or (t == CREW and bool(sides[o].opfor)):
			r = "hostile"
		_rel[Vector2i(t, o)] = r
		_rel[Vector2i(o, t)] = r
	return t


const WAR_AIS := ["crew", "guard", "turret"]   ## the sides an `at_war` side fights (not bystanders or medics)


static func _at_war(a: Dictionary, b: Dictionary) -> bool:
	return (bool(a.get("at_war", false)) and String(b.ai) in WAR_AIS) or (bool(b.get("at_war", false)) and String(a.ai) in WAR_AIS)


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
	for s in sides.size():   # sides that stand with a or b follow
		if s == a or s == b or not sides[s].has("stands_with"):
			continue
		var with := int(sides[s].stands_with)
		if with == a or with == b:
			var other := b if with == a else a
			_rel[Vector2i(s, other)] = r
			_rel[Vector2i(other, s)] = r


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
		if not complication_waves.is_empty():
			Complication.tick(self)
		_tick_backup()
		obj.tick()
		if init.round_num != _civ_round:
			_civ_round = init.round_num
			_civilians_tick()
			_tick_trauma()
			_tick_hazard()
		if state != "playing":
			return
		turn = TurnState.begin(dice, c)
		net_left = 0
		_netting = false
		_slid_this_turn = false
		if cur.team == OPFOR and cur.alerted and turn.survived and c.can_act():
			call_it_in(cur)
		if not turn.survived:
			say("%s fails a Death Save and dies." % c.display_name)
			events.append({"type": "death", "unit": cur.id})   # so the view plays the death, not a snap
		elif c.can_act():
			if cur.has("turret"):   # bolted down: it shoots or it waits (Turret); a held one waits for its Netrunner
				cur.erase("suppressed_by")
				if not cur.has("held_by"):
					AI.turret(self, cur)
				end_turn()
				continue
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
	if turn != null and not cur.is_empty():
		_hazard_harm(cur)
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
	_wreck_turrets()
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


# --- Hazard zone (HazardZone: the Combat Zone's MIST) --------------------------------------

## Once a round: the safe circle closes in on schedule.
func _tick_hazard() -> void:
	if hazard == null or not hazard.tick(init.round_num):
		return
	var msg := "The %s closes in: %d squares round its heart" % [hazard.name, roundi(hazard.radius())]
	say(msg + (", as small as it gets." if hazard.closes_in(init.round_num) < 0 else "."))
	events.append({"type": "hazard", "unit": cur.id if not cur.is_empty() else 0, "stage": hazard.stage, "radius": hazard.radius()})


## The end of `u`'s turn outside the safe circle: the zone's dice straight to HP (no armour).
func _hazard_harm(u: Dictionary) -> void:
	if hazard == null or u.c.dead or u.get("carried", false) or u.has("turret") or not hazard.bites(String(sides[u.team].ai), u.pos, faction_of(u)):
		return
	var dmg := 0
	for i in hazard.damage_dice():
		dmg += dice.d(6)
	if dmg <= 0:
		return
	var before: int = u.c.wound_state()
	u.c.hp -= dmg
	say("%s takes %d outside the %s." % [u.c.display_name, dmg, hazard.name])
	events.append({"type": "harm", "unit": u.id, "damage": dmg, "source": hazard.name, "wound_before": before, "wound_after": u.c.wound_state()})


# --- Neutral ground (NeutralGround: Totentanz's club floor) ------------------------------------

## Set the house up once the posts are manned: the guards posted in its public rooms (the
## bouncers) move to a side of their own, Maelstrom still but `neutral` to the crew.
func _neutral_ground(spec: Dictionary) -> void:
	neutral = NeutralGround.from_spec(spec, m)
	if neutral == null:
		return
	neutral.side = add_side(post_faction, "guard", true, {"stands_with": OPFOR})
	set_relation(neutral.side, CREW, "neutral")
	for u in units:
		if int(u.team) == OPFOR and neutral.inside(u.pos):
			u.team = neutral.side
			u.c.team = neutral.side
			u["bouncer"] = true


## A bouncer while the peace holds: no spotting the crew, no joining a fight it didn't see.
func _keeps_peace(g: Dictionary) -> bool:
	return neutral != null and neutral.holds and int(g.team) == neutral.side


## Does `u` hold its fire at `t`? While the peace holds the house (anyone standing with the
## bouncers) doesn't start a fight with the crew on the club floor (AI._enemies).
func holds_fire(u: Dictionary, t: Dictionary) -> bool:
	return neutral != null and neutral.holds and allied(int(u.team), neutral.side) and allied(int(t.team), CREW) and neutral.inside(t.pos)


## The crew (or anything fighting for them) attacks from `by` at the squares `at`: inside the
## house's public rooms, or where a bouncer can see it (clear sight within SPOT_RANGE, any
## direction), and the peace is over.
func _keep_peace(by: Dictionary, at: Array) -> void:
	if neutral == null or not neutral.holds or by.is_empty() or not allied(int(by.team), CREW):
		return
	var spots: Array = at.duplicate()
	spots.append(by.pos)
	var seen := spots.any(func(p): return neutral.inside(p))
	for g in units:
		if seen:
			break
		if int(g.team) != neutral.side or not g.c.can_act():
			continue
		for p in spots:
			if g.pos == p or (p.z == g.pos.z and Vector2(p.x - g.pos.x, p.y - g.pos.y).length() <= SPOT_RANGE and los.trace(g.pos, p).clear):
				seen = true
				break
	if seen:
		_break_peace(by)


## The first fight in the house: the bouncers are the opposition again and the whole house (them
## and every guard in the building) turns on the crew.
func _break_peace(by: Dictionary) -> void:
	neutral.holds = false
	set_relation(neutral.side, CREW, "hostile")
	var house := []
	for g in units:
		if g.c.dead:
			continue
		if int(g.team) == neutral.side:
			g.team = OPFOR
			g.c.team = OPFOR
			house.append(g)
		elif int(g.team) == OPFOR and is_guard(g):
			var l := m.label(g.pos.z, g.pos.x, g.pos.y)
			if l >= 0 and int(m.rooms[l].get("structure", -1)) == neutral.structure:
				house.append(g)
	say("%s: the peace is broken. The whole house turns on the crew." % neutral.name)
	events.append({"type": "peace_broken", "unit": int(by.id), "units": house.map(func(g): return g.id)})
	_rouse(house)


# --- Automated turrets (Turret: CPR core p.214) ----------------------------------------------

## Every powered turret device becomes a unit on the site's turret side (standing with the
## guards). It never moves and joins the Initiative order the first time it has a target.
func _mount_turrets() -> void:
	var n := 0
	for d in m.devices:
		if String(d.type) != "turret" or _unpowered(d):
			continue
		if turret_side < 0:
			turret_side = add_side(post_faction, "turret", false, {"stands_with": OPFOR})
		n += 1
		var c := Turret.make(n, String(d.get("weapon", Turret.WEAPON)))
		c.faction = post_faction
		_add(c, Vector3i(d.pos.x, d.pos.y, int(d.floor)), turret_side)
		units[-1]["turret"] = int(d.id)


## A turret with its power out does nothing (Utility Codes, NC2045 p.8).
func turret_off(u: Dictionary) -> bool:
	return u.has("turret") and _unpowered(m.devices[int(u.turret)])


## Sleeping turrets that now have someone to shoot (its trigger: anyone it would fire on in
## sight, AI.turret_targets) wake and take their place in the Initiative order.
func _wake_turrets() -> void:
	for u in units:
		if not u.has("turret") or u.has("held_by") or u.alerted or u.c.dead or turret_off(u):
			continue
		if not AI.turret_targets(self, u).is_empty():
			u.alerted = true
			init.add(u.c)
			say("%s swings round." % u.c.display_name)


## Who holds each turret. A Netrunner holding its Control Node operates it (p.199, p.213-214):
## it stands with the crew, leaves the Initiative order and fires only when the runner spends a
## NET Action on it (fire_turret). When they let go of the node (jack out, p199) it goes back to
## the site and, if it was awake, rolls back into the order to act on its own CN + 1d10 (p.213).
func _retake_turrets() -> void:
	var holder := {}   # device id → the runner's unit id
	for uid in runs:
		for did in (runs[uid] as NetRun).controlled_devices():
			holder[int(did)] = int(uid)
	for u in units:
		if not u.has("turret") or u.c.dead:
			continue
		var by: int = holder.get(int(u.turret), -1)
		if by == int(u.get("held_by", -1)):
			continue
		if by >= 0:
			if _crew_turret_side < 0:
				_crew_turret_side = add_side("crew", "turret", false, {"stands_with": CREW})
			var was_held := u.has("held_by")
			u["held_by"] = by
			u.team = _crew_turret_side
			u.c.team = _crew_turret_side
			if not was_held:
				init.remove(u.c)   # no turn of its own while the runner holds it
			say("%s answers to %s's deck." % [u.c.display_name, units[by].c.display_name])
		else:
			u.erase("held_by")
			u.team = turret_side
			u.c.team = turret_side
			if u.alerted and not init.order().has(u.c):
				init.add(u.c)
			say("%s goes back to the site." % u.c.display_name)


## Who rolls the attack: the Netrunner operating a turret (fire_turret), else whoever's turn it is.
func _aimer() -> Combatant:
	return _gunner if _gunner != null else cur.c


## The turrets on Control Nodes `uid`'s Netrunner holds, for the NET panel: [{id, node, why ("" =
## it can fire now), targets: [{id, chance}] best first}].
func held_turrets(uid: int) -> Array:
	var run: NetRun = runs.get(uid)
	var out := []
	if run == null:
		return out
	for u in units:
		if int(u.get("held_by", -1)) != uid or u.c.dead:
			continue
		var node := _turret_node(run, int(u.turret))
		var why := _turret_block(run, u, node)
		var ts := []
		for t in AI.turret_targets(self, u):
			ts.append({"id": int(t.id), "chance": turret_chance(u, t, run.runner)})
		ts.sort_custom(func(a, b): return float(a.chance) > float(b.chance))
		out.append({"id": int(u.id), "node": node, "why": why, "targets": ts})
	return out


## The held Control Node a turret device hangs on (-1: none).
func _turret_node(run: NetRun, did: int) -> int:
	for nid in run.held:
		if (run.arch.nodes[nid].get("devices", []) as Array).has(did):
			return int(nid)
	return -1


## Why the runner can't fire turret `u` right now ("" = they can).
func _turret_block(run: NetRun, u: Dictionary, node: int) -> String:
	if node < 0:
		return "not on a node you hold"
	if turret_off(u):
		return "no power"
	var w: Weapon = u.c.weapons[0]
	if w.jammed:
		return "jammed"
	if w.uses_ammo() and w.ammo <= 0:
		return "out of ammunition"   # nobody reloads a turret (p.214)
	if int(run.activated.get(node, -1)) == init.round_num:
		return "node already used this turn"   # each Node once per Turn (p199)
	return ""


## The runner's chance with turret `u` at `t`: their own REF + weapon Skill (RULES-UNVERIFIED,
## see fire_turret) from the turret's square; a flamethrower's shell is vs DV13 (p174).
func turret_chance(u: Dictionary, t: Dictionary, gunner: Combatant) -> float:
	var w: Weapon = u.c.weapons[0]
	if Turret.shells(w):
		if Los.distance_m(u.pos, t.pos) > Attack.SHOTGUN_SHELL_RANGE_M:
			return 0.0
		return Check.chance_vs_dv(Attack.attack_base(gunner, w, Attack.Mode.SINGLE), Attack.SHOTGUN_SHELL_DV)
	var keep: Dictionary = cur
	cur = u
	_gunner = gunner
	var p := preview(t, w, Attack.Mode.SINGLE)
	cur = keep
	_gunner = null
	return float(p.chance) if p.ok else 0.0


## Operate a held turret (p.199, p.213-214): a NET Action, each Control Node once per Turn, the
## turret firing from where it stands at `target_id` (someone it has in its sights,
## AI.turret_targets) with the Netrunner's own Skill. One Single Shot, or the flamethrower's one
## shell (p174, p.348). Spends the turret's rounds; it is never reloaded.
## RULES-UNVERIFIED: p.213-214 says only "their own Skills"; we use the turret weapon's Skill with
## REF (Shoulder Arms for the rifle, Heavy Weapons for the flamethrower, Handgun for the pistol and
## SMG), as a person firing it would.
func fire_turret(tid: int, target_id: int) -> Dictionary:
	var run: NetRun = runs.get(cur.id)
	if run == null or net_left <= 0:
		return {"ok": false, "reason": "no NET Actions left"}
	if not _netting and not turn.action_available:   # the meat Action is spent: no NET this turn (p197)
		return {"ok": false, "reason": "your Action is spent"}
	if tid < 0 or tid >= units.size() or int(units[tid].get("held_by", -1)) != int(cur.id):
		return {"ok": false, "reason": "you don't hold that turret"}
	var t: Dictionary = units[tid]
	var node := _turret_node(run, int(t.turret))
	var why := _turret_block(run, t, node)
	if why != "":
		return {"ok": false, "reason": why}
	if target_id < 0 or target_id >= units.size() or not AI.turret_targets(self, t).has(units[target_id]):
		return {"ok": false, "reason": "not in the turret's sights"}
	var tgt: Dictionary = units[target_id]
	var w: Weapon = t.c.weapons[0]
	if turret_chance(t, tgt, cur.c) <= 0.0:
		return {"ok": false, "reason": "out of range"}
	turn.action_available = false
	_netting = true
	net_left -= 1
	run.activated[node] = init.round_num
	say("%s fires %s through the NET." % [cur.c.display_name, t.c.display_name])
	var runner: Dictionary = cur
	var keep_turn := turn
	cur = t   # the shot comes from the turret's square, with the turret's gun ...
	turn = TurnState.new()
	turn.c = t.c
	_gunner = runner.c   # ... aimed with the Netrunner's Skill
	var r: Dictionary = shotgun_shell(tgt, w) if Turret.shells(w) else attack(tgt, w, Attack.Mode.SINGLE)
	cur = runner
	turn = keep_turn
	_gunner = null
	r["ok"] = true   # the NET Action is spent whatever the shot did
	r["success"] = bool(r.get("hit", false))
	return r


## A turret at 0 HP is wrecked: no Death Saves for a machine.
func _wreck_turrets() -> void:
	for u in units:
		if u.has("turret") and not u.c.dead and u.c.hp < 1:
			u.c.dead = true
			say("%s is wrecked." % u.c.display_name)


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
## the ones that have panicked run for the map edge.
func _place_civilians(deploy: Vector2i, crowd := 0, extra_blocks: Array = []) -> void:
	var scene := String(m.params.get("scene", ""))
	if scene in ["badlands", "undercity"]:
		return
	var cand := _crowd_cells(deploy)
	if cand.is_empty():
		return
	var extra := int(SetPieces.rule(m, "civilians", 0)) + crowd   # a set piece's public floor draws a crowd
	var n := clampi(int(m.w * m.h / 650.0) + (3 if scene == "arcology" else 0) + extra, 3, 12 + extra)
	# Who's about (NC2045's civilian blocks): two in three are the district's own, the rest from
	# anywhere in the city (HOUSE-RULE: most districts print one or two, so a crowd of only those
	# would be one face). A place whose Security Code answers with its own patrons (`locals`, e.g.
	# a club's regulars) keeps their printed weapons; anywhere else they're unarmed bystanders.
	var local := Recruit.civilian_blocks(district)
	var city := Recruit.civilian_blocks()
	var locals_armed := String(code.get("faction", "")) == "locals"
	var placed: Array = []
	for k in n * 6:
		if placed.size() >= n:
			break
		var v: Vector3i = cand[dice.d(cand.size()) - 1]
		if placed.any(func(q): return Vector2(q.x - v.x, q.y - v.y).length() < 4.0):
			continue
		var pool: Array[String] = local if dice.d(3) <= 2 else city
		_add_civilian(Recruit.civilian(dice, pool[dice.d(pool.size()) - 1]), v, locals_armed)
		placed.append(v)
	# Named extras (an event's guests: Playland's job-fair recruiters), one each where there's room.
	for b in extra_blocks:
		if not RulesDB.load_json("npcs.json")["blocks"].has(String(b)):
			continue
		for k in 12:
			var v: Vector3i = cand[dice.d(cand.size()) - 1]
			if not occupied().has(v):
				_add_civilian(Recruit.civilian(dice, String(b)), v, locals_armed)
				break


## Where bystanders stand: public rooms on the ground floor and the street's pavements, 10+
## squares from the deploy zone.
func _crowd_cells(deploy: Vector2i) -> Array:
	var cand: Array = []
	for y in m.h:
		for x in m.w:
			var v := Vector3i(x, y, m.street)
			if not m.walkable(m.street, Vector2i(x, y)) or occupied().has(v) or Vector2(x - deploy.x, y - deploy.y).length() < 10:
				continue
			var l := m.label(m.street, x, y)
			var ok := false
			if l >= 0:
				var r: Dictionary = m.rooms[l]
				ok = int(r.zone) == TacMap.Zone.PUBLIC and String(r.kind) not in ["roof", "corridor"]
			else:
				ok = m.t(m.street, x, y) == TacMap.T.OUTSIDE and m.ground[y * m.w + x] == TacMap.G.SIDEWALK
			if ok:
				cand.append(v)
	return cand


func _add_civilian(c: Combatant, v: Vector3i, armed: bool) -> void:
	if not armed:
		c.weapons.clear()
	c.faction = "bystanders"
	_add(c, v, CIV_TEAM)
	var u: Dictionary = units[-1]
	u.alerted = false
	u["civ"] = true
	u["panic"] = false
	if armed:
		u["local"] = true


## Uniformed NCPD among the crowd (an event that draws off-duty cops: Playland's NCPD Night,
## NC2045 p.305): `n` officers on the police's side, unalerted, standing about like the
## bystanders; they answer trouble the way police responders do (World.npc's NCPD block).
func _place_police(deploy: Vector2i, n: int) -> void:
	if n <= 0:
		return
	var cand := _crowd_cells(deploy)
	if cand.is_empty():
		return
	var team := side_for("ncpd", "guard", true)
	for i in n:
		for k in 12:
			var v: Vector3i = cand[dice.d(cand.size()) - 1]
			if not occupied().has(v):
				_add(World.npc(dice, "ncpd", "mook", i + 1), v, team)
				units[-1].alerted = false
				break


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
## No doctrine escalates to MaxTac since campaign heat was removed; dev renders (greybox --av) call it.
## With nowhere for the AV to land they come in on foot at the far entrance.
func _maxtac_drop() -> void:
	var crew := alive(0)
	if crew.is_empty():
		return
	var spot := av_spot(crew[0].pos, 6, 40)
	if spot.x < 0:
		var r := World.responder("maxtac")
		var tiers: Array[String] = []
		for t in r.tiers:
			tiers.append(String(t))
		_spawn_wave(tiers, "MAXTAC", side_for("maxtac", "guard", true), "maxtac", String(r.get("rank", "")))
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
	var up := m.street + 1   # the storey above the street (basements sit below it)
	if up >= m.floors:
		return false
	for k in range(2, 9):   # a wedge toward the camera, about 25° either side
		for c in [Vector2i(x + k, y + k), Vector2i(x + k, y + k / 2), Vector2i(x + k / 2, y + k)]:
			if m.inb(c.x, c.y) and m.t(up, c.x, c.y) in [TacMap.T.FLOOR, TacMap.T.WALL, TacMap.T.DOOR, TacMap.T.STAIRS]:   # a second storey
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
					if m.t(m.street, v.x, v.y) != TacMap.T.OUTSIDE or m.label(m.street, v.x, v.y) >= 0 or not m.walkable(m.street, v) or occ.has(Vector3i(v.x, v.y, m.street)):
						ok = false
						break
				if not ok:
					break
			if ok:
				bd = d
				best = Vector3i(x, y, m.street)
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
				if m.inb(v.x, v.y) and m.walkable(v.z, Vector2i(v.x, v.y)) and not occupied().has(v) and not out.has(v):
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
		if m.walkable(v.z, Vector2i(v.x, v.y)) and not occupied().has(v):
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
	_keep_peace(units[by] if by >= 0 and by < units.size() else {}, [center])
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
func secure_cell(target_sid: int, origin: Vector2i, role := "") -> Vector3i:
	var field: Dictionary = nav.distance_field([Vector3i(origin.x, origin.y, m.street)], {})
	var best := Vector3i(origin.x, origin.y, m.street)
	var best_d := -1.0
	var occ := occupied()
	# A site's own anchors (sites.json `anchors.<role>.<room kind>`: a bonus worth ~20 per security
	# level): where its mark sits (vip), its captive is held, its package or machine is kept.
	var anchors: Dictionary = {}
	if target_sid >= 0 and target_sid < m.structures.size():   # a set piece's building: its recipe's anchors
		anchors = SetPieces.structure_def(m.structures[target_sid]).get("anchors", {}).get(role, {})
	for cell in field:
		var l := m.label(cell.z, cell.x, cell.y)
		if l < 0 or m.rooms[l].structure != target_sid or m.rooms[l].get("kind", "") == "roof" or m.rooms[l].get("outdoor", false) or occ.has(cell) \
				or m.has_cover_at(cell.z, Vector2i(cell.x, cell.y)):
			continue
		var score := float(field[cell]) + 20.0 * int(m.rooms[l].get("zone", 0)) \
			+ float(anchors.get(String(m.rooms[l].get("kind", "")), 0.0))   # the most secure rooms first
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
	_wake_turrets()
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
			if not camera_sees(d, u.pos) or passing_as_public(u):
				continue
			var key := ["cam", d.id, u.id, init.round_num if init else 0]
			if not _spot_rolls.has(key):
				var base := CAMERA_PERCEPTION - (0 if lit.has(u.pos) else DARK_PENALTY)
				_spot_rolls[key] = Check.opposed(dice, base, u.c.skill_base("stealth") - u.c.action_penalty()).success
			if _spot_rolls[key]:
				var best: Dictionary = {}
				for g in units:
					if is_guard(g) and hostile(int(g.team), CREW) and not sides[int(g.team)].get("at_war", false) and not g.alerted and not g.c.dead and (best.is_empty() or Vector3(g.pos - cp).length() < Vector3(best.pos - cp).length()):
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
## Radio and shouting range come from the doctrine (data/world/security.json); who answers the
## call, and when, from the Security Codes (call_it_in).


## Can guard `g` spot crew member `u` right now? Inside the guard's view (cone or close), in clear
## sight within SPOT_RANGE, the guard's Perception beats the crew member's Stealth (opposed, p? ;
## Stealth is opposed by Perception, p85), at -4 if the crew member stands in darkness and -2 per
## 5 squares beyond 5 (HOUSE-RULE: distance).
func _spots(g: Dictionary, u: Dictionary) -> bool:
	if u.pos.z != g.pos.z:
		return false
	if passing_as_public(u):
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


## HOUSE-RULE (set pieces with `public_access`: Ziggurat's museum floor, Fort Sumter's petition
## floor): while no alarm is up, crew in the public rooms of the ground floor or out on the open
## street and grounds pass as visitors; guards only take them for intruders past the first
## restricted door (any room above the public zone, any upper floor).
var _public_access = null   ## the set piece's rule, read once


func passing_as_public(u: Dictionary) -> bool:
	if _public_access == null:
		_public_access = bool(SetPieces.rule(m, "public_access", false))
	if alarm > 0 or not _public_access or int(u.get("team", CREW)) != CREW:
		return false
	var p: Vector3i = u.pos
	if p.z != m.street:
		return false
	var l := m.label(m.street, p.x, p.y)
	if l < 0:
		return m.t(m.street, p.x, p.y) in [TacMap.T.OUTSIDE, TacMap.T.DOOR]
	return int(m.rooms[l].zone) <= TacMap.Zone.PUBLIC


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
	for e in ([] if lights_out() else LightPlan.plan(m, m.seed_value)):
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
				if m.t(m.street, x, y) == TacMap.T.OUTSIDE and m.label(m.street, x, y) < 0:
					lit[Vector3i(x, y, m.street)] = true


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
	var field: Dictionary = _keys(func(): return nav.distance_field([Vector3i(deploy.x, deploy.y, m.street)], {}, 4000))
	var cand: Array = []
	for v in field:
		var l := m.label(v.z, v.x, v.y)
		if v.z == m.street and int(field[v]) > 16 and (l < 0 or m.rooms[l].structure != tsid) and not m.has_cover_at(v.z, Vector2i(v.x, v.y)):
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
			var g := World.npc(dice, post_faction, "mook", n, "Patrol", _hardened_posts)
			_add(g, spot, OPFOR)
			taken.append(spot)
			units[-1]["outer"] = true


func _post_guards() -> void:
	for g in units:
		if not is_guard(g):
			continue
		var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
		if g.has("hold"):
			g.facing = g.hold
			continue
		var l := m.label(g.pos.z, g.pos.x, g.pos.y)
		if l >= 0:   # face the middle of the room
			var b: Rect2i = m.rooms[l].bounds
			var to := Vector2(b.position.x + b.size.x / 2.0 - g.pos.x, b.position.y + b.size.y / 2.0 - g.pos.y)
			g.facing = to.normalized() if to.length() > 0.5 else dirs[dice.d(8) - 1]
		else:
			g.facing = dirs[dice.d(8) - 1]
		if dice.d(10) <= 4 or g.get("outer", false) or g.get("roam", false):   # ~40% patrol; outer pairs and roamers (FreeForAll) always walk a beat
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


## A guard who knows the crew is here calls it in: the incident (NC2045 p.7). The radio rouses the
## caller's side within the doctrine's radio range; the site's Security Code is rolled once (1d10
## under its number: its faction responds, after 1d6 or 1d10 minutes at 2 rounds a minute, doubled
## if CitiNet is down), and the district's code once, for a street-level response after that,
## unless the district's faction is the site code's (it has answered already: NC2045 p.7, a
## location's code replaces its district's for that place). Gunfire rouses guards (_noise), who
## call it in on their turn; dev renders call it directly.
func call_it_in(g: Dictionary) -> void:
	if alarm >= 2 or g.c.dead or not reinforcements:
		return
	alarm = 2
	# The radio call rouses guards within the doctrine's radio range of the caller: the rest hold posts.
	var radio := float(doctrine.alarm.radio_range)
	_rouse(units.filter(func(o): return is_guard(o) and allied(int(o.team), int(g.team)) and not o.alerted and not o.c.dead and Vector2(o.pos.x - g.pos.x, o.pos.y - g.pos.y).length() <= radio))
	_backup_round = init.round_num
	_ncpd_round = init.round_num
	var slow := 2 if "citinet" in outages else 1   # OWNER-ACCEPTED: CitiNet out doubles response time
	var msg := "%s calls it in." % g.c.display_name
	if SecurityCode.responds(dice, code):
		_response = _plan_response(code)
		backup_label = String(_response.label)
		backup_in = SecurityCode.response_rounds(dice, SecurityCode.quick(code)) * slow
		msg += " %s in %d rounds." % [String(_response.label).capitalize(), backup_in]
	else:
		msg += " Nobody answers."
	var street_is_site := String(street_code.get("faction", "")) == String(code.faction)
	if not street_code.is_empty() and not street_is_site and ncpd_in == -1 and SecurityCode.responds(dice, street_code):
		_street = _plan_response(street_code)
		ncpd_label = String(_street.label)
		ncpd_in = maxi(backup_in, 0) + SecurityCode.response_rounds(dice, SecurityCode.quick(street_code)) * slow
		msg += " The street noticed: %s in %d." % [SecurityCode.faction_name(String(street_code.faction)), ncpd_in]
	say(msg)
	events.append({"type": "alarm", "unit": g.id, "rounds": backup_in})


## Who a code sends: the site's own people (the target's, or the contractor holding the posts) come
## as BACKUP on the opposition's side; anyone else on their own side (World.relation decides
## whether they also go after the guards). A faction not in factions.json yet turns up as generic
## security under its printed name.
func _plan_response(c: Dictionary) -> Dictionary:
	var fid := String(c.faction)
	var known := World.has_faction(fid)
	var spawn_fid := fid if known else World.DEFAULT_OPFOR
	var own := fid == opfor_faction or spawn_fid == opfor_faction or fid == post_faction
	var rank := "Backup"
	if not own:
		rank = String(World.responder(spawn_fid).get("rank", "")) if known else SecurityCode.faction_name(fid)
	return {"code": c, "fid": spawn_fid, "own": own, "rank": rank,
		"label": "BACKUP" if own else SecurityCode.faction_name(fid).to_upper()}


func _tick_backup() -> void:
	if ncpd_in > 0 and init.round_num != _ncpd_round:
		_ncpd_round = init.round_num
		ncpd_in -= 1
		if ncpd_in == 0:
			ncpd_in = -2   # once per gig
			_arrive(_street)
	if backup_in < 0 or init.round_num == _backup_round:
		return
	_backup_round = init.round_num
	backup_in -= 1
	if backup_in > 0:
		return
	backup_in = -1
	_arrive(_response)


## A planned response turns up at the far entrance, sized by its code's intensity for the crew
## still standing (SecurityCode.response_roster), Hardened if the code is.
func _arrive(r: Dictionary) -> void:
	if r.is_empty():
		return
	var roster := SecurityCode.response_roster(dice, r.code, maxi(1, alive(CREW).size()))
	var team := OPFOR if bool(r.own) else side_for(String(r.fid), "guard", true)
	_spawn_wave(roster, String(r.label), team, String(r.fid), String(r.rank), bool(r.code.get("hardened", false)))


# --- Utility Codes (NC2045 p.8) ------------------------------------------------------------

const POWERED := ["camera", "turret"]


## Is the power out? The lights are off and cameras and turrets dead. `lights_off` (a site played
## with its lights down) is a HOUSE-RULE reading of Playland's Fright Nights (NC2045 p.306): the book
## says only that the Haunted Woods' scares run fully staffed.
func lights_out() -> bool:
	return "power" in outages or lights_off


func _unpowered(dev: Dictionary) -> bool:
	return "power" in outages and String(dev.type) in POWERED


## OWNER-ACCEPTED effects: power out kills cameras, turrets and the site's lights (mechanical locks
## hold); CitiNet out doubles response times (call_it_in); water out is flavour.
func _apply_outages() -> void:
	for d in m.devices:
		if _unpowered(d):
			disabled_devices[d.id] = true
	if "power" in outages:
		say("The power's out: cameras and turrets are dead and the lights are off.")
	if "citinet" in outages:
		say("CitiNet is down here: any call for help will be slow.")
	if "water" in outages:
		say("The water's off.")


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


## Reinforcements for side `team` (faction `fid`), named "<rank> <n>".
func _spawn_wave(roster: Array[String], label: String, team: int, fid: String, rank := "", hardened := false) -> void:
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
		var g := World.npc(dice, fid, roster[i], i + 1, rank, hardened)
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
		if g.alerted or not is_guard(g) or _keeps_peace(g):   # bystanders panic instead; captives and medics don't fight
			continue
		g.alerted = true
		if bool(sides[int(g.team)].opfor):   # a third side's fighters (FreeForAll) raise no alarm of the site's
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
	var p := Attack.preview(_aimer(), weapon, target.c, mode, dist)
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
	_keep_peace(cur, [target.pos])
	_rouse([target])
	_noise(cur.pos)
	var hp_before: int = target.c.hp
	var loc := "head" if mode == Attack.Mode.AIMED_HEAD else "body"
	var sp_before: int = target.c.sp(loc)
	var wound_before: int = target.c.wound_state()
	var ammo_before := weapon.ammo
	var r := Attack.resolve(dice, _aimer(), weapon, target.c, mode, _attack_distance(weapon, p.from, target.pos))
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
	# "Vex → Guard 2 · Autofire · 10 rds · 12 vs 15 · MISS" (the roll against the DV, rounds spent)
	var mname: String = ["Single Shot", "Autofire", "Aimed Shot (head)", "Aimed Shot (leg)", "Aimed Shot (held item)"][mode] if not weapon.is_melee() else "Melee"
	var who := "%s → %s · %s" % [cur.c.display_name, target.c.display_name, mname]
	var rds := maxi(0, ammo_before - weapon.ammo)
	if rds > 1:
		who += " · %d rds" % rds
	if r.get("check") != null:
		who += " · %d vs %d" % [int(r.check.total), int(r.check.dv)]
	if r.dodged:
		say("%s · DODGED" % who)
	elif not r.hit:
		say("%s · MISS" % who)
	else:
		say("%s · HIT %d, %d through%s" % [who, r.damage, r.through, (" · " + ", ".join(r.crits.map(func(x): return x.name))) if not r.crits.is_empty() else ""])
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


## A melee attack on a neighbouring enemy (uses the normal attack, so ROF 2 means two swings),
## with `weapon` (a melee weapon or Brawling) or the first melee weapon carried.
func melee(target: Dictionary, weapon: Weapon = null) -> Dictionary:
	if not adjacent(cur.pos, target.pos):
		return {"ok": false, "reason": "out of reach"}
	return attack(target, weapon if weapon != null else melee_weapon(cur.c), Attack.Mode.SINGLE)


## Ready another carried weapon: it becomes the one in hand (weapons[0]). Drawing an easily
## accessible weapon isn't an Action if you have a free hand (CPR core p.128).
func draw(weapon: Weapon) -> bool:
	if cur.is_empty() or not cur.c.weapons.has(weapon):
		return false
	cur.c.weapons.erase(weapon)
	cur.c.weapons.insert(0, weapon)
	return true


## The attacks a weapon allows, by the book's names (CPR core p.170-177): Single Shot, Aimed Shot
## (head, leg or held item, p.170), Autofire and Suppressive Fire when the weapon has them (p.173-174),
## Shotgun Shell (p.174), shooting the cover in the way (cover has HP, p.182), Melee / Brawling.
## `weapon` null means Brawling. Ids: single, aim_head, aim_leg, aim_held, auto, suppress, shell,
## cover, melee.
static func attack_modes(weapon: Weapon) -> Array[String]:
	if weapon == null or weapon.is_melee():
		return ["melee"]
	var fx: Dictionary = weapon.def.get("fx", {})
	var out: Array[String] = []
	if not fx.get("autofire_only", false) and not fx.get("shell_only", false):
		out.append("single")
		if not fx.get("no_aimed_shot", false):   # a shotgun firing slugs can aim; its shells can't (p.174)
			out.append_array(["aim_head", "aim_leg", "aim_held"])
	if weapon.autofire_mult() > 0:
		out.append("auto")
	if weapon.def.get("suppressive", false):
		out.append("suppress")
	if weapon.def.get("shotgun_shell", false):
		out.append("shell")
	if not fx.get("shell_only", false):
		out.append("cover")
	return out


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
	_keep_peace(cur, targets.map(func(o): return o.pos))
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
	var r := Attack.shotgun_shell(dice, _aimer(), weapon, cone.map(func(o): return o.c))
	if not r.ok:
		return r
	turn.use_action()
	_keep_peace(cur, [target.pos] + cone.map(func(o): return o.pos))
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


## Throw a grenade at a square (p174, p177): DEX + Athletics vs the Grenade Launcher DV for
## the range; a miss scatters the blast somewhere in the 5x5 around the aim point. Damage (6d6) is
## rolled once; cover the blast can't destroy shields whoever is behind it; cover it can destroy is
## destroyed and shields nobody; REF 8+ may dive clear.
## The grenade is the one packed in kit slot `slot` (Items: Armor-Piercing, Incendiary,
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
	_keep_peace(cur, [center])
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
## carry kit too (a Pyro's grenades), packed by their roster rather than from storage.
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
	_keep_peace(cur, [cell])
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
		m.set_t(cell.z, cell.x, cell.y, TacMap.T.FLOOR if cell.z != m.street or m.label(cell.z, cell.x, cell.y) >= 0 else TacMap.T.OUTSIDE)
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
				_retake_turrets()
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
		var dev: Dictionary = m.devices[did]
		if not _unpowered(dev):   # a dead camera stays dead when the runner lets go
			disabled_devices.erase(did)
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
	_retake_turrets()


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
