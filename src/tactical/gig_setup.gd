class_name GigSetup
extends RefCounted
## The start of a campaign gig, without the 3D: the active gig's map, its dice and its Encounter,
## built from Campaign.scene_opts, encounter_opts and objective_for with the crew who can go.
## The greybox's campaign path (new_gig) and the headless soak (SoakDriver) both build gigs here,
## so what the soak plays is what the player gets. The dev gig builder's gigs (CustomGig) come
## through here too: their overrides ride in the gig dict (Campaign.scene_opts / encounter_opts).

var map: TacMap
var dice: Dice
var enc: Encounter


## `kit`: review renders pack these into every crew member's kit slots first (greybox --kit).
## `extra`: Encounter.setup options laid over the gig's own (greybox --complication).
static func for_campaign(camp: Campaign, kit: PackedStringArray = PackedStringArray(), extra: Dictionary = {}) -> GigSetup:
	var g := camp.active_gig
	var s := GigSetup.new()
	s.map = SceneGen.generate(int(g.seed), String(g.scene), Campaign.scene_opts(g))
	if String(g.get("profile", "")) != "":
		s.map.params["scene"] = "neighborhood"
	s.dice = Dice.new(int(g.seed) + 1)
	camp.check_kits()   # only what safehouse storage still holds goes along
	var crew := camp.gig_crew(g)   # everyone fit to go, or the ones a dev gig names (CustomGig)
	for c in crew:
		for i in mini(2, kit.size()):
			c.kit[i] = kit[i]
	var eo := Campaign.encounter_opts(g)
	eo.merge(extra, true)
	s.enc = Encounter.setup(s.map, s.dice, crew, Campaign.objective_for(g), eo)
	name_focus(s.enc, g)
	return s


## The gig's focus item (MissionBuilder, SPM p.73) names what the objective is about: its marker
## and HUD lines read objective.item {label, short, marker} (Objective.item_marker). Its Mission
## Types row's id rides along as objective.mission (plant words its order by it).
static func name_focus(e: Encounter, gig: Dictionary) -> void:
	var mi: Variant = gig.get("mission")
	if mi is Dictionary and String(mi.get("id", "")) != "":
		e.objective["mission"] = String(mi.id)
	var f: Variant = gig.get("focus")
	if f is Dictionary and not (f as Dictionary).is_empty():
		e.objective["item"] = {"label": String(f.get("label", "")), "short": String(f.get("short", "")), "marker": String(f.get("marker", ""))}
