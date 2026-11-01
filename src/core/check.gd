class_name Check
extends RefCounted
## Cyberpunk RED d10 checks and their exact probabilities.
## Check total = base (STAT + Skill + modifiers) + check die. Success = total beats DV (p129).
## Check die (p130): natural 10 → 10 + 1d10 (Critical Success); natural 1 → 1 − 1d10
## (Critical Failure). Neither chains.

enum Crit { NONE, SUCCESS, FAILURE }

var natural: int
var die: int        ## Value of the check die after critical adjustment.
var crit: Crit
var total: int
var dv: int
var success: bool


## Roll a check die with critical handling. Returns {natural, die, crit}.
## `no_fumble`: Solo Fumble Recovery (p146) — a natural 1 just counts as 1.
static func roll_die(dice: Dice, no_fumble: bool = false) -> Dictionary:
	var n := dice.d(10)
	if n == 10:
		return {"natural": n, "die": 10 + dice.d(10), "crit": Crit.SUCCESS}
	if n == 1 and not no_fumble:
		return {"natural": n, "die": 1 - dice.d(10), "crit": Crit.FAILURE}
	return {"natural": n, "die": n, "crit": Crit.NONE}


## Resolve base vs a fixed DV.
static func vs_dv(dice: Dice, base: int, target_dv: int, no_fumble: bool = false) -> Check:
	var c := Check.new()
	var r := roll_die(dice, no_fumble)
	c.natural = r.natural
	c.die = r.die
	c.crit = r.crit
	c.total = base + c.die
	c.dv = target_dv
	c.success = c.total > target_dv
	return c


## Resolve an opposed check. The defender's rolled total becomes the DV,
## and the defender wins ties (p172).
static func opposed(dice: Dice, attacker_base: int, defender_base: int, no_fumble: bool = false) -> Check:
	var d := roll_die(dice)
	return vs_dv(dice, attacker_base, defender_base + d.die, no_fumble)


static var _dist: Dictionary = {}
static var _dist_no_fumble: Dictionary = {}

## Probability mass of the check die: {value: probability}. Cached.
static func die_distribution(no_fumble: bool = false) -> Dictionary:
	if _dist.is_empty():
		for f in range(2, 10):
			_dist[f] = 0.1
			_dist_no_fumble[f] = 0.1
		for k in range(1, 11):
			_dist[10 + k] = 0.01
			_dist[1 - k] = 0.01
			_dist_no_fumble[10 + k] = 0.01
		_dist_no_fumble[1] = 0.1
	return _dist_no_fumble if no_fumble else _dist


## P(base + die > dv). This is what the UI shows as the hit/success percentage.
static func chance_vs_dv(base: int, target_dv: int, no_fumble: bool = false) -> float:
	var p := 0.0
	var dist := die_distribution(no_fumble)
	for v in dist:
		if base + v > target_dv:
			p += dist[v]
	return p


## P(attacker_base + die_a > defender_base + die_d).
static func chance_opposed(attacker_base: int, defender_base: int, no_fumble: bool = false) -> float:
	var p := 0.0
	var dist := die_distribution()
	for v in dist:
		p += dist[v] * chance_vs_dv(attacker_base, defender_base + v, no_fumble)
	return p
