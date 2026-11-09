class_name Daylight
extends RefCounted
## The light a gig is played in, by the hour the crew gets there (owner verdict 2026-11-09: "day
## events on night-lit city maps: light by the hour"). Campaign._start_gig keeps the hour on the
## active gig (`hour`, the campaign clock after the drive, the same clock the scene event is rolled
## on), Campaign.scene_opts hands it to the map's params, and the greybox lights the map by its band
## (greybox scene_look): the night city's approved look at night and after midnight, a day look
## (sun, sky, bright ambient, lamps and neon dimmed, windows less glowy) from dawn to dusk.
## A map without an hour (dev renders without --hour) is night, as every map was before.
##
## Bands (HOUSE-RULE): they follow the scene events' Day / Night / After Midnight (SceneEvent
## time_of, scene_events.json times), split once more at the edges of the day: the first hour of
## the book's Day is dawn, the first hour of its Night is dusk. So a band never disagrees with the
## scene event's table (agrees): dawn and day play Day rows, dusk and night Night rows.
## A tower gig's sky (Campaign.tower_sky) wins, as it does for the scene event.
##
## Pure data and lookups (headless-testable). The look for each band is the greybox's (LOOKS day,
## dawn, dusk; BAND_LOOKS), and each carries a `day_factor` the greybox sets as the global shader
## parameter of that name (0 at night) so emissive materials (and the sign library) can dim by day.

const NIGHT := "night"
const BANDS := ["after_midnight", "dawn", "day", "dusk", "night"]
## [first hour, last hour] of each band on the campaign clock (hours 0-23).
const HOURS := {"after_midnight": [0, 5], "dawn": [6, 6], "day": [7, 17], "dusk": [18, 18], "night": [19, 23]}
## Each band's scene-event time (SceneEvent.TIMES).
const TIME := {"after_midnight": "after_midnight", "dawn": "day", "day": "day", "dusk": "night", "night": "night"}
## How much daylight there is in each band (0: the night look).
const FACTOR := {"after_midnight": 0.0, "dawn": 0.6, "day": 1.0, "dusk": 0.6, "night": 0.0}


## The band at `hour` (0-23; anything else wraps) under a tower gig's `sky` ("day" / "night" / "").
static func band(hour: int, sky := "") -> String:
	var h := posmod(hour, 24)
	var by_clock := NIGHT
	for b in BANDS:
		if h >= int(HOURS[b][0]) and h <= int(HOURS[b][1]):
			by_clock = b
	if sky == "day":
		return "day"
	if sky == "night":
		return "after_midnight" if by_clock == "after_midnight" else NIGHT
	return by_clock


## A map's band: its params' `hour` (Campaign.scene_opts; greybox --hour), else night, and its `sky`.
static func of_params(p: Dictionary) -> String:
	var h := int(p.get("hour", -1))
	var sky := String(p.get("sky", ""))
	if h < 0:
		return "day" if sky == "day" else NIGHT
	return band(h, sky)


static func of_map(m: TacMap) -> String:
	return NIGHT if m == null else of_params(m.params)


## Is `b` lit by the sun (dawn, day, dusk)? Night and after midnight keep the night look.
static func is_lit(b: String) -> bool:
	return float(FACTOR.get(b, 0.0)) > 0.0


static func factor(b: String) -> float:
	return float(FACTOR.get(b, 0.0))


## The scene event's time (SceneEvent.time_of) a band plays.
static func time_of(b: String) -> String:
	return String(TIME.get(b, NIGHT))


## Does band `b` agree with scene-event time `t`?
static func agrees(b: String, t: String) -> bool:
	return time_of(b) == t


## The sun at `hour`: [elevation (degrees, negative: pointing down), world yaw] for the key light
## (greybox LOOKS "sun"). Low in the morning from the default camera's right, highest at noon (50
## degrees: shadows still show) across the view, low in the afternoon from its left, so the shadows
## always fall where the default camera sees them.
static func sun(hour: int) -> Array:
	var t := clampf((posmod(hour, 24) - 6.0) / 12.0, 0.0, 1.0)
	var elev := 18.0 + 32.0 * sin(PI * t)
	return [-elev, 150.0 - 140.0 * t]


## The light entries a map's LightField bakes, by day: lamps, signs and the dressing's glow outdoors
## scaled by `out_scale` (sunlight drowns them); room lights scaled by `room_scale` (offices are lit:
## under the roof's shadow by day their lamps have to read over the sky light). Night (both 1): the
## entries unchanged. View only: the rules' lit squares are LightPlan.plan's.
static func bake_lights(m: TacMap, entries: Array, out_scale: float, room_scale := 1.0) -> Array:
	if out_scale == 1.0 and room_scale == 1.0:
		return entries
	var out := []
	for e in entries:
		var k := room_scale if e.has("room") or _indoors(m, e.cell) else out_scale
		if k == 1.0:
			out.append(e)
			continue
		var d: Dictionary = (e as Dictionary).duplicate()
		d.energy = float(e.energy) * k
		out.append(d)
	return out


## Daylight into rooms through their outside doors and glass walls (view only, LightField entries):
## a soft sky-coloured pool just inside each opening on the outside of a building, so a room by day
## isn't a dark void behind its lit facade. [] at night.
static func window_light(m: TacMap, col: Color, energy: float) -> Array:
	var out := []
	if energy <= 0.0:
		return out
	var seen := {}
	for f in m.floors:
		for y in m.h:
			for x in m.w:
				var t := m.t(f, x, y)
				if t != TacMap.T.DOOR and not (t == TacMap.T.WALL and int(m.wall_mat[f][y * m.w + x]) in [5, 6]):
					continue
				for d in MapGen.DIRS:
					var o: Vector2i = Vector2i(x, y) + d
					var i: Vector2i = Vector2i(x, y) - d
					if not (m.inb(o.x, o.y) and m.inb(i.x, i.y)):
						continue
					if m.t(f, o.x, o.y) != TacMap.T.OUTSIDE or m.t(f, i.x, i.y) != TacMap.T.FLOOR:
						continue
					var k := Vector3i(i.x, i.y, f)
					if seen.has(k):
						continue
					seen[k] = true
					out.append({"kind": "daylight", "cell": k, "out": Vector2i.ZERO, "color": col, "energy": energy, "range": 5.0})
	return out


static func _indoors(m: TacMap, cell: Vector3i) -> bool:
	if not m.inb(cell.x, cell.y):
		return false
	var l := m.label(cell.z, cell.x, cell.y)
	return l >= 0 and not m.rooms[l].get("outdoor", false)
