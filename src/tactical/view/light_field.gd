class_name LightField
extends RefCounted
## Bakes light spill into a texture (4 texels per square, one block of rows per floor) so neon,
## lamps and room lights colour the scene even where the compatibility renderer's per-mesh light
## limit drops real lights. Light only reaches squares a ray from the light can see, so walls
## block it; the shader samples it bilinearly with a small blur, so contours don't follow the grid.
## Light entry: {cell: Vector3i (where the light sits), color, energy, range} (LightPlan format).

const TPC := 4


static func bake(m: TacMap, los: Los, lights: Array) -> ImageTexture:
	var tpc := TPC if m.w * m.h <= 3000 else 2
	var W := m.w * tpc
	var H := m.h * tpc * m.floors
	var data := PackedFloat32Array()
	data.resize(W * H * 3)
	for e in lights:
		var cell: Vector3i = e.cell
		var R := float(e.range)
		var col: Color = e.color
		var en := float(e.energy)
		var origin := Vector2(cell.x + 0.5, cell.y + 0.5) + Vector2(e.get("out", Vector2i.ZERO)) * 0.7
		var seen := _visible(m, los, cell, int(ceil(R)))
		var row0 := cell.z * m.h * tpc
		for c: Vector2i in seen:
			for ty in tpc:
				for tx in tpc:
					var p := Vector2(c.x + (tx + 0.5) / tpc, c.y + (ty + 0.5) / tpc)
					var d := p.distance_to(origin)
					if d >= R:
						continue
					var a := en * pow(1.0 - d / R, 2.0)
					var i: int = ((row0 + c.y * tpc + ty) * W + c.x * tpc + tx) * 3
					data[i] += col.r * a
					data[i + 1] += col.g * a
					data[i + 2] += col.b * a
	var img := Image.create_from_data(W, H, false, Image.FORMAT_RGBF, data.to_byte_array())
	return ImageTexture.create_from_image(img)


## Squares visible from `a` within radius r (walls and closed doors stop the ray but are lit).
static func _visible(m: TacMap, los: Los, a: Vector3i, r: int) -> Dictionary:
	var out := {Vector2i(a.x, a.y): true}
	for i in range(-r, r + 1):
		for b in [Vector3i(a.x + i, a.y - r, a.z), Vector3i(a.x + i, a.y + r, a.z), Vector3i(a.x - r, a.y + i, a.z), Vector3i(a.x + r, a.y + i, a.z)]:
			var cells := Los.ray(a, b)
			cells.append(b)
			for v in cells:
				if not m.inb(v.x, v.y):
					break
				out[Vector2i(v.x, v.y)] = true
				if los.blocker(v) == "wall":
					break
	return out
