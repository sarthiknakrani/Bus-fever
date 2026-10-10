import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

old_vlayer = """	vehicle_layer = Node2D.new()
	vehicle_layer.name = "VehicleLayer"
	board_root.add_child(vehicle_layer)"""

new_vlayer = """	vehicle_layer = Node2D.new()
	vehicle_layer.name = "VehicleLayer"
	vehicle_layer.y_sort_enabled = true
	board_root.add_child(vehicle_layer)"""

content = content.replace(old_vlayer, new_vlayer)

# Also let's make sure the vehicle views themselves can be y-sorted if they have multiple sprites
# Well, actually just sorting the `VehicleView` nodes against each other requires `y_sort_enabled` on `vehicle_layer`. 

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)
print("Patched y_sort")
