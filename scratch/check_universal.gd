extends SceneTree

func _init():
	var level_data = load("res://levels/level_002.tres")
	var UniversalIntegration = load("res://scripts/universal/level_integration.gd")
	for cap in [32, 40, 48, 60, 80, 144]:
		var runtime = UniversalIntegration.build_runtime(level_data, cap, 6)
		print("L2 cap: ", cap, " | solvable: ", runtime.validation.solvable, " | steps: ", runtime.validation.steps, " | reason: ", runtime.validation.reason)
	quit()
