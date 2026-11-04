class_name Turret
extends RefCounted
## Automated turrets (CPR core p.214, Emplaced Defenses; docs/rules/cyber-net.md 3.11): a gun on
## its own Control Node that fires on its own Combat Number + 1d10 when nobody controls it and
## cannot dodge. A Netrunner who takes its node turns it on the site's people (p.213-214).
## In an encounter every powered turret device is a unit that never moves (`turret`: the device
## id) on the site's turret side, or the crew's while a Netrunner holds its node; it joins the
## Initiative order the first time it has someone to shoot (Encounter._mount_turrets, AI.turret).

const COMBAT_NUMBER := 14   # CPR core p.214: Automated Turret, Combat Number 14
const HP := 25              # CPR core p.214: Automated Turret, 25 HP
## HOUSE-RULE: the book arms a turret with one of five guns (p.214: assault rifle, flamethrower,
## dartgun, VH pistol, heavy SMG); every turret mounts the first, the assault rifle (25 rounds).
const WEAPON := "assault_rifle"
const COUNTER_DV := 17      # CPR core p.214: Electronics/Security Tech DV17, 5 minutes (by hand: not modelled yet)
const SKILLS := ["shoulder_arms", "autofire", "handgun", "heavy_weapons", "archery", "melee_weapon"]


## A turret as a combatant: every attack Skill at its Combat Number (REF 0 so STAT + Skill is the
## Combat Number alone), 25 HP, no armour, nothing to dodge with.
## RULES-UNVERIFIED: the book gives a turret no Initiative; REF 0 rolls it on 1d10 alone.
static func make(n: int, weapon_id := WEAPON) -> Combatant:
	var skills := {}
	for s in SKILLS:
		skills[s] = COMBAT_NUMBER
	var c := Combatant.new("Turret %d" % n, {"INT": 0, "REF": 0, "DEX": 0, "TECH": 0, "COOL": 0, "WILL": 0, "LUCK": 0, "MOVE": 0, "BODY": 0, "EMP": 0}, skills)
	c.hp_max_override = HP
	c.hp = HP
	c.role = "turret"
	c.tracks_humanity = false
	c.weapons.append(Weapon.from_id(weapon_id))
	return c
