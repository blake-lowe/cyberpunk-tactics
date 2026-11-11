extends TestCase
## Equipment imported from the core book (data/rules/weapons.json, armor.json, gear.json):
## every entry is cited, well-formed, uses known fx keys and references things that exist; and
## the night market only sells what the game can actually play.

## The fx vocabulary every import starts from (docs/rules/gear.md); data adds its own in fx_keys.
const BASE_FX := ["skill_bonus", "stat_bonus", "attack_bonus", "damage_dice", "damage_bonus", "ignores_sp_below",
	"halves_sp", "sp", "penalty", "shield_hp", "mag", "rof", "hands", "conceal", "non_lethal", "status", "burning",
	"explosive", "area_half", "range", "vision", "requires", "consumable", "charges", "duration", "addiction_dv"]
## fx keys the rules code implements today. An item may only be sold if all its fx are here.
const IMPLEMENTED_FX := ["attack_bonus", "no_damage", "acid_sp_ablate", "no_crit_injury", "no_ablate", "non_lethal",
	"ignores_sp_below", "halves_sp", "keyed_to_owner", "burning", "shell_only", "no_aimed_shot", "autofire_only",
	"ammo_per_attack", "reload_actions", "min_body", "requires", "smartgun", "status", "self_status", "disable_count",
	"battery_shots", "battery_cost", "battery_recharge",   # battery packs play as a magazine (reload = swap a pack)
	# kit items (inventory): grenade payloads, drugs, carried tools
	"ablate_sp", "burning_trigger", "burning_stacks", "burning_extinguish", "duration", "meat_only", "consumable",
	"administer", "addiction_dv", "addiction_check", "stack_extends", "stat_bonus", "stat_cap_bypass", "paranoia",
	"addicted", "humanity_loss", "humanity_refund_on_resist", "ignore_seriously_wounded", "skill_bonus", "no_stack",
	# cyberware phase 2: smoke clouds (Smoke), gas grenades and hazard gear (Combatant.immune_to)
	"obscure", "grenade_hazard", "immune"]
const AMMO_KINDS := ["bullets", "arrows", "grenades", "rockets", "shotgun_shells", "none"]
const SECTIONS := ["attachments", "ammo", "shields", "gear", "fashion", "drugs", "pharmaceuticals", "therapy"]


func _known_fx() -> Dictionary:
	var k := {}
	for x in BASE_FX:
		k[x] = true
	for x in RulesDB.load_json("gear.json").get("fx_keys", {}):
		k[String(x).get_slice(".", 0)] = true
	return k


func _check_fx(where: String, fx: Variant, known: Dictionary) -> void:
	if not (fx is Dictionary):
		return
	for key in fx:
		assert_true(known.has(String(key)), "%s: fx key %s is documented" % [where, key])


func test_every_weapon_builds_and_resolves() -> void:
	var db: Dictionary = RulesDB.load_json("weapons.json")
	var skills: Dictionary = RulesDB.load_json("skills.json")["skills"]
	var known := _known_fx()
	for id in db.weapons:
		var d: Dictionary = db.weapons[id]
		var w := Weapon.from_id(id)
		assert_true(w != null, "%s builds" % id)
		assert_true(skills.has(String(d.skill)), "%s: skill %s" % [id, d.skill])
		if not d.get("melee", false):
			assert_true(db.range_dv.has(String(d.range)), "%s: range table %s" % [id, d.get("range")])
		assert_true(String(d.get("ammo", "none")) in AMMO_KINDS, "%s: ammo kind" % id)
		assert_true(String(d.get("cite", "")).contains("p"), "%s: cited" % id)
		_check_fx(id, d.get("fx", {}), known)
	for q in db.quality:
		_check_fx("quality " + q, db.quality[q].get("fx", {}), known)


func test_every_gear_entry_is_cited_and_well_formed() -> void:
	var g: Dictionary = RulesDB.load_json("gear.json")
	var known := _known_fx()
	var n := 0
	for sec in SECTIONS:
		for id in g.get(sec, {}):
			var it: Dictionary = g[sec][id]
			n += 1
			assert_true(String(it.get("cite", "")).contains("p."), "%s/%s: cited" % [sec, id])
			assert_false(String(it.get("name", "")).is_empty(), "%s/%s: named" % [sec, id])
			assert_true(String(it.get("summary", "")).split(" ").size() <= 25, "%s/%s: summary is a short paraphrase" % [sec, id])
			var c: Variant = it.get("cost")
			assert_true(c == null or (c is float or c is int) and float(c) >= 0.0, "%s/%s: cost" % [sec, id])
			_check_fx("%s/%s" % [sec, id], it.get("fx", {}), known)
			assert_false(RulesDB.gear(sec, id).is_empty(), "%s/%s: reachable through RulesDB.gear" % [sec, id])
	assert_true(n > 90, "the book's equipment is in (%d entries)" % n)


func test_attachments_and_ammo_reference_real_things() -> void:
	var g: Dictionary = RulesDB.load_json("gear.json")
	var weapons: Dictionary = RulesDB.load_json("weapons.json")["weapons"]
	for id in g.attachments:
		var el: Variant = g.attachments[id].get("eligible", {})
		if el is Dictionary:
			for w in el.get("weapons", []):
				assert_true(weapons.has(String(w)), "attachment %s: eligible weapon %s exists" % [id, w])
	for id in g.ammo:
		for t in g.ammo[id].get("types", []):
			assert_true(String(t) in AMMO_KINDS, "ammo %s: kind %s" % [id, t])


func test_the_market_only_sells_gear_that_plays() -> void:
	for key in Items.all():
		var it := Items.def(key)
		assert_false(it.has("unmodelled"), "%s is sold, so nothing about it may be unmodelled" % key)
		assert_true(String(it.get("kit", "")) in ["consumable", "utility"], "%s: a kit kind" % key)
		assert_true(String(it.get("kit_use", "")) in ["grenade", "dose", "carried"], "%s: how it's used" % key)
		if Items.use(key) != "carried":
			assert_true(Items.short_name(key).length() <= 8, "%s: a short action-bar label" % key)
		for k in it.get("fx", {}):
			assert_true(k in IMPLEMENTED_FX, "%s is sold, so its fx %s must be implemented" % [key, k])


func test_the_market_only_sells_what_plays() -> void:
	for f in ["weapons.json", "armor.json"]:
		var db: Dictionary = RulesDB.load_json(f)
		var items: Dictionary = db.get("weapons", db.get("armor", {}))
		for id in items:
			var it: Dictionary = items[id]
			if not it.has("sold"):
				continue
			assert_false(it.has("unmodelled"), "%s is sold, so nothing about it may be unmodelled" % id)
			for key in it.get("fx", {}):
				assert_true(key in IMPLEMENTED_FX, "%s is sold, so its fx %s must be implemented" % [id, key])
