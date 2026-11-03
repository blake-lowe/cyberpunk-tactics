extends TestCase
## Every sound the code asks for exists (tools/gen_audio.py writes them) and loads.


func _names_in(dir: String, out: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			var src := FileAccess.get_file_as_string(dir.path_join(f))
			var re := RegEx.create_from_string("\"((?:sfx|amb|mus)_[a-z_]+)\"")
			for mt in re.search_all(src):
				out[mt.get_string(1)] = dir.path_join(f)
	for sub in d.get_directories():
		_names_in(dir.path_join(sub), out)


func test_every_sound_referenced_exists() -> void:
	var names := {}
	_names_in("res://src", names)
	assert_true(names.size() >= 20, "found sound references (%d)" % names.size())
	for n in names:
		if n.ends_with("_") or n.length() < 7:   # e.g. LOOKS key "amb_e"
			continue
		var path := "res://assets/audio/%s.wav" % n
		assert_true(ResourceLoader.exists(path), "%s (used in %s) exists" % [n, names[n]])


func test_music_and_ambience_load_and_loop() -> void:
	var ad := AudioDirector.new()
	for n in ["mus_explore", "mus_combat", "amb_city", "amb_undercity", "amb_warzone"]:
		var s := ad._looped(n)
		assert_true(s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops" % n)
		assert_true(s.get_length() > 10.0, "%s is a real loop" % n)
	ad.free()
