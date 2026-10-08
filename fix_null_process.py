import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """func _process(delta: float) -> void:
	if passenger_track == null: return
	if controller.state == CarJamController.GameState.PLAYING:"""

code = code.replace("func _process(delta: float) -> void:\n\tif controller.state == CarJamController.GameState.PLAYING:", replacement)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed null in process")
