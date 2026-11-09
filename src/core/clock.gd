class_name Clock
extends RefCounted
## A Solo Play Clock (Cyberpunk RED: Single Player Mode, SPM p.25-26): a hidden-length timer.
## A pool of d6s; on each trigger the whole pool is rolled and every die showing a dropping face
## (a 1) is removed; when the pool is empty the event happens. Pure rules: every roll comes from
## the seeded Dice passed in, and the state saves to a plain Dictionary (to_dict / from_dict).
##
## The book's variants (SPM p.26), each a field:
## - drop_on [1, 6]: "Scale up the Difficulty", dice go on a 1 or a 6 (empties about twice as fast);
## - add_die(): "Reclaiming Their Time", a hard and risky success adds a d6 back (never above the
##   pool the clock started with: HOUSE-RULE, the book sets no cap and an unbounded pool would let
##   a crew stall a clock for ever);
## - escalate: "Degrees of Consequence", when the roll that empties the pool takes two or more dice
##   the outcome lands harder (`escalated`).
## Devil's Luck (a die spent to refresh LUCK) is not modelled: LUCK isn't spent in play yet.
## Simulated means (one trigger at a time, drop on 1): 3d6 empties after ~10.6 rolls, 5d6 ~13,
## 8d6 ~15.4 (SPM p.25 gives about 10.5 / 13 / 15). expected_rolls() is the exact figure.

const STATES := ["running", "empty", "stopped"]

var id := ""                       ## what the clock tracks: "detection", "time_limit", ...
var label := ""                    ## the HUD's name ("DETECTION")
var size := 0                      ## dice the clock started with (the cap for add_die)
var pool := 0                      ## dice left
var drop_on: Array = [1]           ## faces that remove a die (SPM p.25; [1, 6] the harder variant, p.26)
var escalate := true               ## Degrees of Consequence (SPM p.26)
var triggers: Array = []           ## the trigger kinds the encounter rolls it on (Encounter.clock_trigger)
var state := "running"             ## running | empty (the event fired) | stopped (moot: overtaken by events)
var rolls := 0                     ## triggers rolled
var reclaimed := 0                 ## dice added back
var escalated := false             ## it emptied on a roll that took two or more dice
var last: Array = []               ## the last roll's faces, one per die rolled (in pool order)
var meta := {}                     ## the owner's notes (the encounter's: what it does when empty)


static func make(p_id: String, p_size: int, p_drop_on: Array = [1], p_escalate := true, p_triggers: Array = [], p_label := "") -> Clock:
	var c := Clock.new()
	c.id = p_id
	c.label = p_label if p_label != "" else p_id.to_upper()
	c.size = maxi(1, p_size)
	c.pool = c.size
	c.drop_on = p_drop_on.map(func(f): return int(f))
	c.escalate = p_escalate
	c.triggers = p_triggers.duplicate()
	return c


func running() -> bool:
	return state == "running"


func is_empty() -> bool:
	return state == "empty"


## Does a face remove a die?
func drops(face: int) -> bool:
	return drop_on.has(face)


## Roll the pool once (a trigger). `forced` sets the faces instead (review renders; the rest of the
## pool is rolled when it is short). Returns {faces, removed (indices into faces), left, emptied,
## escalated}; {} when the clock isn't running.
func trigger(dice: Dice, forced: Array = []) -> Dictionary:
	if not running() or pool <= 0:
		return {}
	var faces: Array = []
	for i in pool:
		faces.append(int(forced[i]) if i < forced.size() else dice.d(6))
	var removed: Array = []
	for i in faces.size():
		if drops(int(faces[i])):
			removed.append(i)
	rolls += 1
	last = faces
	pool -= removed.size()
	var emptied := pool <= 0
	if emptied:
		pool = 0
		state = "empty"
		escalated = escalate and removed.size() >= 2   # SPM p.26: the last two or more dice in one roll
	return {"faces": faces, "removed": removed, "left": pool, "emptied": emptied, "escalated": escalated and emptied}


## Reclaiming Their Time (SPM p.26): add `n` dice back, up to the starting pool. Returns the dice
## actually added (0 when the clock isn't running or is full).
func add_die(n := 1) -> int:
	if not running():
		return 0
	var add := mini(n, size - pool)
	pool += add
	reclaimed += add
	return add


## The clock is overtaken by events (the alarm went up some other way): it stops rolling.
func stop() -> void:
	if running():
		state = "stopped"


## Exact expected number of triggers to empty a fresh pool of `n` dice when each die goes with
## chance `p` per roll: E[max of n geometric] = sum over t >= 0 of 1 - (1 - (1 - p)^t)^n.
static func expected_rolls(n: int, p: float) -> float:
	var s := 0.0
	for t in 4000:
		var term := 1.0 - pow(1.0 - pow(1.0 - p, t), n)
		s += term
		if term < 1e-9 and t > 0:
			break
	return s


## The chance a single die drops on one roll.
func drop_chance() -> float:
	return float(drop_on.size()) / 6.0


func to_dict() -> Dictionary:
	return {"id": id, "label": label, "size": size, "pool": pool, "drop_on": drop_on.duplicate(), "escalate": escalate,
		"triggers": triggers.duplicate(), "state": state, "rolls": rolls, "reclaimed": reclaimed, "escalated": escalated,
		"last": last.duplicate(), "meta": meta.duplicate(true)}


static func from_dict(d: Dictionary) -> Clock:
	var c := Clock.new()
	c.id = String(d.get("id", ""))
	c.label = String(d.get("label", c.id.to_upper()))
	c.size = maxi(1, int(d.get("size", 1)))
	c.pool = clampi(int(d.get("pool", c.size)), 0, c.size)
	c.drop_on = (d.get("drop_on", [1]) as Array).map(func(f): return int(f))
	c.escalate = bool(d.get("escalate", true))
	c.triggers = (d.get("triggers", []) as Array).map(func(t): return String(t))
	c.state = String(d.get("state", "running")) if String(d.get("state", "running")) in STATES else "running"
	c.rolls = int(d.get("rolls", 0))
	c.reclaimed = int(d.get("reclaimed", 0))
	c.escalated = bool(d.get("escalated", false))
	c.last = (d.get("last", []) as Array).map(func(f): return int(f))
	c.meta = (d.get("meta", {}) as Dictionary).duplicate(true)
	return c
