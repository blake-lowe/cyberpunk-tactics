class_name HazardZone
extends RefCounted
## A shrinking safe circle: an encounter rule any scene can carry (setpieces.json rules.hazard_zone,
## or Encounter.setup opts.hazard_zone). From round `start`, and every `every` rounds after, the safe
## circle closes one step on a point drawn at setup, `steps` times, down to `final_r` squares. A unit
## caught outside it (inside the map's hazard area, TacMap params `hazard_area`) at the end of its
## own turn takes `dice[stage - 1]` d6 straight to HP, unless its side's ai is one the zone `spare`s.
## The Combat Zone's MIST (NC2045 p.215) is the first: its numbers are in setpieces.json.
##
## spec: {name, start, every, steps, final_r, dice: [d6 per stage], spare: [side ai], source}

var name := "HAZARD"
var center := Vector2.ZERO          ## the point it closes on (in squares; a square's middle is +0.5)
var area := Rect2i()                ## where it bites; outside the area it never does
var radii: Array[float] = []        ## the safe radius at each stage; radii[0] = INF (not closing yet)
var stage := 0                      ## closes so far (0 until round `start`)
var start := 3
var every := 3
var dice_by_stage: Array = []       ## d6 a turn outside, per stage (1-based: [0] is stage 1)
var spare: Array = []               ## side ais it never touches (guard: the owner's people)


## The zone for a map, or null when `spec` is empty. Draws its centre with `dice`: an open outdoor
## square in the middle half of the area (else the area's middle).
static func from_spec(spec: Dictionary, m: TacMap, dice: Dice) -> HazardZone:
	if spec.is_empty():
		return null
	var z := HazardZone.new()
	z.name = String(spec.get("name", "HAZARD"))
	z.start = maxi(1, int(spec.get("start", 3)))
	z.every = maxi(1, int(spec.get("every", 3)))
	z.dice_by_stage = spec.get("dice", [1])
	z.spare = spec.get("spare", [])
	var a: Array = m.params.get("hazard_area", [0, 0, m.w, m.h])
	z.area = Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
	var mid := z.area.grow_individual(-z.area.size.x / 4, -z.area.size.y / 4, -z.area.size.x / 4, -z.area.size.y / 4)
	var cands: Array[Vector2i] = []
	for y in range(mid.position.y, mid.end.y):
		for x in range(mid.position.x, mid.end.x):
			if m.t(0, x, y) == TacMap.T.OUTSIDE and m.walkable(0, Vector2i(x, y)):
				cands.append(Vector2i(x, y))
	var c: Vector2i = z.area.get_center() if cands.is_empty() else cands[dice.rng.randi_range(0, cands.size() - 1)]
	z.center = Vector2(c) + Vector2(0.5, 0.5)
	# The first circle takes in the whole area; each close takes an equal step towards final_r.
	var r0 := 0.0
	for corner in [z.area.position, Vector2i(z.area.end.x, z.area.position.y), Vector2i(z.area.position.x, z.area.end.y), z.area.end]:
		r0 = maxf(r0, z.center.distance_to(Vector2(corner)))
	var steps := maxi(1, int(spec.get("steps", 4)))
	var final_r := float(spec.get("final_r", 6))
	z.radii.append(INF)
	for k in range(1, steps + 1):
		z.radii.append(lerpf(r0, final_r, float(k) / steps))
	return z


func steps() -> int:
	return radii.size() - 1


## The round the k-th close happens on (k from 1).
func close_round(k: int) -> int:
	return start + (k - 1) * every


## Bring the zone up to round `round_num`. True if it closed in.
func tick(round_num: int) -> bool:
	var moved := false
	while stage < steps() and round_num >= close_round(stage + 1):
		stage += 1
		moved = true
	return moved


## Rounds until the next close (0: this round), or -1 when it is as small as it gets.
func closes_in(round_num: int) -> int:
	if stage >= steps():
		return -1
	return maxi(0, close_round(stage + 1) - round_num)


func radius() -> float:
	return radii[stage]


## The radius after the next close (the final one once it is as small as it gets).
func next_radius() -> float:
	return radii[mini(stage + 1, steps())]


## Is square `v` (any storey) outside the safe circle and inside the hazard area?
func outside(v: Vector3i) -> bool:
	return stage > 0 and area.has_point(Vector2i(v.x, v.y)) and Vector2(v.x + 0.5, v.y + 0.5).distance_to(center) > radius()


## d6 a turn outside, at the current stage.
func damage_dice() -> int:
	if stage <= 0 or dice_by_stage.is_empty():
		return 0
	return int(dice_by_stage[mini(stage, dice_by_stage.size()) - 1])


## Does the zone bite a unit of side ai `ai` standing at `v`?
func bites(ai: String, v: Vector3i) -> bool:
	return not (ai in spare) and outside(v)


## Jump straight to stage `k` (review renders).
func force_stage(k: int) -> void:
	stage = clampi(k, 0, steps())
