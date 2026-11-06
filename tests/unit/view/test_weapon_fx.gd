extends TestCase
## Every weapon's attack resolves to a look and a sound (data/gen/weapon_fx.json via WeaponFx),
## every sound it names exists, and nothing that isn't a firearm bullet fires a gunshot.


func _weapon_ids() -> Array:
	var ids: Array = (RulesDB.load_json("weapons.json")["weapons"] as Dictionary).keys()
	ids.append_array(["brawling", "martial_arts"])   # Weapon.brawling / Weapon.martial_arts
	return ids


func _sound_exists(n: String) -> bool:
	return ResourceLoader.exists("res://assets/audio/%s.wav" % n)


func test_every_weapon_resolves_to_a_known_kind_with_sounds() -> void:
	var kinds: Dictionary = RulesDB.gen("weapon_fx.json")["kinds"]
	for id in _weapon_ids():
		var k := WeaponFx.kind_of(id)
		assert_true(kinds.has(k), "%s → kind %s exists" % [id, k])
		assert_true((RulesDB.gen("weapon_fx.json")["weapons"] as Dictionary).has(id), "%s is listed explicitly in weapon_fx.json" % id)
		var snd := WeaponFx.shot_sound(id)
		assert_true(snd != "" and _sound_exists(snd), "%s fires with %s (exists)" % [id, snd])
		if WeaponFx.is_swing(id):
			assert_true(_sound_exists(WeaponFx.hit_sound(id)), "%s hits with %s" % [id, WeaponFx.hit_sound(id)])


func test_every_sound_in_the_table_exists() -> void:
	var names := WeaponFx.all_sounds()
	assert_true(names.size() >= 20, "the table names its sounds (%d)" % names.size())
	for n in names:
		assert_true(_sound_exists(n), "%s exists" % n)


func test_non_ballistic_weapons_never_use_the_gunshot() -> void:
	for id in _weapon_ids():
		var vis := WeaponFx.visual(id)
		var snd := WeaponFx.shot_sound(id)
		if vis != "gun":
			assert_false(WeaponFx.GUNSHOTS.has(snd), "%s (%s) does not fire a gunshot (%s)" % [id, vis, snd])
			assert_false(WeaponFx.ejects_brass(id), "%s ejects no brass" % id)
	for id in ["air_pistol", "dartgun", "microwaver", "shrieker", "stun_gun", "stun_baton", "flamethrower", "rhinemetall_emg86",
			"battleglove", "kendachi_mono_three", "cowboy_u56", "grenade_launcher", "rocket_launcher", "bow", "crossbow",
			"light_melee", "medium_melee", "heavy_melee", "very_heavy_melee", "brawling", "martial_arts", "thrown_melee", "thrown_grenade"]:
		assert_true(WeaponFx.visual(id) != "gun", "%s is not on the bullet pipeline" % id)
		assert_false(WeaponFx.GUNSHOTS.has(WeaponFx.shot_sound(id)), "%s: no gunshot" % id)


func test_the_book_shapes() -> void:
	assert_eq(WeaponFx.visual("flamethrower"), "flame")
	assert_eq(WeaponFx.visual("microwaver"), "microwave")
	assert_eq(WeaponFx.visual("shrieker"), "sonic")
	assert_eq(WeaponFx.visual("rhinemetall_emg86"), "rail")
	assert_true(WeaponFx.charge_secs("rhinemetall_emg86") > 0.2, "the railgun winds up")
	assert_eq(WeaponFx.visual("stun_gun"), "arc")
	assert_eq(WeaponFx.visual("bow"), "arrow")
	assert_eq(WeaponFx.visual("cowboy_u56"), "lob")
	assert_true(WeaponFx.is_swing("stun_baton"), "a stun baton is swung, not fired")
	assert_true(WeaponFx.is_swing("kendachi_mono_three"))
	assert_true(WeaponFx.is_swing("battleglove"))
	assert_eq(WeaponFx.hit_sound("light_melee"), "sfx_hit_blade")
	assert_eq(WeaponFx.hit_sound("medium_melee"), "sfx_hit_blunt")
	assert_eq(WeaponFx.hit_sound("brawling"), "sfx_hit_punch")
	assert_eq(WeaponFx.hit_sound("stun_baton"), "sfx_hit_stun")


func test_exotic_guns_keep_bullets_with_their_own_report() -> void:
	for id in ["malorian_arms_3516", "tsunami_helix", "hurricane_assault_weapon"]:
		assert_true(WeaponFx.is_gun(id), "%s fires bullets" % id)
		assert_true(WeaponFx.ejects_brass(id), "%s ejects brass" % id)
		assert_false(WeaponFx.GUNSHOTS.has(WeaponFx.shot_sound(id)), "%s has its own report (%s)" % [id, WeaponFx.shot_sound(id)])
		assert_true(Fx.FLASH.has(String(WeaponFx.spec(id).get("flash", ""))), "%s borrows a muzzle flash class" % id)


func test_plain_and_unknown_guns_fall_back_to_the_gun_pipeline() -> void:
	assert_eq(WeaponFx.kind_of("no_such_gun_9000"), "gun")
	assert_eq(WeaponFx.shot_sound("no_such_gun_9000"), "sfx_shot_rifle")
	assert_eq(WeaponFx.shot_sound("heavy_pistol"), "sfx_shot_pistol")
	assert_eq(WeaponFx.shot_sound("shotgun"), "sfx_shot_shotgun")
	assert_eq(WeaponFx.shot_sound("smg"), "sfx_shot_smg")
	assert_eq(WeaponFx.shot_sound("assault_rifle"), "sfx_shot_rifle")
	assert_true(WeaponFx.ejects_brass("medium_pistol"))
