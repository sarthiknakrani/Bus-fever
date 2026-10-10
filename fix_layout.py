import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# We want the gap between track and parking to be smaller so parking goes up.
# Currently: var gap = clampf(remaining_h / 2.5, 60.0, 350.0)
code = code.replace('var gap = clampf(remaining_h / 2.5, 60.0, 350.0)', 'var gap = clampf(remaining_h / 4.0, 20.0, 100.0)')

# Let's also adjust the partition_y to be tighter to the parking base
code = code.replace('var partition_y = parking_y + (parking_h / 2.0) + (gap / 2.0)', 'var partition_y = parking_y + (parking_h / 2.0) + 10.0')

# And move the board slightly lower if needed, or leave it centered.
# The user wants "Move the road LOWER, clearly underneath the complete parking-container structure."
# If partition_y is tight to the parking, it is clearly underneath it.
# We will draw the straight line at partition_y + 160.0 in platform_view.gd

# Now we also need to ensure the bus reverse animation matches this visual road.
# The bus is at parking_y. The middle of the road is at partition_y + 80.0.
# partition_y = parking_y + 110.
# So middle of road = parking_y + 190.
with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

with open("scripts/gameplay/vehicle_movement.gd", "r") as f:
    v_code = f.read()

# Make the reverse animation go to the exact middle of the new exit road
v_code = v_code.replace('var reverse_pos = vehicle_node.position + Vector2(0, 220.0)', 'var reverse_pos = vehicle_node.position + Vector2(0, 185.0)')

with open("scripts/gameplay/vehicle_movement.gd", "w") as f:
    f.write(v_code)

print("Layout and animation patched.")
