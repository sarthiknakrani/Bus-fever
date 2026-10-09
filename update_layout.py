import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# Replace the layout configuration for platform_bg
old_patch = """	if platform_bg != null:
		platform_bg.position = Vector2(0, board_y)
		platform_bg.setup(board_pixel_w + 160.0, board_pixel_h + 240.0)"""

new_patch = """	if platform_bg != null:
		platform_bg.position = Vector2.ZERO # drawn relative to world_root
		
		# Full screen bounds in local space
		var local_bottom = (vp_size.y / scale_factor) + 1000.0 # extend way down
		
		# Start platform slightly above the parking slots
		var plat_top = parking_y - (parking_h / 2.0) - 40.0
		
		# Partition gap
		var partition_y = parking_y + (parking_h / 2.0) + (gap / 2.0)
		
		# Width needs to cover entire screen width
		var full_w = (vp_size.x / scale_factor) + 200.0
		
		platform_bg.setup_full(plat_top, local_bottom, full_w, partition_y)"""

code = code.replace(old_patch, new_patch)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Updated car_jam_level.gd")
