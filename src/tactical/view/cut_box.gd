class_name CutBox
extends StyleBox
## Square-cornered panel with chamfered corners (no rounding anywhere, per the M4a review), a hard
## 1 px edge, an optional bright accent tick along the top edge, and faint scanlines.
## Corners to cut: bit 0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left.

var fill := Color(0.03, 0.04, 0.055, 0.92)
var edge := Color(0.02, 0.85, 0.91, 0.5)
var accent := Color(0, 0, 0, 0)
var cut := 10.0
var corners := 0b0101
var scan := true
var width := 2.0   # 2 px: matches the world's pixel size


static func make(p_fill: Color, p_edge: Color, p_cut := 10.0, p_corners := 0b0101, p_accent := Color(0, 0, 0, 0), margin := 10.0) -> CutBox:
	var s := CutBox.new()
	s.fill = p_fill
	s.edge = p_edge
	s.cut = p_cut
	s.corners = p_corners
	s.accent = p_accent
	s.content_margin_left = margin + 2
	s.content_margin_right = margin + 2
	s.content_margin_top = margin * 0.7
	s.content_margin_bottom = margin * 0.7
	return s


func points(r: Rect2) -> PackedVector2Array:
	var c := minf(cut, minf(r.size.x, r.size.y) * 0.4)
	var p := PackedVector2Array()
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)
	if corners & 1: p.append_array([tl + Vector2(0, c), tl + Vector2(c, 0)])
	else: p.append(tl)
	if corners & 2: p.append_array([tr - Vector2(c, 0), tr + Vector2(0, c)])
	else: p.append(tr)
	if corners & 4: p.append_array([br - Vector2(0, c), br - Vector2(c, 0)])
	else: p.append(br)
	if corners & 8: p.append_array([bl + Vector2(c, 0), bl - Vector2(0, c)])
	else: p.append(bl)
	return p


func _draw(ci: RID, r: Rect2) -> void:
	var p := points(r)
	if fill.a > 0:
		RenderingServer.canvas_item_add_polygon(ci, p, PackedColorArray([fill]))
	if scan and r.size.y > 12:
		var y := r.position.y + 2.0
		while y < r.end.y - 2:
			RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x + 2, y, r.size.x - 4, 2), Color(1, 1, 1, 0.022))
			y += 4.0
	if edge.a > 0:
		var loop := p.duplicate()
		loop.append(p[0])
		RenderingServer.canvas_item_add_polyline(ci, loop, PackedColorArray([edge]), width)
	if accent.a > 0:
		var x0 := r.position.x + (cut if corners & 1 else 0.0) + 4
		RenderingServer.canvas_item_add_rect(ci, Rect2(x0, r.position.y - 1, minf(36, r.size.x * 0.3), 3), accent)
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.end.x - 10, r.end.y - 3, 6, 2), accent)
