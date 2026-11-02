class_name NetRun
extends RefCounted
## A Netrunner's session in a NET graph. Ability checks are Interface Rank + 1d10 vs DV (p198).
## Moving is free (p198) except through blockers: an unbroken firewall can be entered but only
## left outward (towards shallower zones), and a node with active Black ICE can be entered but
## not passed until the ICE is dealt with. ICE combat and Programs arrive with M3.

var arch: NetArchitecture
var runner: Combatant
## Other NETs reachable through sockets (structure id → NetArchitecture), and per-NET progress.
var nets: Dictionary = {}
var _progress: Dictionary = {}
var current := -1
var revealed := {}   ## node id → true
var broken := {}     ## firewalls Backdoored
var held := {}       ## control nodes taken
var identified := {} ## files Eye-Dee'd
var met := {}        ## Black ICE ids encountered this session (an unsafe jack-out suffers them all, p198)
var armor_rez := 0   ## Armor program running (REZ 7, -4 brain damage, p203); 0 = not running
var armor_used := false   ## each copy once per Netrun (p203)
var lost := {}       ## Programs destroyed this session (Asp)
var kraken_until := -1    ## round: no going deeper or safe Jack Out until then (p207)
var wisp := 0        ## NET Actions lost next turn (p207)
var skunks := {}     ## Skunk ice ids hitting this runner: -2 Slide each while Rezzed (p207)
var no_deeper := false
var scouted := {}    ## nodes seen only through Pathfinder: contents known, DVs not (p199-200)   ## set by the tactical layer while a Kraken holds the runner


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


## Interface for checks: the Rank, less wound penalties like any other Action (p220).
func rank() -> int:
	return interface_rank(runner) - runner.action_penalty()


## Jack in at an access point (meatspace range is checked by the tactical layer).
func jack_in(access_point: int) -> void:
	current = int(arch.access_points[access_point].entry_node)
	revealed[current] = true
	for nb in arch.neighbors(current):
		revealed[nb] = true


func jack_out() -> void:
	current = -1


func cur_node() -> Dictionary:
	return arch.nodes[current]


## Can this node be left towards `to`?
func _passable(from: int, to: int) -> bool:
	var n: Dictionary = arch.nodes[from]
	if n.type == "firewall" and not broken.has(from) and int(arch.nodes[to].zone) >= int(n.zone):
		return false
	if no_deeper and int(arch.nodes[to].zone) > int(n.zone):   # Kraken (p207)
		return false
	# HOUSE-RULE (stands in for the book's chase, p205): active Black ICE pins you on its node; fight
	# it, Slide away (p200) or jack out.
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
	scouted.erase(id)
	for nb in arch.neighbors(id):   # you can see the doors out of where you stand
		revealed[nb] = true
		scouted.erase(nb)
	return true


## Revealed nodes reachable from here, with hop counts (nearest first in the route list).
func route() -> Dictionary:
	var dist := {current: 0}
	var q := [current]
	while not q.is_empty():
		var n: int = q.pop_front()
		for nb in arch.neighbors(n):
			if not dist.has(nb) and revealed.has(nb) and _passable(n, nb):
				dist[nb] = int(dist[n]) + 1
				q.append(nb)
	dist.erase(current)
	return dist


## ICE on the runner's node not met before (the caller rolls the speed contest, p205).
func meet() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in arch.ice_at(current):
		if not met.has(i.id):
			met[i.id] = true
			out.append(i)
	return out


func has_program(p: String) -> bool:
	return p in runner.programs and not lost.has(p)


## Slide (p200): flee to a neighbouring node, not past an unbroken firewall's inward side.
func slide_targets() -> Array:
	return arch.neighbors(current).filter(func(nb): return not (cur_node().type == "firewall" and not broken.has(current) and int(arch.nodes[nb].zone) >= int(cur_node().zone)))


## What each NET Action needs from the node the runner is on ("" = fine).
func action_block(kind: String) -> String:
	if current < 0:
		return "not jacked in"
	var t := String(cur_node().type)
	match kind:
		"backdoor":
			return "" if t == "firewall" and not broken.has(current) else ("already open" if t == "firewall" else "not a firewall")
		"control":
			return "" if t == "control" and not held.has(current) else ("already held" if t == "control" else "not a control node")
		"eye_dee":
			return "" if t == "file" and not identified.has(current) else ("already identified" if t == "file" else "not a file")
	return ""


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
				scouted[nb] = true
				out.append(nb)
			var node: Dictionary = arch.nodes[nb]
			if not (node.type == "firewall" and int(node.dv) > c.total):
				q.append(nb)
	return out


## Step through a socket into the linked NET (M2d review). Progress in each NET is kept.
func cross() -> bool:
	if current < 0:
		return false
	var n := cur_node()
	if n.type != "socket" or not nets.has(n.target_structure):
		return false
	_progress[arch.structure] = [revealed, broken, held, identified]
	arch = nets[n.target_structure]
	var saved: Array = _progress.get(arch.structure, [{}, {}, {}, {}])
	revealed = saved[0]
	broken = saved[1]
	held = saved[2]
	identified = saved[3]
	current = int(n.target_node)
	revealed[current] = true
	return true


func controlled_devices() -> Array:
	var out := []
	for id in held:
		out.append_array(arch.nodes[id].devices)
	return out
