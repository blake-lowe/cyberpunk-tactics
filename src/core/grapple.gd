class_name Grapple
extends RefCounted
## A Grapple between two combatants (CPR core p.177, docs/rules/combat.md section 7): the Attacker
## (`holder`) has hold of the Defender (`held`). Both combatants point at the same Grapple
## (Combatant.grapple) for as long as it lasts. Encounter-scoped: it is never saved and
## Combatant.gig_reset clears it, so it can't outlast a gig.
##
## - Grab: both roll DEX + Brawling + 1d10, the Defender wins ties (p.177, p.172). Needs the target
##   within reach (p.177; Encounter: a neighbouring square).
## - While it lasts both take -2 to all Actions (Combatant.action_penalty), the Defender has no Move
##   Action and is dragged along by the Attacker's (TurnState.begin, Encounter.move_to), and neither
##   can use a two-handed weapon (Attack._illegal_reason) (p.177).
## - The Attacker ends it for free; the Defender, or anyone else, ends it with an Action and a won
##   Grab roll against the Attacker (p.177).
## - Choke and Throw need it (p.177); so does Human Shield, which only the Attacker can use (p.184).

const PENALTY := 2              # -2 to all Actions for both, p.177
const CHOKE_KO_ROUNDS := 3      # choked 3 successive Rounds: Unconscious whatever the HP, p.177
## RULES-UNVERIFIED: p.177 doesn't say how long a choke keeps them out; we use the 1 minute
## (20 rounds of 3 s, p.126) a stabilized character stays Unconscious (p.223).
const KO_ROUNDS := 20

var holder: Combatant
var held: Combatant
var chokes := 0                 ## successive Rounds the held one has been choked
var last_choke_round := -99
var shield := false             ## the holder has equipped the held one as a Human Shield (p.184)
## Once a Human Shield dies it is a corpse shield with HP = its BODY in life (p.184); -1 while alive.
var corpse_hp := -1


## A live grapple: two people struggling. A corpse shield is held, but nobody is grappled any more.
func live() -> bool:
	return corpse_hp < 0


## Who's on the other end of it from `c`.
func other(c: Combatant) -> Combatant:
	return held if c == holder else holder


## Grab Check base: DEX + Brawling (p.177) less the usual penalties (wounds, the grapple's -2).
static func base(c: Combatant) -> int:
	return c.skill_base("brawling") - c.action_penalty()


## Why `attacker` can't Grab `defender` ("" if it can). Reach and turn economy are the caller's.
## RULES-UNVERIFIED (p.177 is silent): no Grab while already in a grapple, on someone already in
## one, or on someone who can't resist (unconscious): those get a different rule in the book or none.
static func why_not(attacker: Combatant, defender: Combatant) -> String:
	if attacker == defender:
		return "not yourself"
	if not attacker.can_act():
		return "can't act"
	if attacker.grapple != null:
		return "already holding or held"
	if defender.dead or not defender.can_act():
		return "they're down"
	if defender.grapple != null:
		return "already in a grapple"
	return ""


## P(the Grab succeeds) for the hit-chance popup.
static func grab_chance(attacker: Combatant, defender: Combatant) -> float:
	return Check.chance_opposed(base(attacker), base(defender))


## Roll the Grab. On a win both combatants share a new Grapple. Returns {ok, reason, success, check, grapple}.
static func grab(dice: Dice, attacker: Combatant, defender: Combatant) -> Dictionary:
	var why := why_not(attacker, defender)
	if why != "":
		return {"ok": false, "reason": why}
	var check := Check.opposed(dice, base(attacker), base(defender))
	var out := {"ok": true, "success": check.success, "check": check, "grapple": null}
	if check.success:
		var g := Grapple.new()
		g.holder = attacker
		g.held = defender
		attacker.grapple = g
		defender.grapple = g
		out.grapple = g
	return out


## P(`by` breaks the hold): their Grab roll against the Attacker's, the Attacker winning ties (p.177).
func escape_chance(by: Combatant) -> float:
	return Check.chance_opposed(base(by), base(holder))


## The Defender (or anyone else) tries to break the hold: an Action, won Grab roll vs the Attacker
## (p.177). Returns {success, check}; on success the grapple is over.
func escape(dice: Dice, by: Combatant) -> Dictionary:
	var check := Check.opposed(dice, base(by), base(holder))
	if check.success:
		end()
	return {"success": check.success, "check": check}


## Choke (p.177): the Attacker's BODY straight to HP, armour ignored and not ablated. If that would
## take someone above 1 HP below 0 they are left at 1 HP and Unconscious instead (the summary's
## "below 0" taken literally: a choke landing exactly on 0 leaves them Mortally Wounded at 0;
## RULES-UNVERIFIED). Choking the same target in 3 successive Rounds knocks them out whatever their
## HP. `round_num` is the Round it happens in. Returns {damage, knocked_out}.
func choke(round_num: int) -> Dictionary:
	var dmg := holder.stat("BODY")
	var out := {"damage": dmg, "knocked_out": false}
	chokes = chokes + 1 if last_choke_round == round_num - 1 else 1
	last_choke_round = round_num
	if held.hp > 1 and held.hp - dmg < 0:
		held.hp = 1
		out.knocked_out = true
	else:
		held.hp -= dmg
	if chokes >= CHOKE_KO_ROUNDS:
		out.knocked_out = true
	if out.knocked_out and held.hp >= 1:
		_knock_out(held)
	return out


## Throw (p.177): the Attacker's BODY straight to HP, armour ignored and not ablated; the grapple
## (and its -2) ends and the target is Prone. Returns {damage}.
func throw_down() -> Dictionary:
	var dmg := holder.stat("BODY")
	var t := held
	end()
	t.hp -= dmg
	t.prone = true
	return {"damage": dmg}


## Why the holder can't take the held one as a Human Shield ("" if they can). p.184: the Attacker
## in a grapple, no other shield (we model no other shields yet), using the grappling hand.
func shield_why_not(by: Combatant) -> String:
	if by != holder:
		return "only the one holding can"
	if shield:
		return "already a shield"
	if not live():
		return "that's a corpse"
	return ""


## The held one dies. A Human Shield becomes a corpse shield with HP = their BODY in life (p.184),
## still held; anyone else is let go. Returns true if a corpse shield was made.
func held_died() -> bool:
	if shield and live():
		corpse_hp = held.raw_stat("BODY")
		return true
	end()
	return false


## The corpse shield takes `damage` (a shield takes the whole attack as HP damage, p.183). At 0 it
## is no longer cover but stays in hand until dropped (p.183). RULES-UNVERIFIED: excess damage is
## lost, as it is for cover (p.182). Returns the HP left.
func hit_corpse(damage: int) -> int:
	corpse_hp = maxi(0, corpse_hp - damage)
	return corpse_hp


## Does the shield still stop shots? A live Human Shield is cover (p.184); a corpse shield is
## until its HP runs out (p.183).
func covers() -> bool:
	return shield and (live() or corpse_hp > 0)


## Let go: both are free of each other.
func end() -> void:
	if holder != null and holder.grapple == self:
		holder.grapple = null
	if held != null and held.grapple == self:
		held.grapple = null


static func _knock_out(c: Combatant) -> void:
	c.unconscious = true
	c.wake_in = maxi(c.wake_in, KO_ROUNDS)
