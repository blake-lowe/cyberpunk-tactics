class_name NeutralGround
extends RefCounted
## Neutral ground: an encounter rule any set piece can carry (setpieces.json rules.neutral_ground,
## or Encounter.setup opts.neutral_ground). The public rooms on the street floor of one building
## (the club floor) are a house where nobody fights: the guards posted there (the bouncers) sit
## on a side of their own that is `neutral` to the crew, so they neither spot nor shoot them, and
## the rest of the house holds its fire at crew standing inside. The first attack the crew makes
## in those rooms, or anywhere a bouncer can see, ends it for good: the bouncers go back to the
## opposition's side and the whole house turns hostile (Encounter._break_peace). Out of the
## bouncers' sight the usual rules apply. Totentanz (NC2045 p.94) is the first.
##
## spec: {name, hud (the round tab's line while it holds), hud_broken (after), part (the building;
## default the target), brief (the gig's briefing line, SetPieces.briefs), _cite, _house_rule}

var name := "NEUTRAL GROUND"
var hud := "NO FIGHTING"
var hud_broken := "THE HOUSE IS HOSTILE"
var cells := {}        ## Vector3i → true: the house's public squares (street floor)
var structure := -1    ## the building whose public floor it is
var side := -1         ## the house's own side while the peace holds (Encounter sets it)
var holds := true      ## nobody has fought in the house yet


## The rule for a map, or null when `spec` is empty or the building has no public rooms.
static func from_spec(spec: Dictionary, m: TacMap) -> NeutralGround:
	if spec.is_empty():
		return null
	var g := NeutralGround.new()
	g.name = String(spec.get("name", g.name))
	g.hud = String(spec.get("hud", g.hud))
	g.hud_broken = String(spec.get("hud_broken", g.hud_broken))
	var part := String(spec.get("part", ""))
	for st in m.structures:
		if (part != "" and String(st.get("part", "")) == part) or (part == "" and st.target):
			g.structure = int(st.id)
	if g.structure < 0:
		for st in m.structures:
			if st.target:
				g.structure = int(st.id)
	for y in m.h:
		for x in m.w:
			var l := m.label(m.street, x, y)
			if l < 0 or int(m.rooms[l].get("structure", -1)) != g.structure or int(m.rooms[l].zone) > TacMap.Zone.PUBLIC:
				continue
			if m.walkable(m.street, Vector2i(x, y)):
				g.cells[Vector3i(x, y, m.street)] = true
	return null if g.cells.is_empty() else g


func inside(v: Vector3i) -> bool:
	return cells.has(v)


## The round tab's line: "TOTENTANZ · NO FIGHTING ON THE FLOOR", then "TOTENTANZ · THE HOUSE TURNS".
func hud_text() -> String:
	return "%s · %s" % [name, hud if holds else hud_broken]
