class_name Weapon
extends RefCounted
## A carried weapon instance: static stats from weapons.json plus ammo state.

var def: Dictionary
var ammo: int


static func from_id(weapon_id: String) -> Weapon:
	var w := Weapon.new()
	w.def = RulesDB.weapon(weapon_id)
	w.ammo = int(w.def.get("mag", 0))
	return w


func id() -> String: return def["id"]
func skill() -> String: return def["skill"]
func dice() -> int: return int(def["dice"])
func rof() -> int: return int(def["rof"])
func is_melee() -> bool: return def.get("melee", false)
func autofire_mult() -> int: return int(def.get("autofire", 0))
func uses_ammo() -> bool: return not is_melee() and int(def.get("mag", 0)) > 0
func mag() -> int: return int(def.get("mag", 0))


func reload() -> void:
	ammo = int(def.get("mag", 0))


## Melee weapons and Martial Arts halve SP; Brawling and thrown weapons don't (p176-178).
func halves_sp() -> bool:
	return is_melee() and not def.get("no_halve", false)


## Unarmed damage by BODY (p176); a Cyberarm gives at least 2d6.
static func unarmed_dice(c: Combatant) -> int:
	var body := c.stat("BODY")
	var n := 1 if body <= 4 else 2 if body <= 6 else 3 if body <= 10 else 4
	if c.cyber_fx_sum("brawling_min_dice") > 0:
		n = maxi(n, 2)
	return n


static func brawling(c: Combatant) -> Weapon:
	var w := Weapon.new()
	w.def = {"id": "brawling", "name": "Fists", "skill": "brawling", "dice": unarmed_dice(c), "rof": 2, "hands": 1, "melee": true, "no_halve": true}
	return w


## Martial Arts (p178): same damage as Brawling but halves SP. `form` is the skill id.
static func martial_arts(c: Combatant, form: String = "martial_arts") -> Weapon:
	var w := Weapon.new()
	w.def = {"id": "martial_arts", "name": "Martial Arts", "skill": form, "dice": unarmed_dice(c), "rof": 2, "hands": 1, "melee": true}
	return w
