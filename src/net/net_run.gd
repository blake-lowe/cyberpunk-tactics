class_name NetRun
extends RefCounted
## A Netrunner's session in a NET graph. Ability checks are Interface Rank + 1d10 vs DV (p198).
## Moving is free (p198) except through blockers: an unbroken firewall can be entered but only
## left outward (towards shallower zones), and a node with active Black ICE can be entered but
## not passed until the ICE is dealt with. ICE combat and Programs arrive with M3.

var arch: NetArchitecture
var runner: Combatant
var current := -1
var revealed := {}   ## node id → true
var broken := {}     ## firewalls Backdoored
var held := {}       ## control nodes taken
var identified := {} ## files Eye-Dee'd


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


## Jack in at an access point (meatspace range is checked by the tactical layer).
func jack_in(access_point: int) -> void:
	current = int(arch.access_points[access_point].entry_node)
	revealed[current] = true


func jack_out() -> void:
	current = -1


func cur_node() -> Dictionary:
	return arch.nodes[current]


## Can this node be left towards `to`?
func _passable(from: int, to: int) -> bool:
	var n: Dictionary = arch.nodes[from]
	if n.type == "firewall" and not broken.has(from) and int(arch.nodes[to].zone) >= int(n.zone):
		return false
	# Active Black ICE pins you: fight it, Slide away (p200) or jack out.
	return arch.ice_at(from).is_empty()


## Nodes the runner can move to this turn.
func movable() -> Dictionary:
	if current < 0:
		return {}
	var seen := {current: true}
	var q := [current]
	while not q.is_empty():
		var n: int = q.pop_back()
		for nb in arch.neighbors(n):
			if not seen.has(nb) and _passable(n, nb):
				seen[nb] = true
				q.append(nb)
	return seen


func can_move_to(id: int) -> bool:
	return movable().has(id)


func move_to(id: int) -> bool:
	if not can_move_to(id):
		return false
	current = id
	revealed[id] = true
	return true


func chance(dv: int) -> float:
	return Check.chance_vs_dv(rank(), dv)


func backdoor(dice: Dice) -> Check:
	var n := cur_node()
	assert(n.type == "firewall")
	var c := Check.vs_dv(dice, rank(), int(n.dv))
	if c.success:
		broken[n.id] = true
	return c


func control(dice: Dice) -> Check:
	var n := cur_node()
	assert(n.type == "control")
	var c := Check.vs_dv(dice, rank(), int(n.dv))
	if c.success:
		held[n.id] = true
	return c


func eye_dee(dice: Dice) -> Check:
	var n := cur_node()
	assert(n.type == "file")
	var c := Check.vs_dv(dice, rank(), int(n.dv))
	if c.success:
		identified[n.id] = true
	return c


## Pathfinder (p199, adapted): reveal up to (check total) nodes outward from here, breadth-first,
## stopping behind any firewall whose DV beats the check (the firewall itself is shown).
func pathfinder(dice: Dice) -> Array[int]:
	var c := Check.vs_dv(dice, rank(), 0)
	var out: Array[int] = []
	var seen := {current: true}
	var q := [current]
	var budget := c.total
	while not q.is_empty() and budget > 0:
		var n: int = q.pop_front()
		for nb in arch.neighbors(n):
			if seen.has(nb) or budget <= 0:
				continue
			seen[nb] = true
			budget -= 1
			if not revealed.has(nb):
				revealed[nb] = true
				out.append(nb)
			var node: Dictionary = arch.nodes[nb]
			if not (node.type == "firewall" and int(node.dv) > c.total):
				q.append(nb)
	return out


func controlled_devices() -> Array:
	var out := []
	for id in held:
		out.append_array(arch.nodes[id].devices)
	return out
