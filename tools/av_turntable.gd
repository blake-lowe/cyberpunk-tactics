extends SceneTree
## Review renders of the AV models outside a map: both liveries side by side on a grey pad, from
## the game's isometric angle, the side, the front, and in forward flight (nacelles tilted).
## timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility \
##   --resolution 1280x720 --path . -s tools/av_turntable.gd -- --out=/some/dir

var out := "."


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a1d24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8090a8")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun.light_energy = 1.1
	w.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("3a3e46")
	ground.material_override = gm
	w.add_child(ground)
	var avs: Array = []
	for i in 2:
		var av := AVModel.make(["trauma", "maxtac"][i])
		w.add_child(av)
		av.position = Vector3(-4.0 + i * 8.0, AVModel.HOVER, 0)
		av._set_tilt(0.0)
		avs.append(av)
	var cam := Camera3D.new()
	cam.fov = 32
	w.add_child(cam)
	var views := {
		"iso": [Vector3(0, 1.0, 0), 45.0, 50.0, 28.0],
		"side": [Vector3(0, 1.2, 0), 0.0, 12.0, 28.0],
		"front": [Vector3(0, 1.2, 0), 0.0, 14.0, 26.0],
		"rear": [Vector3(0, 1.2, 0), 200.0, 30.0, 26.0],
	}
	for name in views:
		var v: Array = views[name]
		var yaw := deg_to_rad(float(v[1]))
		var pitch := deg_to_rad(float(v[2]))
		var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * float(v[3])
		cam.position = (v[0] as Vector3) + off
		cam.look_at(v[0])
		for av in avs:   # the side view turns each craft broadside instead of lining them up
			av.rotation.y = -PI / 2.0 if name == "side" else 0.0
		for f in 6:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/av_%s.png" % [out, name])
	for av in avs:   # forward flight: nacelles tilted, higher
		av.rotation.y = 0.0
		av._set_tilt(AVModel.TILT_FLY)
		av.position.y = 3.0
	cam.position = Vector3(18, 11, 18)
	cam.look_at(Vector3(0, 2.0, 0))
	for f in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/av_flight.png" % out)
	quit()
