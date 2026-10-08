extends SceneTree

func _init() -> void:
	var lvl = load("res://levels/level_001.tres") as CarJamLevelData
	if lvl:
		lvl.parking_slots_count = 7
		ResourceSaver.save(lvl, "res://levels/level_001.tres")
		print("Updated level_001.tres parking slots to 7")
	else:
		print("Failed to load level")
	quit()
