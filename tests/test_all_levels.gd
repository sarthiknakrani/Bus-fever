extends SceneTree

const LevelRegistryScript := preload("res://resources/level_registry.gd")
const HintSolverScript := preload("res://scripts/core/hint_solver.gd")

func _init() -> void:
	print("=== Validating all levels in LevelRegistry ===")
	var total: int = LevelRegistryScript.get_level_count()
	var any_failed := false
	for i in range(1, total + 1):
		var lvl: LevelData = LevelRegistryScript.get_level(i)
		var val: Dictionary = lvl.validate()
		if not val.ok:
			print("  [FAIL] Level %d failed validation: %s" % [i, ", ".join(val.errors)])
			any_failed = true
		else:
			print("  [PASS] Level %d ('%s') validated OK (%d vehicles, %d passengers)" % [
				i, lvl.display_name, lvl.vehicles.size(), lvl.passenger_order.size()
			])
	if any_failed:
		print("FAILED level validation.")
		quit(1)
	else:
		print("ALL LEVELS VALIDATED!")
		quit(0)
