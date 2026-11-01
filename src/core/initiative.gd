class_name Initiative
extends RefCounted
## Initiative Queue (p168): REF + 1d10, descending, ties re-rolled. Repeats each Round.
## Late joiners (reinforcements) roll and slot in immediately: they act this Round if
## their slot is still ahead of the current turn.

var entries: Array[Dictionary] = []  ## {c: Combatant, roll: int, tb: int}
var index := -1  ## Position of the combatant whose turn it is.
var round_num := 0
var _dice: Dice


func _init(dice: Dice) -> void:
	_dice = dice


func add(c: Combatant) -> Dictionary:
	# Ties: "roll again until the higher number wins" (p168). An independent random tiebreak key
	# gives the same uniform ordering among tied combatants.
	var e := {"c": c, "roll": c.stat("REF") + _dice.d(10), "tb": _dice.rng.randi()}
	var pos := entries.size()
	for i in entries.size():
		if _before(e, entries[i]):
			pos = i
			break
	entries.insert(pos, e)
	if pos <= index:
		index += 1  # keep the current turn's owner unchanged
	return e


func remove(c: Combatant) -> void:
	for i in entries.size():
		if entries[i].c == c:
			entries.remove_at(i)
			if i <= index:
				index -= 1
			return


## Advance to the next combatant able to act. Returns null if nobody can.
func next_turn() -> Combatant:
	if entries.is_empty():
		return null
	if round_num == 0:
		round_num = 1
		index = -1
	for _i in entries.size():
		index += 1
		if index >= entries.size():
			index = 0
			round_num += 1
		var c: Combatant = entries[index].c
		if not c.dead:
			return c
	return null


func current() -> Combatant:
	return null if index < 0 or index >= entries.size() else entries[index].c


func order() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for e in entries:
		out.append(e.c)
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	return a.roll > b.roll or (a.roll == b.roll and a.tb > b.tb)
