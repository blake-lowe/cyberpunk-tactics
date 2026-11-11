class_name NetRun
extends RefCounted
## A Netrunner's session in a NET graph. Ability checks are Interface Rank + 1d10 vs DV (p198).
## Moving is free (p198) except through blockers: an unbroken firewall can be entered but only
## left outward (towards shallower zones), and a node with active Black ICE can be entered but
## not passed until the ICE is dealt with. Programs come off the runner's deck (Deck, progs).

var arch: NetArchitecture
var runner: Combatant
## Other NETs reachable through sockets (structure id → NetArchitecture), and per-NET progress.
var nets: Dictionary = {}
var _progress: Dictionary = {}
var current := -1
var revealed := {}   ## node id → true
var broken := {}     ## firewalls Backdoored
var held := {}       ## control nodes taken
var activated := {}  ## control node id → Round its devices were last operated: once per Turn per Node (p199)
var identified := {} ## files Eye-Dee'd
var met := {}        ## Vector2i(structure, ice id) → true: Black ICE met (an unsafe jack-out suffers them all, p198)
## The deck's Programs this Netrun, one entry per copy loaded (Deck; CPR core p.201-205):
## {id, on (Rezzed), rez, round (the Round it was last Activated: once per Round), used (a
## once-per-Netrun copy spent), gone (Destroyed), target (your Black ICE: the enemy ICE id it hunts)}.
## A Jack Out takes them all out with you (p.198): the next Netrun starts them fresh.
var progs: Array[Dictionary] = []
var kraken_until := -1    ## round: no going deeper or safe Jack Out until then (p207)
var wisp := 0        ## NET Actions lost next turn (p207)
var skunks := {}     ## Skunk ice ids hitting this runner: -2 Slide each while Rezzed (p207)
var no_deeper := false
var inside := {}     ## firewalls the runner reached from their inner side: they can go back in (playtest trap)
var scouted := {}    ## nodes seen only through Pathfinder: contents known, DVs not (p199-200)   ## set by the tactical layer while a Kraken holds the runner


static func interface_rank(c: Combatant) -> int:
	return c.role_rank if c.role == "netrunner" else 0


## Why `c` can't jack in at all ("" if they can): netrunning takes the Interface Role Ability (p.197),
## and "to even use a Cyberdeck, you need to plug Interface Plugs into it" (p.196, p.359): a Netrunner
## without working plugs can't, and plugs don't make anyone else a Netrunner. Player text.
static func jack_block(c: Combatant) -> String:
	if interface_rank(c) <= 0:
		return "Not a Netrunner"
	if not c.has_cyberware("interface_plugs"):
		return "Needs Interface Plugs"
	if not c.cyber_working("interface_plugs"):
		return "Interface Plugs offline"
	if c.deck == "":   # "a Cyberdeck" is what Interface Plugs plug into (p.196)
		return "Needs a cyberdeck"
	if Deck.offline(c):   # knocked out by a Microwaver or EMP (p.348)
		return "Cyberdeck offline"
	return ""


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
	for id in runner.programs:
		progs.append({"id": id, "on": false, "rez": 0, "round": -1, "used": false, "gone": false, "target": -1})


# --- Programs (CPR core p.201-205) -------------------------------------------------------------

func prog_def(i: int) -> Dictionary:
	return Deck.program(String(progs[i].id))


## Rezzed and not Derezzed: its effect plays (a Derezzed Program is still running but useless, p.201).
func live(i: int) -> bool:
	var p: Dictionary = progs[i]
	return bool(p.on) and int(p.rez) > 0 and not bool(p.gone)


## Copies whose effect plays now, of class `cls` ("" any).
func rezzed(cls := "") -> Array[int]:
	var out: Array[int] = []
	for i in progs.size():
		if live(i) and (cls == "" or Deck.program_class(String(progs[i].id)) == cls):
			out.append(i)
	return out


## Programs Rezzed whether Derezzed or not (still running, p.201): what Anti-Program Black ICE hunts
## among are the live ones.
func running() -> Array[int]:
	var out: Array[int] = []
	for i in progs.size():
		if bool(progs[i].on) and not bool(progs[i].gone):
			out.append(i)
	return out


## The Boosters' bonus to `what` (pathfinder, backdoor, cloak, speed) from every live copy: copies
## stack (p.201).
func boost(what: String) -> int:
	var n := 0
	for i in rezzed("booster"):
		n += int((prog_def(i).get("fx", {}).get("boost", {}) as Dictionary).get(what, 0))
	return n


## Brain damage taken lowered by a live Defender (Armor -4, p.203; one copy running at a time).
func brain_reduce() -> int:
	var n := 0
	for i in rezzed("defender"):
		n = maxi(n, int(prog_def(i).get("fx", {}).get("brain_reduce", 0)))
	return n


func has_program(p: String) -> bool:
	return progs.any(func(x): return String(x.id) == p and not bool(x.gone))


## Why copy `i` can't be Activated in Round `round_num` ("" if it can). Player text.
func activate_block(i: int, round_num: int) -> String:
	if i < 0 or i >= progs.size():
		return "no such program"
	var p: Dictionary = progs[i]
	var fx: Dictionary = prog_def(i).get("fx", {})
	if bool(p.gone):
		return "destroyed"
	if bool(p.on):
		return "already running"
	if int(p.round) == round_num:   # p.201: once per Round
		return "once a round"
	if bool(fx.get("once_per_run", false)) and bool(p.used):   # p.203
		return "used this run"
	if bool(fx.get("one_running", false)) and progs.any(func(x): return x != p and String(x.id) == String(p.id) and bool(x.on) and not bool(x.gone)):
		return "one copy at a time"
	match Deck.program_class(String(p.id)):
		"attacker", "black_ice":
			if String(prog_def(i).get("target", "")) != "anti_program":
				return "no enemy netrunner"
			if arch.ice_at(current).is_empty():
				return "no ICE here"
	return ""


## Rez copy `i` (a Booster or Defender, or your own Black ICE set on enemy ICE `target`): full REZ
## (p.201: a Derezzed Program comes back by Deactivating and Activating it).
func rez(i: int, round_num: int, target := -1) -> void:
	var p: Dictionary = progs[i]
	p.on = true
	p.rez = int(Deck.stats(String(p.id)).rez)
	p.round = round_num
	p.target = target
	if bool(prog_def(i).get("fx", {}).get("once_per_run", false)):
		p.used = true


## Deactivate copy `i` (p.201). False if it isn't running.
func derez_off(i: int) -> bool:
	if i < 0 or i >= progs.size() or not bool(progs[i].on) or bool(progs[i].gone):
		return false
	progs[i].on = false
	progs[i].target = -1
	return true


## Copy `i` is Destroyed (p.201): erased from the deck for good (Deck.destroy; a Backup Drive may save
## it). Returns whether it was saved.
func destroy(i: int) -> bool:
	var p: Dictionary = progs[i]
	if bool(p.gone):
		return false
	p.gone = true
	p.on = false
	return Deck.destroy(runner, String(p.id))


## Programs a Backup Drive put back (Deck.restore_backup) come back in the state they were saved in
## (p.208-209: a used once-per-Netrun copy stays used).
func restore(ids: Array[String]) -> void:
	for id in ids:
		for p in progs:
			if bool(p.gone) and String(p.id) == id:
				p.gone = false
				break


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
	if n.type == "firewall" and not broken.has(from) and not inside.has(from) and int(arch.nodes[to].zone) >= int(n.zone):
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
	# Firewalls passed outward from the inside stay open behind you (you came from there).
	var parent := {current: -1}
	var q := [current]
	while not q.is_empty() and not parent.has(id):
		var n: int = q.pop_front()
		for nb in arch.neighbors(n):
			if not parent.has(nb) and _passable(n, nb):
				parent[nb] = n
				q.append(nb)
	var step := id
	while parent.has(step) and int(parent[step]) >= 0:
		var prev: int = parent[step]
		if arch.nodes[step].type == "firewall" and int(arch.nodes[prev].zone) >= int(arch.nodes[step].zone):
			inside[step] = true
		step = prev
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
		if not met.has(met_key(i)):
			met[met_key(i)] = true
			out.append(i)
	return out


func met_key(ice: Dictionary) -> Vector2i:
	return Vector2i(arch.structure, int(ice.id))


## Slide (p200): flee to a neighbouring node, not past an unbroken firewall's inward side.
func slide_targets() -> Array:
	return arch.neighbors(current).filter(func(nb): return not (cur_node().type == "firewall" and not broken.has(current) and not inside.has(current) and int(arch.nodes[nb].zone) >= int(cur_node().zone)) \
		and not (no_deeper and int(arch.nodes[nb].zone) > int(cur_node().zone)))


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


func chance(dv: int, what := "") -> float:
	return Check.chance_vs_dv(rank() + (boost(what) if what != "" else 0), dv)


func backdoor(dice: Dice) -> Check:
	var n := cur_node()
	assert(n.type == "firewall")
	var c := Check.vs_dv(dice, rank() + boost("backdoor"), int(n.dv))   # Worm +2 (p.203)
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
	var c := Check.vs_dv(dice, rank() + boost("pathfinder"), 0)   # See Ya +2 (p.203)
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
			if not revealed.has(nb):   # only new nodes use up the check (playtest)
				budget -= 1
				revealed[nb] = true
				scouted[nb] = true
				out.append(nb)
			var node: Dictionary = arch.nodes[nb]
			var open: bool = broken.has(nb) or inside.has(nb)
			if open or not (node.type == "firewall" and int(node.dv) > c.total):   # opened firewalls don't stop it
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
