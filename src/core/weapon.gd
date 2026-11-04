class_name Weapon
extends RefCounted
## A carried weapon instance: static stats from weapons.json plus ammo state.

var def: Dictionary
var ammo: int
var builtin := false   ## part of installed cyberware (Wolvers, Big Knucks): never sold or swapped out
var quality := "standard"   ## poor | standard | excellent (CPR core p.342; weapons.json "quality")
var jammed := false         ## a Poor weapon that rolled a 1: an Action to clear before it fires again


static func from_id(weapon_id: String, p_quality := "standard") -> Weapon:
	var w := Weapon.new()
	w.def = RulesDB.weapon(weapon_id)
	w.ammo = int(w.def.get("mag", 0))
	w.quality = p_quality if can_have_quality(weapon_id, p_quality) else "standard"
	return w


## Quality applies to non-exotic melee and ranged weapons (p.342); exotics are as listed.
static func can_have_quality(weapon_id: String, q: String) -> bool:
	if q == "standard":
		return true
	var d := RulesDB.weapon(weapon_id)
	return (RulesDB.load_json("weapons.json")["quality"] as Dictionary).has(q) and String(d.get("category", "standard")) != "exotic"


func quality_fx() -> Dictionary:
	return (RulesDB.load_json("weapons.json")["quality"][quality] as Dictionary).get("fx", {})


## The weapon's special rules (exotics) as data: weapons.json "fx".
func fx() -> Dictionary:
	return def.get("fx", {})


## +Attack from quality (Excellent +1, p.342) and the weapon's own rules (e.g. Malorian 3516's
## Excellent build and smartgun link, p.348).
func attack_bonus() -> int:
	return int(quality_fx().get("attack_bonus", 0)) + int(fx().get("attack_bonus", 0))


## Poor Quality weapons jam on a Critical Failure (a 1 on the Attack Check, p.342).
func jams_on_fumble() -> bool:
	return bool(quality_fx().get("jam_on_fumble", false))


## List price at this quality (p.342 cost table by base cost).
func cost() -> int:
	var base := int(def.get("cost", 0))
	var table: Dictionary = quality_fx().get("cost_by_base", {})
	return int(table.get(str(base), base))


func display_name() -> String:
	return String(def.get("name", id())) if quality == "standard" else "%s %s" % [quality.capitalize(), def.get("name", id())]


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
