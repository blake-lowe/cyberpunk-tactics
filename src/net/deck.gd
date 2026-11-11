class_name Deck
extends RefCounted
## A Netrunner's cyberdeck and what is loaded on it (CPR core p.196, p.201-209, p.364). Pure rules
## over a Combatant's fields, no Nodes:
##   Combatant.deck          the gear.json id of the deck carried ("cyberdeck_standard"), "" for none
##   Combatant.programs      Programs loaded on it (gear.json "programs" ids; copies repeat)
##   Combatant.deck_hardware Hardware on it (gear.json "hardware" ids)
##   Combatant.backup        Programs a Backup Drive saved from destruction, waiting to be put back
## Storage keys: "gear/cyberdeck_<quality>", "programs/<id>", "hardware/<id>" (Items).
##
## Slots (p.196): Poor 5, Standard 7, Excellent 9; Programs and Hardware share them. A Program takes
## 1 slot, Black ICE 2 (p.204), Hardware 1 unless its entry says 2 (p.208-209). A Cyberdeck in a
## Cyberarm adds 1 (p.208, p.364); a worn Bodyweight Suit adds 1 for Hardware only (p.208, p.350).
## Loading or unloading takes an hour (p.201, p.204, p.208): the safehouse's, never a gig's.

## The Role's starting gear (CPR core p.103): a Cyberdeck with 7 slots, Armor, Sword, and "See Ya or
## Eraser", "Sword or Vrizzbolt", "Worm or Sword". The choices are the ones the game plays (Eraser's
## Cloak and Vrizzbolt's enemy Netrunners aren't in the game): See Ya, Sword, Worm.
const STARTING_DECK := "cyberdeck_standard"
const STARTING_PROGRAMS: Array[String] = ["armor", "sword", "see_ya", "sword", "worm"]
## Gear the deck can't be without: the Bodyweight Suit's extra Hardware-only slot (p.208).
const SUIT := "bodyweight_suit"
## Combatant.cyber_off key for a carried deck knocked out by a Microwaver or EMP (p.348: "cyberware or
## carried electronics"). A deck in a Cyberarm is the arm's piece instead (Cyber.key).
const OFF_KEY := "deck@carried"
## fx the rules code plays (NetRun, Encounter's NET, Attack.microwaver_targets). A Program, Hardware or
## deck is sold only when every fx key it has is here and nothing about it is unmodelled.
const IMPLEMENTED_FX := ["deck_slots", "requires", "boost", "brain_reduce", "one_running", "once_per_run",
	"program_dmg", "own_ice", "backup", "emp_proof", "fireproof", "no_forced_jack_out", "jack_range_m"]


# --- Data ----------------------------------------------------------------------------------------

static func program(id: String) -> Dictionary:
	return RulesDB.gear("programs", id)


static func hardware(id: String) -> Dictionary:
	return RulesDB.gear("hardware", id)


## A cyberdeck's gear.json entry ({} if `id` isn't a deck).
static func deck_def(id: String) -> Dictionary:
	var d := RulesDB.gear("gear", id)
	return d if (d.get("fx", {}) as Dictionary).has("deck_slots") else {}


static func is_deck_key(key: String) -> bool:
	return Items.section(key) == "gear" and not deck_def(Items.base_id(key)).is_empty()


static func is_program_key(key: String) -> bool:
	return Items.section(key) == "programs" and not program(Items.base_id(key)).is_empty()


static func is_hardware_key(key: String) -> bool:
	return Items.section(key) == "hardware" and not hardware(Items.base_id(key)).is_empty()


## A deck, Program or Hardware: the netrunning gear safehouse storage holds.
static func is_netrun_key(key: String) -> bool:
	return is_deck_key(key) or is_program_key(key) or is_hardware_key(key)


## Loaded onto a deck: a Program or Hardware.
static func is_loadable(key: String) -> bool:
	return is_program_key(key) or is_hardware_key(key)


static func entry(key: String) -> Dictionary:
	if is_program_key(key):
		return program(Items.base_id(key))
	if is_hardware_key(key):
		return hardware(Items.base_id(key))
	return deck_def(Items.base_id(key))


## Whether the game sells it: its rules are played (no `unmodelled`, every fx key implemented) and
## it has a price (CPR core p.196, p.203-208).
static func sold(key: String) -> bool:
	var e := entry(key)
	if e.is_empty() or e.has("unmodelled") or int(e.get("cost", 0)) <= 0:
		return false
	for k in e.get("fx", {}):
		if not String(k) in IMPLEMENTED_FX:
			return false
	return true


## Every netrunning key the game sells, decks first, then Programs, then Hardware (data order).
static func all_sold() -> Array[String]:
	var out: Array[String] = []
	var g: Dictionary = RulesDB.load_json("gear.json")
	for id in g.get("gear", {}):
		if not deck_def(String(id)).is_empty():
			out.append("gear/" + String(id))
	for id in g.get("programs", {}):
		out.append("programs/" + String(id))
	for id in g.get("hardware", {}):
		out.append("hardware/" + String(id))
	var keep: Array[String] = []
	for k in out:
		if sold(k):
			keep.append(k)
	return keep


## Deck slots a Program or Hardware takes (Black ICE 2, p.204; some Hardware 2, p.208-209).
static func slots_of(key: String) -> int:
	return int(entry(key).get("slots", 1))


static func prog_slots(id: String) -> int:
	return int(program(id).get("slots", 1))


static func hw_slots(id: String) -> int:
	return int(hardware(id).get("slots", 1))


## "Sword", "Killer" (a Black ICE of yours is named as the ICE).
static func name_of(id: String) -> String:
	return String(program(id).get("name", id.capitalize()))


## booster | defender | attacker | black_ice
static func program_class(id: String) -> String:
	return String(program(id).get("class", ""))


static func is_black_ice(id: String) -> bool:
	return program_class(id) == "black_ice"


## A Program's ATK, DEF and REZ; your own Black ICE's are the ICE's (black_ice.json, p.206-207).
static func stats(id: String) -> Dictionary:
	var p := program(id)
	if p.has("ice"):
		var st: Dictionary = RulesDB.load_json("black_ice.json")["ice"].get(String(p.ice), {})
		return {"atk": int(st.get("atk", 0)), "def": int(st.get("def", 0)), "rez": int(st.get("rez", 0)), "per": int(st.get("per", 0)), "spd": int(st.get("spd", 0))}
	return {"atk": int(p.get("atk", 0)), "def": int(p.get("def", 0)), "rez": int(p.get("rez", 0))}


## One line on a Program, Hardware or deck for lists: "ATK 1 · 3d6 vs ICE", "-4 brain damage", "7 slots".
static func info(key: String) -> String:
	if is_deck_key(key):
		return "%d slots" % int(deck_def(Items.base_id(key)).fx.deck_slots)
	var e := entry(key)
	var sl := slots_of(key)
	var tail := " · %d slots" % sl if sl > 1 else ""
	if is_hardware_key(key):
		return String(e.get("summary", "")) + tail
	var id := Items.base_id(key)
	var fx: Dictionary = e.get("fx", {})
	match program_class(id):
		"attacker":
			if fx.has("program_dmg"):
				return "ATK %d · %s to ICE" % [int(e.atk), String(fx.program_dmg.black_ice)] + tail
			return "ATK %d · vs Netrunners" % int(e.atk) + tail
		"black_ice":
			var st := stats(id)
			return "ATK %d · DEF %d · REZ %d" % [st.atk, st.def, st.rez] + tail
		"defender":
			if fx.has("brain_reduce"):
				return "REZ %d · -%d brain damage · once a run" % [int(e.rez), int(fx.brain_reduce)] + tail
			return "REZ %d · vs Netrunners" % int(e.rez) + tail
		"booster":
			for k in (fx.get("boost", {}) as Dictionary):
				return "REZ %d · +%d %s" % [int(e.rez), int(fx.boost[k]), String(k).capitalize()] + tail
	return String(e.get("summary", "")) + tail


# --- A crew member's deck --------------------------------------------------------------------------

## The Cyberdeck Cyberarm option is installed: their deck is in the arm, +1 slot (p.364).
static func in_arm(c: Combatant) -> bool:
	return c != null and c.has_cyberware("cyberdeck")


## Slots on their deck: its quality's (p.196), +1 in a Cyberarm (p.364). 0 without a deck.
static func slots(c: Combatant) -> int:
	if c == null or c.deck == "":
		return 0
	var n := int((deck_def(c.deck).get("fx", {}) as Dictionary).get("deck_slots", 0))
	if in_arm(c):
		n += int((Cyber.def("cyberdeck").get("fx", {}) as Dictionary).get("deck_slots_bonus", 1))
	return n


## The Bodyweight Suit's extra Hardware-only slot while worn (p.208, p.350).
static func suit_slots(c: Combatant) -> int:
	var a: ArmorPiece = c.armor.get("body") if c != null else null
	return 1 if a != null and a.id == SUIT else 0


static func program_slots_used(c: Combatant) -> int:
	var n := 0
	for id in c.programs:
		n += prog_slots(id)
	return n


static func hardware_slots_used(c: Combatant) -> int:
	var n := 0
	for id in c.deck_hardware:
		n += hw_slots(id)
	return n


## Deck slots in use: Programs, and Hardware beyond what a worn Bodyweight Suit holds.
static func used(c: Combatant) -> int:
	return program_slots_used(c) + maxi(0, hardware_slots_used(c) - suit_slots(c))


static func free_slots(c: Combatant) -> int:
	return slots(c) - used(c)


## Whether `key` would fit on the deck with what's loaded now.
static func fits(c: Combatant, key: String) -> bool:
	if is_program_key(key):
		return program_slots_used(c) + slots_of(key) + maxi(0, hardware_slots_used(c) - suit_slots(c)) <= slots(c)
	if is_hardware_key(key):
		return program_slots_used(c) + maxi(0, hardware_slots_used(c) + slots_of(key) - suit_slots(c)) <= slots(c)
	return false


## Only a Netrunner can use a deck (the Interface Role Ability, p.197): the Armory keeps decks to them.
static func can_carry(c: Combatant) -> bool:
	return c != null and c.role == "netrunner"


## Why `key` can't be loaded onto `c`'s deck ("" if it can). Player text.
static func load_block(c: Combatant, key: String) -> String:
	if not is_loadable(key):
		return "not a program or hardware"
	if not can_carry(c):
		return "netrunners only"
	if c.deck == "":
		return "no cyberdeck"
	if not fits(c, key):
		return "no free slot"
	return ""


static func has_hw(c: Combatant, fx_key: String) -> bool:
	return c != null and c.deck != "" and c.deck_hardware.any(func(h): return (hardware(String(h)).get("fx", {}) as Dictionary).has(fx_key))


static func hw_fx(c: Combatant, fx_key: String, default: Variant = null) -> Variant:
	if c == null or c.deck == "":
		return default
	for h in c.deck_hardware:
		var fx: Dictionary = hardware(String(h)).get("fx", {})
		if fx.has(fx_key):
			return fx[fx_key]
	return default


## Access point range: 6 m, 8 m with a Range Upgrade (p.198, p.208-209).
static func jack_range_m(c: Combatant, base: float) -> float:
	return maxf(base, float(hw_fx(c, "jack_range_m", 0)))


## Knocked out by a Microwaver or EMP for now (p.348): the carried deck, or the arm it's built into.
static func offline(c: Combatant) -> bool:
	if c == null or c.deck == "":
		return false
	if in_arm(c):
		return not c.cyber_working("cyberdeck")
	return c.cyber_off.has(OFF_KEY)


## The carried deck as a piece a Microwaver can knock out ({} when it can't: no deck, in an arm
## (the arm's piece is the target then), or Hardened Circuitry, p.208-209).
static func emp_piece(c: Combatant) -> Dictionary:
	if c == null or c.deck == "" or in_arm(c) or has_hw(c, "emp_proof"):
		return {}
	return {"id": "deck", "loc": "carried"}


## A Program on the deck is Destroyed (p.201): erased from the deck. A Backup Drive saves a
## Non-Black ICE one the instant before (p.208-209). Returns whether it was saved.
static func destroy(c: Combatant, id: String) -> bool:
	if not id in c.programs:
		return false
	c.programs.erase(id)
	if has_hw(c, "backup") and not is_black_ice(id):
		c.backup.append(id)
		return true
	return false


## Put the Backup Drive's Programs back on the deck where there's room (p.208-209: a Meat Action).
## Returns what went back.
static func restore_backup(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	if not has_hw(c, "backup"):
		return out
	for id in c.backup.duplicate():
		if fits(c, "programs/" + id):
			c.backup.erase(id)
			c.programs.append(id)
			out.append(id)
	return out


## The Role's starting deck (CPR core p.103) on a new Netrunner.
static func give_starting(c: Combatant) -> void:
	c.deck = STARTING_DECK
	c.programs.assign(STARTING_PROGRAMS)
