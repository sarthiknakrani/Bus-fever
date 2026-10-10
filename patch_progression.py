import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# Replace _load_level_1 with _load_current_level
content = content.replace("func _load_level_1() -> void:", "func _load_current_level() -> void:")
content = content.replace("_load_level_1()", "_load_current_level()")

# Fix the implementation of _load_current_level
old_load = """func _load_current_level() -> void:
	var lvl: CarJamLevelData = null
	if ResourceLoader.exists("res://levels/level_001.tres"):
		lvl = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	if lvl == null:
		lvl = CarJamLevelFactory.create_level_1()

	controller.load_level(lvl)
	_setup_visuals(lvl)"""

new_load = """func _load_current_level() -> void:
	var lvl_num = 1
	if GameController:
		lvl_num = GameController.current_level_number
		
	var lvl: CarJamLevelData = null
	var path = "res://levels/level_%03d.tres" % lvl_num
	if ResourceLoader.exists(path):
		lvl = ResourceLoader.load(path) as CarJamLevelData
	
	if lvl == null:
		push_error("Level resource not found: " + path)
		if ResourceLoader.exists("res://levels/level_001.tres"):
			lvl = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
		else:
			lvl = CarJamLevelFactory.create_level_1()

	controller.load_level(lvl)
	_setup_visuals(lvl)"""

content = content.replace(old_load, new_load)

# Update the header title
content = content.replace('level_title_label.text = "Level 1"', 'level_title_label.text = "Level " + str(GameController.current_level_number if GameController else 1)')

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("Progression patched")
