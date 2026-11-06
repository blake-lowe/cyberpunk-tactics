class_name ClickIntent
extends RefCounted
## Which mouse button does what in the tactical view (owner: right click moves, left click attacks).
## Pure, so the mapping is testable headless; greybox._unhandled_input acts on the intent.
##   RIGHT          move / run to the hovered square (path preview on the move grid)
##   LEFT           the armed tool on its target (melee, shell, grenade square, suppress, stabilize,
##                  grab a neighbouring foe, break the hold on a friend…),
##                  else attack the hovered enemy with the drawn weapon; nothing on ground / a friendly
##   SHIFT + LEFT   shoot the cover in the way (also plain left with Shoot Cover armed)
##   in the NET     either button picks a node (moving there is the only click there)
## Interacting (doors, devices, bodies) is not a click: B or the bar's button acts on what's adjacent.

const NONE := ""
const MOVE := "move"
const ATTACK := "attack"
const COVER := "shoot_cover"
const TOOL := "tool"
const NET := "net_pick"


static func of(button: int, shift: bool, in_net: bool, tool: String, cover_mode: bool, hover_foe: bool) -> String:
	if button != MOUSE_BUTTON_LEFT and button != MOUSE_BUTTON_RIGHT:
		return NONE
	if in_net:
		return NET
	if button == MOUSE_BUTTON_RIGHT:
		return MOVE
	if tool != "":
		return TOOL   # every tool checks its own target (a foe to hit, an ally to patch up, a square)
	if shift or cover_mode:
		return COVER
	return ATTACK if hover_foe else NONE
