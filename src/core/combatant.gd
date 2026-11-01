class_name Combatant
extends RefCounted
## Rules-level state of anyone in a fight: stats, skills, HP, armor, injuries, death saves.
## Pure data + rules. Scene/visual nodes reference a Combatant; never the other way round.

enum Wound { UNHURT, LIGHT, SERIOUS, MORTAL, DEAD }

const WOUND_ACTION_PENALTY := {Wound.SERIOUS: 2, Wound.MORTAL: 4}  # p220
const MORTAL_MOVE_PENALTY := 6  # p220, MOVE min 1

var id: String
var display_name: String
var team: int = 0
var stats: Dictionary = {}    ## "INT","REF","DEX","TECH","COOL","WILL","LUCK","MOVE","BODY","EMP" → int
var skills: Dictionary = {}   ## skill id → level
var hp: int
var armor: Dictionary = {"head": null, "body": null}  ## location → ArmorPiece
var injuries: Array[Dictionary] = []  ## crit table entries + {"location": ...}
var base_dsp: int = 0         ## Base Death Save Penalty (raised by some crits).
var dsp: int = 0              ## Current Death Save Penalty (base + saves rolled since last stabilization).
var dead := false
var unconscious := false
var prone := false
var weapons: Array[Weapon] = []


func _init(p_name: String = "", p_stats: Dictionary = {}, p_skills: Dictionary = {}) -> void:
	display_name = p_name
	id = p_name.to_snake_case()
	stats = p_stats
	skills = p_skills
	hp = max_hp() if not stats.is_empty() else 0


# --- Derived stats -------------------------------------------------------

func raw_stat(s: String) -> int:
	return int(stats.get(s, 0))


## STAT after armor penalty (REF/DEX/MOVE, p184) and wound/crit MOVE penalties.
func stat(s: String) -> int:
	var v := raw_stat(s)
	if s in ["REF", "DEX", "MOVE"]:
		v = maxi(0, v - armor_penalty())
	if s == "MOVE":
		var reduction := _fx_sum("move")
		if wound_state() == Wound.MORTAL:
			reduction += MORTAL_MOVE_PENALTY
		if reduction > 0:
			v = maxi(mini(v, 1), v - reduction)  # min 1 unless armor already took it to 0
	return v


func max_hp() -> int:
	return 10 + 5 * ceili((raw_stat("BODY") + raw_stat("WILL")) / 2.0)  # p79


func seriously_wounded_threshold() -> int:
	return ceili(max_hp() / 2.0)  # p79/p220


func death_save_target() -> int:
	return raw_stat("BODY")  # p79


func armor_penalty() -> int:
	var worst := 0
	for loc in armor:
		if armor[loc] != null:
			worst = maxi(worst, (armor[loc] as ArmorPiece).penalty)
	return worst


func skill_level(skill_id: String) -> int:
	return int(skills.get(skill_id, 0))


## STAT + Skill (p130), before situational modifiers.
func skill_base(skill_id: String) -> int:
	return stat(RulesDB.skill_stat(skill_id)) + skill_level(skill_id)


func wound_state() -> Wound:
	if dead:
		return Wound.DEAD
	if hp < 1:
		return Wound.MORTAL
	if hp < seriously_wounded_threshold():
		return Wound.SERIOUS
	if hp < max_hp():
		return Wound.LIGHT
	return Wound.UNHURT


## Penalty applied to every Action check (wound state + crits like Concussion).
func action_penalty() -> int:
	return int(WOUND_ACTION_PENALTY.get(wound_state(), 0)) + _fx_sum("all")


## Penalty for an attack of the given kind ("ranged" or "melee").
func attack_penalty(kind: String) -> int:
	return action_penalty() + _fx_sum(kind)


func can_dodge_ranged() -> bool:
	return stat("REF") >= 8 and not _fx_any("no_dodge") and can_act()  # p172


func can_act() -> bool:
	return not dead and not unconscious


func sp(location: String) -> int:
	var a: ArmorPiece = armor.get(location)
	return 0 if a == null else a.sp


# --- Injuries ------------------------------------------------------------

func has_injury(injury_id: String) -> bool:
	return injuries.any(func(i): return i["id"] == injury_id)


func head_multiplier() -> int:
	var m := 2
	for i in injuries:
		m = maxi(m, int(i["fx"].get("head_mult", 2)))
	return m


## Roll and apply a Critical Injury: reroll until one the target doesn't have (p220), 5 bonus HP damage.
## Returns the entry, or {} if every entry in the table is already suffered.
func suffer_crit(dice: Dice, location: String) -> Dictionary:
	var table := RulesDB.crit_table(location)
	var available := table.values().filter(func(e): return not has_injury(e["id"]))
	if available.is_empty():
		return {}
	var entry: Dictionary
	while true:
		entry = table[str(dice.roll(2, 6))]
		if not has_injury(entry["id"]):
			break
	return add_injury(entry, location)


func add_injury(entry: Dictionary, location: String) -> Dictionary:
	var inj := entry.duplicate(true)
	inj["location"] = location
	injuries.append(inj)
	var dsp_up := int(inj["fx"].get("dsp", 0))
	base_dsp += dsp_up
	dsp += dsp_up
	hp -= int(RulesDB.load_json("critical_injuries.json")["bonus_damage"])
	return inj


func _fx_sum(key: String) -> int:
	var t := 0
	for i in injuries:
		t += int(i["fx"].get(key, 0))
	return t


func _fx_any(key: String) -> bool:
	return injuries.any(func(i): return i["fx"].get(key, false))


# --- Death & stabilization ----------------------------------------------

## Roll a Death Save (p222): d10 + current penalty must be under BODY; natural 10 always fails.
## Each roll raises the penalty by 1. Returns true if the character survives.
func death_save(dice: Dice) -> bool:
	var r := dice.d(10)
	var ok := r != 10 and r + dsp < death_save_target()
	dsp += 1
	if not ok:
		dead = true
	return ok


## Chance this character survives their next Death Save.
func death_save_chance() -> float:
	var ok := 0
	for r in range(1, 10):
		if r + dsp < death_save_target():
			ok += 1
	return ok / 10.0


func stabilization_dv() -> int:
	match wound_state():
		Wound.LIGHT: return 10
		Wound.SERIOUS: return 13
		Wound.MORTAL: return 15
	return 0


## Mark as stabilized (p222-223). Mortally Wounded → 1 HP and Unconscious; penalty resets to base.
func stabilize() -> void:
	if wound_state() == Wound.MORTAL:
		hp = 1
		unconscious = true
	dsp = base_dsp
