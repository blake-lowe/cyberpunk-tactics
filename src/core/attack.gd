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
		base += attacker.cyber_fx_sum("aimed_bonus")  # Targeting Scope
	base += attacker.awareness_level("precision_attack")  # Solo (p146)
	return base


## Everything the UI needs before committing: legality, DV source and exact hit chance.
## Keys: ok, reason, base, dv (fixed DV or -1), defense_base (opposed or -1), chance.
static func preview(attacker: Combatant, weapon: Weapon, defender: Combatant, mode: Mode, distance_m: float) -> Dictionary:
	var p := {"ok": false, "reason": "", "base": 0, "dv": -1, "defense_base": -1, "chance": 0.0}
	var nf := attacker.awareness_level("fumble_recovery") > 0
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
		p.chance = Check.chance_opposed(p.base, p.defense_base, nf)
		return p

	p.dv = RulesDB.range_dv(_range_key(weapon, mode), distance_m, mode == Mode.AUTOFIRE)
	p.chance = Check.chance_vs_dv(p.base, p.dv, nf)
	# REF 8+ defenders may dodge instead (p172). They do so whenever it lowers the hit chance.
	if defender.can_dodge_ranged():
		var dodge_chance := Check.chance_opposed(p.base, evasion, nf)
		if dodge_chance < p.chance:
			p.defense_base = evasion
			p.chance = dodge_chance
	return p


## Roll the attack and apply all consequences to `defender`. Consumes ammo.
## Result keys: ok, reason, hit, check, damage, faces, location, through, crits, dropped_item.
static func resolve(dice: Dice, attacker: Combatant, weapon: Weapon, defender: Combatant, mode: Mode, distance_m: float) -> Dictionary:
	var p := preview(attacker, weapon, defender, mode, distance_m)
	var r := {"ok": p.ok, "reason": p.reason, "hit": false, "check": null, "damage": 0, "faces": PackedInt32Array(),
		"location": "head" if mode == Mode.AIMED_HEAD else "body", "through": 0, "crits": [], "dropped_item": false, "dodged": false}
	if not p.ok:
		return r
	if weapon.uses_ammo():
		weapon.ammo -= AUTOFIRE_AMMO if mode == Mode.AUTOFIRE else 1

	var check: Check
	var nf := attacker.awareness_level("fumble_recovery") > 0
	if p.defense_base >= 0:
		check = Check.opposed(dice, p.base, p.defense_base, nf)
	else:
		check = Check.vs_dv(dice, p.base, p.dv, nf)
	r.check = check
	r.hit = check.success
	r.dodged = p.defense_base >= 0 and not weapon.is_melee() and not r.hit  # for the "DODGE" callout
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

	# Solo Spot Weakness: +damage before armor on the first successful attack each Round (p146).
	var sw := attacker.awareness_level("spot_weakness")
	if sw > 0 and not attacker.spot_weakness_used:
		attacker.spot_weakness_used = true
		r.damage += sw
	apply_damage(dice, defender, r, weapon.halves_sp(), mode == Mode.AIMED_HEAD, crit_trigger)

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
		defender.ablate(r.location)  # p186
		# Solo Damage Deflection (p146): reduces the first damage taken this Round.
		# Interpretation: applied to HP damage after armor and head multiplier.
		var dd := defender.awareness_level("damage_deflection")
		if dd > 0 and not defender.deflection_used:
			defender.deflection_used = true
			through = maxi(0, through - dd)
		defender.hp -= through
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


# --- Area attacks ---------------------------------------------------------
# Geometry (who is in the cone/blast, who is behind cover that survives) is the caller's job;
# these functions take the already-selected targets.

const SHOTGUN_SHELL_DV := 13  # p174
const SHOTGUN_SHELL_DICE := 3
const SHOTGUN_SHELL_RANGE_M := 6.0
const SUPPRESSIVE_RANGE_M := 25.0


## Shotgun Shell (p174): one attack vs DV13; on a hit every target in the cone takes the same 3d6.
## Returns {ok, reason, hit, check, faces, results: [{target, dodged, through, crits}]}.
static func shotgun_shell(dice: Dice, attacker: Combatant, weapon: Weapon, targets: Array) -> Dictionary:
	var out := {"ok": false, "reason": "", "hit": false, "check": null, "faces": PackedInt32Array(), "results": []}
	if not weapon.def.get("shotgun_shell", false):
		out.reason = "no shotgun shells"
		return out
	if weapon.ammo < 1:
		out.reason = "empty"
		return out
	out.ok = true
	weapon.ammo -= 1
	var check := Check.vs_dv(dice, attack_base(attacker, weapon, Mode.SINGLE), SHOTGUN_SHELL_DV,
		attacker.awareness_level("fumble_recovery") > 0)
	out.check = check
	out.hit = check.success
	if out.hit:
		out.faces = dice.roll_each(SHOTGUN_SHELL_DICE, 6)
		out.results = _area_hit(dice, check.total, out.faces, targets, false)
	return out


## Explosive (p174): damage rolled once for everyone in the blast. If the attack missed, the caller
## scatters the blast centre and passes the targets around the new centre; damage still applies.
## REF 8+ targets dodge by rolling higher than the attack total.
static func explosion(dice: Dice, attack_total: int, damage_dice: int, targets: Array) -> Dictionary:
	var faces := dice.roll_each(damage_dice, 6)
	return {"faces": faces, "results": _area_hit(dice, attack_total, faces, targets, true)}


## Suppressive Fire (p174): every on-foot, uncovered target in LOS within 25 m rolls
## WILL + Concentration vs the attacker's REF + Autofire. Losers must move to cover next turn.
## Returns the targets who failed. Interpretation: ties go to the defender (general rule, p172).
static func suppressive_fire(dice: Dice, attacker: Combatant, weapon: Weapon, targets: Array) -> Dictionary:
	var out := {"ok": false, "reason": "", "suppressed": []}
	if not weapon.def.get("suppressive", false):
		out.reason = "no suppressive fire"
		return out
	if weapon.ammo < AUTOFIRE_AMMO:
		out.reason = "need 10 rounds"
		return out
	out.ok = true
	weapon.ammo -= AUTOFIRE_AMMO
	var base := attacker.skill_base("autofire") - attacker.action_penalty()
	for t in targets:
		var resist: int = t.skill_base("concentration") - t.action_penalty()
		if Check.opposed(dice, base, resist).success:
			out.suppressed.append(t)
	return out


## Chance one target resists suppression (for the UI).
static func suppressive_resist_chance(attacker: Combatant, target: Combatant) -> float:
	var base := attacker.skill_base("autofire") - attacker.action_penalty()
	return 1.0 - Check.chance_opposed(base, target.skill_base("concentration") - target.action_penalty())


static func _area_hit(dice: Dice, attack_total: int, faces: PackedInt32Array, targets: Array, dodge_strict: bool) -> Array:
	var damage := 0
	for f in faces:
		damage += f
	var results := []
	for t: Combatant in targets:
		var res := {"target": t, "dodged": false, "damage": damage, "location": "body", "through": 0, "crits": []}
		if t.can_dodge_ranged():
			var ev: int = Check.roll_die(dice).die + t.skill_base("evasion") - t.action_penalty()
			res.dodged = ev > attack_total if dodge_strict else ev >= attack_total
		if not res.dodged:
			apply_damage(dice, t, res, false, false, faces.count(6) >= 2)
		results.append(res)
	return results
