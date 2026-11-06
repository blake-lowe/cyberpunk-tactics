extends TestCase
## Item name typography (QualityText, data/gen/item_type.json): Poor rust + alternating case,
## Standard untouched, Excellent sheen, exotic display faces.


func test_alternating_case_is_deterministic_and_keeps_the_letters() -> void:
	assert_eq(QualityText.alt_case("alternating case"), "aLtErNaTiNg CaSe", "letters only, counted across the space")
	assert_eq(QualityText.alt_case("POOR HEAVY PISTOL"), "pOoR hEaVy PiStOl")
	for s in ["Poor Heavy Pistol", "POOR ASSAULT RIFLE 25/25", "Poor Very Heavy Pistol", "Poor Light Melee Weapon"]:
		var a := QualityText.alt_case(s)
		assert_eq(a, QualityText.alt_case(s), "same input, same output")
		assert_eq(a.to_lower(), s.to_lower(), "same letters, digits and spacing: " + a)
		assert_eq(a.length(), s.length())
	var st := QualityText.style("weapon/heavy_pistol@poor", "POOR HEAVY PISTOL")
	assert_eq(st.text, "pOoR hEaVy PiStOl")


func test_poor_colours_are_rust_and_vary_per_item() -> void:
	var seen := {}
	for id in RulesDB.load_json("weapons.json").weapons:
		if not Weapon.can_have_quality(String(id), "poor"):
			continue
		var c: Color = QualityText.style(Items.weapon_key(String(id), "poor"), "x").colour
		assert_between(c.h, 0.03, 0.09, "%s hue is orange-brown" % id)
		assert_between(c.s, 0.6, 0.85, "%s saturation" % id)
		assert_between(c.v, 0.72, 0.92, "%s bright enough on the dark UI" % id)
		assert_true(c.r > c.g and c.g > c.b, "%s reads as rust (r > g > b)" % id)
		assert_eq(c, QualityText.rust(String(id)), "stable per item")
		seen[c.to_html()] = true
	assert_true(seen.size() > 5, "the browns vary between items")


func test_standard_is_unchanged() -> void:
	for key in ["weapon/heavy_pistol", "heavy_pistol", "armor/kevlar", "cyberware/wolvers", "", "gear/medscanner"]:
		var st := QualityText.style(key, "Heavy Pistol 8/8")
		assert_eq(st.text, "Heavy Pistol 8/8", key)
		assert_false(st.colour is Color, key)
		assert_true(st.font == null, key)
		assert_false(st.sheen, key)
		assert_eq(st.scale, 1.0, key)
	var l := Label.new()
	l.text = "HEAVY PISTOL"
	l.add_theme_color_override("font_color", Color.CYAN)
	QualityText.apply(l, "weapon/heavy_pistol")
	assert_eq(l.text, "HEAVY PISTOL")
	assert_eq(l.get_theme_color("font_color"), Color.CYAN)
	assert_true(l.material == null)
	l.free()


func test_excellent_has_a_sheen_and_keeps_its_text() -> void:
	var st := QualityText.style("weapon/assault_rifle@excellent", "EXCELLENT ASSAULT RIFLE")
	assert_true(st.sheen)
	assert_eq(st.text, "EXCELLENT ASSAULT RIFLE")
	Hud._fonts()
	var l := QualityText.apply(UiKit.label("Excellent Assault Rifle", 15, Hud.TEXT), "weapon/assault_rifle@excellent")
	assert_true(l.material is ShaderMaterial, "the sweep shader")
	l.free()
	# the sweep passes once per period and rests in between
	assert_true(QualityText.sheen_amount(50.0, 100.0, 0.45) > 0.9, "mid-sweep, mid-name")
	assert_eq(QualityText.sheen_amount(50.0, 100.0, 2.5), 0.0, "resting")
	assert_true(QualityText.style("cyberware/vampyres", "Vampyres").sheen, "Excellent Quality chrome (cyberware.json)")
	assert_eq(QualityText.quality_of("gear/cyberdeck_poor"), "poor")


func test_every_exotic_weapon_has_a_display_font_that_loads() -> void:
	var fonts := {}
	for id in RulesDB.load_json("weapons.json").weapons:
		if not QualityText.is_exotic(String(id)):
			assert_eq(QualityText.font_key(String(id)), "", "%s isn't exotic" % id)
			continue
		var fk := QualityText.font_key(String(id))
		assert_true(fk != "", "%s has a font in exotic_fonts.json" % id)
		var f := QualityText.font(fk)
		assert_true(f is FontFile, "%s's font %s loads" % [id, fk])
		assert_true(f.has_char("A".unicode_at(0)) and f.has_char("a".unicode_at(0)) and f.has_char("3".unicode_at(0)), fk + " has letters and figures")
		assert_true(f.get_string_size(String(RulesDB.weapon(String(id)).name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > 20.0, fk + " measures")
		fonts[fk] = true
	for fk in fonts:
		var lic := String(QualityText.family(fk).get("license", ""))
		assert_true(lic.begins_with("OFL-") or lic.begins_with("APACHE-"), "%s names its licence file (build_windows.sh copies OFL-*/APACHE-*)" % fk)
		assert_true(FileAccess.file_exists("res://assets/fonts/" + lic), "%s ships its licence %s" % [fk, lic])
		assert_true(String(QualityText.family(fk).get("author", "")) != "", fk + " has an author for the credits")
		assert_true(String(QualityText.family(fk).get("license_id", "")) in ["OFL-1.1", "Apache-2.0"], fk + " licence id")
	assert_false(QualityText.font_credits().is_empty(), "the faces are credited")
	for id in QualityText.exotic_data().weapons:
		assert_true(QualityText.is_exotic(String(id)), "%s in exotic_fonts.json is an exotic weapon" % id)
	assert_eq(QualityText.style("malorian_arms_3516", "MALORIAN ARMS 3516").text, "Malorian Arms 3516", "blackletter in title case")
	assert_eq(QualityText.style("weapon/microwaver", "MICROWAVER").text, "MICROWAVER")


func test_bbcode_carries_the_style() -> void:
	var p := QualityText.bbcode("weapon/heavy_pistol@poor", "Heavy Pistol")
	assert_true(p.begins_with("[color=#") and p.contains("hEaVy PiStOl"), p)
	assert_true(QualityText.bbcode("weapon/heavy_pistol@excellent", "Heavy Pistol").contains("[sheen n=12]"))
	assert_true(QualityText.bbcode("weapon/flamethrower", "Flamethrower").contains("[font=res://assets/fonts/"))
	assert_eq(QualityText.bbcode("weapon/heavy_pistol", "Heavy Pistol"), "Heavy Pistol")
