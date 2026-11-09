class_name MissionBuilder
extends RefCounted
## The Mission Builder (Cyberpunk RED: Single Player Mode, SPM p.28; the Mission Builder/Tracker
## sheet, SPM p.102) as the board's offer pipeline. A gig is built in the book's steps, each one a
## function over the gig dict and the campaign's Dice, run in STEPS order by run():
##   client  — who's hiring: People of Night City (SPM p.50-51) by the place's zone (zone_of);
##   mission — what's the mission: Mission Types (SPM p.72), each row an objective or disabled;
##   focus   — what it's about: Mission Items/MacGuffins (SPM p.73) by zone, fitting the objective;
##   payment — eb by the job's danger (CPR core p.381), sometimes information, a favour or goods;
##   twist   — Plot Twists (SPM p.75-76): not on every job (the Oracle, HOUSE-RULE by security
##             level), hidden from the board, sprung in play (Twist).
## Tables and HOUSE-RULE rates are data/gen/mission_builder.json. Campaign places the job (its
## location, target, fixer, level and base pay: the place has to be known before its zone can
## pick a client), then hands the gig here. Rules only: no Nodes, all rolls on the Dice passed in.
##
## The gig gains: client {zone, roll, id, label}; mission {roll, id, label, objective};
## focus {category, roll, id, label, short, marker, as}; payment {type, base, eb, + per type};
## twist (null, or {row, roll, id, label, trigger, oracle?}: Twist.roll). gig.pay becomes the eb
## part of the payment.

const STEPS := ["client", "mission", "focus", "payment", "twist"]
const ZONES := ["corporate", "moderate", "street", "outskirts"]
const PAYMENT_TYPES := ["eb", "information", "favour", "goods"]
const FAVOURS := ["treatment", "market"]


static func data() -> Dictionary:
	return RulesDB.gen("mission_builder.json")


## Run the builder's steps on `gig` (in place; also returned). `opts` overrides steps (the dev
## builder's form, CustomGig): client "<zone>/<id>", mission <id>, focus "<category>/<id>",
## payment <type> or "favour:<kind>", twist ("none", "auto", "<id or d100 roll>[@<trigger>]"),
## prefer [focus ids] (a unique template's), and goods: a
## Callable(value: int) -> Array of storage keys the goods payment may draw from.
static func run(dice: Dice, gig: Dictionary, opts: Dictionary = {}) -> Dictionary:
	for step in STEPS:
		match step:
			"client": client_step(dice, gig, String(opts.get("client", "")))
			"mission": mission_step(dice, gig, String(opts.get("mission", "")))
			"focus": focus_step(dice, gig, String(opts.get("focus", "")), opts.get("prefer", []))
			"payment": payment_step(dice, gig, String(opts.get("payment", "")), opts.get("goods", Callable()))
			"twist": gig["twist"] = twist(dice, gig, String(opts.get("twist", "")))
	return gig


# --- Zones --------------------------------------------------------------------------------------

## The People of Night City / Mission Items zone of a place (HOUSE-RULE mapping, mission_builder.json
## zones): Outskirts for an outskirts district or a badlands scene; else by its Security Code (its
## own, else the district's): low codes Street, high Corporate, the middle by the district's profile.
static func zone_of(lid: String, did := "", scene := "") -> String:
	var z: Dictionary = data().zones
	var l := World.location(lid) if lid != "" else {}
	if did == "":
		did = String(l.get("district", ""))
	if scene == "":
		scene = String(l.get("scene", ""))
	if did in (z.outskirts_districts as Array) or scene in (z.outskirts_scenes as Array):
		return "outskirts"
	var dist := World.district(did) if did != "" else {}
	var code := SecurityCode.normalise(l.get("security_code"))
	if code.is_empty():
		code = SecurityCode.normalise(dist.get("security_code"))
	var n := int(code.get("n", 5))
	if n <= int(z.street_max):
		return "street"
	if n >= int(z.corporate_min):
		return "corporate"
	var prof := String(dist.get("profile", ""))
	if prof in (z.street_profiles as Array):
		return "street"
	if prof in (z.corporate_profiles as Array):
		return "corporate"
	return "moderate"


static func zone_for(gig: Dictionary) -> String:
	return zone_of(String(gig.get("location", "")), String(gig.get("district", "")), String(gig.get("scene", "")))


static func zone_name(zone: String) -> String:
	return String((data().zones.names as Dictionary).get(zone, zone.capitalize()))


## Roll a table's die: "1d10" or "2d10".
static func _roll_die(dice: Dice, die: String) -> int:
	var parts := die.split("d")
	return dice.roll(maxi(1, int(parts[0])), int(parts[1]))


static func _row_at(rows: Array, r: int) -> Dictionary:
	for row in rows:
		var rr: Variant = row.get("roll")
		if (rr is Array and r >= int(rr[0]) and r <= int(rr[1])) or (not rr is Array and int(rr) == r):
			return row
	return {}


# --- Step 1: who's hiring -----------------------------------------------------------------------

static func client_rows(zone: String) -> Array:
	return (data().clients.get(zone, {}) as Dictionary).get("rows", [])


## The client row for "<zone>/<id>" ({} if none).
static func client_def(key: String) -> Dictionary:
	var zone := key.get_slice("/", 0)
	for row in client_rows(zone):
		if String(row.id) == key.get_slice("/", 1):
			return row
	return {}


## A client from `zone`'s People of Night City table: {zone, roll, id, label}.
static func roll_client(dice: Dice, zone: String) -> Dictionary:
	var t: Dictionary = data().clients.get(zone, data().clients.moderate)
	var r := _roll_die(dice, String(t.die))
	var row := _row_at(t.rows, r)
	return {"zone": zone, "roll": r, "id": String(row.get("id", "")), "label": String(row.get("label", "someone"))}


static func client_step(dice: Dice, gig: Dictionary, force := "") -> void:
	if gig.get("client") is Dictionary and not (gig.client as Dictionary).is_empty():
		return
	var forced := client_def(force) if force != "" else {}
	if not forced.is_empty():
		gig["client"] = {"zone": force.get_slice("/", 0), "roll": forced.roll, "id": String(forced.id), "label": String(forced.label)}
		return
	gig["client"] = roll_client(dice, zone_for(gig))


# --- Step 2: what's the mission -----------------------------------------------------------------

static func mission_rows() -> Array:
	return data().mission_types.rows


static func mission_def(id: String) -> Dictionary:
	for row in mission_rows():
		if String(row.id) == id:
			return row
	return {}


## Does the game play this Mission Types row? It names an objective that has a module.
static func enabled(row: Dictionary) -> bool:
	return row.get("objective") is String and String(row.objective) in Objective.kinds()


## The rows that play as `objective` ("" any enabled row).
static func rows_for(objective := "") -> Array:
	return mission_rows().filter(func(r): return enabled(r) and (objective == "" or String(r.objective) == objective))


## A mission type: roll the d100 (SPM p.72), again on a row the game can't play yet or that isn't
## `objective` (when given). {roll, id, label, objective}. After 100 misses, the first fitting row.
static func roll_mission(dice: Dice, objective := "") -> Dictionary:
	var fit_rows := rows_for(objective)
	if fit_rows.is_empty():
		return {}
	var ids := fit_rows.map(func(x): return String(x.id))
	for i in 100:
		var r := dice.d(100)
		var row := _row_at(mission_rows(), r)
		if String(row.get("id", "")) in ids:
			return _mission(row, r)
	return _mission(fit_rows[0], int(fit_rows[0].roll[0]))


static func _mission(row: Dictionary, r: int) -> Dictionary:
	return {"roll": r, "id": String(row.id), "label": String(row.label), "objective": String(row.objective)}


## The gig kind (gigs.json template kind, Campaign.OBJECTIVES) a mission type plays as.
static func kind_of(mission: Dictionary) -> String:
	var ob := String(mission.get("objective", ""))
	for k in Campaign.OBJECTIVES:
		if String(Campaign.OBJECTIVES[k]) == ob:
			return String(k)
	return ""


## The gig's mission: kept if it has one that fits its kind, else the forced row (if it fits),
## else rolled among the rows for its kind's objective.
static func mission_step(dice: Dice, gig: Dictionary, force := "") -> void:
	var ob := Campaign.objective_for(gig)
	var m: Variant = gig.get("mission")
	if m is Dictionary and String(m.get("objective", "")) == ob:
		return
	var row := mission_def(force)
	if not row.is_empty() and enabled(row) and String(row.objective) == ob:
		gig["mission"] = _mission(row, int(row.roll[0]))
		return
	gig["mission"] = roll_mission(dice, ob)


# --- Step 3: the focus --------------------------------------------------------------------------

static func focus_rows(category: String) -> Array:
	return (data().focus.get(category, {}) as Dictionary).get("rows", [])


## The focus row for "<category>/<id>" ({} if none).
static func focus_def(key: String) -> Dictionary:
	for row in focus_rows(key.get_slice("/", 0)):
		if String(row.id) == key.get_slice("/", 1):
			return row
	return {}


## The `as` tags an objective can play (mission_builder.json focus.plays).
static func plays(objective: String) -> Array:
	return (data().focus.plays as Dictionary).get(objective, [])


static func fits(row: Dictionary, objective: String) -> bool:
	return (row.get("as", []) as Array).any(func(t): return t in plays(objective))


## A focus item for an `objective` job in `zone`: the zone's Mission Items category (else the next
## in its fallback order that has an item the objective can play), its die rolled until a fitting
## item comes up; one of `prefer` (ids) when the category has any. {category, roll, id, label,
## short, marker, as}; {} when nothing fits (an objective with no items).
static func roll_focus(dice: Dice, zone: String, objective: String, prefer: Array = []) -> Dictionary:
	var order: Array = (data().zones.fallback as Dictionary).get(zone, ZONES)
	for cat in order:
		var t: Dictionary = data().focus.get(String(cat), {})
		var ok: Array = (t.get("rows", []) as Array).filter(func(r): return fits(r, objective))
		if ok.is_empty():
			continue
		var pref: Array = ok.filter(func(r): return String(r.id) in prefer)
		if not pref.is_empty():
			var p: Dictionary = pref[dice.d(pref.size()) - 1]
			return _focus(String(cat), p, int(p.roll))
		var ids := ok.map(func(x): return String(x.id))
		for i in 100:
			var r := _roll_die(dice, String(t.die))
			var row := _row_at(t.rows, r)
			if String(row.get("id", "")) in ids:
				return _focus(String(cat), row, r)
		return _focus(String(cat), ok[0], int(ok[0].roll))
	return {}


static func _focus(cat: String, row: Dictionary, r: int) -> Dictionary:
	var label := String(row.label)
	var short := String(row.get("short", _strip_article(label)))
	return {"category": cat, "roll": r, "id": String(row.id), "label": label, "short": short,
		"marker": String(row.get("marker", short.to_upper())), "as": (row.get("as", []) as Array).duplicate()}


static func _strip_article(s: String) -> String:
	for a in ["a ", "an ", "the "]:
		if s.begins_with(a):
			return s.substr(a.length())
	return s


static func focus_step(dice: Dice, gig: Dictionary, force := "", prefer: Array = []) -> void:
	var ob := Campaign.objective_for(gig)
	var row := focus_def(force) if force != "" else {}
	if not row.is_empty():
		gig["focus"] = _focus(force.get_slice("/", 0), row, int(row.roll))
		return
	var pf: Array = prefer.duplicate()
	var m := mission_def(String((gig.get("mission", {}) as Dictionary).get("id", "")))
	pf.append_array(m.get("prefer", []))
	gig["focus"] = roll_focus(dice, zone_for(gig), ob, pf)


## The text slots a focus fills: {item} "a tech prototype", {the_item} "the tech prototype",
## {The_item} capitalised, {item_short} "tech prototype".
static func item_slots(focus: Dictionary) -> Dictionary:
	if focus.is_empty():
		return {"item": "the package", "the_item": "the package", "The_item": "The package", "item_short": "package"}
	var label := String(focus.label)
	var short := String(focus.short)
	var the := label if label.begins_with("the ") else "the " + short
	return {"item": label, "the_item": the, "The_item": the.left(1).to_upper() + the.substr(1), "item_short": short}


# --- Step 4: payment ----------------------------------------------------------------------------

## The payment for a job whose rate is `base` eb (gigs.json pay, CPR core p.381): mostly eb, now and
## then information, a favour or goods (HOUSE-RULE rates, mission_builder.json payment). `force`: a
## type (or "favour:<kind>"); "" rolls. `goods`: Callable(value) -> storage keys worth up to value
## (none: the goods payment falls back to eb). {type, base, eb} plus kind/cap (favour) or item (goods).
static func roll_payment(dice: Dice, base: int, force := "", goods: Callable = Callable()) -> Dictionary:
	var pd: Dictionary = data().payment
	var type := force.get_slice(":", 0)
	if not type in PAYMENT_TYPES:
		var r := dice.d(int(pd.die))
		type = String(_row_at(pd.rows, r).get("type", "eb"))
	var row: Dictionary = {}
	for x in pd.rows:
		if String(x.type) == type:
			row = x
	var out := {"type": type, "base": base, "eb": base}
	match type:
		"information":
			out.eb = int(round(base * float(row.get("eb_share", 1.0))))
		"favour":
			out.eb = int(round(base * float(row.get("eb_share", 1.0))))
			var kinds: Array = row.get("kinds", FAVOURS)
			var kind := force.get_slice(":", 1) if force.contains(":") else ""
			if not kind in kinds:
				kind = String(kinds[dice.d(kinds.size()) - 1])
			out["kind"] = kind
			if kind == "market":
				out["cap"] = int(round(base * float(row.get("market_cap_share", 0.5))))
		"goods":
			var value := int(round(base * float(row.get("goods_share", 0.5))))
			var pool: Array = goods.call(value) if goods.is_valid() else []
			if pool.is_empty():
				out.type = "eb"
			else:
				out.eb = int(round(base * float(row.get("eb_share", 1.0))))
				out["item"] = String(pool[dice.d(pool.size()) - 1])
	return out


static func payment_step(dice: Dice, gig: Dictionary, force := "", goods: Callable = Callable()) -> void:
	var p := roll_payment(dice, int(gig.get("pay", 0)), force, goods)
	gig["payment"] = p
	gig["pay"] = int(p.eb)


## The payment beyond eb in a few words ("" for eb only): "intel on the next board", "a favour:
## one free Treatment", "a favour: a Night Market item up to 1,000 eb", "Kiroshi Optics".
static func payment_extra(p: Dictionary) -> String:
	match String(p.get("type", "eb")):
		"information":
			return "intel on the next board"
		"favour":
			if String(p.get("kind", "")) == "market":
				return "a favour: a Night Market item up to %s eb" % Campaign.eb_text(int(p.get("cap", 0)))
			return "a favour: one free Treatment"
		"goods":
			return Items.display_name(String(p.get("item", "")))
	return ""


## "1,500 eb + intel on the next board" / "2,000 eb".
static func payment_text(p: Dictionary, pay := -1) -> String:
	var eb := int(p.get("eb", pay)) if pay < 0 else pay
	var extra := payment_extra(p)
	return "%s eb" % Campaign.eb_text(eb) + (" + " + extra if extra != "" else "")


# --- Step 5: the twist --------------------------------------------------------------------------

## The twist step (SPM p.28 step 5; Plot Twists, SPM p.75-76): Twist.roll on the Oracle, null on
## most jobs; the gig keeps its answer, hidden until it springs. `force`: as Twist.roll's.
static func twist(dice: Dice, gig: Dictionary, force := "") -> Variant:
	return Twist.roll(dice, gig, force)


# --- Text ---------------------------------------------------------------------------------------

## The board's pitch for the gig: its mission's framing with the target and the focus filled in,
## first letter up ("" for a gig with no mission).
static func pitch(gig: Dictionary, target_name: String) -> String:
	var m := mission_def(String((gig.get("mission", {}) as Dictionary).get("id", "")))
	var s := String(m.get("framing", ""))
	if s == "":
		return ""
	var slots := item_slots(gig.get("focus", {}) if gig.get("focus") is Dictionary else {})
	slots["target"] = target_name
	for k in slots:
		s = s.replace("{%s}" % k, String(slots[k]))
	return s.left(1).to_upper() + s.substr(1)


## "a corp researcher, via Mr. Hands" ("" without a client).
static func client_text(gig: Dictionary) -> String:
	var c: Variant = gig.get("client")
	if not c is Dictionary or (c as Dictionary).is_empty():
		return ""
	var via := String(gig.get("fixer", ""))
	return String(c.get("label", "")) + (", via " + via if via != "" and via != "DEV BUILDER" else "")


## The debrief's line about the focus, by objective and outcome ("" without a focus).
static func debrief_line(gig: Dictionary, won: bool) -> String:
	var f: Variant = gig.get("focus")
	if not f is Dictionary or (f as Dictionary).is_empty():
		return ""
	var lines: Array = (data().focus.debrief as Dictionary).get(Campaign.objective_for(gig), [])
	if lines.size() < 2:
		return ""
	var s := String(lines[0 if won else 1])
	var slots := item_slots(f)
	for k in slots:
		s = s.replace("{%s}" % k, String(slots[k]))
	return s.left(1).to_upper() + s.substr(1)
