class_name ChromeBody
extends Control
## The cyberware body (owner, on the first line figure: "more stylized"; the lead's direction, after
## Cyberpunk 2077's ripperdoc and Deus Ex: Human Revolution's augmentation screen): the crew
## member's own 3D model (CharModel, outfitted as in gigs), rendered in a SubViewport as a hologram
## (holo_body.gdshader: a cyan fresnel rim, a faint lit fill, contour slices, drifting scanlines, a
## scan sweep and a flicker; holo_glow.gdshader blooms it). Body regions with chrome in them glow
## violet, plated; meat stays cyan; the selected location is gold; external chrome is a violet skin
## at the edge. It idles and turns a little (none of that under reduced motion), and turns on a drag.
## Every location (Cyber.LOCS) has a callout card joined by a leader line to its place on the body:
## the anchor is the model's bone (head, eyes, ear, neck, chest, arms, legs) projected to the screen,
## so the lines land on the body as it moves. A card shows what's there (the foundation and the
## pieces) and its Option Slots as pips: filled, empty or locked (no foundation yet). Every installed
## piece is named and filled, its effect played yet or not (owner, 2026-11-11).
## The Med Bay's ripperdoc picks a location or an installed piece here (loc_pressed, piece_pressed;
## a click on the body picks the nearest place); the loadout screen shows it read-only (clicks only
## select). Built from Controls, so tests can read `cards` and each card's `pips` meta. Headless
## (tests) the viewport doesn't draw but the model still poses, so anchors come from its bones.

signal loc_pressed(loc: String)
signal piece_pressed(loc: String, id: String)

## The figure's frame (its aspect; the model is fitted to its height); the character faces the
## viewer, so their right side is on the viewer's left.
const FIG := Vector2(150, 440)
## Where each location's leader line meets the body when there is no model to read (in a 200x440
## frame, scaled to the figure's).
const ANCHORS := {"neural_link": Vector2(100, 18), "chipware": Vector2(100, 64), "right_eye": Vector2(92, 32),
	"left_eye": Vector2(108, 32), "cyberaudio": Vector2(125, 38), "right_arm": Vector2(33, 230), "left_arm": Vector2(167, 230),
	"right_leg": Vector2(79, 350), "left_leg": Vector2(121, 350), "internal": Vector2(100, 110), "external": Vector2(70, 270),
	"fashion": Vector2(170, 262), "borgware": Vector2(140, 84)}
## Where each location sits on the model: [bone, toward bone, t, offset (m)]: the point t of the
## way from the first bone to the second, plus the offset in the first bone's space (alone) or in
## the hips' (a point between two bones). The Quaternius rig's rest bases are identity, +Z forward.
const BONES := {
	"neural_link": ["Head", "", 0.0, Vector3(0, 0.205, -0.02)],
	"right_eye": ["Head", "", 0.0, Vector3(-0.034, 0.1, 0.085)],
	"left_eye": ["Head", "", 0.0, Vector3(0.034, 0.1, 0.085)],
	"cyberaudio": ["Head", "", 0.0, Vector3(0.078, 0.085, 0.0)],
	"chipware": ["Neck", "Head", 0.45, Vector3(0, 0, 0.035)],
	"internal": ["UpperChest", "", 0.0, Vector3(0, -0.03, 0.11)],
	"borgware": ["LeftShoulder", "LeftUpperArm", 0.8, Vector3(0, 0.05, 0)],
	"right_arm": ["RightUpperArm", "RightLowerArm", 0.85, Vector3.ZERO],
	"left_arm": ["LeftUpperArm", "LeftLowerArm", 0.85, Vector3.ZERO],
	"fashion": ["LeftLowerArm", "LeftHand", 0.85, Vector3.ZERO],
	"external": ["RightUpperLeg", "RightLowerLeg", 0.3, Vector3(-0.075, 0, 0.0)],
	"right_leg": ["RightLowerLeg", "RightFoot", 0.3, Vector3.ZERO],
	"left_leg": ["LeftLowerLeg", "LeftFoot", 0.3, Vector3.ZERO],
}
## The callout columns (each stacked in its anchors' top-to-bottom order, so no leader lines cross).
const LEFT_COL: Array[String] = ["neural_link", "right_eye", "internal", "right_arm", "external", "right_leg"]
const RIGHT_COL: Array[String] = ["left_eye", "cyberaudio", "chipware", "borgware", "left_arm", "fashion", "left_leg"]
## Option Slots a location would hold once its foundation is in (shown as locked pips until then).
const LOCKED_SLOTS := {"neural_link": 5, "chipware": 1, "right_eye": 3, "left_eye": 3, "cyberaudio": 3}
const LIMBS: Array[String] = ["right_arm", "left_arm", "right_leg", "left_leg"]

const CHROME := Color("c77dff")       ## Hud.VIOLET lightened: chrome
const MEAT := Color(0.02, 0.85, 0.91, 0.75)   ## Hud.CYAN, a little dimmed: meat
const GAP := 26.0                      ## between a card column and the figure
const CARD_MIN := 150.0
const CARD_MAX := 232.0

const HOLO := preload("res://src/ui/screens/holo_body.gdshader")
const GLOW := preload("res://src/ui/screens/holo_glow.gdshader")
## The model's height in its own space (the 1.8 m body at CharModel.SCALE, plus hair): fitted to
## the figure frame.
const MODEL_H := 0.92
const YAW := -16.0        ## degrees: a three-quarter view, turned toward the viewer's left
const SWAY := 10.0        ## degrees each way, over SWAY_T seconds (none under reduced motion)
const SWAY_T := 18.0
const CAM_DIST := 3.2     ## a long lens: a little depth, nearly a flat scan
const MAX_PX := 1400      ## the viewport's tallest side, in pixels
const POSE_CLIP := "idle_shift"
## The char.gdshader parameters the hologram reads the outfit from.
const OUTFIT := ["tex", "albedo", "skin", "jacket", "sleeve", "forearm", "pants", "boots", "gloves", "belt", "belt_y", "coat_y", "boots_y"]
## Body regions the hologram tints (vertex COLOR.r, from each vertex's dominant bone).
enum Reg { TORSO, HEAD, NECK, R_ARM, L_ARM, R_LEG, L_LEG, R_EYE, L_EYE }
const REGION_LOCS := {Reg.HEAD: "neural_link", Reg.NECK: "chipware", Reg.R_ARM: "right_arm", Reg.L_ARM: "left_arm",
	Reg.R_LEG: "right_leg", Reg.L_LEG: "left_leg", Reg.R_EYE: "right_eye", Reg.L_EYE: "left_eye"}

var c: Combatant
var compact := false       ## short screens (1600x900 is ~600 logical lines): smaller cards
var sel_loc := ""
var sel_id := ""
var hints := {}            ## loc → storage pieces that can go in there now (the Med Bay's "+N")
var cards := {}            ## loc → its callout card
var anchors := {}          ## loc → where its leader line meets the body, in this control
var _fig := Rect2()        ## the figure's frame in this control
var _motion := true        ## off under reduced motion: no turn, idle, sweep or flicker
var _vp: SubViewport       ## the hologram stage (renders only while this is visible)
var _model: CharModel
var _cam: Camera3D
var _holo: TextureRect     ## shows the stage, with the bloom
var _over: Control         ## leader lines and anchor marks, over the figure, under the cards
var _drag := 0.0           ## degrees the player has turned the figure (eases back when let go)
var _dragging := false
var _press := Vector2(-1, -1)
static var _meshes := {}   ## source mesh → its hologram copy (regions in COLOR.r)


func setup(p_c: Combatant, p_sel_loc := "", p_sel_id := "", p_hints := {}, p_compact := false) -> ChromeBody:
	c = p_c
	compact = p_compact
	sel_loc = p_sel_loc
	sel_id = p_sel_id
	hints = p_hints
	name = "ChromeBody"
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	custom_minimum_size = Vector2(2 * _card_min() + 2 * GAP + 120, 360 if compact else 440)
	for ch in get_children():
		ch.free()
	cards.clear()
	anchors.clear()
	_model = null
	_motion = not GameSettings.reduced_motion()
	_build_stage()
	_over = Overlay.new()
	_over.body = self
	_over.name = "Leaders"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_over)
	for loc in LEFT_COL + RIGHT_COL:
		var card := _card(loc)
		cards[loc] = card
		add_child(card)
	_layout()
	return self


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _process(delta: float) -> void:
	if _model == null or not is_visible_in_tree():
		return
	if not _dragging:
		_drag = lerpf(_drag, 0.0, minf(1.0, delta * 1.6))
	var t := Time.get_ticks_msec() / 1000.0
	var sway := SWAY * sin(TAU * t / SWAY_T) if _motion else 0.0
	_model.rotation.y = deg_to_rad(YAW + sway + _drag)
	_read_anchors()
	_over.queue_redraw()


# --- The model, as the cards show it (static: tests read it too) ------------------------------

## A location's Option Slots as pips: [{state, id}], state "filled" (a piece), "empty" or "locked"
## (no foundation yet: what it would hold). A piece takes as many pips as Option Slots (a chip one;
## a Subdermal Grip also one of the Neural Link's). A meat arm or leg holds one piece: one pip.
## Borgware: none.
static func pips(implants: Array, loc: String) -> Array:
	var out: Array = []
	if loc == "borgware":
		return out
	if Cyber.is_meat(implants, loc):
		var mp := Cyber.meat_pieces(implants, loc)
		for p in mp:
			out.append({"state": "filled", "id": String(p.id)})
		if mp.is_empty():
			out.append({"state": "empty", "id": ""})
		return out
	var cap := Cyber.capacity(implants, loc)
	var taken: Array = []
	for p in Cyber.pieces_at(implants, loc):
		var id := String(p.id)
		if Cyber.is_foundation(id):
			continue
		taken.append([id, 1 if loc == "chipware" else int(Cyber.def(id).get("slots", 1))])
	if loc == "neural_link":
		for p in implants:
			var ns := int(Cyber.def(String(p.id)).get("neural_slot", 0))
			if ns > 0 and String(p.loc) != "neural_link":
				taken.append([String(p.id), ns])
	if cap <= 0 and taken.is_empty() and Cyber.foundation_at(implants, loc) == "":
		for i in int(LOCKED_SLOTS.get(loc, 0)):
			out.append({"state": "locked", "id": ""})
		return out
	for t in taken:
		for i in int(t[1]):
			out.append({"state": "filled", "id": String(t[0])})
	for i in maxi(0, cap - Cyber.used(implants, loc)):
		out.append({"state": "empty", "id": ""})
	return out


## The card's line: the foundation (or Meat / Empty) and the pieces in it, "Cybereye · Targeting
## Scope". A meat limb's Standard Hand/Foot isn't listed (it doesn't count there, Cyber.meat_pieces).
static func line(implants: Array, loc: String) -> String:
	var parts: Array[String] = []
	var f := Cyber.foundation_at(implants, loc)
	if f != "":
		parts.append(Cyber.display(f))
	elif loc in LIMBS or loc in Cyber.EYES:
		parts.append("Meat")
	var ps := Cyber.meat_pieces(implants, loc) if Cyber.is_meat(implants, loc) else Cyber.pieces_at(implants, loc)
	for p in ps:
		if String(p.id) != f:
			parts.append(Cyber.display(String(p.id)))
	if parts.is_empty():
		parts.append("Empty")
	return " · ".join(parts)


## Whether anything is installed at `loc` (seen or not): the card's violet edge.
static func chromed(implants: Array, loc: String) -> bool:
	return not Cyber.pieces_at(implants, loc).filter(func(p): return not Cyber.def(String(p.id)).get("free_in_meat", false)).is_empty()


# --- Cards ------------------------------------------------------------------------------------

func _card(loc: String) -> PanelContainer:
	var on := loc == sel_loc
	var chrome := chromed(c.implants, loc)
	var p := PanelContainer.new()
	p.name = "Card_" + loc
	var fill := Color(0.11, 0.09, 0.02, 0.96) if on else Color(0.025, 0.035, 0.05, 0.94)
	var edge := Hud.GOLD if on else (Color(CHROME, 0.7) if chrome else Color(Hud.DIM, 0.35))
	p.add_theme_stylebox_override("panel", CutBox.make(fill, edge, 6, 0b0101 if loc in LEFT_COL else 0b1010, Hud.GOLD if on else Color(0, 0, 0, 0), 4 if compact else 5))
	var v := UiKit.vbox(1 if compact else 2)
	p.add_child(v)
	var top := UiKit.hbox(4)
	v.add_child(top)
	var head := UiKit.label(Cyber.loc_name(loc), 11 if compact else 12, Hud.GOLD if on else (CHROME if chrome else Hud.CYAN))
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	var n := int(hints.get(loc, 0))
	if n > 0:   # the Med Bay: pieces in storage that can go in here now
		var h := UiKit.label("+%d" % n, 12, Hud.GREEN)
		h.name = "Hint"
		top.add_child(h)
	var ps := pips(c.implants, loc)
	p.set_meta("pips", ps)
	if not ps.is_empty():
		var row := UiKit.hbox(3)
		row.name = "Pips"
		v.add_child(row)
		for pp in ps:
			var pip := Pip.new()
			pip.state = String(pp.state)
			if compact:
				pip.custom_minimum_size = Vector2(9, 9)
			pip.on = String(pp.id) != "" and String(pp.id) == sel_id and on
			row.add_child(pip)
	var txt := line(c.implants, loc)
	var l := UiKit.fit(UiKit.body(txt, 12 if compact else 13, Hud.TEXT if chrome else Hud.DIM, false))
	l.name = "Line"
	v.add_child(l)
	var lc := loc
	UiKit.clickable(p, func(): loc_pressed.emit(lc))
	var pr := p.find_child("Pips", true, false)
	if pr:   # a filled pip picks its piece (after clickable, which mutes the children)
		for i in pr.get_child_count():
			var pid := String(ps[i].id)
			var pip: Pip = pr.get_child(i)
			if String(ps[i].state) == "filled":
				pip.mouse_filter = Control.MOUSE_FILTER_STOP
				pip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				pip.tooltip_text = Cyber.display(pid)
				pip.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						piece_pressed.emit(lc, pid)
						pip.accept_event())
	return p


## One Option Slot.
class Pip extends Control:
	var state := "empty"
	var on := false

	func _init() -> void:
		custom_minimum_size = Vector2(11, 11)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(0.5, 0.5), size - Vector2(1, 1))
		var k := 3.0   # a chamfered corner, like the panels
		var pts := PackedVector2Array([r.position + Vector2(k, 0), r.end - Vector2(0, r.size.y), Vector2(r.end.x, r.end.y - k),
			Vector2(r.end.x - k, r.end.y), Vector2(r.position.x, r.end.y), r.position + Vector2(0, k)])
		var col: Color = Hud.GOLD if on else ChromeBody.CHROME
		match state:
			"filled":
				draw_colored_polygon(pts, Color(col, 0.9))
			"empty":
				pts.append(pts[0])
				draw_polyline(pts, Color(col, 0.75), 1.0)
			"locked":
				pts.append(pts[0])
				draw_polyline(pts, Color(Hud.DIM, 0.3), 1.0)
				draw_line(Vector2(3, 3), Vector2(size.x - 3, size.y - 3), Color(Hud.DIM, 0.35), 1.0)


# --- The hologram -----------------------------------------------------------------------------

## The stage: the crew member's model (as base_view dresses them), a camera, and the TextureRect
## that shows it. The viewport updates only while this control is visible.
func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.name = "HoloStage"
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(4, 4)
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_vp)
	# a campaign crew member's own look; one without (a dev gig's sample crew): one from their name
	var look := c.look_seed if c.look_seed >= 0 else absi(hash(c.display_name)) % 64
	_model = CharModel.build(0, look, String(c.role), c.weapons[0].id() if not c.weapons.is_empty() else "heavy_pistol")
	_model.hold_state = true   # no state picking: this screen plays the idle itself
	if _model.gun:
		_model.gun.visible = false   # a body scan, not a loadout
	_model.rotation.y = deg_to_rad(YAW)
	_model.tree_entered.connect(func(): _pose.call_deferred())   # (the player seeks only once it's in the tree)
	_vp.add_child(_model)
	_dress()
	_cam = Camera3D.new()
	_cam.current = true
	_vp.add_child(_cam)
	_holo = TextureRect.new()
	_holo.name = "Holo"
	_holo.texture = _vp.get_texture()
	_holo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_holo.stretch_mode = TextureRect.STRETCH_SCALE
	_holo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var gm := ShaderMaterial.new()
	gm.shader = GLOW
	_holo.material = gm
	_holo.mouse_filter = Control.MOUSE_FILTER_STOP
	_holo.gui_input.connect(_holo_input)
	add_child(_holo)


## The idle (a calm weight shift, facing front: the injured idle turns away), from a time-based
## phase so a rebuilt screen carries on where it was; held still under reduced motion.
func _pose() -> void:
	if _model == null or _model.anim == null:
		return
	var clip := POSE_CLIP
	if not _model.anim.has_animation(clip):
		return
	_model.state = clip
	_model.anim.play(clip)
	var ln := _model.anim.current_animation_length
	_model.anim.seek(fmod(Time.get_ticks_msec() / 1000.0, ln) if _motion else ln * 0.3, true)
	if not _motion:
		_model.anim.pause()
	_model.skel.force_update_all_bone_transforms()   # posed before the first frame draws
	_layout()   # the cards by the posed body


## Every surface takes the hologram material: the body and eyes as region-painted copies (a region
## per location), hair with the head, gear with the bone it hangs from.
func _dress() -> void:
	var tints := PackedColorArray()
	var plated := PackedFloat32Array()
	for r in 10:
		var tp := _tint(r)
		tints.append(tp[0])
		plated.append(tp[1])
	var shell := Color(0, 0, 0, 0)
	if sel_loc == "external":
		shell = Color(Hud.GOLD, 0.85)
	elif chromed(c.implants, "external"):
		shell = Color(CHROME, 0.75)
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if _model.gun and _model.gun.is_ancestor_of(mi):
			continue
		var old := mi.material_override as ShaderMaterial
		var mode := int(old.get_shader_parameter("mode")) if old else 2
		var m := ShaderMaterial.new()
		m.shader = HOLO
		m.set_shader_parameter("meat", MEAT)
		m.set_shader_parameter("tints", tints)
		m.set_shader_parameter("plated", plated)
		m.set_shader_parameter("shell", shell)
		m.set_shader_parameter("motion", 1.0 if _motion else 0.0)
		m.set_shader_parameter("top", MODEL_H)
		if old:   # the outfit's colours, for their brightness
			for k in OUTFIT:
				m.set_shader_parameter(k, old.get_shader_parameter(k))
		m.set_shader_parameter("mode", mini(mode, 2))
		match mode:
			0:   # the body: regions from bone weights; the outfit and its texture shade the fill
				mi.mesh = _region_copy(mi, _model.skel, false)
			3:   # the eyes: left and right by side, bright
				mi.mesh = _region_copy(mi, _model.skel, true)
				m.set_shader_parameter("mode", 2)
				m.set_shader_parameter("albedo", Color(0.9, 0.9, 0.9))
			1:   # hair and brows
				m.set_shader_parameter("region_fixed", Reg.HEAD)
				m.set_shader_parameter("gain", 0.85)
			_:   # gear on a bone
				var p := mi.get_parent()
				m.set_shader_parameter("region_fixed", _bone_region(String((p as BoneAttachment3D).bone_name)) if p is BoneAttachment3D else Reg.TORSO)
				m.set_shader_parameter("gain", 0.7)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A region's tint [colour (a = how much), plated]: gold where the selected location is, violet
## chrome where a foundation (or anything, for the open places) is in, else meat (a = 0).
func _tint(r: int) -> Array:
	if r == Reg.TORSO:   # the trunk: the chest's internal chrome and borgware
		if sel_loc in ["internal", "borgware"]:
			return [Color(Hud.GOLD, 0.5), 0.0]
		if chromed(c.implants, "borgware"):
			return [Color(CHROME, 0.6), 1.0]
		return [Color(0, 0, 0, 0), 0.0]
	if not REGION_LOCS.has(r):
		return [Color(0, 0, 0, 0), 0.0]
	var loc: String = REGION_LOCS[r]
	var found := Cyber.foundation_at(c.implants, loc) != "" if loc != "chipware" else chromed(c.implants, loc)
	var eye := r == Reg.R_EYE or r == Reg.L_EYE
	if sel_loc == loc:
		return [Color(Hud.GOLD, 1.0 if eye else 0.8), 1.0 if found else 0.0]
	if found:
		return [Color(CHROME, 1.0 if eye else (0.6 if r == Reg.HEAD else 0.85)), 1.0]
	return [Color(0, 0, 0, 0), 0.0]


## A copy of a skinned mesh with each vertex's body region in COLOR.r: from its dominant bone (the
## body) or its side (the eyes). Cached per source mesh (CharModel shares one body per sex).
static func _region_copy(mi: MeshInstance3D, skel: Skeleton3D, eyes: bool) -> Mesh:
	var src := mi.mesh as ArrayMesh
	if src == null:
		return mi.mesh
	var key := src.get_instance_id()
	if _meshes.has(key):
		return _meshes[key]
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var per := bones.size() / maxi(1, verts.size())
		var src_cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var cols := PackedColorArray()
		cols.resize(verts.size())
		var by_bind := {}
		for v in verts.size():
			var reg := Reg.TORSO
			if eyes:
				reg = Reg.L_EYE if verts[v].x > 0.0 else Reg.R_EYE   # the character's left is +X
			elif per > 0:
				var best := 0
				for k in per:
					if weights[v * per + k] > weights[v * per + best]:
						best = k
				var bind := bones[v * per + best]
				if not by_bind.has(bind):
					by_bind[bind] = _bone_region(_bind_name(mi, skel, bind))
				reg = by_bind[bind]
			var was: Color = src_cols[v] if src_cols.size() == verts.size() else Color(0, verts[v].y / 2.0, 0)
			cols[v] = Color(reg / 16.0, was.g, was.r)   # region; rest height and cloth (CharModel's) kept
		arr[Mesh.ARRAY_COLOR] = cols
		for ch in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[ch] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	_meshes[key] = out
	return out


static func _bind_name(mi: MeshInstance3D, skel: Skeleton3D, bind: int) -> String:
	if mi.skin == null or bind >= mi.skin.get_bind_count():
		return ""
	var nm := String(mi.skin.get_bind_name(bind))
	if nm == "" and mi.skin.get_bind_bone(bind) >= 0:
		nm = skel.get_bone_name(mi.skin.get_bind_bone(bind))
	return nm


## The body region a bone belongs to (the shoulders go with the trunk).
static func _bone_region(b: String) -> int:
	if b in ["Head", "Jaw", "LeftEye", "RightEye"]:
		return Reg.HEAD
	if b == "Neck":
		return Reg.NECK
	var left := b.begins_with("Left") or b.ends_with("_l")
	var right := b.begins_with("Right") or b.ends_with("_r")
	if b.contains("Leg") or b.contains("Foot") or b.contains("Toes") or b.begins_with("ball"):
		return Reg.L_LEG if left else (Reg.R_LEG if right else Reg.TORSO)
	if (left or right) and not b.ends_with("Shoulder"):
		return Reg.L_ARM if left else Reg.R_ARM
	return Reg.TORSO


## Drag the figure to turn it; a click on it picks the nearest place.
func _holo_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press = ev.position
			_dragging = true
		else:
			_dragging = false
			if _press.x >= 0 and ev.position.distance_to(_press) < 4.0:
				var at: Vector2 = _holo.position + ev.position
				var best := ""
				var bd := 48.0
				for loc: String in anchors:
					var d := at.distance_to(anchors[loc])
					if d < bd:
						bd = d
						best = loc
				if best != "":
					loc_pressed.emit(best)
			_press = Vector2(-1, -1)
		_holo.accept_event()
	elif ev is InputEventMouseMotion and _dragging:
		_drag = clampf(_drag + ev.relative.x * 0.5, -150.0, 150.0)
		_holo.accept_event()


# --- Layout -----------------------------------------------------------------------------------

func _layout() -> void:
	if cards.is_empty():
		return
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	var fh := minf(h - 6.0, (w - 2.0 * _card_min() - 2.0 * GAP) * FIG.y / FIG.x)
	fh = maxf(fh, 120.0)
	var fw := fh * FIG.x / FIG.y
	var cw := clampf((w - fw) / 2.0 - GAP, _card_min(), CARD_MAX)
	_fig = Rect2(Vector2((w - fw) / 2.0, (h - fh) / 2.0), Vector2(fw, fh))
	var lx := maxf(0.0, _fig.position.x - GAP - cw)
	var rx := minf(w - cw, _fig.end.x + GAP)
	_frame_stage(Rect2(Vector2(lx + cw, 0), Vector2(rx - lx - cw, h)))
	_read_anchors()
	_column(LEFT_COL, lx, cw, h)
	_column(RIGHT_COL, rx, cw, h)
	_over.size = size
	queue_redraw()
	_over.queue_redraw()


## The stage fills the space between the card columns; the camera fits the model's height to
## the figure frame and centres it there.
func _frame_stage(r: Rect2) -> void:
	if _holo == null or r.size.x < 8 or r.size.y < 8:
		return
	_holo.position = r.position
	_holo.size = r.size
	var px := 1.0
	if is_inside_tree():
		px = clampf(get_screen_transform().get_scale().y, 0.5, 3.0)
	var vs := (r.size * px).round()
	var k := minf(1.0, MAX_PX / maxf(vs.x, vs.y))
	_vp.size = Vector2i(maxi(4, int(vs.x * k)), maxi(4, int(vs.y * k)))
	var ext := r.size.y / _fig.size.y * MODEL_H   # world height the stage shows at the model
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.fov = rad_to_deg(2.0 * atan(ext * 0.5 / CAM_DIST))
	_cam.h_offset = -(_fig.get_center().x - r.get_center().x) * ext / r.size.y
	_cam.position = Vector3(0, MODEL_H * 0.5 + (_fig.get_center().y - r.get_center().y) * ext / r.size.y, CAM_DIST)


func _card_min() -> float:
	return 136.0 if compact else CARD_MIN


## Stack a column's cards in their anchors' top-to-bottom order, each as near its anchor's height
## as it fits.
func _column(col: Array[String], x: float, cw: float, h: float) -> void:
	var locs := col.duplicate()
	locs.sort_custom(func(a: String, b: String) -> bool: return _anchor(a).y < _anchor(b).y)
	var ys: Array[float] = []
	var hs: Array[float] = []
	for loc in locs:
		var card: Control = cards[loc]
		card.size = Vector2(cw, 0)
		var ch := card.get_combined_minimum_size().y
		hs.append(ch)
		ys.append(_anchor(loc).y - ch / 2.0)
	var gap := 3.0 if compact else 5.0
	for i in ys.size():   # down: no overlaps
		ys[i] = maxf(ys[i], 0.0 if i == 0 else ys[i - 1] + hs[i - 1] + gap)
	for i in range(ys.size() - 1, -1, -1):   # up: inside the bottom edge
		ys[i] = minf(ys[i], h - hs[i] if i == ys.size() - 1 else ys[i + 1] - hs[i] - gap)
	for i in locs.size():
		var card: Control = cards[locs[i]]
		card.position = Vector2(x, maxf(0.0, ys[i]))
		card.size = Vector2(cw, hs[i])


## A location's anchor in this control: off the model's bones, else the fallback figure point.
func _anchor(loc: String) -> Vector2:
	if anchors.has(loc):
		return anchors[loc]
	return _fig.position + (ANCHORS[loc] as Vector2) * _fig.size / Vector2(200, 440)


## Project every location's bone point through the stage camera (worked out here, not by the
## camera, so it holds outside the tree too: tests).
func _read_anchors() -> void:
	if _model == null or _model.skel == null or _holo.size.x <= 0 or _holo.size.y <= 0:
		return
	var sk := _model.skel
	var to_stage := Transform3D.IDENTITY   # skeleton space → the stage's world
	var n: Node = sk
	while n != null and n != _vp:
		if n is Node3D:
			to_stage = (n as Node3D).transform * to_stage
		n = n.get_parent()
	var half := tan(deg_to_rad(_cam.fov) * 0.5)
	var eye := _cam.position + Vector3(_cam.h_offset, 0, 0)
	var px := _holo.size.y * 0.5 / half   # control pixels per unit of x/z or y/z
	for loc in BONES:
		var b: Array = BONES[loc]
		var ia := sk.find_bone(String(b[0]))
		if ia < 0:
			continue
		var pa := sk.get_bone_global_pose(ia)
		var p := pa.origin
		var basis := pa.basis.orthonormalized()
		if String(b[1]) != "":
			var ib := sk.find_bone(String(b[1]))
			if ib >= 0:
				p = p.lerp(sk.get_bone_global_pose(ib).origin, float(b[2]))
			basis = sk.get_bone_global_pose(sk.find_bone("Hips")).basis.orthonormalized()
		p += basis * (b[3] as Vector3)
		var d := to_stage * p - eye
		if d.z > -0.01:   # behind the camera
			continue
		anchors[loc] = _holo.position + _holo.size * 0.5 + Vector2(d.x, -d.y) / -d.z * px


# --- Drawing ----------------------------------------------------------------------------------

## The colour of a location's mark and line: gold selected, violet with anything installed, else
## a dim cyan.
func _loc_col(loc: String) -> Color:
	if loc == sel_loc:
		return Hud.GOLD
	return CHROME if chromed(c.implants, loc) else Color(Hud.CYAN, 0.45)


## Behind the figure: the scanner frame (corner brackets, a height scale, faint scanlines) and the
## platform it stands on.
func _draw() -> void:
	if c == null or _fig.size.x <= 0:
		return
	var fr := _fig.grow(10.0)
	var bc := Color(Hud.CYAN, 0.35)
	var bl := 18.0
	for corner in [[fr.position, Vector2(1, 1)], [Vector2(fr.end.x, fr.position.y), Vector2(-1, 1)], [fr.end, Vector2(-1, -1)], [Vector2(fr.position.x, fr.end.y), Vector2(1, -1)]]:
		var o: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_line(o, o + Vector2(bl * d.x, 0), bc, 1.5)
		draw_line(o, o + Vector2(0, bl * d.y), bc, 1.5)
	var y := fr.position.y + 2.0
	while y < fr.end.y:
		draw_line(Vector2(fr.position.x + 2, y), Vector2(fr.end.x - 2, y), Color(Hud.CYAN, 0.03), 1.0)
		y += 4.0
	# a height scale up the frame's inner edge: ticks every tenth, longer at the half
	for i in 11:
		var ty := lerpf(_fig.end.y, _fig.position.y, i / 10.0)
		var tl := 7.0 if i % 5 == 0 else 3.5
		draw_line(Vector2(fr.position.x + 3, ty), Vector2(fr.position.x + 3 + tl, ty), Color(Hud.CYAN, 0.28), 1.0)
	# the platform: two thin ellipses and a few ticks round them at the feet (a menu's scanner, not
	# a unit marker: faint)
	var foot := _fig.get_center() + Vector2(0, _fig.size.y * 0.5)
	var rx := _fig.size.x * 0.62
	var ry := rx * 0.16
	# the projector's light rising off it, fading out by the knees
	var beam := PackedVector2Array([foot + Vector2(-rx * 0.72, 0), foot + Vector2(rx * 0.72, 0), foot + Vector2(rx * 0.5, -_fig.size.y * 0.32), foot + Vector2(-rx * 0.5, -_fig.size.y * 0.32)])
	draw_polygon(beam, PackedColorArray([Color(Hud.CYAN, 0.07), Color(Hud.CYAN, 0.07), Color(Hud.CYAN, 0.0), Color(Hud.CYAN, 0.0)]))
	_ellipse(foot, rx, ry, Color(Hud.CYAN, 0.22), 1.2)
	_ellipse(foot, rx * 0.72, ry * 0.72, Color(Hud.CYAN, 0.12), 1.0)
	draw_colored_polygon(_ellipse_pts(foot, rx * 0.72, ry * 0.72), Color(Hud.CYAN, 0.035))
	for i in 24:
		var a := TAU * i / 24.0
		var p := foot + Vector2(cos(a) * rx, sin(a) * ry)
		var q := foot + Vector2(cos(a) * rx * 1.06, sin(a) * ry * 1.06)
		draw_line(p, q, Color(Hud.CYAN, 0.25 if i % 6 == 0 else 0.12), 1.0, true)


func _ellipse_pts(o: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		pts.append(o + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _ellipse(o: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := _ellipse_pts(o, rx, ry)
	pts.append(pts[0])
	draw_polyline(pts, col, w, true)


## Over the figure: each card's leader line and its mark on the body (a chromed place is a lit
## node, as the book's art studs chrome with lights; the chest's internal chrome a core).
func _draw_over(o: Control) -> void:
	if c == null:
		return
	for loc: String in cards:
		var card: Control = cards[loc]
		var a := _anchor(loc)
		var left := loc in LEFT_COL
		var r := card.get_rect()
		var edge := Vector2(r.end.x if left else r.position.x, r.position.y + minf(10.0, r.size.y / 2.0))
		var elbow := Vector2(edge.x + (12.0 if left else -12.0), edge.y)
		var on := loc == sel_loc
		var col := _loc_col(loc)
		var lc := col if on else Color(col, 0.6 if chromed(c.implants, loc) else 0.4)
		o.draw_polyline(PackedVector2Array([edge, elbow, a]), lc, 1.6 if on else 1.0, true)
	for loc: String in cards:
		var a := _anchor(loc)
		var on := loc == sel_loc
		var chrome := chromed(c.implants, loc)
		var col := _loc_col(loc)
		if loc == "internal":   # the core: a hexagon in the chest
			var hx := PackedVector2Array()
			for i in 7:
				hx.append(a + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * (7.0 if on else 6.0))
			if chrome or on:
				o.draw_polyline(hx, Color(col, 0.25), 5.0, true)
			o.draw_polyline(hx, col if chrome or on else Color(Hud.CYAN, 0.35), 1.3, true)
			continue
		if on or chrome:   # a lit node: halo, ring, core
			o.draw_circle(a, 7.0 if on else 5.5, Color(col, 0.16))
			o.draw_arc(a, 4.5 if on else 3.5, 0, TAU, 16, col, 1.2, true)
			o.draw_circle(a, 2.0, Color(1, 1, 1, 0.9).lerp(col, 0.35))
		else:
			o.draw_circle(a, 1.8, col)


## The leader lines' layer.
class Overlay extends Control:
	var body: ChromeBody

	func _draw() -> void:
		if body:
			body._draw_over(self)
