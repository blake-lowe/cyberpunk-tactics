extends SceneTree
## Writes a contact sheet of procedural portraits (4x upscaled) for review:
##   timeout 60 godot --headless -s tools/dump_portraits.gd -- out.png

func _initialize() -> void:
	var out := "portraits.png"
	for a in OS.get_cmdline_user_args():
		out = a
	var roles := ["solo", "netrunner", "solo", "netrunner", "solo", "netrunner", "", ""]
	var sheet := Image.create(Portraits.S * 4 * 4, Portraits.S * 4 * 2, false, Image.FORMAT_RGBA8)
	for i in 8:
		var team := 0 if i < 6 else 1
		var img := Portraits.make(UnitLook.make(i, team, roles[i]))
		img.resize(Portraits.S * 4, Portraits.S * 4, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i((i % 4) * Portraits.S * 4, (i / 4) * Portraits.S * 4))
	sheet.save_png(out)
	quit()
