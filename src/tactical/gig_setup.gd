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
	return s
