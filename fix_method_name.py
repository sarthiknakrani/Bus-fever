import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

code = code.replace("controller.queue.get_total_remaining()", "controller.queue.get_remaining_total()")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed method name")
