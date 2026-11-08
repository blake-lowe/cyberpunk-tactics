class_name ClickIntent
extends RefCounted
## Which mouse button does what in the tactical view (owner: right click moves, left click attacks).
## Pure, so the mapping is testable headless; greybox._unhandled_input acts on the intent.
##   RIGHT          move / run to the hovered square (path preview on the move grid)
##   LEFT           the armed tool on its target (melee, shell, grenade square, suppress, stabilize,
##                  grab a neighbouring foe, break the hold on a friend…),
##                  else shoot the cover in the way when the attack stage's COVER is armed,
##                  else attack the hovered enemy with the drawn weapon,
##                  else, with no attack armed and no unit under the cursor, focus the building
##                  under it (its floors take the floor stack, FloorNav.slices);
##                  nothing on open ground or a friendly
##   in the NET     either button picks a node (moving there is the only click there)
## The order is the rule: a foe under the cursor is always attacked, never focused past, and an
## armed attack or tool never turns a near-miss into a focus. (Shift+left no longer shoots cover:
## Shift and Ctrl are the floor keys now; COVER on the attack stage does it.)
## Interacting (doors, devices, bodies) is not a click: B or the bar's button acts on what's adjacent.

const NONE := ""
const MOVE := "move"
const ATTACK := "attack"
const COVER := "shoot_cover"
const TOOL := "tool"
const NET := "net_pick"
const FOCUS := "focus_building"


## `building`: the building (structure id) under the cursor, -1 none; `armed`: an attack is armed
## (the attack stage is open); `hover_unit`: any unit (a friendly, a bystander) is under the cursor.
static func of(button: int, in_net: bool, tool: String, cover_mode: bool, hover_foe: bool, building := -1,
		armed := false, hover_unit := false) -> String:
	if button != MOUSE_BUTTON_LEFT and button != MOUSE_BUTTON_RIGHT:
		return NONE
	if in_net:
		return NET
	if button == MOUSE_BUTTON_RIGHT:
		return MOVE
	if tool != "":
		return TOOL   # every tool checks its own target (a foe to hit, an ally to patch up, a square)
	if cover_mode:
		return COVER
	if hover_foe:
		return ATTACK
	if armed or hover_unit or building < 0:
		return NONE
	return FOCUS
