import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """
			# Winding Path (Reference style)
			var band_width = 5
			var band_row = pass_idx / band_width
			var band_col = pass_idx % band_width
			
			var path_t = float(band_row) * 0.25
			var center_x = sin(path_t) * 140.0
			var center_y = -float(band_row) * 28.0
			
			var px = center_x + (float(band_col) - 2.0) * 24.0
			var py = center_y

			pv.position = Vector2(px, py)
			pv.set_meta("base_y", py)
			passenger_visuals.add_child(pv)
			passenger_views.append(pv)
			pass_idx += 1
"""

# We need to replace the inner loop
old_code = """				# Snake layout: 12 passengers per row
				var row = pass_idx / 12
				var col = pass_idx % 12
				var px = (float(col) - 5.5) * 26.0
				var py = -float(row) * 32.0
				
				# Alternate direction every row to create a continuous snake path
				if row % 2 == 1:
					px = -px
				
				pv.position = Vector2(px, py)
				pv.set_meta("base_y", py)
				passenger_visuals.add_child(pv)
				passenger_views.append(pv)
				pass_idx += 1"""

code = code.replace(old_code, replacement.strip('\n'))

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Patched passenger curve")
