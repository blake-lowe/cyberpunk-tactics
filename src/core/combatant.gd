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
var wake_in := 0               ## rounds until a stabilized character comes round (1 minute = 20 rounds, p223)
var prone := false
var weapons: Array[Weapon] = []
var grenades: int = 0          ## frag grenades carried (thrown: DEX + Athletics, 6d6 blast, p174/p177)

var role: String = ""         ## "solo", "netrunner", "medtech", "tech", ...
var role_rank: int = 0
## Solo Combat Awareness allocation (p146): ability id → points spent. See COMBAT_AWARENESS.
var awareness: Dictionary = {}
var tracks_humanity := false  ## Mooks skip Humanity entirely.
var humanity: int = 0
var max_humanity: int = 0
var cyberware: Array[String] = []
var subdermal: Dictionary = {}  ## location → ArmorPiece from Subdermal Armor / Skin Weave.
## Per-Round trackers for "first X this Round" abilities. Reset by new_round().
var skip_next_action := false  ## Spinal Injury (p221).
var skip_next_move := false    ## Damaged/Lost Ear after moving > 4 m (p222).
var psychosis_turns := 0      ## Remaining turns of a cyberpsychosis episode (HOUSE-RULE).
var deflection_used := false
var spot_weakness_used := false

## Combat Awareness costs (p146). Stepped abilities list the cost of each level.
const COMBAT_AWARENESS := {
	"damage_deflection": [2, 4, 6, 8, 10],
	"fumble_recovery": [4],
	"initiative_reaction": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
	"precision_attack": [3, 6, 9],
	"spot_weakness": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
	"threat_detection": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
}


func _init(p_name: String = "", p_stats: Dictionary = {}, p_skills: Dictionary = {}) -> void:
	display_name = p_name
	id = p_name.to_snake_case()
	stats = p_stats
	skills = p_skills
	hp = max_hp() if not stats.is_empty() else 0


# --- Derived stats -------------------------------------------------------

## STAT including permanent modifiers (cyberware, Humanity → EMP) but not armor or wounds.
func raw_stat(s: String) -> int:
	var v := int(stats.get(s, 0))
	if s == "EMP" and tracks_humanity:
		return maxi(0, humanity) / 10  # tens digit of current Humanity (p80)
	for fx in _cyber_fx():
		if fx.has("stat") and fx["stat"].has(s):
			v = mini(v + int(fx["stat"][s]), maxi(v, int(fx.get("stat_cap", 99))))
	return v


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
	var v := int(skills.get(skill_id, 0))
	for fx in _cyber_fx():
		if fx.has("skill"):
			v += int(fx["skill"].get(skill_id, 0))
	return v


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
	var w := wound_state()
	if w == Wound.SERIOUS and _cyber_fx().any(func(fx): return fx.get("ignore_seriously_wounded", false)):
		w = Wound.LIGHT  # Pain Editor (p112)
	return int(WOUND_ACTION_PENALTY.get(w, 0)) + _fx_sum("all")


## Penalty for an attack of the given kind ("ranged" or "melee").
func attack_penalty(kind: String) -> int:
	return action_penalty() + _fx_sum(kind)


func can_dodge_ranged() -> bool:
	return stat("REF") >= 8 and not _fx_any("no_dodge") and can_act()  # p172


func can_act() -> bool:
	return not dead and not unconscious


## SP in a location: SP doesn't stack, only the highest counts (p184), incl. subdermal armor.
func sp(location: String) -> int:
	var best := 0
	for a in [armor.get(location), subdermal.get(location)]:
		if a != null:
			best = maxi(best, (a as ArmorPiece).sp)
	return best


## All armor in a location ablates together when damage gets through (p184, p186).
func ablate(location: String) -> void:
	for a in [armor.get(location), subdermal.get(location)]:
		if a != null:
			(a as ArmorPiece).ablate()


func initiative_bonus() -> int:
	var b := awareness_level("initiative_reaction")
	for fx in _cyber_fx():
		b += int(fx.get("initiative", 0))
	return b


## Called at the start of each Round.
func new_round() -> void:
	deflection_used = false
	spot_weakness_used = false


# --- Solo: Combat Awareness (p146) --------------------------------------

## Level bought in an ability (e.g. precision_attack 2 = +2), from points allocated.
func awareness_level(ability: String) -> int:
	if role != "solo":
		return 0
	var pts := int(awareness.get(ability, 0))
	var level := 0
	for cost in COMBAT_AWARENESS[ability]:
		if pts >= cost:
			level += 1
	return level


## Set an allocation. Returns false (and changes nothing) if it exceeds Role Rank.
func set_awareness(alloc: Dictionary) -> bool:
	var total := 0
	for k in alloc:
		if not COMBAT_AWARENESS.has(k):
			return false
		total += int(alloc[k])
	if role != "solo" or total > role_rank:
		return false
	awareness = alloc.duplicate()
	return true


# --- Humanity & cyberware (p80, p110-116, p230) --------------------------

func init_humanity() -> void:
	tracks_humanity = true
	humanity = int(stats.get("EMP", 0)) * 10
	max_humanity = humanity


## Install cyberware. At character creation Humanity Loss uses the flat value; afterwards it's
## rolled (p111). Each piece with HL lowers max Humanity by 2, Borgware by 4 (p230).
## Returns the Humanity lost.
func install_cyberware(cyber_id: String, dice: Dice = null, at_creation: bool = false) -> int:
	var d: Dictionary = RulesDB.cyberware(cyber_id)
	cyberware.append(cyber_id)
	var fx: Dictionary = d.get("fx", {})
	if fx.has("armor_sp"):
		for loc in ["body", "head"]:
			var a := ArmorPiece.new()
			a.id = cyber_id
			a.name = d["name"]
			a.max_sp = int(fx["armor_sp"])
			a.sp = a.max_sp
			subdermal[loc] = a
	var loss := 0
	if tracks_humanity and int(d["hl_flat"]) > 0:
		loss = int(d["hl_flat"]) if at_creation or dice == null else roll_hl(dice, d["hl_dice"])
		humanity -= loss
		max_humanity -= 4 if d["borgware"] else 2
		humanity = mini(humanity, max_humanity)
	return loss


func has_cyberware(cyber_id: String) -> bool:
	return cyber_id in cyberware


func lose_humanity(amount: int) -> void:
	if tracks_humanity:
		humanity -= amount


## Therapy etc. Capped by max Humanity (p230).
func regain_humanity(amount: int) -> void:
	if tracks_humanity:
		humanity = mini(max_humanity, humanity + amount)


## Cyberpsychosis tier from current EMP (p232): 0 none, 1 borderline (EMP 2), 2 dissociative
## (EMP 1), 3 cyberpsychosis (EMP 0), 4 extreme (Humanity below 0).
## The book gives no mechanics for these; what each tier does in play is a game design decision.
func psychosis_tier() -> int:
	if not tracks_humanity:
		return 0
	if humanity < 0:
		return 4
	return clampi(3 - raw_stat("EMP"), 0, 3)


## HOUSE-RULE (approved): chance per combat turn that a cyberpsychosis episode starts.
const EPISODE_CHANCE := {1: 0.05, 2: 0.15, 3: 0.30}  # psychosis tier → chance


func episode_chance() -> float:
	var tier := psychosis_tier()
	return 1.0 if tier >= 4 else float(EPISODE_CHANCE.get(tier, 0.0))


## Start-of-turn episode check. Returns true if this turn is under AI control.
## Episodes last 1-2 turns; Humanity below 0 means permanent loss of control.
func check_episode(dice: Dice) -> bool:
	if psychosis_turns > 0:
		psychosis_turns -= 1
		return true
	var chance := episode_chance()
	if chance >= 1.0:
		return true
	if chance > 0.0 and dice.rng.randf() < chance:
		psychosis_turns = dice.d(2) - 1  # this turn plus 0-1 more
		return true
	return false


static func roll_hl(dice: Dice, expr: String) -> int:
	match expr:
		"1d6/2": return ceili(dice.d(6) / 2.0)
		"1d6": return dice.roll(1, 6)
		"2d6": return dice.roll(2, 6)
		"4d6": return dice.roll(4, 6)
	return 0


func cyber_fx_sum(key: String) -> int:
	var t := 0
	for fx in _cyber_fx():
		t += int(fx.get(key, 0))
	return t


func _cyber_fx() -> Array:
	var out := []
	for cid in cyberware:
		var fx: Dictionary = RulesDB.cyberware(cid).get("fx", {})
		if not fx.is_empty():
			out.append(fx)
	return out


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
	if inj["fx"].get("no_action_next_turn", false):
		skip_next_action = true
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
		wake_in = 20   # "Unconscious for 1 minute" (p223): 20 rounds of 3 s
	dsp = base_dsp
