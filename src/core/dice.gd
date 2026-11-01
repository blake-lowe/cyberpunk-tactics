class_name Dice
extends RefCounted
## Seeded dice roller. All randomness in rules code goes through a Dice instance
## so combat, generation and tests are reproducible from a seed.

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


func d(sides: int) -> int:
	return rng.randi_range(1, sides)


## Sum of `count` dice with `sides` faces, e.g. roll(3, 6) for 3d6.
func roll(count: int, sides: int) -> int:
	var total := 0
	for i in count:
		total += d(sides)
	return total


## Individual results, for rules that inspect faces (e.g. two 6s on damage → Critical Injury).
func roll_each(count: int, sides: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in count:
		out.append(d(sides))
	return out
