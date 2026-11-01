class_name NetRun
extends RefCounted
## A Netrunner's session in an Architecture (p197-201). Ability checks are Interface Rank + 1d10
## vs DV (p198). Moving within the Architecture is free, but you can't move past a Password you
## haven't broken (p198). Black ICE combat and Programs arrive with the M3 greybox.

var arch: NetArchitecture
var runner: Combatant
var current := -1
var revealed := {}   ## floor id → true (Pathfinder or visited)
var broken := {}     ## Password floors Backdoored
var held := {}       ## Control floors taken
var identified := {} ## File floors Eye-Dee'd


static func interface_rank(c: Combatant) -> int:
	return c.role_rank if c.role == "netrunner" else 0


## NET Actions per turn by Interface Rank (p197).
static func net_actions(rank: int) -> int:
	var n := 0
	for row in RulesDB.load_json("net.json")["net_actions_by_rank"]:
		if rank >= int(row[0]):
			n = int(row[1])
	return n


func _init(p_arch: NetArchitecture, p_runner: Combatant) -> void:
	arch = p_arch
	runner = p_runner


func rank() -> int:
	return interface_rank(runner)


## Jack in at an access point (must be within 6 m in meatspace — checked by the tactical layer).
func jack_in(access_point: int) -> void:
	current = int(arch.access_points[access_point].entry_floor)
	revealed[current] = true


func jack_out() -> void:
	current = -1


func cur_floor() -> Dictionary:
	return arch.floors[current]


## Can the runner stand on floor `id`? Up the tree is always open; going down, every Password
## strictly between here and the target must be broken (and the current floor, if a Password).
func can_move_to(id: int) -> bool:
	if current < 0:
		return false
	var path := arch.path_to(id)
	var here := path.find(current)
	if here < 0:
		return arch.path_to(current).has(id)  # moving up
	for i in range(here, path.size() - 1):
		var f: Dictionary = arch.floors[path[i]]
		if f.type == "password" and not broken.has(f.id):
			return false
	return true


func move_to(id: int) -> bool:
	if not can_move_to(id):
		return false
	current = id
	revealed[id] = true
	return true


## Exact chance for an ability against the current floor (or the given DV).
func chance(dv: int) -> float:
	return Check.chance_vs_dv(rank(), dv)


func backdoor(dice: Dice) -> Check:
	var f: Dictionary = cur_floor()
	assert(f.type == "password")
	var c := Check.vs_dv(dice, rank(), int(f.dv))
	if c.success:
		broken[f.id] = true
	return c


func control(dice: Dice) -> Check:
	var f: Dictionary = cur_floor()
	assert(f.type == "control")
	var c := Check.vs_dv(dice, rank(), int(f.dv))
	if c.success:
		held[f.id] = true
	return c


func eye_dee(dice: Dice) -> Check:
	var f: Dictionary = cur_floor()
	assert(f.type == "file")
	var c := Check.vs_dv(dice, rank(), int(f.dv))
	if c.success:
		identified[f.id] = true
	return c


## Pathfinder (p199): reveal as many floors below as the check total, stopping at (and showing)
## the first Password whose DV beats the check. Returns the floors newly revealed.
func pathfinder(dice: Dice) -> Array[int]:
	var c := Check.vs_dv(dice, rank(), 0)
	var out: Array[int] = []
	var frontier: Array[int] = [current]
	var budget := c.total
	while not frontier.is_empty() and budget > 0:
		var nxt: Array[int] = []
		for id in frontier:
			for ch in arch.children(id):
				if budget <= 0:
					break
				budget -= 1
				if not revealed.has(ch):
					revealed[ch] = true
					out.append(ch)
				var f: Dictionary = arch.floors[ch]
				if not (f.type == "password" and int(f.dv) > c.total):
					nxt.append(ch)
		frontier = nxt
	return out


## Devices the runner currently controls (cameras, locks, turrets...), for the tactical layer.
func controlled_devices() -> Array:
	var out := []
	for id in held:
		out.append_array(arch.floors[id].devices)
	return out
