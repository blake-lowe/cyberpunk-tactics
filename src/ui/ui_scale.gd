class_name UiScale
extends RefCounted
## The HUD and menus are laid out for a 720-line screen; bigger windows scale them up (owner:
## text was tiny at 1080p and up). Steps of 0.5 keep the 3D view's pixels whole: the greybox
## sizes its low-res buffer from the logical size (2 logical px per texel), so a texel is
## 2 x factor screen pixels.

const BASE_H := 720.0


static func factor(h: int) -> float:
	return maxf(1.0, roundf(h / 360.0) / 2.0)


static func apply(w: Window, mult := 1.0) -> void:
	var f := maxf(1.0, factor(w.size.y) * mult)
	if not is_equal_approx(w.content_scale_factor, f):
		w.content_scale_factor = f


## Scale now and whenever the window is resized. `mult` < 1 for text-dense menus (no 3D view, so
## the factor needn't keep texels whole).
static func watch(w: Window, mult := 1.0) -> void:
	apply(w, mult)
	for c in w.size_changed.get_connections():
		if (c.callable as Callable).get_method() == "apply":
			w.size_changed.disconnect(c.callable)
	w.size_changed.connect(apply.bind(w, mult))
