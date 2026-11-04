extends SceneTree
## Catalogue renders for content review: every faction's look (three people each, from their
## roster: a Mook, a Lieutenant and a Mini Boss with the faction's kit), one PNG per faction.
## tools/catalogue.py composes them (and greybox shots of every site and district profile) into
## captioned contact sheets.
## timeout 300 xvfb-run -a -s "-screen 0 960x540x24" godot --rendering-method gl_compatibility \
##   --resolution 960x540 --path . -s tools/catalogue.gd -- --out=/some/dir

const TIERS := ["mook", "lieutenant", "mini_boss"]
const CREW_ROLES := ["solo", "netrunner", "tech"]
const CASUAL_ROLES := ["media", "fixer", "exec"]

var out := "."


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_run.call_deferred()


func _weapon(fid: String, tier: String) -> String:
	var kits: Array = World.faction(fid).get("roster", {}).get("kits", {}).get(tier, [])
	if kits.is_empty():
		kits = RulesDB.load_json("npcs.json")["tiers"][tier]["weapons"]
	return String(kits[0][0])


func _run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("15181e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9aa4b4")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-25), 0)
	key.light_energy = 1.1
	key.light_color = Color("fff2e4")
	key.light_cull_mask = 0xFFFFF
	w.add_child(key)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("2a2e36")
	floor_m.material_override = fm
	w.add_child(floor_m)
	var cam := Camera3D.new()
	cam.fov = 26
	w.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.3, 4.6), Vector3(0, 0.88, 0))
	var ids: Array = World.factions().keys()
	for fid in ids:
		var kind := World.kind(fid)
		var models: Array = []
		for i in 3:
			var role: String
			var weapon := "heavy_pistol"
			var team := 1
			if kind == "crew":
				role = CREW_ROLES[i]
				team = 0
				weapon = ["assault_rifle", "heavy_pistol", "shotgun"][i]
			elif kind in ["civilian", "captive"]:
				role = CASUAL_ROLES[i]
				team = 0
			else:
				role = TIERS[i]
				weapon = _weapon(fid, role)
			var n := CharModel.build(team, 100 + i * 7, role, weapon, "" if kind == "crew" else fid)
			w.add_child(n)
			n.position = Vector3(-1.15 + i * 1.15, 0, 0)
			n.rotation.y = deg_to_rad(-12 + i * 12)
			if kind in ["civilian", "captive"] and n.gun:
				n.gun.visible = false
			n.pose_still("idle_shift" if team == 0 else "rifle_idle", 0.4)
			models.append(n)
		for f in 8:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/faction_%s.png" % [out, fid])
		for n in models:
			n.queue_free()
		await process_frame
	quit()
