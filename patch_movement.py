import re

with open("scripts/gameplay/vehicle_movement.gd", "r") as f:
    code = f.read()

# Fix the final target Y
code = code.replace('var final_target = Vector2(exit_local.x, reverse_pos.y - 100.0)', 'var final_target = Vector2(exit_local.x, reverse_pos.y - 10.0)')

# Fix the bezier tangent out handle (so it doesn't swing up into the slots)
code = code.replace('curve.add_point(reverse_pos, Vector2.ZERO, Vector2(0, -120.0))', 'curve.add_point(reverse_pos, Vector2.ZERO, Vector2(0, -50.0))')

with open("scripts/gameplay/vehicle_movement.gd", "w") as f:
    f.write(code)

print("Movement path patched.")
