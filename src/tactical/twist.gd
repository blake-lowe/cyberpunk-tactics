class_name Twist
extends RefCounted
## Plot Twists (Cyberpunk RED: Single Player Mode, SPM p.75-76; the Mission Builder's step 5,
## SPM p.28): the gig layer's surprise, beside the Hardened complication tables (the opposition
## layer, Complication). Data: data/gen/twists.json (all 50 rows by the book's d100 positions, our
## own labels; a row plays when it has no `unmodelled` and only FX keys).
##
## When an offer is made (MissionBuilder.twist) the Oracle is asked whether the job takes a turn
## (HOUSE-RULE likelihood by security level, twists.json `chance`): on a plain yes a row is rolled
## among those that play and fit the gig's objective, and its trigger fixed (a round range is
## rolled): gig.twist = {row, roll, id, label, trigger, oracle}, hidden (never on the board card).
## In the encounter (arm, poll, spring) it springs once at its trigger and applies its fx; the crew
## learns of it then (a callout, the log, the round tab) and the debrief names it.
##
## FX (what Twist implements):
## - units {side: opfor | rival | ally, blocks, n: [lo, hi], rank, at: far | deploy}: people arrive
##   (the opposition's, a rival crew at war with everyone, FreeForAll-style, or a stranger on the
##   crew's side, run by the AI);
## - extraction "move": the deploy zone closes as a way out; the extraction point moves to the
##   entrance farthest from it;
## - response {code, rounds: [lo, hi]}: that code's people (NCPD) come in 0-2 rounds, hostile on arrival;
## - response_mult: the response timers counting down are scaled (halved);
## - mark "flee": the mark is tipped off and runs for an exit;
## - tier_up "target": the mark (else the opposition's strongest) steps up a tier, in place;
## - clock: a Solo Play Clock starts (Clocks.add: time_limit);
## - devices {camera: n, turret: n}: extra devices in the target building (start only: the view
##   builds devices with the map).

const FX := ["units", "extraction", "response", "response_mult", "mark", "tier_up", "clock", "devices"]
const TRIGGERS := ["objective_done", "round", "alarm", "start"]
const NONE := "none"
const NEXT_TIER := {"mook": "lieutenant", "lieutenant": "mini_boss", "mini_boss": "mini_boss", "boss": "boss"}


static func db() -> Dictionary:
	return RulesDB.gen("twists.json")


static func rows() -> Array:
	return db().rows


## The row whose id is `key`, or whose d100 range holds the number `key` ({} none).
static func row(key: String) -> Dictionary:
	for r in rows():
		if String(r.id) == key:
			return r
	if key.is_valid_int():
		var n := int(key)
		for r in rows():
			if n >= int(r.roll[0]) and n <= int(r.roll[1]):
				return r
	return {}


## Does the game play this row? No `unmodelled`, and every fx key one Twist implements.
static func enabled(r: Dictionary) -> bool:
	if r.is_empty() or r.has("unmodelled"):
		return false
	var fx: Dictionary = r.get("fx", {})
	return not fx.is_empty() and fx.keys().all(func(k): return String(k) in FX)


## Does row `r` fit a gig of `objective` (its `objectives`, absent: any)?
static func fits(r: Dictionary, objective: String) -> bool:
	var obs: Array = r.get("objectives", [])
	return obs.is_empty() or objective in obs


static func enabled_rows(objective := "") -> Array:
	return rows().filter(func(r): return enabled(r) and (objective == "" or fits(r, objective)))


# --- The roll at offer time (MissionBuilder.twist) -------------------------------------------

## The Oracle's likelihood that a job at security `level` (1-3) takes a turn.
static func likelihood(level: int) -> String:
	return String((db().chance.likelihood as Dictionary).get(str(clampi(level, 1, 3)), "unlikely"))


## The exact chance a job at `level` gets a twist (the answers that count, at its likelihood).
static func chance(level: int) -> float:
	var lk := likelihood(level)
	var p := 0.0
	for a in db().chance.answers:
		p += Oracle.chance(lk, String(a))
	return p


## Ask the Oracle for a job at `level`: Oracle.ask's answer plus `twist` (it counts).
static func ask(dice: Dice, level: int) -> Dictionary:
	var a := Oracle.ask(dice, likelihood(level))
	a["twist"] = String(a.outcome) in (db().chance.answers as Array)
	return a


## A row for an `objective` job: roll the d100 (SPM p.75-76) until a row that plays and fits comes
## up (as the Mission Types step does); after 100 misses the first that fits. {} if none fits.
static func roll_row(dice: Dice, objective: String) -> Array:
	var ok := enabled_rows(objective)
	if ok.is_empty():
		return []
	var ids := ok.map(func(r): return String(r.id))
	for i in 100:
		var n := dice.d(100)
		var r := row(str(n))
		if String(r.get("id", "")) in ids:
			return [r, n]
	return [ok[0], int(ok[0].roll[0])]


## The gig's twist from row `r` (rolled `n`): {row, roll, id, label, trigger}; a round range in the
## trigger is rolled now. `on`: a trigger to use instead ("start", "alarm", "objective_done",
## "round<n>").
static func make(dice: Dice, r: Dictionary, n := -1, on := "") -> Dictionary:
	var t: Dictionary = (r.get("trigger", {"on": "objective_done"}) as Dictionary).duplicate(true)
	if on != "":
		t = parse_trigger(on)
	if t.get("n") is Array:
		var lh: Array = t.n
		t["n"] = int(lh[0]) + dice.d(int(lh[-1]) - int(lh[0]) + 1) - 1
	elif t.has("n"):
		t["n"] = int(t.n)
	if t.has("or_round"):
		t["or_round"] = int(t.or_round)
	return {"row": int(r.roll[0]), "roll": n if n > 0 else int(r.roll[0]), "id": String(r.id), "label": String(r.label), "trigger": t}


## "start" / "alarm" / "objective_done" / "round3" as a trigger dict.
static func parse_trigger(s: String) -> Dictionary:
	if s.begins_with("round"):
		return {"on": "round", "n": maxi(1, int(s.substr(5)))}
	return {"on": s if s in TRIGGERS else "objective_done"}


## The twist step (MissionBuilder.twist): null, or a hidden twist for `gig`. `force` (the dev
## builder, CustomGig): "none", "" / "auto" (the Oracle, as a board offer), or "<id or d100
## roll>[@<trigger>]" for that row.
static func roll(dice: Dice, gig: Dictionary, force := "") -> Variant:
	if force == NONE:
		return null
	var ob := Campaign.objective_for(gig)
	if force != "" and force != "auto":
		var r := row(force.get_slice("@", 0))
		if r.is_empty():
			return null
		return make(dice, r, -1, force.get_slice("@", 1) if force.contains("@") else "")
	var a := ask(dice, int(gig.get("security", 1)))
	if not bool(a.twist):
		return null
	var picked := roll_row(dice, ob)
	if picked.is_empty():
		return null
	var t := make(dice, picked[0], int(picked[1]))
	t["oracle"] = String(a.outcome)
	return t


## Is `t` a twist in the saved shape (or null)?
static func valid(t: Variant) -> bool:
	if t == null:
		return true
	if not t is Dictionary:
		return false
	var r := row(String(t.get("id", "")))
	var tr: Variant = t.get("trigger")
	return enabled(r) and tr is Dictionary and String(tr.get("on", "")) in TRIGGERS and int(t.get("row", -1)) == int(r.roll[0])


# --- In the encounter ---------------------------------------------------------------------------

## Take the gig's twist into the encounter (Encounter.setup, before the turrets are mounted): a
## `start` twist springs now.
static func arm(e: Encounter, spec: Variant) -> void:
	if not spec is Dictionary or (spec as Dictionary).is_empty():
		return
	var r := row(String(spec.get("id", "")))
	if not enabled(r):
		return
	e.twist = (spec as Dictionary).duplicate(true)
	e.twist["sprung"] = false
	if String((e.twist.get("trigger", {}) as Dictionary).get("on", "")) == "start":
		spring(e)


## Has the twist's moment come? (Encounter: every turn, after an end check, when the alarm goes up.)
static func due(e: Encounter) -> bool:
	var t: Dictionary = e.twist.get("trigger", {})
	var rn := e.init.round_num if e.init else 0
	var hit := false
	match String(t.get("on", "")):
		"start":
			hit = true
		"round":
			hit = rn >= int(t.get("n", 1))
		"alarm":
			hit = e.alarm >= 2
		"objective_done":
			hit = e.obj != null and e.obj.near_done()
	return hit or (t.has("or_round") and rn >= int(t.or_round))


static func poll(e: Encounter) -> void:
	if e.twist.is_empty() or bool(e.twist.get("sprung", false)) or e.state != "playing" or e._twist_busy:
		return
	if due(e):
		spring(e)


## The twist happens: its fx, a log line, a `twist` event for the view's callout. Records
## {sprung, round, text, applied, skipped} on e.twist.
static func spring(e: Encounter) -> void:
	if e.twist.is_empty() or bool(e.twist.get("sprung", false)):
		return
	e._twist_busy = true
	var r := row(String(e.twist.id))
	e.twist["sprung"] = true
	e.twist["round"] = e.init.round_num if e.init else 0
	e.twist["note"] = String(r.get("note", ""))
	var out := {"applied": [], "skipped": [], "lines": [], "units": []}
	var ev := {"type": "twist", "unit": Clocks._anchor(e), "id": String(e.twist.id), "label": String(e.twist.label),
		"note": String(r.get("note", "")), "text": ""}
	e.events.append(ev)   # before the arrivals, so the callout plays first
	var fx: Dictionary = r.get("fx", {})
	for k in fx:
		match String(k):
			"units": _units(e, fx.units, out)
			"extraction": _extraction(e, out)
			"response": _response(e, fx.response, out)
			"response_mult": _response_mult(e, float(fx.response_mult), out)
			"mark": _mark_flees(e, out)
			"tier_up": _tier_up(e, out)
			"clock":
				var c := Clocks.add(e, String(fx.clock))
				out.applied.append("clock")
				out.lines.append("%s: %dd6 on the clock." % [c.label.capitalize(), c.size])
			"devices": _devices(e, fx.devices, out)
			_:
				out.skipped.append(String(k))
	var text := " ".join(out.lines)
	e.twist["text"] = text
	e.twist["applied"] = out.applied
	e.twist["skipped"] = out.skipped
	e.twist["units"] = out.units
	ev["text"] = text
	ev["units"] = out.units
	ev["cells"] = e.extract_cells.keys() if "extraction" in out.applied else []
	e.say("Plot twist: %s. %s %s" % [String(e.twist.label), String(r.get("note", "")).capitalize(), text])
	e._twist_busy = false


## One line for the round tab once it has sprung ("" before): "TWIST · HEAVIES CALLED IN".
static func hud_line(e: Encounter) -> String:
	if e.twist.is_empty() or not bool(e.twist.get("sprung", false)):
		return ""
	var s := "TWIST · " + String(e.twist.label).to_upper()
	if String(e.twist.id) == "police_sting" and e.ncpd_in > 0:
		s += " · %s IN %d" % [e.ncpd_label, e.ncpd_in]
	return s


# --- FX ---------------------------------------------------------------------------------------

static func _n(e: Encounter, v: Variant) -> int:
	if v is Array:
		var a: Array = v
		return int(a[0]) + e.dice.d(int(a[-1]) - int(a[0]) + 1) - 1
	return int(v)


## People arrive: on the opposition's side, a rival crew at war with everyone, or a stranger
## fighting beside the crew (an AI-run side allied to it, hostile to all who are hostile to it).
static func _units(e: Encounter, spec: Dictionary, out: Dictionary) -> void:
	var side := String(spec.get("side", "opfor"))
	var blocks: Array = spec.get("blocks", ["boosterganger"])
	var rank := String(spec.get("rank", "Hostile"))
	var n := _n(e, spec.get("n", [2, 3]))
	var fid := e.post_faction
	var team := Encounter.OPFOR
	match side:
		"rival":
			var gangs: Array = (World.district(e.district).get("gangs", []) as Array).filter(func(g): return World.has_faction(String(g)) and String(g) != e.opfor_faction and String(g) != e.post_faction)
			fid = String(gangs[e.dice.d(gangs.size()) - 1]) if not gangs.is_empty() else "scavvers"
			team = e.add_side(fid, "guard", false, {"at_war": true, "twist": true})
		"ally":
			fid = "locals"
			team = e.add_side(fid, "guard", false, {"twist": true, "ally": true})
			for s in e.sides.size():
				if s != team and e.hostile(s, Encounter.CREW):
					e.set_relation(team, s, "hostile")
			e.set_relation(team, Encounter.CREW, "ally")
	var at := e.arrival_cell() if String(spec.get("at", "far")) == "far" else _deploy_cell(e)
	if at.x < 0:
		out.skipped.append("units")
		return
	var reach: Dictionary = e._keys(func(): return e.nav.reachable(at, 6, e.occupied()))
	var cells: Array = reach.keys().filter(func(v): return v.z == at.z)
	cells.sort_custom(func(a, b): return int(reach[a]) < int(reach[b]))
	var ids := []
	for i in mini(n, cells.size()):
		var block := String(blocks[e.dice.d(blocks.size()) - 1])
		var c := Recruit.from_block(e.dice, block, "%s %d" % [rank, i + 1] if n > 1 else rank)
		c.role = String(RulesDB.load_json("npcs.json")["blocks"][block].get("tier", "mook"))
		c.faction = World.faction(fid).id if World.has_faction(fid) else fid
		e._add(c, cells[i], team)
		var u: Dictionary = e.units[-1]
		u.alerted = true
		u["twist"] = true
		e.init.add(c)
		ids.append(u.id)
	if ids.is_empty():
		out.skipped.append("units")
		return
	out.applied.append("units")
	out.units.append_array(ids)
	var who := {"opfor": "%d %ss for %s arrive" % [ids.size(), rank.to_lower(), World.display_name(e.post_faction)],
		"rival": "A rival crew of %d (%s) is after the same prize, hostile to everyone" % [ids.size(), World.display_name(fid)],
		"ally": "A stranger joins the crew's side"}
	out.lines.append(String(who.get(side, "%d more arrive" % ids.size())) + ".")
	e.events.append({"type": "backup", "unit": ids[0], "units": ids, "label": rank.to_upper() + ("S" if ids.size() > 1 else "")})


static func _deploy_cell(e: Encounter) -> Vector3i:
	var occ := e.occupied()
	for c in e.extract_cells:
		if not occ.has(c):
			return c
	return e.extract_cells.keys()[0] if not e.extract_cells.is_empty() else Vector3i(-1, -1, -1)


## No Way Back: the extraction point moves from the deploy zone to the entrance farthest from it
## (a 3x3 patch of walkable squares about it on its floor).
static func _extraction(e: Encounter, out: Dictionary) -> void:
	var old: Array = e.extract_cells.keys()
	var c0 := Vector2.ZERO
	for v in old:
		c0 += Vector2(v.x, v.y)
	c0 /= maxf(1.0, old.size())
	var best := Vector3i(-1, -1, -1)
	var bd := -1.0
	for en in e.m.entrances:
		if String(en.kind) == "deploy" or not bool(en.get("exit", true)):
			continue
		var v := Vector3i(en.pos.x, en.pos.y, int(en.get("floor", e.m.street)))
		if not e.m.walkable(v.z, Vector2i(v.x, v.y)) or e.extract_cells.has(v):
			continue
		var d := Vector2(v.x, v.y).distance_to(c0)
		if d > bd:
			bd = d
			best = v
	if best.x < 0:
		out.skipped.append("extraction")
		return
	var cells := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var v := best + Vector3i(dx, dy, 0)
			if e.m.inb(v.x, v.y) and e.m.walkable(v.z, Vector2i(v.x, v.y)):
				cells[v] = true
	e.extract_cells = cells
	out.applied.append("extraction")
	out.lines.append("The way in is shut: the extraction zone has moved.")


## Police Sting: the code's people (NCPD) come in a few rounds, and come hostile.
static func _response(e: Encounter, spec: Dictionary, out: Dictionary) -> void:
	var code := SecurityCode.normalise(spec.get("code", {}))
	if code.is_empty():
		out.skipped.append("response")
		return
	var r := e._plan_response(code)
	r["sting"] = true
	var rounds := maxi(0, _n(e, spec.get("rounds", [0, 2])))
	e._street = r
	e.ncpd_label = String(r.label)
	e._ncpd_round = e.init.round_num
	out.applied.append("response")
	if rounds <= 0:
		e.ncpd_in = 0
		e._arrive(r)
		out.lines.append("%s is already here." % SecurityCode.faction_name(String(code.faction)))
	else:
		e.ncpd_in = rounds
		out.lines.append("%s moves in: %d round%s." % [SecurityCode.faction_name(String(code.faction)), rounds, "" if rounds == 1 else "s"])


## Too Much Heat: every response counting down comes in `mult` the time (halved), at least the
## next round; with nothing coming, the street's code answers anyway.
static func _response_mult(e: Encounter, mult: float, out: Dictionary) -> void:
	var scale := func(n: int) -> int: return maxi(1, ceili(n * mult)) if n > 0 else n
	e.backup_in = scale.call(e.backup_in)
	e.ncpd_in = scale.call(e.ncpd_in)
	if e.backup_in < 0 and e.ncpd_in < 0 and not e.street_code.is_empty():
		e._street = e._plan_response(e.street_code)
		e.ncpd_label = String(e._street.label)
		e._ncpd_round = e.init.round_num
		e.ncpd_in = scale.call(SecurityCode.response_rounds(e.dice, SecurityCode.quick(e.street_code)))
	out.applied.append("response_mult")
	var parts := []
	if e.backup_in > 0:
		parts.append("%s in %d" % [e.backup_label.capitalize(), e.backup_in])
	if e.ncpd_in > 0:
		parts.append("%s in %d" % [e.ncpd_label.capitalize(), e.ncpd_in])
	out.lines.append("Everyone's coming fast" + ((": " + ", ".join(parts) + ".") if not parts.is_empty() else "."))


## The objective's mark (assassinate), or -1.
static func _mark(e: Encounter) -> int:
	var t := int(e.objective.get("target", -1)) if String(e.objective.get("kind", "")) == "assassinate" else -1
	return t if t >= 0 and t < e.units.size() and not e.units[t].c.dead else -1


## Target Escapes: the mark is tipped off and runs for an exit (AI._vip runs an alerted mark).
static func _mark_flees(e: Encounter, out: Dictionary) -> void:
	var t := _mark(e)
	if t < 0:
		out.skipped.append("mark")
		return
	var u: Dictionary = e.units[t]
	if not u.alerted:
		u.alerted = true
		e.init.add(u.c)
	out.applied.append("mark")
	out.units.append(t)
	out.lines.append("%s has been tipped off and runs for an exit." % u.c.display_name)


## Target Fights Back: the mark (else the opposition's strongest standing) steps up a tier in
## place: the next tier's stat block for its faction (a Mini Boss's Hardened one), the damage it
## has taken kept. A mark stops running and fights.
static func _tier_up(e: Encounter, out: Dictionary) -> void:
	var t := _mark(e)
	if t < 0:
		var order := {"mini_boss": 3, "lieutenant": 2, "mook": 1}
		var bs := -1
		for u in e.units:
			if int(u.team) == Encounter.OPFOR and not u.c.dead and u.c.can_act() and not u.has("turret") and not u.has("broke"):
				var s := int(order.get(String(u.c.role), 0))
				if s > bs:
					bs = s
					t = int(u.id)
	if t < 0:
		out.skipped.append("tier_up")
		return
	var u: Dictionary = e.units[t]
	var c: Combatant = u.c
	var tier := String(NEXT_TIER.get(String(c.role), "lieutenant"))
	var hard := String(c.role) == tier or e._hardened_posts
	var fid := c.faction if World.has_faction(c.faction) else e.post_faction
	var n := World.npc(e.dice, fid, tier, 1, "", hard)
	var lost := c.max_hp() - c.hp
	c.stats = n.stats.duplicate()
	c.skills = n.skills.duplicate()
	c.weapons = n.weapons
	c.armor = n.armor
	c.subdermal = n.subdermal
	c.cyberware = n.cyberware
	c.awareness = n.awareness
	c.hp_max_override = n.hp_max_override
	c.block = n.block
	c.role = tier
	c.hp = maxi(1, c.max_hp() - lost)
	u["fights"] = true   # a mark stands and fights (AI._fight)
	out.applied.append("tier_up")
	out.units.append(t)
	out.lines.append("%s fights like a %s." % [c.display_name, String(Complication.TIER_NAMES.get(tier, tier))])


## Trap Location: extra cameras and turrets in the target building's restricted rooms (before the
## turrets are mounted: the view builds devices with the map).
static func _devices(e: Encounter, spec: Dictionary, out: Dictionary) -> void:
	var sid := -1
	for st in e.m.structures:
		if st.target:
			sid = int(st.id)
	var inside := func(r: Dictionary) -> bool: return int(r.get("structure", -2)) == sid and int(r.get("floor", -1)) >= 0 \
		and int(r.get("cells", 0)) >= 6 and not r.get("outdoor", false) and String(r.get("kind", "")) != "roof"
	var rooms: Array = e.m.rooms.filter(func(r): return inside.call(r) and int(r.zone) >= TacMap.Zone.STAFF)
	if rooms.is_empty():
		rooms = e.m.rooms.filter(func(r): return inside.call(r))
	if rooms.is_empty():
		out.skipped.append("devices")
		return
	var added := {}
	for kind in spec:
		for i in int(spec[kind]):
			var r: Dictionary = rooms[e.dice.d(rooms.size()) - 1]
			var before := e.m.devices.size()
			Furnish.add_device(e.m, e.dice, r, String(kind), "trap_%s" % kind, true, {"trap": true})
			if e.m.devices.size() > before:
				added[kind] = int(added.get(kind, 0)) + 1
	if added.is_empty():
		out.skipped.append("devices")
		return
	out.applied.append("devices")
	var parts := []
	for k in added:
		parts.append("%d %s%s" % [int(added[k]), String(k), "" if int(added[k]) == 1 else "s"])
	out.lines.append("The site's rigged: %s nobody mentioned, off the NET." % " and ".join(parts))
