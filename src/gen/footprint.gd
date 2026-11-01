class_name Footprint
extends RefCounted
## A building's ground shape: its bounding `shell` rect, optionally clipped by a cell mask (cut
## corners, lots sliced by a diagonal avenue). The outer ring of the shape is exterior wall; the
## rest is interior that room layouts fill.

var shell: Rect2i
var cells: Dictionary = {}     ## Vector2i → true; empty = the whole rect
var _interior: Dictionary = {}
var count := 0


static func make(p_shell: Rect2i, mask: Dictionary = {}) -> Footprint:
	var fp := Footprint.new()
	fp.shell = p_shell
	fp.cells = mask
	for y in range(p_shell.position.y, p_shell.end.y):
		for x in range(p_shell.position.x, p_shell.end.x):
			var v := Vector2i(x, y)
			if not fp.has(v):
				continue
			fp.count += 1
			var inside := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not fp.has(v + Vector2i(dx, dy)):
						inside = false
			if inside:
				fp._interior[v] = true
	return fp


func has(v: Vector2i) -> bool:
	return shell.has_point(v) and (cells.is_empty() or cells.has(v))


func interior(v: Vector2i) -> bool:
	return _interior.has(v)


func exterior(v: Vector2i) -> bool:
	return has(v) and not _interior.has(v)
