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


func reload() -> void:
	ammo = int(def.get("mag", 0))
