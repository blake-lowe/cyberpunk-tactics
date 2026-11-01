class_name Attack
extends RefCounted
## Resolves one attack check (one of up to ROF checks per Action) and previews its hit chance.
## Ranged p172-174, aimed shots p170, autofire p173, melee p176, damage & armor p186, crits p220.

enum Mode { SINGLE, AUTOFIRE, AIMED_HEAD, AIMED_LEG, AIMED_HELD }

const AIMED_PENALTY := 8  # p170
const MELEE_REACH_M := 2.0  # p176
const AUTOFIRE_AMMO := 10  # p173


static func is_aimed(mode: Mode) -> bool:
	return mode in [Mode.AIMED_HEAD, Mode.AIMED_LEG, Mode.AIMED_HELD]


## Attacker's STAT + Skill + modifiers for this attack.
static func attack_base(attacker: Combatant, weapon: Weapon, mode: Mode) -> int:
	var skill := "autofire" if mode == Mode.AUTOFIRE else weapon.skill()
	var base := attacker.skill_base(skill)
	base -= attacker.attack_penalty("melee" if weapon.is_melee() else "ranged")
	if is_aimed(mode):
		base -= AIMED_PENALTY
	return base


## Everything the UI needs before committing: legality, DV source and exact hit chance.
## Keys: ok, reason, base, dv (fixed DV or -1), defense_base (opposed or -1), chance.
static func preview(attacker: Combatant, weapon: Weapon, defender: Combatant, mode: Mode, distance_m: float) -> Dictionary:
	var p := {"ok": false, "reason": "", "base": 0, "dv": -1, "defense_base": -1, "chance": 0.0}
	var reason := _illegal_reason(weapon, mode, distance_m)
	if reason != "":
		p.reason = reason
		return p
	p.ok = true
	p.base = attack_base(attacker, weapon, mode)

	var evasion := defender.skill_base("evasion") - defender.action_penalty()
	if weapon.is_melee():
		# Melee is always opposed by DEX + Evasion (p176).
		# HOUSE-RULE: a defender who can't act (unconscious) gets no Evasion, only the die.
		p.defense_base = evasion if defender.can_act() else 0
		p.chance = Check.chance_opposed(p.base, p.defense_base)
		return p

	p.dv = RulesDB.range_dv(_range_key(weapon, mode), distance_m, mode == Mode.AUTOFIRE)
	p.chance = Check.chance_vs_dv(p.base, p.dv)
	# REF 8+ defenders may dodge instead (p172). They do so whenever it lowers the hit chance.
	if defender.can_dodge_ranged():
		var dodge_chance := Check.chance_opposed(p.base, evasion)
		if dodge_chance < p.chance:
			p.defense_base = evasion
			p.chance = dodge_chance
	return p


## Roll the attack and apply all consequences to `defender`. Consumes ammo.
## Result keys: ok, reason, hit, check, damage, faces, location, through, crits, dropped_item.
static func resolve(dice: Dice, attacker: Combatant, weapon: Weapon, defender: Combatant, mode: Mode, distance_m: float) -> Dictionary:
	var p := preview(attacker, weapon, defender, mode, distance_m)
	var r := {"ok": p.ok, "reason": p.reason, "hit": false, "check": null, "damage": 0, "faces": PackedInt32Array(),
		"location": "head" if mode == Mode.AIMED_HEAD else "body", "through": 0, "crits": [], "dropped_item": false}
	if not p.ok:
		return r
	if weapon.uses_ammo():
		weapon.ammo -= AUTOFIRE_AMMO if mode == Mode.AUTOFIRE else 1

	var check: Check
	if p.defense_base >= 0:
		check = Check.opposed(dice, p.base, p.defense_base)
	else:
		check = Check.vs_dv(dice, p.base, p.dv)
	r.check = check
	r.hit = check.success
	if not r.hit:
		return r

	var crit_trigger := false
	if mode == Mode.AUTOFIRE:
		var faces := dice.roll_each(2, 6)
		r.faces = faces
		r.damage = (faces[0] + faces[1]) * mini(check.total - check.dv, weapon.autofire_mult())
		crit_trigger = faces[0] == 6 and faces[1] == 6
	else:
		var faces := dice.roll_each(weapon.dice(), 6)
		r.faces = faces
		for f in faces:
			r.damage += f
		crit_trigger = faces.count(6) >= 2

	apply_damage(dice, defender, r, weapon.is_melee(), mode == Mode.AIMED_HEAD, crit_trigger)

	if r.through > 0:
		if mode == Mode.AIMED_HELD:
			r.dropped_item = true
		elif mode == Mode.AIMED_LEG and not (defender.has_injury("broken_leg") or defender.has_injury("dismembered_leg")):
			r.crits.append(defender.add_injury(RulesDB.crit_table("body")["8"], "body"))
	return r


## Apply rolled damage `r.damage` at `r.location`. Fills r.through and r.crits.
## Used by attacks and by area effects (explosions) that hit a combatant.
static func apply_damage(dice: Dice, defender: Combatant, r: Dictionary, halve_sp: bool, head_aimed: bool, crit_trigger: bool) -> void:
	var was_mortal := defender.wound_state() == Combatant.Wound.MORTAL
	var sp := defender.sp(r.location)
	if halve_sp:
		sp = ceili(sp / 2.0)  # p176
	var through := maxi(0, int(r.damage) - sp)
	if through > 0:
		if head_aimed:
			through *= defender.head_multiplier()  # p170, Cracked Skull p222
		defender.hp -= through
		var a: ArmorPiece = defender.armor.get(r.location)
		if a != null:
			a.ablate()  # p186
	r.through = through

	# Crit on 2+ sixes regardless of SP (p220). Mortally Wounded targets also take a crit and +1 DSP
	# whenever damaged by an attack (p220). One crit per attack even if both apply.
	var damaged_while_mortal := was_mortal and through > 0
	if crit_trigger or damaged_while_mortal:
		var c := defender.suffer_crit(dice, "head" if head_aimed else "body")
		if not c.is_empty():
			r.crits.append(c)
	if damaged_while_mortal:
		defender.dsp += 1


static func _range_key(weapon: Weapon, mode: Mode) -> String:
	return weapon.def["autofire_range"] if mode == Mode.AUTOFIRE else weapon.def["range"]


static func _illegal_reason(weapon: Weapon, mode: Mode, distance_m: float) -> String:
	if weapon.is_melee():
		if mode == Mode.AUTOFIRE:
			return "no autofire"
		return "out of reach" if distance_m > MELEE_REACH_M else ""
	if mode == Mode.AUTOFIRE:
		if weapon.autofire_mult() == 0:
			return "no autofire"
		if weapon.ammo < AUTOFIRE_AMMO:
			return "need 10 rounds"
	elif weapon.uses_ammo() and weapon.ammo < 1:
		return "empty"
	if RulesDB.range_dv(_range_key(weapon, mode), distance_m, mode == Mode.AUTOFIRE) < 0:
		return "out of range"
	return ""
