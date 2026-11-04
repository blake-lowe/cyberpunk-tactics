extends Objective
## Data theft: download the target building's most valuable File by Eye-Dee'ing it in the NET
## (NetRun sets o.done), or put every guard down. State: {structure, node}.


func setup(target_sid: int, _origin: Vector2i, _sec: int) -> void:
	if not e.m.architectures.has(target_sid):
		return
	var a: NetArchitecture = e.m.architectures[target_sid]
	var best := -1
	for nd in a.nodes_of_type("file"):
		if best < 0 or int(nd.value) > int(a.nodes[best].value):
			best = nd.id
	o.merge({"structure": target_sid, "node": best})


func check_end() -> String:
	var r := _cleared()
	if r != "":
		return r
	if done():
		e.say("The data is yours.")
		return "won"
	return ""


func hud_text() -> String:
	if int(o.get("node", -1)) >= 0 and e.m.architectures.has(int(o.structure)):
		var fn: Dictionary = (e.m.architectures[int(o.structure)] as NetArchitecture).nodes[int(o.node)]
		return "OBJECTIVE · DOWNLOAD THE ★ FILE (NET LEVEL %d)\nOR ELIMINATE ALL HOSTILES" % int(fn.zone)
	return "OBJECTIVE · ELIMINATE ALL HOSTILES"


## The nearest jack point into the target NET while nobody on the crew is jacked in.
func marks(_fog: bool) -> Array:
	if int(o.get("node", -1)) < 0 or not e.m.architectures.has(int(o.structure)):
		return []
	for id in e.runs:
		if int(e.units[id].team) == Encounter.CREW:
			return []
	var a: NetArchitecture = e.m.architectures[int(o.structure)]
	var from: Vector3i = e.cur.pos if not e.cur.is_empty() else e.units[0].pos
	var best := Vector3i(-1, -1, -1)
	var bd := INF
	for ap in a.access_points:
		var d: Dictionary = e.m.devices[ap.device]
		var dp := Vector3i(d.pos.x, d.pos.y, d.floor)
		var dist := Vector3(dp - from).length()
		if dist < bd:
			bd = dist
			best = dp
	if best.x < 0:
		return []
	return [{"cell": best, "h": 0.7, "label": "JACK POINT", "tone": "cyan"}]
