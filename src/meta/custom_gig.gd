class_name CustomGig
extends RefCounted
## DEV ONLY: the custom gig builder (the Fixer Network's CUSTOM GIG (DEV) card, shown in developer
## mode, GameSettings.dev_mode). A form sets every parameter a campaign gig has; build() turns it
## into a gig dict that Campaign.accept_custom starts like a board offer (travel, GigSetup's map and
## Encounter, Campaign.resolve's pay, IP and injuries), marked `dev` in the save and the debrief.
##
## The form speaks the greybox's dev flags (--district --location --setpiece --variant --scene
## --profile --site --objective --faction --security --complication --seed), plus flags of its own
## for the rest (--code --utility --pay --deploy --basements --tower --band --mood, and --gig-crew=<names>: the base
## view's --crew picks a crew card): from_flags / to_flags convert, so a gig built on the card and
## one launched from the command line are the same gig (a dev launch's flags prefill the card).
##
## Every field defaults to auto ("" / 0): a partly filled form still works. What is left auto is
## drawn from its own Dice seeded from the gig's seed, so one seed always resolves the same way.

## Form fields and their auto values. district / location: "none" for no district / canon place.
## code: "" from the location (Campaign.codes_for), else the printed form "6:ncpd,hardened heavy"
## (SecurityCode.parse). utility: auto (the campaign's 1-in-3 roll of the Utility Code), none,
## roll (the code rolled every time), or the utilities out ("power", "power,water", ...).
## complication: auto (the Oracle by security level, Complication.likelihood), none, random (forced, its roll rolled), or
## <tier>[:<roll>] / <roll> as greybox --complication. deploy: near | far. basements: on | off
## (ordinary target buildings whose site has below_grade). tower: a tower gig (TowerGen, a band of a
## tall building: docs/world/towers.md): a tower's short id or location id ("raven", "the_glen_24"),
## or "any" (one drawn); "" plays a tower's location as its street-level building, as the board's
## ordinary offers do. band: the tower's band ("" its sky band, the only one stage 1a builds).
## mood: a tower gig's weather (Atmosphere: clear, acid_rain, dust, smog, drizzle; "" drawn from the
## seed and district as a board gig's is). crew: names; [] everyone fit to go. The Mission Builder sheet's rows (SPM p.102; MissionBuilder): client
## "<zone>/<id>" (People of Night City), mission (a Mission Types id; its objective is used when
## objective is auto), item "<category>/<id>" (the focus: Mission Items; not "focus", which the
## base view's --focus flag already means), payment (eb, information, favour,
## favour:treatment, favour:market, goods); "" rolls each. The twist has no field yet (null).
const FIELDS := {"district": "", "location": "", "setpiece": "", "variant": "", "scene": "", "profile": "",
	"site": "", "objective": "", "faction": "", "security": 0, "code": "", "utility": "auto",
	"complication": "auto", "pay": 0, "seed": 0, "deploy": "", "basements": "", "tower": "", "band": "", "mood": "", "crew": [],
	"client": "", "mission": "", "item": "", "payment": ""}
const NONE := "none"
const STRING_FLAGS := ["district", "location", "setpiece", "variant", "scene", "profile", "site", "objective",
	"faction", "code", "utility", "complication", "deploy", "basements", "tower", "band", "mood", "client", "mission", "item", "payment"]
const INT_FLAGS := ["security", "pay", "seed"]
const UTILITY_MODES := ["auto", "none", "roll"]
## Scenes where an empty profile takes the district's own streets (as greybox --district does).
const DISTRICT_SCENES := ["skirmish", "neighborhood", "street_block", "city_district"]


static func defaults() -> Dictionary:
	return FIELDS.duplicate(true)


## A form from command-line flags (OS.get_cmdline_user_args()); flags it doesn't know are ignored.
static func from_flags(args: PackedStringArray) -> Dictionary:
	var f := defaults()
	for a in args:
		var at := a.find("=")
		if not a.begins_with("--") or at < 0:
			continue
		var k := a.substr(2, at - 2)
		var v := a.substr(at + 1)
		if k in STRING_FLAGS:
			f[k] = v
		elif k in INT_FLAGS:
			f[k] = int(v)
		elif k == "gig-crew":
			f.crew = Array(v.split(",", false))
	return f


## The flags that build the same gig (auto fields left out).
static func to_flags(form: Dictionary) -> PackedStringArray:
	var f := defaults()
	f.merge(form, true)
	var out := PackedStringArray()
	for k in STRING_FLAGS:
		if String(f[k]) != String(FIELDS[k]):
			out.append("--%s=%s" % [k, String(f[k])])
	for k in INT_FLAGS:
		if int(f[k]) != 0:
			out.append("--%s=%d" % [k, int(f[k])])
	if not (f.crew as Array).is_empty():
		out.append("--gig-crew=" + ",".join(PackedStringArray(f.crew)))
	return out


## greybox --complication's form ("<tier>:<roll>" or "<roll>"), and the builder's "random" and a
## bare tier: Encounter.setup's forced complication ({tier?, roll?}; roll 0 is rolled).
static func parse_complication(s: String) -> Dictionary:
	if s == "random":
		return {"roll": 0}
	var parts := s.split(":")
	if parts.size() > 1:
		return {"tier": parts[0], "roll": int(parts[1])}
	if s.is_valid_int():
		return {"roll": int(s)}
	return {"tier": s, "roll": 0}


## Districts a gig can be in (city.json, less Campaign.NO_GIGS), in data order.
static func districts() -> Array:
	return World.districts().keys().filter(func(d): return not String(d) in Campaign.NO_GIGS)


## Canon locations the card offers (any World location outside Campaign.NO_GIGS, in `did` if
## given, whose name or id contains `query`), sorted by name.
static func locations(did := "", query := "") -> Array:
	var q := query.strip_edges().to_lower()
	var all := World.locations()
	var out: Array = []
	for id in all:
		var l: Dictionary = all[id]
		if not Campaign.offered_at(String(id)) or (did != "" and did != NONE and String(l.get("district", "")) != did):
			continue
		if q != "" and not String(l.get("name", "")).to_lower().contains(q) and not String(id).contains(q):
			continue
		out.append(String(id))
	out.sort_custom(func(a, b): return String(all[a].get("name", a)) < String(all[b].get("name", b)))
	return out


## Gig kinds (gigs.json templates) by objective (Campaign.OBJECTIVES), and back.
static func kind_of(objective: String) -> String:
	if Campaign.OBJECTIVES.has(objective):
		return objective
	for k in Campaign.OBJECTIVES:
		if String(Campaign.OBJECTIVES[k]) == objective:
			return String(k)
	return ""


## Can the gig's target building be forced to have basements or none (BasementGen.ordinary: an
## ordinary map whose site has below_grade; a site left to the scene might)? A set piece's
## basements are its recipe's.
static func basements_apply(gig: Dictionary) -> bool:
	if String(gig.get("setpiece", "")) != "" or not String(gig.get("scene", "")) in BasementGen.ORDINARY_SCENES:
		return false
	var site := String(gig.get("site", ""))
	return site == "" or not (RulesDB.gen("sites.json").get(site, {}) as Dictionary).get("below_grade", {}).is_empty()


## The campaign gig dict for `form`. `camp` draws the seed when the form leaves it auto (else 1).
## The gig carries `dev: true` and `form`: the form with its seed filled in, which builds it again.
static func build(form: Dictionary, camp: Campaign = null) -> Dictionary:
	var f := defaults()
	f.merge(form, true)
	var seed := int(f.seed)
	if seed <= 0:
		seed = camp.dice.rng.randi_range(1, 99999) if camp != null and camp.dice != null else 1
	f.seed = seed
	var d := Dice.new(seed * 7919 + 101)   # the random fields' own stream: the map keeps `seed`
	var g := RulesDB.gen("gigs.json")
	var kind := kind_of(String(f.objective))
	if kind == "" and MissionBuilder.enabled(MissionBuilder.mission_def(String(f.mission))):   # the mission type names the objective
		kind = MissionBuilder.kind_of(MissionBuilder.mission_def(String(f.mission)))
	var direct := String(f.scene) != "" or String(f.profile) != "" or String(f.site) != ""
	var sp := String(f.setpiece)
	# A tower gig (the tower field, or the tower_top scene picked directly): its tower's band.
	var tw := String(f.tower)
	if tw == "" and String(f.scene) == "tower_top":
		tw = "any"
	if tw != "" and tw != NONE:
		return _tower_build(f, d, g, kind, tw)
	# Where: a canon place (given, one of the set piece's, or one in the district), else the scene direct.
	var lid := String(f.location)
	if lid == "" and sp != "":
		var own: Array = (SetPieces.get_def(sp).get("locations", {}) as Dictionary).keys().filter(func(id): return Campaign.offered_at(String(id)))
		lid = String(_pick(d, own)) if not own.is_empty() else NONE
	if lid == "" and not direct:
		var did0 := String(f.district) if String(f.district) != NONE else ""
		var pool := locations(did0)
		var fits := pool.filter(func(id): return kind == "" or _kinds_at(World.location(String(id))).has(kind))
		lid = String(_pick(d, fits if not fits.is_empty() else pool)) if not pool.is_empty() else NONE
	if lid == NONE or not World.locations().has(lid):
		lid = ""
	var l := World.location(lid) if lid != "" else {}
	var gig := {"id": "dev", "dev": true, "seed": seed, "fixer": "DEV BUILDER", "fixer_id": "", "hook": ""}
	if lid != "" and direct:   # a scene, profile or site set directly plays the place as that, not as itself
		gig["location"] = lid
	elif lid != "":
		gig.merge(Campaign._place_at(lid), true)
	for k in ["scene", "profile", "site"]:
		if String(f[k]) != "":
			gig[k] = String(f[k])
	if sp != "":
		gig["setpiece"] = sp
	if String(f.variant) != "":
		gig["variant"] = String(f.variant)
	var did := String(f.district)
	if did == "":
		did = String(l.get("district", "")) if lid != "" else String(_pick(d, districts()))
	if did == NONE:
		did = ""
	if String(gig.get("scene", "")) == "":
		gig["scene"] = "neighborhood" if String(gig.get("profile", "")) != "" or (String(gig.get("site", "")) == "" and did != "") \
			else ("lone_building" if String(gig.get("site", "")) != "" else "skirmish")
	if String(gig.get("profile", "")) == "" and did != "" and String(gig.get("setpiece", "")) == "" and String(gig.scene) in DISTRICT_SCENES:
		gig["profile"] = String(World.district(did).get("profile", ""))   # the district's own streets
	if kind == "":
		var ks: Array = _kinds_at(l).keys() if lid != "" else []
		kind = String(_pick(d, ks)) if not ks.is_empty() else String((_pick(d, g.templates) as Dictionary).kind)
	gig["kind"] = kind
	# Who and how hard.
	var fid := String(f.faction)
	if fid == "":
		if lid != "":
			var tmp := Campaign.new()   # Campaign._target_for draws on its dice: lend it ours
			tmp.dice = d
			fid = tmp._target_for(l, kind)
		elif sp != "":
			fid = String(SetPieces.get_def(sp).get("faction", ""))
		if fid == "":
			var ids := World.targets_for(kind)
			fid = String(_pick(d, ids)) if not ids.is_empty() else World.DEFAULT_OPFOR
	gig["faction"] = fid
	var code := SecurityCode.normalise(String(f.code)) if String(f.code) != "" else {}
	var sec := int(f.security)
	if sec < 1 or sec > 3:
		var rng: Array = Campaign.location_levels(l, fid) if lid != "" else []
		if rng.size() >= 2:
			sec = d.rng.randi_range(int(rng[0]), int(rng[1]))
		elif not code.is_empty():
			sec = SecurityCode.level(code)
		else:
			sec = d.d(3)
	gig["security"] = sec
	gig.merge(Campaign.codes_for(gig, did), true)
	if not code.is_empty():
		gig["security_code"] = code
	gig["pay"] = int(g.pay[str(sec)])
	_mission_steps(f, d, gig)
	# The encounter's dials.
	var ut := String(f.utility)
	if ut != "auto" and ut != "":
		gig["utility"] = ut
	var cx := String(f.complication)
	if cx == NONE:
		gig["complication"] = NONE
	elif cx != "auto" and cx != "":
		gig["complication"] = parse_complication(cx)
	if String(f.deploy) in ["near", "far"]:
		gig["deploy"] = String(f.deploy)
	if String(f.basements) in ["on", "off"]:
		gig["basement_storeys"] = 2 if String(f.basements) == "on" else 0   # BasementGen.ordinary clamps to the site's most
	if not (f.crew as Array).is_empty():
		gig["crew"] = (f.crew as Array).map(func(n): return String(n))
	var label := kind.capitalize()
	for t in g.templates:
		if String(t.kind) == kind:
			label = String(t.get("label", label))
	label = String((gig.get("mission", {}) as Dictionary).get("label", label))
	gig["title"] = "DEV · %s: %s" % [label, Campaign.place_name(gig)]
	var pitch := MissionBuilder.pitch(gig, World.display_name(fid))
	gig["blurb"] = "Custom gig from the dev builder.%s Flags: %s" % [(" " + pitch) if pitch != "" else "", " ".join(to_flags(f))]
	gig["form"] = f
	return gig


## The Mission Builder's steps (MissionBuilder.run, SPM p.28) on a dev gig, on the form's dice `d`:
## the form's client, mission, focus and payment where set, the rest rolled; Pay (eb), when set,
## is the eb part of the payment. Goods come from the fixer's staples (no campaign's market: one
## form builds the same gig in any campaign).
static func _mission_steps(f: Dictionary, d: Dice, gig: Dictionary) -> void:
	for k in MissionBuilder.STEPS:
		gig.erase(k)
	MissionBuilder.run(d, gig, {"client": String(f.client), "mission": String(f.mission), "focus": String(f.item),
		"payment": String(f.payment), "goods": func(v: int) -> Array: return goods(v)})
	if int(f.pay) > 0:
		gig["pay"] = int(f.pay)
		gig.payment["eb"] = int(f.pay)


## Storage keys a dev gig's goods payment worth up to `value` may be: anything the game sells
## (NightMarket.on_sale) worth at least a third of it (Campaign.goods_pool's rule, without a
## campaign's market).
static func goods(value: int) -> Array:
	var keys: Array = []
	for id in RulesDB.load_json("weapons.json")["weapons"]:
		keys.append("weapon/%s" % id)
	for id in RulesDB.load_json("armor.json")["armor"]:
		keys.append("armor/%s" % id)
	for id in Campaign.RIPPERDOC:
		keys.append("cyberware/%s" % id)
	keys.append_array(Items.all())
	var out: Array = []
	for k in keys:
		if not NightMarket.on_sale(String(k)):
			continue
		var p := Items.price(String(k))
		if p <= value and p * 3 >= value and Items.is_stored(String(k)):
			out.append(String(k))
	out.sort()
	return out


## A tower gig from the form (build: f.tower set): the named tower ("any": one drawn on `d`, in the
## form's district when it has one), its band (f.band, else the sky band), a kind the band hosts (the
## form's objective if the band has it, else drawn), the rest as build() fills a gig.
static func _tower_build(f: Dictionary, d: Dice, g: Dictionary, kind: String, tw: String) -> Dictionary:
	var lid := World.tower_location(tw)
	if lid == "":
		var ids: Array = World.towers().keys().filter(func(id): return Campaign.offered_at(String(id)))
		ids.sort()
		var did0 := String(f.district)
		var in_d := ids.filter(func(id): return String(World.location(String(id)).get("district", "")) == did0)
		lid = String(_pick(d, in_d if not in_d.is_empty() else ids))
	var t := World.tower(lid)
	var bands: Dictionary = t.get("bands", {})
	var bid := String(f.band) if String(f.band) != "" else TowerGen.DEFAULT_BAND
	if not bands.has(bid):
		bid = String(bands.keys()[0])
	var b: Dictionary = bands[bid]
	var kinds: Array = b.get("gigs", [])
	if kind == "" or not kind in kinds:
		kind = String(_pick(d, kinds)) if not kinds.is_empty() else "data_theft"
	var tmp := Campaign.new()   # Campaign.tower_gig draws on its dice: lend it ours
	tmp.dice = d
	var gig := tmp.tower_gig(g, lid, kind, bid)
	gig.merge({"id": "dev", "dev": true, "seed": int(f.seed), "fixer": "DEV BUILDER", "fixer_id": "", "hook": ""}, true)
	gig["sky"] = Campaign.tower_sky(int(f.seed))   # the form's seed decides day or night, as a board gig's does
	gig["mood"] = String(f.mood) if Atmosphere.has(String(f.mood)) else Campaign.tower_mood(int(f.seed), String(gig.get("district", "")))   # and its weather
	if String(f.faction) != "":
		gig["faction"] = String(f.faction)
	var sec := int(f.security)
	if sec >= 1 and sec <= 3:
		gig["security"] = sec
	gig.merge(Campaign.codes_for(gig, String(gig.get("district", ""))), true)
	if String(f.code) != "":
		var code := SecurityCode.normalise(String(f.code))
		if not code.is_empty():
			gig["security_code"] = code
	gig["pay"] = int((gig.get("payment", {}) as Dictionary).get("base", gig.get("pay", 0)))
	_mission_steps(f, d, gig)   # the form's builder fields over the tower job's
	_dials(f, gig)
	var floors := "%d-%d" % [int(b.storeys[0]), int(b.storeys[1])]
	gig["title"] = "DEV · %s: %s %s" % [String(gig.mission.get("label", String(gig.title).get_slice(":", 0))), String(World.location(lid).get("name", lid)), floors]
	gig["blurb"] = "Custom tower gig from the dev builder (%s, floors %s). Flags: %s" % [String(t.get("name", lid)), floors, " ".join(to_flags(f))]
	gig["form"] = f
	return gig


## The encounter's dials from the form (utilities, complication, deploy, crew) onto `gig`.
static func _dials(f: Dictionary, gig: Dictionary) -> void:
	var ut := String(f.utility)
	if ut != "auto" and ut != "":
		gig["utility"] = ut
	var cx := String(f.complication)
	if cx == NONE:
		gig["complication"] = NONE
	elif cx != "auto" and cx != "":
		gig["complication"] = parse_complication(cx)
	if String(f.deploy) in ["near", "far"]:
		gig["deploy"] = String(f.deploy)
	if not (f.crew as Array).is_empty():
		gig["crew"] = (f.crew as Array).map(func(n): return String(n))


## The gig kinds a location's hooks and `gigs` name, as a set.
static func _kinds_at(l: Dictionary) -> Dictionary:
	var out := {}
	for k in l.get("gigs", []):
		out[String(k)] = true
	for h in l.get("hooks", []):
		for k in h.get("gigs", []):
			out[String(k)] = true
	return out


static func _pick(d: Dice, a: Array) -> Variant:
	return a[d.d(a.size()) - 1] if not a.is_empty() else ""
