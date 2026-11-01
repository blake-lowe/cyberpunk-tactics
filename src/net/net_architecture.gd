class_name NetArchitecture
extends RefCounted
## A NET Architecture (p209): floors in a tree. Each floor holds one thing — a Password, File,
## Control Node, or Black ICE. Runners descend floor by floor; Passwords block until Backdoored.
##
## floor: {id, parent, branch, depth, type: "password"|"file"|"control"|"ice", dv, ice: [],
##         devices: [device ids] (control), group (control), device (file), value (file), zone}

var difficulty: int = 1
var style: String = "stack"
var floors: Array[Dictionary] = []
var access_points: Array[Dictionary] = []  ## {device, entry_floor}


func add_floor(parent: int, branch: int, data: Dictionary) -> int:
	var f := data.duplicate()
	f["id"] = floors.size()
	f["parent"] = parent
	f["branch"] = branch
	f["depth"] = 0 if parent < 0 else int(floors[parent].depth) + 1
	floors.append(f)
	return f.id


func children(id: int) -> Array[int]:
	var out: Array[int] = []
	for f in floors:
		if f.parent == id:
			out.append(f.id)
	return out


## Floors from the top down to `id`, inclusive.
func path_to(id: int) -> Array[int]:
	var out: Array[int] = []
	var cur := id
	while cur >= 0:
		out.push_front(cur)
		cur = floors[cur].parent
	return out


func floors_of_type(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in floors:
		if f.type == type:
			out.append(f)
	return out


func control_floor_for_device(device_id: int) -> int:
	for f in floors:
		if f.type == "control" and device_id in f.devices:
			return f.id
	return -1


func to_dict() -> Dictionary:
	return {"difficulty": difficulty, "style": style, "floors": floors, "access_points": access_points}
