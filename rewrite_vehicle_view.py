import re

with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    code = f.read()

draw_iso = """func _draw() -> void:
	# Calculate logical cells width/height
	var cells_w: int = vehicle_footprint.size() if vehicle_dir == CarJamVehicleData.Direction.RIGHT or vehicle_dir == CarJamVehicleData.Direction.LEFT else 1
	var cells_h: int = vehicle_footprint.size() if vehicle_dir == CarJamVehicleData.Direction.UP or vehicle_dir == CarJamVehicleData.Direction.DOWN else 1
	
	var tile_w = 80.0
	var tile_h = 46.0
	var height = 40.0
	var margin = 6.0
	
	# Compute logical isometric bounding box for the footprint
	# In our setup, right=x+, down=y+
	var base_x = (cells_w * tile_w) / 2.0 - margin
	var base_y = (cells_h * tile_w) / 2.0 - margin
	
	# We draw an isometric block manually
	# Center is (0,0)
	var p_top = Vector2(0, -base_y * (tile_h/tile_w))
	var p_right = Vector2(base_x, 0)
	var p_bottom = Vector2(0, base_y * (tile_h/tile_w))
	var p_left = Vector2(-base_x, 0)
	
	var c_top = vehicle_color.lightened(0.2)
	var c_left = vehicle_color
	var c_right = vehicle_color.darkened(0.3)
	
	# Shift up for 3D height
	var up = Vector2(0, -height)
	
	# Top face
	draw_colored_polygon(PackedVector2Array([p_top+up, p_right+up, p_bottom+up, p_left+up]), c_top)
	
	# Left face
	draw_colored_polygon(PackedVector2Array([p_left+up, p_bottom+up, p_bottom, p_left]), c_left)
	
	# Right face
	draw_colored_polygon(PackedVector2Array([p_bottom+up, p_right+up, p_right, p_bottom]), c_right)
"""

code = re.sub(r'func _draw\(\) -> void:[\s\S]*?(?=func _setup_capacity_badge)', draw_iso, code)

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(code)

print("Rewrote VehicleView for isometric")
