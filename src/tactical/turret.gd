class_name Turret
extends RefCounted
## Automated turrets (CPR core p.214, Emplaced Defenses; docs/rules/cyber-net.md 3.11): a gun on
## its own Control Node that fires on its own Combat Number + 1d10 when nobody controls it and
## cannot dodge. A Netrunner who takes its node operates it as a NET Action, once per Turn, with
## their own Skills (p.199, p.213-214; Encounter.fire_turret).
## In an encounter every powered turret device is a unit that never moves (`turret`: the device
## id) on the site's turret side; it joins the Initiative order the first time it has someone to
## shoot (Encounter._mount_turrets, AI.turret). While a Netrunner holds its node it stands with
## the crew and takes no turn of its own (`held_by`: the runner's unit id).

const COMBAT_NUMBER := 14   # CPR core p.214: Automated Turret, Combat Number 14
const HP := 25              # CPR core p.214: Automated Turret, 25 HP
const COUNTER_DV := 17      # CPR core p.214: Electronics/Security Tech DV17, 5 minutes (by hand: not modelled yet)
const SKILLS := ["shoulder_arms", "autofire", "handgun", "heavy_weapons", "archery", "melee_weapon"]

## The book's armaments and their rounds (CPR core p.214): Assault Rifle (25), Flamethrower (4
## incendiary), Dartgun (8), VH Pistol (8 AP), Heavy SMG (40). Each mounts its weapon's own
## magazine (weapons.json `mag`: 25, 4, 8, 40) and nobody reloads it: empty, it falls silent.
## `special`: the gear.json ammo its rounds are (the flamethrower's shells are incendiary by the
## weapon's own rules, p.348). The Dartgun is left out: its darts' payload is unmodelled
## (weapons.json `unmodelled`), so it would fire as a plain very heavy pistol.
const WEAPON := "assault_rifle"   ## the default armament
const ARMAMENTS := {
	"assault_rifle": {},
	"flamethrower": {},
	"very_heavy_pistol": {"special": "ammo/armor_piercing_ammo"},
	"heavy_smg": {},
}


## A turret as a combatant: every attack Skill at its Combat Number (REF 0 so STAT + Skill is the
## Combat Number alone), 25 HP, no armour, nothing to dodge with, armed with `weapon_id` (one of
## ARMAMENTS; anything else gets the assault rifle).
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
	if not ARMAMENTS.has(weapon_id):
		weapon_id = WEAPON
	var w := Weapon.from_id(weapon_id)
	var special := String(ARMAMENTS[weapon_id].get("special", ""))
	if special != "":
		w.load_special(Items.fx(special), w.mag())   # VH Pistol: all 8 rounds Armor-Piercing (p.214, p.345)
	c.weapons.append(w)
	return c


## Its weapon fires shotgun shells only (the flamethrower, p.348): Encounter.shotgun_shell.
static func shells(w: Weapon) -> bool:
	return bool(w.def.get("fx", {}).get("shell_only", false))
