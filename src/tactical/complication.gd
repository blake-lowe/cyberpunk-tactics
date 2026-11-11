class_name Complication
extends RefCounted
## The book's complication tables in play (owner-approved, decisions log 2026-11-04: they replace
## our invented gig twists). At gig start the opposition's strongest tier present (Mini Boss, else
## Lieutenant, else Mook) may roll 1d10 on its table (data/rules/npcs.json `complications`: Mook
## Encounter Complication, RTG Hardened Mooks p.2; Hardened Lieutenant Tactics, RTG Hardened LTs
## p.3; Mini Boss Mini Promotion, RTG Hardened Mini Bosses p.2). The entry's fx are applied where
## the engine models them; the rest is logged and skipped. The crew learns of it when it springs
## (the round tab and the log at the start), never on the board: nothing in the book says a fixer
## would know.
##
## Modelled fx: add_units (now, or on round N / rounds; 'different_type' another block of the tier,
## 'team_member' a Mook follower; crit_injury: each starts with one at that location, without the
## Bonus Damage), kit (a grenade into a kit slot; with qty, special rounds loaded into the primary
## weapon), drug (in their system from the start), skill_base, skill_base_raise, stat_set,
## stat_bonus, armor, no_armor_penalty, weapon (given as primary), ai 'reckless', hp_bonus,
## cyberware, cyberware_eb (chrome_up: fitted combat chrome for the eb), tactic ambush / charge /
## focus_fire, choose. Not yet: other tactics (human_shield, hold_cover, command), trap, facedown,
## reputation, role_ability, EMP grenades (no kit use yet), and the empty fx. A smoke grenade is a kit grenade (Smoke, CPR core p.347).

## Whether a gig runs into one is a Closed Question put to the Oracle (Oracle; SPM p.12-13): "Is
## the opposition ready with something extra?" (yes is the interesting answer). Either yes answer
## springs one; the answer is kept on it as `oracle`. HOUSE-RULE: how likely yes is by the gig's 1-3
## security level, i.e. how hard the place is guarded (SecurityCode.level): Light places Impossible
## (10%), Medium Unlikely (35%, about the one gig in three this replaced), Heavy 50/50 (60%). The
## DLCs roll one per encounter, and a gig holds several encounters' worth of guards; on every gig
## they'd be routine, so a crew nobody knows rarely meets one and a fortress often does.
const LIKELIHOOD := {1: "impossible", 2: "unlikely", 3: "even"}
const TIERS := ["mini_boss", "lieutenant", "mook"]   ## strongest first
const TIER_NAMES := {"mook": "Mook", "lieutenant": "Lieutenant", "mini_boss": "Mini Boss"}
## Unit keys the per-unit appliers handle (everything else is a whole-encounter key or skipped).
const UNIT_KEYS := ["kit", "qty", "drug", "when", "skill_base", "skill_base_raise", "stat_set", "stat_bonus", "armor",
	"no_armor_penalty", "weapon", "ai", "hp_bonus", "cyberware", "cyberware_eb"]


static func table(tier: String) -> Array:
	return (RulesDB.load_json("npcs.json").get("complications", {}) as Dictionary).get(tier, [])


## The Oracle's likelihood that a gig at security level `level` (1-3) runs into a complication.
static func likelihood(level: int) -> String:
	return String(LIKELIHOOD[clampi(level, 1, 3)])


## Ask the Oracle whether a gig at security level `level` gets a complication (Oracle.ask).
static func ask(dice: Dice, level: int) -> Dictionary:
	return Oracle.ask(dice, likelihood(level))


## Does a gig at security level `level` get a complication? The Oracle's yes (either kind).
static func happens(dice: Dice, level := 2) -> bool:
	return bool(ask(dice, level).yes)


## The strongest tier with a table among the opposition's people standing, "" if none.
static func top_tier(e: Encounter) -> String:
	for t in TIERS:
		if e.units.any(func(u): return int(u.team) == Encounter.OPFOR and String(u.c.role) == t and not u.c.dead):
			return t
	return ""


## Ask the Oracle (likelihood by the map's security level) and on a yes apply a complication on
## `e`, recording it in e.complication and the log. `force` picks one instead: {tier?, roll?}
## (tests, the greybox --complication flag, a fixer's intel asked ahead: Campaign.foresee; a
## missing roll is rolled). Returns e.complication ({} if none).
static func start(e: Encounter, force: Dictionary = {}) -> Dictionary:
	var tier := String(force.get("tier", ""))
	if tier == "":
		tier = top_tier(e)
	var rows := table(tier)
	if rows.is_empty():
		return {}
	var answer := {}
	if force.is_empty():
		answer = ask(e.dice, int(e.m.params.get("security", 1)) if e.m != null else 1)
		if not bool(answer.yes):
			return {}
	var r := int(force.get("roll", 0))
	if r < 1 or r > 10:
		r = e.dice.d(10)
	var entry: Dictionary = rows[clampi(r, 1, rows.size()) - 1]
	for row in rows:
		if int(row.get("roll", 0)) == r:
			entry = row
	var out := {"tier": tier, "roll": r, "text": String(entry.get("text", "")), "hud": String(entry.get("hud", entry.get("text", ""))), "applied": [], "skipped": []}
	if not answer.is_empty():
		out["oracle"] = String(answer.outcome)   # yes or yes_complication (a later twist step may make the second worse)
	e.complication = out
	e.say("Complication: %s. %s" % [out.hud, out.text])   # the alert, then the rules detail for the log
	apply(e, tier, entry.get("fx", {}), out)
	if not (out.skipped as Array).is_empty():
		e.say("Not modelled yet, skipped: %s." % ", ".join(out.skipped))
	return out


## Apply `fx` (one table entry's) for `tier` on `e`; records what was applied and skipped in `out`.
static func apply(e: Encounter, tier: String, fx: Dictionary, out: Dictionary) -> void:
	if fx.has("choose"):
		var opts: Array = fx.choose
		fx = opts[e.dice.d(opts.size()) - 1] if not opts.is_empty() else {}
	if fx.is_empty():
		out.skipped.append("the whole entry")
		return
	if fx.has("add_units"):
		_add_units(e, tier, fx, out)
	if fx.has("tactic"):
		_tactic(e, tier, String(fx.tactic), out)
	for k in ["trap", "facedown", "reputation", "role_ability"]:
		if fx.has(k):
			out.skipped.append(k)
	if UNIT_KEYS.any(func(k): return fx.has(k)):
		var who := _of_tier(e, tier)
		var n := mini(int(fx.get("affects", 1)), who.size())
		var picked: Array = []
		for i in n:
			var u: Dictionary = who[e.dice.d(who.size()) - 1]
			who.erase(u)
			picked.append(u)
		for u in picked:
			apply_unit(e, u, fx, out)


## The opposition's standing units of `tier`.
static func _of_tier(e: Encounter, tier: String) -> Array:
	return e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and String(u.c.role) == tier and not u.c.dead)


## One unit's share of an entry: gear, drugs, armour, stats, then Skill Bases last (so a set base
## is the total with the new stats and armour).
static func apply_unit(e: Encounter, u: Dictionary, fx: Dictionary, out: Dictionary) -> void:
	var c: Combatant = u.c
	var did := func(k: String) -> void:
		if not k in out.applied:
			out.applied.append(k)
	var skip := func(k: String) -> void:
		if not k in out.skipped:
			out.skipped.append(k)
	if fx.has("armor"):
		for loc in fx.armor:
			var aid := String(fx.armor[loc])
			c.armor[loc] = ArmorPiece.from_id(aid) if aid != "" else null
		did.call("armor")
	if bool(fx.get("no_armor_penalty", false)):
		for loc in c.armor:
			if c.armor[loc] != null:
				(c.armor[loc] as ArmorPiece).penalty = 0
		did.call("no_armor_penalty")
	for s in fx.get("stat_set", {}):
		c.stats[String(s)] = int(fx.stat_set[s])
		did.call("stat_set")
	for s in fx.get("stat_bonus", {}):   # to the STAT itself: the armour penalty still applies after
		c.stats[String(s)] = int(c.stats.get(String(s), 0)) + int(fx.stat_bonus[s])
		did.call("stat_bonus")
	if fx.has("hp_bonus"):
		c.hp_max_override = c.max_hp() + int(fx.hp_bonus)
		c.hp = c.max_hp()
		did.call("hp_bonus")
	if fx.has("weapon"):
		c.weapons.insert(0, Weapon.from_id(String(fx.weapon)))
		did.call("weapon")
	for cw in fx.get("cyberware", []):
		if not c.has_cyberware(String(cw)):
			c.install_cyberware(String(cw), e.dice, true)
		did.call("cyberware")
	if fx.has("cyberware_eb"):   # "600eb more cyberware" (RTG Hardened Mini Bosses p.2)
		var got := chrome_up(c, int(fx.cyberware_eb))
		e.say("%s is chromed up: %s." % [c.display_name, ", ".join(got) if not got.is_empty() else "nothing more fits"])
		did.call("cyberware_eb")
	if fx.has("kit"):
		if give_kit(c, String(fx.kit), int(fx.get("qty", 0))):
			did.call("kit")
		else:
			skip.call("kit (%s)" % Items.display_name(String(fx.kit)))
	if fx.has("drug"):
		var drugs: Array = fx.drug if fx.drug is Array else [fx.drug]
		dose(c, String(drugs[e.dice.d(drugs.size()) - 1]))
		did.call("drug")
	if String(fx.get("ai", "")) == "reckless":
		u["reckless"] = true
		did.call("ai")
	for s in fx.get("skill_base", {}):
		if set_skill_base(c, String(s), int(fx.skill_base[s])):
			did.call("skill_base")
		else:
			skip.call("skill %s" % s)
	if fx.has("skill_base_raise"):
		var r: Dictionary = fx.skill_base_raise
		var high: Array = c.skills.keys().filter(func(s): return c.skill_base(String(s)) > int(r.get("above", 10)) and c.skill_base(String(s)) < int(r.get("to", 17)))
		high.sort_custom(func(a, b): return c.skill_base(String(a)) > c.skill_base(String(b)))
		for s in high.slice(0, int(r.get("count", 1))):
			set_skill_base(c, String(s), int(r.get("to", 17)))
		did.call("skill_base_raise")


## The heavily chromed Mini Boss's extra chrome (cyberware_eb): combat chrome the game plays
## (Cyber.modelled), bought at list price (the cost includes the surgery, p.110) and fitted where the
## slot rules allow, up to `eb`. Deterministic, no dice: each package in CHROME_UP order goes in if
## it adds something they lack, fits and is affordable with what's left; benefits don't stack, so
## nothing doubles up (p.111). Returns the piece names fitted, in order.
const CHROME_UP: Array = [
	["kerenzikov"],                                                     # +2 Initiative; needs a Neural Link already in
	["skin_weave"],                                                     # SP 7 under the skin, if their armour is thinner
	["cybereye", "cybereye", "anti_dazzle", "anti_dazzle"],             # flashbang- and teargas-proof
	["anti_dazzle", "anti_dazzle"],                                     # ...in two Cybereyes they have
	["wolvers"],                                                        # heavy melee claws in a meat arm
	["nasal_filters"],                                                  # gas-proof
	["toxin_binders"],                                                  # +2 Resist Torture/Drugs
	["big_knucks"],
	["scratchers"],
]


static func chrome_up(c: Combatant, eb: int) -> Array[String]:
	var got: Array[String] = []
	var left := eb
	for pack in CHROME_UP:
		var cost := 0
		for id in pack:
			cost += int(Cyber.def(String(id)).get("cost", 0))
		if cost > left or not _adds(c, pack):
			continue
		var trial: Array = c.implants.duplicate()
		var ok := true
		for id in pack:
			var loc := Cyber.auto_loc(trial, String(id))
			if loc == "" or not Cyber.modelled(String(id)):
				ok = false
				break
			trial.append({"id": String(id), "loc": loc})
		if not ok:
			continue
		for id in pack:
			c.install_cyberware(String(id), null, true)
			got.append(Cyber.display(String(id)))
		left -= cost
	return got


## Whether a CHROME_UP package gives `c` something it lacks: no second Speedware, Skin Weave only over
## thinner worn body armour (the higher SP counts, p.184) and no subdermal armour, one built-in melee
## weapon, a piece they don't have yet.
static func _adds(c: Combatant, pack: Array) -> bool:
	for id in pack:
		var d := Cyber.def(String(id))
		if c.has_cyberware(String(id)) and not (String(id) == "cybereye"):
			return false
		if String(d.get("group", "")) != "" and c.implants.any(func(p): return String(Cyber.def(String(p.id)).get("group", "")) == String(d.group)):
			return false
		if d.get("fx", {}).has("armor_sp"):
			var worn: ArmorPiece = c.armor.get("body")
			if not c.subdermal.is_empty() or (worn != null and worn.sp >= int(d.fx.armor_sp)):
				return false
		if d.get("fx", {}).has("weapon") and c.weapons.any(func(w): return w.builtin and w.is_melee() and w.popup == ""):
			return false
	if pack.has("cybereye") and Cyber.EYES.any(func(l): return Cyber.foundation_at(c.implants, l) != ""):
		return false   # the eye package is for meat eyes; two Cybereyes take the anti-dazzle pair alone
	return true


## Set `c`'s Skill Base (STAT + Skill, as the book prints it) for `skill` to `base`. False if the
## game doesn't know the skill.
static func set_skill_base(c: Combatant, skill: String, base: int) -> bool:
	if not (RulesDB.load_json("skills.json")["skills"] as Dictionary).has(skill):
		return false
	c.skills[skill] = maxi(0, int(c.skills.get(skill, 0)) + base - c.skill_base(skill))
	return true


## Give `c` the kit item `key`: with `qty` > 1, that many special rounds in the primary weapon if it
## takes that ammunition (Incendiary rounds, CPR core p.346); otherwise a grenade in a kit slot.
## False if neither works yet (an EMP grenade has no kit use).
static func give_kit(c: Combatant, key: String, qty: int) -> bool:
	var g := RulesDB.gear(key.get_slice("/", 0), key.get_slice("/", 1))
	if qty > 1:
		for w in c.weapons:
			if w.uses_ammo() and String(w.def.get("ammo", "")) in (g.get("types", []) as Array):
				w.load_special(Items.fx(key), qty)
				return true
		return false
	if Items.is_item(key) and Items.use(key) == "grenade":
		var slot := c.kit.find("")
		c.kit[slot if slot >= 0 else 0] = key
		c.kit_spent[slot if slot >= 0 else 0] = false
		return true
	return false


## `drug` in `c`'s system from the start (the effects a dose gives, Encounter.take_dose). NPCs don't
## track Humanity, so Black Lace's cost doesn't apply.
static func dose(c: Combatant, drug: String) -> void:
	var fx: Dictionary = RulesDB.gear("drugs", drug).get("fx", {})
	var eff := {}
	for k in ["stat_bonus", "skill_bonus", "ignore_seriously_wounded"]:
		if fx.has(k):
			eff[k] = fx[k]
	c.drug_fx.append(eff)
	c.drugs_taken.append(drug)


static func _tactic(e: Encounter, tier: String, tactic: String, out: Dictionary) -> void:
	match tactic:
		"ambush":   # they know the crew is coming (CPR p.399): alerted from the start
			for u in e.units:
				if int(u.team) == Encounter.OPFOR and not u.alerted and not u.c.dead:
					u.alerted = true
					e.init.add(u.c)
			e.alarm = maxi(e.alarm, 1)
		"charge":   # a wild charge: nobody minds cover
			for u in e.units:
				if int(u.team) == Encounter.OPFOR:
					u["reckless"] = true
		"focus_fire":   # everyone shoots the same crew member first
			var crew := e.alive(Encounter.CREW)
			if crew.is_empty():
				out.skipped.append("tactic " + tactic)
				return
			e.focus_id = int(crew[e.dice.d(crew.size()) - 1].id)
		_:
			out.skipped.append("tactic " + tactic)
			return
	out.applied.append("tactic " + tactic)


## Extra units: now (beside the tier's people), or queued for the rounds given (Encounter ticks them).
static func _add_units(e: Encounter, tier: String, fx: Dictionary, out: Dictionary) -> void:
	var unit_tier := "mook" if String(fx.get("unit", "")) == "team_member" else tier
	var rounds: Array = fx.get("rounds", [fx.round] if fx.has("round") else [])
	var batch := {"n": int(fx.add_units), "tier": unit_tier, "unit": String(fx.get("unit", "")), "crit": String(fx.get("crit_injury", ""))}
	if rounds.is_empty():
		spawn(e, batch, true)
	else:
		for r in rounds:
			var b := batch.duplicate()
			b["round"] = int(r)
			e.complication_waves.append(b)
	out.applied.append("add_units")
	if batch.crit != "":
		out.applied.append("crit_injury")


## Put `batch` ({n, tier, unit, crit}) on the map for the opposition: at setup beside one of the
## tier's people (`now`), later at the entrance farthest from the crew. They're alerted if the
## opposition already is (and join the initiative order); otherwise they walk to a guard's post.
static func spawn(e: Encounter, batch: Dictionary, now: bool) -> Array:
	var anchor := Vector3i(-1, -1, -1)
	if not now:
		anchor = _far_entrance(e)
	if anchor.x < 0:
		var near := _of_tier(e, String(batch.tier))
		if near.is_empty():
			near = e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and not u.c.dead)
		if near.is_empty():
			return []
		anchor = near[e.dice.d(near.size()) - 1].pos
	var reach: Dictionary = e._keys(func(): return e.nav.reachable(anchor, 6, e.occupied()))
	var cells: Array = reach.keys().filter(func(v): return v.z == anchor.z and v != anchor)
	cells.sort_custom(func(a, b): return int(reach[a]) < int(reach[b]))
	var existing: Array = _of_tier(e, String(batch.tier)).map(func(u): return String(u.c.block))
	var alert := e.alarm >= 1
	var posts: Array = e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and not u.c.dead).map(func(u): return u.pos)
	var ids := []
	for i in mini(int(batch.n), cells.size()):
		var g := World.npc(e.dice, e.post_faction, String(batch.tier), e.units.size() + 1, "", e._hardened_posts)
		if String(batch.unit) == "different_type":   # another block of the tier than those fielded
			for k in 6:
				if not String(g.block) in existing:
					break
				g = World.npc(e.dice, e.post_faction, String(batch.tier), e.units.size() + 1, "", e._hardened_posts)
		if String(batch.crit) != "":
			var table := RulesDB.crit_table(String(batch.crit))
			g.add_injury(table[str(e.dice.roll(2, 6))], String(batch.crit), false)
		e._add(g, cells[i], Encounter.OPFOR)
		var u: Dictionary = e.units[-1]
		if alert:
			u.alerted = true
			e.init.add(g)
		elif not now and not posts.is_empty():
			u["patrol"] = [cells[i], posts[e.dice.d(posts.size()) - 1]]
			u["patrol_i"] = 1
		ids.append(u.id)
	if not now and not ids.is_empty():
		e.say("Complication: %d more %s join the opposition." % [ids.size(), TIER_NAMES.get(String(batch.tier), String(batch.tier))])
		e.events.append({"type": "backup", "unit": ids[0], "units": ids, "label": "MORE " + String(TIER_NAMES.get(String(batch.tier), "")).to_upper() + "S"})
	return ids


## The non-deploy entrance farthest from the crew (where reinforcements walk in; in a tower band
## the lift car or the fire stair: Encounter.arrival_cell), or (-1,-1,-1).
static func _far_entrance(e: Encounter) -> Vector3i:
	return e.arrival_cell()


## Units due this round (Encounter.next_turn calls it at each new round).
static func tick(e: Encounter) -> void:
	var due := e.complication_waves.filter(func(b): return int(b.round) <= e.init.round_num)
	for b in due:
		e.complication_waves.erase(b)
		spawn(e, b, false)
