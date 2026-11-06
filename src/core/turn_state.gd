class_name TurnState
extends RefCounted
## One combatant's turn budget (p168-169): 1 Move Action + 1 Action.
## - Movement is a pool of squares (MOVE per Move Action). It can be split around the Action.
## - Run spends the Action for a second Move Action, only after a Move Action was taken.
## - An attack Action grants up to ROF attack checks (max 2) which can be split around movement.
## Also applies start/end-of-turn rules: Death Saves, Spinal Injury, Damaged Ear, Broken Ribs.

const SQUARE_M := 2.0  # 1 square = 2 m/yds (p126)
const STRAIN_DISTANCE_M := 4.0  # Broken Ribs / Foreign Object / Damaged Ear threshold (p221-222)

var c: Combatant
var move_actions := 1
var action_available := true
var move_left := 0          ## Squares remaining from Move Actions already started.
var squares_moved := 0
var moved_this_turn := false
var attacks_left := 0       ## Remaining attack checks from the current attack Action.
var attack_weapon: Weapon = null
var survived := true        ## False if the opening Death Save failed.
var psychotic := false      ## Cyberpsychosis episode: the AI controls this turn.


## Start a turn. Rolls the Death Save if Mortally Wounded (p222).
static func begin(dice: Dice, combatant: Combatant) -> TurnState:
	var t := TurnState.new()
	t.c = combatant
	if combatant.unconscious and combatant.wake_in > 0:   # coming round after stabilization (p223)
		combatant.wake_in -= 1
		if combatant.wake_in == 0:
			combatant.unconscious = false
	if combatant.wound_state() == Combatant.Wound.MORTAL and not combatant.dead:
		if combatant.death_saves:
			t.survived = combatant.death_save(dice)
		else:   # HOUSE-RULE (NPC_FLATLINE, Encounter._flatline_npcs): an NPC below 1 HP flatlines
			combatant.dead = true
			t.survived = false
	if not t.survived or not combatant.can_act():
		t.move_actions = 0
		t.action_available = false
		return t
	t.psychotic = combatant.check_episode(dice)
	if combatant.skip_next_action:  # Spinal Injury (p221)
		combatant.skip_next_action = false
		t.action_available = false
	if combatant.skip_next_move:  # Damaged / Lost Ear (p222)
		combatant.skip_next_move = false
		t.move_actions = 0
	if combatant.prone:
		t.move_actions = 0  # must Get Up first (p168)
	if combatant.is_grappled():
		t.move_actions = 0  # held: no Move Action, dragged along by the Attacker's (p.177)
	return t


func can_move() -> bool:
	return move_left > 0 or move_actions > 0


## Spend `squares` of movement, starting the Move Action if needed. Returns false if not enough.
func move(squares: int) -> bool:
	if squares <= 0:
		return true
	if squares > move_left and move_actions > 0:
		move_actions -= 1
		move_left += c.stat("MOVE")
		moved_this_turn = true
	if squares > move_left:
		return false
	move_left -= squares
	squares_moved += squares
	return true


## Max squares available right now without spending the Action on Run.
func squares_available() -> int:
	return move_left + (c.stat("MOVE") if move_actions > 0 else 0)


## Run (p169): spend the Action for another Move Action. Requires having taken a Move Action.
func run() -> bool:
	if not action_available or not moved_this_turn or move_actions > 0:
		return false
	action_available = false
	move_actions += 1
	return true


## Begin an attack Action with `weapon`: grants up to ROF attack checks (p169).
## Autofire, aimed shots and other full-Action modes grant one.
func start_attack(weapon: Weapon, single_check: bool = false) -> bool:
	if not action_available:
		return false
	action_available = false
	attack_weapon = weapon
	attacks_left = 1 if single_check else mini(2, weapon.rof())
	return true


## Take one attack check with `weapon` (p169): a fresh attack Action, or the second check of a
## 2 ROF one. That second check must itself be a single attack with a 2 ROF weapon (the same one or
## another 2 ROF weapon); Autofire, Aimed Shots and ROF 1 weapons take a whole Action (p169-170).
## `single_check`: this attack takes the whole Action.
func take_attack(weapon: Weapon, single_check: bool) -> bool:
	if attacks_left > 0:
		if single_check or weapon.rof() < 2:
			return false
		return use_attack()
	if not start_attack(weapon, single_check):
		return false
	return use_attack()


## Consume one attack check. Returns false if none remain.
func use_attack() -> bool:
	if attacks_left <= 0:
		return false
	attacks_left -= 1
	return true


## Spend the Action on anything else (reload, use object, skill, stand up, ...).
func use_action() -> bool:
	if not action_available:
		return false
	action_available = false
	return true


## Get Up from Prone costs the Action and restores the Move Action (p168). Still held in a
## grapple, they stay without one (p.177).
func get_up() -> bool:
	if not c.prone or not use_action():
		return false
	c.prone = false
	if not c.is_grappled():
		move_actions = 1
	return true


## Out of a grapple mid-turn (escaped): the Move Action the hold took is theirs again if it's
## unspent. RULES-UNVERIFIED: p.177 only says the Defender can't use one while held.
func freed() -> void:
	if not moved_this_turn and not c.prone and move_left == 0:
		move_actions = maxi(move_actions, 1)


## End of turn: strain injuries trigger after moving more than 4 m/yds on foot (p221-222).
## Returns HP damage taken from Broken Ribs / Foreign Object.
func end() -> int:
	var dmg := 0
	if squares_moved * SQUARE_M > STRAIN_DISTANCE_M:
		for inj in c.injuries:
			if inj["fx"].get("move_bleed", false):
				dmg += int(RulesDB.load_json("critical_injuries.json")["bonus_damage"])
			if inj["fx"].get("move_stagger", false):
				c.skip_next_move = true
	c.hp -= dmg
	return dmg
