class_name NetOverlay
extends Control
## The NET while jacked in, drawn crisp and bright over the stylised environment (owner: the
## world goes to the background, nodes and connections stay in normal, brighter colours).
## Holographic look: each node is a hexagon floating over its device (net-only nodes float near
## their neighbours, higher for deeper security levels) with a thin projection beam to the floor,
## a chromatic double outline, flicker and scanned labels; data flows along links as moving dashes.
## Only the current node and the nodes linked to it are shown. A link the runner can't take
## (an unbroken firewall in the way) ends in a red barrier; nodes beyond a firewall stay hidden.
## Nodes visited earlier remain as faint ghosts.

const COL := {"port": Color("05d9e8"), "hub": Color("7fb8d8"), "file": Color("f9c80e"), "control": Color("39f0a0"),
	"firewall": Color("ff3b4f"), "socket": Color("b537f2"), "root": Color("ffffff")}

var run: NetRun
var pos := {}                 ## node id → Vector3 world position
var ground := {}              ## node id → Vector3 floor point under it
var to_screen: Callable       ## Vector3 → Vector2
var visited := {}             ## node id → true
var hot := -1                 ## node under the mouse
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


## Nodes drawn now: current plus linked nodes (firewalls block what lies beyond them).
func shown() -> Dictionary:
	var out := {}
	if run == null or run.current < 0:
		return out
	out[run.current] = "current"
	for nb in run.arch.neighbors(run.current):
		out[nb] = "open" if run._passable(run.current, nb) else "blocked"
	return out


## Screen hit test: the shown node within `r` px of `p`, or -1.
func pick(p: Vector2, r := 20.0) -> int:
	var best := -1
	var bd := r
	for id in shown():
		if not pos.has(id):
			continue
		var d := (to_screen.call(pos[id]) as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = id
	return best


func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 7:
		var a := PI / 6 + k * PI / 3
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	if run == null or run.current < 0:
		return
	var font := Hud.F_MONO   # the NET's own readouts keep the terminal face
	var flick := 0.85 + 0.15 * sin(_t * 31.0) * sin(_t * 7.3)
	var sh := shown()
	# ghosts of visited nodes and the links between them
	for id in visited:
		if sh.has(id) or not pos.has(id):
			continue
		var p: Vector2 = to_screen.call(pos[id])
		draw_arc(p, 5, 0, TAU, 8, Color(0.6, 0.8, 1.0, 0.18), 1.0)
		for nb in run.arch.neighbors(id):
			if visited.has(nb) and pos.has(nb) and nb > id:
				draw_line(p, to_screen.call(pos[nb]), Color(0.6, 0.8, 1.0, 0.08), 1.0)
	var cur: int = run.current
	var cp: Vector2 = to_screen.call(pos.get(cur, Vector3.ZERO))
	# links from the current node: moving dashes (data flow) or a red barrier
	for id in sh:
		if id == cur or not pos.has(id):
			continue
		var p2: Vector2 = to_screen.call(pos[id])
		var open: bool = sh[id] == "open"
		var col: Color = COL.get(String(run.arch.nodes[id].type), Color.WHITE) if open else Hud.RED
		var seg := p2 - cp
		var n := int(seg.length() / 9.0)
		for k in n:
			var f0 := (k + fmod(_t * 2.5, 1.0)) / n
			var f1 := minf(1.0, f0 + 0.45 / n)
			if not open and f0 > 0.5:
				break
			draw_line(cp + seg * f0, cp + seg * f1, Color(col, 0.85 * flick), 2.0)
		if not open:   # barrier at the midpoint: a crossed hex
			var mid := cp + seg * 0.5
			var hx := _hex(mid, 9)
			draw_colored_polygon(hx, Color(0.3, 0.02, 0.05, 0.7))
			draw_polyline(hx, Hud.RED, 2.0)
			draw_line(mid + Vector2(-5, -5), mid + Vector2(5, 5), Hud.RED, 2.0)
			draw_line(mid + Vector2(-5, 5), mid + Vector2(5, -5), Hud.RED, 2.0)
	# nodes (labels step down out of each other's way)
	var placed: Array[Rect2] = []
	var labels: Array = []   # drawn last, on a dark plate, so links and nodes never cross the text
	for id in sh:
		if not pos.has(id):
			continue
		var nd: Dictionary = run.arch.nodes[id]
		var t := String(nd.type)
		var p3: Vector2 = to_screen.call(pos[id])
		var g: Vector2 = to_screen.call(ground.get(id, pos[id]))
		var is_cur: bool = id == cur
		var col2: Color = COL.get(t, Color.WHITE)
		if t == "firewall" and run.broken.has(id):
			col2 = Color("8a96a0")
		var ice := run.arch.ice_at(id)
		var r := 15.0 if not is_cur else 18.0 + 2.0 * sin(_t * 5.0)
		# projection beam down to the floor
		draw_line(p3 + Vector2(0, r), g, Color(col2, 0.18 * flick), 1.0)
		draw_arc(g, 4, 0, TAU, 8, Color(col2, 0.25), 1.0)
		var hx2 := _hex(p3, r)
		draw_colored_polygon(hx2, Color(col2.r * 0.15, col2.g * 0.15, col2.b * 0.15, 0.75))
		draw_polyline(_hex(p3 + Vector2(-1.5, 0), r), Color(Hud.MAGENTA, 0.35 * flick), 1.0)   # chromatic split
		draw_polyline(_hex(p3 + Vector2(1.5, 0), r), Color(Hud.CYAN, 0.35 * flick), 1.0)
		draw_polyline(hx2, Color(col2, flick), 2.0 if not is_cur else 3.0)
		if is_cur:
			draw_arc(p3, r + 6, _t * 2.0, _t * 2.0 + PI * 1.2, 16, Color(Hud.GOLD, 0.9), 2.0)
		if id == hot:
			draw_polyline(_hex(p3, r + 4), Color.WHITE, 1.0)
		_glyph(t, p3, col2)
		if not ice.is_empty():   # Black ICE: a red, glitching triangle on the node
			var j := Vector2(sin(_t * 47.0) * 1.5, 0)
			var tri := PackedVector2Array([p3 + Vector2(r * 0.9, -r * 1.1) + j, p3 + Vector2(r * 1.6, -r * 0.1) + j, p3 + Vector2(r * 0.2, -r * 0.1) + j])
			draw_colored_polygon(tri, Color(1, 0.1, 0.2, 0.85))
			var ice_at := _free_spot(Rect2(p3 + Vector2(r * 1.7, -r * 0.4 - 12), Vector2(90, 16)), placed)
			draw_string(font, ice_at.position + Vector2(0, 12), "ICE: %s" % String(ice[0].kind).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Hud.RED)
		var label := _label(nd)
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 8.0
		var at := _free_spot(Rect2(p3 + Vector2(-lw * 0.5, r + 4), Vector2(lw, 16)), placed)
		labels.append([at, label, Color(col2, 0.95 * flick)])
	for lb in labels:
		var rr: Rect2 = lb[0]
		draw_rect(rr.grow_individual(2, 1, 2, 3), Color(0.0, 0.0, 0.0, 0.8))
		draw_string(font, rr.position + Vector2(0, 12), String(lb[1]), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 18, lb[2])


## First spot at or below `want` that doesn't overlap a label already placed; records it.
func _free_spot(want: Rect2, placed: Array[Rect2]) -> Rect2:
	var r := want
	for k in 8:
		var hit := false
		for q in placed:
			if q.intersects(r):
				hit = true
				r.position.y = q.end.y + 1
				break
		if not hit:
			break
	placed.append(r)
	return r


func _glyph(t: String, c: Vector2, col: Color) -> void:
	match t:
		"port":
			draw_rect(Rect2(c - Vector2(5, 4), Vector2(10, 8)), col, false, 2.0)
			draw_line(c + Vector2(-2, -4), c + Vector2(-2, -8), col, 2.0)
			draw_line(c + Vector2(2, -4), c + Vector2(2, -8), col, 2.0)
		"hub":
			draw_circle(c, 3.0, col)
			for k in 3:
				var a := k * TAU / 3 + _t
				draw_line(c, c + Vector2(cos(a), sin(a)) * 7, col, 1.0)
		"file":
			draw_polyline(PackedVector2Array([c + Vector2(-4, -6), c + Vector2(2, -6), c + Vector2(5, -3), c + Vector2(5, 6), c + Vector2(-4, 6), c + Vector2(-4, -6)]), col, 2.0)
		"control":
			draw_arc(c, 5, 0.6, TAU - 0.6, 12, col, 2.0)
			draw_line(c, c + Vector2(0, -7), col, 2.0)
		"firewall":
			for k in 3:
				draw_line(c + Vector2(-6, -4 + k * 4), c + Vector2(6, -4 + k * 4), col, 2.0)
		"socket":
			draw_arc(c + Vector2(-2, 0), 4, 0, TAU, 10, col, 2.0)
			draw_arc(c + Vector2(3, 0), 4, 0, TAU, 10, col, 2.0)
		_:
			draw_circle(c, 3.0, col)


func _label(nd: Dictionary) -> String:
	match String(nd.type):
		"firewall": return "FIREWALL DV%d" % int(nd.dv)
		"file": return "FILE DV%d" % int(nd.dv)
		"control": return "CONTROL: " + Hud.control_name(String(nd.group)).to_upper()
		"socket": return "SOCKET"
		"port": return "ACCESS PORT"
		"hub": return "L%d HUB" % int(nd.zone)
	return String(nd.type).to_upper()
