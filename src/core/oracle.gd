class_name Oracle
extends RefCounted
## The Closed Question Oracle (Cyberpunk RED: Single Player Mode, SPM p.12-13; table reprinted
## SPM p.32): frame a yes/no question so that yes is the more interesting answer, choose how
## likely yes is, roll 1d100. Five answers, low rolls to high: no, no with a complication,
## complicated (neither: the question turns into a different problem), yes with a complication,
## yes. Pure rules: the roll comes from the seeded Dice passed in; chance() gives exact odds.

const LIKELIHOODS := ["certain", "likely", "even", "unlikely", "impossible"]   ## "even" is the book's 50/50
const OUTCOMES := ["no", "no_complication", "complicated", "yes_complication", "yes"]
## The top roll of each of the first four answers, by likelihood (SPM p.13); 100 and below that is yes.
const BANDS := {
	"certain": [5, 10, 15, 40],      # SPM p.13
	"likely": [15, 25, 35, 55],      # SPM p.13
	"even": [20, 30, 40, 60],        # SPM p.13
	"unlikely": [40, 55, 65, 75],    # SPM p.13
	"impossible": [75, 85, 90, 95],  # SPM p.13
}
const NAMES := {"certain": "Certain", "likely": "Likely", "even": "50/50", "unlikely": "Unlikely", "impossible": "Impossible"}


## The answer a d100 `roll` gives at `likelihood` (an OUTCOMES name).
static func outcome_for(roll: int, likelihood: String) -> String:
	var b: Array = BANDS.get(likelihood, BANDS.even)
	for i in b.size():
		if roll <= int(b[i]):
			return OUTCOMES[i]
	return OUTCOMES[-1]


## Ask the Oracle: {likelihood, roll, outcome, yes (either yes answer), complication (any of the
## middle three answers)}.
static func ask(dice: Dice, likelihood: String) -> Dictionary:
	var lk := likelihood if BANDS.has(likelihood) else "even"
	var r := dice.d(100)
	var out := outcome_for(r, lk)
	return {"likelihood": lk, "roll": r, "outcome": out, "yes": is_yes(out), "complication": out in ["no_complication", "complicated", "yes_complication"]}


static func is_yes(outcome: String) -> bool:
	return outcome == "yes" or outcome == "yes_complication"


## Exact chance of `outcome` at `likelihood` (0..1).
static func chance(likelihood: String, outcome: String) -> float:
	var b: Array = BANDS.get(likelihood, BANDS.even)
	var i := OUTCOMES.find(outcome)
	if i < 0:
		return 0.0
	var lo := 0 if i == 0 else int(b[i - 1])
	var hi := 100 if i >= b.size() else int(b[i])
	return float(hi - lo) / 100.0


## Exact chance of a yes (either kind) at `likelihood`.
static func chance_yes(likelihood: String) -> float:
	return chance(likelihood, "yes") + chance(likelihood, "yes_complication")
