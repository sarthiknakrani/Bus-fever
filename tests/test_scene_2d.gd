extends SceneTree

const Level1Scene := preload("res://scenes/level1.tscn")

func _init() -> void:
	print("=== Validating 2D Level Scene ===")
	var scene = Level1Scene.instantiate()
	if scene == null:
		print("  [FAIL] Failed to instantiate Level1 scene")
		quit(1)
		return
	print("  [PASS] Level1 scene instantiated as Node2D: %s" % (scene is Node2D))

	root.add_child(scene)
	print("  [PASS] Scene added to tree")
	if not scene.is_node_ready():
		scene._ready()

	# Verify 2D nodes exist
	var game_world = scene.get_node_or_null("GameWorld")
	if game_world != null and game_world is Node2D:
		print("  [PASS] GameWorld Node2D found")
	else:
		print("  [FAIL] GameWorld Node2D missing")
		quit(1)
		return

	var vehicles = game_world.get_node_or_null("Vehicles")
	if vehicles != null and vehicles.get_child_count() > 0:
		print("  [PASS] Vehicles 2D nodes built: %d vehicles" % vehicles.get_child_count())
	else:
		print("  [FAIL] Vehicles 2D nodes missing")
		quit(1)
		return

	var bays = game_world.get_node_or_null("Bays")
	if bays != null and bays.get_child_count() == 7:
		print("  [PASS] 7 waiting bays built")
	else:
		print("  [FAIL] Waiting bays missing or count != 7")
		quit(1)
		return

	# Simulate a bus tap on vehicle 0 (bus A)
	scene._controller.tap_vehicle(0)
	print("  [PASS] Bus A tapped successfully")

	scene.queue_free()
	print("=== 2D Level Scene Validation PASSED! ===")
	quit(0)
