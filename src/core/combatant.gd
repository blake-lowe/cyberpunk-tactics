class_name Combatant
extends RefCounted
## Rules-level state of anyone in a fight: stats, skills, HP, armor, injuries, death saves.
## Pure data + rules. Scene/visual nodes reference a Combatant; never the other way round.

enum Wound { UNHURT, LIGHT, SERIOUS, MORTAL, DEAD }

const WOUND_ACTION_PENALTY := {Wound.SERIOUS: 2, Wound.MORTAL: 4}  # p220
const MORTAL_MOVE_PENALTY := 6  # p220, MOVE min 1

var id: String
var display_name: String       ## the handle the crew and the HUD use
var real_name := ""              ## the person behind the handle (Names.person); "" for NPCs and older saves
var team: int = 0
var faction := "crew"        ## World faction id (data/world/factions.json); the crew is "crew"
var stats: Dictionary = {}    ## "INT","REF","DEX","TECH","COOL","WILL","LUCK","MOVE","BODY","EMP" → int
var skills: Dictionary = {}   ## skill id → level
var hp: int
var armor: Dictionary = {"head": null, "body": null}  ## location → ArmorPiece
var injuries: Array[Dictionary] = []  ## crit table entries + {"location": ...}
var base_dsp: int = 0         ## Base Death Save Penalty (raised by some crits).
var dsp: int = 0              ## Current Death Save Penalty (base + saves rolled since last stabilization).
## Rolls Death Saves when Mortally Wounded (p.222). HOUSE-RULE (NPC_FLATLINE, Encounter._flatline_npcs):
## the encounter clears it for NPCs, who flatline below 1 HP instead. Not saved: crew always roll.
var death_saves := true
var dead := false
var unconscious := false
var wake_in := 0               ## rounds until a stabilized character comes round (1 minute = 20 rounds, p223)
var prone := false              ## p.168-169: no Move Action until Get Up (TurnState.get_up). Thrown foes land Prone (p.177).
## The Grapple this combatant is in, holding or held (Grapple, p.177); null when free. Not saved:
## a grapple never outlasts the gig (gig_reset clears it).
var grapple: Grapple = null
var weapons: Array[Weapon] = []
var block := ""               ## the printed stat block an NPC was built from (npcs.json), "" for crew
var hp_max_override := 0       ## a stat block's printed HP when it differs from the formula (0: formula)
var ip: int = 0                ## unspent Improvement Points (p410-411)
## Reputation Level 0-10 (CPR core p193): the Level of their most notable deed (a new deed replaces it
## only if higher; most characters start at 0). Others roll 1d10 under it to have heard of them.
var reputation: int = 0
var look_seed: int = -1        ## the crew member's appearance seed (stable across gigs); -1 = by unit order

var role: String = ""         ## "solo", "netrunner", "medtech", "tech", ...
var role_rank: int = 0
var perks: Array[String] = []
## Medtech Medicine (p149-150): Specialty points. Pharmaceutical points unlock drugs in order
## (Speedheal, Stim); doses per gig = Medical Tech Skill (HOUSE-RULE: synthesized in downtime).
var medicine := {}               ## {surgery, pharma, cryo} points
var downtime := "recover"        ## between gigs: recover (Campaign.DOWNTIME)
var maker := {}                  ## Tech Maker Specialty ranks (p147): field, upgrade, fabrication, invention
var doses := 0                   ## Pharmaceutical doses carried this gig
var temp_mods := {}              ## stat → penalty for the rest of the gig (Liche, Scorpion: "for 1 hour")
var heat := 0                    ## this gig: added to an existing armor penalty by the weather (Weather.heat; set by the Encounter)
var kit: Array[String] = ["", ""]   ## what they take into a gig from safehouse storage (Items keys; slot rules in gear.json kit_rules)
var kit_spent: Array[bool] = [false, false]   ## this gig: a consumable slot already used
var drugs_taken: Array[String] = []   ## this gig: drug ids dosed (addiction checks afterwards, p.229)
var drug_fx: Array[Dictionary] = []   ## this gig: effects of drugs in the system (HOUSE-RULE: a dose lasts the gig)
var addictions: Array[String] = []    ## drug ids they're hooked on (p.229): the "addicted" fx apply unless high
var clean_since := {}                 ## drug id → campaign day Addiction Therapy freed them of it (p230: a year of auto-fails)
var drug_humanity := {}               ## this gig: drug id → Humanity it cost (Black Lace refunds it on resisting addiction)
var burning := 0                 ## on fire: HP lost at the end of each turn until an Action puts it out (Hellhound 2, p207; flamethrower 4, p348)
var cyber_off := {}              ## Cyber.key(piece) ("cybereye@left_eye") → rounds it stays inoperable (Microwaver, p348)
## The cyberdeck carried and what's loaded on it (Deck; CPR core p.196, p.201-209): the deck's gear.json
## id ("" for none), its Programs (copies repeat), its Hardware, and Programs a Backup Drive saved.
var deck := ""
var programs: Array[String] = []
var deck_hardware: Array[String] = []
var backup: Array[String] = []
var stimmed := false             ## Stim: ignore Seriously Wounded penalties (1 hour = the gig)
var speedhealed := false         ## Speedheal: once per day   ## Role specialisation perks (data/rules/perks.json, HOUSE-RULE)
## Solo Combat Awareness allocation (p146): ability id → points spent. See COMBAT_AWARENESS.
var awareness: Dictionary = {}
var tracks_humanity := false  ## Mooks skip Humanity entirely.
var humanity: int = 0
var max_humanity: int = 0
## Installed cyberware, one {"id", "loc"} per piece (Cyber: locations, slots, what fits). Change it
## through install_cyberware / remove_cyberware, which keep subdermal armour and built-in weapons in step.
var implants: Array[Dictionary] = []
var subdermal: Dictionary = {}  ## location → ArmorPiece from Subdermal Armor / Skin Weave.
## This gig: activated chrome running, id → rounds left (the Sandevistan's minute, CPR core p.359),
## and chrome already used, id → true (its hour-long cooldown outlasts any gig). Not saved.
var chrome_on := {}
var chrome_spent := {}
## This gig: the Popup Shield is out of its Cyberarm (CPR core p.365). Its HP is the piece's "hp". Not saved.
var shield_out := false
## Chipware this character has had in (specs): putting one back in costs no Humanity Loss (CPR core p.359).
var chips_used: Array[String] = []
## This gig: a hand on a surface for the Tactile Boost (CPR core p.359): it senses motion within 20 m,
## and that hand does nothing else (Attack.hand_reason). Moving lifts it. Not saved.
var touching := false
## Per-Round trackers for "first X this Round" abilities. Reset by new_round().
var skip_next_action := false  ## Spinal Injury (p221).
var skip_next_move := false    ## Damaged/Lost Ear after moving > 4 m (p222).
var psychosis_turns := 0      ## Remaining turns of a cyberpsychosis episode (HOUSE-RULE).
var deflection_used := false
var spot_weakness_used := false

## Combat Awareness costs (p146). Stepped abilities list the cost of each level.
const COMBAT_AWARENESS := {
	"damage_deflection": [2, 4, 6, 8, 10],
	"fumble_recovery": [4],
	"initiative_reaction": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
	"precision_attack": [3, 6, 9],
	"spot_weakness": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
	"threat_detection": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
}


func _init(p_name: String = "", p_stats: Dictionary = {}, p_skills: Dictionary = {}) -> void:
	display_name = p_name
	id = p_name.to_snake_case()
	stats = p_stats
	skills = p_skills
	hp = max_hp() if not stats.is_empty() else 0


# --- Derived stats -------------------------------------------------------

## STAT including permanent modifiers (cyberware, Humanity → EMP) but not armor or wounds.
func raw_stat(s: String) -> int:
	var v := int(stats.get(s, 0))
	if s == "EMP" and tracks_humanity:
		return maxi(0, humanity) / 10  # tens digit of current Humanity (p80)
	var fxs := _cyber_fx()
	for fx in fxs:
		if fx.has("stat") and fx["stat"].has(s):
			v = mini(v + int(fx["stat"][s]), maxi(v, int(fx.get("stat_cap", 99))))
	for fx in fxs:   # a Linear Frame: BODY becomes 12 or 14, never lower than it was (CPR core p.367)
		if fx.has("stat_set") and fx["stat_set"].has(s):
			v = maxi(v, int(fx["stat_set"][s]))
	return v


## STAT after armor penalty (REF/DEX/MOVE, p184) and wound/crit MOVE penalties.
func stat(s: String) -> int:
	var v := raw_stat(s)
	if s in ["REF", "DEX", "MOVE"]:
		v = maxi(0, v - armor_penalty())
	if temp_mods.has(s):
		v = maxi(1, v - int(temp_mods[s]))
	v = maxi(1, v + drug_stat(s)) if drug_stat(s) != 0 and v > 0 else v
	if s == "MOVE":
		var reduction := _fx_sum("move")
		if wound_state() == Wound.MORTAL:
			reduction += MORTAL_MOVE_PENALTY
		if reduction > 0:
			v = maxi(mini(v, 1), v - reduction)  # min 1 unless armor already took it to 0
	return v


## What kind of person this is, for cards: the stat block's name ("Security Operative") or the role.
func kind_name() -> String:
	if block != "":
		return String(RulesDB.load_json("npcs.json")["blocks"][block]["name"])
	return role.capitalize()


func max_hp() -> int:
	if hp_max_override > 0:
		return hp_max_override
	return 10 + 5 * ceili((raw_stat("BODY") + raw_stat("WILL")) / 2.0)  # p79


func seriously_wounded_threshold() -> int:
	return ceili(max_hp() / 2.0)  # p79/p220


func death_save_target() -> int:
	return raw_stat("BODY")  # p79


func armor_penalty() -> int:
	var worst := 0
	for loc in armor:
		if armor[loc] != null:
			worst = maxi(worst, (armor[loc] as ArmorPiece).penalty)
	return worst + heat if worst > 0 else 0   # a heat wave makes an existing penalty worse (Weather.heat, NCW p.5)


func skill_level(skill_id: String) -> int:
	var v := int(skills.get(skill_id, 0))
	if chipped(skill_id):   # Skill Chip: trained at +3 unless already higher (CPR core p.360)
		v = maxi(v, 3)
	for fx in _cyber_fx():
		if fx.has("skill"):
			v += int(fx["skill"].get(skill_id, 0))
	return v


## A working Skill Chip for this Skill is in a Chipware Socket (CPR core p.359-360).
func chipped(skill_id: String) -> bool:
	for p in implants:
		if String(p.get("choice", "")) == skill_id and Cyber.def(String(p.id)).get("fx", {}).has("skill_chip") \
				and int(cyber_off.get(Cyber.key(p), 0)) <= 0:
			return true
	return false


## STAT + Skill (p130), before situational modifiers.
func skill_base(skill_id: String) -> int:
	return stat(RulesDB.skill_stat(skill_id)) + skill_level(skill_id) + int(perk_fx("skills").get(skill_id, 0)) + kit_skill_bonus(skill_id)


## Carried utilities' Skill bonuses (Medscanner +2 First Aid/Paramedic, Techscanner +2 Tech
## Skills, p.353-355), and the same scanners built into a Cyberarm (p.365-366). The same kind of
## tool doesn't stack, carried or installed: the best one counts.
func kit_skill_bonus(skill_id: String) -> int:
	var best := 0
	for i in kit.size():
		if kit[i] != "" and Items.kind(kit[i]) == "utility":
			best = maxi(best, int(Items.fx(kit[i]).get("skill_bonus", {}).get(skill_id, 0)))
	for fx in _cyber_fx():   # installed scanners and drugs in the system
		best = maxi(best, int(fx.get("skill_bonus", {}).get(skill_id, 0)))
	return best


## Net STAT change from drugs: doses in the system (+), addictions to drugs not currently in the
## system (-) (p.229, p.357-358).
func drug_stat(s: String) -> int:
	var t := 0
	for fx in drug_fx:
		t += int(fx.get("stat_bonus", {}).get(s, 0))
	for drug in addictions:
		var add: Dictionary = RulesDB.gear("drugs", drug).get("fx", {}).get("addicted", {})
		if bool(add.get("suppressed_by_primary", false)) and drug in drugs_taken:
			continue   # high: the craving's penalty is held off
		t += int(add.get("stat_bonus", {}).get(s, 0))
	return t


# --- Role perks (HOUSE-RULE game content, data/rules/perks.json) --------------------

## The perk tree for a Role: [[tier-1 options], [tier-2 options]].
static func perk_tree(p_role: String) -> Array:
	return RulesDB.load_json("perks.json")["roles"].get(p_role, [])


static func perk_def(id: String) -> Dictionary:
	for roles in RulesDB.load_json("perks.json")["roles"].values():
		for tier in roles:
			for p in tier:
				if p.id == id:
					return p
	return {}


## An effect summed over taken perks: a Dictionary for "skills" (merged), a number otherwise
## (numbers add; booleans become 1).
func perk_fx(key: String) -> Variant:
	if key == "skills":
		var out := {}
		for id in perks:
			var sk: Dictionary = perk_def(id).get("skills", {})
			for s in sk:
				out[s] = int(out.get(s, 0)) + int(sk[s])
		return out
	var total := 0.0
	for id in perks:
		var v: Variant = perk_def(id).get(key, null)
		if v != null:
			total += float(v)
	return total


## Can this perk be taken now? Returns "" if so, else the reason.
func perk_block(id: String) -> String:
	var tree := perk_tree(role)
	var cfg: Dictionary = RulesDB.load_json("perks.json")
	for t in tree.size():
		var ids: Array = tree[t].map(func(p): return p.id)
		if id not in ids:
			continue
		if ids.any(func(x): return x in perks):
			return "tier taken"
		if t >= 1 and not (tree[t - 1] as Array).any(func(p): return p.id in perks):
			return "needs tier %d" % t
		if t >= 1 and role_rank < int(cfg.tier2_rank):
			return "needs Rank %d" % int(cfg.tier2_rank)
		if ip < int(cfg.tier_cost[t]):
			return "%d IP" % int(cfg.tier_cost[t])
		return ""
	return "not this Role"


func perk_cost(id: String) -> int:
	var tree := perk_tree(role)
	for t in tree.size():
		if (tree[t] as Array).any(func(p): return p.id == id):
			return int(RulesDB.load_json("perks.json").tier_cost[t])
	return 0


func take_perk(id: String) -> bool:
	if perk_block(id) != "":
		return false
	ip -= perk_cost(id)
	perks.append(id)
	return true


## Role Rank (p411): 60 IP x the new Rank, max 10.
## Medical Tech Skill = Pharmaceutical + Cryosystem points (p149).
func medical_tech() -> int:
	return int(medicine.get("pharma", 0)) + int(medicine.get("cryo", 0))


## TECH + Medical Tech (p149, p229): a Medtech's base for Therapy. 0 for anyone else (only Medtechs
## have the Skill, p150).
func therapy_base() -> int:
	return stat("TECH") + medical_tech() if role == "medtech" else 0


## Pharmaceuticals this Medtech can make: one per Pharmaceutical point (p149), in our fixed order.
## HOUSE-RULE: Pharmaceuticals points unlock drugs in this fixed order (the book lets the Medtech
## pick one per point, p149); the first two are the ones that matter in a fight.
const PHARMA_ORDER := ["speedheal", "stim", "antibiotic", "rapidetox", "surge"]


func knows_drug(drug: String) -> bool:
	var i := PHARMA_ORDER.find(drug)
	return role == "medtech" and i >= 0 and i < int(medicine.get("pharma", 0))


## Fresh for a gig: doses restocked, once-a-day effects cleared (HOUSE-RULE: a gig is a day).
func gig_reset() -> void:
	doses = medical_tech() if role == "medtech" else 0
	for loc in armor:
		if armor[loc]:
			(armor[loc] as ArmorPiece).rigged = false
	stimmed = false
	speedhealed = false
	temp_mods.clear()
	heat = 0
	burning = 0
	cyber_off.clear()
	chrome_on.clear()
	chrome_spent.clear()
	shield_out = false
	touching = false
	kit_spent = [false, false]
	drugs_taken.clear()
	drug_fx.clear()
	if grapple != null:   # a grapple or a fall never carries into the next gig
		grapple.end()
	grapple = null
	prone = false
	for w in weapons:   # reloaded between gigs: a full magazine of standard rounds (the saved count is last gig's)
		w.reload()
		w.jammed = false
		w.load_special({}, 0)
		w.revealed = false   # a popup is hidden again for the next gig


## A flashbang's or teargas's injuries last "for the next minute" (p.346-347; Attack `expires_in`
## rounds, counted down on the victim's own turns). Once the fight is over that minute has passed.
func expire_brief_injuries() -> void:
	injuries.assign(injuries.filter(func(i): return not i.has("expires_in")))


func rank_raise_cost() -> int:
	return 60 * (role_rank + 1)   # CPR core p411


func raise_rank() -> bool:
	if role_rank >= 10 or ip < rank_raise_cost():
		return false
	ip -= rank_raise_cost()
	role_rank += 1
	if role == "tech":   # each Maker Rank: +1 in two different Specialties (p147); ours: Field and Upgrade
		for k in ["field", "upgrade"]:
			maker[k] = int(maker.get(k, 0)) + 1
	if role == "medtech":   # each Medicine Rank adds a Specialty point (p149): pharma first, max 5
		var k := "pharma" if int(medicine.get("pharma", 0)) < 5 else "surgery"
		medicine[k] = int(medicine.get(k, 0)) + 1
	return true


func wound_state() -> Wound:
	if dead:
		return Wound.DEAD
	if hp < 1:
		return Wound.MORTAL
	if hp < seriously_wounded_threshold():
		return Wound.SERIOUS
	if hp < max_hp():
		return Wound.LIGHT
	return Wound.UNHURT


## Penalty applied to every Action check (wound state + crits like Concussion).
func action_penalty() -> int:
	var w := wound_state()
	if w == Wound.SERIOUS and (stimmed or _cyber_fx().any(func(fx): return fx.get("ignore_seriously_wounded", false)) \
			or drug_fx.any(func(fx): return fx.get("ignore_seriously_wounded", false))):
		w = Wound.LIGHT  # Pain Editor (p112), Stim (p150), Black Lace (p.358)
	return int(WOUND_ACTION_PENALTY.get(w, 0)) + _fx_sum("all") + (Grapple.PENALTY if grapple != null and grapple.live() else 0)   # grappled: -2 both, p.177


## Penalty for an attack of the given kind ("ranged" or "melee").
func attack_penalty(kind: String) -> int:
	return action_penalty() + _fx_sum(kind)


func can_dodge_ranged() -> bool:
	return stat("REF") >= 8 and not _fx_any("no_dodge") and can_act() and not is_human_shield()  # p172; a Human Shield can't, p.184


## Holding someone in a grapple (the Attacker, p.177), a corpse shield included.
func is_grappling() -> bool:
	return grapple != null and grapple.holder == self


## Held in a live grapple (the Defender, p.177): no Move Action, dragged along.
func is_grappled() -> bool:
	return grapple != null and grapple.held == self and grapple.live()


## Held up as someone's Human Shield (p.184).
func is_human_shield() -> bool:
	return is_grappled() and grapple.shield


func can_act() -> bool:
	return not dead and not unconscious


## SP in a location: SP doesn't stack, only the highest counts (p184), incl. subdermal armor.
func sp(location: String) -> int:
	var best := 0
	for a in [armor.get(location), subdermal.get(location)]:
		if a != null:
			best = maxi(best, (a as ArmorPiece).sp)
	return best


## All armor in a location ablates together when damage gets through (p184, p186).
func ablate(location: String) -> void:
	for a in [armor.get(location), subdermal.get(location)]:
		if a != null:
			(a as ArmorPiece).ablate()


func initiative_bonus() -> int:
	var b := awareness_level("initiative_reaction")
	for fx in _cyber_fx():
		b += int(fx.get("initiative", 0))
	for id in chrome_on:   # activated: the Sandevistan's +3 to any Initiative Roll in its minute (p.359)
		b += int(Cyber.def(String(id)).get("fx", {}).get("initiative_activated", 0))
	return b


## Called at the start of each Round.
func new_round() -> void:
	deflection_used = false
	spot_weakness_used = false


# --- Solo: Combat Awareness (p146) --------------------------------------

## Level bought in an ability (e.g. precision_attack 2 = +2), from points allocated.
func awareness_level(ability: String) -> int:
	if role != "solo":
		return 0
	var pts := int(awareness.get(ability, 0))
	var level := 0
	for cost in COMBAT_AWARENESS[ability]:
		if pts >= cost:
			level += 1
	return level


## Set an allocation. Returns false (and changes nothing) if it exceeds Role Rank.
func set_awareness(alloc: Dictionary) -> bool:
	var total := 0
	for k in alloc:
		if not COMBAT_AWARENESS.has(k):
			return false
		total += int(alloc[k])
	if role != "solo" or total > role_rank:
		return false
	awareness = alloc.duplicate()
	return true


# --- Humanity & cyberware (p80, p110-116, p230) --------------------------

func init_humanity() -> void:
	tracks_humanity = true
	humanity = int(stats.get("EMP", 0)) * 10
	max_humanity = humanity


## Install a piece at `loc` (Cyber locations; "" = Cyber.auto_loc, and where nothing fits, as for a
## printed stat block, Cyber.fallback_loc). Doesn't check that it fits: Campaign.install_block and
## Cyber.block do. At character creation Humanity Loss uses the flat value; afterwards it's rolled
## (p111). Each piece with HL lowers max Humanity by 2, Borgware by 4 (p230); a paired option is
## two pieces, each paid for (CPR core p.361). Returns the Humanity lost.
func install_cyberware(cyber_id: String, dice: Dice = null, at_creation: bool = false, loc: String = "") -> int:
	var d: Dictionary = Cyber.def(cyber_id)
	var choice := Cyber.choice_of(cyber_id)   # a spec: "skill_chip@handgun", "popup_ranged_weapon@heavy_pistol"
	var spec := cyber_id
	cyber_id = Cyber.base(cyber_id)
	var where := loc if loc != "" else Cyber.auto_loc(implants, cyber_id)
	var piece := {"id": cyber_id, "loc": where if where != "" else Cyber.fallback_loc(cyber_id)}
	if choice != "":
		piece["choice"] = choice
	var fx: Dictionary = d.get("fx", {})
	if fx.has("shield"):   # the Popup Shield's Bulletproof Shield (p.365), at full HP
		piece["hp"] = Cyber.shield_max(cyber_id)
	implants.append(piece)
	var pw := Cyber.popup_weapon(piece)
	if pw:   # a popup's weapon: carried, concealed, never the primary (p.365)
		weapons.append(pw)
	var reused := String(d.get("host", "")) == "chipware" and spec in chips_used
	if String(d.get("host", "")) == "chipware" and not reused:
		chips_used.append(spec)
	if fx.has("armor_sp") and (subdermal.is_empty() or int(fx["armor_sp"]) > (subdermal["body"] as ArmorPiece).max_sp):
		_set_subdermal(cyber_id)   # only the highest SP counts (p184)
	if fx.has("weapon"):   # built-in melee weapons (Wolvers, Big Knucks...): keep the hardest-hitting one
		var nw := _builtin_weapon(fx)
		var melee := weapons.filter(func(x): return x.is_melee() and x.popup == "")
		if melee.all(func(x): return x.dice() < nw.dice() or not x.builtin):
			for old in melee:
				weapons.erase(old)
			weapons.append(nw)
	var loss := 0
	if tracks_humanity and int(d.get("hl_flat", 0)) > 0:
		loss = int(d["hl_flat"]) if at_creation or dice == null else roll_hl(dice, d["hl_dice"])
		if reused:   # "Re-installing Chipware you've already used doesn't" cost Humanity (p.359)
			loss = 0
		humanity -= loss
		max_humanity -= 4 if d.get("borgware", false) else 2
		humanity = mini(humanity, max_humanity)
	return loss


static func _builtin_weapon(fx: Dictionary) -> Weapon:
	var w := Weapon.from_id(String(fx["weapon"]), String(fx.get("weapon_quality", "standard")))   # Vampyres: Excellent (p.363)
	w.builtin = true
	return w


func _set_subdermal(cyber_id: String) -> void:
	for loc in ["body", "head"]:
		var a := ArmorPiece.new()
		a.id = cyber_id
		a.name = Cyber.display(cyber_id)
		a.max_sp = int(Cyber.def(cyber_id)["fx"]["armor_sp"])
		a.sp = a.max_sp
		subdermal[loc] = a


## The installed ids, one per piece, in install order ("cybereye" twice for two Cybereyes).
func cyber_ids() -> Array[String]:
	var out: Array[String] = []
	for p in implants:
		out.append(String(p.id))
	return out


func has_cyberware(cyber_id: String) -> bool:
	return implants.any(func(p): return String(p.id) == cyber_id)


## Whether a piece of it is installed and working now: not knocked out by a Microwaver, and for a
## paired option both halves in (Cyber.active_ids).
func cyber_working(cyber_id: String) -> bool:
	return cyber_id in Cyber.active_ids(implants, cyber_off)


## The installed piece of `cyber_id` at `loc` ("" = the last one installed), {} if none. A spec
## ("skill_chip@handgun") picks the piece made for that choice.
func implant(cyber_id: String, loc: String = "") -> Dictionary:
	var ch := Cyber.choice_of(cyber_id)
	cyber_id = Cyber.base(cyber_id)
	for i in range(implants.size() - 1, -1, -1):
		var p: Dictionary = implants[i]
		if String(p.id) == cyber_id and (loc == "" or String(p.loc) == loc) and (ch == "" or String(p.get("choice", "")) == ch):
			return p
	return {}


# --- Activated chrome and popups (CPR core p.359-360, p.365) -----------------------------------

## The Popup Shield piece ({} if none installed).
func shield_piece() -> Dictionary:
	for p in implants:
		if Cyber.def(String(p.id)).get("fx", {}).has("shield"):
			return p
	return {}


## HP left on the Popup Shield's Bulletproof Shield (0 with none, or destroyed).
func shield_hp() -> int:
	var p := shield_piece()
	return int(p.get("hp", 0)) if not p.is_empty() else 0


## Wielding a shield with HP left: "considered to be in cover", and it can be put between them and
## an attack they see (CPR core p.183). The Popup Shield out of its arm (p.365).
func shield_up() -> bool:
	return shield_out and shield_hp() > 0


## Why the Popup Shield can't come out or go back now ("" if it can): "drawn or stowed without an
## Action, provided that the shield has more than 0 HP" (p.365); knocked out, the arm won't work it;
## one shield at a time (a Human Shield is one, p.184).
func shield_block() -> String:
	var p := shield_piece()
	if p.is_empty():
		return "No popup shield"
	if shield_hp() <= 0:
		return "Shield destroyed"
	if int(cyber_off.get(Cyber.key(p), 0)) > 0:
		return "Chrome offline"
	if not shield_out and grapple != null and grapple.holder == self and grapple.shield:
		return "Already holding a shield"
	return ""


## A piece nobody else has seen yet: a popup whose weapon hasn't been used, a Popup Shield still in
## the arm (concealed without a Check, CPR core p.360, p.365).
func concealed(piece: Dictionary) -> bool:
	var fx: Dictionary = Cyber.def(String(piece.id)).get("fx", {})
	if fx.has("shield"):
		return not shield_out
	if not (fx.has("popup") or fx.has("weapon_choice")):
		return false
	var k := Cyber.key(piece)
	return not weapons.any(func(w): return w.popup == k and w.revealed)


## Put the Popup Shield's hits on it: returns the HP left (0: destroyed, p.183).
func hit_shield(damage: int) -> int:
	var p := shield_piece()
	if p.is_empty():
		return 0
	p["hp"] = maxi(0, int(p.get("hp", 0)) - maxi(0, damage))
	return int(p.hp)


## Skin Weave and Subdermal Armor mend: each day of natural healing repairs 1 lost SP in both the
## body and the head location (CPR core p.364).
func mend_subdermal(days: int) -> void:
	for loc in subdermal:
		var a: ArmorPiece = subdermal[loc]
		if a:
			a.sp = mini(a.max_sp, a.sp + maxi(0, days))


## Take a piece out (a Medtech's harvest, CPR core p226: the piece doesn't survive it in this game,
## see Campaign.remove): the one at `loc`, or the last one installed. What it gave goes with it:
## subdermal armour, a built-in weapon (the next hardest-hitting one left takes its place), a STAT
## bonus (HP over the new maximum is lost). Humanity lost to it is not given back: the book returns
## Humanity only through therapy (p229-230). The cap it took (2, Borgware 4, p230) comes back so
## therapy can restore it (RULES-UNVERIFIED: p230 doesn't say whether the cap recalculates on
## removal; docs/rules/cyber-net.md). Returns false if it isn't installed.
func remove_cyberware(cyber_id: String, loc: String = "") -> bool:
	var piece := implant(cyber_id, loc)
	if piece.is_empty():
		return false
	implants.erase(piece)
	cyber_off.erase(Cyber.key(piece))
	var pk := Cyber.key(piece)
	weapons.assign(weapons.filter(func(w): return w.popup != pk))   # its popup weapon goes with it
	if shield_piece().is_empty():
		shield_out = false
	var d: Dictionary = Cyber.def(cyber_id)
	var fx: Dictionary = d.get("fx", {})
	if fx.has("armor_sp"):
		var best := ""
		for cid in cyber_ids():   # another subdermal piece still under the skin
			var ofx: Dictionary = Cyber.def(cid).get("fx", {})
			if ofx.has("armor_sp") and (best == "" or int(ofx.armor_sp) > int(Cyber.def(best).fx.armor_sp)):
				best = cid
		if best != String((subdermal.get("body") as ArmorPiece).id if subdermal.get("body") else ""):
			subdermal.clear()
			if best != "":
				_set_subdermal(best)
	if fx.has("weapon"):
		weapons.assign(weapons.filter(func(w): return not w.builtin or w.popup != ""))
		var bw: Weapon = null
		for cid in cyber_ids():
			var ofx: Dictionary = Cyber.def(cid).get("fx", {})
			if ofx.has("weapon"):
				var nw := _builtin_weapon(ofx)
				if bw == null or nw.dice() > bw.dice():
					bw = nw
		if bw:
			weapons.append(bw)
	if tracks_humanity and int(d.get("hl_flat", 0)) > 0:
		max_humanity += 4 if d.get("borgware", false) else 2
	hp = mini(hp, max_hp())
	return true


func lose_humanity(amount: int) -> void:
	if tracks_humanity:
		humanity -= amount


## Therapy etc. Capped by max Humanity (p230).
func regain_humanity(amount: int) -> void:
	if tracks_humanity:
		humanity = mini(max_humanity, humanity + amount)


## Cyberpsychosis tier from current EMP (p232): 0 none, 1 borderline (EMP 2), 2 dissociative
## (EMP 1), 3 cyberpsychosis (EMP 0), 4 extreme (Humanity below 0).
## The book gives no mechanics for these; what each tier does in play is a game design decision.
func psychosis_tier() -> int:
	if not tracks_humanity:
		return 0
	if humanity < 0:
		return 4
	return clampi(3 - raw_stat("EMP"), 0, 3)


## HOUSE-RULE (approved): chance per combat turn that a cyberpsychosis episode starts.
const EPISODE_CHANCE := {1: 0.05, 2: 0.15, 3: 0.30}  # psychosis tier → chance


func episode_chance() -> float:
	var tier := psychosis_tier()
	return 1.0 if tier >= 4 else float(EPISODE_CHANCE.get(tier, 0.0))


## Start-of-turn episode check. Returns true if this turn is under AI control.
## Episodes last 1-2 turns; Humanity below 0 means permanent loss of control.
func check_episode(dice: Dice) -> bool:
	if psychosis_turns > 0:
		psychosis_turns -= 1
		return true
	var chance := episode_chance()
	if chance >= 1.0:
		return true
	if chance > 0.0 and dice.rng.randf() < chance:
		psychosis_turns = dice.d(2) - 1  # this turn plus 0-1 more
		return true
	return false


static func roll_hl(dice: Dice, expr: String) -> int:
	match expr:
		"1d6/2": return ceili(dice.d(6) / 2.0)
		"1d6": return dice.roll(1, 6)
		"2d6": return dice.roll(2, 6)
		"4d6": return dice.roll(4, 6)
	return 0


# --- Senses and hazards (cyberware phase 2: CPR core p.359-363; gear p.352) ------------------------

## What can hurt a character through their senses or lungs, and what shrugs each off:
##   flash       dangerous flashes of light (a flashbang's Damaged Eye): Anti-Dazzle (p.360)
##   loud_noise  dangerously loud noises (a flashbang's Damaged Ear, the Shrieker): Level Damper (p.361),
##               Auto Level Dampening Ear Protectors (p.352)
##   inhaled     toxic gasses and fumes, anything that must be inhaled (a poison or biotoxin grenade's
##               cloud): Nasal Filters, Independent Air Supply (p.363), Anti-Smog Breathing Mask (p.352)
## Teargas isn't one: it works on "anyone with meat eyes" (p.347), so only two Cybereyes stop it.
const HAZARDS: Array[String] = ["flash", "loud_noise", "inhaled"]


## Immune to `hazard` (HAZARDS): working chrome whose fx "immune" lists it, or a carried utility
## whose does (the ear protectors, the anti-smog mask).
func immune_to(hazard: String) -> bool:
	for fx in _cyber_fx():
		if hazard in (fx.get("immune", []) as Array):
			return true
	for k in kit:
		if k != "" and Items.kind(k) == "utility" and hazard in (Items.fx(k).get("immune", []) as Array):
			return true
	return false


## Low Light / Infrared / UV, both halves working: penalties for darkness and "other intangible
## obscurement, like smoke, fog, etc." are 0; it can't see through anything that could be cover (p.360).
func sees_through_obscurement() -> bool:
	return _cyber_fx().any(func(fx): return fx.get("ignore_obscured", false))


## The Perception bonus for a Check that uses sight and/or hearing: Image Enhance +2 when it includes
## sight (p.360), Amplified Hearing +2 when it includes hearing (p.361). Two different pieces: a Check
## using both senses takes both (only installations of the same piece don't stack, p.111).
func perception_bonus(sight: bool, hearing: bool) -> int:
	var t := 0
	for fx in _cyber_fx():
		var pb: Dictionary = fx.get("perception_bonus", {})
		t += (int(pb.get("sight", 0)) if sight else 0) + (int(pb.get("hearing", 0)) if hearing else 0)
	return t


## The range in metres of working sense chrome with fx `key` ("radar_m": Radar/Sonar 50 m, p.363;
## "motion_sense_m": Tactile Boost 20 m, p.359), 0 without it.
func sense_range(key: String) -> float:
	var best := 0.0
	for fx in _cyber_fx():
		best = maxf(best, float(fx.get(key, 0)))
	return best


# --- Movement and downtime chrome (cyberware phases 3 and 4) -------------------------------------

## Grip Foot, both working: climbing costs no more than walking (p.366; climbing is 2 squares per
## square, p.169): Nav prices a ladder or fire escape like stairs for them.
func climbs_free() -> bool:
	return _cyber_fx().any(func(fx): return fx.get("climb_free", false))


## Jump Boosters, both working: jumping costs no more than walking (p.366; jumping is 2 squares per
## square, p.169): Nav prices a jump like a walk for them.
func jumps_free() -> bool:
	return _cyber_fx().any(func(fx): return fx.get("jump_free", false))


## Extra squares a Run gives (TurnState.run): Skate Foot's +6 m/yds "when using Run Action" (p.366),
## 3 squares of 2 m (p.126). 0 without a working pair.
func run_bonus_squares() -> int:
	return int(sense_range("run_bonus_m") / TurnState.SQUARE_M)


## The Grapple Hand's line, 30 m (p.365); 0 without a working one (Encounter.grapple_targets).
func grapple_range_m() -> float:
	return sense_range("grapple_m")


## HP healed by `days` of rest after stabilization: BODY a day (p.223), BODY x 2 with Enhanced
## Antibodies (p.362). Campaign.rest; Linear Frames and Grafted Muscle count (raw_stat).
func rest_heal(days: int) -> int:
	var mult := 1
	for fx in _cyber_fx():
		mult = maxi(mult, int(fx.get("rest_heal_mult", 1)))
	return raw_stat("BODY") * mult * days


func cyber_fx_sum(key: String) -> int:
	var t := 0
	for fx in _cyber_fx():
		t += int(fx.get(key, 0))
	return t


## Effects of the cyberware that works now: one per id (benefits don't stack, p111), none from a
## piece knocked out (Microwaver) or a paired option missing its other half (Cyber.active_ids).
func _cyber_fx() -> Array:
	var out := []
	for cid in Cyber.active_ids(implants, cyber_off):
		var fx: Dictionary = Cyber.def(cid).get("fx", {})
		if not fx.is_empty():
			out.append(fx)
	out.append_array(drug_fx)   # drugs in the system (Black Lace: shrug off serious wounds, p.358)
	return out


# --- Injuries ------------------------------------------------------------

func has_injury(injury_id: String) -> bool:
	return injuries.any(func(i): return i["id"] == injury_id)


func head_multiplier() -> int:
	var m := 2
	for i in injuries:
		m = maxi(m, int(i["fx"].get("head_mult", 2)))
	return m


## Roll and apply a Critical Injury: reroll until one the target doesn't have (p220), 5 bonus HP damage.
## Returns the entry, or {} if every entry in the table is already suffered.
func suffer_crit(dice: Dice, location: String) -> Dictionary:
	var table := RulesDB.crit_table(location)
	var available := table.values().filter(func(e): return not has_injury(e["id"]))
	if available.is_empty():
		return {}
	var entry: Dictionary
	while true:
		entry = table[str(dice.roll(2, 6))]
		if not has_injury(entry["id"]):
			break
	return add_injury(entry, location)


## `bonus_damage` false for injuries a weapon inflicts without the Bonus Damage (Shrieker, teargas).
func add_injury(entry: Dictionary, location: String, bonus_damage := true) -> Dictionary:
	var inj := entry.duplicate(true)
	inj["location"] = location
	injuries.append(inj)
	if inj["fx"].get("no_action_next_turn", false):
		skip_next_action = true
	var dsp_up := int(inj["fx"].get("dsp", 0))
	base_dsp += dsp_up
	dsp += dsp_up
	if bonus_damage:
		hp -= int(RulesDB.load_json("critical_injuries.json")["bonus_damage"])
	return inj


func _fx_sum(key: String) -> int:
	var t := 0
	for i in injuries:
		t += int(i["fx"].get(key, 0))
	return t


func _fx_any(key: String) -> bool:
	return injuries.any(func(i): return i["fx"].get(key, false))


# --- Death & stabilization ----------------------------------------------

## Roll a Death Save (p222): d10 + current penalty must be under BODY; natural 10 always fails.
## Each roll raises the penalty by 1. Returns true if the character survives.
func death_save(dice: Dice) -> bool:
	var r := dice.d(10)
	var ok := r != 10 and r + dsp < death_save_target()
	dsp += 1
	if not ok:
		dead = true
	return ok


## Chance this character survives their next Death Save.
func death_save_chance() -> float:
	var ok := 0
	for r in range(1, 10):
		if r + dsp < death_save_target():
			ok += 1
	return ok / 10.0


func stabilization_dv() -> int:
	match wound_state():
		Wound.LIGHT: return 10
		Wound.SERIOUS: return 13
		Wound.MORTAL: return 15
	return 0


## Mark as stabilized (p222-223). Mortally Wounded → 1 HP and Unconscious; penalty resets to base.
func stabilize() -> void:
	if wound_state() == Wound.MORTAL:
		hp = 1
		unconscious = true
		wake_in = 20   # "Unconscious for 1 minute" (p223): 20 rounds of 3 s
	dsp = base_dsp


# --- Save / load (campaign state between gigs) ---------------------------------

static func _armor_dict(a: ArmorPiece) -> Variant:
	return {"id": a.id, "sp": a.sp, "upgraded": a.upgraded, "work": a.repair_work} if a else null


static func _armor_from(d: Variant) -> ArmorPiece:
	if d == null:
		return null
	var a := ArmorPiece.from_id(String(d.id))
	a.upgraded = bool(d.get("upgraded", false))
	if a.upgraded:
		a.max_sp += 1
	a.sp = int(d.sp)
	a.repair_work = int(d.get("work", 0))
	return a


func to_dict() -> Dictionary:
	var arm := {}
	for loc in armor:
		arm[loc] = _armor_dict(armor[loc])
	var sub := {}
	for loc in subdermal:
		sub[loc] = _armor_dict(subdermal[loc])
	return {"id": id, "name": display_name, "real_name": real_name, "team": team, "faction": faction, "stats": stats, "skills": skills, "hp": hp, "armor": arm,
		"subdermal": sub, "injuries": injuries, "base_dsp": base_dsp, "dsp": dsp, "dead": dead, "unconscious": unconscious,
		"weapons": weapons.map(func(w): return {"id": w.id(), "ammo": w.ammo, "builtin": w.builtin, "quality": w.quality, "popup": w.popup}), "role": role,
		"role_rank": role_rank, "awareness": awareness, "tracks_humanity": tracks_humanity, "humanity": humanity,
		"max_humanity": max_humanity, "cyberware": implants, "ip": ip, "look_seed": look_seed, "perks": perks, "medicine": medicine, "maker": maker, "downtime": downtime, "deck": deck, "programs": programs,
		"deck_hardware": deck_hardware, "backup": backup, "kit": kit, "addictions": addictions, "clean_since": clean_since, "reputation": reputation, "chips_used": chips_used}


static func from_dict(d: Dictionary) -> Combatant:
	var st := {}
	for k in d.stats:
		st[k] = int(d.stats[k])
	var sk := {}
	for k in d.skills:
		sk[k] = int(d.skills[k])
	var c := Combatant.new(String(d.name), st, sk)
	c.id = String(d.id)
	c.real_name = String(d.get("real_name", ""))
	c.team = int(d.team)
	c.faction = String(d.get("faction", "crew"))
	c.hp = int(d.hp)
	for loc in d.armor:
		c.armor[loc] = _armor_from(d.armor[loc])
	for loc in d.get("subdermal", {}):
		c.subdermal[loc] = _armor_from(d.subdermal[loc])
	for inj in d.injuries:
		c.injuries.append(inj)
	c.base_dsp = int(d.base_dsp)
	c.dsp = int(d.dsp)
	c.dead = bool(d.dead)
	c.unconscious = bool(d.unconscious)
	var popups := {}   # popup weapons are rebuilt from their pieces below (Cyber.popup_weapon)
	for wd in d.weapons:
		if String(wd.get("popup", "")) != "":
			popups[String(wd.popup)] = int(wd.ammo)
			continue
		var w := Weapon.from_id(String(wd.id), String(wd.get("quality", "standard")))
		w.ammo = int(wd.ammo)
		w.builtin = bool(wd.get("builtin", false))
		c.weapons.append(w)
	c.role = String(d.role)
	c.role_rank = int(d.role_rank)
	for k in d.awareness:   # JSON numbers come back as floats
		c.awareness[String(k)] = int(d.awareness[k])
	c.tracks_humanity = bool(d.tracks_humanity)
	c.humanity = int(d.humanity)
	c.max_humanity = int(d.max_humanity)
	var flat: Array = []   # bare ids (a hand-written dict, an older save the migration missed): placed by Cyber
	for cw in d.get("cyberware", []):
		if cw is Dictionary and Cyber.db().has(String(cw.get("id", ""))):
			var piece := {"id": String(cw.id), "loc": String(cw.get("loc", Cyber.fallback_loc(String(cw.id))))}
			for k in ["choice", "hp"]:   # what it was made for (Cyber.choices); a Popup Shield's HP
				if cw.has(k):
					piece[k] = String(cw[k]) if k == "choice" else int(cw[k])
			c.implants.append(piece)
		elif cw is String:
			flat.append(cw)
	if not flat.is_empty():
		c.implants.append_array(Cyber.place_ids(flat))
	for p in c.implants:   # popup weapons from the pieces holding them
		var pw := Cyber.popup_weapon(p)
		if pw:
			pw.ammo = int(popups.get(pw.popup, pw.mag()))
			c.weapons.append(pw)
	for s in d.get("chips_used", []):
		c.chips_used.append(String(s))
	c.ip = int(d.get("ip", 0))
	c.look_seed = int(d.get("look_seed", -1))
	c.downtime = String(d.get("downtime", "recover"))
	var kd: Array = d.get("kit", ["", ""])
	for i in mini(2, kd.size()):
		c.kit[i] = String(kd[i])
	for a in d.get("addictions", []):
		c.addictions.append(String(a))
	for k in d.get("clean_since", {}):
		c.clean_since[String(k)] = int(d.clean_since[k])
	c.reputation = int(d.get("reputation", 0))
	# A dict from before the deck model (SaveMigrations v21 gives saves theirs): a Netrunner gets the
	# Role's starting deck (Deck.give_starting, CPR core p.103).
	if String(d.role) == "netrunner" and not d.has("deck"):
		Deck.give_starting(c)
	else:
		c.deck = String(d.get("deck", ""))
		for pg in d.get("programs", []):
			if not Deck.program(String(pg)).is_empty():
				c.programs.append(String(pg))
	for h in d.get("deck_hardware", []):
		if not Deck.hardware(String(h)).is_empty():
			c.deck_hardware.append(String(h))
	for pg in d.get("backup", []):
		if not Deck.program(String(pg)).is_empty():
			c.backup.append(String(pg))
	for k in d.get("maker", {}):
		c.maker[String(k)] = int(d.maker[k])
	for k in d.get("medicine", {}):
		c.medicine[String(k)] = int(d.medicine[k])
	for pk in d.get("perks", []):
		c.perks.append(String(pk))
	return c


## IP to raise a skill to its next level (p411): 20 x the new level, doubled for (x2) skills.
func skill_raise_cost(skill_id: String) -> int:
	var nxt := int(skills.get(skill_id, 0)) + 1
	return nxt * (40 if RulesDB.skill(skill_id).get("x2", false) else 20)


## Spend IP on the next level of a skill (max 10). Returns false if it can't.
func raise_skill(skill_id: String) -> bool:
	var cost := skill_raise_cost(skill_id)
	if int(skills.get(skill_id, 0)) >= 10 or ip < cost:
		return false
	ip -= cost
	skills[skill_id] = int(skills.get(skill_id, 0)) + 1
	return true