import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

bad_func = """	# 1. Determine local bounding sizes
	var track_h = 180.0
	var parking_h = 200.0
	var board_cells_w = float(controller.level_data.board_size.x)
	var board_cells_h = float(controller.level_data.board_size.y)
	var board_local_size = max(board_cells_w, board_cells_h) * CELL_SIZE
	# Rotated 45 deg, scale (1.0, 0.6)
	var board_pixel_w = board_local_size * sqrt(2.0)
	var board_pixel_h = board_pixel_w * 0.6
	
	# 2. Determine required margins and total logical dimensions
	# We need extra width for buses to exit the board cleanly.
	# A 3-cell bus takes ~234 pixels. We add 300 padding on each side.
	var required_w = max(640.0, board_pixel_w + 200.0)
	
	# Stack vertically with comfortable gaps
	var scale_w = screen_safe_w / required_w
	var scale_h = screen_safe_h / (track_h + 120.0 + parking_h + board_pixel_h)
	var scale_factor = clampf(min(scale_w, scale_h), 0.4, 2.0)
	
	# Compute how much logical vertical space we have available with this scale
	var available_local_h = screen_safe_h / scale_factor
	
	# Distribute the remaining vertical space evenly into the 2 gaps
	var remaining_h = available_local_h - (track_h + parking_h + board_pixel_h)
	# But cap the gaps so they don't look completely ridiculous
	var gap = clampf(remaining_h / 2.5, 60.0, 350.0)
	
	var total_content_h = track_h + gap + parking_h + gap + board_pixel_h
	
	# Safe areas on screen (top header, bottom boosters)
	var screen_safe_h = vp_size.y - 450.0 # leave 150 top, 300 bottom
	var screen_safe_w = vp_size.x * 0.95
	
	# 3. Calculate coherent scale factor to fit BOTH width and height
	# Scale factor was calculated above for dynamic gap
	
	# Apply scale to world root
	world_root.scale = Vector2(scale_factor, scale_factor)
	world_root.position = Vector2.ZERO
	
	# 4. Center the stacked layout around the middle of the safe area
	var half_h = (vp_size.y / 2.0) / scale_factor
	var top_y = -half_h + (150.0 / scale_factor) # Start drawing below the header
	
	# Or dynamically center the content block vertically in the available space:
	available_local_h = (screen_safe_h / scale_factor)
	var start_y = top_y + (available_local_h - total_content_h) / 2.0 + (track_h / 2.0)"""

good_func = """	# 1. Determine local bounding sizes
	var track_h = 180.0
	var parking_h = 200.0
	var board_cells_w = float(controller.level_data.board_size.x)
	var board_cells_h = float(controller.level_data.board_size.y)
	var board_local_size = max(board_cells_w, board_cells_h) * CELL_SIZE
	# Rotated 45 deg, scale (1.0, 0.6)
	var board_pixel_w = board_local_size * sqrt(2.0)
	var board_pixel_h = board_pixel_w * 0.6
	
	# 2. Determine required margins and total logical dimensions
	# We need extra width for buses to exit the board cleanly.
	var required_w = max(640.0, board_pixel_w + 200.0)
	
	# Safe areas on screen (top header, bottom boosters)
	var screen_safe_h = vp_size.y - 450.0 # leave 150 top, 300 bottom
	var screen_safe_w = vp_size.x * 0.95
	
	# Stack vertically with comfortable gaps
	var scale_w = screen_safe_w / required_w
	var scale_h = screen_safe_h / (track_h + 120.0 + parking_h + board_pixel_h)
	var scale_factor = clampf(min(scale_w, scale_h), 0.4, 2.0)
	
	# Compute how much logical vertical space we have available with this scale
	var available_local_h = screen_safe_h / scale_factor
	
	# Distribute the remaining vertical space evenly into the 2 gaps
	var remaining_h = available_local_h - (track_h + parking_h + board_pixel_h)
	# But cap the gaps so they don't look completely ridiculous
	var gap = clampf(remaining_h / 2.5, 60.0, 350.0)
	
	var total_content_h = track_h + gap + parking_h + gap + board_pixel_h
	
	# Apply scale to world root
	world_root.scale = Vector2(scale_factor, scale_factor)
	world_root.position = Vector2.ZERO
	
	# 4. Center the stacked layout around the middle of the safe area
	var half_h = (vp_size.y / 2.0) / scale_factor
	var top_y = -half_h + (150.0 / scale_factor) # Start drawing below the header
	
	# Or dynamically center the content block vertically in the available space:
	var start_y = top_y + (available_local_h - total_content_h) / 2.0 + (track_h / 2.0)"""

code = code.replace(bad_func, good_func)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

