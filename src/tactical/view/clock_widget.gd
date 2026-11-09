class_name ClockWidget
extends Control
## One Solo Play Clock on the round tab (Clocks, SPM p.25-26) as a row of d6s: pixel-crisp faces in
## the HUD palette, a dim socket where each lost die was. Presentation only: the rules are the
## Clock's, and this plays what an encounter's `clock` events say happened.
## - A roll: every die tumbles (bouncing, spinning, faces flicking) with a rattle; the dropping ones
##   flash red, crack and shatter in a burst of pixel shards; the rest slide together and settle.
## - Pressure: the row pulses faster and harder as the pool shrinks, and the last die beats like a
##   heart (lub-dub).
## - Empty: the whole row blows apart (the view adds the flash, klaxon and banner).
## - A die won back (Reclaiming Their Time) drops into the next socket with a cyan glint.
## `reduced` (GameSettings reduced_motion): no tumble, shake, shards or heartbeat; the outcome
## shows at once with a short colour change.
## Randomness here is cosmetic (its own unseeded RandomNumberGenerator): it never touches rules.

signal hovered(on: bool)

const DIE := 22                 ## a die's side (logical px: the HUD's 720-line layout)
const GAP := 6
const LABEL_H := 16
const TUMBLE := 0.62            ## seconds of tumbling
const STAGGER := 0.045          ## each die lands a beat after the one before
const DOOM := 0.42              ## the doomed dice flash red
const CRACK := 0.16             ## ... crack ...
const SLIDE := 0.24             ## ... and the rest slide together
const DROP := 0.42              ## a die won back falling in
const BOOM := 0.9               ## the row exploding on empty
const GRAVITY := 900.0
const PIPS := {1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
	5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]]}
const INK := Color("0b1016")
const PIP := Color("e8eef2")
const RED := Color("ff3b4f")
const CYAN := Color("05d9e8")
const WHITE := Color(1, 1, 1)

var clock_id := ""
var label := ""
var col := CYAN                 ## the clock's colour (cyan detection, gold time limit)
var sockets := 0                ## dice the clock started with
var dice: Array = []            ## one per die still in the pool: {face, x (slot x, px), y, rot, sc, state, t, flash, crack}
var shards: Array = []          ## {p, v, life, max, col, s}
var glints: Array = []          ## {p, v, life, max}
var reduced := false
var gone := false               ## emptied or stopped: the row fades out
var _t := 0.0                   ## seconds since the widget started (pulses)
var _busy_until := 0.0          ## an animation is playing until then (sync waits)
var _boom_t := -1.0
var _boom_pending := false      ## this roll empties the pool: the row bursts as the last dice shatter
var _plus := {}                 ## a die won back: "+1" rising from its socket {x, life}
var _fade := 1.0
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


static func make(p_id: String, p_label: String, p_col: Color, n_size: int, n_pool: int, faces: Array = []) -> ClockWidget:
	var w := ClockWidget.new()
	w.clock_id = p_id
	w.label = p_label
	w.col = p_col
	w.sockets = n_size
	for i in n_pool:
		w.dice.append(w._die(int(faces[i]) if i < faces.size() else 6 - i % 3, i))   # a fresh pool shows high faces
	w.custom_minimum_size = Vector2(maxf(150.0, n_size * (DIE + GAP) - GAP + 6), LABEL_H + DIE + 10)
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	w.mouse_default_cursor_shape = Control.CURSOR_HELP
	w.z_index = 5   # shards and the burst fly over the round tab's other lines
	return w


func _ready() -> void:
	_rng.randomize()
	mouse_entered.connect(func(): hovered.emit(true))
	mouse_exited.connect(func(): hovered.emit(false))


func _die(face: int, slot: int) -> Dictionary:
	return {"face": face, "x": _slot_x(slot), "to_x": _slot_x(slot), "y": 0.0, "rot": 0.0, "sc": Vector2.ONE, "state": "idle", "t": 0.0,
		"flash": 0.0, "crack": 0.0, "final": face, "doom": false, "spin": 0.0, "delay": 0.0, "glint": -1.0}


func _slot_x(i: int) -> float:
	return 2.0 + i * (DIE + GAP)


func pool() -> int:
	return dice.size()


func busy() -> bool:
	return _t < _busy_until or _boom_t >= 0.0


## The danger 0 (full) .. 1 (one die left).
func danger() -> float:
	if sockets <= 1:
		return 1.0 if pool() <= 1 else 0.0
	return clampf(1.0 - float(pool() - 1) / float(sockets - 1), 0.0, 1.0)


# --- What happened (the view calls these from the encounter's events) ----------------------

## A trigger rolled the pool: `faces` (one per die, in order), `removed` (indices of the dropped
## ones), `emptied`. Returns how long it takes to play (s), so the view can wait on it.
func play_roll(faces: Array, removed: Array, emptied: bool) -> float:
	while dice.size() < faces.size():   # out of step (a missed event): catch up silently
		dice.append(_die(1, dice.size()))
	while dice.size() > faces.size():
		dice.pop_back()
	for i in dice.size():
		var d: Dictionary = dice[i]
		d.final = int(faces[i])
		d.doom = i in removed
		d.state = "tumble"
		d.t = 0.0
		d.delay = i * STAGGER
		d.spin = _rng.randf_range(-1.0, 1.0) * TAU * 1.6
		d.flash = 0.0
		d.crack = 0.0
	_sfx("sfx_dice_rattle", -4.0)
	var dur := (0.12 if reduced else TUMBLE + STAGGER * dice.size()) + (0.0 if removed.is_empty() else (0.3 if reduced else DOOM + CRACK + SLIDE))
	if emptied:
		dur += 0.15 if reduced else BOOM
		_boom_pending = true
	_busy_until = _t + dur
	if reduced:
		for d in dice:
			d.face = int(d.final)
			d.state = "doom" if d.doom else "idle"
			d.t = 0.0
	return dur


## A die won back (Reclaiming Their Time, SPM p.26): it drops into the next socket.
func play_add(sound := true) -> float:
	if dice.size() >= sockets:
		return 0.0
	var d := _die(_rng.randi_range(2, 6), dice.size())
	d.state = "drop"
	d.y = -34.0
	d.t = 0.0
	d.glint = 0.0
	dice.append(d)
	_busy_until = _t + (0.2 if reduced else DROP + 0.35)
	if reduced:
		d.state = "idle"
		d.y = 0.0
	if sound:
		_sfx("sfx_die_add", -6.0)
	return 0.2 if reduced else DROP + 0.25


## The clock is moot (the alarm went up some other way) or done: the row dims and fades.
func play_stop() -> float:
	gone = true
	return 0.4


## Match the clock without animating (a load, or an event the view never played).
func sync(pool_n: int, n_size: int, faces: Array = []) -> void:
	if busy():
		return
	sockets = n_size
	while dice.size() > pool_n:
		dice.pop_back()
	while dice.size() < pool_n:
		dice.append(_die(int(faces[dice.size()]) if dice.size() < faces.size() else 6, dice.size()))
	for i in dice.size():
		dice[i].x = _slot_x(i)
		dice[i].to_x = _slot_x(i)


# --- Animation --------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_t += dt
	_shake = maxf(0.0, _shake - dt * 3.0)
	if gone and _boom_t < 0.0:
		_fade = maxf(0.0, _fade - dt * 2.2)
	var cracked := false
	for d in dice:
		match String(d.state):
			"tumble":
				d.t += dt
				var lt: float = d.t - d.delay
				if lt < 0.0:
					continue
				var k := clampf(lt / TUMBLE, 0.0, 1.0)
				var bounce := absf(sin(k * PI * 3.2)) * (1.0 - k) * (1.0 - k)
				d.y = -bounce * 13.0
				d.rot = d.spin * (1.0 - k) * (1.0 - k)
				if int(d.t * 1000.0) / 55 != int((d.t - dt) * 1000.0) / 55 and k < 0.9:
					d.face = _rng.randi_range(1, 6)   # the faces flick as it turns
				if k >= 1.0:
					d.face = int(d.final)
					d.y = 0.0
					d.rot = 0.0
					d.sc = Vector2(1.22, 0.8)   # it lands: a squash
					d.state = "doom" if d.doom else "settle"
					d.t = 0.0
			"settle":
				d.t += dt
				d.sc = d.sc.lerp(Vector2.ONE, minf(1.0, dt * 14.0))
				if d.t > 0.25:
					d.sc = Vector2.ONE
					d.state = "idle"
			"doom":
				d.t += dt
				d.sc = d.sc.lerp(Vector2.ONE, minf(1.0, dt * 14.0))
				var wait := 0.0 if reduced else STAGGER * maxf(0.0, dice.size() - 1 - dice.find(d)) * 0.5
				d.flash = 1.0 if fmod(maxf(0.0, d.t - wait), 0.14) < 0.08 else 0.25
				if d.t >= DOOM * (0.5 if reduced else 1.0):
					d.state = "crack"
					d.t = 0.0
					if not reduced:
						cracked = true
			"crack":
				d.t += dt
				d.crack = clampf(d.t / CRACK, 0.0, 1.0)
				d.flash = 1.0
				if d.t >= CRACK or reduced:
					d.state = "dead"
					if not reduced:
						_burst(Vector2(d.x + DIE / 2.0, LABEL_H + 4 + DIE / 2.0 + d.y), 14, RED)
						_shake = maxf(_shake, 0.6)
			"drop":
				d.t += dt
				var k2 := clampf(d.t / DROP, 0.0, 1.0)
				# falls in and bounces twice
				var fall := 1.0 - k2
				d.y = -34.0 * fall * fall * absf(cos(k2 * PI * 2.5)) if k2 < 1.0 else 0.0
				if k2 >= 1.0:
					d.y = 0.0
					d.sc = Vector2(1.25, 0.8)
					d.state = "settle"
					d.t = 0.0
					d["cy"] = 1.0
					_sparkle(Vector2(d.x + DIE / 2.0, LABEL_H + 4 + DIE / 2.0))
					_plus = {"x": float(d.x) + DIE / 2.0, "life": 0.0}
		if float(d.get("cy", 0.0)) > 0.0:
			d.cy = maxf(0.0, float(d.cy) - dt * 2.2)
		if float(d.glint) >= 0.0:
			d.glint += dt
			if d.glint > 0.75:
				d.glint = -1.0
	if cracked:
		_sfx("sfx_die_break", -5.0)
	var before := dice.size()
	dice = dice.filter(func(d): return String(d.state) != "dead")
	if _boom_pending and dice.is_empty():   # the last die shattered: the whole row goes with it
		_boom_pending = false
		explode()
	if dice.size() != before:   # the rest slide together
		for i in dice.size():
			dice[i].to_x = _slot_x(i)
	for d in dice:
		d.x = lerpf(float(d.x), float(d.to_x), minf(1.0, dt * (40.0 if reduced else 12.0)))
	if _boom_t >= 0.0:
		_boom_t += dt
		if _boom_t > BOOM:
			_boom_t = -1.0
			gone = true
	for s in shards:
		s.life += dt
		s.v.y += GRAVITY * dt * float(s.get("g", 1.0))
		s.v *= 1.0 - dt * 1.2
		s.p += s.v * dt
	shards = shards.filter(func(s): return s.life < s.max)
	for g in glints:
		g.life += dt
		g.p += g.v * dt
		g.v *= 1.0 - dt * 4.0
	glints = glints.filter(func(g): return g.life < g.max)
	if not _plus.is_empty():
		_plus.life += dt
		if _plus.life > 0.9:
			_plus = {}
	queue_redraw()


## Seconds from play_roll until an emptying roll bursts (the view times its flash and klaxon to it).
func boom_delay() -> float:
	if reduced:
		return 0.12 + DOOM * 0.5
	return TUMBLE + STAGGER * maxf(0.0, dice.size() - 1) + DOOM + CRACK


## The pool ran out: the row blows apart (shards from every socket, a white-hot flash).
func explode() -> void:
	_boom_t = 0.0
	if reduced:
		_boom_t = BOOM - 0.15
		return
	for i in sockets:
		_burst(Vector2(_slot_x(i) + DIE / 2.0, LABEL_H + 4 + DIE / 2.0), 10, RED if i % 2 == 0 else col, 1.6)
	_burst(Vector2(size.x / 2.0, LABEL_H + 4 + DIE / 2.0), 28, WHITE, 2.2)
	_shake = 1.5


func _burst(at: Vector2, n: int, c: Color, power := 1.0) -> void:
	for i in n:
		var a := _rng.randf_range(-PI, 0.0) if _rng.randf() < 0.8 else _rng.randf_range(0.0, PI)
		var sp := _rng.randf_range(90.0, 260.0) * power
		var tone := c if _rng.randf() < 0.6 else (INK.lightened(0.25) if _rng.randf() < 0.5 else PIP)
		shards.append({"p": at + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6)), "v": Vector2(cos(a), sin(a)) * sp,
			"life": 0.0, "max": _rng.randf_range(0.35, 0.8) * (1.0 + 0.3 * (power - 1.0)), "col": tone, "s": float(_rng.randi_range(2, 4)), "g": 1.0})


func _sparkle(at: Vector2) -> void:
	for i in 10:
		var a := TAU * i / 10.0 + _rng.randf_range(-0.2, 0.2)
		glints.append({"p": at, "v": Vector2(cos(a), sin(a)) * _rng.randf_range(60.0, 120.0), "life": 0.0, "max": _rng.randf_range(0.35, 0.6)})


func _sfx(name: String, vol: float) -> void:
	if AudioDirector.I and is_instance_valid(AudioDirector.I):
		AudioDirector.I.ui(name, vol)


# --- Drawing ----------------------------------------------------------------------------------

func _draw() -> void:
	var dz := danger()
	var a := _fade
	if a <= 0.01 and shards.is_empty():
		return
	var shake := Vector2.ZERO
	if _shake > 0.0 and not reduced:
		shake = Vector2(roundf(_rng.randf_range(-2, 2) * _shake), roundf(_rng.randf_range(-1, 1) * _shake))
	# The pulse: a frame around the dice that breathes faster and brighter as the pool shrinks.
	var hz := 0.55 + 1.9 * dz
	var amp := 0.12 + 0.55 * dz
	var pulse := 0.5 + 0.5 * sin(_t * TAU * hz)
	var tone := _tone(dz)
	if gone:
		tone = Color(0.55, 0.6, 0.66)
	draw_string(Hud.F_DISPLAY, Vector2(0, LABEL_H - 3) + shake, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(tone, a))
	var tag := "%d/%d" % [pool(), sockets]
	var tw := Hud.F_TERM.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(Hud.F_TERM, Vector2(size.x - tw - 2, LABEL_H - 3) + shake, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(tone, a * 0.85))
	var row := Rect2(Vector2(-2, LABEL_H + 1), Vector2(sockets * (DIE + GAP) - GAP + 8, DIE + 6))
	if not gone:
		draw_rect(row, Color(tone, (0.05 + amp * 0.35 * pulse) * a))
		_frame(Rect2(row.position + shake, row.size), Color(tone, (0.25 + amp * pulse) * a), 2)
	var y0 := LABEL_H + 4
	for i in sockets:   # an empty socket for each die gone: four dim corners
		if i >= dice.size():
			_corners(Rect2(Vector2(_slot_x(i), y0) + shake, Vector2(DIE, DIE)), Color(tone, 0.32 * a))
	var beat := 0.0
	if pool() == 1 and not gone and not reduced and not busy():
		var ph := fmod(_t, 0.95)   # lub-dub
		beat = 0.2 * exp(-pow(ph / 0.07, 2.0)) + 0.12 * exp(-pow((ph - 0.24) / 0.07, 2.0))
	for d in dice:
		var lt: float = float(d.t) - float(d.delay) if String(d.state) == "tumble" else 1.0
		var c := Vector2(roundf(float(d.x)) + DIE / 2.0, roundf(y0 + float(d.y)) + DIE / 2.0) + shake
		var sc: Vector2 = d.sc * (1.0 + beat)
		draw_set_transform(c, float(d.rot) if lt >= 0.0 else 0.0, sc)
		_face(int(d.face), float(d.flash), float(d.crack), tone if not gone else Color(0.5, 0.55, 0.6), a, float(d.glint), float(d.get("cy", 0.0)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for s in shards:
		var k: float = 1.0 - float(s.life) / float(s.max)
		var sz := float(s.s)
		draw_rect(Rect2((s.p as Vector2).round() - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(s.col, k))
	for g in glints:
		var k2: float = 1.0 - float(g.life) / float(g.max)
		var gs := 3.0 if k2 > 0.5 else 2.0
		draw_rect(Rect2((g.p as Vector2).round() - Vector2(1, 1), Vector2(gs, gs)), Color(CYAN.lightened(0.4), k2))
	if not _plus.is_empty():   # "+1" floats up out of the socket the die fell into
		var pk := float(_plus.life) / 0.9
		var py := LABEL_H + 2 - roundf(14.0 * pk)
		var pa := clampf(2.0 - pk * 2.0, 0.0, 1.0)
		draw_string(Hud.F_DISPLAY, Vector2(roundf(float(_plus.x) - 9), py), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(CYAN.lightened(0.35), pa))
	if _boom_t >= 0.0 and not reduced:   # the burst: the dice flash white-hot, then shock rings spread from the row
		var k3 := clampf(1.0 - _boom_t / 0.12, 0.0, 1.0)
		if k3 > 0.0:
			for i in sockets:
				draw_rect(Rect2(Vector2(_slot_x(i), y0) - Vector2(2, 2), Vector2(DIE + 4, DIE + 4)), Color(1, 0.95, 0.9, k3))
		for ring in 2:
			var rt := clampf((_boom_t - ring * 0.12) / 0.55, 0.0, 1.0)
			if rt > 0.0 and rt < 1.0:
				var grow := Vector2(40, 18) * rt * (1.0 + ring)
				_frame(Rect2((row.position - grow).round(), (row.size + grow * 2.0).round()), Color(RED.lightened(0.3 * (1 - ring)), (1.0 - rt) * 0.9), 2)


## The row's colour as the pool shrinks, in steps (pixel-art reads, and a blend of cyan into amber
## passes through green, the health colour): its own colour for the first third, amber, then red
## for the last dice.
func _tone(dz: float) -> Color:
	if dz < 0.34:
		return col
	if dz < 0.75:
		return Color("ffb020")
	return RED


## A d6 centred on the transform's origin: an ink body with chamfered corners, a 2 px rim, square
## pips (the 1 in red, as on a casino die). `flash` 0..1 turns it red-hot, `crack` draws the split.
func _face(face: int, flash: float, crack: float, rim: Color, a: float, glint: float, cy := 0.0) -> void:
	var h := DIE / 2.0
	var body := PackedVector2Array([Vector2(-h + 3, -h), Vector2(h - 3, -h), Vector2(h, -h + 3), Vector2(h, h - 3),
		Vector2(h - 3, h), Vector2(-h + 3, h), Vector2(-h, h - 3), Vector2(-h, -h + 3)])
	var fill := INK.lerp(Color("5a0812"), flash).lerp(Color("0b6f78"), cy)   # red-hot when doomed, cyan when won back
	rim = rim.lerp(CYAN.lightened(0.5), cy)
	draw_colored_polygon(body, Color(fill, a))
	draw_rect(Rect2(Vector2(-h + 3, -h + 2), Vector2(DIE - 6, 2)), Color(rim.lightened(0.2), 0.22 * a))   # a lit top edge
	var rc := rim.lerp(RED.lightened(0.3), flash)
	var loop := body.duplicate()
	loop.append(body[0])
	draw_polyline(loop, Color(rc, a), 2.0)
	var pc := PIP.lerp(WHITE, flash)
	if face == 1:   # the 1: one big red pip, as on a casino die
		draw_rect(Rect2(Vector2(-3, -3), Vector2(6, 6)), Color(RED if flash < 0.5 else pc, a))
	else:
		for p in PIPS.get(face, []):
			var pp := Vector2(-6 + int(p[0]) * 6, -6 + int(p[1]) * 6) - Vector2(2, 2)
			draw_rect(Rect2(pp, Vector2(4, 4)), Color(pc, a))
	if crack > 0.0:   # a jagged split, top to bottom, widening
		var pts := PackedVector2Array([Vector2(-1, -h), Vector2(2, -h * 0.45), Vector2(-2, -h * 0.05), Vector2(3, h * 0.35), Vector2(0, h)])
		var n := int(ceil(crack * (pts.size() - 1)))
		for i in n:
			draw_line(pts[i], pts[i + 1], Color(WHITE, a), 2.0)
		if crack > 0.6:
			draw_line(Vector2(-2, -h * 0.05), Vector2(-h, h * 0.2), Color(WHITE, a * 0.8), 1.0)
			draw_line(Vector2(3, h * 0.35), Vector2(h, h * 0.55), Color(WHITE, a * 0.8), 1.0)
	if glint >= 0.0 and glint < 0.55:   # a die won back: a bright band sweeps across it
		var gx := lerpf(-h - 8, h + 8, glint / 0.55)
		var band := PackedVector2Array([Vector2(gx - 3, -h), Vector2(gx + 3, -h), Vector2(gx - 5, h), Vector2(gx - 11, h)])
		draw_colored_polygon(band, Color(CYAN.lightened(0.6), 0.85 * a))
		draw_polyline(loop, Color(CYAN, a * (1.0 - glint / 0.55)), 2.0)


func _frame(r: Rect2, c: Color, w: int) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), c)
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), c)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), c)
	draw_rect(Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y)), c)


func _corners(r: Rect2, c: Color) -> void:
	var l := 5.0
	for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if p.x == r.position.x else -1.0
		var sy := 1.0 if p.y == r.position.y else -1.0
		draw_rect(Rect2(Vector2(p.x if sx > 0 else p.x - 2, p.y if sy > 0 else p.y - l), Vector2(2, l)), c)
		draw_rect(Rect2(Vector2(p.x if sx > 0 else p.x - l, p.y if sy > 0 else p.y - 2), Vector2(l, 2)), c)
