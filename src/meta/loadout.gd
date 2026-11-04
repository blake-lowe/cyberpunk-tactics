class_name Loadout
extends RefCounted
## The Armory's loadout model (no Nodes, testable headless): a crew member's slots, what in
## storage fits each, the one-verb EQUIP / STORE, comparison deltas, self-explaining counts and the
## squad's gaps. Campaign keeps the storage and the equip rules; this only arranges them for the
## screen.
##
## Slot ids: "w0", "w1"... (carried weapons in draw order), "wadd" (a weapon not yet carried),
## "head", "body" (armour, p97), "k0" (consumable), "k1" (utility; gear.json kit_rules).

const FILTERS := ["all", "weapons", "armor", "consumable", "utility"]
const SORTS := ["name", "damage", "sp", "count"]


## Every slot of `c` in screen order.
static func slots(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	if c == null:
		return out
	for i in c.weapons.size():
		out.append("w%d" % i)
	out.append_array(["wadd", "head", "body"])
	for i in c.kit.size():
		out.append("k%d" % i)
	return out


static func weapon_index(slot: String) -> int:
	return int(slot.substr(1)) if slot.begins_with("w") and slot != "wadd" else -1


static func kit_index(slot: String) -> int:
	return int(slot.substr(1)) if slot.begins_with("k") else -1


static func is_weapon_slot(slot: String) -> bool:
	return slot.begins_with("w")


static func is_armor_slot(slot: String) -> bool:
	return slot in ["head", "body"]


## "WEAPON 2", "HEAD", "CONSUMABLE".
static func slot_label(slot: String) -> String:
	if slot == "wadd":
		return "NEW WEAPON"
	if is_weapon_slot(slot):
		return "WEAPON %d" % (weapon_index(slot) + 1)
	if is_armor_slot(slot):
		return slot.to_upper()
	return Items.slot_name(kit_index(slot)).to_upper()


## The storage filter a slot opens with.
static func filter_for(slot: String) -> String:
	if is_weapon_slot(slot):
		return "weapons"
	if is_armor_slot(slot):
		return "armor"
	return "consumable" if kit_index(slot) == 0 else "utility"


## Whether a storage key belongs under a filter chip. ALL also lists cyberware waiting for the
## Med Bay.
static func in_filter(filter: String, key: String) -> bool:
	match filter:
		"weapons": return Items.is_weapon(key)
		"armor": return Items.is_armor(key)
		"consumable": return Items.fits(0, key) and Items.is_item(key)
		"utility": return Items.fits(1, key) and Items.is_item(key)
	return Items.is_stored(key)


## Whether `key` can go in `slot` at all (kind only; availability is equip_block).
static func fits(slot: String, key: String) -> bool:
	if is_weapon_slot(slot):
		return Items.is_weapon(key)
	if is_armor_slot(slot):
		return Items.is_armor(key)
	var k := kit_index(slot)
	return k >= 0 and Items.is_item(key) and Items.fits(k, key)


## The slot a storage item goes to when picked while another kind of slot is selected: armour on
## an empty location first (head, then body), kit by its kind, weapons as a new weapon. "" for
## cyberware (installed at the Med Bay, not here).
static func best_slot(c: Combatant, key: String) -> String:
	if Items.is_weapon(key):
		return "wadd"
	if Items.is_armor(key):
		return "head" if c != null and c.armor.get("head") == null else "body"
	if Items.is_item(key):
		for i in Items.slot_kinds().size():
			if Items.fits(i, key):
				return "k%d" % i
	return ""


## The installed cyberware a built-in weapon belongs to ("Wolvers"), or "".
static func chrome_name(c: Combatant, w: Weapon) -> String:
	if c == null or not w.builtin:
		return ""
	var db: Dictionary = RulesDB.load_json("cyberware.json")["cyberware"]
	for id in c.cyberware:
		if db.has(id) and String((db[id].get("fx", {}) as Dictionary).get("weapon", "")) == w.id():
			return String(db[id].get("name", id))
	return ""


## The storage key of what's in the slot now ("" if empty). A chrome weapon has its weapon key
## (for comparisons) though it never goes to storage.
static func slot_key(c: Combatant, slot: String) -> String:
	if c == null:
		return ""
	var wi := weapon_index(slot)
	if wi >= 0:
		return Items.key_of_weapon(c.weapons[wi]) if wi < c.weapons.size() else ""
	if is_armor_slot(slot):
		var a: ArmorPiece = c.armor.get(slot)
		return Items.key_of_armor(a) if a else ""
	var k := kit_index(slot)
	return c.kit[k] if k >= 0 and k < c.kit.size() else ""


## Installed chrome in a weapon slot: changed at the Med Bay, never stored.
static func is_chrome(c: Combatant, slot: String) -> bool:
	var wi := weapon_index(slot)
	return c != null and wi >= 0 and wi < c.weapons.size() and c.weapons[wi].builtin


## Why `key` can't be equipped into `slot` now ("" if it can).
static func equip_block(camp: Campaign, c: Combatant, slot: String, key: String) -> String:
	if c == null:
		return "nobody selected"
	if not fits(slot, key):
		return "doesn't fit " + slot_label(slot)
	if Items.is_item(key):
		var k := kit_index(slot)
		if c.kit[k] == key:
			return "equipped"
		return "" if camp.unpacked(key, c, k) > 0 else "all assigned"
	if camp.stored(key) <= 0:
		return "not in storage"
	return camp.equip_block(c, key, slot if is_armor_slot(slot) else "body")


## EQUIP: put `key` from storage into `slot`; what was there goes back to storage (a chrome weapon
## stays, and the new one is carried after it).
static func equip(camp: Campaign, c: Combatant, slot: String, key: String) -> bool:
	if equip_block(camp, c, slot, key) != "":
		return false
	if is_weapon_slot(slot):
		var wi := weapon_index(slot)
		if wi >= 0 and wi < c.weapons.size() and not c.weapons[wi].builtin:
			camp.unequip_weapon(c, wi)
			return camp.equip_weapon(c, key, wi)
		return camp.equip_weapon(c, key)
	if is_armor_slot(slot):
		return camp.equip_armor(c, slot, key)
	return camp.set_kit(c, kit_index(slot), key)


## STORE: what's in `slot` back to storage.
static func store(camp: Campaign, c: Combatant, slot: String) -> bool:
	if c == null or slot_key(c, slot) == "" or is_chrome(c, slot):
		return false
	var wi := weapon_index(slot)
	if wi >= 0:
		return camp.unequip_weapon(c, wi)
	if is_armor_slot(slot):
		return camp.unequip_armor(c, slot)
	return camp.set_kit(c, kit_index(slot), "")


## Move a carried weapon one place up (-1) or down (+1). Returns the slot it ends in ("" if it
## didn't move).
static func reorder(camp: Campaign, c: Combatant, slot: String, step: int) -> String:
	var wi := weapon_index(slot)
	if wi < 0 or not camp.reorder_weapon(c, wi, wi + step):
		return ""
	return "w%d" % (wi + step)


# --- Storage list ------------------------------------------------------------------------------

## Storage keys under `filter`, sorted by `sort` (name, damage, sp or count; ties by name). Kit
## items everyone has equipped stay listed (greyed out, "all assigned").
static func storage_keys(camp: Campaign, filter: String, sort: String) -> Array[String]:
	var out: Array[String] = []
	for k in camp.stash:
		var key := String(k)
		if camp.stored(key) > 0 and in_filter(filter, key):
			out.append(key)
	out.sort_custom(func(a: String, b: String) -> bool:
		var va := sort_value(camp, a, sort)
		var vb := sort_value(camp, b, sort)
		if va != vb:
			return va > vb
		return Items.display_name(a).naturalnocasecmp_to(Items.display_name(b)) < 0)
	return out


## Higher first; 0 for keys the sort doesn't apply to (name sort: all equal, so by name).
static func sort_value(camp: Campaign, key: String, sort: String) -> int:
	match sort:
		"damage":
			return damage_dice(key)
		"sp":
			return sp_of(key)
		"count":
			return camp.stored(key)
	return 0


static func damage_dice(key: String) -> int:
	if Items.is_weapon(key):
		return Items.make_weapon(key).dice()
	if Items.use(key) == "grenade" and not Items.fx(key).get("no_damage", false):
		return int(RulesDB.weapon("thrown_grenade").get("dice", 0))   # a grenade's blast, CPR core p.177
	return 0


## Current SP of an armour key (ablated pieces keep their SP in storage).
static func sp_of(key: String) -> int:
	return Items.make_armor(key).sp if Items.is_armor(key) else 0


## "×2 · 1 with Torque": how many storage holds, then who has one. Kit counts include the
## equipped ones (they stay in storage until spent); a weapon or armour piece someone carries is on
## them, so it's named but not counted. "all assigned" when nobody else can take a kit item.
static func count_text(camp: Campaign, key: String) -> String:
	var n := camp.stored(key)
	var parts: Array[String] = ["×%d" % n]
	var with := {}
	var order: Array[String] = []
	for m in camp.alive_crew():
		var has := 0
		if Items.is_item(key):
			has = m.kit.count(key)
		elif Items.is_weapon(key):
			for w in m.weapons:
				if not w.builtin and Items.key_of_weapon(w) == key:
					has += 1
		elif Items.is_armor(key):
			for loc in ["head", "body"]:
				var a: ArmorPiece = m.armor.get(loc)
				if a and a.id == Items.base_id(key):
					has += 1
		if has > 0:
			with[m.display_name] = has
			order.append(m.display_name)
	if order.size() == 1:
		parts.append("%d with %s" % [int(with[order[0]]), order[0]])
	elif order.size() > 1:   # names would run off the row: the count says it
		var held := 0
		for nm in order:
			held += int(with[nm])
		parts.append("%d with the crew" % held)
	if Items.is_item(key) and camp.unpacked(key) <= 0:
		parts.append("all assigned")
	return " · ".join(parts)


# --- Stats and comparison ----------------------------------------------------------------------

## Short stats for a storage key: "4d6 · ROF 1 · 8 rds", "SP 11", "6d6 · ablates 2".
static func stats(key: String) -> String:
	if Items.is_weapon(key):
		var w := Items.make_weapon(key)
		return "%dd6 · " % w.dice() + ("melee" if w.is_melee() else "ROF %d · %d rds" % [w.rof(), w.mag()])
	if Items.is_armor(key):
		var a := Items.make_armor(key)
		return "SP %d" % a.max_sp + (" · -%d REF/DEX/MOVE" % a.penalty if a.penalty > 0 else "") if a.sp >= a.max_sp \
			else "SP %d/%d" % [a.sp, a.max_sp]
	if Items.is_item(key):
		return kit_stats(key)
	return Campaign.item_info(key)


## A kit item's effect in a few words, from its gear.json fx (CPR core p.344-347 grenades, p.358
## drugs, p.351 scanners).
static func kit_stats(key: String) -> String:
	var fx := Items.fx(key)
	var out: Array[String] = []
	var dmg := damage_dice(key)
	if dmg > 0:
		out.append("%dd6" % dmg)
	elif fx.get("no_damage", false):
		out.append("no damage")
	if fx.has("ablate_sp"):
		out.append("ablates %d" % int(fx.ablate_sp))
	if fx.has("burning"):
		out.append("burns %d/turn" % int(fx.burning))
	if fx.has("status"):
		out.append("DV%d %s" % [int(fx.status.dv), String(RulesDB.skill(String(fx.status.check)).get("name", fx.status.check))])
	for s in (fx.get("stat_bonus", {}) as Dictionary):
		out.append("%+d %s" % [int(fx.stat_bonus[s]), s])
	if fx.has("ignore_seriously_wounded"):
		out.append("ignore Seriously Wounded")
	if fx.has("skill_bonus"):
		var sk: Dictionary = fx.skill_bonus
		var first := String(sk.keys()[0])
		out.append("%+d %s%s" % [int(sk[first]), String(RulesDB.skill(first).get("name", first)), " +%d more" % (sk.size() - 1) if sk.size() > 1 else ""])
	if fx.has("duration"):
		out.append(String(fx.duration))
	return " · ".join(out) if not out.is_empty() else String(Items.def(key).get("summary", ""))


## The slot item's line on the loadout: a weapon's dice, ROF and ammo; armour SP current/max (the
## caller paints an ablated SP red) and repair progress; a kit item's effect.
static func slot_stats(c: Combatant, slot: String) -> String:
	var wi := weapon_index(slot)
	if wi >= 0 and wi < c.weapons.size():
		var w: Weapon = c.weapons[wi]
		if w.is_melee():
			return "%dd6 · ROF %d · melee" % [w.dice(), w.rof()]
		return "%dd6 · ROF %d · %d/%d" % [w.dice(), w.rof(), w.ammo, w.mag()]
	if is_armor_slot(slot):
		var a: ArmorPiece = c.armor.get(slot)
		if a == null:
			return ""
		var s := "SP %d/%d" % [a.sp, a.max_sp]
		if a.sp < a.max_sp:
			s += " · " + repair_text(a)
		return s
	var key := slot_key(c, slot)
	return kit_stats(key) if key != "" else ""


## Repair progress (Item Repair, CPR core p140: time by Price Category; done during rest).
static func repair_text(a: ArmorPiece) -> String:
	var need := ArmorPiece.repair_hours(a.price())
	if need > 72:
		return "repair %d/%d days" % [a.repair_work / 24, need / 24]
	return "repair %d/%d h" % [a.repair_work, need]


## Deltas of `key` against `now` (what's in the slot; "" for an empty slot), as [text, sign]
## pairs: sign 1 better (green), -1 worse (red), 0 neutral. [["same", 0]] when nothing differs.
static func deltas(key: String, now: String) -> Array:
	var out: Array = []
	if now == "" or Items.section(key) != Items.section(now):
		return out
	if Items.is_weapon(key):
		var a := Items.make_weapon(key)
		var b := Items.make_weapon(now)
		if a.dice() != b.dice():
			out.append(["%+dd6" % (a.dice() - b.dice()), signi(a.dice() - b.dice())])
		if a.rof() != b.rof():
			out.append(["ROF %+d" % (a.rof() - b.rof()), signi(a.rof() - b.rof())])
		if a.attack_bonus() != b.attack_bonus():
			out.append(["%+d to hit" % (a.attack_bonus() - b.attack_bonus()), signi(a.attack_bonus() - b.attack_bonus())])
		if a.is_melee() != b.is_melee():
			out.append(["melee" if a.is_melee() else "ranged", 0])
	elif Items.is_armor(key):
		var a := Items.make_armor(key)
		var b := Items.make_armor(now)
		if a.sp != b.sp:
			out.append(["SP %+d" % (a.sp - b.sp), signi(a.sp - b.sp)])
		if a.penalty != b.penalty:
			out.append(["%+d penalty" % (a.penalty - b.penalty), -signi(a.penalty - b.penalty)])
	elif key != now:
		return out
	if out.is_empty():
		out.append(["same", 0])
	return [out[0], out[1]] if out.size() > 2 else out


## The comparison table: [label, this, now, sign of this vs now]. `now` may be "".
static func compare_rows(key: String, now: String) -> Array:
	var rows: Array = []
	if Items.is_weapon(key):
		var a := Items.make_weapon(key)
		var b: Weapon = Items.make_weapon(now) if Items.is_weapon(now) else null
		rows.append(["DAMAGE", "%dd6" % a.dice(), "%dd6" % b.dice() if b else "—", signi(a.dice() - b.dice()) if b else 0])
		rows.append(["ROF", str(a.rof()), str(b.rof()) if b else "—", signi(a.rof() - b.rof()) if b else 0])
		rows.append(["MAG", "melee" if a.is_melee() else str(a.mag()), ("melee" if b.is_melee() else str(b.mag())) if b else "—", 0])
		rows.append(["RANGE", _reach(a), _reach(b) if b else "—", 0])
	elif Items.is_armor(key):
		var a := Items.make_armor(key)
		var b: ArmorPiece = Items.make_armor(now) if Items.is_armor(now) else null
		rows.append(["SP", "%d/%d" % [a.sp, a.max_sp], "%d/%d" % [b.sp, b.max_sp] if b else "—", signi(a.sp - b.sp) if b else 0])
		rows.append(["PENALTY", str(-a.penalty) if a.penalty else "none", (str(-b.penalty) if b.penalty else "none") if b else "—",
			-signi(a.penalty - b.penalty) if b else 0])
	elif Items.is_item(key):
		rows.append(["EFFECT", kit_stats(key), kit_stats(now) if now != "" else "—", 0])
		rows.append(["USE", Items.use(key), Items.use(now) if now != "" else "—", 0])
	return rows


static func _reach(w: Weapon) -> String:
	if w.is_melee():
		return "%d m" % int(Attack.MELEE_REACH_M)
	return "%d m" % int(RangeCurve.max_range_m(String(w.def.get("range", "")), false, float(w.fx().get("max_range_m", 0.0))))


# --- Squad -------------------------------------------------------------------------------------

## What the squad is missing: no consumable, no utility, ablated armour, no ranged weapon.
static func warnings(camp: Campaign) -> Array[String]:
	var out: Array[String] = []
	var crew := camp.alive_crew()
	for i in Items.slot_kinds().size():
		var n := crew.filter(func(m: Combatant): return m.kit[i] == "").size()
		if n > 0:
			out.append("%s %s no %s" % [_crew_count(n), "has" if n == 1 else "have", Items.slot_name(i).to_upper()])
	for m in crew:
		for loc in ["head", "body"]:
			var a: ArmorPiece = m.armor.get(loc)
			if a and a.sp < a.max_sp:
				out.append("%s's %s armor is ablated" % [m.display_name, loc])
	for m in crew:
		if not m.weapons.any(func(w: Weapon): return not w.is_melee()):
			out.append("%s has no ranged weapon" % m.display_name)
	return out


static func _crew_count(n: int) -> String:
	return "%d crew" % n
