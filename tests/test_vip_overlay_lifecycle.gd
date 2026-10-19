extends SceneTree

# Verifies the VIP UI overlay (Feature C) builds and responds to controller signals
# via the CarJamLevel scene. Bypasses actual level rendering and asserts on the
# overlay's visibility transitions.

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("\n=== VIP UI OVERLAY LIFECYCLE TEST ===\n")

	var CarJamLevelScene = preload("res://scenes/gameplay/car_jam_level.tscn")
	var lvl = CarJamLevelScene.instantiate()
	if lvl == null:
		print("  [FAIL] CarJamLevel failed to instantiate")
		quit(1)
		return
	root.add_child(lvl)

	# The scene's _ready() instantiates the VIP overlay; give it a frame.
	await create_timer(0.2).timeout

	if lvl.vip_overlay == null or not is_instance_valid(lvl.vip_overlay):
		print("  [FAIL] vip_overlay was not created by _setup_vip_overlay()")
		quit(1)
		return
	if lvl.vip_button == null or not is_instance_valid(lvl.vip_button):
		print("  [FAIL] vip_button was not created")
		quit(1)
		return
	print("  [PASS] VIP overlay + button instantiated")

	# Initial state: overlay should be hidden (controller hasn't fired vip_available_changed yet).
	assert(not lvl.vip_overlay.visible, "VIP overlay must start hidden")
	print("  [PASS] VIP overlay hidden at scene start")

	# Trigger the controller's available signal: overlay should become visible.
	var ctrl: CarJamController = lvl.controller
	if ctrl == null:
		print("  [FAIL] controller ref is null on the level scene")
		quit(1)
		return

	# Manually emit (simulating vip_available_changed(true) flow that runs at level load).
	ctrl.vip_available_changed.emit(true)
	await create_timer(0.05).timeout
	assert(lvl.vip_overlay.visible, "Overlay must become visible after vip_available_changed(true)")
	print("  [PASS] Overlay became visible on vip_available_changed(true)")

	# Consume the booster via the controller API, which fires vip_available_changed(false).
	# Pre-park a bus first so the call succeeds.
	var pm = ctrl.parking
	var v: VehicleModel = ctrl.vehicles.get(2, null)
	assert(v != null, "Need at least one vehicle to extract")
	pm.reserve_slot(2)
	pm.confirm_arrival(pm.get_slot_for_vehicle(2), 2)
	v.state = VehicleModel.VehicleState.PARKED
	var ok: bool = ctrl.try_extract_vip(2)
	assert(ok, "VIP extract must succeed with a parked bus present")
	await create_timer(0.05).timeout
	assert(not lvl.vip_overlay.visible, "Overlay must be hidden after vip_available_changed(false)")
	print("  [PASS] Overlay hidden after VIP consumption\n")

	print("=== ALL VIP UI OVERLAY TESTS PASSED ===\n")
	quit(0)
