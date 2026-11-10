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
var site_owner := ""                ## the location's owner faction ("" for none): a venue code's staff (SecurityCode.respondent)
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
var clocks: Array = []              ## Solo Play Clocks running this gig (Clock; Clocks, SPM p.25-26): the detection clock, a Time Limit
var scene_event := {}               ## the street around the gig (SceneEvent, SPM p.77-84): {table, id, label, note, applied, units, ...}
var twist := {}                     ## the gig's plot twist (Twist, SPM p.75-76): {row, id, label, trigger, sprung, round, text, applied}
var _clock_hits := {}               ## clock trigger rate limits (Clocks._limit_key) and reclaims this turn
var _room_rounds := {}              ## crew unit id → [room label, rounds there]: a minute in a secured room (Clocks.round_start)
var _clock_round := -1
var _clock_obj_seen := false        ## the objective trigger has rolled (once a gig)
var _spoofed := {}                  ## device id → true: already fooled for the detection clock (Clocks.spoof, NET loops)
var _twist_busy := false
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
var weather := ""                   ## the mood over the gig now (Atmosphere id; the map's, until a Weather Turns twist): its rules are Weather's
var backup_in := -1                 ## rounds until the site code's response arrives (0: arriving this round; -1 none coming)
var backup_label := "BACKUP"        ## who that is, for the HUD
var alarm_cause := ""               ## why the alarm went up, upper case for the HUD ("CAMERA SPOTTED VEX"); "" while quiet
var _backup_round := 0
var _patrol_round := -1
var reinforcements := true          ## responses on (balance tests switch them off)
var ncpd_in := -1                   ## rounds until the street-level (district code) response (0: arriving this round); -2 once it came
var ncpd_label := "NCPD"
var _ncpd_round := 0
var _response: Dictionary = {}      ## the planned responses: {code, fid, own, label, rank}
var _street: Dictionary = {}
var _hardened_posts := false        ## the posts use Hardened blocks (a Hardened code of the people holding them)
var _spot_rolls := {}               ## [guard id, crew id, round] → result: one stealth roll per pair per round
var jack_pos := {}                  ## runner unit id → the square of the device they jacked in at
var disabled_devices := {}          ## device id → true: off for the site (a camera killed, looped or out of power; a lock opened)
var looped := {}                    ## camera device id → runner unit id: its feed looped from the NET (NetDevices)
var sealed := {}                    ## door cell → true: locked from the NET; the guards' keys don't open it (NetDevices)
var _net_doors := {}                ## door cell → [runner unit id, locked before the NET touched it]
var dev_state := {}                 ## device id → runner unit id: a device switched from the NET (a seal, an alarm line cut)
var dark_rooms := {}                ## room id → runner unit id: its lights killed from the NET
var neutral: NeutralGround = null   ## a house where nobody fights (Totentanz's club floor), null for none
var turret_side := -1               ## the site's automated turrets (Turret); -1 until the map has one
var _crew_turret_side := -1         ## turrets a Netrunner holds; -1 until one does
var _gunner: Combatant = null       ## who aims this attack when not `cur` itself: a Netrunner firing a held turret (fire_turret)
var morale := true                  ## NPCs break at stress points (Morale, SPM p.20-21); balance tests may switch it off
var surrendered := 0                ## units that gave up this gig (Morale): the debrief counts them
var fled := 0                       ## units that ran off the map this gig (Morale)
var loot: Array[Dictionary] = []    ## what the crew found on bodies (CorpseLoot.search): {body, by, table, roll, label, kind, items, eb, lead, keycard, net_code}
var login_codes := 0                ## NET login codes found on bodies: each opens one Password (firewall) on this site's NET without a roll (HOUSE-RULE)


## opts: {faction: the gig's target faction id (World), default generic private security;
## security_code: the site's Security Code (SecurityCode; default the fallback for the map's
## security level); district_code: the street's code ({} for none; default SecurityCode.STREET_FALLBACK);
## guards: whose people hold the posts under the site code (SecurityCode.guarded_by: the target's,
## a contractor's, or "" when the code is an outside authority's; default worked out from the code
## and the target alone); utility_code: the Utility Code (default 0, nothing goes out), rolled
## every time unless utilities: true, which rolls it only on one gig in SecurityCode.UTILITY_CHANCE_IN;
## outages: the utilities out, forced (nothing rolled; the dev gig builder);
## complications: true to roll for one of the book's complications (Complication.CHANCE_IN);
## complication: {tier?, roll?} to force one; twist: the gig's plot twist (Twist: {id, row,
## trigger, ...}, sprung at its trigger); clocks: "auto" runs the detection clock on a stealth gig
## (Clocks.stealth_gig: campaign gigs), true / false always or never (default false: tests and
## tools run none); district: the gig's district, whose civilians make up
## the crowd and the people the objectives need (Recruit.civilian_blocks); owner: the location's
## owner faction, whose people a venue code's staff are (SecurityCode.respondent); neutral_ground /
## free_for_all: a set piece's rules for any map (NeutralGround, FreeForAll; by default the map's
## set piece's own); scene_event: the street round the gig (SceneEvent: {table, id, ...}, rolled
## when the gig started); street_life: false leaves everyday life out (StreetLife; default on)}.
static func setup(p_map: TacMap, p_dice: Dice, crew: Array[Combatant], kind := "data", opts: Dictionary = {}) -> Encounter:
	var e := Encounter.new()
	opts = SetPieces.encounter_opts(p_map, opts)   # a set piece's per-seed variant (an estate's owner) brings its own code
	e.opfor_faction = String(opts.get("faction", World.DEFAULT_OPFOR))
	e.district = String(opts.get("district", ""))
	e.site_owner = String(opts.get("owner", ""))
	if not World.has_faction(e.opfor_faction):
		e.opfor_faction = World.DEFAULT_OPFOR
	e._init_sides()
	e.m = p_map
	e.weather = Atmosphere.of(p_map) if Atmosphere.has_sky(String(p_map.params.get("scene", ""))) else Atmosphere.default_id()   # no weather in the tunnels
	e.dice = p_dice
	SceneEvent.dress(p_map, opts.get("scene_event"))   # its set dressing is cover: on the map before anything reads it
	e.nav = Nav.new(p_map)
	e.los = Los.new(p_map)
	e.init = Initiative.new(p_dice)
	var deploy: Dictionary = p_map.entrances.filter(func(x): return x.kind == "deploy")[0]
	var cells: Array = deploy.get("cells", [deploy.pos])
	for c0 in cells:
		e.extract_cells[Vector3i(c0.x, c0.y, p_map.street)] = true
	for i in crew.size():
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
	# Objective: a module per kind (data/gen/objectives.json); made here so it can say whether the
	# posts are manned at all (defend: the crew holds the place), set up once the guards are posted.
	e.obj = Objective.make(kind, e)
	e.objective = e.obj.o
	if not e.obj.manned():
		roster.clear()
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
	e.obj.setup(target_sid, cells[0], sec)   # the module places what the job needs
	# M3 playtest verdict: guards only join the initiative order once they're alerted.
	for u in e.units:
		if u.alerted:
			e.init.add(u.c)
	e.vision = Vision.new(p_map, e.los)
	if opts.has("outages"):   # forced (the dev gig builder, CustomGig): exactly these, nothing rolled
		e.outages.assign((opts.outages as Array).filter(func(u): return String(u) in SecurityCode.UTILITIES).map(func(u): return String(u)))
	elif not bool(opts.get("utilities", false)) or SecurityCode.utilities_happen(p_dice):
		e.outages = SecurityCode.roll_utilities(p_dice, e.utility_code)
	SceneEvent.pre(e, opts.get("scene_event"))   # a block gone dark
	var wo := Weather.outage(e.weather)   # a storm took the grid down (blackout, NCW p.4)
	if wo != "" and not (wo in e.outages):
		e.outages.append(wo)
	e._apply_outages()
	e._compute_light()
	if e.obj.manned():
		e._outer_patrols(cells[0])
	FreeForAll.place(e, opts.get("free_for_all", SetPieces.rule(p_map, "free_for_all", {})), cells[0])
	e._post_guards()
	if opts.has("complication") or bool(opts.get("complications", false)):
		Complication.start(e, opts.get("complication", {}))
	if bool(e.doctrine.get("keycards", true)):
		e._hand_out_keycards()
	e._trauma_cards()
	e._place_civilians(cells[0])
	SceneEvent.apply(e, opts.get("scene_event"))   # the street around the gig: its crowd, gangs, patrols, callers
	if bool(opts.get("street_life", true)):   # (off: performance comparisons, greybox --life=0)
		StreetLife.place(e, cells[0])   # everyday life: vendors, queues, walkers, patrons
	Twist.arm(e, opts.get("twist"))   # a start twist (Trap Location) places its devices before the turrets mount
	e._mount_turrets()
	for line in SetPieces.briefs(String(p_map.params.get("setpiece", ""))):   # the place's house rules, for the briefing
		e.say(line)
	Clocks.start(e, opts.get("clocks", false))   # the detection clock on a stealth gig (SPM p.25): campaign gigs ask "auto"
	e.refresh_vision()
	e.update_alerts()
	return e


## Recompute crew sight. Returns true if new cells were explored.
## Everyone on the crew who can act sees, the Mortally Wounded included (they still take their
## Turns, p.222: alive() leaves them out, which left a dying crew member blind and unable to aim).
func refresh_vision() -> bool:
	return vision.update(units.filter(func(u): return u.team == CREW and u.c.can_act()).map(func(u): return u.pos), NetDevices.feed_cells(self))


func _add(c: Combatant, pos: Vector3i, team: int) -> void:
	c.team = team
	c.death_saves = team == CREW or team == CAPTIVE   # HOUSE-RULE (NPC_FLATLINE): see _flatline_npcs
	c.heat = Weather.heat(weather)   # a heat wave weighs on everyone's armor (NCW p.5)
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
## turrets; FreeForAll), `spares_crew` (with at_war: a street gang war, SceneEvent._gangs, that
## leaves the crew and anyone standing with it neutral until the crew provokes it: _provoke).
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
			r = "neutral" if _spares(side, o) or _spares(sides[o], t) else "hostile"
		if (o == CREW and opfor) or (t == CREW and bool(sides[o].opfor)):
			r = "hostile"
		if o != t and (ai == "surrendered" or String(sides[o].ai) == "surrendered"):
			r = "neutral"   # out of the fight (Morale): nobody's enemy, nobody's friend
		_rel[Vector2i(t, o)] = r
		_rel[Vector2i(o, t)] = r
	return t


const WAR_AIS := ["crew", "guard", "turret"]   ## the sides an `at_war` side fights (not bystanders or medics)


static func _at_war(a: Dictionary, b: Dictionary) -> bool:
	return (bool(a.get("at_war", false)) and String(b.ai) in WAR_AIS) or (bool(b.get("at_war", false)) and String(a.ai) in WAR_AIS)


## Does `side` (still) leave team `o` alone: a `spares_crew` side not yet provoked, and `o` the crew
## or a side standing with it.
func _spares(side: Dictionary, o: int) -> bool:
	return bool(side.get("spares_crew", false)) and (o == CREW or (sides[o].has("stands_with") and int(sides[o].stands_with) == CREW))


## The crew attacked or hit someone of team `t`: a side that was sparing the crew (a street gang
## war, SceneEvent._gangs) turns on it. It is still not the gig's opposition (objectives, the
## alarm): a neighbourhood's fight, now with the crew in it.
func _provoke(t: int) -> void:
	if not bool(sides[t].get("spares_crew", false)):
		return
	sides[t].spares_crew = false
	set_relation(t, CREW, "hostile")
	say("%s turn on the crew." % SecurityCode.faction_name(String(sides[t].faction)))


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
## backup, and police or MaxTac who join in against the crew). Those who broke (Morale: running
## for the edge, or surrendered onto a side of their own) don't count.
func opfor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in units:
		if bool(sides[int(u.team)].opfor) and not u.c.dead and u.c.wound_state() != Combatant.Wound.MORTAL and not u.has("broke"):
			out.append(u)   # one running for the edge (Morale) is out of the fight: it counts as done
	return out


## Everyone still standing who would shoot `u`.
func foes(u: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in units:
		if o != u and hostile(int(u.team), int(o.team)) and not o.c.dead and o.c.wound_state() != Combatant.Wound.MORTAL and not o.has("broke"):
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
		if init.round_num != _clock_round and state == "playing":   # Solo Play Clocks' top-of-round triggers, then the twist's moment
			_clock_round = init.round_num
			Clocks.round_start(self)
		Twist.poll(self)
		if init.round_num != _civ_round:
			_civ_round = init.round_num
			_civilians_tick()
			SceneEvent.poll(self)
			_tick_trauma()
		if state != "playing":
			return
		turn = TurnState.begin(dice, c)
		net_left = 0
		_netting = false
		_slid_this_turn = false
		if cur.team == OPFOR and cur.alerted and turn.survived and c.can_act():
			call_it_in(cur)
		if not turn.survived:
			say(("%s fails a Death Save and flatlines." if c.death_saves else "%s flatlines.") % c.display_name)
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
			if String(cur.get("broke", "")) == "flee":   # broke at a stress point (Morale): runs for the edge
				AI.flee(self, cur)
				end_turn()
				continue
			if String(sides[cur.team].ai) == "trauma":
				AI.trauma(self, cur)
				end_turn()
				continue
			# A freed hostage (rescue) is the player's to move now, like the crew (playtest round 4: left
			# to the AI they got stuck), so their turn comes back to the player below.
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
	# On fire (Hellhound p207, flamethrower p348): direct damage at the end of each Turn until an
	# Action puts it out (put_out_fire, CPR core p.180). Spending the Action on anything else (a
	# shot, a reload) doesn't: the old rule here did, so a burning shooter never burned.
	if turn != null and not cur.is_empty() and cur.c.burning > 0:
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
	_wreck_turrets()
	_flatline_npcs()
	_check_grapples()
	if state != "playing":
		return
	_count_civ_harm()
	_watch_cardholders()
	if int(tt.get("carrier", -1)) >= 0 and not units[int(tt.carrier)].c.can_act():   # the carrier went down: the patient drops
		var pt: Dictionary = units[int(tt.patient)]
		pt.erase("carried")
		pt.pos = units[int(tt.carrier)].pos
		tt.carrier = -1
	if morale:
		Morale.sweep(self)
	obj.before_check()
	# a freed hostage doesn't count: alone they can't finish the job (nobody to walk them out)
	if units.filter(func(u): return u.team == 0 and not is_hostage(u) and u.c.can_act()).is_empty() \
			and units.filter(func(u): return u.team == 0 and not is_hostage(u) and not u.c.dead and u.c.wake_in > 0).is_empty():
		state = "lost"   # nobody on the crew can act or will wake up (the loop would otherwise spin)
		return
	if not obj.extracting():
		var r := obj.check_end()
		if r == "won":
			_job_done()
		elif r != "":
			state = r
	if state == "playing" and obj.extracting() and _crew_out():
		state = "won"
		say("The crew gets clear. The job's done.")
	if state == "playing":   # the objective taken: the detection clock rolls, a twist may spring
		Clocks.check_objective(self)
		Twist.poll(self)


## The job itself is done (Objective.check_end said "won"): it never ends the gig on the spot
## (owner, playtest v0.10.1). The crew still standing has to reach the extraction zone (or an
## escort's rendezvous: Objective.exit_cells) and leave; _check_end wins it then.
func _job_done() -> void:
	objective["done"] = true
	objective["extract"] = true
	say("The job's done. Get to the extraction zone.")
	events.append({"type": "job_done", "unit": int(cur.get("id", 0)) if not cur.is_empty() else 0})


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
	_witness_attack(by, at)
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


# --- Witnesses: responders who aren't the site's own -------------------------------------------

## HOUSE-RULE (WITNESS): the Security Codes say who answers a call, not how (NC2045 p.7). Anyone
## but the site's own people (the NCPD, a district gang, armed locals) comes to look, not to fight:
## their side is neutral to the crew until one of them witnesses a crime, then it is hostile and
## joins the opposition. A crime: the crew attacking within earshot (GUNFIRE_RANGE, a floor either
## way) or attacking them; a crew member spotted (the guards' Perception vs Stealth, _spots) in a
## restricted area (not in_public) or within sight of a body the crew made; a guard calling in
## the alarm in front of them. Neutral, they walk toward the crew to see (AI._investigate).
func witness_side(fid: String) -> int:
	for t in sides.size():
		if String(sides[t].faction) == fid and bool(sides[t].get("witness", false)):
			return t
	var t := add_side(fid, "guard", false, {"witness": true})
	set_relation(t, CREW, "neutral")
	return t


## A responder still making up their mind about the crew (see witness_side).
func watching(g: Dictionary) -> bool:
	return bool(sides[int(g.team)].get("witness", false)) and not hostile(int(g.team), CREW) and g.c.can_act()


func _witness(t: int, why: String) -> void:
	if hostile(t, CREW):
		return
	set_relation(t, CREW, "hostile")
	sides[t].opfor = true
	say("%s: %s turns on the crew." % [why, SecurityCode.faction_name(String(sides[t].faction))])


func _witness_attack(by: Dictionary, at: Array) -> void:
	if by.is_empty() or not allied(int(by.team), CREW):
		return
	for u in units:
		if u.pos in at and not u.c.dead and not allied(int(u.team), CREW):
			u["crew_hit"] = true   # a body later, if this kills them
			_provoke(int(u.team))   # a gang the crew shoots at (or catches in a blast) is in the fight now
	var spots: Array = at.duplicate()
	spots.append(by.pos)
	for w in units:
		if not watching(w):
			continue
		var hit: bool = w.pos in at
		var heard := spots.any(func(p): return absi(p.z - w.pos.z) <= 1 and Vector2(p.x - w.pos.x, p.y - w.pos.y).length() <= GUNFIRE_RANGE)
		if hit or heard:
			_witness(int(w.team), "%s %s" % [w.c.display_name, "is attacked" if hit else "witnesses an attack"])


## Witnesses who spot a crew member somewhere they shouldn't be, or near a body the crew made.
func _witness_sightings() -> void:
	for w in units:
		if not watching(w):
			continue
		for u in units:
			if u.team != CREW or not u.c.can_act() or not _spots(w, u):
				continue
			if not in_public(u.pos):
				_witness(int(w.team), "%s finds %s trespassing" % [w.c.display_name, u.c.display_name])
			elif _body_in_sight(w):
				_witness(int(w.team), "%s finds %s by a body" % [w.c.display_name, u.c.display_name])
			if not watching(w):
				break


func _body_in_sight(w: Dictionary) -> bool:
	for b in units:
		if not b.get("crew_hit", false) or b.get("fled", false) or not (b.c.dead or b.c.wound_state() == Combatant.Wound.MORTAL):
			continue
		if b.pos.z == w.pos.z and Vector2(b.pos.x - w.pos.x, b.pos.y - w.pos.y).length() <= SPOT_RANGE and los.trace(w.pos, b.pos).clear:
			return true
	return false


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
		if u.has("turret") and not u.get("wrecked", false) and u.c.hp < 1:   # (apply_damage may have flagged it dead already)
			u.c.dead = true
			u["wrecked"] = true
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
	if not check.success:   # a failed Electronics/Security Tech check (SPM p.25 Corporate Heist)
		Clocks.trigger(self, "failed_tech", int(cur.id), "%s fails a bypass" % cur.c.display_name)
	return {"ok": true, "success": check.success, "loud": loud}


func _unlock(cell: Vector3i) -> void:
	nav.locked.erase(cell)
	sealed.erase(cell)
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


## A downed (or surrendered: Morale) guard next to `u` still holding a keycard.
func keycard_in_reach(u: Dictionary) -> Dictionary:
	for g in units:
		if g.has("keycard") and _searchable_state(g) and adjacent(u.pos, g.pos) and g.pos.z == u.pos.z:
			return g
	return {}


## Down (dead, out cold, Mortally Wounded) or surrendered, and still on the map.
func _searchable_state(g: Dictionary) -> bool:
	if _off_map(g) or g.get("carried", false):
		return false
	return g.c.dead or g.c.unconscious or g.c.wound_state() == Combatant.Wound.MORTAL or String(g.get("broke", "")) == "surrender"


## Take a keycard off a downed guard (an Action): every lock of that zone or below opens.
func loot_keycard() -> Dictionary:
	var g := keycard_in_reach(cur)
	if g.is_empty():
		return {"ok": false, "reason": "no keycard on anyone next to you"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	var z: int = g.keycard
	g.erase("keycard")
	var opened := _open_zone(z)
	events.append({"type": "keycard", "unit": cur.id, "from": g.id, "zone": z, "opened": opened})
	say("%s takes a %s keycard: %d door%s unlocked." % [cur.c.display_name, TacMap.ZONE_NAMES[z], opened, "" if opened == 1 else "s"])
	return {"ok": true, "opened": opened}


## The crew holds zone `z`'s keycard: every lock of that zone or below opens. Returns how many.
func _open_zone(z: int) -> int:
	keycards[z] = true
	var opened := 0
	for d in m.devices:
		if String(d.type) == "door_lock" and int(d.zone) <= z:
			var cell := Vector3i(d.pos.x, d.pos.y, d.floor)
			if nav.locked.has(cell):
				_unlock(cell)
				opened += 1
	return opened


# --- Searching bodies (CorpseLoot: SPM p.65-70) ------------------------------------------------

## Whose pockets the crew may go through: anyone not on the crew's side who isn't a bystander,
## a captive or a turret, once they're down (dead, out cold, Mortally Wounded) or have surrendered
## (Morale), and still on the map. Once per body.
func searchable(g: Dictionary) -> bool:
	if g.has("turret") or g.get("civ", false) or g.get("captive", false) or g.get("searched", false):
		return false
	if int(g.team) == CREW or int(g.team) == CAPTIVE:
		return false
	return _searchable_state(g)


## A body `u` stands on or next to that can be searched, or {}.
func body_in_reach(u: Dictionary) -> Dictionary:
	for g in units:
		if g != u and searchable(g) and g.pos.z == u.pos.z and (g.pos == u.pos or adjacent(u.pos, g.pos)):
			return g
	return {}


## Search Body (an Action; SPM p.65): go through the pockets of a body beside the active unit
## (CorpseLoot.search rolls what's there). A keycard opens its doors at once; a NET login code
## is kept for the Netrunner (login_codes); eb, items and leads go home with whoever found them
## (Campaign.resolve, CorpseLoot.kept).
func search_body() -> Dictionary:
	var g := body_in_reach(cur)
	if g.is_empty():
		return {"ok": false, "reason": "no body to search next to you"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	var f := CorpseLoot.search(self, cur, g)
	match String(f.kind):
		"keycard":
			var zones: Array = m.devices.filter(func(d): return String(d.type) == "door_lock").map(func(d): return int(d.zone))
			if zones.is_empty():
				f["opened"] = 0
			else:
				var z: int = zones.max() if String(f.zone) == "high" else zones.min()
				f["opened"] = _open_zone(z)
		"net_code":
			login_codes += 1
	loot.append(f)
	events.append({"type": "search", "unit": cur.id, "body": g.id, "find": f})
	if String(f.kind) == "nothing":
		say("%s searches %s: nothing worth taking." % [cur.c.display_name, g.c.display_name])
	else:
		say("%s searches %s and finds %s." % [cur.c.display_name, g.c.display_name, CorpseLoot.describe(f)])
	return {"ok": true, "find": f}


# --- Withdrawal ------------------------------------------------------------------------

## The crew can cut and run: on their turn, if everyone still on their feet stands in the deploy
## zone. The gig fails (state "fled"); anyone left behind (down or elsewhere) is lost
## (HOUSE-RULE: nobody comes back for them). A freed hostage needn't be there: the crew can abandon
## the rescue (it fails).
func can_withdraw() -> bool:
	if state != "playing" or cur.is_empty() or cur.team != 0:
		return false
	var up := units.filter(func(u): return u.team == 0 and not is_hostage(u) and u.c.can_act())
	return not up.is_empty() and up.all(func(u): return extract_cells.has(u.pos))


## A rescue's freed captive: on the crew's side and the player's to move, but not on the crew
## (no pay, no permadeath, never joins the roster: Campaign only settles its own crew).
func is_hostage(u: Dictionary) -> bool:
	return bool(u.get("captive", false))


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


# --- Morale (Morale: SPM p.20-21) ----------------------------------------------------------

## `u` gives up (Morale.sweep). It moves to a side of its own for its faction, neutral to
## everyone (add_side), so hostile AI leaves it be and it no longer counts as opposition; it
## drops its weapons (there are no items on the ground, so it is just disarmed: `dropped` keeps
## their keys for the view; a weapon built into its chrome stays, unused), lets go of anyone it
## holds and leaves the Initiative order. The crew can still shoot it, a choice the attack preview
## points out (`surrendered` in preview). A keycard it carries can be taken (keycard_in_reach)
## and it can be searched (search_body).
func surrender(u: Dictionary, why := "", roll := 0, thr := 0) -> void:
	_drop_carried_patient(u)
	u["broke"] = "surrender"
	u["side0"] = int(u.team)
	var t := side_for(faction_of(u), "surrendered", false)
	u.team = t
	u.c.team = t
	var dropped: Array = []
	for w in u.c.weapons.duplicate():
		if not w.builtin:
			dropped.append(Items.key_of_weapon(w))
			u.c.weapons.erase(w)
	u["dropped"] = dropped
	var g: Grapple = u.c.grapple
	if g != null and g.holder == u.c:
		g.end()
	u.erase("suppressed_by")
	u.erase("hold")
	init.remove(u.c)
	surrendered += 1
	events.append({"type": "morale", "unit": u.id, "result": "surrender", "why": why, "roll": roll, "threshold": thr})
	say("%s surrenders (morale %d vs %d: %s)." % [u.c.display_name, roll, thr, Morale.why_text(why)])


## `u` breaks and runs (Morale.sweep): from its next turn it heads for the nearest way off the map
## (AI.flee) and is gone there (flee_out). It stays on its side, so the crew can still shoot it,
## but it no longer fights back or counts as opposition (opfor, foes). A sniper leaves its nest.
func start_flight(u: Dictionary, why := "", roll := 0, thr := 0) -> void:
	_drop_carried_patient(u)
	u["broke"] = "flee"
	u.erase("hold")
	var g: Grapple = u.c.grapple
	if g != null and g.holder == u.c:
		g.end()
	events.append({"type": "morale", "unit": u.id, "result": "flee", "why": why, "roll": roll, "threshold": thr})
	say("%s breaks and runs (morale %d vs %d: %s)." % [u.c.display_name, roll, thr, Morale.why_text(why)])


## A fleeing unit reached the edge: gone, unharmed (like a bystander who ran, `fled`). HOUSE-RULE
## (stealth consequence): a guard who gets away while the alarm hasn't been raised (alarm below 2)
## raises it on the way out.
func flee_out(u: Dictionary) -> void:
	if is_guard(u) and alarm < 2 and reinforcements and bool(sides[int(u.team)].opfor):
		say("%s gets clear and raises the alarm." % u.c.display_name)
		call_it_in(u, "%s GOT AWAY" % u.c.display_name)
	u.c.dead = true   # off the map, not killed: the log and `fled` say so
	u["fled"] = true
	init.remove(u.c)
	fled += 1
	events.append({"type": "fled", "unit": u.id})
	say("%s flees the scene." % u.c.display_name)


## A Trauma Team carrier who breaks puts the patient down where they stand.
func _drop_carried_patient(u: Dictionary) -> void:
	if int(tt.get("carrier", -1)) == int(u.id):
		var pt: Dictionary = units[int(tt.patient)]
		pt.erase("carried")
		pt.pos = u.pos
		tt.carrier = -1


## Who broke this gig, for the debrief: {surrendered, fled} (fleeing units still on the map count
## as neither until they're gone).
func morale_counts() -> Dictionary:
	return {"surrendered": surrendered, "fled": fled}


# --- Objective helpers ------------------------------------------------------------------------

## Every crew member still standing is in the extraction zone (or on another of the job's ways out:
## Objective.exit_cells).
func _crew_out() -> bool:
	var up := units.filter(func(u): return u.team == 0 and not u.get("captive", false) and u.c.can_act())
	var out := {}
	for c in obj.exit_cells():
		out[c] = true
	return not up.is_empty() and up.all(func(u): return out.has(u.pos))


## The mark reached an exit (assassination: the AI calls this).
func _vip_escapes(u: Dictionary) -> void:
	if obj.has_method("escape"):
		obj.escape(u)


## Crew actions the objective offers the active unit now ("grab", "free", "plant").
func obj_actions() -> Array[String]:
	var none: Array[String] = []   # typed: a bare [] from a ternary comes back untyped
	return obj.actions() if state == "playing" else none


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
var tt := {}                        ## the Trauma Team call: {patient, round, av, units, carrier, state, on_foot}
var _civ_round := -1
var _counted := {}


## Civilians (HOUSE-RULE): bystanders in the public rooms and on the street, more where people
## gather (bars, clubs, markets), few in the badlands or the tunnels. They take no turns: each round
## the ones that have panicked run for the map edge.
func _place_civilians(deploy: Vector2i) -> void:
	var scene := String(m.params.get("scene", ""))
	if scene in ["badlands", "undercity"]:
		return
	var cand := _crowd_cells(deploy)
	if cand.is_empty():
		return
	var extra := int(SetPieces.rule(m, "civilians", 0))   # a set piece's public floor draws a crowd
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
			if ok and not StreetLife.blocked_spot(self, v):   # never in a 1-wide way through or the objective's rooms
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


## HOUSE-RULE (owner verdict 2026-11-09, "a lot of these bystanders would scatter if there is a
## gunfight"): gunfire or a blast at `at` spooks the bystanders who hear it (a floor either way):
## all of them within PANIC_NEAR squares, fewer the further off (panic_chance), none past
## PANIC_FAR. Each shot is a fresh chance, so a running firefight clears the street round it. Who
## panics scatters their own way (`scatter`, _scatter_way): most run for a way off the map, some
## duck into the nearest public room and cower there, a few freeze where they stand. Deterministic
## (a hash of the unit, the spot and the round), so the gig's own dice never shift.
const PANIC_NEAR := 8.0
const PANIC_FAR := 24.0
const SCATTER_FLEE := 55   ## of 100 outdoors: run for a way out (a street edge, a building's door)
const SCATTER_HIDE := 30   ## of 100 outdoors: into the nearest public room, then cower (the rest cower where they are)
const HIDE_REACH := 20     ## a room further than this (squares of walking) is no shelter: run instead


static func panic_chance(d: float) -> float:
	if d <= PANIC_NEAR:
		return 1.0
	return clampf((PANIC_FAR - d) / (PANIC_FAR - PANIC_NEAR), 0.0, 1.0)


static func _roll100(key: Array) -> int:
	return posmod(hash(key), 100)


func _panic_near(at: Vector3i) -> void:
	var fresh := []
	var rnd := init.round_num if init != null else 0
	for u in units:
		if not u.get("civ", false) or u.panic or u.c.dead or absi(at.z - u.pos.z) > 1:
			continue
		var p := panic_chance(Vector2(at.x - u.pos.x, at.y - u.pos.y).length())
		if p <= 0.0 or (p < 1.0 and _roll100([int(u.id), at, rnd]) >= roundi(p * 100.0)):
			continue
		u.panic = true
		u["scatter"] = _scatter_way(u)
		fresh.append(u.id)
	if not fresh.is_empty():
		events.append({"type": "panic", "unit": fresh[0], "units": fresh})


## How a bystander scatters: "flee" (off the map), "hide" (into the nearest public room, then
## "hidden": cowering there) or "cower" (down where they stand). Indoors, half cower, half run.
func _scatter_way(u: Dictionary) -> String:
	var r := _roll100([int(u.id), "scatter", m.seed_value])
	if not StreetLife.outdoors(m, u.pos):
		return "cower" if r < 50 else "flee"
	if r < SCATTER_FLEE:
		return "flee"
	return "hide" if r < SCATTER_FLEE + SCATTER_HIDE else "cower"


## Is `u` a bystander down and out of it: cowering where they stood, or hidden indoors.
static func cowering(u: Dictionary) -> bool:
	return u.get("civ", false) and u.get("panic", false) and String(u.get("scatter", "")) in ["cower", "hidden"]


## Walking distance to the nearest square a bystander can shelter in: a public room at street
## level (not a corridor, nor the rooms the objective is about), off the 1-wide ways and doorways.
func _shelter_field() -> Dictionary:
	if not has_meta("shelter_seeds"):
		set_meta("shelter_seeds", _shelter_seeds())
	var seeds: Array = get_meta("shelter_seeds")
	return nav.distance_field(seeds, {}, 400) if not seeds.is_empty() else {}


func _shelter_seeds() -> Array:
	var seeds: Array = []
	for y in m.h:
		for x in m.w:
			var l := m.label(m.street, x, y)
			if l < 0:
				continue
			var r: Dictionary = m.rooms[l]
			if bool(r.get("outdoor", false)) or int(r.get("zone", -1)) != TacMap.Zone.PUBLIC or String(r.get("kind", "")) in ["roof", "corridor"]:
				continue
			var v := Vector3i(x, y, m.street)
			if not StreetLife.blocked_spot(self, v):
				seeds.append(v)
	return seeds


## Panicked bystanders scatter each round (up to 10 squares): runners for the nearest way off the
## map (gone there), hiders for the nearest shelter (cowering once in); never stopping in a 1-wide
## way or a doorway when anywhere else gets them closer. Cowering ones stay put.
func _civilians_tick() -> void:
	if not units.any(func(u): return u.get("civ", false) and u.get("panic", false) and not u.c.dead and String(u.get("scatter", "flee")) in ["flee", "hide"]):
		StreetLife.tick(self)   # nobody running: only everyday life moves
		return
	var exits: Array = []
	for en in m.entrances:
		if m.walkable(int(en.get("floor", 0)), en.pos):
			exits.append(Vector3i(en.pos.x, en.pos.y, int(en.get("floor", 0))))
	var field: Dictionary = nav.distance_field(exits, {}, 4000) if not exits.is_empty() else {}
	var shelter: Variant = null
	for u in units:
		if not u.get("civ", false) or not u.panic or u.c.dead or not u.c.can_act():
			continue
		var way := String(u.get("scatter", "flee"))
		if way in ["cower", "hidden"]:
			continue
		var goal := field
		if way == "hide":
			if shelter == null:
				shelter = _shelter_field()
			goal = shelter
			if int(goal.get(u.pos, 9999)) > HIDE_REACH:
				way = "flee"   # nowhere to duck into near enough: run
				u.scatter = way
				goal = field
		if goal.is_empty():
			continue
		var occ := occupied(u)
		var reach: Dictionary = nav.reachable(u.pos, 10, occ)
		var best: Vector3i = u.pos
		var stuck: Vector3i = u.pos   # the closest stop counting 1-wide ways and doorways, if nothing else gets closer
		for cell in reach:
			if occ.has(cell):
				continue
			var d := int(goal.get(cell, 9999))
			if d < int(goal.get(stuck, 9999)):
				stuck = cell
			if d < int(goal.get(best, 9999)) and (d == 0 or not (StreetLife.is_choke(m, cell) or StreetLife.by_door(m, cell))):
				best = cell
		if best == u.pos:
			best = stuck
		if best != u.pos:
			var path: Array[Vector3i] = nav.path(u.pos, best, occ)
			var full: Array = [u.pos]
			full.append_array(path)
			u.pos = best
			events.append({"type": "move", "unit": u.id, "path": full, "run": true})
		if int(goal.get(u.pos, 9999)) == 0:
			if way == "hide":
				u.scatter = "hidden"   # in, and down out of sight of the street
			else:
				u.c.dead = true   # gone off the map, unharmed
				u["fled"] = true
				events.append({"type": "civ_gone", "unit": u.id})
	StreetLife.tick(self)


func _count_civ_harm() -> void:
	for u in units:
		if u.get("civ", false) and not u.get("fled", false) and not _counted.has(u.id) and (u.c.dead or not u.c.can_act()):
			_counted[u.id] = true
			# HOUSE-RULE: with a scene event on the street (SceneEvent: a gang war, a psycho, a Trauma
			# Team client already down), only the bystanders the crew hurt are the crew's to answer for.
			if not scene_event.is_empty() and not u.get("crew_hit", false):
				continue
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


## HOUSE-RULE (NPC_FLATLINE, owner's call, for pace): NPCs make no Death Saves (p.222 gives
## everyone them): one under 1 HP flatlines at once. Attack.apply_damage does it for attacks; this
## sweep catches the rest (fire, strain, brain damage). Kept: the crew; a rescue's captive (the job
## needs them alive, and the crew can stabilise them). Trauma Team cardholders flatline like any
## other NPC (owner's call), but the card still calls the team, who come for the body
## (_watch_cardholders). Combatant.death_saves marks who rolls.
func _flatline_npcs() -> void:
	for u in units:
		if not u.c.death_saves and not u.c.dead and u.c.hp < 1 and not u.has("turret"):
			u.c.dead = true


## A cardholder going down, or flatlining (the card's biomonitor pings either way), calls Trauma
## Team, who arrive TT_ROUNDS rounds later and take the patient, alive or dead, away.
func _watch_cardholders() -> void:
	if not tt.is_empty():
		return
	for u in units:
		if u.get("trauma_card", false) and not u.c.can_act() and not _off_map(u):
			tt = {"patient": u.id, "round": init.round_num + TT_ROUNDS, "state": "called"}
			events.append({"type": "tt_call", "unit": u.id})
			say("%s's Trauma Team card pings. An AV is on its way." % u.c.display_name)
			return


## Gone from the map (ran off, got away, already flown out): nobody left to collect.
func _off_map(u: Dictionary) -> bool:
	return u.get("fled", false) or u.get("escaped", false)


## The AV sets down near the patient (the body, if they've flatlined) and three responders get out.
## With nowhere to land (HOUSE-RULE: the book has no rule for it) they come in on foot at the map
## entrance nearest the patient and carry them out the same way; `tt.av` is then that entrance.
func _tick_trauma() -> void:
	if tt.get("state", "") != "called" or init.round_num < int(tt.round):
		return
	var patient: Dictionary = units[int(tt.patient)]
	if _off_map(patient):
		tt.state = "cancelled"
		return
	var spot := av_spot(patient.pos, 2, 30)
	if spot.x >= 0:
		var ids := _responders("trauma_team", TT_TEAM, _av_exits(spot, 3), 3)
		for id in ids:
			units[id]["tt"] = true
		tt.merge({"state": "landed", "av": spot, "av_fit": av_fit.duplicate(), "units": ids, "carrier": -1, "on_foot": false}, true)
		events.append({"type": "av_land", "unit": ids[0] if not ids.is_empty() else 0, "kind": "trauma", "cell": spot, "units": ids, "yaw": av_fit.yaw, "scale": av_fit.scale})
		say("Trauma Team lands. Stay out of their way.")
		return
	var gate := _tt_gate(patient.pos)
	if gate.x < 0:
		tt.state = "cancelled"
		return
	var reach: Dictionary = _keys(func(): return nav.reachable(gate, 6, occupied()))
	var cells: Array = reach.keys().filter(func(v): return v.z == gate.z)
	cells.sort_custom(func(a, b): return int(reach[a]) < int(reach[b]))
	var ids := _responders("trauma_team", TT_TEAM, cells, 3)
	if ids.is_empty():
		tt.state = "cancelled"
		return
	for id in ids:
		units[id]["tt"] = true
	tt.merge({"state": "landed", "av": gate, "units": ids, "carrier": -1, "on_foot": true}, true)
	events.append({"type": "backup", "unit": ids[0], "units": ids, "label": "TRAUMA TEAM"})
	say("Nowhere to land: Trauma Team comes in on foot. Stay out of their way.")


## The walkable map entrance nearest `near` (the team's way in and out on foot), or (-1, -1, -1).
func _tt_gate(near: Vector3i) -> Vector3i:
	var best := Vector3i(-1, -1, -1)
	var bd := INF
	for en in m.entrances:
		var v := Vector3i(en.pos.x, en.pos.y, int(en.get("floor", 0)))
		var d := Vector2(v.x - near.x, v.y - near.y).length() + absi(v.z - near.z) * 4.0
		if m.walkable(v.z, Vector2i(v.x, v.y)) and d < bd:
			bd = d
			best = v
	return best


## Trauma Team got the patient (or the body) aboard, or out the gate on foot: they're gone.
## Only a live patient counts as saved (Objective.on_evacuated); a body is just a body.
func tt_depart() -> void:
	var foot := bool(tt.get("on_foot", false))
	for id in tt.get("units", []):
		units[id].c.dead = true
		units[id]["fled"] = true
		if foot:
			events.append({"type": "civ_gone", "unit": id})
	var patient: Dictionary = units[int(tt.patient)]
	var alive_out: bool = not patient.c.dead
	patient.c.dead = true
	patient["fled"] = true
	patient["extracted"] = true
	patient.erase("carried")
	tt.state = "gone"
	var who: String = patient.c.display_name if alive_out else "%s's body" % patient.c.display_name
	if foot:
		events.append({"type": "civ_gone", "unit": int(tt.patient)})
		say("Trauma Team carries %s out." % who)
	else:
		events.append({"type": "av_leave", "unit": int(tt.patient), "kind": "trauma", "cell": tt.av})
		say("The Trauma Team AV lifts off with %s." % who)
	if alive_out:
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
	_keep_peace(units[by] if by >= 0 and by < units.size() else {}, [center] + caught.map(func(o): return o.pos))
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
## through the distance field), off guard posts and cover. `min_room`: only in a room (not a
## corridor) with at least that many squares one can stand on (defend: a room to hold), when the
## building has one.
func secure_cell(target_sid: int, origin: Vector2i, role := "", min_room := 0) -> Vector3i:
	var field: Dictionary = nav.distance_field([Vector3i(origin.x, origin.y, m.street)], {})
	var size := {}   # room label → standable squares (min_room only)
	if min_room > 0:
		for cell in field:
			var l0 := m.label(cell.z, cell.x, cell.y)
			if l0 >= 0 and m.rooms[l0].get("kind", "") != "corridor" and not m.has_cover_at(cell.z, Vector2i(cell.x, cell.y)):
				size[l0] = int(size.get(l0, 0)) + 1   # a corridor is a way through, not a room
		if not size.keys().any(func(k): return int(size[k]) >= min_room and m.rooms[k].structure == target_sid):
			size = {}
			min_room = 0
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
				or m.has_cover_at(cell.z, Vector2i(cell.x, cell.y)) or (min_room > 0 and int(size.get(l, 0)) < min_room):
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
				g["why_next"] = "%s SAW %s" % [g.c.display_name, u.c.display_name]
				break
	_witness_sightings()
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
	if not check.success:   # a failed Electronics/Security Tech check (SPM p.25 Corporate Heist)
		Clocks.trigger(self, "failed_tech", int(cur.id), "%s fumbles a camera" % cur.c.display_name)
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
## per camera, crew member and round. A hit rouses the nearest unalerted guard, who calls the
## alarm in on their turn. Looping their feed (the Loop NET action) turns them off; holding the
## node only gives the runner the feed - the netrunner's job in a stealth gig.
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
				if _spot_rolls[key]:   # a failed Stealth check (SPM p.25 Corporate Heist)
					Clocks.trigger(self, "failed_stealth", int(u.id), "a camera catches %s" % u.c.display_name)
			if _spot_rolls[key]:
				var best: Dictionary = {}
				for g in units:
					if is_guard(g) and hostile(int(g.team), CREW) and not sides[int(g.team)].get("at_war", false) and not g.alerted and not g.c.dead and (best.is_empty() or Vector3(g.pos - cp).length() < Vector3(best.pos - cp).length()):
						best = g
				if not best.is_empty():
					say("A camera catches %s. %s is on the way." % [u.c.display_name, best.c.display_name])
					best["why_next"] = "CAMERA SPOTTED %s" % u.c.display_name
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
	base -= Weather.sight_penalty(m, weather, g.pos, u.pos)   # rain, dust, ash, smog out in the open (NCW p.4-5)
	var sneak: int = u.c.skill_base("stealth") - u.c.action_penalty()
	var key := [g.id, u.id, init.round_num if init else 0]   # HOUSE-RULE: one contest per guard, sneaker and round
	if not _spot_rolls.has(key):
		_spot_rolls[key] = Check.opposed(dice, base, sneak).success
		if _spot_rolls[key] and int(u.team) == CREW and bool(sides[int(g.team)].opfor) and hostile(int(g.team), CREW):   # a failed Stealth check (SPM p.25)
			Clocks.trigger(self, "failed_stealth", int(u.id), "%s fails to slip past %s" % [u.c.display_name, g.c.display_name])
	return _spot_rolls[key]


## HOUSE-RULE (set pieces with `public_access`: Ziggurat's museum floor, Fort Sumter's petition
## floor): while no alarm is up, crew in the public rooms of the ground floor or out on the open
## street and grounds pass as visitors; guards only take them for intruders past the first
## restricted door (any room above the public zone, any upper floor). HOUSE-RULE (towers, stage 1a):
## a tower band has it too: its lowest storey's public rooms (the sky lobby the lift car opens onto,
## a hotel's lift lobby and guest corridor) take visitors who come up with an appointment, so a
## crew stepping out of the car is not an intruder until it passes a restricted door.
var _public_access = null   ## the set piece's rule, read once


func passing_as_public(u: Dictionary) -> bool:
	if _public_access == null:
		_public_access = bool(SetPieces.rule(m, "public_access", false)) or m.is_tower()
	if alarm > 0 or not _public_access or int(u.get("team", CREW)) != CREW:
		return false
	return in_public(u.pos)


## Open to anyone: the street-level floor's outdoors and doorways, and its public rooms. Anywhere
## else (an upper floor, a basement, past the first restricted door) is restricted.
func in_public(p: Vector3i) -> bool:
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
		if is_dark(c):   # its lights killed from the NET (NetDevices)
			continue
		var r := float(e.range) * 0.6
		for dy in range(-int(r), int(r) + 1):
			for dx in range(-int(r), int(r) + 1):
				var v := Vector3i(c.x + dx, c.y + dy, c.z)
				if Vector2(dx, dy).length() <= r and m.inb(v.x, v.y) and not lit.has(v) and not is_dark(v) and los.trace(c, v).clear:
					lit[v] = true
	if day:
		for y in m.h:
			for x in m.w:
				if m.t(m.street, x, y) == TacMap.T.OUTSIDE and m.label(m.street, x, y) < 0:
					lit[Vector3i(x, y, m.street)] = true


## A room whose lights were killed from the NET (NetDevices "lights").
func is_dark(v: Vector3i) -> bool:
	if dark_rooms.is_empty() or not m.inb(v.x, v.y):
		return false
	var l := m.label(v.z, v.x, v.y)
	return l >= 0 and dark_rooms.has(l)


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
func call_it_in(g: Dictionary, why := "") -> void:
	if alarm >= 2 or g.c.dead or not reinforcements:
		return
	alarm = 2
	_set_alarm_cause(why if why != "" else String(g.get("alert_why", "")), g)
	for w in units:   # a raised alarm in front of a witness is a crime they saw
		if watching(w) and w.pos.z == g.pos.z and Vector2(w.pos.x - g.pos.x, w.pos.y - g.pos.y).length() <= SPOT_RANGE and los.trace(w.pos, g.pos).clear:
			_witness(int(w.team), "%s sees %s call in the alarm" % [w.c.display_name, g.c.display_name])
	# The radio call rouses guards within the doctrine's radio range of the caller: the rest hold posts.
	var radio := float(doctrine.alarm.radio_range)
	_rouse(units.filter(func(o): return is_guard(o) and allied(int(o.team), int(g.team)) and not o.alerted and not o.c.dead and Vector2(o.pos.x - g.pos.x, o.pos.y - g.pos.y).length() <= radio))
	_backup_round = init.round_num
	_ncpd_round = init.round_num
	var slow := 2 if "citinet" in outages else 1   # OWNER-ACCEPTED: CitiNet out doubles response time
	if NetDevices.alarm_cut(self):   # HOUSE-RULE: the alarm line cut from the NET, the call goes by radio alone: as slow
		slow *= 2
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
	events.append({"type": "alarm", "unit": g.id, "rounds": backup_in, "cause": alarm_cause})
	Clocks.on_alarm(self)   # the detection clock is moot now (an alarm twist springs at the next turn: Twist.poll)


## Record why the alarm went up and say so in the log (owner, playtest v0.10.1: the detection clock
## gave way to an ALARM line with no reason given). `why` upper case, or "" for `g` calling it in.
func _set_alarm_cause(why: String, g: Dictionary = {}) -> void:
	if alarm_cause != "":
		return
	if why == "":
		why = ("%s RAISED IT" % g.c.display_name) if not g.is_empty() else "THE SITE IS ON TO YOU"
	alarm_cause = why.to_upper()
	say("Alarm: %s." % why_line(alarm_cause))


## The cause in a log line: "GUARD 3 SAW VEX" -> "Guard 3 saw Vex" (names keep their capitals).
func why_line(why: String) -> String:
	var out := why.to_lower()
	for u in units:
		var nm := String(u.c.display_name)
		out = out.replace(nm.to_lower(), nm)
	return out.left(1).to_upper() + out.substr(1)


## Who a code sends: the site's own people (the target's, or the contractor holding the posts) come
## as BACKUP on the opposition's side; anyone else on their own side (World.relation decides
## whether they also go after the guards). A faction not in factions.json yet turns up as generic
## security under its printed name. Who answers is rolled now (SecurityCode.respondent): one of a
## two-responder code's factions; for a venue's code its owner's people, a district gang or armed
## locals (`civilians`: the district's civilian blocks, _arrive).
func _plan_response(c: Dictionary) -> Dictionary:
	var who := SecurityCode.respondent(dice, c, site_owner, World.district(district).get("gangs", []))
	var fid := String(who.faction)
	var known := World.has_faction(fid)
	var spawn_fid := fid if known else World.DEFAULT_OPFOR
	var own := fid == opfor_faction or spawn_fid == opfor_faction or fid == post_faction
	var rank := "Backup"
	if not own:
		rank = String(World.responder(spawn_fid).get("rank", "")) if known else SecurityCode.faction_name(fid)
	return {"code": c, "fid": spawn_fid, "own": own, "rank": rank, "civilians": bool(who.civilians),
		"label": "BACKUP" if own else SecurityCode.faction_name(fid).to_upper()}


## Once a round: the countdowns tick toward arrival. A response lands the round its count reaches 0
## and the count stays at 0 for that round (the HUD's ARRIVING), then clears: -1 for the site's
## response, -2 (once per gig) for the street's.
func _tick_backup() -> void:
	if ncpd_in >= 0 and init.round_num != _ncpd_round:
		_ncpd_round = init.round_num
		if ncpd_in == 0:
			ncpd_in = -2
		else:
			ncpd_in -= 1
			if ncpd_in == 0:
				_arrive(_street)
	if backup_in < 0 or init.round_num == _backup_round:
		return
	_backup_round = init.round_num
	if backup_in == 0:
		backup_in = -1
		return
	backup_in -= 1
	if backup_in == 0:
		_arrive(_response)


## A planned response turns up at the far entrance, sized by its code's intensity for the crew
## still standing (SecurityCode.response_roster), Hardened if the code is. Armed locals
## (`civilians`, HOUSE-RULE: a venue's patrons or the people about) are the district's civilian
## blocks with their printed weapons as the Mooks; their officers come from the locals' roster.
func _arrive(r: Dictionary) -> void:
	if r.is_empty():
		return
	var roster := SecurityCode.response_roster(dice, r.code, maxi(1, alive(CREW).size()))
	var team := OPFOR if bool(r.own) else witness_side(String(r.fid))
	var civ: Array[String] = Recruit.civilian_blocks(district) if bool(r.get("civilians", false)) else ([] as Array[String])
	_spawn_wave(roster, String(r.label), team, String(r.fid), String(r.rank), bool(r.code.get("hardened", false)), civ)
	if bool(r.get("sting", false)) and team != OPFOR:   # a police sting (Twist): they came for the crew
		_witness(team, "A police sting")


# --- Weather (Weather, data/gen/atmospheres.json) ------------------------------------------

## The weather turns mid-gig (the Weather Turns twist, Weather.turn): mood `id` from now on, its
## heat on everyone's armor; a `weather` event lets the view change the sky, the rain and the air.
func set_weather(id: String) -> void:
	if not Atmosphere.has(id) or id == weather:
		return
	var was := weather
	weather = id
	for u in units:
		u.c.heat = Weather.heat(weather)
	events.append({"type": "weather", "unit": Clocks._anchor(self), "mood": id, "was": was})


# --- Utility Codes (NC2045 p.8) ------------------------------------------------------------

const POWERED := ["camera", "turret"]


## Is the power out? The lights are off and cameras and turrets dead.
func lights_out() -> bool:
	return "power" in outages


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
## `civ`: civilian blocks (Recruit.civilian_blocks) the wave's Mooks are drawn from instead.
## `at`: where they step onto the map (defend's waves pick their entry), else arrival_cell().
func _spawn_wave(roster: Array[String], label: String, team: int, fid: String, rank := "", hardened := false, civ: Array[String] = [], at := Vector3i(-1, -1, -1)) -> void:
	var spawn := at if at.x >= 0 else arrival_cell()
	if spawn.x < 0:
		return
	var arrived := []
	var reach: Dictionary = _keys(func(): return nav.reachable(spawn, 6, occupied()))
	var occ := occupied()   # never onto someone already there (the entry itself can be taken)
	var cells: Array = reach.keys().filter(func(v): return v.z == spawn.z and not occ.has(v))
	cells.sort_custom(func(a, b): return int(reach[a]) < int(reach[b]))
	for i in mini(roster.size(), cells.size()):
		var g: Combatant
		if not civ.is_empty() and roster[i] == "mook":
			g = Recruit.civilian(dice, civ[dice.d(civ.size()) - 1], "%s %d" % [rank if rank != "" else "Local", i + 1])
			g.faction = World.faction(fid).id
		else:
			g = World.npc(dice, fid, roster[i], i + 1, rank, hardened)
		_add(g, cells[i], team)
		var u: Dictionary = units[-1]
		u.alerted = true
		init.add(g)
		arrived.append(u.id)
	say("%s arrives: %d more." % [label.capitalize(), arrived.size()])
	if not arrived.is_empty():
		events.append({"type": "backup", "unit": arrived[0], "units": arrived, "label": label})


## Where people sent to the site step onto the map (responders, a complication's arrivals), or
## (-1, -1, -1): on an ordinary map the entrance farthest from the crew (the far street edge). In a
## tower band (TacMap.is_tower: there is no street) they come out of the lift car or up the fire
## stair (TowerGen `arrival` entrances) on the storey most of the crew is on, whichever of those is
## farther from the crew and free; with both taken, the nearest storey that has one free.
func arrival_cell() -> Vector3i:
	var crew := alive(CREW)
	var crew_c := Vector2.ZERO
	for u in crew:
		crew_c += Vector2(u.pos.x, u.pos.y)
	crew_c /= maxf(1.0, crew.size())
	var spawn := Vector3i(-1, -1, -1)
	if m.is_tower():
		var on := {}
		for u in crew:
			on[u.pos.z] = int(on.get(u.pos.z, 0)) + 1
		var floor_z := m.street
		for z in on:
			if int(on[z]) > int(on.get(floor_z, 0)) or (int(on[z]) == int(on.get(floor_z, 0)) and int(z) < floor_z):
				floor_z = int(z)
		var occ := occupied()
		var best_s := INF
		for en in m.entrances:
			if not en.has("arrival"):
				continue
			var v := Vector3i(en.pos.x, en.pos.y, int(en.floor))
			if occ.has(v) or not m.walkable(v.z, Vector2i(v.x, v.y)):
				continue
			var s := absi(v.z - floor_z) * 1000.0 - Vector2(v.x, v.y).distance_to(crew_c)
			if s < best_s:
				best_s = s
				spawn = v
		return spawn
	var best := -1.0
	for en in m.entrances:
		var v := Vector3i(en.pos.x, en.pos.y, int(en.floor))
		var dd := Vector2(v.x, v.y).distance_to(crew_c)
		if en.kind != "deploy" and dd > best and m.walkable(v.z, Vector2i(v.x, v.y)):
			best = dd
			spawn = v
	return spawn


## Gunfire at `at` alerts guards within GUNFIRE_RANGE on any floor.
func _noise(at: Vector3i) -> void:
	_panic_near(at)
	if not cur.is_empty() and int(cur.team) == CREW:   # the crew's gunfire or blast: the detection clock rolls (Clocks)
		Clocks.trigger(self, "noise", int(cur.id), "%s makes noise" % cur.c.display_name)
	# HOUSE-RULE: a scene event's fighters (SceneEvent: a gang war, a psycho) shooting on the street
	# don't put the site on alert: a firefight a block off is the neighbourhood's, not the crew's.
	var street: bool = not cur.is_empty() and bool(cur.get("street_event", false))
	var fresh := []
	for g in units:
		if street and bool(sides[int(g.team)].opfor):
			continue
		if not g.alerted and not g.c.dead and Vector2(at.x - g.pos.x, at.y - g.pos.y).length() <= GUNFIRE_RANGE \
				and absi(at.z - g.pos.z) <= 1:
			fresh.append(g)
	_rouse(fresh, "SHOTS HEARD")


## Alert `fresh` (and whoever of theirs is within shouting range). `why`: what put them on alert,
## upper case for the alarm callout ("GUARD 3 SAW VEX", "SHOTS HEARD"); it rides on the unit
## (`alert_why`) so a later call to the alarm can say why (call_it_in). By default, the crew's
## active unit attacking them.
func _rouse(fresh: Array, why := "") -> void:
	if why == "" and not cur.is_empty() and allied(int(cur.team), CREW):
		why = "%s ATTACKED" % cur.c.display_name
	var q := fresh.duplicate()
	while not q.is_empty():
		var g: Dictionary = q.pop_front()
		if g.alerted or not is_guard(g) or _keeps_peace(g):   # bystanders panic instead; captives and medics don't fight
			continue
		g.alerted = true
		var because := String(g.get("why_next", why)).to_upper()   # its own reason (spotted, a camera), else the call's
		g.erase("why_next")
		g["alert_why"] = because
		if bool(sides[int(g.team)].opfor):   # a third side's fighters (FreeForAll) raise no alarm of the site's
			alarm = maxi(alarm, 1)
		init.add(g.c)
		events.append({"type": "alert", "unit": g.id})
		for o in units:
			if not o.alerted and not o.c.dead and is_guard(o) and allied(int(o.team), int(g.team)) and o.pos.z == g.pos.z \
					and Vector2(o.pos.x - g.pos.x, o.pos.y - g.pos.y).length() <= float(doctrine.alarm.shout_range):
				if not o.has("why_next"):
					o["why_next"] = because   # shouted to: the same reason
				q.append(o)


func engaged() -> bool:
	return units.any(func(u): return is_guard(u) and hostile(int(u.team), CREW) and u.alerted and not u.c.dead and _near_crew(u))


## A scene event's fighters (SceneEvent: gangs at war, a cyberpsycho) count as engaging the crew
## only once they're within spotting range of one of them; a gang war three blocks off isn't.
func _near_crew(u: Dictionary) -> bool:
	if not u.get("street_event", false):
		return true
	return units.any(func(c): return int(c.team) == CREW and c.c.can_act() and c.pos.z == u.pos.z and Vector2(c.pos.x - u.pos.x, c.pos.y - u.pos.y).length() <= SPOT_RANGE)


# --- Movement ----------------------------------------------------------------------

## Guards carry the keys to their own security doors; the crew needs them hacked or shot open.
## Trauma Team gets the site's override with the subscriber's contract (HOUSE-RULE: else a patient
## behind a locked door could never be collected).
func _with_locks(callable: Callable) -> Variant:
	var saved := nav.locked
	if not cur.is_empty() and cur.get("tt", false):
		nav.locked = {}
	elif not cur.is_empty() and is_guard(cur):
		nav.locked = sealed   # a door locked from the NET keeps them out too (NetDevices)
	var r: Variant = callable.call()
	nav.locked = saved
	return r


## Paths for guards outside their own turn (patrols, posting): they have the keys.
func _keys(callable: Callable) -> Variant:
	var saved := nav.locked
	nav.locked = sealed
	var r: Variant = callable.call()
	nav.locked = saved
	return r


func move_options() -> Dictionary:
	var opts: Dictionary = _with_locks(func(): return nav.reachable(cur.pos, turn.squares_available(), _blocking(cur)))
	for v in occupied(cur):   # you can pass allies but not stop on them
		opts.erase(v)
	return opts


## Every square the active unit could still end on this turn by also spending its Action on a Run
## (p127, p169: another Move Action's worth); includes move_options(). {} once the Action is spent.
func run_options() -> Dictionary:
	if cur.is_empty() or turn == null or not _can_run():
		return {}
	var budget: int = turn.squares_available() + cur.c.stat("MOVE")
	var opts: Dictionary = _with_locks(func(): return nav.reachable(cur.pos, budget, _blocking(cur)))
	for v in occupied(cur):
		opts.erase(v)
	return opts


## Run needs the Action and a Move Action taken first (TurnState.run; move_to takes the first leg).
func _can_run() -> bool:
	return turn.action_available and (turn.moved_this_turn or turn.move_actions > 0)


## The squares a move to `dest` would walk, starting with the unit's own, for the path preview:
## [] unless move_to(dest, allow_run) would take it there (a Run only with `allow_run`).
func move_preview(dest: Vector3i, allow_run := true) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if state != "playing" or cur.is_empty() or turn == null or occupied(cur).has(dest) or dest == cur.pos:
		return out
	var p: Array[Vector3i] = _with_locks(func(): return nav.path(cur.pos, dest, _blocking(cur)))
	if p.is_empty():
		return out
	var cost := nav.cost_of(cur.pos, p)
	var reach: int = turn.squares_available() + (cur.c.stat("MOVE") if allow_run and _can_run() else 0)
	if cost > reach:
		return out
	out.append(cur.pos)
	out.append_array(p)
	return out


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
	_drag(cur, full)   # whoever they hold comes along (p.177)
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
	var sh := shield_for(target, weapon, mode, s.from)   # a Human Shield takes the shot (p.184)
	var wm := 0 if weapon.is_melee() else -Weather.ranged_penalty(m, weather, s.from, target.pos, dist)   # a shot through the weather (NCW p.4-5)
	var p := Attack.preview(_aimer(), weapon, sh.c if not sh.is_empty() else target.c, mode, dist, wm)
	p["from"] = s.from
	p["weather"] = wm
	p["blocker"] = s.blocker
	if not sh.is_empty():
		p["shield"] = sh.id
	match String(target.get("broke", "")):   # Morale: shooting someone who gave up (or is running) is the crew's choice; the view says so
		"surrender":
			p["surrendered"] = true
		"flee":
			p["fleeing"] = true
	return p


func attack(target: Dictionary, weapon: Weapon, mode: Attack.Mode) -> Dictionary:
	var p := preview(target, weapon, mode)
	if not p.ok:
		return {"ok": false, "reason": p.reason}
	if not turn.take_attack(weapon, mode != Attack.Mode.SINGLE or weapon.rof() < 2):
		return {"ok": false, "reason": "no action left" if turn.attacks_left <= 0 else "the second attack must be a single 2 ROF attack"}
	if int(target.team) == TT_TEAM and cur.team == CREW:
		tt_hostile = true
		set_relation(TT_TEAM, CREW, "hostile")
	_keep_peace(cur, [target.pos])
	_rouse([target])
	_noise(cur.pos)
	if p.has("shield"):   # the Human Shield takes it instead (p.184): the attack goes into them
		var sh: Dictionary = units[int(p.shield)]
		say("%s's human shield %s takes the shot." % [target.c.display_name, sh.c.display_name])
		if sh.c.dead:
			return _attack_corpse(target, sh, weapon, mode, p)
		target = sh
	var hp_before: int = target.c.hp
	var loc := "head" if mode == Attack.Mode.AIMED_HEAD else "body"
	var sp_before: int = target.c.sp(loc)
	var wound_before: int = target.c.wound_state()
	var ammo_before := weapon.ammo
	var r := Attack.resolve(dice, _aimer(), weapon, target.c, mode, _attack_distance(weapon, p.from, target.pos), int(p.get("weather", 0)))
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


## An attack stopped by a corpse shield (p.183-184): the event the view plays, the log line.
func _attack_corpse(target: Dictionary, sh: Dictionary, weapon: Weapon, mode: Attack.Mode, p: Dictionary) -> Dictionary:
	var ammo_before := weapon.ammo
	var r := _hit_corpse(sh, weapon, mode, p)
	events.append({"type": "attack", "unit": cur.id, "target": target.id, "from": p.from, "hit": false, "dodged": false, "damage": 0, "through": 0,
		"location": "body", "sp_before": target.c.sp("body"), "sp_after": target.c.sp("body"), "crit": false, "crit_names": [],
		"wound_before": target.c.wound_state(), "wound_after": target.c.wound_state(), "mult": 1, "rounds": maxi(1, ammo_before - weapon.ammo),
		"mode": mode, "weapon": weapon.id(), "dead": target.c.dead, "killed": false, "shielded": r.hit, "shield_left": int(r.get("shield_left", -1))})
	var ck: Check = r.check
	say("%s → %s · corpse shield · %d vs %d · %s" % [cur.c.display_name, target.c.display_name, ck.total, ck.dv,
		("%d into the body (%d HP left)" % [r.damage, int(r.shield_left)]) if r.hit else "MISS"])
	_check_end()
	return r


## Ready another carried weapon: it becomes the one in hand (weapons[0]). Drawing an easily
## accessible weapon isn't an Action if you have a free hand (CPR core p.128).
func draw(weapon: Weapon) -> bool:
	if cur.is_empty() or not cur.c.weapons.has(weapon):
		return false
	cur.c.weapons.erase(weapon)
	cur.c.weapons.insert(0, weapon)
	return true


# --- Grappling (CPR core p.168-169, p.177, p.184; Grapple) -----------------------------------

## The grappling actions open to the active unit, in bar order (the HUD shows these; grapple_act
## runs them): get_up while Prone; escape while held; choke, throw, shield, release while holding
## (release alone once it's a corpse shield); grab with a foe in reach; break an ally's hold.
func grapple_options() -> Array[String]:
	var out: Array[String] = []
	if cur.is_empty() or turn == null:
		return out
	var c: Combatant = cur.c
	if c.prone:
		out.append("get_up")
	if c.is_grappled():
		out.append("escape")
	elif c.is_grappling():
		if c.grapple.live():
			out.append_array(["choke", "throw"])
			if not c.grapple.shield:
				out.append("shield")
		out.append("release")
	elif not grab_targets(cur).is_empty():
		out.append("grab")
	if c.grapple == null and not break_targets(cur).is_empty():
		out.append("break")
	if c.burning > 0:   # not close quarters, but the same kind of only-when-it-applies bar entry
		out.append("put_out")
	return out


## Put Out Fire (CPR core p.180, docs/rules/combat.md "Being On Fire"): spend the Action beating
## the flames out; On Fire ends and does no more damage. Meat only: a Netrunner's NET Actions
## don't (their body's still burning).
func put_out_fire() -> Dictionary:
	if cur.is_empty() or turn == null or cur.c.burning <= 0:
		return {"ok": false, "reason": "not on fire"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	cur.c.burning = 0
	events.append({"type": "put_out", "unit": cur.id})
	say("%s beats out the flames." % cur.c.display_name)
	return {"ok": true}


## Foes `u` could Grab: in reach (a neighbouring square, p.177 / MELEE_ADJACENT_M), people (not
## turrets), free to be grabbed (Grapple.why_not).
func grab_targets(u: Dictionary) -> Array:
	return units.filter(func(o): return o != u and not o.has("turret") and hostile(int(u.team), int(o.team)) \
		and adjacent(u.pos, o.pos) and Grapple.why_not(u.c, o.c) == "")


## Allies held by someone `u` can reach: anyone may break a hold (p.177).
func break_targets(u: Dictionary) -> Array:
	return units.filter(func(o): return o != u and o.c.is_grappled() and allied(int(u.team), int(o.team)) \
		and adjacent(u.pos, unit_of(o.c.grapple.holder).pos))


## The other end of `u`'s grapple as a unit, or {}.
func grapple_partner(u: Dictionary) -> Dictionary:
	if u.is_empty() or u.c.grapple == null:
		return {}
	return unit_of(u.c.grapple.other(u.c))


## Why the active unit can't Grab `target` ("" if it can).
func grab_why_not(target: Dictionary) -> String:
	if target.is_empty() or target == cur:
		return "pick a neighbouring foe"
	if target.has("turret"):
		return "nothing to get hold of"
	if not adjacent(cur.pos, target.pos):
		return "out of reach"
	if not turn.action_available:
		return "no action left"
	return Grapple.why_not(cur.c, target.c)


## The hit-chance popup for a Grab: {ok, reason, chance, base, defense_base}.
func grab_preview(target: Dictionary) -> Dictionary:
	var why := grab_why_not(target)
	if why != "":
		return {"ok": false, "reason": why, "chance": 0.0}
	return {"ok": true, "reason": "", "chance": Grapple.grab_chance(cur.c, target.c), "base": Grapple.base(cur.c), "defense_base": Grapple.base(target.c)}


## Grab (p.168, p.177): an Action; DEX + Brawling + 1d10 against the target's, ties to them. It
## needs a free hand: a two-handed weapon in hand is slung and the first one-handed weapon carried
## drawn (drawing is free, p.128; RULES-UNVERIFIED: slinging a long arm as part of the Grab).
## Only grabbing hold of the person is modelled, not taking an object they hold (p.177).
func grapple(target: Dictionary) -> Dictionary:
	var why := grab_why_not(target)
	if why != "":
		return {"ok": false, "reason": why}
	turn.use_action()
	_free_hand(cur.c)
	_hostile_act(target)
	var wb: int = target.c.wound_state()
	var r := Grapple.grab(dice, cur.c, target.c)
	var ck: Check = r.check
	events.append({"type": "grapple", "kind": "grab", "unit": cur.id, "target": target.id, "success": r.success,
		"roll": ck.total, "dv": ck.dv, "wound_before": wb, "wound_after": wb})
	say("%s → %s · Grab · %d vs %d · %s" % [cur.c.display_name, target.c.display_name, ck.total, ck.dv, "GRAPPLED" if r.success else "BROKE FREE"])
	return {"ok": true, "success": r.success}


func _free_hand(c: Combatant) -> void:
	if c.weapons.is_empty() or int(c.weapons[0].def.get("hands", 1)) < 2:
		return
	for w in c.weapons:
		if int(w.def.get("hands", 1)) < 2:
			c.weapons.erase(w)
			c.weapons.insert(0, w)
			return


## Laying hands on someone is an attack for the peace, the witnesses and the guards.
func _hostile_act(target: Dictionary) -> void:
	if int(target.team) == TT_TEAM and cur.team == CREW:
		tt_hostile = true
		set_relation(TT_TEAM, CREW, "hostile")
	_keep_peace(cur, [target.pos])
	_rouse([target])


## Choke (p.168, p.177): an Action on the one you hold; your BODY straight to their HP (Grapple.choke).
func choke() -> Dictionary:
	var g: Grapple = cur.c.grapple
	if g == null or g.holder != cur.c or not g.live():
		return {"ok": false, "reason": "not holding anyone"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	var t := unit_of(g.held)
	var wb: int = t.c.wound_state()
	var was_out: bool = t.c.unconscious
	var r := g.choke(init.round_num)
	_flatline_npcs()
	events.append({"type": "grapple", "kind": "choke", "unit": cur.id, "target": t.id, "damage": r.damage, "ko": r.knocked_out and not was_out,
		"chokes": g.chokes, "wound_before": wb, "wound_after": t.c.wound_state(), "dead": t.c.dead})
	say("%s chokes %s · %d to HP%s" % [cur.c.display_name, t.c.display_name, r.damage, " · UNCONSCIOUS" if r.knocked_out and not was_out else ""])
	_check_end()
	return {"ok": true, "damage": r.damage, "knocked_out": r.knocked_out}


## Throw (p.169, p.177): an Action; your BODY straight to their HP, the grapple ends and they land
## Prone. RULES-UNVERIFIED (the book doesn't place them): in a free square beside you, as far from
## where they stood as there is (over the shoulder), else where they stand.
func throw_foe() -> Dictionary:
	var g: Grapple = cur.c.grapple
	if g == null or g.holder != cur.c or not g.live():
		return {"ok": false, "reason": "not holding anyone"}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	var t := unit_of(g.held)
	var wb: int = t.c.wound_state()
	var from: Vector3i = t.pos
	var occ := occupied(t)
	var land := from
	var far := -1.0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var v := Vector3i(cur.pos.x + dx, cur.pos.y + dy, cur.pos.z)
			if v == cur.pos or occ.has(v) or not nav.open(v) or not adjacent(cur.pos, v):
				continue
			var d := Vector2(v.x - from.x, v.y - from.y).length()
			if d > far:
				far = d
				land = v
	t.pos = land
	var r := g.throw_down()
	_flatline_npcs()
	events.append({"type": "grapple", "kind": "throw", "unit": cur.id, "target": t.id, "damage": r.damage, "from": from, "to": land,
		"wound_before": wb, "wound_after": t.c.wound_state(), "dead": t.c.dead})
	say("%s throws %s · %d to HP · PRONE" % [cur.c.display_name, t.c.display_name, r.damage])
	update_alerts()
	_check_end()
	return {"ok": true, "damage": r.damage, "to": land}


## Human Shield (p.169, p.184): an Action; the one you hold becomes cover against ranged attacks
## you can see coming, except Aimed Shots at your head (shield_for). They can't dodge them.
func human_shield() -> Dictionary:
	var g: Grapple = cur.c.grapple
	if g == null:
		return {"ok": false, "reason": "not holding anyone"}
	var why := g.shield_why_not(cur.c)
	if why != "":
		return {"ok": false, "reason": why}
	if not turn.use_action():
		return {"ok": false, "reason": "no action left"}
	g.shield = true
	var t := unit_of(g.held)
	events.append({"type": "grapple", "kind": "shield", "unit": cur.id, "target": t.id})
	say("%s holds %s up as a human shield." % [cur.c.display_name, t.c.display_name])
	return {"ok": true}


## Release (p.177, p.184): letting go is free; dropping a corpse shield takes an Action.
func release() -> Dictionary:
	var g: Grapple = cur.c.grapple
	if g == null or g.holder != cur.c:
		return {"ok": false, "reason": "not holding anyone"}
	if not g.live() and not turn.use_action():
		return {"ok": false, "reason": "dropping a corpse shield takes an Action"}
	var t := unit_of(g.held)
	g.end()
	events.append({"type": "grapple", "kind": "release", "unit": cur.id, "target": t.id})
	say("%s lets go of %s." % [cur.c.display_name, t.c.display_name])
	return {"ok": true}


## The hit-chance popup for breaking a hold: {ok, reason, chance}. `target` is the ally to free
## ({}: your own escape).
func escape_preview(target: Dictionary = {}) -> Dictionary:
	var held: Dictionary = cur if target.is_empty() else target
	if not held.c.is_grappled():
		return {"ok": false, "reason": "nobody's holding them", "chance": 0.0}
	if held != cur and not break_targets(cur).has(held):
		return {"ok": false, "reason": "can't reach whoever holds them", "chance": 0.0}
	if not turn.action_available:
		return {"ok": false, "reason": "no action left", "chance": 0.0}
	return {"ok": true, "reason": "", "chance": held.c.grapple.escape_chance(cur.c)}


## Escape (p.177): an Action and a won Grab roll against the one holding; the held one or anyone
## else in reach of the holder (RULES-UNVERIFIED: reach for a third party, as for a Grab).
func escape_grapple(target: Dictionary = {}) -> Dictionary:
	var p := escape_preview(target)
	if not p.ok:
		return p
	var held: Dictionary = cur if target.is_empty() else target
	var g: Grapple = held.c.grapple
	var holder := unit_of(g.holder)
	turn.use_action()
	if held != cur:
		_hostile_act(holder)
	var r := g.escape(dice, cur.c)
	var ck: Check = r.check
	if r.success and held == cur:
		turn.freed()
	events.append({"type": "grapple", "kind": "escape", "unit": cur.id, "target": holder.id, "freed": held.id, "success": r.success, "roll": ck.total, "dv": ck.dv})
	say("%s %s %s's hold · %d vs %d" % [cur.c.display_name, "breaks" if r.success else "fails to break", holder.c.display_name, ck.total, ck.dv])
	return {"ok": true, "success": r.success}


## Get Up (p.168): an Action; Prone, you have no Move Action until you do (TurnState.get_up).
func get_up() -> Dictionary:
	if not cur.c.prone:
		return {"ok": false, "reason": "not prone"}
	if not turn.get_up():
		return {"ok": false, "reason": "no action left"}
	events.append({"type": "get_up", "unit": cur.id})
	say("%s gets up." % cur.c.display_name)
	return {"ok": true}


## Run one of grapple_options() by id; `target` for grab and break.
func grapple_act(id: String, target: Dictionary = {}) -> Dictionary:
	match id:
		"grab": return grapple(target)
		"choke": return choke()
		"throw": return throw_foe()
		"shield": return human_shield()
		"release": return release()
		"escape": return escape_grapple()
		"break": return escape_grapple(target)
		"get_up": return get_up()
		"put_out": return put_out_fire()
	return {"ok": false, "reason": "unknown action"}


## The Attacker's Move Action drags the Defender along (p.177): they end on the last square of the
## path behind the mover that's free, else any free square beside them. With nowhere to put them
## the hold is lost (RULES-UNVERIFIED). Dragging costs no extra movement (RULES-UNVERIFIED).
func _drag(mover: Dictionary, full: Array) -> void:
	var t := grapple_partner(mover)
	if t.is_empty() or not mover.c.is_grappling():
		return
	var occ := occupied(t)
	var dest: Vector3i = mover.pos
	var cand: Array = []
	for i in range(full.size() - 2, -1, -1):
		cand.append(full[i])
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			cand.append(Vector3i(dest.x + dx, dest.y + dy, dest.z))
	for v: Vector3i in cand:
		if v != dest and not occ.has(v) and nav.open(v) and adjacent(dest, v):
			var trail: Array = [t.pos]
			var idx := full.find(v)
			trail.append_array(full.slice(0, idx + 1) if idx >= 0 else full.slice(0, full.size() - 1))
			if idx < 0:
				trail.append(v)
			t.pos = v
			events.append({"type": "move", "unit": t.id, "path": trail, "run": false, "dragged": true})
			return
	say("%s loses hold of %s." % [mover.c.display_name, t.c.display_name])
	mover.c.grapple.end()
	events.append({"type": "grapple", "kind": "broken", "unit": mover.id, "target": t.id})


## Grapples that can't go on (checked after everything): the holder can't act (out cold, down);
## the held one dies (a Human Shield becomes a corpse shield, anyone else is let go); the two are
## no longer side by side. RULES-UNVERIFIED: p.177 lists only the ways to end a grapple on purpose.
func _check_grapples() -> void:
	for u in units:
		var g: Grapple = u.c.grapple
		if g == null or g.holder != u.c:
			continue
		var t := unit_of(g.held)
		if g.live() and g.held.dead and u.c.can_act():
			if g.held_died():
				say("%s holds on to %s's body: a corpse shield." % [u.c.display_name, g.held.display_name])
				continue
		elif u.c.dead or not u.c.can_act() or (g.live() and not adjacent(u.pos, t.pos)):
			g.end()
		else:
			continue
		if u.c.grapple == null:
			events.append({"type": "grapple", "kind": "broken", "unit": u.id, "target": t.id})


## A Human Shield between `target` and an attack on them from `from` (p.184): the target holds one
## that still covers and sees the attacker, and the attack is ranged and not an Aimed Shot at the
## head. Returns the shield's unit or {}. RULES-UNVERIFIED: area attacks (shells, blasts,
## suppression) ignore it.
func shield_for(target: Dictionary, weapon: Weapon, mode: Attack.Mode, from: Vector3i) -> Dictionary:
	if target.is_empty() or not target.c.is_grappling() or weapon.is_melee() or mode == Attack.Mode.AIMED_HEAD:
		return {}
	var g: Grapple = target.c.grapple
	if not g.covers() or _aimer() == g.held or not los.sight(target.pos, from).visible:
		return {}
	return unit_of(g.held)


## A shot into a corpse shield (p.183-184): it can't dodge, and on a hit it takes the whole attack
## as HP damage. Returns an Attack.resolve-like result.
func _hit_corpse(sh: Dictionary, weapon: Weapon, mode: Attack.Mode, p: Dictionary) -> Dictionary:
	var g: Grapple = sh.c.grapple
	if weapon.uses_ammo():
		weapon.spend(weapon.autofire_ammo() if mode == Attack.Mode.AUTOFIRE else 1)
	var check := Check.vs_dv(dice, int(p.base), int(p.dv))
	var r := {"ok": true, "hit": check.success, "check": check, "damage": 0, "through": 0, "location": "body", "crits": [], "dodged": false}
	if check.success:
		var dmg := 0
		if mode == Attack.Mode.AUTOFIRE:
			dmg = dice.roll(2, 6) * mini(check.total - check.dv, weapon.autofire_mult())
		else:
			dmg = dice.roll(weapon.dice(), 6)
		r.damage = dmg
		r["shield_left"] = g.hit_corpse(dmg)
	return r


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
## Who Suppressive Fire from `u` reaches (p.174): foes on foot (not turrets), in sight within 25 m and
## out of cover (nothing solid beside them on u's side, AI.covered_from).
func suppress_targets(u: Dictionary) -> Array:
	return foes(u).filter(func(o): return Los.distance_m(u.pos, o.pos) <= Attack.SUPPRESSIVE_RANGE_M and los.sight(u.pos, o.pos).visible \
			and not o.has("turret") and not AI.covered_from(self, o.pos, [u]))


func suppress(weapon: Weapon) -> Dictionary:
	if not turn.action_available:
		return {"ok": false, "reason": "no action left"}
	var targets := suppress_targets(cur)
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
	_keep_peace(cur, [center] + caught.map(func(o): return o.pos))   # everyone caught: a stray blast provokes a gang too
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
	if Attack.grapple_reason(weapon, cur.c) != "":
		return {"ok": false, "reason": Attack.grapple_reason(weapon, cur.c)}
	if not turn.take_attack(weapon, weapon.rof() < 2):
		return {"ok": false, "reason": "no action left" if turn.attacks_left <= 0 else "the second attack must be a single 2 ROF attack"}
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
		sealed.erase(cell)
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
	return los.wall_between(a, b)


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


## The NET Actions net_action takes (each has a hover card in data/rules/net_help.json; sword and
## armor activate those Programs).
const NET_ACTIONS: Array[String] = ["backdoor", "control", "eye_dee", "zap", "cross", "jack_out", "sword", "armor", "slide", "pathfinder"]


## NET Actions (p198). kind: backdoor | control | eye_dee | zap | cross | jack_out. Moving between
## nodes is free (run.move_to). A turn spent in the NET forgoes the meat Action (p197).
func net_action(kind: String, arg: int = -1) -> Dictionary:
	var run: NetRun = runs.get(cur.id)
	if kind == "jack_out_unsafe" and run != null:   # pull the plug: no Action needed, Kraken or not, but every ICE met hits (p198)
		say("%s pulls the plug." % cur.c.display_name)
		_drop_run(cur.id, true)
		return {"ok": true}
	if kind not in NET_ACTIONS:
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
			if login_codes > 0:   # HOUSE-RULE: a login code off a body (CorpseLoot) opens this Password, no roll
				login_codes -= 1
				run.broken[n.id] = true
				say("%s keys in a login code from a body: the Password opens." % cur.c.display_name)
				return {"ok": true, "success": true, "login_code": true}
			var c := run.backdoor(dice)
			say("Backdoor %s." % ("succeeds" if c.success else "fails"))
			return {"ok": true, "success": c.success}
		"control":   # take the Node (p199); its devices are then worked one NET Action each (net_device)
			var c2 := run.control(dice)
			events.append({"type": "net_control", "unit": cur.id, "node": int(n.id), "devices": (n.get("devices", []) as Array).duplicate(), "ok": c2.success, "roll": c2.total, "dv": int(n.dv)})
			if c2.success:
				say("%s takes the %s node: %s." % [cur.c.display_name, String(n.group).replace("_", " "), _devices_text(n)])
				_retake_turrets()
			else:
				say("%s fails to take the %s node (%d vs DV %d)." % [cur.c.display_name, String(n.group).replace("_", " "), c2.total, int(n.dv)])
			return {"ok": true, "success": c2.success}
		"eye_dee":   # what the File is and what it is worth (p199)
			var c3 := run.eye_dee(dice)
			var target: bool = int(objective.get("node", -2)) == int(n.id) and run.arch.structure == int(objective.get("structure", -2))
			var info := NetDevices.file_info(self, n)
			events.append({"type": "eye_dee", "unit": cur.id, "node": int(n.id), "ok": c3.success, "what": info.what, "value": info.value, "tier": info.tier, "target": target, "roll": c3.total, "dv": int(n.dv)})
			if c3.success:
				say("Eye-Dee: %s, value %d/5 (%s)%s." % [info.what, int(info.value), info.tier, obj.net_line() if target else ""])
				if target:
					objective.done = true
			else:
				say("Eye-Dee fails (%d vs DV %d)." % [c3.total, int(n.dv)])
			_check_end()
			return {"ok": true, "success": c3.success, "what": info.what, "value": info.value, "tier": info.tier, "target": target}
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


## The devices on Control Node `n` in words ("3 cameras, door lock").
func _devices_text(n: Dictionary) -> String:
	var count := {}
	var order: Array[String] = []
	for did in n.get("devices", []):
		var k := String(m.devices[did].type)
		if not count.has(k):
			order.append(k)
		count[k] = int(count.get(k, 0)) + 1
	var parts: Array[String] = []
	for k in order:
		var nm := String(NetDevices.spec(k).get("name", k.replace("_", " ")))
		parts.append("%d %s%s" % [int(count[k]), nm, "" if nm.ends_with("s") else "s"] if int(count[k]) > 1 else nm)
	return ", ".join(parts) if not parts.is_empty() else "nothing wired to it"


## The held Control Nodes of runner `uid` and what can be done with each (NetDevices.rows).
func device_ops(uid: int) -> Array:
	return NetDevices.rows(self, uid)


## Who holds device `did` through the NET (a runner's unit id), -1 for nobody.
func device_holder(did: int) -> int:
	return NetDevices.holder(self, did)


## Work a device on a held Control Node (p199): a NET Action, from anywhere in the Architecture,
## each Node once per Turn (shared with its turrets' FIRE). `did` names the device (any one of a
## bank: NetDevices). What it does is data/rules/net_devices.json.
func net_device(nid: int, did: int) -> Dictionary:
	var run: NetRun = runs.get(cur.id)
	if run == null or net_left <= 0:
		return {"ok": false, "reason": "no NET Actions left"}
	if not _netting and not turn.action_available:   # the meat Action is spent: no NET this turn (p197)
		return {"ok": false, "reason": "your Action is spent"}
	if not run.held.has(nid) or did < 0 or did >= m.devices.size() or not (run.arch.nodes[nid].get("devices", []) as Array).has(did):
		return {"ok": false, "reason": "not on a node you hold"}
	var d: Dictionary = m.devices[did]
	var op := String(NetDevices.spec(String(d.type)).get("op", ""))
	if op == "" or op == "fire":
		return {"ok": false, "reason": "nothing to work remotely" if op == "" else "fire it from its FIRE row"}
	if int(run.activated.get(nid, -1)) == init.round_num:
		return {"ok": false, "reason": "node already used this turn"}   # each Node once per Turn (p199)
	var why := NetDevices.why_not(self, d, NetDevices.is_on(self, d))
	if why != "":
		return {"ok": false, "reason": why}
	turn.action_available = false
	_netting = true
	net_left -= 1
	run.activated[nid] = init.round_num
	var r := NetDevices.operate(self, int(cur.id), nid, did)
	say(String(r.text))
	events.append({"type": "net_device", "unit": cur.id, "node": nid, "device": did, "kind": String(d.type), "op": r.op, "on": r.on, "devices": r.devices, "cells": r.cells})
	Clocks.on_net_device(self, did, String(r.op), bool(r.on))   # looping cameras or cutting the alarm wins time back (SPM p.26)
	refresh_vision()
	return r


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
	var had := run.held.size()
	runs.erase(uid)   # the nodes go first: NetDevices.release asks who still holds what
	NetDevices.release(self, uid)
	runs[uid] = run
	if had > 0:
		say("%s's hold on %d node%s is lost: the site has its devices back." % [units[uid].c.display_name, had, "" if had == 1 else "s"])
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
