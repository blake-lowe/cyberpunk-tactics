class_name LightField
extends RefCounted
## Bakes light spill into a texture (4 texels per square, one block of rows per floor) so neon,
## lamps and room lights colour the scene even where the compatibility renderer's per-mesh light
## limit drops real lights. Light only reaches squares a ray from the light can see, so walls
## block it; the shader samples it bilinearly with a small blur, so contours don't follow the grid.
## Alpha carries contact occlusion: darkening on the floor within ~0.7 squares of walls and cover
## (the only ambient occlusion in both renderers: Forward+ SSAO is off, it doubled this into a
## dark halo along every wall).
## Light entry: {cell: Vector3i (where the light sits), color, energy, range} (LightPlan format).

const TPC := 4
const ROOM_FILL := 0.3   # a room light's even level, per unit of its energy (dim: no interior boost)


static func bake(m: TacMap, los: Los, lights: Array) -> ImageTexture:
	var tpc := TPC if m.w * m.h <= 3000 else 2
	var W := m.w * tpc
	var H := m.h * tpc * m.floors
	var data := PackedFloat32Array()
	data.resize(W * H * 4)
	var rooms_done := {}
	for e in lights:
		var cell: Vector3i = e.cell
		var R := float(e.range)
		var col: Color = e.color
		var en := float(e.energy)
		if e.has("room"):   # a ceiling light: an area light filling its room evenly, walls included
			# Owner light review: "strange shadows and darkening vignette on the edges of every room".
			# A room light used to be a point source (range 7.5, quadratic falloff, then the shader's
			# hard light bands): a bright round pool with dark, banded edges in every room. Rooms are
			# lit by ceiling panels, so the whole room gets one level (one fill per room).
			var key := Vector2i(int(e.room), cell.z)
			if rooms_done.has(key):
				continue
			rooms_done[key] = true
			var a2 := en * ROOM_FILL
			var row2 := cell.z * m.h * tpc
			for c: Vector2i in _room_cells(m, cell.z, int(e.room)):
				for ty in tpc:
					for tx in tpc:
						var i2: int = ((row2 + c.y * tpc + ty) * W + c.x * tpc + tx) * 4
						data[i2] += col.r * a2
						data[i2 + 1] += col.g * a2
						data[i2 + 2] += col.b * a2
			continue
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
					var i: int = ((row0 + c.y * tpc + ty) * W + c.x * tpc + tx) * 4
					data[i] += col.r * a
					data[i + 1] += col.g * a
					data[i + 2] += col.b * a
	# contact occlusion: splat from every wall, door and cover square into nearby floor texels
	var reach := 0.7
	for f in m.floors:
		var row0 := f * m.h * tpc
		for y in m.h:
			for x in m.w:
				var t := m.t(f, x, y)
				if not (t == TacMap.T.WALL or t == TacMap.T.DOOR or m.has_cover_at(f, Vector2i(x, y))):
					continue
				var cover := t != TacMap.T.WALL and t != TacMap.T.DOOR
				var r := Rect2(x, y, 1, 1).grow(-0.25 if cover else -0.3)
				for ty in range(maxi(0, (y - 1) * tpc), mini(m.h * tpc, (y + 2) * tpc)):
					for tx in range(maxi(0, (x - 1) * tpc), mini(m.w * tpc, (x + 2) * tpc)):
						var p := Vector2((tx + 0.5) / tpc, (ty + 0.5) / tpc)
						var d := Vector2(maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0), maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)).length()
						if d >= reach:
							continue
						var o := pow(1.0 - d / reach, 2.0) * (0.8 if cover else 1.0)
						var i: int = ((row0 + ty) * W + tx) * 4 + 3
						data[i] = maxf(data[i], o)
	var img := Image.create_from_data(W, H, false, Image.FORMAT_RGBAF, data.to_byte_array())
	return ImageTexture.create_from_image(img)


## A room's squares plus the walls and doors around them (lit, so the bilinear lookup doesn't fade
## the light out toward the walls).
static func _room_cells(m: TacMap, f: int, room: int) -> Dictionary:
	var out := {}
	for y in m.h:
		for x in m.w:
			if m.label(f, x, y) != room:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var v := Vector2i(x + dx, y + dy)
					if not m.inb(v.x, v.y):
						continue
					if (dx == 0 and dy == 0) or m.t(f, v.x, v.y) == TacMap.T.WALL or m.t(f, v.x, v.y) == TacMap.T.DOOR:
						out[v] = true
	return out


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
