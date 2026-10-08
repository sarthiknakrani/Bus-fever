import re

with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    code = f.read()

draw_iso = """func _draw() -> void:
	var cells_w: float = float(vehicle_footprint.size()) if vehicle_dir == CarJamVehicleData.Direction.RIGHT or vehicle_dir == CarJamVehicleData.Direction.LEFT else 1.0
	var cells_h: float = float(vehicle_footprint.size()) if vehicle_dir == CarJamVehicleData.Direction.UP or vehicle_dir == CarJamVehicleData.Direction.DOWN else 1.0
	
	var tile_w = 80.0
	var tile_h = 46.0
	var height = 35.0
	var margin = 0.15 # 15% margin
	
	# Compute logical corners in local grid space (centered at 0,0)
	var hw = cells_w / 2.0 - margin
	var hh = cells_h / 2.0 - margin
	
	# Helper to convert local grid coords to local isometric coords
	var to_iso = func(lx: float, ly: float) -> Vector2:
		return Vector2((lx - ly) * (tile_w / 2.0), (lx + ly) * (tile_h / 2.0))
	
	# The 4 corners on the ground
	# 0: top, 1: right, 2: bottom, 3: left in grid space
	var g0 = to_iso(-hw, -hh)
	var g1 = to_iso(hw, -hh)
	var g2 = to_iso(hw, hh)
	var g3 = to_iso(-hw, hh)
	
	# Shift up for 3D roof
	var up = Vector2(0, -height)
	var r0 = g0 + up
	var r1 = g1 + up
	var r2 = g2 + up
	var r3 = g3 + up
	
	var c_top = vehicle_color.lightened(0.15)
	var c_left = vehicle_color
	var c_right = vehicle_color.darkened(0.25)
	
	# Draw Left Face (g3, g2, r2, r3)
	draw_colored_polygon(PackedVector2Array([g3, g2, r2, r3]), c_left)
	
	# Draw Right Face (g2, g1, r1, r2)
	draw_colored_polygon(PackedVector2Array([g2, g1, r1, r2]), c_right)
	
	# Draw Top Face (r0, r1, r2, r3)
	draw_colored_polygon(PackedVector2Array([r0, r1, r2, r3]), c_top)
	
	# Outline for pop
	var oc = Color(0,0,0, 0.4)
	draw_line(r0, r1, oc, 2.0)
	draw_line(r1, r2, oc, 2.0)
	draw_line(r2, r3, oc, 2.0)
	draw_line(r3, r0, oc, 2.0)
	draw_line(g2, r2, oc, 2.0)
	draw_line(g3, r3, oc, 2.0)
	draw_line(g1, r1, oc, 2.0)
"""

code = re.sub(r'func _draw\(\) -> void:[\s\S]*?(?=func _setup_capacity_badge)', draw_iso, code)

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(code)

print("Fixed VehicleView")
