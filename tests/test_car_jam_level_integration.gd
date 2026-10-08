extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	print("=== Running Car Jam Level Full Integration Test ===")
	var failures: Array[String] = []

	var scene: Node2D = CarJamLevelScene.instantiate()
	if scene == null:
		print("  [FAIL] Failed to instantiate CarJamLevel scene")
		quit(1)
		return
	print("  [PASS] CarJamLevel instantiated as Node2D")

	root.add_child(scene)
	if not scene.is_node_ready():
		scene._ready()
	print("  [PASS] Scene added to tree and _ready executed")

	# 1. Hierarchy verification
	var world_root = scene.get_node_or_null("WorldRoot")
	if world_root == null:
		failures.append("WorldRoot missing")
	else:
		print("  [PASS] WorldRoot found")

	var board_root = world_root.get_node_or_null("BoardRoot")
	var parking_root = world_root.get_node_or_null("ParkingRoot")
	var passenger_track = world_root.get_node_or_null("PassengerTrack")
	var transit_layer = world_root.get_node_or_null("TransitLayer")
	var camera_2d = scene.get_node_or_null("Camera2D")
	var hud = scene.get_node_or_null("HUD")

	if board_root == null or parking_root == null or passenger_track == null or transit_layer == null or camera_2d == null or hud == null:
		failures.append("One or more required hierarchy nodes missing")
	else:
		print("  [PASS] Exact required hierarchy verified: BoardRoot, ParkingRoot, PassengerTrack, TransitLayer, Camera2D, HUD")

	# 2. Entity count check
	var ctrl: CarJamController = scene.controller
	if ctrl == null:
		failures.append("Controller missing")
		print("=== Integration Tests FAILED ===")
		quit(1)
		return

	if ctrl.vehicles.size() != 12:
		failures.append("Expected 12 vehicles, got %d" % ctrl.vehicles.size())
	else:
		print("  [PASS] 12 vehicles initialized on board")

	if ctrl.parking.get_slot_count() != 4:
		failures.append("Expected 4 parking slots, got %d" % ctrl.parking.get_slot_count())
	else:
		print("  [PASS] Exactly 4 parking slots initialized")

	if ctrl.queue.get_initial_total() != 48:
		failures.append("Expected 48 initial passengers, got %d" % ctrl.queue.get_initial_total())
	else:
		print("  [PASS] 48 passengers initialized in queue")

	# 3. Blocked vehicle tap test
	# Vehicle B (id 1) is initially blocked by Vehicle A (id 0)
	var tapped_blocked := ctrl.tap_vehicle(1)
	if tapped_blocked:
		failures.append("Blocked vehicle B should NOT be dispatched")
	else:
		print("  [PASS] Blocked tap rejected: Vehicle B remained ON_BOARD")

	# 4. Legal dispatch and boarding test
	# Vehicle A (id 0, blue) is initially free and matches queue head (blue)
	var tapped_a := ctrl.tap_vehicle(0)
	if not tapped_a:
		failures.append("Vehicle A should be a legal dispatch")
	else:
		print("  [PASS] Vehicle A dispatched successfully")

	# Simulate arrival at slot 0
	ctrl.on_vehicle_arrived_at_slot(0, 0, ctrl.session_token)
	var v_a: VehicleModel = ctrl.vehicles[0]
	if not v_a.is_full() or v_a.state != VehicleModel.VehicleState.FULL:
		failures.append("Vehicle A should have boarded 4 blue passengers and become FULL")
	else:
		print("  [PASS] Vehicle A boarded 4 matching blue passengers and filled")

	# Simulate departure of vehicle A
	ctrl.on_vehicle_departed_from_slot(0, 0, ctrl.session_token)
	if v_a.state != VehicleModel.VehicleState.COMPLETED:
		failures.append("Vehicle A should be COMPLETED after departure")
	elif ctrl.parking.find_available_slot() != 0:
		failures.append("Slot 0 should be released and free after departure")
	else:
		print("  [PASS] Vehicle A departed, marked COMPLETED, and slot 0 freed")

	# 5. Fast unblocking: Now Vehicle B (id 1) should be FREE to escape UP!
	var tapped_b := ctrl.tap_vehicle(1)
	if not tapped_b:
		failures.append("Vehicle B should now be unblocked and legal to dispatch")
	else:
		print("  [PASS] Dynamic unblocking: Vehicle B successfully dispatched after A cleared")

	scene.queue_free()

	if failures.is_empty():
		print("=== All Car Jam Level Integration Tests Passed (0 failures) ===")
		quit(0)
	else:
		print("=== Integration Tests FAILED: %s ===" % str(failures))
		quit(1)
