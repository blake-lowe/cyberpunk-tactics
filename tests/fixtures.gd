class_name Fixtures
extends RefCounted
## Shared test characters.


static func stats(overrides: Dictionary = {}) -> Dictionary:
	var s := {"INT": 5, "REF": 6, "DEX": 6, "TECH": 5, "COOL": 5, "WILL": 5, "LUCK": 5, "MOVE": 6, "BODY": 6, "EMP": 5}
	s.merge(overrides, true)
	return s


## A generic gunfighter: REF 6, Handgun/Shoulder Arms/Autofire 6, Evasion 4.
static func shooter(name: String = "Shooter", stat_overrides: Dictionary = {}) -> Combatant:
	var c := Combatant.new(name, stats(stat_overrides),
		{"handgun": 6, "shoulder_arms": 6, "autofire": 6, "evasion": 4, "melee_weapon": 4, "brawling": 4, "first_aid": 4})
	c.armor["body"] = ArmorPiece.from_id("light_armorjack")
	c.armor["head"] = ArmorPiece.from_id("light_armorjack")
	return c


static func unarmored(name: String = "Target", stat_overrides: Dictionary = {}) -> Combatant:
	return Combatant.new(name, stats(stat_overrides), {"evasion": 4})
