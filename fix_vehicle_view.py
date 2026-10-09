import re

with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    code = f.read()

bad_func = """		var create_np = func(tex, color, w, h, y_off):
			var np = NinePatchRect.new()
			if tex: np.texture = tex
			np.modulate = color
			np.patch_margin_left = 24
			np.patch_margin_right = 24
			np.patch_margin_top = 24
			np.patch_margin_bottom = 24
			np.size = Vector2(w, h)
			np.position = Vector2(-w/2.0, -h/2.0 + y_off)
			add_child(np)
			return np"""

# Isometric screen UP requires local (-value, -value) 
good_func = """		var create_np = func(tex, color, w, h, y_off):
			var np = NinePatchRect.new()
			if tex: np.texture = tex
			np.modulate = color
			np.patch_margin_left = 24
			np.patch_margin_right = 24
			np.patch_margin_top = 24
			np.patch_margin_bottom = 24
			np.size = Vector2(w, h)
			# To shift straight UP/DOWN on an isometric screen, we must shift BOTH local X and Y.
			# y_off > 0 (down) -> (+x, +x)
			# y_off < 0 (up) -> (-x, -x)
			# An approximate multiplier for 0.6 scale is ~1.18.
			var iso_shift = Vector2(y_off * 1.18, y_off * 1.18)
			np.position = Vector2(-w/2.0, -h/2.0) + iso_shift
			add_child(np)
			return np"""
code = code.replace(bad_func, good_func)

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(code)

