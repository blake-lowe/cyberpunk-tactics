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
