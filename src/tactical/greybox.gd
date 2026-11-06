extends Node
## Playable tactical view: a generated scene in 3D, driven by Encounter.
## M4 first pass (M3 playtest verdicts): pixel-art render (low-res SubViewport + palette/dither
## post), night lighting with neon signs, street lamps and room lights, bloom; fog of war (building
## interiors appear only once the squad sees them; guards are drawn only while in sight); a
## Baldur's Gate 3 style HUD (view/hud.gd).
##
## Controls
##   WASD / arrows   pan          Mouse wheel   zoom
##   Q / E (hold)    rotate (eased)             Middle-drag   rotate freely        H  controls hint
##   PageUp/PageDown change the floor you're viewing (floors above open up around the focus)
##   Right click     move (path preview while hovering the move grid)
##   Left click      attack the enemy under the cursor or its turn-order portrait; with a tool armed
##                   (F / the bar), use it on its target; Shift+left: shoot the cover in the way.
##                   Left on empty ground or a friendly does nothing. NET: either button picks a node.
##   Esc             cancel the armed attack / tool    B  interact (doors, devices, bodies: not a click)
##                   (mapping: ClickIntent)
##   Hover an enemy  line of fire / swing / throw arc and the hit chance (AimPreview)
##   F attack (again: next mode)   Tab next weapon   R reload   J jack in   Space end turn
##   Alt (hold) inspect, crew roster, enemy outlines    F4 cyberspace style    N peek out of the NET
##   C cutaway auto / all seen rooms / off    Z guard sight lines near your move / always / off
##   F1 new gig    F2 look settings    F3 toggle fog of war    K collapse / show the combat log
## Screenshot mode:  -- --shot=path.png [--scene=x] [--profile=y] [--district=z] [--seed=n] [--pixel=3]
##   [--levels=0] [--dither=0.5] [--outline=0.4] [--bloom=0.8] [--contrast=1.1] [--ortho=1]
##   [--fog=0] [--zoom=24] [--yaw=45] [--lights=1] [--hover=x,y] [--promo=1] [--cut=auto|all|off]
##   [--stage=attack] [--arm=brawl|grenade|<attack mode>] [--portrait=1] [--alt=1] [--near=n] [--help=1]
##   [--exposure=1 --gamma=1 --ambient=1 --lights=1 --spill=1 (lighting review: grade exposure and power curve, ambient, lamp and baked-spill scales)]
##   [--hurt=0.6 (the nearest foes roused and hurt)] [--logt=0..1 (the log slide held there)]

const FH := 1.6           # floor height in squares (3.2 m)
const POST_SHADER := preload("res://src/tactical/view/post.gdshader")
const SKY_SHADER := preload("res://src/tactical/view/sky.gdshader")
## The tactical view's one grade (owner light review, round 4: "one look overall", darker than the
## round-3 renders at 55%): exposure, then a power curve in the post shader that deepens the darks
## and keeps lights and trim bright. Set once, for every scene; --exposure and --gamma scale them.
const GRADE_EXPOSURE := 0.9
const GRADE_GAMMA := 1.2
## A key light on units only (render layer 2: CharModel), so crew and foes stand out from a dark
## world through their own lighting. No ring or glow under them (owner rule). Round 5 (owner: whole
## outfits came out white or neon at 5.0): a modest lift; trims and silhouettes carry the contrast.
const UNIT_KEY := 2.0

var m: TacMap
var enc: Encounter
var dice: Dice
var view_floor := 0
var cutaway := true
var cut_all := false   ## C cycles: AUTO (buildings open only with crew inside or pointed into) → ALL SEEN → OFF
var sight_mode := 0    ## Z cycles guards' sight lines: 0 near the hovered move / hovered guard, 1 always, 2 off
var fog_on := true
var mode := Attack.Mode.SINGLE
var stage := "main"         ## action bar: "main" or "attack" (weapon tabs + the drawn weapon's attacks)
var atk_mode := "single"    ## the armed attack (Encounter.attack_modes ids, or "brawl")
var cover_mode := false
var move_opts := {}
var hover := Vector3i(-1, -1, -1)
var mouse := Vector2.ZERO
var _security_flag := false   # --security= given: it overrides a set piece's own level
var gig := {"scene": "skirmish", "profile": "", "seed": 11, "security": 1, "faction": "", "site": ""}
var look := {"pixel": 0.0, "palette": 1.0, "levels": 0.0, "dither": 0.3, "contrast": 1.0, "saturation": 1.1, "outline": 0.35,
	"bloom": 1.2, "ortho": 1.0, "lights": 1.0, "dim": 0.5, "spill": 1.0, "net_style": 7.0}
const NET_STYLES := ["", "POINTILLIST", "OBRA DINN", "WIRE · PIXEL", "BLACKWALL", "GHOST", "STARGATE", "WIRE · CRISP", "WIRE · BLUEPRINT", "WIRE · SCAN"]
const NET_FULL_RES := [7, 8]   # styles drawn without the pixel filter
const NET_CYCLE := [7, 8, 9, 3, 1, 2, 4, 5, 6]

## Curated palette (M4b critique: a real limited palette instead of free-floating mids): ink and
## navy ramps, warm concrete, cool greys, skin, wood, foliage, and each neon in two steps.
## Round 2: each neon has a 4-step ramp (deep, mid, full, pale) so coloured light keeps its hue in
## shadow and highlight; skin and wood are cut to two steps each; matching happens in OKLab.
## Round 3: neutrals first; neon-ramp entries are only allowed for saturated pixels (post shader),
## so shadows go navy instead of a violet wash. Warm darks added for earth.
## Sunset (badlands): violet-ink shadows, a long sand ramp, rust rock, cool metal greys, dry
## scrub, skin, dusk violet; then the neon ramps for the camp's signs and the UI-coloured effects.
## No orange/yellow neon ramps here: sunlit rock would snap to them and turn garish.
const PALETTE_SUNSET_NEUTRALS := 37
const PALETTE_SUNSET := ["07060a", "120c14", "1c1420", "2a1c2c", "3a2636", "4e3240",
	"3a2a22", "543a2c", "70503a", "8e6648", "ae8058", "c89a6a", "e0b884", "f2d6a8", "fff0d4",
	"4a2418", "6a3220", "8c4428", "ae5a32", "cc7440", "d88a48", "eaa860", "f4c88a",
	"2a2a34", "44444e", "62626c", "84828a", "aaa6a8", "d2ccc6",
	"5a4a30", "7a6840", "9a8a58", "8a5a40", "c08a68", "3a3a5a", "5a5a8a", "8a80b0",
	"5a1040", "ff2a6d", "ffa0c0", "0a4a5a", "05d9e8", "aaf6ff", "4a1a6a", "b537f2", "0e5a3a", "39f0a0", "7a1420", "ff3b4f"]
const PALETTE_NEUTRALS := 35
const PALETTE := ["05060a", "0b0e16", "141a26", "1e2636", "2a3448", "3a4660", "4e5c78",
	"1a1714", "2b2622", "3d3630", "554b42", "70665a", "8e8476",
	"4a5560", "66717c", "8a96a0", "b4bec6", "dfe6ea", "fff4e0",
	"8a5a40", "c08a68", "3a2418", "6a4a2a", "12261a", "1f4a2a", "3a6a3a", "6a5a50", "8a7a68",
	"241c18", "3a2c22", "5a4636", "2a3a5a", "2e1c10", "5a3414", "a0601e",
	"2a0a1e", "5a1040", "ff2a6d", "ffa0c0", "062430", "0a4a5a", "05d9e8", "aaf6ff",
	"2a1e06", "6a4a08", "f9c80e", "fff0a0", "1e0a2e", "4a1a6a", "b537f2", "e2b0ff",
	"2e1206", "7a3008", "ff6b1a", "ffc8a0", "06261a", "0e5a3a", "39f0a0", "b8ffe0",
	"7a1420", "ff3b4f"]
## Per-scene light: ambient, moon key, fog (round 2: the desert needs moonlit sand). Round 3 raised
## night ambient; the owner's light review (round 4) put it back: units read through their own look
## (trim, UNIT_KEY), not a brighter world. One grade for every scene: GRADE_EXPOSURE.
## Optional per scene: "sun" [elevation, world yaw] fixes the key light in the world (a real sun;
## night scenes let the moon key follow the camera), "sky" [zenith, mid, horizon], "palette",
## "rim" colour/energy and "lights" (lamp scale: dusk lamps are weaker than night ones).
const LOOKS := {
	"default": {"ambient": "262c44", "amb_e": 0.65, "key": "8fa0e0", "key_e": 0.5, "fog": "0d1422", "fog_d": 0.0035},
	"badlands": {"ambient": "4c4c90", "amb_e": 0.75, "key": "ffc898", "key_e": 1.15, "fog": "a86a58", "fog_d": 0.0025,
		"sun": [-17.0, 235.0], "sky": ["1c2050", "9a4466", "ff8c3c"], "palette": "sunset", "rim": ["6a5aa0", 0.35], "lights": 0.55,
		"fog_dim": 0.78, "fog_sat": 0.9, "fog_cool": 0.0},
	# Undercity: no sky, no moon. Dim green-black ambient; the work lamps and the glowing runoff
	# do the lighting. Unseen tunnels stay green-dark rather than going blue.
	"undercity": {"ambient": "2a4034", "amb_e": 0.7, "key": "6a8a70", "key_e": 0.22, "fog": "0a1a10", "fog_d": 0.006,
		"sky": ["020403", "040806", "0a140c"], "rim": ["3a6a4a", 0.2], "lights": 1.15,
		"fog_dim": 0.62, "fog_sat": 0.55, "fog_cool": 0.0},
	# Arcology: cold, shadowless light from the atrium roof; a faint red rim. Owner light review:
	# it read washed out once the colour bug was fixed, so the atrium is lit like an evening
	# interior now, a lot darker, with its contrast kept.
	"arcology": {"ambient": "6a7890", "amb_e": 0.06, "key": "e0e8f4", "key_e": 0.07, "fog": "2a303a", "fog_d": 0.0015,
		"sun": [-62.0, 200.0], "sky": ["181c24", "242a34", "343c48"], "rim": ["ff5060", 0.22], "lights": 0.2, "spill": 0.12, "soft_light": true,
		"fog_dim": 0.82, "fog_sat": 0.7, "fog_cool": 0.0},
	# Warzone: dusk under a sky lit by the fires; ember key low in the west, heavy brown smoke haze.
	"warzone": {"ambient": "3a3038", "amb_e": 0.62, "key": "ff8a50", "key_e": 0.5, "fog": "3a2420", "fog_d": 0.0045,
		"sun": [-12.0, 250.0], "sky": ["120a0c", "4a1a14", "c8501a"], "rim": ["ff6a2a", 0.3], "lights": 0.85,
		"fog_dim": 0.7, "fog_sat": 0.75, "fog_cool": 0.0},
}
const DECAL := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.0, 0.85, 0.9, 1.0);
uniform float pulse = 0.0;
uniform float ring = 0.0;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.15, d) * 0.45;
	if (ring > 0.5) a = max(a * 0.35, smoothstep(0.1, 0.0, abs(d - 0.82)));
	a *= 1.0 + pulse * 0.45 * sin(TIME * 4.0);
	ALBEDO = col.rgb * a * 1.6;
}
"""
const RANGE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec4 col : source_color = vec4(0.02, 0.85, 0.91, 1.0);
uniform vec4 col2 : source_color = vec4(1.0, 0.69, 0.0, 1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 v = texture(mask, UV).rg;
	float e1 = smoothstep(0.44, 0.5, v.r) - smoothstep(0.5, 0.56, v.r);
	float e2 = (smoothstep(0.44, 0.5, v.g) - smoothstep(0.5, 0.56, v.g)) * (1.0 - smoothstep(0.4, 0.5, v.r));
	float fill = smoothstep(0.45, 0.55, v.r);
	float dash = step(0.5, fract((wpos.x + wpos.z) * 1.2 - TIME * 0.5));
	ALBEDO = col.rgb * (e1 * (0.75 + 0.25 * dash) + fill * 0.04) + col2.rgb * e2 * 0.85 * (0.6 + 0.4 * dash);
}
"""

## Guards' sight lines: a thin dashed red contour round the watched ground and a faint moving
## hatch inside (no tiles); G marks the stretch of the hovered path that would be seen, brighter.
const WATCH := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec4 col : source_color = vec4(1.0, 0.23, 0.31, 1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 v = texture(mask, UV).rg;
	float edge = smoothstep(0.4, 0.5, v.r) - smoothstep(0.5, 0.6, v.r);
	float inside = smoothstep(0.45, 0.55, v.r);
	float dash = step(0.45, fract((wpos.x - wpos.z) * 1.1 + TIME * 0.4));
	float hatch = step(0.86, fract((wpos.x + wpos.z) * 1.6 - TIME * 0.25));
	float hot = smoothstep(0.35, 0.6, v.g);
	ALBEDO = col.rgb * (edge * (0.35 + 0.45 * dash) + inside * hatch * 0.16 + hot * (0.22 + 0.2 * hatch));
}
"""

var svp: SubViewport
var screen: TextureRect
var post: ShaderMaterial
var env: Environment
var sun: DirectionalLight3D
var cam: Camera3D
var cam_target := Vector3.ZERO
var cam_yaw := 45.0           ## free angle: Q/E turn it while held (CamTurn), middle-drag drags it
var cam_turn := CamTurn.new()
var _turn_keys := {}          ## KEY_Q / KEY_E → held (pressed through _unhandled_input, so the HUD can take them)
var cam_dist := 20.0
var hud: Hud
var world: Node3D
var floor_nodes: Array[Node3D] = []
var unit_nodes := {}
var door_nodes: Node3D
var grid_node: MeshInstance3D
var watch_node: MeshInstance3D   ## stealth: ground that visible, unalerted guards and cameras watch
var watch_img: Image
var watch_tex: ImageTexture
var _watchers := {}           ## "g<id>" / "c<id>" → watched squares, rebuilt each time the grid is
var _path_cells: Array[Vector3i] = []   ## the hovered move's squares
var path_node: MeshInstance3D
var range_img: Image
var range_tex: ImageTexture
var fires: Array[OmniLight3D] = []
var decals := {}              ## unit id → ground glow MeshInstance3D
var _withdraw_ask := -10000    ## withdrawal needs a second press within 3 s
var devices: DeviceView      ## meatspace devices with status lights
var ambient: AmbientFx       ## scene ambience: embers, flames and smoke, steam, drips, light shafts
var keycard_nodes := {}        ## unit id → glinting keycard over a downed carrier
var obj_node: Node3D           ## snatch objective: the package (a case on a gold beacon) and the extraction squares
var dash_opts := {}           ## squares reachable by also spending the Action on a Run (amber contour)
var rim: DirectionalLight3D
var unit_key: DirectionalLight3D   ## lights units only (UNIT_KEY)
var sky_mat: ShaderMaterial


## This scene's light and palette (LOOKS), defaulting to the night city; a district's look
## (SceneTheme light: smog, sea mist, dust) goes over it.
func _scene_look() -> Dictionary:
	if m == null:
		return LOOKS["default"]
	var lk: Dictionary = LOOKS.get(String(m.params.get("scene", "")), LOOKS["default"])
	var dl: Dictionary = SceneTheme.of(m).get("light", {})
	if dl.is_empty():
		return lk
	lk = lk.duplicate()
	lk.merge(dl, true)
	return lk
var open_cells := {}             ## Vector2i squares the cutaway may open (seen-into rooms + walls)
var struct_rooms := {}           ## structure id → {room label: true}, indoor rooms only
var _hover_sid := -1             ## building the pointer is planning into (opens it in AUTO)
var room_xy := {}                ## room label → its squares, for opening rooms
const KERB := 0.07               # sidewalk height (WorldBuilder raises sidewalks)
var _last_cur := -1
var fx: Fx
var busy := false             ## animating events: input is ignored
var _rebuild := false         ## cover/wall destroyed during playback: rebuild the world after
var ring: MeshInstance3D
var caret: MeshInstance3D
var lights: Array = []        ## [OmniLight3D, Vector3i cell, kind]
var fog_img: Image
var fog_tex: ImageTexture
var builder: WorldBuilder
var _log_seen := 0
var _shot_path := ""
var _shot_hover := Vector2i(-1, -1)
var _frames := 0
var _reveal := false
var _walk := 0
var _focus := ""
var _shot_floor := -1
var _attack_demo := false
var _jack_demo := false
var _av_demo := ""
var _inspect_demo := false
var net_overlay: NetOverlay
var net_view := true          ## N toggles back to the plain world while jacked in
var _net_pos := {}            ## architecture instance id → [pos, ground]
var _net_framed := -1
var _net_full_res := false
var _inspected := false        ## the Alt inspector card is showing
var _inspect_cell := Vector3i(-1, -1, -1)
var _shot_delay := 0.0
var _demo_ms := 0
var _reel := ""
var tool := ""                  ## M5 target-picking action: melee, shell, grenade, stabilize ("" = normal attacks)
var _dev_kit: PackedStringArray = []   ## --kit=a,b (review renders)
var _dev_stage := ""                   ## --stage=attack (review renders)
var _dev_arm := ""                     ## --arm=brawl|grenade|<attack mode> (review renders)
var _dev_portrait := false             ## --portrait=1 (review renders): hover the hovered foe's portrait instead
var _alt_demo := false                 ## --alt=1 (review renders): Alt held (outlines, roster)
var _dev_help := false                 ## --help=1 (review renders): the H panel open
var _dev_hurt := -1.0                  ## --hurt=f (review renders): the nearest foes roused, f of their HP lost
var _dev_log_t := -1.0                 ## --logt=t (review renders): the log's slide held at t
var _dev_near := 0                     ## --near=n (review renders): bring the nearest foe n squares from the crew
var _alt_on := false                   ## Alt is held: enemy outlines, last-known marks
var _portrait_uid := -1                ## the turn-order portrait under the mouse (-1 none)
var _aim := {}                         ## the hovered attack's preview: shape, from, to, col, ...
var aim_fx: AimFx                      ## ... drawn in the 3D world (the post shader pixelates it)
var _mh := {}                          ## the melee hover: attacker node, target id, yaw to restore
var _shot2 := ""                       ## --shot2=path (review renders): a second frame 0.15 s later
var _shot_ms := 0
var _last_known := {}                  ## foe unit id → the square the crew last saw them on
var _dev_end := ""                     ## --end=won|lost|fled (review renders): the gig ends that way, the end panel shows
var _dev_peace := false                ## --peace=broken (review renders): the crew breaks a neutral house's peace
var _jack_turret := false              ## --jack=turret (review renders): the runner also holds a turret's Control Node
var _dev_ambient := 1.0                ## --ambient=s (review renders): scale the scene's ambient energy (dev only)
var _dev_exposure := 1.0               ## --exposure=s (review renders): scale the tonemap exposure, the whole lit scene (dev only)
var _dev_gamma := 1.0                  ## --gamma=s (review renders): scale the grade's power curve (dev only)
var _campaign_gig := false             ## this map is the campaign's active gig (a board gig)
var blast_node: MeshInstance3D  ## the grenade's 5x5 blast preview under the cursor
var _net_cleaned := false
var _lf_dims := Vector3.ZERO
var _door_leaves := {}        ## door cell → leaf mesh, so moves can swing doors open as they pass


## Swing a door leaf open (a quarter turn about its hinge) when someone steps into the doorway.
func _swing_door(v: Vector3i) -> void:
	var mi: MeshInstance3D = _door_leaves.get(v)
	if mi == null or not is_instance_valid(mi) or absf(mi.rotation.y) > 0.1:
		return
	_snd("sfx_door", Vector3(v.x + 0.5, v.z * FH + 0.6, v.y + 0.5), -6.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(mi, "rotation:y", PI / 2, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position", mi.get_meta("open_at"), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _ready() -> void:
	UiScale.watch(get_window())
	AudioDirector.get_or_make(get_tree()).screen_of = func(p: Vector3) -> Vector2: return _to_screen(p) if cam else Vector2.ZERO
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"shot": _shot_path = kv[1]
			"shot2": _shot2 = kv[1]
			"scene": gig.scene = kv[1]
			"profile": gig.profile = kv[1]
			"district": gig["district"] = kv[1]   # a Night City district (city.json): its look, and its profile unless --profile/--scene say otherwise
			"seed": gig.seed = int(kv[1])
			"faction": gig.faction = kv[1]   # the target faction (World id: militech, maelstrom, ...)
			"site": gig.site = kv[1]   # lone_building: which building type (sites.json)
			"setpiece": gig["setpiece"] = kv[1]   # a set piece (setpieces.json): its scene, buildings and faction
			"location": gig["location"] = kv[1]   # with --setpiece: the World location it is played for
			"variant": gig["variant"] = kv[1]   # with --setpiece: one of its variants by id (the Estates: 1a-1l)
			"floor": _shot_floor = int(kv[1])   # review renders: look at this storey
			"kit": _dev_kit = kv[1].split(",")   # review renders: pack every crew member's kit slots
			"stage": _dev_stage = kv[1]   # review renders: open the action bar on this stage (attack)
			"arm": _dev_arm = kv[1]   # review renders: arm this attack (brawl, grenade = kit slot 1, or a mode id)
			"portrait": _dev_portrait = kv[1] != "0"   # review renders: the hover goes through the foe's portrait
			"alt": _alt_demo = kv[1] != "0"   # review renders: Alt held
			"help": _dev_help = kv[1] != "0"   # review renders: the H panel open
			"hurt": _dev_hurt = float(kv[1])   # review renders: the nearest foes are roused and lose this share of their HP
			"logt": _dev_log_t = float(kv[1])   # review renders: hold the log's slide here (0 collapsed .. 1 open)
			"near": _dev_near = int(kv[1])   # review renders: the nearest foe stands this many squares off, in the line of fire
			"end": _dev_end = kv[1]   # review renders: the gig ends this way (won | lost | fled), the end panel shows
			"peace": _dev_peace = true   # review renders: --peace=broken: the crew breaks a neutral house's peace (Totentanz)
			"exposure": _dev_exposure = float(kv[1])   # review renders: tonemap exposure x s (darkens world and units alike)
			"gamma": _dev_gamma = float(kv[1])   # review renders: grade power curve x s
			"ambient": _dev_ambient = float(kv[1])   # review renders: ambient energy x s (lamps: --lights, baked spill: --spill)
			"security":
				gig.security = int(kv[1])
				_security_flag = true
			"objective": gig["objective"] = kv[1]
			"complication": gig["complication"] = kv[1]   # force one: mook:2, lieutenant:1, mini_boss:4
			"fog": fog_on = kv[1] != "0"
			"cut":   # review renders: auto | all | off
				cutaway = kv[1] != "off"
				cut_all = kv[1] == "all"
			"sight": sight_mode = int(kv[1])
			"promo":   # beauty renders: the world and the characters only (no HUD, grid, markers)
				_promo = kv[1] != "0"
			"zoom": cam_dist = float(kv[1])
			"yaw":
				cam_yaw = float(kv[1])
			"reveal":  # review renders: everything explored
				_reveal = true
			"walk":  # review renders: the crew walks n squares toward the target first
				_walk = int(kv[1])
			"focus":  # review renders: centre the camera on a square ("center" = the target building)
				_focus = kv[1]
			"attack":  # review renders: the active crew member fires at the nearest guard
				_attack_demo = true
			"jack":  # review renders: the Netrunner jacks in at the nearest terminal (turret: one holding a turret's node)
				_jack_demo = true
				_jack_turret = kv[1] == "turret"
			"av":  # review renders: an AV lands (trauma | maxtac); --shot-delay sets when to capture
				_av_demo = kv[1]
			"reel":  # review videos: script one combat scene, then quit (record with --write-movie)
				_reel = kv[1]
			"inspect":  # review renders: show the Alt inspector card for the hovered square
				_inspect_demo = true
			"delay":  # review renders: take the shot this many seconds after the demo action
				_shot_delay = float(kv[1])
			"slow":  # review renders: slow motion so short effects land in a frame (software GL is slow)
				Engine.time_scale = float(kv[1])
			"hover":
				if kv[1] == "guard":
					_shot_hover = Vector2i(-2, -2)
					continue
				if kv[1] == "turret":   # the nearest turret in sight
					_shot_hover = Vector2i(-3, -3)
					continue
				var xy := kv[1].split(",")
				_shot_hover = Vector2i(int(xy[0]), int(xy[1]))
			_:
				if look.has(kv[0]):
					look[kv[0]] = float(kv[1])
	_build_view()
	new_gig()


func _process(delta: float) -> void:
	if _promo:
		_hide_overlays()
	if _charge_node and is_instance_valid(_charge_node) and enc:   # blink faster as the fuse runs down
		var rate := 2.0 + 3.0 * float(int(enc.obj.cfg.get("fuse_rounds", 3)) - maxi(enc.fuse_left(), 0))
		var on := fmod(Time.get_ticks_msec() / 1000.0 * rate, 1.0) < 0.5
		(_charge_node.get_node("led") as Node3D).visible = on
		(_charge_node.get_node("glow") as OmniLight3D).visible = on
	if devices and not keycard_nodes.is_empty():
		_update_keycards()
	if obj_node and is_instance_valid(obj_node) and int(enc.objective.get("carrier", -1)) >= 0:   # the diamond follows the carrier
		var tag := obj_node.get_node("tag") as Node3D
		tag.position = (unit_nodes[int(enc.objective.carrier)] as Node3D).position + Vector3(0, 2.75, 0)
		tag.rotation.y += delta * 2.0
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	if pan != Vector3.ZERO:
		cam_target += pan.rotated(Vector3.UP, deg_to_rad(cam_yaw)).normalized() * delta * cam_dist * 0.9
		_place_camera()
	for k in _turn_keys.keys():   # a key let go (wherever the release went) stops turning
		if not Input.is_key_pressed(k):
			_turn_keys.erase(k)
	var turn_dir := (1.0 if _turn_keys.has(KEY_E) else 0.0) - (1.0 if _turn_keys.has(KEY_Q) else 0.0)
	if turn_dir != 0.0 or cam_turn.turning():   # held Q/E: a steady turn, eased in and out
		cam_yaw = wrapf(cam_yaw + cam_turn.step(turn_dir, delta), 0.0, 360.0)
		_place_camera()
		if enc and m and _shot_path == "" and _reel == "":   # the world turns under a still cursor: re-pick
			var h := _pick(mouse)
			if h != hover:
				hover = h
				_on_hover_changed()
				if not _inspected:
					_update_hover()
	_update_shake(delta)
	_sync_aim_fx()
	# hold Alt to inspect what's under the cursor (owner: a dwell timer would be annoying)
	var alt := Input.is_key_pressed(KEY_ALT) or _inspect_demo or _alt_demo
	if hud and alt != hud.roster_on:
		hud.show_roster(alt)   # Alt slides the crew roster in (owner)
	if enc and alt != _alt_on:   # ... and outlines every enemy in sight (no conflict: both show)
		_alt_on = alt
		_update_outlines()
	if enc and hover.x >= 0 and alt and (not _inspected or hover != _inspect_cell):
		_inspected = true
		_inspect_cell = hover
		_inspect(hover)
	elif _inspected and not alt:
		_inspected = false
		_update_hover()
	if caret and enc and not enc.cur.is_empty():   # caret follows the active unit, bobbing and turning
		var cn: Node3D = unit_nodes.get(enc.cur.id)
		caret.visible = cn != null and cn.visible and enc.cur.team == 0 and enc.state == "playing"
		if cn:
			var t := Time.get_ticks_msec() / 1000.0
			caret.position = cn.global_position + Vector3(0, 1.55 + 0.05 * sin(t * 4.0), 0)
			caret.rotation.y = t * 1.5
	for fl in fires:  # firelight flicker
		fl.light_energy = fl.get_meta("base", 1.0) * look.lights * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.013 + fl.position.x) + randf() * 0.08)
	if _reel != "":
		_frames += 1
		if _frames == 1:   # set up on the very first frame, so the video opens on the action
			_run_reel()
	elif _shot_path != "":
		_frames += 1
		if _frames == 2 and _dev_help:
			hud.toggle_hint()
		if _frames == 2 and _dev_hurt >= 0.0:
			_demo_hurt()
		if _frames == 4 and _dev_log_t >= 0.0:
			hud.set_log_t(_dev_log_t)
		if _frames == 2 and _dev_near > 0:
			_demo_near()
		if _frames == 2 and _shot_hover.x <= -2:  # --hover=guard / turret: the nearest one in sight
			var want_turret := _shot_hover.x == -3
			var best := INF
			for u in enc.units:
				if (u.has("turret") if want_turret else (_foe(u) and u.pos.z == view_floor)) and (enc.vision.visible.has(u.pos) or not fog_on) and not u.c.dead:
					var d := Vector2(u.pos.x - enc.cur.pos.x, u.pos.y - enc.cur.pos.y).length()
					if not want_turret and not enc.los.sight(enc.cur.pos, u.pos).visible:
						d += 1000.0   # a guard in the line of fire first
					if d < best:
						best = d
						_shot_hover = Vector2i(u.pos.x, u.pos.y)
						if want_turret:   # turrets stand on roofs and decks: look at its storey
							view_floor = u.pos.z
							cam_target = Vector3(u.pos.x, 0, u.pos.y)
							_place_camera()
			if not want_turret and best < INF and _focus == "":   # frame shooter and guard
				var a3 := Vector3(enc.cur.pos.x, 0, enc.cur.pos.y)
				var b3 := Vector3(_shot_hover.x, 0, _shot_hover.y)
				cam_target = (a3 + b3) / 2
				cam_dist = maxf(cam_dist, minf(60.0, (a3 - b3).length() * 1.6 + 8.0))
				_place_camera()
		if _frames == 2 and _dev_stage != "":
			_on_hud("stage", _dev_stage)
		if _frames == 2 and _dev_arm != "":
			if _dev_arm == "grenade":
				_on_hud("kit", 0)
			elif _dev_arm == "brawl":
				stage = "attack"
				_arm("brawl")
				_refresh()
			else:
				_on_hud("atk_mode", _dev_arm)
		if _frames == 3 and _shot_hover.x >= 0:
			hover = Vector3i(_shot_hover.x, _shot_hover.y, view_floor)
			mouse = _to_screen(Vector3(hover.x + 0.5, view_floor * FH, hover.y + 0.5))
			_on_hover_changed()
			_update_hover()
			if _dev_portrait:   # the same target, through its portrait: the mouse sits on the strip
				var tu := _unit_at(hover)
				if not tu.is_empty():
					hover = Vector3i(-1, -1, -1)
					_on_hover_changed()
					_update_hover()
					_on_hud("portrait_hover", [int(tu.id), hud.portrait_rect(int(tu.id), true)])
			if _inspect_demo:
				_inspected = true
				_inspect_cell = hover
				_inspect(hover)
		if _frames == 10 and _attack_demo:
			_demo_attack()
		if _frames == 10 and _jack_demo:
			_demo_jack()
		if _frames == 10 and _av_demo != "":
			_demo_av()
		if _frames == 10 and _dev_peace:
			_demo_peace()
		if _frames == 10 and _dev_end != "":
			_demo_ms = Time.get_ticks_msec()
			enc.state = _dev_end
			_after_action()
		var shoot_now: bool = _frames >= 12 if not (_attack_demo or _jack_demo or _av_demo != "" or _dev_peace or _dev_end != "") else (_demo_ms > 0 and Time.get_ticks_msec() - _demo_ms >= int(_shot_delay * 1000.0 / Engine.time_scale))
		if shoot_now and _shot_ms == 0:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			_shot_ms = Time.get_ticks_msec()
			if _shot2 == "":
				get_tree().quit()
		elif _shot_ms > 0 and Time.get_ticks_msec() - _shot_ms >= 150:
			get_viewport().get_texture().get_image().save_png(_shot2)
			get_tree().quit()


# --- View: low-res 3D viewport + post + HUD ---------------------------------------

func _build_view() -> void:
	svp = SubViewport.new()
	svp.own_world_3d = true
	svp.msaa_3d = Viewport.MSAA_DISABLED
	# Not HDR 2D: under Forward+ (the owner's GPU) an HDR 2D buffer holds LINEAR colour, which the post
	# shader and the screen read as sRGB, so the whole scene came out ~3x darker (luma 0.05 vs 0.17 on
	# compatibility, which ignores the flag). Glow still runs in the 3D buffer. Same fix as the safehouse.
	svp.use_hdr_2d = false
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)
	screen = TextureRect.new()
	screen.texture = svp.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = POST_SHADER
	screen.material = post
	var bg := CanvasLayer.new()
	bg.layer = -1
	add_child(bg)
	bg.add_child(screen)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skm := ShaderMaterial.new()
	skm.shader = SKY_SHADER
	sky.sky_material = skm
	sky_mat = skm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("222a48")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR   # ACES washed saturated neon to white
	env.tonemap_exposure = GRADE_EXPOSURE
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:  # wide, chunky halos once the low-res buffer is upscaled
		env.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)
	# No SSAO: the LightField bakes contact occlusion at wall and cover bases for both renderers.
	# SSAO (Forward+ only) doubled it into a dark halo along every room's walls (owner light review).
	env.ssao_enabled = false
	env.ssr_enabled = true         # wet-street reflections on the user's GPU
	env.fog_enabled = true
	env.fog_height = 1.2          # low haze over the far city
	env.fog_height_density = 0.08
	env.fog_light_color = Color("2a1020")
	env.fog_density = 0.006
	we.environment = env
	svp.add_child(we)
	sun = DirectionalLight3D.new()   # cold moonlight, just enough to read the blockout
	sun.rotation_degrees = Vector3(-55, 80, 0)   # key moonlight from the camera side (set in _place_camera)
	sun.light_color = Color("7f9cd0")
	sun.light_energy = 0.35
	sun.shadow_enabled = true
	svp.add_child(sun)
	rim = DirectionalLight3D.new()   # weak back light for silhouettes; `sun` is the key from the camera side
	rim.light_color = Color("5a6aa0")
	rim.light_energy = 0.25
	# No specular: a back light's highlight on a glossy floor faces the camera and bloomed into a
	# big saturated blob (the arcology's red rim, owner light review). It only edges silhouettes.
	rim.light_specular = 0.0
	svp.add_child(rim)
	unit_key = DirectionalLight3D.new()   # units only: a soft key from above the camera
	unit_key.light_color = Color("dfe6f0")
	unit_key.light_energy = UNIT_KEY
	unit_key.light_cull_mask = 2   # CharModel meshes sit on render layer 2; the world is on layer 1
	unit_key.shadow_enabled = false
	unit_key.light_specular = 0.3
	svp.add_child(unit_key)
	cam = Camera3D.new()
	cam.fov = 34
	svp.add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.action.connect(_on_hud)
	net_overlay = NetOverlay.new()
	net_overlay.visible = false
	hud.add_child(net_overlay)
	hud.move_child(net_overlay, 0)
	net_overlay.to_screen = _to_screen
	var markers := Hud.Painter.new()   # objective markers, edge arrows when off screen
	markers.fn = _draw_markers
	hud.add_child(markers)
	hud.move_child(markers, 0)
	var shields := Hud.Painter.new()
	shields.fn = _draw_cover_shields
	hud.add_child(shields)
	hud.move_child(shields, 0)
	var aim := Hud.Painter.new()   # Alt's last-known marks (the attack preview is in the 3D world: AimFx)
	aim.fn = _draw_aim
	hud.add_child(aim)
	hud.move_child(aim, 0)
	hud.build_hint()
	hud.build_settings(look, [["pixel", "Pixel scale (0 auto)", 0, 6, 1], ["palette", "Palette", 0, 1, 1], ["levels", "Channel steps", 0, 32, 1], ["dither", "Dither", 0, 1, 0.05], ["spill", "Light spill", 0, 2, 0.05],
		["contrast", "Contrast", 0.6, 1.6, 0.05], ["saturation", "Saturation", 0, 2, 0.05], ["outline", "Outline", 0, 1, 0.05],
		["bloom", "Bloom", 0, 2, 0.05], ["lights", "Light level", 0.2, 2, 0.05], ["ortho", "Orthographic", 0, 1, 1]], _apply_look)
	get_viewport().size_changed.connect(_apply_look)
	_apply_look()


static func _oklab(c: Color) -> Vector3:
	var lin := func(x: float) -> float: return x / 12.92 if x <= 0.04045 else pow((x + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m2 := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s2 := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m2 - 0.0040720468 * s2,
		1.9779984951 * l - 2.4285922050 * m2 + 0.4505937099 * s2,
		0.0259040371 * l + 0.7827717662 * m2 - 0.8086757660 * s2)


## Screen pixels per buffer pixel: set, or auto so the buffer is ~360 lines tall at any window size.
func _px() -> float:
	if _net_full_res:
		return 1.0
	if look.pixel >= 1.0:
		return float(look.pixel)
	return maxf(1.0, roundf(get_viewport().get_visible_rect().size.y / 360.0))


func _apply_look() -> void:
	var px := _px()
	var win := Vector2(get_viewport().get_visible_rect().size)
	# one spare buffer pixel on each side so the texel-snapped camera can shift the image sub-pixel
	svp.size = Vector2i(maxi(1, int(win.x / px)) + 2, maxi(1, int(win.y / px)) + 2)
	screen.size = Vector2(svp.size) * px
	post.set_shader_parameter("src_size", Vector2(svp.size))
	post.set_shader_parameter("palette_on", look.palette > 0.5)
	var pname := String(_scene_look().get("palette", SceneTheme.of(m).get("palette", "")))
	var hexes: Array = PALETTE
	var nn := PALETTE_NEUTRALS
	if pname == "sunset":
		hexes = PALETTE_SUNSET
		nn = PALETTE_SUNSET_NEUTRALS
	elif SceneTheme.palettes().has(pname):
		nn = int(SceneTheme.palettes()[pname][0])
		hexes = SceneTheme.palettes()[pname][1]
	var pal := PackedVector3Array()
	for h in hexes:
		pal.append(_oklab(Color(h)))
	post.set_shader_parameter("palette", pal)
	post.set_shader_parameter("palette_n", pal.size())
	post.set_shader_parameter("palette_neutral_n", nn)
	if hud and hud.portraits:   # portraits stay on the night palette: the HUD is the same in every scene
		var npal := PackedVector3Array()
		for h in PALETTE:
			npal.append(_oklab(Color(h)))
		hud.portraits.post_shader = POST_SHADER
		hud.portraits.palette = npal
		hud.portraits.palette_neutral_n = PALETTE_NEUTRALS
	post.set_shader_parameter("levels", look.levels)
	post.set_shader_parameter("dither", look.dither)
	post.set_shader_parameter("contrast", look.contrast)
	post.set_shader_parameter("saturation", look.saturation)
	post.set_shader_parameter("grade_gamma", GRADE_GAMMA * _dev_gamma)
	post.set_shader_parameter("outline", look.outline)
	env.glow_intensity = look.bloom
	env.glow_strength = 1.0
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL if look.ortho > 0.5 else Camera3D.PROJECTION_PERSPECTIVE
	for l in lights:
		l[0].light_energy = l[0].get_meta("base", 1.0) * look.lights * float(_scene_look().get("lights", 1.0))
	_apply_world_look()
	_place_camera()


# --- Gig setup -------------------------------------------------------------------

func new_gig() -> void:
	_last_known = {}
	_aim = {}
	var o := {"security": gig.security}
	var did := String(gig.get("district", ""))
	if did != "":
		o["district"] = did
		if gig.profile == "" and gig.scene in ["skirmish", "neighborhood", "street_block", "city_district"]:   # the district's own streets
			gig.profile = String(World.district(did).get("profile", ""))
	if gig.profile != "":
		o["profile"] = gig.profile
	if String(gig.site) != "":
		o["site"] = gig.site
	if String(gig.get("setpiece", "")) != "":
		o["setpiece"] = gig.setpiece
		o["location"] = String(gig.get("location", ""))
		if not _security_flag:   # review renders show the recipe's own security level
			o.erase("security")
		if gig.has("variant"):
			o["variant"] = String(gig.variant)
		if String(gig.get("faction", "")) == "":
			gig.faction = String(SetPieces.get_def(String(gig.setpiece)).get("faction", ""))
	var camp := Campaign.current
	var campaign_gig: bool = camp != null and not camp.active_gig.is_empty() and _reel == "" and _shot_path == ""
	_campaign_gig = campaign_gig
	var eo: Dictionary = {}
	if gig.has("complication"):   # review renders: --complication=<tier>:<roll> (or just the roll)
		var parts := String(gig.complication).split(":")
		eo["complication"] = {"tier": parts[0], "roll": int(parts[1])} if parts.size() > 1 else {"roll": int(parts[0])}
	if campaign_gig:   # a gig taken from the fixer board, built as every campaign gig is (GigSetup, shared with the soak)
		gig.scene = String(camp.active_gig.scene)
		gig.seed = int(camp.active_gig.seed)
		gig.security = int(camp.active_gig.security)
		gig.profile = ""
		var gs := GigSetup.for_campaign(camp, _dev_kit, eo)
		m = gs.map
		dice = gs.dice
		enc = gs.enc
	else:
		m = SceneGen.generate(gig.seed, "neighborhood" if gig.profile != "" else gig.scene, o)
		dice = Dice.new(gig.seed + 1)
		var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
		for cm in crew:   # review renders: everyone packs the same kit
			for i in mini(2, _dev_kit.size()):
				cm.kit[i] = _dev_kit[i]
		var fid := String(gig.get("faction", ""))
		if fid != "":
			eo["faction"] = fid
		enc = Encounter.setup(m, dice, crew, gig.get("objective", "data") as String, eo)
	view_floor = m.street   # the crew goes in at street level
	_log_seen = 0
	var lk := _scene_look()
	env.ambient_light_color = Color(lk.ambient)
	env.ambient_light_energy = lk.amb_e * _dev_ambient
	env.tonemap_exposure = GRADE_EXPOSURE * _dev_exposure
	sun.light_color = Color(lk.key)
	sun.light_energy = lk.key_e
	env.fog_light_color = Color(lk.fog)
	env.fog_density = lk.fog_d
	var skc: Array = lk.get("sky", ["030308", "0d0817", "521a29"])
	sky_mat.set_shader_parameter("zenith", Color(skc[0]))
	sky_mat.set_shader_parameter("mid", Color(skc[1]))
	sky_mat.set_shader_parameter("horizon", Color(skc[2]))
	var rimc: Array = lk.get("rim", ["5a6aa0", 0.25])
	rim.light_color = Color(rimc[0])
	rim.light_energy = rimc[1]
	sun.directional_shadow_max_distance = 140.0
	_apply_look()
	_build_world()
	_last_cur = -1
	_frame_unit(enc.units[0])
	enc.next_turn()
	if _reveal:
		for f in m.floors:
			for y in m.h:
				for x in m.w:
					enc.vision.explored[Vector3i(x, y, f)] = true
	for i in _walk:  # scripted approach for review renders: each crew member walks toward the main door
		for u in enc.alive(0):
			var door := Vector3i(m.w / 2, m.h / 2, m.street)
			for e in m.entrances:
				if e.main:
					door = Vector3i(e.pos.x, e.pos.y, int(e.floor))
			var p := enc.nav.path(u.pos, door, enc.occupied(u))
			if p.size() > 1:
				u.pos = p[0]
				enc.los.open_doors[p[0]] = true if m.t(p[0].z, p[0].x, p[0].y) == TacMap.T.DOOR else false
				if not enc.los.open_doors[p[0]]:
					enc.los.open_doors.erase(p[0])
		enc.refresh_vision()
		enc.update_alerts()
	if _walk > 0:
		_frame_unit(enc.cur)
	if _focus != "":
		var fc := Vector2(m.w / 2.0, m.h / 2.0)
		var o_unit := enc.obj.focus_unit()
		var o_cell := enc.obj.focus_cell()
		if _focus == "objective" and o_unit >= 0:   # review renders: the mark or the captive
			var ou: Vector3i = enc.units[o_unit].pos
			fc = Vector2(ou.x, ou.y)
			view_floor = ou.z
		elif _focus == "objective" and o_cell.x >= 0:   # review renders: the package, the machine
			fc = Vector2(o_cell.x, o_cell.y)
			view_floor = o_cell.z
		elif _focus == "civ":   # review renders: the bystander nearest the crew
			var best := INF
			for u in enc.units:
				if u.team == Encounter.CIV_TEAM:
					var d := Vector2(u.pos.x - enc.cur.pos.x, u.pos.y - enc.cur.pos.y).length()
					if m.t(u.pos.z, u.pos.x, u.pos.y) != TacMap.T.OUTSIDE:
						d += 1000.0   # indoors: hidden under the roof in a promo render
					if d < best:
						best = d
						fc = Vector2(u.pos.x, u.pos.y)
						view_floor = u.pos.z
		elif _focus == "center":
			for st in m.structures:
				if st.target and st.has("rect"):
					fc = Vector2((st.rect as Rect2i).get_center())
		else:
			var xy := _focus.split(",")
			fc = Vector2(float(xy[0]), float(xy[1]))
		cam_target = Vector3(fc.x, 0, fc.y)
		_place_camera()
		_last_cur = enc.cur.id
	if _shot_floor >= 0:   # review renders: a storey of the building (with --cut=all, the floors above cut away)
		view_floor = mini(_shot_floor, m.floors - 1)
		_last_cur = enc.cur.id if not enc.cur.is_empty() else -1   # the first turn keeps this storey (it would frame the crew's)
		_place_camera()
	_after_action()


# --- World -------------------------------------------------------------------------

func _unlit(col: Color, alpha := 1.0, glow := 1.0) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(col * glow, alpha)
	if alpha < 1.0:
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mt


func _build_world() -> void:
	if world:
		world.queue_free()
	world = Node3D.new()
	svp.add_child(world)
	fog_img = Image.create(m.w, m.h * m.floors, false, Image.FORMAT_RG8)
	fog_tex = ImageTexture.create_from_image(fog_img)
	_update_fog()
	room_xy.clear()
	struct_rooms.clear()
	_hover_sid = -1
	for f in m.floors:
		for y in m.h:
			for x in m.w:
				var l := m.label(f, x, y)
				if l >= 0:
					room_xy.get_or_add(l, []).append(Vector2i(x, y))
					if not m.rooms[l].get("outdoor", false):
						struct_rooms.get_or_add(int(m.rooms[l].structure), {})[l] = true
	builder = WorldBuilder.new(m, enc.vision, fog_tex)
	floor_nodes = builder.build(world)
	for s in builder.surfaces():
		floor_nodes[int(s.get_meta("floor", 0))].add_child(s)
	builder.lightfield = LightField.bake(m, enc.los, LightPlan.plan(m, m.seed_value) + LightPlan.fill(m, m.seed_value) + builder.emitters)
	devices = DeviceView.new()
	world.add_child(devices)
	devices.build(m, func(v: Vector3i) -> float: return _gy(v))
	keycard_nodes.clear()
	RenderingServer.global_shader_parameter_set("lf_tex", builder.lightfield)   # units read it too
	_lf_dims = Vector3(m.w, m.h, m.floors)
	RenderingServer.global_shader_parameter_set("lf_dims", _lf_dims)
	unit_nodes.clear()
	lights.clear()
	ambient = AmbientFx.new()
	world.add_child(ambient)
	ambient.build(m, SceneTheme.of(m).get("ambient", []), m.seed_value)
	_build_lights()
	door_nodes = Node3D.new()
	world.add_child(door_nodes)
	fx = Fx.new()
	fx.rng.seed = gig.seed * 7 + 3
	world.add_child(fx)
	_flash_lights.clear()
	grid_node = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(m.w, m.h)
	grid_node.mesh = pm
	grid_node.position = Vector3(m.w / 2.0, 0, m.h / 2.0)
	var rsh := Shader.new()
	rsh.code = RANGE
	var rmt := ShaderMaterial.new()
	rmt.shader = rsh
	grid_node.material_override = rmt
	range_img = Image.create(m.w, m.h, false, Image.FORMAT_RG8)
	range_tex = null
	world.add_child(grid_node)
	path_node = MeshInstance3D.new()
	world.add_child(path_node)
	ring = _decal(Color("f9c80e"), 1.1, true, 1.0)
	caret = _make_caret()
	decals.clear()
	for u in enc.units:
		_unit_node(u)
	_apply_world_look()
	_refresh()


## A unit's body (built with the world, or when backup arrives mid-gig).
func _unit_node(u: Dictionary) -> CharModel:
	if unit_nodes.has(u.id):
		return unit_nodes[u.id]
	var look_role := "exec" if u.get("vip", false) else String(u.c.role)
	var n := CharModel.build(UnitLook.seed_team(u), u.c.look_seed if u.c.look_seed >= 0 else u.id, look_role, u.c.weapons[0].id() if not u.c.weapons.is_empty() else "heavy_pistol", u.c.faction)
	if u.c.weapons.is_empty() and n.gun:   # the unarmed (captives) carry nothing
		n.gun.visible = false
	if u.has("turret"):   # an automated turret (Turret): DeviceView draws the gun; the unit only stands in for it
		n.skel.visible = false
		if n.gun:
			n.gun.visible = false
	decals[u.id] = _decal(Color("05d9e8"), 0.95, false, 0.0)
	decals[u.id].visible = false   # owner: no glows under units; they blend into the scene
	var blob := _decal(Color.BLACK, 0.75, false, 0.0, true)   # contact shadow
	blob.name = "blob"
	blob.get_parent().remove_child(blob)
	n.add_child(blob)
	blob.position = Vector3(0, 0.02, 0)
	blob.scale = Vector3.ONE / 1.3
	world.add_child(n)
	n.position = Vector3(u.pos.x + 0.5, _gy(u.pos), u.pos.y + 0.5)
	n.scale = Vector3.ONE * 1.3
	unit_nodes[u.id] = n
	return n


func _apply_world_look() -> void:
	if builder:
		for mt in builder.materials():
			var lk := _scene_look()   # per scene: bright natural scenes only dim what's out of sight (owner)
			mt.set_shader_parameter("explored_dim", float(lk.get("fog_dim", look.dim)))
			mt.set_shader_parameter("fog_sat", float(lk.get("fog_sat", 0.3)))
			mt.set_shader_parameter("fog_cool", float(lk.get("fog_cool", 1.0)))
			mt.set_shader_parameter("soft_light", bool(lk.get("soft_light", false)))
			mt.set_shader_parameter("spill", 0.0 if _net_cleaned else look.spill * float(lk.get("spill", 1.0)))   # cyberspace keeps the spill off
			mt.set_shader_parameter("lightfield", builder.lightfield)


## A soft additive glow on the ground (team colour under units; a ring for the active unit and
## the hovered target).
func _decal(col: Color, size: float, ring_mode: bool, pulse: float, shadow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(size, size)
	var sh := Shader.new()
	sh.code = DECAL if not shadow else DECAL.replace("blend_add", "blend_mul").replace("ALBEDO = col.rgb * a * 1.6;", "ALBEDO = mix(vec3(1.0), vec3(0.35), clamp(a * 2.2, 0.0, 1.0));")
	var mt := ShaderMaterial.new()
	mt.shader = sh
	mt.set_shader_parameter("col", col)
	mt.set_shader_parameter("ring", 1.0 if ring_mode else 0.0)
	mt.set_shader_parameter("pulse", pulse)
	q.material = mt
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	return mi


func _build_lights() -> void:
	fires.clear()
	for e in LightPlan.plan(m, m.seed_value) + LightPlan.fill(m, m.seed_value):
		var cell: Vector3i = e.cell
		var fn: Node3D = floor_nodes[cell.z]
		var base := Vector3(cell.x + 0.5, cell.z * FH, cell.y + 0.5)
		if e.get("bake", false):   # baked-only (LightField): no OmniLight; a porch lamp still shows its fixture
			if e.kind == "porch":
				var pout := Vector3(e.out.x, 0, e.out.y)
				var lampm := MeshInstance3D.new()
				var pb := BoxMesh.new()
				pb.size = Vector3(0.22, 0.05, 0.12) if e.out.y != 0 else Vector3(0.12, 0.05, 0.22)
				pb.material = _unlit(e.color, 1.0, 1.4)
				lampm.mesh = pb
				lampm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				lampm.position = base + pout * 0.62 + Vector3(0, 1.42, 0)
				fn.add_child(lampm)
			continue
		if e.kind == "room":   # ceiling light: an even area light baked in the LightField (it lights units
			continue           # too). An OmniLight here drew a round pool with dark room edges (owner review).
		var l := OmniLight3D.new()
		l.light_color = e.color
		l.omni_range = e.range
		l.omni_attenuation = 1.4
		l.set_meta("base", e.energy)
		match e.kind:
			"sign":
				var out := Vector3(e.out.x, 0, e.out.y)
				l.position = base + out * 0.9 + Vector3(0, 1.15, 0)
				var sign := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.75, 0.16, 0.06) if e.out.y != 0 else Vector3(0.06, 0.16, 0.75)
				bm.material = _unlit(e.color, 1.0, 1.5)
				sign.mesh = bm
				sign.position = base + out * 0.55 + Vector3(0, 1.3, 0)
				fn.add_child(sign)
			"lamp" when e.out != Vector2i.ZERO:   # bulkhead: a caged work lamp on the wall
				var outv := Vector3(e.out.x, 0, e.out.y)
				var wallp := base - outv * 0.5
				var hous := MeshInstance3D.new()
				var hb2 := BoxMesh.new()
				hb2.size = Vector3(0.2, 0.14, 0.12) if e.out.y != 0 else Vector3(0.12, 0.14, 0.2)
				hb2.material = builder.mat("steel", 0, false, {"color": Color("2a2e2a")})
				hous.mesh = hb2
				hous.position = wallp + outv * 0.26 + Vector3(0, 1.18, 0)
				fn.add_child(hous)
				var lens := MeshInstance3D.new()
				var lb := BoxMesh.new()
				lb.size = Vector3(0.15, 0.09, 0.02) if e.out.y != 0 else Vector3(0.02, 0.09, 0.15)
				lb.material = _unlit(e.color, 1.0, 1.6)
				lens.mesh = lb
				lens.position = hous.position + outv * 0.07
				fn.add_child(lens)
				l.position = lens.position + outv * 0.25 - Vector3(0, 0.1, 0)
			"lamp":
				l.position = base + Vector3(0, 1.45, 0)
				var pole := MeshInstance3D.new()
				var pm := CylinderMesh.new()
				pm.top_radius = 0.025
				pm.bottom_radius = 0.035
				pm.height = 1.5
				pm.material = builder.mat("post", 0, false)
				pole.mesh = pm
				pole.position = base + Vector3(0.3, 0.75, 0.3)
				fn.add_child(pole)
				var housing := MeshInstance3D.new()
				var hb := BoxMesh.new()
				hb.size = Vector3(0.14, 0.06, 0.14)
				hb.material = pm.material
				housing.mesh = hb
				housing.position = base + Vector3(0.22, 1.52, 0.3)
				fn.add_child(housing)
				var head := MeshInstance3D.new()
				var hm := BoxMesh.new()
				hm.size = Vector3(0.11, 0.015, 0.11)
				hm.material = _unlit(e.color, 1.0, 1.4)
				head.mesh = hm
				head.position = base + Vector3(0.22, 1.485, 0.3)
				fn.add_child(head)
				l.position = head.position - Vector3(0, 0.05, 0)
			"fire":
				l.position = base + Vector3(0, 0.45, 0)
				var pit := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.22
				cm.bottom_radius = 0.26
				cm.height = 0.1
				cm.material = builder.mat("stone", 0, false)
				pit.mesh = cm
				pit.position = base + Vector3(0, 0.05, 0)
				fn.add_child(pit)
				var flame := MeshInstance3D.new()
				var fm := SphereMesh.new()
				fm.radius = 0.16
				fm.height = 0.36
				fm.radial_segments = 6
				fm.rings = 3
				fm.material = _unlit(Color("ff9a30"), 1.0, 1.6)
				flame.mesh = fm
				flame.position = base + Vector3(0, 0.2, 0)
				fn.add_child(flame)
				fires.append(l)
			"blaze":   # a burning wreck: flames, sparks and a smoke column (AmbientFx)
				l.position = base + Vector3(0, 0.9, 0)
				ambient.flame(base + Vector3(0, 0.25, 0), 1.3, true)
				fires.append(l)
			"hazard":
				l.position = base + Vector3(0, 0.6, 0)
		fn.add_child(l)
		lights.append([l, cell, e.kind])
	_apply_look()


# --- Refresh: fog, cutaway, units, grid, HUD -------------------------------------

func _refresh() -> void:
	if hud:   # which overlays are on, so a toggled-off one isn't a mystery
		hud.set_overlays("SIGHT LINES %s [Z]  ·  CUTAWAY %s [C]" % [["NEAR MOVE", "ALWAYS", "OFF"][sight_mode], "OFF" if not cutaway else ("ALL" if cut_all else "AUTO")])
	_update_fog()
	_update_cut()
	_update_objective()
	if devices:
		devices.refresh(enc)
		_update_keycards()
	for l in lights:  # rooms stay dark until explored, so a reveal reads as lights coming on
		var cell: Vector3i = l[1]
		l[0].visible = not _net_cleaned and not enc.lights_out() and (l[2] != "room" or not fog_on or enc.vision.explored.has(cell))
	_build_doors()
	AimPreview.remember(_last_known, enc.units.filter(func(o): return _foe(o)), _seen)
	for u in enc.units:
		var n: Node3D = _unit_node(u)
		var seen: bool = u.team == 0 or not fog_on or enc.vision.visible.has(u.pos)
		n.visible = seen and not _cut_hides(u.pos) and not u.get("fled", false) and not u.get("carried", false) and not n.get_meta("arriving", false)
		if u.get("fled", false) or u.get("carried", false):
			continue
		var dc: MeshInstance3D = decals[u.id]
		dc.visible = false
		n.set_meta("wound", u.c.wound_state())
		n.set_meta("calm", enc.is_guard(u) and not u.alerted)
		n.set_meta("jack", enc.runs.has(u.id))
		if u.c.dead:
			if not n.get_meta("fallen", false):   # died out of sight: just lie there
				n.position = Vector3(u.pos.x + 0.5, _gy(u.pos), u.pos.y + 0.5)
				(n as CharModel).die(Vector3.BACK.rotated(Vector3.UP, n.rotation.y), false, true)
			continue
		n.position = Vector3(u.pos.x + 0.5, _gy(u.pos), u.pos.y + 0.5)
		n.scale = Vector3.ONE * 1.3   # a touch larger than life, still in scale with 1.15-high doors
		dc.position = n.position + Vector3(0, 0.03, 0)
		n.set_meta("slump_goal", 1.0 if u.c.wound_state() == Combatant.Wound.MORTAL else 0.0)
		n.set_meta("crouch_goal", 1.0 if _beside_cover(u.pos) or u.team == Encounter.CAPTIVE else 0.0)   # crouching reads as "in cover"; captives kneel
		if true:
			n.rotation.x = 0
			var foes := enc.foes(u).filter(func(o): return o.alerted or enc.is_guard(u))
			if enc.is_guard(u) and not u.alerted:
				foes = []
				var fc: Vector2 = u.get("facing", Vector2.ZERO)   # watching their sector
				if fc != Vector2.ZERO:
					n.rotation.y = atan2(fc.x, fc.y)
			if not foes.is_empty():
				foes.sort_custom(func(a, b): return Vector3(a.pos - u.pos).length() < Vector3(b.pos - u.pos).length())
				var d: Vector3i = foes[0].pos - u.pos
				n.rotation.y = atan2(float(d.x), float(d.y))
	if not enc.cur.is_empty():
		ring.visible = false   # the white outline marks the active unit now
		_update_outlines()
		ring.position = Vector3(enc.cur.pos.x + 0.5, _gy(enc.cur.pos) + 0.04, enc.cur.pos.y + 0.5)
	_update_xray()
	_update_audio()
	_draw_grid()
	_hud_refresh()
	_update_net()
	_toast_new_log()


# --- Cyberspace view ------------------------------------------------------------------------

func _net_active() -> NetRun:
	return net_view_run(enc, net_view)


## The run the NET view shows: the active unit's, only while it's a jacked-in crew Netrunner's turn
## in a gig still going (and the N toggle is on); null shows the plain world.
static func net_view_run(e: Encounter, view_on: bool) -> NetRun:
	if e == null or not view_on or e.state != "playing" or e.cur.is_empty() or e.cur.team != Encounter.CREW:
		return null
	return e.runs.get(e.cur.id)


## Cyberspace reads cleaner without the physical world's lighting: the edge styles otherwise trace
## every lamp pool and light spill as white swaths (owner). While jacked in, lamps go dark, the
## baked spill and sun shadows are off, and the move outline and path are hidden.
func _net_clean(on: bool) -> void:
	if on:
		grid_node.visible = false
		path_node.mesh = null
	if on == _net_cleaned:
		return
	_net_cleaned = on
	for l in lights:
		(l[0] as Node3D).visible = not on and (l[2] != "room" or not fog_on or enc.vision.explored.has(l[1]))
	for fl in fires:
		fl.visible = not on
	sun.shadow_enabled = not on
	if builder:
		for mt in builder.materials():
			mt.set_shader_parameter("spill", 0.0 if on else look.spill)
	RenderingServer.global_shader_parameter_set("lf_dims", Vector3.ZERO if on else _lf_dims)   # units drop the spill too


## While jacked in: the environment goes to the chosen background style, the NET draws on top.
func _update_net() -> void:
	_show_net(_net_active())


## The NET view for `run` (null: the plain world). The wireframe belongs to the runner's own turn.
func _show_net(run: NetRun) -> void:
	post.set_shader_parameter("net_style", int(look.net_style) if run else 0)
	var full: bool = run != null and int(look.net_style) in NET_FULL_RES
	if full != _net_full_res:   # crisp styles render the 3D view at full resolution
		_net_full_res = full
		_apply_look()
	net_overlay.visible = run != null
	_net_clean(run != null)
	if run == null:
		return
	var key := run.arch.get_instance_id()
	if not _net_pos.has(key):
		_net_pos[key] = _net_layout(run.arch)
	net_overlay.run = run
	net_overlay.pos = _net_pos[key][0]
	net_overlay.ground = _net_pos[key][1]
	net_overlay.visited[run.current] = true
	if run.current != _net_framed:   # frame the current node and its links
		_net_framed = run.current
		var pts: Array = []
		for id in net_overlay.shown():
			if net_overlay.pos.has(id):
				pts.append(net_overlay.pos[id])
		if not pts.is_empty():
			var c := Vector3.ZERO
			var span := 0.0
			for p in pts:
				c += p
			c /= pts.size()
			for p in pts:
				span = maxf(span, Vector2(p.x - c.x, p.z - c.z).length())
			_pan_to(c, 0.35, clampf(span * 3.2 + 10.0, 16.0, 50.0))


## Where each node floats: over its device(s); net-only nodes near their linked nodes; deeper
## security levels higher. Returns [pos, ground] dictionaries.
func _net_layout(a: NetArchitecture) -> Array:
	var known := {}
	var fl := {}
	for nd in a.nodes:
		var ids: Array = []
		if int(nd.get("device", -1)) >= 0:
			ids = [int(nd.device)]
		elif nd.has("devices"):
			ids = nd.devices
		if ids.is_empty():
			continue
		var acc := Vector2.ZERO
		var f := 0
		for did in ids:
			var d: Dictionary = m.devices[did]
			acc += Vector2(d.pos.x + 0.5, d.pos.y + 0.5)
			f = d.floor
		known[nd.id] = acc / ids.size()
		fl[nd.id] = f
	for pass_i in 8:   # relax: unplaced nodes sit around their placed neighbours
		for nd in a.nodes:
			if known.has(nd.id):
				continue
			var acc2 := Vector2.ZERO
			var k := 0
			var f2 := 0
			for nb in a.neighbors(nd.id):
				if known.has(nb):
					acc2 += known[nb]
					f2 = maxi(f2, fl[nb])
					k += 1
			if k > 0:
				var ang: float = float(nd.id) * 2.39996
				known[nd.id] = acc2 / k + Vector2(cos(ang), sin(ang)) * 1.6
				fl[nd.id] = f2
	for nd in a.nodes:   # anything still unplaced goes round the structure centre (below)
		pass
	# separate: nodes at least 2.2 squares apart so icons and labels don't pile up
	var ids := known.keys()
	for it in 30:
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var pa: Vector2 = known[ids[i]]
				var pb: Vector2 = known[ids[j]]
				var dv := pb - pa
				var dl := dv.length()
				if dl < 2.2:
					var push := (dv / maxf(dl, 0.01) if dl > 0.01 else Vector2(cos(i), sin(i))) * (2.2 - dl) * 0.5
					known[ids[i]] = pa - push
					known[ids[j]] = pb + push
	var st_center := Vector2(m.w / 2.0, m.h / 2.0)
	if a.structure >= 0 and m.structures[a.structure].has("rect"):
		st_center = Vector2((m.structures[a.structure].rect as Rect2i).get_center())
	var pos := {}
	var ground := {}
	for nd in a.nodes:
		var xy: Vector2 = known.get(nd.id, st_center + Vector2(cos(nd.id * 2.4), sin(nd.id * 2.4)) * 2.0)
		var f3: int = fl.get(nd.id, 0)
		pos[nd.id] = Vector3(xy.x, f3 * FH + 1.3 + int(nd.zone) * 0.9, xy.y)
		ground[nd.id] = Vector3(xy.x, f3 * FH, xy.y)
	return [pos, ground]


# --- Cover shields and the hover inspector ---------------------------------------------------

## XCOM-style: while planning a move, the hovered square shows a holographic shield on each side
## that has cover (solid: walls and cover pieces; outlined: see-through bulletproof glass).
## Where the objective is: world points with a label and colour (the view draws a chevron over each,
## or an arrow at the screen edge with the distance when it's off screen).
var _charge_node: Node3D
var _avs := {}   ## kind → AVModel on the ground


## An AV comes down onto its landing spot; the team it carries jumps out once it's down.
func _anim_av_land(e: Dictionary) -> void:
	var cell: Vector3i = e.cell
	var at := Vector3(cell.x + 0.5, _gy(cell), cell.y + 0.5)
	for id in e.units:   # hidden until they step out
		var nn: Node3D = _unit_node(enc.units[id])
		nn.set_meta("arriving", true)
		nn.visible = false
	var av := AVModel.make(String(e.kind))
	world.add_child(av)
	_avs[String(e.kind)] = av
	await _pan_to(at, 0.5)
	hud.turn_banner("MAXTAC HAS LANDED" if e.kind == "maxtac" else "TRAUMA TEAM HAS LANDED", Hud.RED if e.kind == "maxtac" else Color("2a8cff"))
	_snd("sfx_jack_in", at, -2.0, 0.0, 0)
	var tw := av.land(at, float(e.get("yaw", 0.0)), float(e.get("scale", 1.0)))
	await tw.finished
	fx.burst(at + Vector3(0, 0.1, 0), Color("8a8070"), 30, 3.5, 0.12, 0.9, 0.0, -2.0)   # downwash dust
	_kick(Vector2(0, 1), 4.0)
	_snd("sfx_door", at, 0.0, 0.0, 0)
	for id in e.units:
		var nn2: CharModel = _unit_node(enc.units[id])
		nn2.set_meta("arriving", false)
		var dest := Vector3(enc.units[id].pos.x + 0.5, _gy(enc.units[id].pos), enc.units[id].pos.y + 0.5)
		nn2.position = at + Vector3(0, 0.4, 0)
		nn2.visible = true
		create_tween().tween_property(nn2, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD)
		await get_tree().create_timer(0.18).timeout
	_float(enc.units[e.units[0]], "MAXTAC" if e.kind == "maxtac" else "TRAUMA TEAM", Hud.RED if e.kind == "maxtac" else Color("7fd0ff"))
	await get_tree().create_timer(0.5).timeout


## Review renders (--peace=broken): the house turns, as the crew's first shot inside would do.
func _demo_peace() -> void:
	_demo_ms = Time.get_ticks_msec()
	if enc.neutral != null:
		enc._break_peace(enc.cur)
		_play_events()
		_refresh()


## Review renders (--jack=turret): a Control Node of `a` with a turret on it (-1: none).
func _turret_node_of(a: NetArchitecture) -> int:
	var turrets := {}
	for u in enc.units:
		if u.has("turret") and not u.c.dead:
			turrets[int(u.turret)] = true
	for n in a.nodes:
		if String(n.type) == "control" and (n.get("devices", []) as Array).any(func(d): return turrets.has(int(d))):
			return int(n.id)
	return -1


## Review renders (--jack=turret): if the held turret has nothing in its sights, walk the nearest
## foe into them, so the NET panel shows its FIRE TURRET rows.
func _demo_turret_target(runner: Dictionary) -> void:
	for ht in enc.held_turrets(runner.id):
		if not (ht.targets as Array).is_empty():
			return
		var tu: Dictionary = enc.units[int(ht.id)]
		for o in enc.units:
			if o.has("turret") or o.c.dead or not enc.hostile(int(tu.team), int(o.team)):
				continue
			for r in range(3, 9):
				for dy in range(-r, r + 1):
					for dx in range(-r, r + 1):
						var v := Vector3i(tu.pos.x + dx, tu.pos.y + dy, tu.pos.z)
						if m.inb(v.x, v.y) and m.walkable(v.z, Vector2i(v.x, v.y)) and not enc.occupied().has(v) and enc.los.sight(tu.pos, v).visible:
							o.pos = v
							enc.refresh_vision()
							return


func _demo_av() -> void:
	_demo_ms = Time.get_ticks_msec()
	if _av_demo == "maxtac":
		enc._maxtac_drop()
	else:   # down the first guard, give them a card, call the team and fast-forward to the landing
		for g in enc.units:
			if g.team == Encounter.OPFOR:
				g["trauma_card"] = true
				g.c.death_saves = true
				g.c.hp = 0
				g.c.unconscious = true
				break
		enc._check_end()
		enc.init.round_num += Encounter.TT_ROUNDS
		enc._tick_trauma()
	for ev in enc.events:   # frame the landing for the capture
		if ev.type == "av_land":
			cam_target = Vector3(ev.cell.x + 0.5, 0, ev.cell.y + 0.5)
			_place_camera()
	_play_events()


func _anim_av_leave(e: Dictionary) -> void:
	var av: AVModel = _avs.get(String(e.kind))
	for u in enc.units:
		if u.get("tt", false):
			(unit_nodes[u.id] as Node3D).visible = false
	if av and is_instance_valid(av):
		await _pan_to(av.position, 0.4)
		var tw := av.lift_off()
		await get_tree().create_timer(1.2).timeout
	_avs.erase(String(e.kind))
	hud.toast("THE TRAUMA TEAM AV LIFTS OFF")


## The planted charge: a dark brick on the machine with a red light blinking faster as it runs down.
func _make_charge(at: Vector3) -> void:
	_charge_node = Node3D.new()
	world.add_child(_charge_node)
	_charge_node.position = at + Vector3(0, 0.9, 0.46)
	var brick := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.2, 0.1)
	brick.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color("2a2a22")
	brick.material_override = mt
	_charge_node.add_child(brick)
	var led := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.07, 0.07, 0.02)
	led.mesh = lm
	led.material_override = _unlit(Hud.RED, 1.0, 2.5)
	led.position = Vector3(0.09, 0.03, 0.06)
	led.name = "led"
	_charge_node.add_child(led)
	var gl := OmniLight3D.new()
	gl.light_color = Hud.RED
	gl.omni_range = 2.0
	gl.light_energy = 1.5
	gl.name = "glow"
	_charge_node.add_child(gl)


func _extract_mark() -> Array:
	var acc := Vector2.ZERO
	for c2 in enc.extract_cells:
		acc += Vector2(c2.x + 0.5, c2.y + 0.5)
	acc /= maxf(1.0, enc.extract_cells.size())
	return [Vector3(acc.x, 0.3, acc.y), "EXTRACT", Hud.GOLD, Vector3i(int(acc.x), int(acc.y), 0)]


func objective_marks() -> Array:
	var out := []
	if enc == null or enc.state != "playing" or _net_cleaned:
		return out
	var tones := {"gold": Hud.GOLD, "red": Hud.RED, "cyan": Hud.CYAN}
	for mk in enc.obj.marks(fog_on):   # the objective module says where; the view draws it
		if mk.get("extract", false):
			out.append(_extract_mark())
		else:
			var c: Vector3i = mk.cell
			var wp := Vector3(c.x + 0.5, _gy(c) + float(mk.h), c.y + 0.5)
			var un: Node3D = unit_nodes.get(int(mk.get("unit", -1)))
			if un and is_instance_valid(un) and un.visible:   # over a unit in sight: ride its node through moves
				wp = un.position + Vector3(0, float(mk.h), 0)
			out.append([wp, String(mk.label), tones.get(String(mk.tone), Hud.GOLD), c])
	return out


func _runner_id() -> int:
	for u in enc.units:
		if u.team == 0 and NetRun.interface_rank(u.c) > 0:
			return u.id
	return -1


func _draw_markers(c: Control) -> void:
	var r := _safe_rect()
	var from: Vector3i = enc.cur.pos if enc and not enc.cur.is_empty() else Vector3i.ZERO
	var t := Time.get_ticks_msec() / 1000.0
	for mk in objective_marks():
		var wp: Vector3 = mk[0]
		var col: Color = mk[2]
		var sp := _to_screen(wp)
		var behind := cam.is_position_behind(wp)
		var dist := int(round(Vector3(Vector3i(mk[3]) - from).length() * 2.0))   # squares are 2 m
		if r.has_point(sp) and not behind:
			var y := sp.y - 18.0 - 4.0 * sin(t * 3.0)
			c.draw_colored_polygon(PackedVector2Array([Vector2(sp.x - 9, y - 12), Vector2(sp.x + 9, y - 12), Vector2(sp.x, y)]), col)
			c.draw_polyline(PackedVector2Array([Vector2(sp.x - 13, y - 16), Vector2(sp.x + 13, y - 16), Vector2(sp.x, y + 4), Vector2(sp.x - 13, y - 16)]), Color(col, 0.5), 1.5)
			var label := "%s  %d M" % [mk[1], dist]
			var lw := Hud.F_BOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var lp := Vector2(clampf(sp.x - lw * 0.5, r.position.x, r.end.x - lw), y - 22)   # long names stay on screen
			c.draw_string_outline(Hud.F_BOLD, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0, 0.85))
			c.draw_string(Hud.F_BOLD, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		else:
			var ctr := r.get_center()
			var dir := (sp - ctr).normalized() if not behind else (ctr - sp).normalized()
			# where the ray from the centre leaves the safe rect
			var k := INF
			if absf(dir.x) > 0.001:
				k = minf(k, (r.size.x / 2 - 24) / absf(dir.x))
			if absf(dir.y) > 0.001:
				k = minf(k, (r.size.y / 2 - 24) / absf(dir.y))
			var p := ctr + dir * k
			var side := Vector2(-dir.y, dir.x)
			c.draw_colored_polygon(PackedVector2Array([p + dir * 14, p - dir * 6 + side * 10, p - dir * 6 - side * 10]), col)
			var tag := "%s %d M" % [mk[1], dist]
			var tw := Hud.F_BOLD.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var at := p - dir * (22.0 + tw * 0.5 * absf(dir.x) + 10.0 * absf(dir.y))   # clear of the arrow, whichever edge
			at.x = clampf(at.x, r.position.x + tw * 0.5, r.end.x - tw * 0.5)
			c.draw_string_outline(Hud.F_BOLD, at - Vector2(tw * 0.5, -6), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0, 0.85))
			c.draw_string(Hud.F_BOLD, at - Vector2(tw * 0.5, -6), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _draw_cover_shields(c: Control) -> void:
	if busy or not _crew_turn() or not (move_opts.has(hover) or dash_opts.has(hover)):
		return
	var t := Time.get_ticks_msec() / 1000.0
	for d in MapGen.DIRS:
		var nb := Vector3i(hover.x + d.x, hover.y + d.y, hover.z)
		var b := enc.los.blocker(nb)
		if b == "":
			continue
		var wp := Vector3(hover.x + 0.5 + d.x * 0.45, _gy(hover) + 0.55, hover.y + 0.5 + d.y * 0.45)
		var p: Vector2 = _to_screen(wp)
		var s := 11.0
		var shape := PackedVector2Array([p + Vector2(-s, -s), p + Vector2(s, -s), p + Vector2(s, s * 0.2), p + Vector2(0, s * 1.3), p + Vector2(-s, s * 0.2), p + Vector2(-s, -s)])
		var col := Color("05d9e8")
		var a := 0.85 + 0.15 * sin(t * 6.0)
		if b != "glass":
			c.draw_colored_polygon(shape, Color(col, 0.35 * a))
		c.draw_polyline(shape, Color(col, a), 2.0)
		c.draw_polyline(PackedVector2Array([p + Vector2(-s * 0.5, -s * 0.2), p + Vector2(0, s * 0.5), p + Vector2(s * 0.5, -s * 0.2)]), Color(col, a), 2.0)


## Hold Alt: a card with what's under the cursor and its game stats.
func _inspect(v: Vector3i) -> void:
	if not m.inb(v.x, v.y):
		return
	var lines: Array[String] = []
	var head := "// INSPECT"
	var head_col := Hud.GOLD
	var u := _unit_at(v)
	if not u.is_empty():
		lines.append(Hud.stat_block(u.c, true, _unit_conditions(u)))
		head = "// INSPECT · " + ("CREW" if u.team == 0 else ("%s · %s" % [World.display_name(enc.faction_of(u)), Hud.stance(enc, int(u.team))]).to_upper())
		head_col = Hud.CYAN if u.team == 0 else Hud.stance_col(Hud.stance(enc, int(u.team)))
	var cover_hp: int = enc.los.cover_hp.get(v, 0)
	for cv in m.cover:
		if cv.floor == v.z and cv.pos == Vector2i(v.x, v.y) and cover_hp > 0:
			lines.append("[b]%s[/b]" % String(cv.kind).replace("_", " ").capitalize())
			lines.append("Material: %s%s" % [cv.material, " (thick)" if cv.thick else ""])
			lines.append("Cover · [code]%d / %d HP[/code]" % [cover_hp, int(cv.hp)])
			if String(cv.get("hazard", "")) != "":
				lines.append("[color=#ff6b1a]Hazard: %s[/color]" % cv.hazard)
	var wc := m.wall_cover(v.z, v.x, v.y)
	if not wc.is_empty():
		var t := m.t(v.z, v.x, v.y)
		var hp_left: int = enc.los.wall_hp.get(v, int(wc.hp))
		lines.append("[b]%s[/b]" % ("Door" if t == TacMap.T.DOOR else "Wall"))
		lines.append("Material: %s" % String(wc.material))
		if wc.cover:
			lines.append("Cover · [code]%d / %d HP[/code]" % [hp_left, int(wc.hp)])
		lines.append("Sight: %s" % ("blocked" if wc.blocks_los else "see-through"))
		if t == TacMap.T.DOOR:
			lines.append("Locked (security)" if enc.nav.locked.has(v) else ("Open" if enc.los.open_doors.has(v) else "Closed"))
	for d in m.devices:
		if d.floor == v.z and d.pos == Vector2i(v.x, v.y):
			var on_net := false
			for sid in m.architectures:
				for ap in m.architectures[sid].access_points:
					if ap.device == d.id:
						on_net = true
			lines.append("Device: %s%s%s" % [String(d.type).replace("_", " "), " · jack-in point" if on_net else "", " · under control" if enc.disabled_devices.has(d.id) else ""])
	if lines.is_empty():
		var t2 := m.t(v.z, v.x, v.y)
		var l := m.label(v.z, v.x, v.y)
		var what := ""
		if l >= 0 and not m.rooms[l].get("outdoor", false):
			what = String(m.rooms[l].kind).replace("_", " ").capitalize() + " · L%d" % int(m.rooms[l].zone)
		else:
			what = ["", "Asphalt", "Sidewalk", "Gravel", "Dirt", "Concrete", "Rail bed", "Dock", "Grass", "Sand"][int(m.ground[v.y * m.w + v.x])] if t2 == TacMap.T.OUTSIDE else ""
		if what == "":
			return
		lines.append("[b]%s[/b]" % what)
		lines.append("Floor %d · no cover" % (v.z + 1))
	hud.tip("\n".join(lines), mouse, head, head_col)


func _beside_cover(v: Vector3i) -> bool:
	for d in MapGen.DIRS:
		var b := enc.los.blocker(Vector3i(v.x + d.x, v.y + d.y, v.z))
		if b == "cover" or b == "wall":
			return true
	return false


func _cut_radius() -> float:
	return clampf(cam_dist * 0.3, 5.0, 13.0) if cutaway else 0.0


func _update_cut() -> void:
	var fwd := Vector2(-cam.global_transform.basis.z.x, -cam.global_transform.basis.z.z)
	RenderingServer.global_shader_parameter_set("cut_dir", fwd.normalized() if fwd.length() > 0.01 else Vector2(0, -1))
	RenderingServer.global_shader_parameter_set("cut_center", Vector3(cam_target.x, view_floor, cam_target.z))
	# see-through hole around the focus (screen UV, view depth, radius)
	if svp and svp.size.y > 0:
		# the hole follows the active crew member (it exists to keep them visible), else the focus
		var fp := Vector3(cam_target.x, view_floor * FH, cam_target.z)
		if enc and _focus_unit >= 0:
			var fu: Dictionary = enc.units[_focus_unit]
			fp = Vector3(fu.pos.x + 0.5, fu.pos.z * FH, fu.pos.y + 0.5)
		elif enc and not enc.cur.is_empty() and enc.cur.team == 0:
			fp = Vector3(enc.cur.pos.x + 0.5, enc.cur.pos.z * FH, enc.cur.pos.y + 0.5)
		var uv := cam.unproject_position(fp) / Vector2(svp.size)
		var dep := (fp - cam.global_position).dot(-cam.global_transform.basis.z)
		RenderingServer.global_shader_parameter_set("focus_view", Vector4(uv.x, uv.y, dep, 0.14))
	RenderingServer.global_shader_parameter_set("cut_radius", _cut_radius())
	_below_grade_view()


## Viewing a storey below the street lifts the street and everything above it off whole (the
## ground is solid: no cutaway radius to see into), so the basement shows as a dug-out level in
## the earth WorldBuilder packs round it; the skyline goes with the street.
func _below_grade_view() -> void:
	if m == null or m.basements == 0 or floor_nodes.size() != m.floors:
		return
	var below := view_floor < m.street
	for f in floor_nodes.size():   # from the street up the storeys below are out of sight under it
		floor_nodes[f].visible = _grade_shows(f)
	var sky := world.get_node_or_null("skyline") as Node3D
	if sky:
		sky.visible = not below
	for group in [devices, door_nodes]:   # wall kit (terminals, cameras, jack points), door leaves and lock lamps go with their storey
		if group:
			for n in group.get_children():
				if n is Node3D and n.has_meta("floor"):
					(n as Node3D).visible = _grade_shows(int(n.get_meta("floor")))
	if ambient and is_instance_valid(ambient):   # embers, wreck fires and the like hang over the street
		ambient.visible = not below


## Whether storey `f` stands in the below-grade view: viewing a basement shows it and the storeys
## under it; otherwise the street and everything above (the basements are out of sight under it).
func _grade_shows(f: int) -> bool:
	if m == null or m.basements == 0:
		return true
	return f <= view_floor if view_floor < m.street else f >= m.street


func _cut_hides(v: Vector3i) -> bool:
	if m != null and view_floor < m.street and v.z > view_floor:   # below grade: everything above is lifted off
		return true
	if v.z <= view_floor or not cutaway:
		return false
	return open_cells.has(Vector2i(v.x, v.y))


## Fog texture: R = vision state per square, G = 1 where the cutaway may open: rooms the crew is
## in or has seen into (grown by one square for their walls), on every floor so the storeys above
## them lift too. Unseen rooms keep their walls and roof (round-4 critique).
func _update_fog() -> void:
	open_cells.clear()
	var open_rooms := {}
	if cutaway and not cut_all:   # AUTO: whole buildings, only where the crew is or is heading
		var open_s := {}
		for u in enc.alive(0):
			open_s[_indoor_structure(u.pos)] = true
		open_s[_hover_sid] = true
		if _focus_unit >= 0 and _focus_unit < enc.units.size():   # playback: the unit being followed, if seen
			var fu: Dictionary = enc.units[_focus_unit]
			if fu.team == 0 or not fog_on or enc.vision.visible.has(fu.pos):
				open_s[_indoor_structure(fu.pos)] = true
		for sid in open_s:
			for l in struct_rooms.get(sid, {}):
				open_rooms[l] = true
	for u in ([] if not cut_all else enc.alive(0)):
		var l := m.label(u.pos.z, u.pos.x, u.pos.y)
		if l >= 0 and not m.rooms[l].get("outdoor", false):
			open_rooms[l] = true
	for v in (enc.vision.explored if cut_all else {}):
		var l2 := m.label(v.z, v.x, v.y)
		if l2 >= 0 and v.z <= view_floor and not m.rooms[l2].get("outdoor", false):
			open_rooms[l2] = true
	for l3 in open_rooms:
		for c in room_xy.get(l3, []):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					open_cells[Vector2i(c.x + dx, c.y + dy)] = true
	if not fog_on and cut_all:
		for st in m.structures:
			if st.has("rect"):
				var r: Rect2i = (st.rect as Rect2i).grow(1)
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						open_cells[Vector2i(x, y)] = true
	var data := PackedByteArray()
	data.resize(m.w * m.h * m.floors * 2)
	for f in m.floors:
		for y in m.h:
			for x in m.w:
				var i := ((f * m.h + y) * m.w + x) * 2
				data[i] = 255 if not fog_on else [0, 128, 255][enc.vision.state(Vector3i(x, y, f))]
	for c in open_cells:
		if m.inb(c.x, c.y):
			for f in m.floors:
				data[((f * m.h + c.y) * m.w + c.x) * 2 + 1] = 255
	fog_img.set_data(m.w, m.h * m.floors, false, Image.FORMAT_RG8, data)
	fog_tex.update(fog_img)
	_update_xray()


## The building (structure id) whose indoor room holds square v, or -1 outdoors.
func _indoor_structure(v: Vector3i) -> int:
	if not m.inb(v.x, v.y) or v.z < 0 or v.z >= m.floors:
		return -1
	var l := m.label(v.z, v.x, v.y)
	if l < 0 or m.rooms[l].get("outdoor", false):
		return -1
	return int(m.rooms[l].structure)


## Units the crew can see inside a building that is still closed (roof on) show as a silhouette
## through it: guards red, crew cyan.
func _update_xray() -> void:
	if enc == null:
		return
	for u in enc.units:
		var n = unit_nodes.get(u.id)
		if not (n is CharModel) or u.c.dead:
			if n is CharModel:
				(n as CharModel).set_xray(false)
			continue
		var seen: bool = u.team == 0 or not fog_on or enc.vision.visible.has(u.pos)
		var closed := _indoor_structure(u.pos) >= 0 and not (cutaway and open_cells.has(Vector2i(u.pos.x, u.pos.y)))
		(n as CharModel).set_xray(seen and closed and not _promo, Hud.CYAN if u.team == 0 else Hud.stance_col(Hud.stance(enc, int(u.team))))


## Door leaves: closed in the wall line, or swung open 90° on the hinge; a lock light on the frame.
func _build_doors() -> void:
	_door_leaves.clear()
	for ch in door_nodes.get_children():
		ch.queue_free()
	for d in m.doors:
		var v := Vector3i(d.pos.x, d.pos.y, d.floor)
		if m.t(d.floor, d.pos.x, d.pos.y) != TacMap.T.DOOR or (fog_on and not enc.vision.explored.has(v)):
			continue
		var leaf := builder.door_leaf(d)
		var horiz: bool = leaf.horiz
		var c: Vector3 = leaf.center
		var open: bool = enc.los.open_doors.has(v)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.material = builder.mat("door", d.floor)   # world shader: obeys cutaway and fog
		bm.size = Vector3(0.88, 1.1, 0.05) if horiz else Vector3(0.05, 1.1, 0.88)
		mi.mesh = bm
		mi.position = c
		mi.set_meta("closed", c)
		mi.set_meta("open_at", c + (Vector3(-0.44, 0, 0.44) if horiz else Vector3(0.44, 0, -0.44)))
		if open:
			mi.position = mi.get_meta("open_at")
			mi.rotation.y = PI / 2
		mi.set_meta("floor", d.floor)
		mi.visible = _grade_shows(d.floor)
		door_nodes.add_child(mi)
		_door_leaves[v] = mi
		var lamp := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.09, 0.11, 0.09)
		var locked: bool = enc.nav.locked.has(v)
		lm.material = builder.mat("dark", d.floor, true, {"glow": 1.2, "emit": Color("ff3b4f") if locked else Color("39f0a0")})
		lamp.mesh = lm
		lamp.position = c + (Vector3(0.47, 0.05, 0.26) if horiz else Vector3(0.26, 0.05, 0.47))
		lamp.set_meta("floor", d.floor)
		lamp.visible = mi.visible
		door_nodes.add_child(lamp)


## Move range as a soft contour (a cubic-upscaled mask drawn by the RANGE shader): no tiles,
## no stair-steps; the hovered path is a ribbon.
func _draw_grid() -> void:
	move_opts = {}
	dash_opts = {}
	if _crew_turn() and enc.turn.can_move():
		move_opts = enc.move_options()
	if _crew_turn():
		dash_opts = enc.run_options()
	var data := PackedByteArray()
	data.resize(m.w * m.h * 2)
	for v in move_opts:
		if v.z == view_floor:
			data[(v.y * m.w + v.x) * 2] = 255
	if not move_opts.is_empty():   # draw-only: the contour never wraps a teammate's square
		for u in enc.alive(0):
			if u.pos.z == view_floor:
				data[(u.pos.y * m.w + u.pos.x) * 2] = 255
				data[(u.pos.y * m.w + u.pos.x) * 2 + 1] = 255
	for v in dash_opts:
		if v.z == view_floor:
			data[(v.y * m.w + v.x) * 2 + 1] = 255
	grid_node.visible = not (move_opts.is_empty() and dash_opts.is_empty())
	_watchers.clear()
	if grid_node.visible:
		range_img.set_data(m.w, m.h, false, Image.FORMAT_RG8, data)
		var big := range_img.duplicate() as Image
		big.resize(m.w * 4, m.h * 4, Image.INTERPOLATE_CUBIC)
		if range_tex == null:
			range_tex = ImageTexture.create_from_image(big)
		else:
			range_tex.update(big)
		(grid_node.material_override as ShaderMaterial).set_shader_parameter("mask", range_tex)
		grid_node.position.y = view_floor * FH + 0.1
	_draw_path()
	_draw_watch(grid_node.visible)


func _draw_path() -> void:
	var pts: Array[Vector3] = []
	_path_cells.clear()
	# Only while a move can be chosen: not during playback (the options are the last turn's, and
	# enc.cur may already be the next unit), and over the normal and the Run (amber) range alike.
	if not busy and _crew_turn() and (move_opts.has(hover) or dash_opts.has(hover)):
		_path_cells = enc.move_preview(hover)
		for c in _path_cells:
			pts.append(Vector3(c.x + 0.5, c.z * FH + 0.12, c.y + 0.5))
	if pts.size() < 2:
		path_node.mesh = null
		return
	# Catmull-Rom through square centres, then a flat ribbon with an end diamond
	var smooth: Array[Vector3] = []
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for k in 4:
			var t := k / 4.0
			smooth.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	smooth.append(pts[-1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.05
	for i in smooth.size() - 1:
		var a := smooth[i]
		var b := smooth[i + 1]
		var side := (b - a).cross(Vector3.UP).normalized() * w
		for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
			st.add_vertex(v)
	var e := pts[-1] + Vector3(0, 0.01, 0)
	for v in [e + Vector3(-0.2, 0, 0), e + Vector3(0, 0, -0.2), e + Vector3(0.2, 0, 0), e + Vector3(-0.2, 0, 0), e + Vector3(0.2, 0, 0), e + Vector3(0, 0, 0.2)]:
		st.add_vertex(v)
	var mesh := st.commit()
	var ws := _watch_status()   # the ribbon warns: red through watched ground, amber at its edge
	var mt := _unlit(Hud.RED if ws.seen > 0 else (Color("ff8a24") if ws.near else Color("f9c80e")), 1.0, 1.0)
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mt)
	path_node.mesh = mesh


## Pitch follows zoom (close: low, to see facades and signs; far: high, a planning view). In
## orthographic mode the camera is snapped to the buffer's texel grid and the sub-texel remainder
## is applied as a screen-space shift, so the pixel art doesn't crawl while panning.
func _place_camera() -> void:
	var fy := view_floor * FH
	var pitch := deg_to_rad(lerpf(36.0, 62.0, clampf(inverse_lerp(12.0, 70.0, cam_dist), 0.0, 1.0)))
	if _promo and m:   # beauty renders: keep the frame on the map (r8 review: half the frame was off-map void)
		var half_h := cam_dist * 0.62 / 2.0 / sin(pitch)
		var vs := get_viewport().get_visible_rect().size
		var half_w := cam_dist * 0.62 / 2.0 * (vs.x / maxf(vs.y, 1.0))
		var yr := deg_to_rad(cam_yaw)
		var right := Vector2(cos(yr), -sin(yr))
		var fwd := Vector2(sin(yr), cos(yr))
		var ex := 0.0
		var ez := 0.0
		for c in [right * half_w + fwd * half_h, right * half_w - fwd * half_h]:
			ex = maxf(ex, absf(c.x))
			ez = maxf(ez, absf(c.y))
		cam_target.x = m.w / 2.0 if m.w < ex * 2.0 else clampf(cam_target.x, ex, m.w - ex)
		cam_target.z = m.h / 2.0 if m.h < ez * 2.0 else clampf(cam_target.z, ez, m.h - ez)
	var off := Vector3(0, sin(pitch), cos(pitch)).rotated(Vector3.UP, deg_to_rad(cam_yaw)) * cam_dist
	var focus := cam_target + Vector3(0, fy, 0)
	cam.position = focus + off
	cam.look_at(focus)
	cam.size = cam_dist * 0.62
	var px := _px()
	var shift := Vector2.ZERO
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL and svp.size.y > 0:
		var texel := cam.size / float(svp.size.y)
		var bx := cam.global_transform.basis.x
		var by := cam.global_transform.basis.y
		var lx := bx.dot(cam.position)
		var ly := by.dot(cam.position)
		var sx := roundf(lx / texel) * texel
		var sy := roundf(ly / texel) * texel
		cam.position += bx * (sx - lx) + by * (sy - ly)
		shift = Vector2(-(lx - sx), (ly - sy)) / texel * px
	_screen_base = Vector2(-px, -px) + shift
	screen.position = _screen_base + _shake_px.round() * px
	var sd: Array = _scene_look().get("sun", [])
	sun.rotation_degrees = Vector3(sd[0], sd[1], 0) if not sd.is_empty() else Vector3(-55, cam_yaw + 35, 0)   # a real sun stays put
	if enc and not unit_nodes.is_empty():
		_update_outlines()
	if rim:
		rim.rotation_degrees = Vector3(-30, cam_yaw + 190, 0)
	if unit_key:   # from over the camera's shoulder, whatever the scene's sun does
		unit_key.rotation_degrees = Vector3(-40, cam_yaw + 20, 0)
	_update_cut()


## Put the unit a little above screen centre (the hotbar covers the bottom), clamped to the map.
func _frame_unit(u: Dictionary) -> void:
	var fwd := Vector2(-sin(deg_to_rad(cam_yaw)), -cos(deg_to_rad(cam_yaw)))
	var p := Vector2(u.pos.x + 0.5, u.pos.y + 0.5) - fwd * cam_dist * 0.12
	if _last_cur == -1 and m.w > 40:   # first turn on a big map: lean toward the middle (objective)
		p += (Vector2(m.w / 2.0, m.h / 2.0) - p).limit_length(cam_dist * 0.2)   # but keep the unit in view
	cam_target = Vector3(clampf(p.x, 0, m.w), 0, clampf(p.y, 0, m.h))
	view_floor = u.pos.z
	_place_camera()


## Guards' sight lines (XCOM concealment, owner round 5: the old red tiles were loud). While the
## crew is undetected and planning, the watched ground is drawn as a dashed contour with a faint
## hatch: by default only for the guards and cameras that would see the hovered move (or are within
## two squares of it), and for a hovered guard; Z shows all of them, or none.
func _draw_watch(show: bool) -> void:
	if watch_node == null or not is_instance_valid(watch_node) or watch_node.get_parent() != world:
		watch_node = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(m.w, m.h)
		watch_node.mesh = pm
		watch_node.position = Vector3(m.w / 2.0, 0, m.h / 2.0)
		var sh := Shader.new()
		sh.code = WATCH
		var mt := ShaderMaterial.new()
		mt.shader = sh
		mt.set_shader_parameter("col", Hud.RED)
		watch_node.material_override = mt
		watch_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		watch_img = Image.create(m.w, m.h, false, Image.FORMAT_RG8)
		watch_tex = null
		world.add_child(watch_node)
	var cells := {}
	if show and sight_mode != 2 and enc.alarm < 2 and not _net_cleaned:
		var w := _watch_map()
		if sight_mode == 1:
			for k in w:
				cells.merge(w[k])
		else:
			for k in _relevant_watchers():
				cells.merge(w[k])
	watch_node.visible = not cells.is_empty()
	if cells.is_empty():
		return
	var data := PackedByteArray()
	data.resize(m.w * m.h * 2)
	for v in cells:
		data[(v.y * m.w + v.x) * 2] = 255
	for v in _path_cells:
		if cells.has(v):
			data[(v.y * m.w + v.x) * 2 + 1] = 255
	watch_img.set_data(m.w, m.h, false, Image.FORMAT_RG8, data)
	var big := watch_img.duplicate() as Image
	big.resize(m.w * 4, m.h * 4, Image.INTERPOLATE_CUBIC)
	if watch_tex == null:
		watch_tex = ImageTexture.create_from_image(big)
	else:
		watch_tex.update(big)
	(watch_node.material_override as ShaderMaterial).set_shader_parameter("mask", watch_tex)
	watch_node.position.y = view_floor * FH + 0.11


## Every live watcher the crew knows about on this floor → the squares it watches (cached until
## the grid is redrawn).
func _watch_map() -> Dictionary:
	if not _watchers.is_empty() or enc.alarm >= 2:
		return _watchers
	for g in enc.units:
		if enc.is_guard(g) and _foe(g) and not g.alerted and g.c.can_act() and g.pos.z == view_floor and (not fog_on or enc.vision.visible.has(g.pos)):
			_watchers["g%d" % g.id] = enc.watched_cells(g)
	for d in m.devices:   # live cameras the crew has seen watch their floor too
		var cp := Vector3i(d.pos.x, d.pos.y, d.floor)
		if String(d.type) == "camera" and not enc.disabled_devices.has(d.id) and cp.z == view_floor and (not fog_on or enc.vision.explored.has(cp)):
			_watchers["c%d" % d.id] = enc.camera_cells(d)
	return _watchers


## Watchers worth showing right now: those that see the hovered path or come within two squares of
## its end, and a hovered guard.
func _relevant_watchers() -> Array:
	var out := []
	if not _crew_turn():
		return out
	var w := _watch_map()
	var hu := _unit_at(hover)
	if not hu.is_empty() and _foe(hu) and w.has("g%d" % hu.id):
		out.append("g%d" % hu.id)
	var dest := hover if (move_opts.has(hover) or dash_opts.has(hover)) else Vector3i(-1, -1, -1)
	if dest.x < 0:
		return out
	for k in w:
		if k in out:
			continue
		var cs: Dictionary = w[k]
		var hit := _path_cells.any(func(v): return cs.has(v)) or cs.has(dest)
		if not hit:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if cs.has(dest + Vector3i(dx, dy, 0)):
						hit = true
		if hit:
			out.append(k)
	return out


## How exposed the hovered move is: watchers that would see a square of it, and whether its end is
## within two squares of watched ground (the edge of someone's sight).
func _watch_status() -> Dictionary:
	var res := {"seen": 0, "near": false}
	if not _crew_turn() or enc.alarm >= 2 or _path_cells.is_empty():
		return res
	var dest: Vector3i = _path_cells[-1]
	var w := _watch_map()
	for k in w:
		var cs: Dictionary = w[k]
		if _path_cells.slice(1).any(func(v): return cs.has(v)):
			res.seen += 1
			continue
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if cs.has(dest + Vector3i(dx, dy, 0)):
					res.near = true
	return res


## Alt held: an outline round every enemy the crew can see (owner: no rings or glows under units).
func _update_outlines() -> void:
	for u in enc.units:
		var n = unit_nodes.get(u.id)
		if n is CharModel:
			var melee: bool = int(_mh.get("tid", -1)) == u.id and not u.c.dead   # the melee hover's target
			(n as CharModel).set_outline(melee or _alt_on and not _promo and _foe(u) and not u.c.dead and _seen(u.pos), Hud.RED)


## With Alt held, a faint
## mark on each enemy's last-known square while they're out of sight.
func _draw_aim(c: Control) -> void:
	if enc == null or _promo:
		return
	if _alt_on:
		_draw_last_known(c)
		_draw_range_labels(c)


## Alt with a gun's shot line showing (owner: "bracket ticks"): where the shooter's range bracket
## changes along the line, from the muzzle out to the weapon's reach or the map's edge. The book's
## range table (single shot, or Autofire's own when that's the armed mode, p173) via RangeCurve.
## Each mark: {at: Vector3, edge: bool (a tick) or a label point mid-bracket, dv, chance, past}.
var _range_marks: Array = []


func _calc_range_marks(o: Vector3) -> Array:
	var out: Array = []
	if not _alt_on or String(_aim.get("shape", "")) != AimPreview.LINE or String(_aim.get("wid", "")) == "":
		return out
	var w: Weapon = null
	for cw in enc.cur.c.weapons:
		if cw.id() == String(_aim.wid):
			w = cw
			break
	if w == null or w.is_melee():
		return out
	var md: int = _aim.get("mode", Attack.Mode.SINGLE)
	var brs := RangeCurve.brackets_for(w, md)
	if brs.is_empty():
		return out
	var c: Combatant = enc.cur.c
	var base := Attack.attack_base(c, w, md)
	var nf := c.awareness_level("fumble_recovery") > 0
	var fsq: Vector3i = _aim.fsq
	var c0 := Vector3(fsq.x + 0.5, 0, fsq.y + 0.5)
	var to: Vector3 = _aim.to
	var flat := Vector3(to.x - c0.x, 0, to.z - c0.z)
	var tlen := flat.length()
	if tlen < 0.01:
		return out
	var dir := flat / tlen
	var auto := md == Attack.Mode.AUTOFIRE
	var reach_m := RangeCurve.max_range_m(String(w.def.get("autofire_range" if auto else "range", "")), auto, float(w.fx().get("max_range_m", 0.0)))
	var lim := minf(reach_m / 2.0, _ray_to_map_edge(c0, dir))   # a square is 2 m (p127), 1 world unit
	var tgt_m := tlen * 2.0
	var at := func(d_m: float) -> Vector3:   # along the shot line's slope, kept near it beyond the target
		var k := d_m / 2.0
		var y := lerpf(o.y, to.y, k / tlen)
		return Vector3(c0.x + dir.x * k, clampf(y, o.y - 1.0, o.y + 1.0), c0.z + dir.z * k)
	for i in brs.size():
		var a_m := float(brs[i][0])
		if a_m / 2.0 >= lim:
			break
		var b_m := minf(float(brs[i + 1][0]) if i + 1 < brs.size() else reach_m, lim * 2.0)
		var dv := int(brs[i][1])
		var ch := Check.chance_vs_dv(base, dv, nf)
		if a_m > 0.0:
			out.append({"at": at.call(a_m), "edge": true, "dv": dv, "chance": ch, "past": a_m > tgt_m + 0.5})
		out.append({"at": at.call((a_m + b_m) / 2.0), "edge": false, "dv": dv, "chance": ch, "past": (a_m + b_m) / 2.0 > tgt_m + 0.5})
	if lim * 2.0 >= reach_m - 0.01:   # the weapon's reach ends on the map: a last tick there
		out.append({"at": at.call(reach_m), "edge": true, "dv": -1, "chance": 0.0, "past": reach_m > tgt_m + 0.5})
	return out


## World units from `p` along the flat direction `dir` to the map's edge.
func _ray_to_map_edge(p: Vector3, dir: Vector3) -> float:
	var t := INF
	if dir.x > 0.0001:
		t = minf(t, (m.w - p.x) / dir.x)
	elif dir.x < -0.0001:
		t = minf(t, -p.x / dir.x)
	if dir.z > 0.0001:
		t = minf(t, (m.h - p.z) / dir.z)
	elif dir.z < -0.0001:
		t = minf(t, -p.z / dir.z)
	return maxf(0.0, t)


## The ticks' DV labels, on the HUD layer (after the pixel shader), in the HUD's smallest face,
## coloured by the hit chance in that bracket; past the target, a little faded.
func _draw_range_labels(c: Control) -> void:
	var vp := c.get_viewport_rect().size
	for mk in _range_marks:
		if mk.edge:
			continue
		var p: Vector2 = _to_screen(mk.at)
		if p.x < 0 or p.y < 0 or p.x > vp.x or p.y > vp.y:
			continue
		var ch: float = mk.chance
		var col := Hud.GREEN if ch >= 0.65 else (Hud.GOLD if ch >= 0.35 else Hud.RED)
		var a := 0.55 if mk.past else 1.0
		var txt := "DV%d" % int(mk.dv)
		var tw := Hud.F_TERM.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var at := p + Vector2(-tw / 2.0, -8)
		c.draw_string_outline(Hud.F_TERM, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color(0, 0, 0, 0.85 * a))
		c.draw_string(Hud.F_TERM, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col, a))


## The hovered attack's preview in the 3D world, every frame (the muzzle and the sway move):
## guns a thin scrolling dashed line from just ahead of the muzzle to centre mass or the head (an
## X where it's blocked), throws the same along a parabola from the hand, melee a wind-up pose,
## a slice on the floor toward the target and the target outlined (owner: no rings under units).
func _sync_aim_fx() -> void:
	if world == null or not is_instance_valid(world):
		return
	if aim_fx == null or not is_instance_valid(aim_fx):
		aim_fx = AimFx.new()
		world.add_child(aim_fx)
	var on := enc != null and not _aim.is_empty() and not busy and not _promo and _crew_turn()
	var shape := String(_aim.get("shape", "")) if on else ""
	if shape != AimPreview.SWING:
		_end_melee_hover()
	_range_marks = []
	if not on:
		aim_fx.clear()
		return
	aim_fx.set_ticks([], Vector3.ZERO, 0.0, 0.0)
	var sn: Node3D = unit_nodes.get(enc.cur.id)
	var col: Color = _aim.col
	aim_fx.set_cross(false)
	aim_fx.set_slice(false)
	match shape:
		AimPreview.LINE:
			var mz: Vector3 = _muzzle_of(sn) if sn else _aim.from
			var fsq: Vector3i = _aim.fsq
			if fsq != enc.cur.pos:   # leaning out of cover to fire
				mz += Vector3(fsq.x - enc.cur.pos.x, 0, fsq.y - enc.cur.pos.y).normalized() * 0.35
			var o := AimPreview.muzzle_origin(mz, _aim.to)
			var paths := [[PackedVector3Array([o, _aim.to]), col]]
			if _aim.has("stop"):   # no line of fire: it stops at what's in the way, faint beyond
				var sp := AimPreview.stop_point(o, _aim.to, _aim.stop)
				paths = [[PackedVector3Array([o, sp]), col], [PackedVector3Array([sp, _aim.to]), Color(Hud.RED, 0.4)]]
				aim_fx.set_cross(true, sp)
			aim_fx.set_paths(paths, cam.global_position, _line_width(o.lerp(_aim.to, 0.5)))
			_range_marks = _calc_range_marks(o)
			var ticks: Array = []
			for mk in _range_marks:
				if mk.edge:
					ticks.append([mk.at, Color(Color("e8eef2"), 0.4 if mk.past else 0.85)])
			aim_fx.set_ticks(ticks, cam.global_position, _line_width(o) * 1.4, 0.22, Vector3(_aim.to - o).normalized())
		AimPreview.THROW:
			var h: Vector3 = (sn as CharModel).hand_point() if sn is CharModel else _aim.from
			var o := AimPreview.muzzle_origin(h, _aim.to)
			var arc := AimPreview.arc_points(o, _aim.to, AimPreview.peak_for(Vector3(_aim.to - o).length()), 24)
			aim_fx.set_paths([[arc, col]], cam.global_position, _line_width(arc[12]))
		AimPreview.SWING:
			aim_fx.set_paths([], cam.global_position, 0.0)
			_melee_hover(sn, col)


## About one low-res buffer pixel at `p`, in world units.
func _line_width(p: Vector3) -> float:
	var span := cam.size if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else 2.0 * cam.global_position.distance_to(p) * tan(deg_to_rad(cam.fov) * 0.5)
	return span / maxf(1.0, float(svp.size.y)) * 1.3


## Melee hover (BG3-style): the attacker turns to the target and holds the wind-up of their swing.
func _melee_hover(sn: Node3D, col: Color) -> void:
	if sn == null:
		return
	var tid := int(_aim.get("tid", -1))
	if _mh.get("node") != sn or int(_mh.get("tid", -2)) != tid:
		_end_melee_hover()
		_mh = {"node": sn, "tid": tid, "yaw": sn.rotation.y}
		_update_outlines()
	var me := Vector3(sn.global_position.x, _gy(enc.cur.pos) + 0.03, sn.global_position.z)
	var yaw := AimPreview.face_yaw(me, _aim.to)
	sn.rotation.y = yaw
	if sn is CharModel:
		var wu := AimPreview.windup(String(_aim.get("wid", "brawling")))
		(sn as CharModel).windup(wu[0], wu[1])
	aim_fx.set_slice(true, me, yaw, Color(col, 0.9), AimPreview.SLICE_REACH_M / AimPreview.SQUARE_M)


## The melee hover ended: back to the idle and the old facing (an attack that starts turns anyway).
func _end_melee_hover() -> void:
	if _mh.is_empty():
		return
	var n = _mh.get("node")
	var yaw := float(_mh.yaw)
	_mh = {}
	if is_instance_valid(n):
		if n is CharModel:
			(n as CharModel).end_windup()
		if not busy:
			(n as Node3D).rotation.y = yaw
	_update_outlines()


func _draw_last_known(c: Control) -> void:
	var a := 0.4 + 0.1 * sin(Time.get_ticks_msec() / 300.0)
	for u in enc.units:
		if not _last_known.has(u.id) or (_seen(u.pos) and not u.c.dead):
			continue
		var v: Vector3i = _last_known[u.id]
		if _seen(v) or v.z != view_floor:   # in sight now and not there: they've moved on
			continue
		var wp := Vector3(v.x + 0.5, _gy(v) + 1.2, v.y + 0.5)
		if cam.is_position_behind(wp):
			continue
		var p := _to_screen(wp)
		var d := PackedVector2Array([p + Vector2(0, -12), p + Vector2(9, 0), p + Vector2(0, 12), p + Vector2(-9, 0), p + Vector2(0, -12)])
		c.draw_polyline(d, Color(Hud.RED, a), 2.0)
		c.draw_string(Hud.F_BOLD, p + Vector2(-4, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Hud.RED, a))


func _make_caret() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()   # a 4-sided cone, point down: a caret
	cm.top_radius = 0.13
	cm.bottom_radius = 0.0
	cm.height = 0.2
	cm.radial_segments = 4
	cm.rings = 1
	cm.material = _unlit(Color("ffb000"), 1.0, 1.4)
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	return mi


## The HUD's floor label, plain (owner): "FLOOR 1", "FLOOR 2" ... from the street up, "FLOOR B1",
## "FLOOR B2" below it; no counter, on every map.
static func floor_label(mp: TacMap, f: int) -> String:
	return "FLOOR %s" % mp.floor_name(f)


## The HUD's place label: a set piece by its name (an estate by its owner's), a board gig by its
## place (Campaign.place_name), anything else by its scene.
static func place_label(mp: TacMap, active: Dictionary, scene: String) -> String:
	if SetPieces.has(String(mp.params.get("setpiece", ""))):
		return SetPieces.place_name(mp)
	if not active.is_empty():
		return Campaign.place_name(active)
	return String(mp.params.get("scene", scene)).replace("_", " ")


## Height of the walkable surface of a square (sidewalks are raised by a kerb).
func _gy(v: Vector3i) -> float:
	var y := v.z * FH
	if v.z == m.street and m.inb(v.x, v.y) and m.t(v.z, v.x, v.y) == TacMap.T.OUTSIDE and m.label(v.z, v.x, v.y) < 0 \
			and m.ground[v.y * m.w + v.x] == TacMap.G.SIDEWALK:
		y += KERB
	return y


func _to_screen(p: Vector3) -> Vector2:
	return cam.unproject_position(p) * _px() + screen.position


# --- Input ------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		if ev.button_mask & MOUSE_BUTTON_MASK_MIDDLE:   # middle-drag: free rotation
			cam_yaw = wrapf(cam_yaw - ev.relative.x * 0.35, 0.0, 360.0)
			_place_camera()
		mouse = ev.position
		if net_overlay.visible:
			net_overlay.hot = net_overlay.pick(mouse)
		var h := _pick(ev.position)
		if h != hover:
			hover = h
			_on_hover_changed()
		if not _inspected:
			_update_hover()
	elif ev is InputEventMouseButton and ev.pressed:
		if busy and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP: cam_dist = maxf(8, cam_dist * 0.9); _place_camera()
			MOUSE_BUTTON_WHEEL_DOWN: cam_dist = minf(160, cam_dist * 1.1); _place_camera()
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:   # right moves, left attacks (ClickIntent)
				var run := _net_active()
				var t: Dictionary = _unit_at(hover) if enc else {}
				match ClickIntent.of(ev.button_index, ev.shift_pressed, run != null, tool, cover_mode, not t.is_empty() and _foe(t)):
					ClickIntent.NET:
						var id := net_overlay.pick(ev.position)
						if id >= 0 and id != run.current:
							if run.can_move_to(id):
								_on_hud("net_move", id)
							else:
								hud.toast("Blocked: break the firewall or deal with the ICE first.")
					ClickIntent.MOVE: _click_move()
					ClickIntent.TOOL: _click_tool()
					ClickIntent.COVER: _click_attack(true)
					ClickIntent.ATTACK: _click_attack(false)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if _end_key(ev.keycode):   # the gig is over: the end panel takes Enter, Space and Esc first
			get_viewport().set_input_as_handled()
			return
		match ev.keycode:
			KEY_Q, KEY_E: _turn_keys[ev.keycode] = true   # turns while held (_process)
			KEY_H: hud.toggle_hint()
			KEY_K: hud.toggle_log()   # collapse / show the combat log (the chevron does the same)
			KEY_PAGEUP: view_floor = mini(view_floor + 1, m.floors - 1); _place_camera(); _refresh()
			KEY_PAGEDOWN: view_floor = maxi(view_floor - 1, 0); _place_camera(); _refresh()
			KEY_C:
				if not cutaway:
					cutaway = true
					cut_all = false
				elif not cut_all:
					cut_all = true
				else:
					cutaway = false
				hud.toast("CUTAWAY: " + ("OFF" if not cutaway else ("ALL SEEN ROOMS" if cut_all else "AUTO")))
				_refresh()
			KEY_Z:
				sight_mode = (sight_mode + 1) % 3
				hud.toast("GUARD SIGHT LINES: " + ["NEAR YOUR MOVE", "ALWAYS", "OFF"][sight_mode])
				_draw_grid()
			# Letters only (owner): F attack (again: next attack), Tab next weapon, R reload, G kit,
			# J jack in/out, B interact, T stabilize, V role ability, L withdraw, Space end turn.
			KEY_F:
				if stage == "attack":
					_on_hud("atk_cycle", null)
				else:
					_on_hud("stage", "attack")
			KEY_TAB:
				if stage != "attack":
					_on_hud("stage", "attack")
				_on_hud("draw_next", null)
			KEY_G: _on_hud("kit", 0)
			KEY_T: _on_hud("tool", "stabilize")
			KEY_B: _on_hud("interact", null)
			KEY_V: _on_hud("role", null)
			KEY_L: _on_hud("withdraw", null)
			KEY_ESCAPE:
				if tool != "" or stage != "main" or cover_mode:
					_back_to_main()
					_refresh(); _update_hover()
			KEY_R: _on_hud("reload", null)
			KEY_J: _on_hud("jack_in", null)   # JACK OUT while jacked in
			KEY_SPACE: _on_hud("end_turn", null)
			KEY_F1: gig.seed += 1; new_gig()
			KEY_F2: hud.settings.visible = not hud.settings.visible
			KEY_F3: fog_on = not fog_on; _refresh()
			KEY_F4:
				look.net_style = float(NET_CYCLE[(NET_CYCLE.find(int(look.net_style)) + 1) % NET_CYCLE.size()])
				hud.toast("CYBERSPACE STYLE: " + NET_STYLES[int(look.net_style)])
				_refresh()
			KEY_N: net_view = not net_view; _refresh()


func _on_hud(name: String, arg: Variant) -> void:
	if name == "portrait_hover":   # [unit id or -1, portrait rect]: hover tracking, even while busy
		_portrait_hover(int(arg[0]), arg[1])
		return
	if busy:
		return
	match name:
		"portrait_click":   # clicking a foe's portrait does what clicking their figure would
			if _aim_armed() and _portrait_target(int(arg)):
				if tool != "":
					_click_tool()
				else:
					_click_attack(cover_mode)
		"stage":
			if String(arg) == "attack" and stage != "attack":
				if not _spend_check():
					return
				stage = "attack"
				var w0: Weapon = enc.cur.c.weapons[0] if not enc.cur.c.weapons.is_empty() else null
				_arm(Encounter.attack_modes(w0)[0] if w0 else "brawl")
			else:
				_back_to_main()
			_refresh(); _update_hover()
		"atk_mode":
			_arm(String(arg))
			_refresh(); _update_hover()
		"atk_cycle":
			var ms := Encounter.attack_modes(null if atk_mode == "brawl" else (enc.cur.c.weapons[0] if not enc.cur.c.weapons.is_empty() else null))
			_arm(ms[(ms.find(atk_mode if atk_mode != "brawl" else "melee") + 1) % ms.size()] if atk_mode != "brawl" else "brawl")
			_refresh(); _update_hover()
		"draw", "draw_next":   # drawing a carried weapon is free with a hand free (p.128)
			var tabs := Hud.weapon_tabs(enc.cur.c)
			var at := tabs.size() - 1 if atk_mode == "brawl" else tabs.find(enc.cur.c.weapons[0] if not enc.cur.c.weapons.is_empty() else null)
			var pick: Variant = tabs[int(arg)] if name == "draw" else tabs[(at + 1) % tabs.size()]
			if pick == null:
				_arm("brawl")
			else:
				enc.draw(pick)
				_arm(Encounter.attack_modes(pick)[0])
			_refresh(); _update_hover()
		"interact":
			if _crew_turn() and _spend_check():
				var here := Hud.interact_here(enc)
				if here.is_empty():
					hud.toast("NOTHING TO INTERACT WITH HERE")
				else:
					_on_hud(String(here[0]), null)
		"role":
			if _crew_turn() and _spend_check():
				var ra := Hud.role_action(enc.cur.c)
				if not ra.is_empty():
					_on_hud("tool", String(ra[0]))
		"tool":
			tool = "" if tool == String(arg) else String(arg)
			cover_mode = false
			_refresh(); _update_hover()
		"suppress": _suppress()
		"kit":   # the packed consumable: a grenade picks a square; a drug is taken at once
			if not _crew_turn():
				return
			var slot := int(arg)
			match enc.kit_action(slot):
				"grenade":
					tool = "" if tool == "grenade" else "grenade"
					cover_mode = false
					_refresh(); _update_hover()
				"dose":
					var rd: Dictionary = enc.take_dose(slot)
					if rd.ok:
						_after_action()
					else:
						hud.toast(String(rd.reason).to_upper())
		"plant":
			if _crew_turn():
				var rp: Dictionary = enc.plant_charge()
				if not rp.ok:
					hud.toast(String(rp.reason).to_upper())
				_after_action()
		"free":
			if _crew_turn():
				var r: Dictionary = enc.free_captive()
				if not r.ok:
					hud.toast(String(r.reason).to_upper())
				_after_action()
		"grab":
			if _crew_turn():
				var r := enc.grab()
				if not r.get("ok", false):
					hud.toast(String(r.get("reason", "can't")))
				_after_action()
		"bypass":
			if _crew_turn():
				var rb := enc.bypass_lock()
				if not rb.get("ok", false):
					hud.toast(String(rb.get("reason", "can't")))
				_after_action()
		"keycard":
			if _crew_turn():
				var rk := enc.loot_keycard()
				if not rk.get("ok", false):
					hud.toast(String(rk.get("reason", "can't")))
				_after_action()
		"tamper":
			if _crew_turn():
				var rt := enc.tamper_camera()
				if not rt.get("ok", false):
					hud.toast(String(rt.get("reason", "can't")))
				_after_action()
		"withdraw":
			if not _crew_turn() or not enc.can_withdraw():
				hud.toast("Everyone still standing must be in the deploy zone")
			elif Time.get_ticks_msec() - _withdraw_ask > 3000:
				_withdraw_ask = Time.get_ticks_msec()
				var lb := enc.left_behind()
				hud.toast("WITHDRAW? PRESS AGAIN" + ("  ·  LEAVING %d BEHIND" % lb.size() if not lb.is_empty() else ""), 3.0)
			else:
				enc.withdraw()
				_after_action()
		"reload": _reload()
		"jack_in":
			if _crew_turn() and enc.runs.has(enc.cur.id):
				_on_hud("net", "jack_out")
			else:
				_jack_in()
		"end_turn": _end_turn()
		"net":
			if _crew_turn():
				var r := enc.net_action(String(arg))
				if not r.get("ok", false):
					hud.toast(String(r.get("reason", "can't")))
				elif r.has("success"):
					_float(enc.cur, "%s %s" % [String(arg).replace("_", "-").to_upper(), "OK" if r.success else "FAILED"], Color("d68cff"))
				_after_action()
		"net_move":
			if _crew_turn():   # not once the gig is over (a won data leg ends inside the NET)
				if not enc.net_move(int(arg)):
					hud.toast("Blocked by a firewall or ICE.")
				_after_action()
		"net_turret":   # [turret unit id, target unit id]: fire a held turret (Encounter.fire_turret)
			if _crew_turn():
				var rt: Dictionary = enc.fire_turret(int(arg[0]), int(arg[1]))
				if not rt.get("ok", false):
					hud.toast(String(rt.get("reason", "can't")).to_upper())
				_after_action()
		"net_slide":
			if _crew_turn():
				var rs := enc.net_action("slide", int(arg))
				if not rs.get("ok", false):
					hud.toast(String(rs.get("reason", "can't")))
				else:
					_float(enc.cur, "SLIDE %s" % ("OK" if rs.success else "FAILED"), Color("d68cff"))
				_after_action()


func _pick(screen_pos: Vector2) -> Vector3i:
	var sp := (screen_pos - screen.position) / _px()
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	var hit: Variant = Plane(Vector3.UP, view_floor * FH).intersects_ray(o, d)
	if hit == null:
		return Vector3i(-1, -1, -1)
	return Vector3i(floori(hit.x), floori(hit.z), view_floor)


func _crew_turn() -> bool:
	return enc.state == "playing" and not enc.cur.is_empty() and enc.cur.team == 0


## An attack option is selected: the attack stage, or a target-picking attack (melee, shell, grenade).
func _aim_armed() -> bool:
	return _crew_turn() and (stage == "attack" or tool in ["melee", "shell", "grenade"])


## A foe's turn-order portrait: point the hover at them if they're in sight (true).
func _portrait_target(uid: int) -> bool:
	for u in enc.units:
		if int(u.id) == uid and _foe(u) and not _unit_at(u.pos).is_empty():
			hover = u.pos
			return true
	return false


func _portrait_hover(uid: int, rect: Rect2) -> void:
	_portrait_uid = uid
	if enc == null or uid < 0 or not _aim_armed() or not _portrait_target(uid):
		return
	mouse = Vector2(rect.get_center().x, rect.end.y)   # the odds card hangs under the portrait
	_on_hover_changed()
	_update_hover()


## --near=n: move the nearest foe onto a free square n squares from the active unit, in its line of
## fire (review renders of the attack previews).
## Review renders (--hurt=f): the three nearest foes join the fight, each a little worse off
## than the last (f, 2f/3, f/3 of their HP gone), so the portraits show their blood levels.
func _demo_hurt() -> void:
	var foes := enc.units.filter(func(o): return _foe(o) and enc.is_guard(o) and not o.c.dead)
	foes.sort_custom(func(a, b): return Vector3(a.pos - enc.cur.pos).length() < Vector3(b.pos - enc.cur.pos).length())
	foes = foes.slice(0, 3)
	enc._rouse(foes)
	for i in foes.size():
		var c: Combatant = foes[i].c
		c.hp = maxi(1, roundi(c.max_hp() * (1.0 - _dev_hurt * (3 - i) / 3.0)))
		enc.say("%s takes a hit (%d/%d HP)." % [c.display_name, c.hp, c.max_hp()])
	_refresh()


func _demo_near() -> void:
	var foes := enc.units.filter(func(o): return _foe(o) and not o.c.dead)
	if foes.is_empty():
		return
	foes.sort_custom(func(a, b): return Vector3(a.pos - enc.cur.pos).length() < Vector3(b.pos - enc.cur.pos).length())
	var occ := enc.occupied()
	var c: Vector3i = enc.cur.pos
	for r in range(_dev_near, _dev_near + 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var v := Vector3i(c.x + dx, c.y + dy, c.z)
				if maxi(absi(dx), absi(dy)) != r or not m.inb(v.x, v.y) or not m.walkable(v.z, Vector2i(v.x, v.y)) or occ.has(v) or not enc.los.trace(c, v).clear:
					continue
				foes[0].pos = v
				enc.refresh_vision()
				if _dev_portrait:   # in the turn order: guards join it once alerted
					enc._rouse([foes[0]])
					enc.events.clear()
				_refresh()
				return


func _click_move() -> void:
	if not _crew_turn():
		return
	if move_opts.has(hover) and enc.move_to(hover):
		_after_action()
	elif dash_opts.has(hover) and enc.move_to(hover, true):   # Run Action (p127)
		_after_action()


func _unit_at(v: Vector3i) -> Dictionary:
	for u in enc.units:
		if u.pos == v and not u.c.dead and (u.team == 0 or not fog_on or enc.vision.visible.has(v)):
			return u
	return {}


func _click_attack(at_cover: bool) -> void:
	if not _crew_turn() or enc.cur.c.weapons.is_empty():
		return
	var w: Weapon = enc.cur.c.weapons[0]
	var t := _unit_at(hover)
	if at_cover or t.is_empty():
		var r := {}
		if not t.is_empty():
			var p := enc.preview(t, w, mode)
			if p.blocker.x >= 0:
				r = enc.shoot_cover(p.blocker, w)
		elif enc.los.blocker(hover) != "":
			r = enc.shoot_cover(hover, w)
		if r.get("ok", false):
			hud.toast("%d damage to cover%s" % [r.damage, " — destroyed" if r.left == 0 else " (%d HP left)" % r.left])
		_after_action()
		return
	if t.team == 0:
		return
	var r := enc.attack(t, w, mode)
	if r.get("ok", true) == false:
		hud.toast(r.reason)
	_after_action()


func _reload() -> void:
	if _crew_turn() and not enc.cur.c.weapons.is_empty():
		if enc.reload(enc.cur.c.weapons[0]):
			_after_action()
		else:
			hud.toast("Magazine full or no Action left.")


## M5: apply the active tool to the hovered square.
func _click_tool() -> void:
	if not _crew_turn():
		return
	var t := _unit_at(hover)
	var w: Weapon = enc.cur.c.weapons[0] if not enc.cur.c.weapons.is_empty() else null
	var r := {"ok": false, "reason": "pick a target"}
	match tool:
		"melee":
			if not t.is_empty() and not enc.allied(t.team, enc.cur.team):
				r = enc.melee(t, Weapon.brawling(enc.cur.c) if atk_mode == "brawl" else (w if w and w.is_melee() else null))
		"suppress":   # Suppressive Fire hits everyone in sight within 25 m: left-click anywhere
			if w:
				r = enc.suppress(w)
		"shell":
			if not t.is_empty() and not enc.allied(t.team, enc.cur.team) and w:
				r = enc.shotgun_shell(t, w)
		"grenade":
			if hover.x >= 0:
				r = enc.throw_grenade(hover, 0)
		"stabilize":
			if not t.is_empty():
				r = enc.stabilize(t)
		"rig":
			if not t.is_empty():
				r = enc.jury_rig(t)
		"dose":
			if not t.is_empty():
				var drug := enc.best_dose(t)
				r = enc.dose(t, drug) if drug != "" else {"ok": false, "reason": "no drug would help"}
	if not r.get("ok", false):
		hud.toast(String(r.get("reason", "can't")).capitalize())
		return
	tool = ""
	if blast_node:
		blast_node.visible = false
	_after_action()


func _suppress() -> void:
	if not _crew_turn() or enc.cur.c.weapons.is_empty():
		return
	var r := enc.suppress(enc.cur.c.weapons[0])
	if not r.get("ok", false):
		hud.toast(String(r.get("reason", "can't")).capitalize())
		return
	_after_action()


## Hover feedback for the M5 tools: odds and who would be caught; the grenade shows its blast.
## The preview line or arc from the shooter's square to the target (a unit or a square), coloured
## like the odds; `stop` marks what blocks the line of fire.
func _set_aim(shape: String, from: Vector3i, t: Variant, pct: int, stop := Vector3i(-1, -1, -1), head := false, wid := "") -> void:
	if shape == "":
		return
	var tv: Vector3i = t.pos if t is Dictionary else t
	var base := Vector3(tv.x + 0.5, _gy(tv), tv.y + 0.5)
	var b := AimPreview.aim_point(base, head) if t is Dictionary else base + Vector3(0, 0.05, 0)
	var col := Hud.RED if pct < 0 else (Hud.GREEN if pct >= 65 else (Hud.GOLD if pct >= 35 else Hud.RED))
	_aim = {"shape": shape, "from": Vector3(from.x + 0.5, _gy(from) + 1.05, from.y + 0.5), "fsq": from, "to": b, "col": col,
		"tid": int(t.id) if t is Dictionary else -1, "wid": wid, "mode": mode}
	if stop.x >= 0 and shape == AimPreview.LINE:
		_aim["stop"] = Vector3(stop.x + 0.5, 0, stop.y + 0.5)


func _tool_hover() -> void:
	var c: Combatant = enc.cur.c
	var t := _unit_at(hover)
	if blast_node == null:
		blast_node = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(5, 5)
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;\nvoid fragment() {\n\tvec2 d = abs(UV - 0.5) * 2.0;\n\tfloat edge = step(0.94, max(d.x, d.y));\n\tfloat grid = step(0.92, fract(UV.x * 5.0)) + step(0.92, fract(UV.y * 5.0));\n\tALBEDO = vec3(1.0, 0.55, 0.1) * (0.08 + edge * 0.9 + min(grid, 1.0) * 0.12);\n}"
		sm.shader = sh
		pm.material = sm
		blast_node.mesh = pm
		world.add_child(blast_node)
	blast_node.visible = tool == "grenade" and hover.x >= 0
	match tool:
		"grenade":
			if hover.x < 0:
				hud.tip("", mouse)
				return
			blast_node.position = Vector3(hover.x + 0.5, _gy(hover) + 0.05, hover.y + 0.5)
			var bh := AimPreview.blast_half(c.kit[0])   # the item's blast (every kit grenade: 5x5, p174)
			blast_node.visible = bh > 0
			blast_node.scale = Vector3.ONE * (2 * bh + 1) / 5.0
			var dist := Los.distance_m(enc.cur.pos, hover)
			var ok: bool = dist <= Encounter.THROW_RANGE_M and hover.z == enc.cur.pos.z and enc.los.trace(enc.cur.pos, hover).clear
			var dv := maxi(10, RulesDB.range_dv("grenade_launcher", dist))
			var pct := roundi(Check.chance_vs_dv(c.skill_base("athletics") - c.action_penalty(), dv) * 100)
			_set_aim(AimPreview.for_armed(tool, atk_mode, null, c.kit[0]), enc.cur.pos, hover, pct if ok else -1)
			var caught := enc.units.filter(func(o): return not o.c.dead and o.pos.z == hover.z and maxi(absi(o.pos.x - hover.x), absi(o.pos.y - hover.y)) <= Encounter.BLAST_HALF)
			var names := caught.map(func(o): return ("[color=#39f0a0]%s[/color]" if enc.allied(o.team, enc.cur.team) else "[color=#ff3b4f]%s[/color]") % o.c.display_name)
			var what := "no damage: everyone caught resists or is affected" if Items.fx(c.kit[0]).get("no_damage", false) else "6d6"
			hud.tip(("[code][font_size=44]%d%%[/font_size][/code] on target · DV %d · %d m\n%s in a 5x5 blast (a miss scatters it)\n%s" % [pct, dv, roundi(dist), what, ", ".join(names) if not names.is_empty() else "nobody in the blast"]) if ok else "[color=#ff3b4f]Out of reach or no clear throw[/color]", mouse, "// " + Items.display_name(c.kit[0]).to_upper(), Hud.GOLD)
		"melee":
			if t.is_empty() or enc.allied(t.team, enc.cur.team):
				hud.tip("Pick a neighbouring enemy", mouse, "// MELEE", Hud.CYAN)
				return
			var mw := enc.melee_weapon(c)
			var p := enc.preview(t, mw, Attack.Mode.SINGLE)
			_set_aim(AimPreview.SWING, enc.cur.pos, t, roundi(p.chance * 100) if p.ok else -1, Vector3i(-1, -1, -1), false, mw.id())
			hud.tip(("[code][font_size=44]%d%%[/font_size][/code]  %s · %dd6" % [roundi(p.chance * 100), mw.def.name, mw.dice()]) if p.ok else "[color=#ff3b4f]%s[/color]" % String(p.reason).capitalize(), mouse, "// MELEE", Hud.CYAN)
		"shell":
			if t.is_empty() or enc.allied(t.team, enc.cur.team):
				hud.tip("Pick an enemy: everyone in a 90° cone to 6 m is caught", mouse, "// SHOTGUN SHELL", Hud.CYAN)
				return
			var pct2 := roundi(Check.chance_vs_dv(c.skill_base(enc.cur.c.weapons[0].skill()) - c.action_penalty(), Attack.SHOTGUN_SHELL_DV) * 100)
			_set_aim(AimPreview.LINE, enc.cur.pos, t, pct2)
			hud.tip("[code][font_size=44]%d%%[/font_size][/code] vs DV13 · 3d6 to everyone in the cone" % pct2, mouse, "// SHOTGUN SHELL", Hud.CYAN)
		"rig":
			if t.is_empty() or not enc.allied(t.team, enc.cur.team):
				hud.tip("Pick yourself or a neighbouring ally with worn armour", mouse, "// JURY-RIG", Hud.CYAN)
				return
			var loc := enc.rig_target_loc(t)
			if loc == "":
				hud.tip("No worn armour that hasn't been rigged already", mouse, "// JURY-RIG", Hud.CYAN)
				return
			var ap: ArmorPiece = t.c.armor[loc]
			var pr := roundi(Check.chance_vs_dv(Encounter.rig_base(c), ArmorPiece.maker_dv(ap.price())) * 100)
			hud.tip("[code][font_size=44]%d%%[/font_size][/code] %s SP %d → %d · TECH + Basic Tech + Field vs DV%d" % [pr, loc.to_upper(), ap.sp, ap.max_sp, ArmorPiece.maker_dv(ap.price())], mouse, "// JURY-RIG", Hud.CYAN)
		"dose":
			if t.is_empty() or not enc.allied(t.team, enc.cur.team):
				hud.tip("Pick yourself or a neighbouring ally (%d doses)" % c.doses, mouse, "// PHARMACEUTICALS", Hud.GREEN)
				return
			var drug := enc.best_dose(t)
			if drug == "":
				hud.tip("Nothing helps: unhurt, Mortally Wounded, or already dosed today", mouse, "// PHARMACEUTICALS", Hud.GREEN)
				return
			var what := "+%d HP (BODY + WILL)" % mini(t.c.max_hp() - t.c.hp, t.c.raw_stat("BODY") + t.c.raw_stat("WILL")) if drug == "speedheal" else "ignore Seriously Wounded penalties"
			hud.tip("%s · %s · %d doses left" % [drug.to_upper(), what, c.doses], mouse, "// PHARMACEUTICALS", Hud.GREEN)
		"stabilize":
			if t.is_empty() or not enc.allied(t.team, enc.cur.team) or t.c.wound_state() != Combatant.Wound.MORTAL:
				hud.tip("Pick a Mortally Wounded ally in reach", mouse, "// STABILIZE", Hud.GREEN)
				return
			var pct3 := roundi(Check.chance_vs_dv(maxi(c.skill_base("first_aid"), c.skill_base("paramedic")) - c.action_penalty(), t.c.stabilization_dv()) * 100)
			hud.tip("[code][font_size=44]%d%%[/font_size][/code] vs DV%d · TECH + First Aid" % [pct3, t.c.stabilization_dv()], mouse, "// STABILIZE", Hud.GREEN)


func _jack_in() -> void:
	if not _crew_turn():
		return
	var pts := enc.jack_points(enc.cur)
	if pts.is_empty():
		hud.toast("No terminal within %d m." % int(Encounter.jack_range(enc.cur.c)))
	elif not enc.jack_in(pts[0]):
		hud.toast("Your Action is spent this turn.")
	else:
		_ui_snd("sfx_jack_in", -3.0)
	_after_action()


func _end_turn() -> void:
	if not _crew_turn():
		return
	enc.end_turn()
	enc.next_turn()
	_after_action()


func _demo_jack() -> void:
	var runner := {}
	for u in enc.alive(0):
		if NetRun.interface_rank(u.c) > 0:
			runner = u
	if runner.is_empty():
		return
	var best := Vector3i(-1, -1, -1)
	for sid in m.architectures:
		var a: NetArchitecture = m.architectures[sid]
		if _jack_turret and _turret_node_of(a) < 0:
			continue
		for ap in a.access_points:
			var d: Dictionary = m.devices[ap.device]
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var v := Vector3i(d.pos.x + dx, d.pos.y + dy, d.floor)
					if best.x < 0 and m.walkable(v.z, Vector2i(v.x, v.y)) and not enc.occupied().has(v) and Los.distance_m(v, Vector3i(d.pos.x, d.pos.y, d.floor)) <= 4.0 \
							and not enc._wall_between(v, Vector3i(d.pos.x, d.pos.y, d.floor)):
						best = v
	if best.x < 0:
		return
	runner.pos = best
	enc.cur = runner
	enc.turn = TurnState.begin(dice, runner.c)
	view_floor = best.z
	var pts := enc.jack_points(runner)
	if not pts.is_empty():
		enc.jack_in(pts[0])
		var run: NetRun = enc.runs[runner.id]
		for nb in run.arch.neighbors(run.current):   # step one node in so more of the NET shows
			if run.can_move_to(nb) and run.arch.neighbors(nb).size() > 1:
				enc.net_move(nb)
				break
		var tn := _turret_node_of(run.arch) if _jack_turret else -1
		if tn >= 0:   # the turret's node taken (as a CONTROL would)
			run.held[tn] = true
			enc._retake_turrets()
			_demo_turret_target(runner)
	enc.refresh_vision()
	_frame_unit(runner)
	_refresh()
	_demo_ms = Time.get_ticks_msec()


## Review videos: one scripted combat beat per reel, recorded with Godot's movie writer
## (tools/review_videos.sh). Outcomes are forced by setting HP/SP before the roll and retrying, so
## each reel shows the effect it is named for.
func _run_reel() -> void:
	var g := _nearest_guard()
	if _reel not in ["move", "jack", "cover", "stabilize", "reload", "dose", "rig", "grab", "backup", "watch"]:
		_reel_setup_shot(g)
	if _reel in ["stabilize", "reload", "dose", "rig", "grab", "backup"]:
		_reel_frame(enc.cur)
	var cell := Vector3i(-1, -1, -1)
	if _reel == "cover":   # a one-square piece that takes a few shots; the shooter stands 3-5 squares off in sight
		var best_hp := 0
		for c in m.cover:
			var v := Vector3i(c.pos.x, c.pos.y, c.floor)
			var hp: int = enc.los.cover_hp.get(v, 0)
			if int(c.get("prop", -1)) >= 0 or hp < 8 or hp > 40 or hp <= best_hp:
				continue
			for s in enc.nav.reachable(v, 6, enc.occupied()):
				var dd := Vector2(s.x - v.x, s.y - v.y).length()
				if s.z == v.z and dd >= 3 and dd <= 5 and enc.los.sight(s, v).visible:
					cell = v
					best_hp = hp
					enc.cur.pos = s
					break
		if cell.x >= 0:
			print("reel cover: %s %s hp %d" % [cell, m.cover.filter(func(c): return Vector3i(c.pos.x, c.pos.y, c.floor) == cell)[0].kind, best_hp])
			view_floor = cell.z
			cam_target = Vector3((enc.cur.pos.x + cell.x) / 2.0 + 0.5, 0, (enc.cur.pos.y + cell.y) / 2.0 + 0.5)
			_place_camera()
			enc.refresh_vision()
			_refresh()   # synchronous: the first rendered frame already frames shooter and target
	await get_tree().create_timer(0.6).timeout
	var tail := 1.6
	match _reel:
		"move":
			var far := Vector3i(-1, -1, -1)
			for v in enc.nav.reachable(enc.cur.pos, enc.turn.squares_available(), enc.occupied()):
				if far.x < 0 or Vector3(v - enc.cur.pos).length() > Vector3(far - enc.cur.pos).length():
					far = v
			enc.move_to(far)
			await _act()
			await get_tree().create_timer(0.6).timeout
			enc.turn.move_left = 0
			var far2 := Vector3i(-1, -1, -1)
			for v in enc.nav.reachable(enc.cur.pos, enc.cur.c.stat("MOVE"), enc.occupied()):
				if far2.x < 0 or Vector3(v - enc.cur.pos).length() > Vector3(far2 - enc.cur.pos).length():
					far2 = v
			enc.move_to(far2, true)   # Run action
			await _act()
		"single", "auto", "kill", "headshot", "armor", "pistol":
			var md: int = {"auto": Attack.Mode.AUTOFIRE, "headshot": Attack.Mode.AIMED_HEAD}.get(_reel, Attack.Mode.SINGLE)
			if _reel in ["kill", "headshot", "armor"]:   # make the beat happen on the first shot
				for sk in enc.cur.c.skills:
					enc.cur.c.skills[sk] = int(enc.cur.c.skills[sk]) + 12
			if _reel in ["kill", "headshot"]:
				g.c.hp = 1
				for loc in ["head", "body"]:
					if g.c.armor[loc]:
						g.c.armor[loc].sp = 0
				tail = 4.0   # the whole fall
			if _reel == "armor":
				for loc in ["head", "body"]:
					if g.c.armor[loc]:
						g.c.armor[loc].sp = 40
			for k in 8:   # retry until the beat happens (a hit for kill/armor/headshot)
				enc.turn.action_available = true
				enc.turn.attacks_left = 0
				var r := enc.attack(g, enc.cur.c.weapons[0], md)
				print("reel %s try %d: %s" % [_reel, k, {"ok": r.get("ok"), "hit": r.get("hit"), "dodged": r.get("dodged"), "damage": r.get("damage"), "through": r.get("through"), "armor": [g.c.armor.head != null, g.c.armor.body != null], "sp": g.c.sp("body"), "reason": r.get("reason"), "dead": g.c.dead}])
				await _act()
				if _reel in ["single", "auto", "pistol"] or g.c.dead:
					break
				if r.get("hit", false) and not r.get("dodged", false):
					break
				await get_tree().create_timer(0.3).timeout
			if _reel in ["kill", "headshot"] and not g.c.dead:
				# 0 HP is Mortally Wounded (DYING); death comes from a failed Death Save at the start
				# of the guard's own turn (p222). Make the save fail and play turns until it does.
				g.c.dsp = 50
				tail = 0.2   # the death event already holds on the body
				for k in 6:
					if g.c.dead:
						break
					_on_hud("end_turn", null)
					await get_tree().create_timer(0.2).timeout
					while busy:
						await get_tree().process_frame
		"cover":
			if cell.x >= 0:
				for k in 8:
					if enc.los.cover_hp.get(cell, 0) <= 0:
						break
					enc.turn.action_available = true
					enc.turn.attacks_left = 0
					enc.shoot_cover(cell, enc.cur.c.weapons[0])
					await _act()
		"enemy":
			enc.attack(g, enc.cur.c.weapons[0], Attack.Mode.SINGLE)   # gunfire rouses the guards into initiative
			await _act()
			var others: Array = enc.units.filter(func(o): return enc.is_guard(o) and _foe(o) and not o.alerted and not o.c.dead)
			enc._rouse(others.slice(0, 3))
			await _act()
			for k in 4:   # end crew turns: the guards act in between (AI turns play out inside _after_action)
				_on_hud("end_turn", null)
				await get_tree().create_timer(0.2).timeout
				while busy:
					await get_tree().process_frame
		"jack":
			_demo_jack()
			await get_tree().create_timer(3.5).timeout
		"melee":
			for s in enc.nav.reachable(g.pos, 3, enc.occupied()):
				if enc.adjacent(s, g.pos):
					enc.cur.pos = s
					break
			_reel_frame(g)
			await get_tree().create_timer(0.5).timeout
			for k in 6:
				enc.turn = TurnState.begin(dice, enc.cur.c)
				var r := enc.melee(g)
				await _act()
				if r.get("hit", false) or g.c.dead:
					break
		"suppress":
			await get_tree().create_timer(0.4).timeout
			for k in 4:
				enc.turn = TurnState.begin(dice, enc.cur.c)
				enc.cur.c.weapons[0].reload()
				var r := enc.suppress(enc.cur.c.weapons[0])
				await _act()
				if not r.get("suppressed", []).is_empty():
					break
			for k in 2:   # the pinned guard dives for cover on its turn
				_on_hud("end_turn", null)
				await get_tree().create_timer(0.2).timeout
				while busy:
					await get_tree().process_frame
		"shell":
			var sg := Weapon.from_id("shotgun")
			enc.cur.c.weapons.insert(0, sg)
			(unit_nodes[enc.cur.id] as CharModel).set_weapon("shotgun")
			for s in enc.nav.reachable(g.pos, 4, enc.occupied()):
				if Vector2(s.x - g.pos.x, s.y - g.pos.y).length() >= 2 and Vector2(s.x - g.pos.x, s.y - g.pos.y).length() <= 2.9 and enc.los.sight(s, g.pos).visible:
					enc.cur.pos = s
					break
			_reel_frame(g)
			enc.cur.c.skills["shoulder_arms"] = int(enc.cur.c.skills.get("shoulder_arms", 0)) + 10
			await get_tree().create_timer(0.5).timeout
			for k in 4:
				enc.turn = TurnState.begin(dice, enc.cur.c)
				sg.reload()
				var r := enc.shotgun_shell(g, sg)
				await _act()
				if r.get("hit", false):
					break
		"grenade":
			enc.cur.c.skills["athletics"] = int(enc.cur.c.skills.get("athletics", 0)) + 10
			await get_tree().create_timer(0.4).timeout
			enc.turn = TurnState.begin(dice, enc.cur.c)
			enc.cur.c.kit[0] = "ammo/armor_piercing_ammo"
			enc.cur.c.kit_spent[0] = false
			var r := enc.throw_grenade(g.pos, 0)
			print("reel grenade: ", r.get("ok"), " ", r.get("reason", ""), " dmg ", r.get("damage", 0))
			await _act()
			tail = 2.5
		"stabilize":
			var ally: Dictionary = enc.alive(0).filter(func(o): return o != enc.cur)[0]
			for s in enc.nav.reachable(enc.cur.pos, 3, enc.occupied()):
				if enc.adjacent(s, enc.cur.pos):
					ally.pos = s
					break
			ally.c.hp = 0
			_refresh()
			_reel_frame(ally)
			enc.cur.c.skills["first_aid"] = int(enc.cur.c.skills.get("first_aid", 0)) + 10
			await get_tree().create_timer(0.8).timeout
			for k in 4:
				enc.turn = TurnState.begin(dice, enc.cur.c)
				var r := enc.stabilize(ally)
				await _act()
				if r.get("success", false):
					break
		"dose", "rig":
			var ally2: Dictionary = enc.alive(0).filter(func(o): return o != enc.cur)[0]
			for s in enc.nav.reachable(enc.cur.pos, 3, enc.occupied()):
				if enc.adjacent(s, enc.cur.pos):
					ally2.pos = s
					break
			if _reel == "dose":
				enc.cur.c.role = "medtech"
				enc.cur.c.medicine = {"pharma": 2}
				enc.cur.c.doses = 2
				ally2.c.hp = maxi(1, ally2.c.max_hp() / 3)
			else:
				enc.cur.c.maker = {"field": 3}
				enc.cur.c.skills["basic_tech"] = 10
				(ally2.c.armor.body as ArmorPiece).sp = 3
			_refresh()
			_reel_frame(ally2)
			await get_tree().create_timer(0.8).timeout
			enc.turn = TurnState.begin(dice, enc.cur.c)
			var r2 := enc.dose(ally2, "speedheal") if _reel == "dose" else enc.jury_rig(ally2)
			print("reel %s: %s" % [_reel, r2])
			await _act()
		"grab":
			var spot := Vector3i(-1, -1, -1)
			for s in enc.nav.reachable(enc.cur.pos, 3, enc.occupied()):
				if enc.adjacent(s, enc.cur.pos):
					spot = s
					break
			enc.set_objective("snatch", {"cell": spot, "carrier": -1})
			_refresh()
			await get_tree().create_timer(1.2).timeout
			enc.turn = TurnState.begin(dice, enc.cur.c)
			print("reel grab: ", enc.grab())
			await _act()
			var far3 := Vector3i(-1, -1, -1)
			for v in enc.nav.reachable(enc.cur.pos, enc.turn.squares_available(), enc.occupied()):
				if far3.x < 0 or Vector3(v - enc.cur.pos).length() > Vector3(far3 - enc.cur.pos).length():
					far3 = v
			enc.move_to(far3)
			await _act()
		"backup":
			await get_tree().create_timer(0.4).timeout
			var gs := enc.opfor()
			if not gs.is_empty():
				enc.call_it_in(gs[0])
			await _act()
			var roster: Array[String] = ["mook", "mook", "mook"]
			enc._spawn_wave(roster, "BACKUP", Encounter.OPFOR, enc.opfor_faction, "Backup")
			await _act()
			tail = 2.5
		"watch":   # the stealth overlay: a guard's watched squares while the crew plans a move
			fog_on = false
			var gw := _nearest_guard()
			if not gw.is_empty():
				gw.facing = Vector2(enc.cur.pos.x - gw.pos.x, enc.cur.pos.y - gw.pos.y).normalized()
				view_floor = gw.pos.z
				cam_target = Vector3(gw.pos.x + 0.5, 0, gw.pos.y + 0.5)
				_place_camera()
			_refresh()
			tail = 3.0
		"reload":
			await get_tree().create_timer(0.4).timeout
			enc.cur.c.weapons[0].ammo = 2
			enc.turn = TurnState.begin(dice, enc.cur.c)
			enc.reload(enc.cur.c.weapons[0])
			await _act()
	await get_tree().create_timer(tail).timeout
	print("reel %s end: target %s" % [_reel, "dead" if g.get("c") and g.c.dead else "alive"])
	get_tree().quit()


func _reel_frame(u: Dictionary) -> void:
	view_floor = enc.cur.pos.z
	var a := _body_pos(enc.cur)
	var b := _body_pos(u)
	cam_target = Vector3((a.x + b.x) / 2.0, 0, (a.z + b.z) / 2.0)
	_place_camera()
	enc.refresh_vision()
	_refresh()


func _act() -> void:
	_after_action()
	await get_tree().process_frame
	while busy:
		await get_tree().process_frame


func _nearest_guard() -> Dictionary:
	var best := {}
	for u in enc.units:
		if enc.is_guard(u) and _foe(u) and not u.c.dead and (best.is_empty() or Vector2(u.pos.x - enc.cur.pos.x, u.pos.y - enc.cur.pos.y).length() < Vector2(best.pos.x - enc.cur.pos.x, best.pos.y - enc.cur.pos.y).length()):
			best = u
	return best


## Put the shooter in sight of the guard, a few squares off, and frame both.
func _reel_setup_shot(g: Dictionary) -> void:
	if g.is_empty():
		return
	if _reel == "pistol":
		for u in enc.alive(0):
			if u.c.weapons[0].id().contains("pistol"):
				enc.cur = u
				enc.turn = TurnState.begin(dice, u.c)
	for v in enc.nav.reachable(g.pos, 6, enc.occupied()):
		var d := Vector2(v.x - g.pos.x, v.y - g.pos.y).length()
		if v != g.pos and d >= 3 and d <= 6 and enc.los.sight(v, g.pos).visible:
			enc.cur.pos = v
			break
	view_floor = enc.cur.pos.z
	cam_target = Vector3((enc.cur.pos.x + g.pos.x) / 2.0 + 0.5, 0, (enc.cur.pos.y + g.pos.y) / 2.0 + 0.5)
	_place_camera()
	enc.refresh_vision()
	_refresh()


func _demo_attack() -> void:
	var best := {}
	for u in enc.units:
		if enc.is_guard(u) and _foe(u) and not u.c.dead and (best.is_empty() or Vector2(u.pos.x - enc.cur.pos.x, u.pos.y - enc.cur.pos.y).length() < Vector2(best.pos.x - enc.cur.pos.x, best.pos.y - enc.cur.pos.y).length()):
			best = u
	if best.is_empty():
		return
	var g: Dictionary = best
	var near := enc.nav.reachable(g.pos, 6, enc.occupied())
	for v in near:   # put the shooter in sight of the guard for the demo
		if v != g.pos and enc.los.sight(v, g.pos).visible and Vector2(v.x - g.pos.x, v.y - g.pos.y).length() >= 3:
			enc.cur.pos = v
			break
	view_floor = enc.cur.pos.z
	cam_target = Vector3((enc.cur.pos.x + g.pos.x) / 2.0 + 0.5, 0, (enc.cur.pos.y + g.pos.y) / 2.0 + 0.5)
	_place_camera()
	enc.refresh_vision()
	_refresh()
	mode = Attack.Mode.AUTOFIRE
	enc.turn.action_available = true
	enc.attack(g, enc.cur.c.weapons[0], mode)
	_demo_ms = Time.get_ticks_msec()
	_after_action()


## After any rules call: play what happened (moves, shots, alerts) as animation, then sync.
## Encounter-level conditions on a unit for its card (suppressed, unaware); the combatant's own
## (injuries, prone, burning, drugs...) come from Hud.conditions.
func _unit_conditions(u: Dictionary) -> Array:
	var out: Array = []
	if u.has("suppressed_by"):
		out.append("suppressed")
	if u.team != 0 and not u.get("alerted", true) and not u.has("held_by"):
		out.append("unaware")
	if u.has("held_by"):   # a turret a Netrunner operates (Encounter.fire_turret)
		out.append("held by %s's deck" % enc.units[int(u.held_by)].c.display_name)
	if u.has("turret") and not u.c.weapons.is_empty() and u.c.weapons[0].uses_ammo() and u.c.weapons[0].ammo <= 0:
		out.append("out of ammunition")
	return out


## Encounter.attack_modes ids that are plain attacks → Attack.Mode.
const ATK_ENUM := {"single": Attack.Mode.SINGLE, "aim_head": Attack.Mode.AIMED_HEAD, "aim_leg": Attack.Mode.AIMED_LEG,
	"aim_held": Attack.Mode.AIMED_HELD, "auto": Attack.Mode.AUTOFIRE, "cover": Attack.Mode.SINGLE}


## Arm an attack from the attack stage: plain shots set the fire mode (left-click a target);
## the rest are target-picking tools; Shoot Cover aims at the cover in the way.
func _arm(m: String) -> void:
	atk_mode = m
	mode = ATK_ENUM.get(m, Attack.Mode.SINGLE)
	cover_mode = m == "cover"
	tool = {"suppress": "suppress", "shell": "shell", "melee": "melee", "brawl": "melee"}.get(m, "")


func _back_to_main() -> void:
	stage = "main"
	tool = ""
	cover_mode = false
	atk_mode = "single"
	mode = Attack.Mode.SINGLE


## True if the active unit can still act this turn; otherwise says so (spent buttons are dimmed).
func _spend_check() -> bool:
	if not _crew_turn():
		return false
	if not (enc.turn.action_available or enc.turn.attacks_left > 0):
		hud.toast("NO ACTION LEFT")
		return false
	return true


func _after_action() -> void:
	busy = true
	hud.log_hold = true   # log lines land with their callouts, not before the animation
	grid_node.visible = false
	move_opts = {}   # no move is pending until the grid is drawn again for whoever acts next
	dash_opts = {}
	_path_cells.clear()
	path_node.mesh = null
	if enc.turn != _view_turn:   # the turn shown has ended: whatever plays next (the other side's turns) is meatspace
		_show_net(null)
	await _play_events()
	busy = false
	hud.log_hold = false
	if stage == "attack" and (enc.cur.is_empty() or enc.cur.team != 0 or not (enc.turn.action_available or enc.turn.attacks_left > 0)):
		_back_to_main()   # the attack is spent: back to the main bar (a ROF 2 second shot stays armed)
	if _rebuild:
		_rebuild = false
		_build_world()
	enc.refresh_vision()
	var new_turn: bool = not enc.cur.is_empty() and enc.cur.team == 0 and enc.cur.id != _last_cur
	if new_turn:
		_frame_unit(enc.cur)   # new crew turn: centre the active unit in the space between the panels
	_last_cur = enc.cur.id if not enc.cur.is_empty() else -1
	_view_turn = enc.turn
	_refresh()
	_update_hover()
	if new_turn and enc.state == "playing":
		hud.turn_banner("%s  ·  YOUR MOVE" % enc.cur.c.display_name.to_upper(), Hud.GOLD)
		_ui_snd("sfx_turn", -6.0)
	if enc.state != "playing":   # every way a gig ends (a board gig or a dev map) comes here: never a dead end
		_finish_gig()


## Downed guards still carrying a keycard: a small gold card turning over the body, so the crew
## knows it's worth going over.
func _update_keycards() -> void:
	for u in enc.units:
		var down: bool = u.has("keycard") and (u.c.dead or u.c.unconscious or u.c.wound_state() == Combatant.Wound.MORTAL)
		var seen: bool = not fog_on or enc.vision.visible.has(u.pos)
		if down and seen and not keycard_nodes.has(u.id):
			var card := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.16, 0.22, 0.02)
			card.mesh = bm
			card.material_override = _unlit(Hud.GOLD, 1.0, 1.6)
			card.position = Vector3(u.pos.x + 0.5, _gy(u.pos) + 0.75, u.pos.y + 0.5)
			world.add_child(card)
			keycard_nodes[u.id] = card
		elif not down and keycard_nodes.has(u.id):
			(keycard_nodes[u.id] as Node3D).queue_free()
			keycard_nodes.erase(u.id)
	var t := Time.get_ticks_msec() / 1000.0
	for id in keycard_nodes:
		var n: Node3D = keycard_nodes[id]
		n.rotation.y = t * 2.0
		n.position.y = _gy(enc.units[id].pos) + 0.72 + 0.05 * sin(t * 3.0)
		n.visible = _grade_shows(enc.units[id].pos.z)   # a card over a body on the street lifts off with it below grade


## Snatch gigs: the package sits on a gold beacon until someone carries it (then a gold diamond
## floats over the carrier), and the deploy squares glow as the extraction point.
func _update_objective() -> void:
	var snatch: bool = enc.objective.get("kind", "") == "snatch"
	if obj_node == null or not is_instance_valid(obj_node) or obj_node.get_parent() != world:
		obj_node = Node3D.new()
		world.add_child(obj_node)
		var case := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.42, 0.16, 0.3)
		case.mesh = bm
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color("2a2c30")
		cm.metallic = 0.6
		cm.roughness = 0.35
		case.material_override = cm
		case.position.y = 0.08
		case.name = "case"
		obj_node.add_child(case)
		var beacon := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.3   # a tall shaft of light so it reads from across the map
		cy.bottom_radius = 0.42
		cy.height = 4.5
		cy.cap_top = false
		cy.cap_bottom = false
		beacon.mesh = cy
		beacon.material_override = _unlit(Hud.GOLD, 0.16, 1.3)
		beacon.position.y = 1.1
		beacon.name = "beacon"
		obj_node.add_child(beacon)
		var tag := MeshInstance3D.new()   # the carrier's diamond
		var pm := PrismMesh.new()
		pm.size = Vector3(0.22, 0.3, 0.06)
		tag.mesh = pm
		tag.material_override = _unlit(Hud.GOLD, 1.0, 1.4)
		tag.rotation.z = PI
		tag.name = "tag"
		obj_node.add_child(tag)
		var zone := Node3D.new()
		zone.name = "zone"
		obj_node.add_child(zone)
		for cell in enc.extract_cells:
			var q := MeshInstance3D.new()
			var qm := PlaneMesh.new()
			qm.size = Vector2(0.86, 0.86)
			q.mesh = qm
			q.material_override = _unlit(Hud.GOLD, 0.22, 1.0)
			q.position = Vector3(cell.x + 0.5, _gy(cell) + 0.025, cell.y + 0.5)
			zone.add_child(q)
	obj_node.visible = not _net_cleaned
	var carrier: int = enc.objective.get("carrier", -1)
	var case_n := obj_node.get_node("case") as Node3D
	if not snatch:   # the deploy zone still marks the way out (withdrawal)
		for nm in ["case", "beacon", "tag"]:
			(obj_node.get_node(nm) as Node3D).visible = false
		return
	var beacon_n := obj_node.get_node("beacon") as Node3D
	var tag_n := obj_node.get_node("tag") as Node3D
	if carrier < 0:
		var cell: Vector3i = enc.objective.cell
		var p := Vector3(cell.x + 0.5, _gy(cell), cell.y + 0.5)
		case_n.position = p + Vector3(0, 0.08, 0)
		beacon_n.position = p + Vector3(0, 2.25, 0)
		case_n.visible = not _cut_hides(cell)
		beacon_n.visible = case_n.visible
		tag_n.visible = false
	else:
		case_n.visible = false
		beacon_n.visible = false
		var cn: Node3D = unit_nodes[carrier]
		tag_n.visible = cn.visible
		tag_n.position = cn.position + Vector3(0, 2.75, 0)


var _settling := false     ## _finish_gig is under way: once per gig
var _view_turn: TurnState = null   ## the turn the view last settled on (a new one means the last turn ended)


## The banner over the settling: {text, good, head}. `head` is the headline alone, for the toast
## that stays up (Hud.end_toast) and the debrief's wording (DebriefScreen.outcome).
static func end_banner(state: String) -> Dictionary:
	var head := "GIG %s" % ("COMPLETE" if state == "won" else ("ABANDONED" if state == "fled" else "FAILED"))
	return {"text": head + "  ·  DEBRIEF", "good": state == "won", "head": head}


## What the player can do once the gig is over: [[action, button text, key], ...]. A board gig
## goes home to the safehouse debrief (the design: data theft ends when the File is pulled, a
## snatch when the package reaches the deploy zone: no extraction phase after the objective). A
## dev map (no campaign gig) offers another map or quitting. The first is the default (Enter/Space).
static func end_choices(campaign_gig: bool) -> Array:
	if campaign_gig:
		return [["safehouse", "RETURN TO SAFEHOUSE  ›  [ENTER]", "enter"]]
	return [["restart", "RESTART  ›  [ENTER]", "enter"], ["quit", "QUIT  [ESC]", "esc"]]


## The gig is over: the banner and the headline toast, a board gig settled (pay, injuries, the
## dead) and saved at once, then the end panel with what comes next (end_choices). Once per gig.
func _finish_gig() -> void:
	if _settling:
		return
	_settling = true
	_back_to_main()
	_show_net(null)
	var b := end_banner(enc.state)
	hud.end_toast = String(b.head)   # the toast that stays up says what the banner says
	hud.toast(hud.end_toast, 1e9)
	var camp := Campaign.current if _campaign_gig else null
	hud.turn_banner(String(b.text if camp != null else b.head), Hud.GREEN if b.good else Hud.RED)   # no debrief off the campaign
	if camp != null:   # settled now, so quitting from the end panel loses nothing (the safehouse opens the debrief, BaseView)
		var report := camp.resolve(enc)
		camp.set_meta("report", report)
		if not camp.has_meta("demo"):
			camp.save()
	_show_end_panel(b, camp != null)


var _end_panel: Control = null
var _end_opts: Array = []   ## end_choices of the panel that is up


func _show_end_panel(b: Dictionary, campaign_gig: bool) -> void:
	if _end_panel != null and is_instance_valid(_end_panel):
		return
	var col: Color = Hud.GREEN if b.good else Hud.RED
	_end_panel = UiKit.panel(col, 16)
	_end_panel.custom_minimum_size.x = 480
	var v := UiKit.vbox(10)
	_end_panel.add_child(v)
	v.add_child(UiKit.label("// GIG OVER", 13, col))
	v.add_child(UiKit.head(String(b.head), 32, Hud.TEXT))
	v.add_child(UiKit.body("Pay, injuries and the fallen are settled. The debrief is waiting at the safehouse." if campaign_gig
		else "A dev map, outside the campaign: nothing to settle.", 16))
	var row := UiKit.hbox(12)
	v.add_child(row)
	_end_opts = end_choices(campaign_gig)
	for ch in _end_opts:
		var act := String(ch[0])
		row.add_child(UiKit.button(String(ch[1]), UiKit.PRIMARY if row.get_child_count() == 0 else UiKit.NEUTRAL, func(): _end_choose(act)))
	_end_panel.modulate.a = 0.0   # shown once laid out at its real size
	hud.add_child(_end_panel)
	var p := _end_panel
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	p.reset_size()
	p.position = ((hud.size - p.size) / 2.0).floor() + Vector2(0, 60)   # under the banner
	p.modulate.a = 1.0


func _end_choose(act: String) -> void:
	match act:
		"safehouse": get_tree().change_scene_to_file("res://scenes/base.tscn")
		"restart": get_tree().reload_current_scene()
		"quit": get_tree().quit()


## The end panel's keys while it's up: Enter / Space the first choice, Esc the last. True if used.
func _end_key(code: Key) -> bool:
	if _end_panel == null or not is_instance_valid(_end_panel):
		return false
	var ch := _end_opts
	match code:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_end_choose(String(ch[0][0]))
			return true
		KEY_ESCAPE:
			_end_choose(String(ch[-1][0]))
			return true
	return false


# --- Juice: event playback ----------------------------------------------------------
# Timing rule (game-feel review): every outcome fires when its round arrives; the camera frames
# who is acting; bodies wind up, recoil and react on the joint rig; HUD drains at impact.

const FIRE_GAP := {"smg": 0.06, "heavy_smg": 0.07, "assault_rifle": 0.085}
const SAFE := Rect2(260, 110, 0, 0)   # HUD-free area: left edge, top; right/bottom margins below
const SAFE_BOTTOM := 170.0

var _focus_unit := -1                 ## unit the see-through hole and cutaway follow during playback
var _shake_px := Vector2.ZERO         ## screen-space shake offset (buffer pixels) and its velocity
var _shake_vel := Vector2.ZERO
var _screen_base := Vector2.ZERO
var _callout_stack := {}              ## unit id → [count, msec] so callouts stack instead of overlapping
var _flash_lights := {}               ## unit id → pooled muzzle OmniLight3D


## Would this unit shoot the crew? (Red in the view; bystanders and medics are neutral.)
func _foe(u: Dictionary) -> bool:
	return enc.hostile(Encounter.CREW, int(u.team))


func _seen(v: Vector3i) -> bool:
	return not fog_on or enc.vision.visible.has(v)


func _body_pos(u: Dictionary) -> Vector3:
	return Vector3(u.pos.x + 0.5, _gy(u.pos), u.pos.y + 0.5)


## Events that don't count as "hostile activity" for the enemy-phase banner (bookkeeping, third
## parties, things the crew caused).
const QUIET_EVENTS := ["alert", "death", "camera", "tt_call", "av_land", "av_leave", "tt_pickup", "panic", "civ_gone"]

var _handlers: Dictionary = {}


## Event type (Encounter.events) → how the view plays it. Rules modules (objectives, responders)
## add event types; their view side registers a handler here (register_event) instead of growing
## a match statement. Unknown types are skipped.
func _event_handlers() -> Dictionary:
	if _handlers.is_empty():
		_handlers = {
			"move": _anim_move,
			"attack": _anim_attack,
			"cover": _anim_cover,
			"alert": _anim_alert,
			"reload": _anim_reload,
			"stabilize": _anim_stabilize,
			"rig": _ev_rig,
			"dose": _ev_dose,
			"suppress": _anim_suppress,
			"shell": _anim_shell,
			"blast": _anim_blast,
			"harm": _anim_harm,
			"alarm": _ev_alarm,
			"backup": _anim_backup,
			"bypass": _ev_bypass,
			"keycard": _ev_keycard,
			"tamper": _ev_tamper,
			"camera": _ev_camera,
			"death": _anim_death,
			"grab": _ev_grab,
			"drop": _ev_drop,
			"free": _ev_free,
			"plant": _ev_plant,
			"panic": _ev_panic,
			"civ_gone": _ev_civ_gone,
			"tt_call": _ev_tt_call,
			"av_land": _anim_av_land,
			"tt_pickup": _ev_tt_pickup,
			"av_leave": _anim_av_leave,
			"target_down": _ev_target_down,
			"escape": _ev_escape,
			"peace_broken": _ev_peace_broken,
		}
	return _handlers


func register_event(type: String, handler: Callable) -> void:
	_event_handlers()[type] = handler


func _play_events() -> void:
	var hostile_shown := false
	while not enc.events.is_empty():
		var e: Dictionary = enc.events.pop_front()
		var u: Dictionary = enc.units[e.unit]
		if enc.is_guard(u) and _foe(u) and not hostile_shown and String(e.type) not in QUIET_EVENTS and not e.get("patrol", false) and _event_visible(e):
			hostile_shown = true
			hud.enemy_phase(true)
			hud.turn_banner("HOSTILE ACTIVITY", Hud.RED)
			_ui_snd("sfx_ui_error", -10.0)
			await get_tree().create_timer(0.3).timeout
		var h: Variant = _event_handlers().get(String(e.type))
		if h != null:
			await (h as Callable).call(e)
	hud.enemy_phase(false)
	_focus_unit = -1


# --- Event handlers (registered in _event_handlers) ---------------------------------------

## The first fight in a neutral house (NeutralGround: Totentanz): a banner, and the bouncers shout.
func _ev_peace_broken(e: Dictionary) -> void:
	hud.turn_banner(enc.neutral.hud_text(), Hud.RED)   # the round tab's line, word for word
	_ui_snd("sfx_ui_error", -8.0)
	for id in e.get("units", []):
		var g: Dictionary = enc.units[int(id)]
		if g.get("bouncer", false) and _seen(g.pos):
			_float(g, "NOT IN MY HOUSE", Hud.RED)
	await get_tree().create_timer(0.6).timeout


func _ev_rig(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var rn: CharModel = unit_nodes[u.id]
	var rt: Dictionary = enc.units[e.target]
	_focus_unit = u.id
	if rt != u:
		var rd := Vector2(rt.pos.x - u.pos.x, rt.pos.y - u.pos.y)
		_turn_to(rn, atan2(rd.x, rd.y), 0.15)
	rn.perform("medtech", 1.0)
	await get_tree().create_timer(1.0).timeout
	_float(rt, ("%s ARMOUR RIGGED" % String(e.loc).to_upper()) if e.ok else "RIG FAILED", Hud.CYAN if e.ok else Hud.RED)
	await get_tree().create_timer(0.4).timeout


func _ev_dose(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var dn: CharModel = unit_nodes[u.id]
	var dt: Dictionary = enc.units[e.target]
	_focus_unit = u.id
	if dt != u:
		var dd := Vector2(dt.pos.x - u.pos.x, dt.pos.y - u.pos.y)
		_turn_to(dn, atan2(dd.x, dd.y), 0.15)
	dn.duck(0.4)
	await get_tree().create_timer(0.35).timeout
	_float(dt, ("SPEEDHEAL +%d" % int(e.healed)) if e.drug == "speedheal" else ("STIMMED" if e.drug == "stim" else String(e.get("name", e.drug)).to_upper()), Hud.GREEN)
	_snd("sfx_inject", _body_pos(dt), -4.0)
	await get_tree().create_timer(0.5).timeout


func _ev_alarm(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	if _seen(u.pos):
		_float(u, "CALLING IT IN", Hud.RED)
	hud.toast(Hud.countdown_text(enc.backup_label, int(e.rounds)))
	_snd("sfx_alarm", _body_pos(u), -6.0, 0.0, 500)


func _ev_bypass(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	_focus_unit = u.id
	var bn: CharModel = unit_nodes[u.id]
	var bc: Vector3i = e.cell
	var bd := Vector2(bc.x - u.pos.x, bc.y - u.pos.y)
	_turn_to(bn, atan2(bd.x, bd.y), 0.15)
	bn.perform("medtech", 1.2)
	var lockp := Vector3(bc.x + 0.5, _gy(bc) + 0.62, bc.y + 0.5)
	for k in 3:
		await get_tree().create_timer(0.3).timeout
		fx.lock_crackle(lockp, e.ok or k < 2)
	_float(u, "LOCK BYPASSED" if e.ok else ("BUZZER!" if e.loud else "BYPASS FAILED"), Hud.CYAN if e.ok else Hud.RED)
	if e.ok:
		hud.flash_screen(Color(0.2, 0.9, 1.0, 0.06))
	await get_tree().create_timer(0.4).timeout


func _ev_keycard(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	_focus_unit = u.id
	var kn: CharModel = unit_nodes[u.id]
	kn.duck(0.6)
	await get_tree().create_timer(0.35).timeout
	var fu: Dictionary = enc.units[e.from]
	fx.glint(Vector3(fu.pos.x + 0.5, _gy(fu.pos) + 0.4, fu.pos.y + 0.5))
	_float(u, "%s KEYCARD" % TacMap.ZONE_NAMES[int(e.zone)].to_upper(), Hud.GOLD)
	hud.toast("%d DOOR%s UNLOCKED" % [int(e.opened), "" if int(e.opened) == 1 else "S"])
	await get_tree().create_timer(0.5).timeout


func _ev_tamper(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	_focus_unit = u.id
	(unit_nodes[u.id] as CharModel).perform("idle_shift", 0.8)
	await get_tree().create_timer(0.6).timeout
	_float(u, "CAMERA DOWN" if e.ok else "TAMPER FAILED", Hud.CYAN if e.ok else Hud.RED)
	await get_tree().create_timer(0.4).timeout


func _ev_camera(e: Dictionary) -> void:
	var tu: Dictionary = enc.units[e.target]
	_float(tu, "ON CAMERA", Hud.RED)
	hud.toast("A CAMERA SPOTTED %s · TAKE THE CAMERAS IN THE NET" % tu.c.display_name.to_upper())


func _ev_grab(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var gn: CharModel = unit_nodes[u.id]
	_focus_unit = u.id
	gn.duck(0.6)
	await get_tree().create_timer(0.4).timeout
	_float(u, "PACKAGE RECOVERED", Hud.GOLD)
	_ui_snd("sfx_ui_confirm", -6.0)
	hud.toast("CARRY IT TO THE EXTRACTION ZONE")
	await get_tree().create_timer(0.5).timeout


func _ev_drop(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	_float(u, "PACKAGE DROPPED", Hud.RED)


func _ev_free(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var fnode: CharModel = unit_nodes[u.id]
	var ct: Dictionary = enc.units[e.target]
	_focus_unit = u.id
	fnode.duck(0.6)
	_snd("sfx_zap", _body_pos(ct), -10.0)
	await get_tree().create_timer(0.4).timeout
	_float(ct, "FREED", Hud.GOLD)
	_ui_snd("sfx_ui_confirm", -6.0)
	hud.toast("GET %s TO THE EXTRACTION ZONE" % ct.c.display_name.to_upper())
	await get_tree().create_timer(0.5).timeout


func _ev_plant(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var pn: CharModel = unit_nodes[u.id]
	_focus_unit = u.id
	pn.perform("medtech", 1.0)
	await get_tree().create_timer(0.8).timeout
	var pc: Vector3i = e.cell
	_make_charge(Vector3(pc.x + 0.5, _gy(pc), pc.y + 0.5))
	_snd("sfx_beep", _body_pos(u), 0.0)
	_float(u, "CHARGE SET", Hud.RED)
	hud.toast("%d ROUNDS · GET CLEAR OF THE BLAST" % int(enc.obj.cfg.get("fuse_rounds", 3)))
	await get_tree().create_timer(0.4).timeout


func _ev_panic(e: Dictionary) -> void:
	var shown := 0
	for pid in e.units:
		var pu: Dictionary = enc.units[pid]
		if _seen(pu.pos) and shown < 3:
			_float(pu, "SCREAMS", Color("ffd0a0"))
			shown += 1
	if shown > 0:
		hud.toast("BYSTANDERS SCATTER")


func _ev_civ_gone(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	(unit_nodes[u.id] as Node3D).visible = false


func _ev_tt_call(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	if _seen(u.pos):
		_float(u, "TRAUMA CARD", Color("2a8cff"))
	hud.turn_banner("TRAUMA TEAM INBOUND FOR %s · %d ROUNDS" % [u.c.display_name.to_upper(), Encounter.TT_ROUNDS], Color("2a8cff"))
	_ui_snd("sfx_beep", -4.0)


func _ev_tt_pickup(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var tu2: Dictionary = enc.units[e.target]
	_float(u, "PATIENT SECURED", Color("2a8cff"))
	(unit_nodes[tu2.id] as Node3D).visible = false
	await get_tree().create_timer(0.4).timeout


func _ev_target_down(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	_float(u, "TARGET FLATLINED" if u.c.dead else "TARGET DOWN", Hud.GOLD)
	_ui_snd("sfx_ui_confirm", -6.0)
	hud.toast("THE MARK IS DOWN · GET TO THE EXTRACTION ZONE OR WITHDRAW")


func _ev_escape(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	if _seen(u.pos):
		_float(u, "TARGET ESCAPED", Hud.RED)
	(unit_nodes[u.id] as Node3D).visible = false
	hud.toast("%s GOT AWAY" % String(enc.objective.get("name", "THE MARK")).to_upper())


func _event_visible(e: Dictionary) -> bool:
	match String(e.type):
		"move":
			return (e.path as Array).any(func(v): return _seen(v))
		"attack":
			return _seen(enc.units[e.unit].pos) or _seen(enc.units[e.target].pos)
	return _seen(enc.units[e.unit].pos)


## HUD-safe screen rect (outside the panels).
func _safe_rect() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	return Rect2(SAFE.position, Vector2(vs.x - SAFE.position.x - 40, vs.y - SAFE.position.y - SAFE_BOTTOM))


## Smoothly move the camera focus (and optionally zoom) over `secs`.
func _pan_to(p: Vector3, secs := 0.3, dist := -1.0) -> void:
	var from := cam_target
	var d0 := cam_dist
	var d1 := dist if dist > 0 else cam_dist
	var tw := create_tween()
	tw.tween_method(func(t: float):
		cam_target = from.lerp(Vector3(p.x, 0, p.z), t)
		cam_dist = lerpf(d0, d1, t)
		_place_camera(), 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Frame two points inside the safe rect, zooming out if they don't fit.
func _frame_pair(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) / 2
	var span := Vector2(a.x - b.x, a.z - b.z).length()
	var want := maxf(cam_dist, minf(60.0, span * 1.9 + 6.0))
	var sa := _to_screen(a)
	var sb := _to_screen(b)
	var sr := _safe_rect().grow(-40)
	if sr.has_point(sa) and sr.has_point(sb) and want <= cam_dist + 0.1:
		return
	await _pan_to(mid, 0.28, want)


## Walk the body along the path, square by square, facing the way it goes; the camera follows
## softly once the walker leaves the middle of the safe area.
func _anim_move(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var n: Node3D = unit_nodes[u.id]
	var path: Array = e.path
	if u.team != 0 and not _event_visible(e):
		return
	_focus_unit = u.id
	if _reel != "" and OS.has_environment("REEL_DEBUG"):
		print("move %s: %s" % [u.c.display_name, (path as Array).map(func(v): return "%d,%d,%d:%s%s" % [v.x, v.y, v.z, m.t(v.z, v.x, v.y), "C" if _cut_hides(v) else ""])])
	var step := 0.22 if e.run else 0.33   # matches the sprint / run clips' stride at unit scale
	if e.get("patrol", false):
		step = 0.62   # a patrol strolls (walk clip)
	n.set_meta("stroll", e.get("patrol", false))
	n.set_meta("walk", true)
	n.set_meta("run", e.run)
	n.set_meta("crouch_goal", 0.0)
	var inner := _safe_rect().grow_individual(-_safe_rect().size.x * 0.2, -_safe_rect().size.y * 0.2, -_safe_rect().size.x * 0.2, -_safe_rect().size.y * 0.2)
	for i in range(1, path.size()):
		var a: Vector3i = path[i - 1]
		var b: Vector3i = path[i]
		var d := Vector2(b.x - a.x, b.y - a.y)
		if d.length() > 0.01:
			_turn_to(n, atan2(d.x, d.y), 0.06)
		# hidden while on a storey above the cutaway (otherwise they float over the cut-away walls
		# below and seem to walk through them), and guards only where the crew can see
		n.visible = (u.team == 0 or _seen(a) or _seen(b)) and not (_cut_hides(a) and _cut_hides(b))
		var to := Vector3(b.x + 0.5, _gy(b), b.y + 0.5)
		for dv in [a, b]:   # doors open as the walker reaches them, not after the whole playback
			if m.t(dv.z, dv.x, dv.y) == TacMap.T.DOOR:
				_swing_door(dv)
		var tw := create_tween()
		tw.tween_property(n, "position", to, step * (1.0 if d.length() < 1.2 else 1.4))
		if n.visible:
			_snd("sfx_step", to, -10.0 if u.team == 0 else -12.0, 0.18, 60)
		(decals[u.id] as Node3D).position = to + Vector3(0, 0.03, 0)
		if u == enc.cur:
			ring.position = to + Vector3(0, 0.04, 0)
		if n.visible and not inner.has_point(_to_screen(to)):
			_pan_to(to, 0.35)   # soft follow (not awaited)
		await tw.finished
	n.set_meta("walk", false)


func _turn_to(n: Node3D, yaw: float, secs := 0.12) -> void:
	var goal := n.rotation.y + wrapf(yaw - n.rotation.y, -PI, PI)
	create_tween().tween_property(n, "rotation:y", goal, secs).set_trans(Tween.TRANS_SINE)


func _muzzle_of(n: Node3D) -> Vector3:
	var j: Dictionary = n.get_meta("j", {})
	var mz: Node3D = j.get("muzzle")
	return mz.global_position if mz and is_instance_valid(mz) else n.global_position + Vector3(0, 0.8, 0)


func _flash_light(uid: int) -> OmniLight3D:
	if not _flash_lights.has(uid) or not is_instance_valid(_flash_lights[uid]):
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		fx.add_child(l)
		_flash_lights[uid] = l
	return _flash_lights[uid]


## Where a missed round ends: offset clear of the body, then on along the line until it meets a
## wall or the floor.
func _miss_point(m0: Vector3, aim: Vector3) -> Vector3:
	var dir := (aim - m0).normalized()
	var side := dir.cross(Vector3.UP).normalized() * (fx.rng.randf_range(0.4, 0.75) * (1.0 if fx.rng.randf() < 0.5 else -1.0))
	var p := aim + side + Vector3(0, fx.rng.randf_range(-0.25, 0.45), 0)
	var d2 := (p - m0).normalized()
	for k in 48:
		p += d2 * 0.25
		var f := clampi(int(floor(p.y / FH)), 0, m.floors - 1)
		var c := Vector3i(int(floor(p.x)), int(floor(p.z)), f)
		if not m.inb(c.x, c.y) or p.y <= f * FH + 0.02 or enc.los.blocker(c) == "wall":
			return p
	return p


## Shots on the rig: lean out, turn and raise, fire round by round (each impact on arrival),
## recoil with muzzle climb, then the outcome on the last connecting round.
func _anim_attack(e: Dictionary) -> void:
	if not _event_visible(e):
		return
	var su: Dictionary = enc.units[e.unit]
	var tu: Dictionary = enc.units[e.target]
	var sn: Node3D = unit_nodes[su.id]
	var tn: Node3D = unit_nodes[tu.id]
	_focus_unit = su.id
	var restore_floor := -1
	if su.team == 0 and su.pos.z != view_floor:   # follow a crew shooter to their floor (XCOM-style)
		view_floor = su.pos.z
		_refresh()
	elif enc.is_guard(su) and maxi(su.pos.z, tu.pos.z) > view_floor and _seen(su.pos):   # a guard firing from above: lift the view for the shot
		restore_floor = view_floor
		view_floor = maxi(su.pos.z, tu.pos.z)
		_update_fog()
		_update_cut()
	sn.visible = sn.visible or _seen(su.pos)
	if e.get("jammed", false) and _seen(su.pos):   # a Poor Quality gun rolled a 1 (p.342)
		_float(su, "JAMMED", Hud.GOLD)
	tn.visible = tn.visible or _seen(tu.pos)
	await _frame_pair(_body_pos(su), _body_pos(tu))
	var wid := String(e.get("weapon", "assault_rifle"))
	if wid == "brawling" or wid.begins_with("martial") or wid.ends_with("_melee"):
		await _anim_melee(e, su, tu, sn, tn, wid)
		return
	sn.set_meta("aim_at", AimPreview.aim_point(_body_pos(tu), String(e.get("location", "body")) == "head"))   # before the weapon comes up
	var d := Vector2(tu.pos.x - su.pos.x, tu.pos.y - su.pos.y)
	# lean out of cover toward the firing square
	var home := sn.position
	var from: Vector3i = e.get("from", su.pos)
	if from != su.pos:
		var lean := Vector3(from.x - su.pos.x, 0, from.y - su.pos.y).normalized() * 0.35
		create_tween().tween_property(sn, "position", home + lean, 0.12)
	sn.set_meta("crouch_goal", 0.0)   # stand (or lean out) to fire: the muzzle clears low cover; crouch is only the idle in-cover pose
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), float(sn.get_meta("aim", 0.0)), 1.0, 0.1)
	await get_tree().create_timer(0.18).timeout
	var aim := AimPreview.aim_point(_body_pos(tu), String(e.get("location", "body")) == "head")
	sn.set_meta("aim_at", aim)
	var rounds: int = int(e.get("rounds", 1)) if int(e.mode) == Attack.Mode.AUTOFIRE else 1
	var connect: int = (int(e.get("mult", 1)) if int(e.mode) == Attack.Mode.AUTOFIRE else 1) if (e.hit and not e.dodged) else 0
	var hit_rounds := {}   # which rounds connect: spread through the burst
	for k in connect:   # floor, not round: a single shot's only round is index 0
		hit_rounds[mini(rounds - 1, int(floor(float(k + 1) * rounds / (connect + 1))))] = true
	var last_hit := -1
	for k in hit_rounds:
		last_hit = maxi(last_hit, k)
	var gap: float = FIRE_GAP.get(wid, 0.0)
	var light := _flash_light(su.id)
	if e.dodged:   # the dodge starts before the rounds arrive, so they pass through empty air
		var side := Vector3(-d.y, 0, d.x).normalized() * 0.32
		(tn as CharModel).duck(0.55)   # a snap down into cover stance while the body slips sideways
		var tw := create_tween()
		tw.tween_property(tn, "position", tn.position + side, 0.09).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25)
		tw.tween_property(tn, "position", tn.position, 0.2)
		_float(tu, "DODGE", Hud.CYAN)
		_snd("sfx_dodge", _body_pos(tu), -4.0)
	var arrived := [0]
	var outcome_shown := [false]
	for i in rounds:
		var m0 := _muzzle_of(sn)
		var dir := (aim - m0).normalized()
		fx.muzzle(m0, dir, wid, light, rounds == 1 or fx.rng.randf() > 0.25)
		if not wid.contains("launcher") and not wid.contains("bow"):
			fx.brass(m0 - dir * 0.35, dir.cross(Vector3.UP).normalized(), _gy(su.pos))
		var hits: bool = hit_rounds.has(i)
		var dest := aim + Vector3(fx.rng.randf_range(-0.08, 0.08), fx.rng.randf_range(-0.08, 0.08), fx.rng.randf_range(-0.08, 0.08)) if hits else _miss_point(m0, aim)
		var is_last := i == last_hit
		fx.bullet(m0, dest, wid, func():
			arrived[0] += 1
			if hits:
				if int(e.damage) > 0 and not is_last:   # rounds that get through bleed; armour sparks
					fx.blood(dest, dir, 0.4, _gy(tu.pos))
				elif int(e.damage) <= 0:
					fx.sparks(dest)
				if is_last:
					outcome_shown[0] = true
					_outcome(e, su, tu, tn, dest, dir)
			else:
				fx.burst(dest, Color("ffd27a"), 5, 2.0, 0.035, 0.2, 1.6)
				fx.burst(dest, Color("8a8478"), 3, 0.6, 0.12, 0.6, 0.0, 0.4))
		_recoil(sn, rounds > 1)
		_kick(_screen_dir(m0, aim) * -1.0, 1.0 if rounds > 1 else 1.5)
		await get_tree().create_timer(gap + fx.rng.randf_range(0.0015, 0.003) if rounds > 1 else 0.05).timeout
	# wait for the last round to land, then hold the framing a moment
	var t0 := Time.get_ticks_msec()
	while arrived[0] < rounds and Time.get_ticks_msec() - t0 < 600:
		await get_tree().process_frame
	if connect > 0 and not outcome_shown[0]:   # safety net: a hit always resolves on screen
		_outcome(e, su, tu, tn, aim, (aim - _muzzle_of(sn)).normalized())
	if not e.hit and not e.dodged:
		_float(tu, "MISS", Hud.DIM)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 1.0, 0.0, 0.25).set_delay(0.3)
	if from != su.pos:
		create_tween().tween_property(sn, "position", home, 0.15).set_delay(0.25)
	await get_tree().create_timer(0.45 if e.hit else 0.3).timeout
	if restore_floor >= 0:
		view_floor = restore_floor
		_update_fog()
		_update_cut()


# --- M5 actions: melee, reload, stabilize, suppressive fire, shotgun shells, grenades -----------

## Melee: a step in, the swing (brawling or blade clip), the outcome on contact, a step back.
func _anim_melee(e: Dictionary, su: Dictionary, tu: Dictionary, sn: Node3D, tn: Node3D, wid: String) -> void:
	var d := Vector2(tu.pos.x - su.pos.x, tu.pos.y - su.pos.y)
	_turn_to(sn, atan2(d.x, d.y), 0.1)
	_turn_to(tn, atan2(-d.x, -d.y), 0.15)
	var home := sn.position
	var lunge := Vector3(d.x, 0, d.y).normalized() * 0.3
	create_tween().tween_property(sn, "position", home + lunge, 0.18).set_trans(Tween.TRANS_QUAD)
	(sn as CharModel).play_once("melee_blade" if wid.ends_with("_melee") else "melee", 0.08)
	_snd("sfx_swing", _body_pos(su), -4.0)
	await get_tree().create_timer(0.38).timeout
	if e.hit and not e.dodged:
		_snd("sfx_melee_hit", _body_pos(tu), 0.0)
	var at := _body_pos(tu) + Vector3(0, 0.7, 0)
	var dir := Vector3(d.x, 0, d.y).normalized()
	if e.hit and not e.dodged:
		_outcome(e, su, tu, tn, at, dir)
		_kick(_screen_dir(at - dir, at), 3.0)
	else:
		_float(tu, "BLOCKED" if not e.dodged else "DODGE", Hud.CYAN)
	await get_tree().create_timer(0.35).timeout
	create_tween().tween_property(sn, "position", home, 0.2)
	await get_tree().create_timer(0.3).timeout


func _anim_reload(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	if not _seen(u.pos):
		return
	var n: CharModel = unit_nodes[u.id]
	_focus_unit = u.id
	var clip := ("pistol" if n.gun_kind == "pistol" else "rifle") + "_reload"
	n.play_once(clip, 0.12)
	_float(u, "RELOAD", Hud.CYAN)
	_snd("sfx_reload", _body_pos(u), 4.0)
	await get_tree().create_timer(minf(n.anim.get_animation(clip).length, 2.4) if n.anim.has_animation(clip) else 1.0).timeout


func _anim_stabilize(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var t: Dictionary = enc.units[e.target]
	var n: CharModel = unit_nodes[u.id]
	_focus_unit = u.id
	await _pan_to(_body_pos(t), 0.3)
	var d := Vector2(t.pos.x - u.pos.x, t.pos.y - u.pos.y)
	_turn_to(n, atan2(d.x, d.y), 0.15)
	n.perform("medtech", 1.8)
	await get_tree().create_timer(1.6).timeout
	_float(t, "STABILIZED" if e.ok else "STABILIZE FAILED", Hud.GREEN if e.ok else Hud.RED)
	if e.ok:
		(unit_nodes[t.id] as Node3D).set_meta("slump_goal", 0.0)
	await get_tree().create_timer(0.5).timeout


## Suppressive fire: ten rounds raked across everyone in range; nobody is hurt (p174), the ones
## who lose the contest are PINNED and will dive for cover on their turn.
func _anim_suppress(e: Dictionary) -> void:
	var su: Dictionary = enc.units[e.unit]
	var sn: Node3D = unit_nodes[su.id]
	_focus_unit = su.id
	var targets: Array = (e.targets as Array).map(func(i): return enc.units[i])
	var c := Vector3.ZERO
	for t in targets:
		c += _body_pos(t)
	c /= maxf(1.0, targets.size())
	await _frame_pair(_body_pos(su), c)
	var d := Vector2(c.x - _body_pos(su).x, c.z - _body_pos(su).z)
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	sn.set_meta("crouch_goal", 0.0)
	sn.set_meta("aim_at", c + Vector3(0, 0.7, 0))
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 0.0, 1.0, 0.1)
	await get_tree().create_timer(0.2).timeout
	var wid := String(e.weapon)
	var light := _flash_light(su.id)
	for i in 10:
		var t: Dictionary = targets[i % targets.size()]
		var aim := _body_pos(t) + Vector3(fx.rng.randf_range(-0.6, 0.6), fx.rng.randf_range(0.5, 1.1), fx.rng.randf_range(-0.6, 0.6))
		sn.set_meta("aim_at", aim)
		var m0 := _muzzle_of(sn)
		var dir := (aim - m0).normalized()
		fx.muzzle(m0, dir, wid, light, fx.rng.randf() > 0.25)
		fx.brass(m0 - dir * 0.35, dir.cross(Vector3.UP).normalized(), _gy(su.pos))
		var dest := _miss_point(m0, aim)
		fx.bullet(m0, dest, wid, func(): fx.burst(dest, Color("ffd27a"), 4, 2.0, 0.035, 0.2, 1.6))
		_recoil(sn, true)
		_kick(_screen_dir(m0, aim) * -1.0, 1.0)
		await get_tree().create_timer(FIRE_GAP.get(wid, 0.085)).timeout
	await get_tree().create_timer(0.3).timeout
	for t in targets:
		_float(t, "PINNED" if t.id in e.suppressed else "HOLDS", Hud.GOLD if t.id in e.suppressed else Hud.DIM)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 1.0, 0.0, 0.25).set_delay(0.3)
	await get_tree().create_timer(0.6).timeout


## Reinforcements arrive at an entrance: bodies appear there and the camera glances over.
func _anim_backup(e: Dictionary) -> void:
	var first: Dictionary = {}
	for id in e.units:
		var bu: Dictionary = enc.units[id]
		var n := _unit_node(bu)
		n.visible = _seen(bu.pos)
		if first.is_empty():
			first = bu
	hud.toast("%s HAS ARRIVED" % String(e.get("label", "BACKUP")))
	if not first.is_empty() and _seen(first.pos):
		await _pan_to(_body_pos(first), 0.4)
		await get_tree().create_timer(0.6).timeout


## Damage that isn't an attack (Black ICE brain damage, strained injuries): a number and a flash.
func _anim_harm(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	if not _seen(u.pos):
		return
	_float(u, "-%d %s" % [int(e.damage), String(e.source)], Hud.RED)
	_hit_flash(unit_nodes[u.id])
	hud.hit_unit(u.id)
	_hud_refresh()
	if int(e.wound_before) < Combatant.Wound.MORTAL and int(e.wound_after) >= Combatant.Wound.MORTAL:
		_die(u, unit_nodes[u.id], Vector3.FORWARD, enc.units[e.unit].c.dead)


## A per-target attack-like dict from an area hit, for _outcome.
func _area_outcome_event(h: Dictionary) -> Dictionary:
	var t: Dictionary = enc.units[h.id]
	return {"damage": h.damage, "sp_before": t.c.sp("body"), "sp_after": t.c.sp("body"), "crit": false, "crit_names": [],
		"location": "body", "wound_before": h.wound_before, "wound_after": h.wound_after, "killed": h.killed, "dead": h.dead, "hit": true, "dodged": h.dodged}


## Shotgun shell: one blast, pellets fanning into the cone, everyone caught reacts together.
func _anim_shell(e: Dictionary) -> void:
	var su: Dictionary = enc.units[e.unit]
	var tu: Dictionary = enc.units[e.target]
	var sn: Node3D = unit_nodes[su.id]
	_focus_unit = su.id
	await _frame_pair(_body_pos(su), _body_pos(tu))
	var d := Vector2(tu.pos.x - su.pos.x, tu.pos.y - su.pos.y)
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	sn.set_meta("crouch_goal", 0.0)
	sn.set_meta("aim_at", _body_pos(tu) + Vector3(0, 0.7, 0))
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 0.0, 1.0, 0.1)
	await get_tree().create_timer(0.2).timeout
	var m0 := _muzzle_of(sn)
	var dir := (_body_pos(tu) + Vector3(0, 0.7, 0) - m0).normalized()
	fx.muzzle(m0, dir, "shotgun", _flash_light(su.id))
	for k in 9:   # the spread: pellets fanning across the cone
		var spread := dir.rotated(Vector3.UP, fx.rng.randf_range(-0.6, 0.6)).rotated(dir.cross(Vector3.UP).normalized(), fx.rng.randf_range(-0.12, 0.12))
		var dest := m0 + spread * fx.rng.randf_range(4.0, 6.5)
		fx.bullet(m0, dest, "medium_pistol")
	_recoil(sn, false)
	_kick(_screen_dir(m0, m0 + dir) * -1.0, 3.0)
	await get_tree().create_timer(0.12).timeout
	if e.hit:
		for h in e.hits:
			var t: Dictionary = enc.units[h.id]
			if h.dodged:
				_float(t, "DODGE", Hud.CYAN)
				continue
			_outcome(_area_outcome_event(h), su, t, unit_nodes[t.id], _body_pos(t) + Vector3(0, 0.7, 0), (_body_pos(t) - _body_pos(su)).normalized())
	else:
		_float(tu, "MISS", Hud.DIM)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 1.0, 0.0, 0.25).set_delay(0.3)
	await get_tree().create_timer(0.7).timeout


## Grenade: the toss, the arc, the blast (light, fireball, smoke, scorch), damage to everyone caught,
## and broken cover flying apart.
func _anim_blast(e: Dictionary) -> void:
	var su: Dictionary = enc.units[e.unit]
	var sn: CharModel = unit_nodes[su.id]
	var center: Vector3i = e.center
	var at := Vector3(center.x + 0.5, _gy(center), center.y + 0.5)
	if e.get("charge", false):   # sabotage: the planted charge goes off (no throw)
		await _pan_to(at, 0.4)
		for k in 3:   # the last beeps
			_snd("sfx_beep", at, -2.0 + k * 2.0, 0.0, 0)
			await get_tree().create_timer(0.22).timeout
		if _charge_node and is_instance_valid(_charge_node):
			_charge_node.queue_free()
		fx.explosion(at, _gy(center))
		fx.explosion(at + Vector3(0.6, 0.3, -0.4), _gy(center))
		fx.explosion(at + Vector3(-0.5, 0.2, 0.5), _gy(center))
		hud.flash_screen(Color(1.0, 0.7, 0.35, 0.45))
		_kick(Vector2(1, -1).normalized(), 16.0)
		_hit_stop(140)
		for v in e.destroyed:
			builder.hide_cover(v)
			fx.shatter(Vector3(v.x + 0.5, v.z * FH + 0.4, v.y + 0.5), "steel", Vector3(v.x - center.x, 0, v.y - center.y), v.z * FH, true)
		_float_at(at + Vector3(0, 1.6, 0), "%s DESTROYED" % String(enc.objective.get("name", "TARGET")).to_upper(), Hud.GOLD)
		for h in e.hits:
			var t: Dictionary = enc.units[h.id]
			var dir := Vector3(t.pos.x - center.x, 0, t.pos.y - center.y)
			dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
			if h.dodged:
				_float(t, "DIVES CLEAR", Hud.CYAN)
				continue
			_outcome(_area_outcome_event(h), su, t, unit_nodes[t.id], _body_pos(t) + Vector3(0, 0.5, 0), dir)
		await get_tree().create_timer(1.4).timeout
		return
	_focus_unit = su.id
	await _frame_pair(_body_pos(su), at)
	var d := Vector2(at.x - _body_pos(su).x, at.z - _body_pos(su).z)
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	sn.play_once("grenade", 0.1)
	await get_tree().create_timer(1.15).timeout   # the release in the toss clip
	var hand := sn.head_point() + Vector3(0, 0.1, 0)
	var landed := [false]
	fx.grenade_arc(hand, at + Vector3(0, 0.06, 0), 0.75, func(): landed[0] = true)
	while not landed[0]:
		await get_tree().process_frame
	if not e.hit:
		_float_at(at + Vector3(0, 0.6, 0), "OFF TARGET", Hud.GOLD)
	await get_tree().create_timer(0.25).timeout   # it rattles for a moment
	fx.explosion(at, _gy(center))
	hud.flash_screen(Color(1.0, 0.75, 0.4, 0.25))
	_kick(Vector2(1, -1).normalized(), 8.0)
	_hit_stop(90)
	for v in e.destroyed:
		builder.hide_cover(v)
		var cv: Array = m.cover.filter(func(c): return c.floor == v.z and c.pos == Vector2i(v.x, v.y))
		fx.shatter(Vector3(v.x + 0.5, v.z * FH + 0.3, v.y + 0.5), String(cv[0].material) if not cv.is_empty() else "wood", Vector3(v.x - center.x, 0, v.y - center.y), v.z * FH, true)
	var gas: bool = String(e.get("payload", "")) != "" and Items.fx(String(e.payload)).get("no_damage", false)
	if not gas:
		_float_at(at + Vector3(0, 1.0, 0), "%d" % int(e.damage), Hud.GOLD)
	else:
		_float_at(at + Vector3(0, 1.0, 0), Items.display_name(String(e.payload)).to_upper(), Hud.GOLD)
	for h in e.hits:
		var t: Dictionary = enc.units[h.id]
		var dir := Vector3(t.pos.x - center.x, 0, t.pos.y - center.y)
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
		if h.dodged:
			_float(t, "DIVES CLEAR", Hud.CYAN)
			continue
		if gas:   # flash and gas: the check is the result
			_exotic_callouts({"status": h.get("status", {})}, su, t)
			continue
		_exotic_callouts({"ignited": h.get("ignited", false)}, su, t)
		_outcome(_area_outcome_event(h), su, t, unit_nodes[t.id], _body_pos(t) + Vector3(0, 0.5, 0), dir)
	await get_tree().create_timer(1.2).timeout


## Exotic weapon effects on the target (and the shooter), as floating words.
func _exotic_callouts(e: Dictionary, su: Dictionary, tu: Dictionary) -> void:
	var st: Dictionary = e.get("status", {})
	if not st.is_empty():
		var label: String = {"damaged_ear": "DEAFENED", "cyberware_disabled": "CHROME OFFLINE", "flashbang": "BLINDED · DEAFENED", "teargas": "BLINDED"}.get(String(st.get("name", "")), String(st.get("name", "")).to_upper())
		_float(tu, "RESISTED" if st.get("resisted", false) else label, Hud.DIM if st.get("resisted", false) else Hud.GOLD)
	if e.get("ignited", false):
		_float(tu, "ON FIRE", Hud.RED)
	if e.get("stunned", false):
		_float(tu, "STUNNED", Hud.GOLD)
	if String(e.get("self_hurt", "")) == "damaged_ear":
		_float(su, "EARS RINGING", Hud.DIM)


## The result on the target, when the connecting round lands.
func _outcome(e: Dictionary, su: Dictionary, tu: Dictionary, tn: Node3D, at: Vector3, dir: Vector3) -> void:
	_exotic_callouts(e, su, tu)
	var dmg := int(e.damage)
	if e.get("no_damage", false):   # paint, sound, microwaves: the effect is the hit (p347-349)
		_react(tn, dir, 0.3)
		if int(e.sp_after) < int(e.sp_before):
			_float(tu, "ACID · SP %d→%d" % [int(e.sp_before), int(e.sp_after)], Hud.GOLD)
		return
	if dmg <= 0:   # armour stopped it: sparks and a ricochet, cyan ARMOR and the SP ablation
		fx.burst(at, Color("fff0b0"), 14, 4.5, 0.04, 0.3, 2.0)
		fx.bullet(at, at + (Vector3.UP * 0.8 + dir.cross(Vector3.UP) * fx.rng.randf_range(-1.0, 1.0) - dir * 0.3).normalized() * 3.0, "medium_pistol")
		_float(tu, "ARMOR", Hud.CYAN)
		_snd("sfx_hit_armor", _body_pos(tu), -4.0, 0.1, 60)
		_float(tu, "SP %d→%d" % [int(e.sp_before), int(e.sp_after)], Hud.CYAN)
		_react(tn, dir, 0.4)
		_kick(_screen_dir(at - dir, at), 1.5)
		return
	fx.blood(at, dir, 1.6 if (e.crit or e.killed) else 1.0, _gy(tu.pos))
	_hit_flash(tn)
	_react(tn, dir, 1.0 if not e.crit else 1.5)
	_float(tu, "-%d" % dmg, Hud.RED)
	if String(e.get("location", "body")) == "head":
		_float(tu, "HEADSHOT", Hud.GOLD)
	if int(e.sp_after) < int(e.sp_before):
		_float(tu, "SP %d→%d" % [int(e.sp_before), int(e.sp_after)], Hud.CYAN)
	_kick(_screen_dir(at - dir, at), 2.0)
	hud.hit_unit(tu.id)
	_hud_refresh()   # HP drains at the moment of impact
	if e.crit:
		var names: Array = e.get("crit_names", [])
		_float(tu, "CRITICAL · %s" % (String(names[0]).to_upper() if not names.is_empty() else ""), Hud.GOLD)
		hud.flash_screen(Color(1, 0.2, 0.2, 0.22))
		_kick(_screen_dir(at - dir, at), 4.0)
		_hit_stop(90)
	if int(e.wound_before) < Combatant.Wound.SERIOUS and int(e.wound_after) == Combatant.Wound.SERIOUS:
		_float(tu, "SERIOUSLY WOUNDED", Color("ffb000"))
	if e.killed:
		_die(tu, tn, dir, bool(e.get("dead", true)), String(e.get("location", "body")) == "head")


func _hud_refresh() -> void:
	hud.tool = tool
	hud.stage = stage
	hud.atk_mode = atk_mode
	var active: Dictionary = Campaign.current.active_gig if _campaign_gig and Campaign.current else {}
	var place := place_label(m, active, String(gig.scene))
	hud.refresh(enc, mode, cover_mode, "%s  ·  %s" % [place.to_upper(), floor_label(m, view_floor)])


## Recoil: kick the weapon back and the chest up; autofire climbs, capped; settles with a spring.
func _recoil(n: Node3D, burst: bool) -> void:
	var r: float = n.get_meta("recoil", 0.0)
	n.set_meta("recoil", minf(r + (0.05 if burst else 0.12), 0.24))
	n.set_meta("recoil_kick", 1.0)


## Hit reaction: the upper body snaps away from the shot, then springs back.
func _react(n: Node3D, dir: Vector3, strength: float) -> void:
	n.set_meta("hit_dir", dir)
	n.set_meta("hit_t", 0.0)
	n.set_meta("hit_amp", strength)
	var tw := create_tween()   # a small shove along the shot
	tw.tween_property(n, "position", n.position + Vector3(dir.x, 0, dir.z).normalized() * 0.08 * strength, 0.05)
	tw.tween_property(n, "position", n.position, 0.22)


func _hit_flash(n: Node3D) -> void:
	for mt in n.get_meta("mats", []):
		(mt as ShaderMaterial).set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float):
		for mt in n.get_meta("mats", []):
			(mt as ShaderMaterial).set_shader_parameter("flash", v), 1.0, 0.0, 0.25)


## Death: a death clip picked by where the shot came from (CharModel.die); the weapon drops.
## Mortally Wounded units slump to their knees instead (they can still be stabilised).
func _die(u: Dictionary, n: Node3D, dir: Vector3, dead: bool, head := false) -> void:
	n.set_meta("slump_goal", 1.0)
	if not dead:
		_float(u, "MORTALLY WOUNDED", Hud.RED)
		return
	_float(u, "FLATLINED", Hud.RED)
	(n as CharModel).die(dir, head)
	await get_tree().create_timer(0.35).timeout   # the model lets the gun fall (CharModel._drop_gun)
	fx.pool(_body_pos(u))
	(decals[u.id] as Node3D).visible = false


func _anim_cover(e: Dictionary) -> void:
	var su: Dictionary = enc.units[e.unit]
	var sn: Node3D = unit_nodes[su.id]
	var cell: Vector3i = e.cell
	var at := Vector3(cell.x + 0.5, cell.z * FH + 0.45, cell.y + 0.5)
	sn.set_meta("aim_at", at)
	sn.set_meta("crouch_goal", 0.0)   # stand to fire: never shoot into the cover you're crouched behind
	_focus_unit = su.id
	var d := Vector2(cell.x - su.pos.x, cell.y - su.pos.y)
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 0.0, 1.0, 0.1)
	await get_tree().create_timer(0.15).timeout
	var m0 := _muzzle_of(sn)
	var wid := String(e.get("weapon", "assault_rifle"))
	fx.muzzle(m0, (at - m0).normalized(), wid, _flash_light(su.id))
	_recoil(sn, false)
	var left: int = int(e.get("left", 1))   # HP after this shot (later shots in the same playback don't leak back)
	var gone: bool = left <= 0
	var is_cover: bool = e.get("is_cover", false)
	fx.bullet(m0, at, wid, func():
		fx.debris(at, gone)
		if gone:
			if is_cover:
				builder.hide_cover(cell)   # the piece breaks apart: chunks fly and stay on the floor
				var cv: Array = m.cover.filter(func(c): return c.floor == cell.z and c.pos == Vector2i(cell.x, cell.y))
				fx.shatter(Vector3(cell.x + 0.5, cell.z * FH + 0.3, cell.y + 0.5), String(cv[0].material) if not cv.is_empty() else "concrete", (at - m0).normalized(), cell.z * FH, cv.size() > 0 and bool(cv[0].get("thick", false)))
			else:
				_rebuild = true            # a wall gave way: rebuild after playback
		_kick(_screen_dir(m0, at), 4.0 if gone else 1.5)
		_float_at(at + Vector3(0, 0.5, 0), "-%d · %s" % [int(e.damage), "DESTROYED" if gone else "%d HP" % left], Hud.GOLD if gone else Hud.TEXT))
	await get_tree().create_timer(0.45).timeout
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 1.0, 0.0, 0.25)


## A Mortally Wounded unit fails its Death Save at the start of its turn (p222): it dies where it
## knelt, toppling backwards.
func _anim_death(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var n: Node3D = unit_nodes[u.id]
	if not _seen(u.pos) or n.get_meta("fallen", false):
		return
	get_tree().create_timer(0.55).timeout.connect(func(): _snd("sfx_death", _body_pos(u), -2.0))
	_focus_unit = u.id
	await _pan_to(_body_pos(u), 0.3)
	_float(u, "DEATH SAVE FAILED", Hud.RED)
	await _die(u, n, -n.global_transform.basis.z, true)
	await get_tree().create_timer(1.2).timeout


func _anim_alert(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	if _seen(u.pos):
		(unit_nodes[u.id] as Node3D).visible = true
		_float(u, "!", Hud.RED)
		hud.flash_screen(Color(1, 0.15, 0.2, 0.12))
	_hud_refresh()   # the stealth chip flips to ENGAGED now, not after playback


# --- Shake and hit-stop (screen space: whole buffer pixels, so the pixel art never crawls) ----

func _screen_dir(a: Vector3, b: Vector3) -> Vector2:
	var v := cam.unproject_position(b) - cam.unproject_position(a)
	return v.normalized() if v.length() > 0.01 else Vector2.RIGHT


func _kick(dir: Vector2, px: float) -> void:
	_shake_vel += dir * px * 60.0


func _hit_stop(ms: int) -> void:
	var tws := get_tree().get_processed_tweens()
	for t in tws:
		t.pause()
	fx.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	for t in tws:
		if t.is_valid():
			t.play()
	fx.process_mode = Node.PROCESS_MODE_INHERIT


func _update_shake(delta: float) -> void:
	# damped spring back to rest, in small sub-steps: one big explicit step is unstable at low
	# frame rates (at 12 fps the offset blew up and threw the view off screen)
	var left := minf(delta, 0.25)
	while left > 0.0:
		var h := minf(left, 1.0 / 240.0)
		left -= h
		_shake_vel += (-_shake_px * 600.0 - _shake_vel * 22.0) * h
		_shake_px += _shake_vel * h
	if _shake_px.length() < 0.05 and _shake_vel.length() < 0.5:
		_shake_px = Vector2.ZERO
		_shake_vel = Vector2.ZERO
	screen.position = _screen_base + _shake_px.round() * _px()


func _toast_new_log() -> void:
	for i in range(_log_seen, enc.log.size()):
		if enc.log[i].contains("spots"):
			hud.toast("⚠ " + enc.log[i].to_upper())
	_log_seen = enc.log.size()


## Floating callout over a unit, on the HUD layer so it stays crisp above the pixel filter.
## Callouts on the same unit stack upward instead of overlapping; all stay inside the safe rect.
func _float(u: Dictionary, text: String, col: Color, offset := Vector2.ZERO) -> void:
	var now := Time.get_ticks_msec()
	var st: Array = _callout_stack.get(u.id, [0, 0])
	var k: int = st[0] + 1 if now - int(st[1]) < 900 else 0
	_callout_stack[u.id] = [k, now]
	var n: Node3D = unit_nodes.get(u.id)
	var base := n.global_position if n else _body_pos(u)
	_float_at(base + Vector3(0, 1.4, 0), text, col, offset + Vector2(0, -30 * k))


func _float_at(wp: Vector3, text: String, col: Color, offset := Vector2.ZERO) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Hud.F_DISPLAY)
	l.add_theme_font_size_override("font_size", 30 if text.length() > 3 else 40)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(Hud.MAGENTA, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	var sr := _safe_rect()
	var p := _to_screen(wp) - Vector2(30, 20) + offset
	l.position = Vector2(clampf(p.x, sr.position.x, sr.end.x - 200), clampf(p.y, sr.position.y, sr.end.y))
	l.scale = Vector2(1.25, 1.25)
	hud.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 46, 1.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.tween_callback(l.queue_free)


## The pointer moved to another square: the path ribbon, the sight lines that matter for it, and
## the building it points into (AUTO cutaway opens it).
var _promo := false


func _hide_overlays() -> void:
	if hud:
		hud.visible = false
	for n in [grid_node, path_node, watch_node, caret, ring, obj_node]:
		if n and is_instance_valid(n):
			(n as Node3D).visible = false


func _snd(name: String, at: Vector3, vol := 0.0, pitch_var := 0.06, gap := 25) -> void:
	if AudioDirector.I and is_instance_valid(AudioDirector.I):
		AudioDirector.I.sfx(name, at, vol, pitch_var, gap)


func _ui_snd(name: String, vol := 0.0) -> void:
	if AudioDirector.I and is_instance_valid(AudioDirector.I):
		AudioDirector.I.ui(name, vol)


const AMBIENCE := {"undercity": ["amb_undercity", 0.8, 0.3], "arcology": ["amb_arcology", 0.7, 0.2], "warzone": ["amb_warzone", 0.5, 0.12],
	"badlands": ["amb_badlands", 0.2, 0.04]}


## The scene's ambience and room sound, and calm or combat music by the encounter's state.
func _update_audio() -> void:
	var ad := AudioDirector.I
	if ad == null or not is_instance_valid(ad) or enc == null:
		return
	var a: Array = AMBIENCE.get(String(m.params.get("scene", "")), ["amb_city", 0.45, 0.12])
	ad.ambience(String(a[0]))
	ad.set_space(float(a[1]), float(a[2]))
	var fighting: bool = enc.alarm >= 1 or enc.engaged()
	ad.music("" if enc.state != "playing" else ("combat" if fighting else "explore"))


func _on_hover_changed() -> void:
	_draw_path()
	_draw_watch(grid_node != null and grid_node.visible)
	var hs := -1
	var hu := _unit_at(hover)
	if _crew_turn() and (move_opts.has(hover) or dash_opts.has(hover) or (not hu.is_empty() and _foe(hu))):
		hs = _indoor_structure(hover)
	if hs != _hover_sid:
		_hover_sid = hs
		_update_fog()


func _update_hover() -> void:
	_aim = {}
	hud.mode_pcts({})
	if blast_node and tool != "grenade":
		blast_node.visible = false
	if not _crew_turn():
		hud.tip("", mouse)
		return
	if tool != "":
		_tool_hover()
		return
	var t := _unit_at(hover)
	if t.is_empty() or t.team == 0 or enc.cur.c.weapons.is_empty():
		if cover_mode and enc.los.blocker(hover) != "":
			hud.tip("[b]%s[/b]" % ("Cover piece · [code]%d HP[/code]" % enc.los.cover_hp[hover] if enc.los.cover_hp.get(hover, 0) > 0 else "Wall / door"), mouse, "// SHOOT COVER", Hud.GOLD)
		elif move_opts.has(hover):
			var p: Array[Vector3i] = enc._with_locks(func(): return enc.nav.path(enc.cur.pos, hover, enc.occupied(enc.cur)))
			var ws := _watch_status()
			var warn := ""
			if ws.seen > 0:
				warn = "\n[color=#ff3b4f]In sight of %d watcher%s on the way[/color]" % [ws.seen, "" if ws.seen == 1 else "s"]
			elif ws.near:
				warn = "\n[color=#ff8a24]Ends at the edge of a guard's sight[/color]"
			hud.tip("[code]%d / %d[/code] squares%s" % [enc.nav.cost_of(enc.cur.pos, p), enc.turn.squares_available(), warn], mouse, "// MOVE", Hud.CYAN)
		elif dash_opts.has(hover):
			hud.tip("Uses your [b]Action[/b] as a Run (an extra Move Action)", mouse, "// RUN", Color("ffb000"))
		else:
			hud.tip("", mouse)
		return
	var w: Weapon = enc.cur.c.weapons[0]
	if not busy and unit_nodes.has(enc.cur.id) and AimPreview.for_weapon(w) != AimPreview.SWING:   # the active unit turns to aim at the hovered target (melee: the wind-up turns it)
		var dd := Vector2(t.pos.x - enc.cur.pos.x, t.pos.y - enc.cur.pos.y)
		(unit_nodes[enc.cur.id] as Node3D).rotation.y = atan2(dd.x, dd.y)
	var p := enc.preview(t, w, mode)
	_set_aim(AimPreview.for_weapon(w), p.from if p.ok else enc.cur.pos, t, roundi(p.chance * 100) if p.ok else -1, p.blocker if not p.ok else Vector3i(-1, -1, -1), mode == Attack.Mode.AIMED_HEAD, w.id())
	var pcts := {}
	for m in Encounter.attack_modes(w):   # hit chance per attack, shown on the bar's buttons
		if ATK_ENUM.has(m):
			var pm := enc.preview(t, w, ATK_ENUM[m])
			pcts[m] = roundi(pm.chance * 100) if pm.ok else -1
	hud.mode_pcts(pcts)
	var c: Combatant = t.c
	var lines: Array[String] = []
	if p.ok:
		var pct := roundi(p.chance * 100)
		var col := "#39f0a0" if pct >= 65 else ("#f9c80e" if pct >= 35 else "#ff3b4f")
		lines.append("[code][font_size=44][color=%s]%d%%[/color][/font_size][/code]  to hit · %s" % [col, pct, ["Single Shot", "Autofire", "Aimed Shot: head", "Aimed Shot: leg", "Aimed Shot: held item"][mode]])
		lines.append("Range %d m · DV %d · %s" % [roundi(Los.distance_m(p.from, t.pos)), int(p.dv), w.def.name])
		if p.blocker.x >= 0 and p.from != enc.cur.pos:
			lines.append("[color=#05d9e8]Leaning out of cover[/color]")
	else:
		lines.append("[color=#ff3b4f]%s[/color]" % String(p.reason).capitalize())
	# CPR armour often stops everything: show what the weapon averages through it
	var loc := "head" if mode == Attack.Mode.AIMED_HEAD else "body"
	var avg := w.dice() * 3.5
	var thru := maxf(0.0, avg - c.sp(loc)) * (2.0 if loc == "head" else 1.0)
	lines.append("[code]%dd6 vs SP %d: ~%d through[/code]" % [w.dice(), c.sp(loc), roundi(thru)] + ("  [color=#ff3b4f]armor likely stops it[/color]" if thru < 1.0 else ""))
	lines.append(Hud.stat_block(c, false, _unit_conditions(t)))
	var st := Hud.stance(enc, int(t.team))
	hud.tip("\n".join(lines), mouse, "// TARGET · " + st, Hud.stance_col(st))
