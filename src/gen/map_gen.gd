class_name MapGen
extends RefCounted
## Entry point and shared constants for map generation.
## - SceneGen builds whole scenes (streets, docks, badlands…) out of outdoor areas and structures.
## - BuildingGen fills each building plot.
## generate() keeps the original single-building scene: one building on a street corner.

const DEFAULTS := {
	"w": 40, "h": 32, "floors": 2,
	"security": 1,       # 0-3 → Basic/Standard/Uncommon/Advanced (p210)
	"density": -1.0,     # cover density 0-1; -1 = site type default
	"loops": 0.35,       # chance of extra doors between same/adjacent-zone rooms (flanking routes)
	"verticality": 1,    # 0 = single floor, 1 = stairs, 2 = stairs + elevator
	"net_threat": 1.0,   # gig parameter: scales the Black ICE budget
	"net_scale": "",     # "intro" = one tiny subnet for tutorial / low-stakes gigs
}

static var DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


## One building of site type `site` on a street corner (street to the south, alley to the east).
## overrides may force "algorithm" (for comparisons) and any DEFAULTS key.
static func generate(seed_value: int, site: String, overrides: Dictionary = {}) -> TacMap:
	var o := overrides.duplicate()
	o["site"] = site
	return SceneGen.generate(seed_value, "lone_building", o)


static func max_zone(security: int) -> int:
	return [TacMap.Zone.STAFF, TacMap.Zone.SECURE, TacMap.Zone.VAULT, TacMap.Zone.VAULT][clampi(security, 0, 3)]
