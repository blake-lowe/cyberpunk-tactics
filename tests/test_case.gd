class_name TestCase
extends RefCounted
## Base class for unit tests. Methods named `test_*` are run by tests/run_tests.gd.
## Assertions record failures instead of aborting, so one test reports all problems.

var failures: Array[String] = []


func before_each() -> void:
	pass


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("expected true. " + msg)


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		failures.append("expected false. " + msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("expected %s, got %s. %s" % [var_to_str(expected), var_to_str(actual), msg])


func assert_near(actual: float, expected: float, tol: float = 0.0001, msg: String = "") -> void:
	if absf(actual - expected) > tol:
		failures.append("expected %f ± %f, got %f. %s" % [expected, tol, actual, msg])


func assert_between(actual: float, lo: float, hi: float, msg: String = "") -> void:
	if actual < lo or actual > hi:
		failures.append("expected %s in [%s, %s]. %s" % [actual, lo, hi, msg])


## Extraction (every job ends with the way out, Encounter._job_done): the job's done, so walk every
## crew member still standing onto the job's ways out and run the end check.
func walk_out(e: Encounter) -> void:
	assert_true(e.obj.extracting(), "the job's done: only the way out is left")
	assert_eq(e.state, "playing", "the job done doesn't end the gig on the spot")
	var exits: Array = e.obj.exit_cells()
	var used := {}
	for u in e.units:
		if int(u.team) != Encounter.CREW or e.is_hostage(u) or not u.c.can_act():
			continue
		if exits.has(u.pos) and not used.has(u.pos):
			used[u.pos] = true
			continue
		for c in exits:
			if not used.has(c) and not e.occupied(u).has(c):
				u.pos = c
				used[c] = true
				break
	e._check_end()
