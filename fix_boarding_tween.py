import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# Fix the tween target
code = code.replace(
    'tw.tween_property(pv, "global_position", parking_root.global_position + slot_pos + Vector2(0, 12), 0.36)',
    'tw.tween_property(pv, "position", slot_pos + Vector2(0, 12), 0.36)'
)

# And pv.position = global_p -> we should set pv.global_position = global_p and then tween position!
# Actually, if we add pv to boarding_effects, pv.global_position = global_p works perfectly, then we tween pv.position!
with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed boarding tween")
