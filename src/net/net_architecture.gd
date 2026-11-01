class_name NetArchitecture
extends RefCounted
## A site's NET as a graph (design departs from the book's floor stack — see docs/roadmap.md).
## Subnets cluster the nodes of one security zone (per building floor at high complexity), each
## around a hub. Firewalls (Passwords) join a subnet to the shallower zone. Node types and DVs,
## Interface abilities and Black ICE stats are the book's.
##
## node:   {id, type: "hub"|"firewall"|"file"|"control"|"port", zone, subnet, dv, net_only,
##          devices, group (control), device, value (file)}
## ice:    {id, kind, node, patrol}
## access: {device, entry_node}

var structure := -1
var scale := "normal"   ## "intro" = tutorial-size NET
var difficulty := 1
var complexity := 0.0   ## 0 = simple subnets … 1 = full graph (loops, multiple routes, patrols)
var budget := 0         ## Black ICE points available
var spent := 0
var nodes: Array[Dictionary] = []
var edges: Array[Vector2i] = []
var subnets: Array[Dictionary] = []    ## {id, zone, bfloor, hub}
var ice: Array[Dictionary] = []
var access_points: Array[Dictionary] = []
var _adj: Dictionary = {}


func add_node(data: Dictionary) -> int:
	var n := data.duplicate()
	n["id"] = nodes.size()
	n["net_only"] = n.get("net_only", false)
	nodes.append(n)
	_adj[n.id] = []
	return n.id


func link(a: int, b: int) -> void:
	if a == b or b in _adj[a]:
		return
	edges.append(Vector2i(mini(a, b), maxi(a, b)))
	_adj[a].append(b)
	_adj[b].append(a)


func neighbors(id: int) -> Array:
	return _adj.get(id, [])


func nodes_of_type(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in nodes:
		if n.type == type:
			out.append(n)
	return out


func ice_at(node_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in ice:
		if i.node == node_id and not i.get("derezzed", false):
			out.append(i)
	return out


func control_node_for_device(device_id: int) -> int:
	for n in nodes:
		if n.type == "control" and device_id in n.get("devices", []):
			return n.id
	return -1


## Nodes reachable from `start` without passing through any node in `blocked` (blocked nodes
## themselves are reached but not expanded).
func reach(start: int, blocked: Dictionary) -> Dictionary:
	var seen := {start: true}
	var q := [start]
	while not q.is_empty():
		var n: int = q.pop_back()
		if n != start and blocked.has(n):
			continue
		for nb in neighbors(n):
			if not seen.has(nb):
				seen[nb] = true
				q.append(nb)
	return seen


func to_dict() -> Dictionary:
	var e := []
	for v in edges:
		e.append([v.x, v.y])
	return {"structure": structure, "scale": scale, "difficulty": difficulty, "complexity": complexity, "budget": budget, "spent": spent,
		"nodes": nodes, "edges": e, "subnets": subnets, "ice": ice, "access_points": access_points}
