extends SceneTree

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	var ctrl = CarJamController.new()
	var lvl = load("res://levels/level_001.tres")
	ctrl.load_level(lvl)
	
	print("Checking vehicle exit paths for Level 1:")
	for vid in ctrl.vehicles:
		var v = ctrl.vehicles[vid]
		var res = ctrl.board.check_swept_escape(v)
		print("  Vehicle %d (%s) at anchor %s, dir %d: can_escape = %s, blocker = %d" % [
			v.id, v.color_id, str(v.anchor), v.direction, res["can_escape"], res.get("blocker_id", -1)
		])
	quit()
