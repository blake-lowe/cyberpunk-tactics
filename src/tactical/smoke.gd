class_name Smoke
extends RefCounted
## Smoke grenades' clouds (CPR core p.347, Smoke Ammunition: "obscures a 10m/yd by 10m/yd area with
## smoke for a minute on impact. The typical penalty for trying to perform a task obscured by smoke
## is -4"). The task modifier table has the same -4 for a task obscured by smoke or darkness (p.130-131).
##
## A cloud fills the 5x5 squares (2 m each) round the grenade's landing square, the area a blast covers
## (p.174), as far as it can spread without passing a wall or a closed door. It doesn't stop a line of
## sight: smoke is intangible obscurement, not cover (Low Light/Infrared/UV, p.360, "can't see through
## anything that could provide cover", ignores it). It makes seeing hard: a Perception Check to spot
## someone (Encounter._spots) and an attack (Encounter.preview) with smoke anywhere on the line, at either
## end included, take the -4 once, whether there is smoke, darkness or both (one modifier: "obscured").
## The minute is 20 Rounds of 3 seconds (p.126): a cloud made in Round R is gone when Round R+20 starts.

const HALF := 2       ## 10 x 10 m: 5x5 squares round the landing square (p.347; a blast's area, p.174)
const ROUNDS := 20    ## a minute (p.347): 20 Rounds of 3 seconds (p.126)
const PENALTY := 4    ## "Task obscured by smoke, darkness" -4 (p.130-131); smoke's typical -4 (p.347)

var clouds: Array[Dictionary] = []   ## {id, center: Vector3i, made: Round, until: the Round it's gone, cells: {Vector3i: true}}
var cells := {}                      ## Vector3i → how many clouds cover it
var _next := 0


## A new cloud at `center`, made in Round `round_num`: the squares within `half` of it the smoke can
## reach from there (no wall, closed door or solid ground in the way). Returns the cloud.
func add(m: TacMap, los: Los, center: Vector3i, round_num: int, half := HALF, rounds := ROUNDS) -> Dictionary:
	var got := {}
	var todo: Array[Vector3i] = [center]
	got[center] = true
	while not todo.is_empty():
		var v: Vector3i = todo.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := Vector3i(v.x + d.x, v.y + d.y, v.z)
			if got.has(n) or absi(n.x - center.x) > half or absi(n.y - center.y) > half or not _fills(m, los, n):
				continue
			got[n] = true
			todo.append(n)
	var cloud := {"id": _next, "center": center, "made": round_num, "until": round_num + rounds, "cells": got}
	_next += 1
	clouds.append(cloud)
	for v in got:
		cells[v] = int(cells.get(v, 0)) + 1
	return cloud


## The half-width in squares of a square area `size_m` metres across (2 m squares): 10 m → 5 squares → 2.
static func half_for(size_m: int) -> int:
	return int(size_m / 2) / 2


## Smoke drifts into a square that is on the map, not solid (a wall, a closed door, earth) - furniture
## and cover don't stop it.
static func _fills(m: TacMap, los: Los, v: Vector3i) -> bool:
	if not m.inb(v.x, v.y):
		return false
	var t := m.t(v.z, v.x, v.y)
	return t != TacMap.T.VOID and t != TacMap.T.WALL and los.blocker(v) != "wall"


## The start of Round `round_num`: clouds whose minute is up clear. Returns the clouds gone.
func tick(round_num: int) -> Array:
	var gone: Array = clouds.filter(func(c): return int(c.until) <= round_num)
	for c in gone:
		clouds.erase(c)
		for v in c.cells:
			cells[v] = int(cells[v]) - 1
			if int(cells[v]) <= 0:
				cells.erase(v)
	return gone


func covers(v: Vector3i) -> bool:
	return cells.has(v)


## Is the line from `a` to `b` obscured by smoke: smoke at either end or on any square between?
func on_line(a: Vector3i, b: Vector3i) -> bool:
	if cells.is_empty():
		return false
	if cells.has(a) or cells.has(b):
		return true
	for v in Los.ray(a, b):
		if cells.has(v):
			return true
	return false


## Rounds left on a cloud at Round `round_num` (the HUD).
static func left(cloud: Dictionary, round_num: int) -> int:
	return maxi(0, int(cloud.until) - round_num)
