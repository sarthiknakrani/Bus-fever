extends SceneTree

const CarJamPassengerQueue := preload("res://scripts/gameplay/passenger_queue.gd")
const CarJamParkingManager := preload("res://scripts/gameplay/parking_manager.gd")
const CarJamBoardingController := preload("res://scripts/gameplay/boarding_controller.gd")
const VehicleModel := preload("res://scripts/gameplay/vehicle_model.gd")
const PassengerGroupData := preload("res://data/passenger_group_data.gd")
const CarJamVehicleData := preload("res://data/vehicle_data.gd")

func _init() -> void:
	print("=== Running Boarding Controller & Queue QA Tests ===")
	var failures: Array[String] = []

	var queue := CarJamPassengerQueue.new()
	var parking := CarJamParkingManager.new()
	parking.setup(4)
	var boarding := CarJamBoardingController.new()

	# Create ordered queue:
	# Group 0: Blue (4)
	# Group 1: Red (4)
	# Group 2: Yellow (6)
	var groups: Array[PassengerGroupData] = [
		PassengerGroupData.new(0, "blue", 4),
		PassengerGroupData.new(1, "red", 4),
		PassengerGroupData.new(2, "yellow", 6)
	]
	queue.setup(groups)

	var initial_total := queue.get_initial_total() # 14
	if initial_total != 14:
		failures.append("Initial total should be 14, got %d" % initial_total)

	# 1. Non-matching parked vehicle test:
	# Park a RED vehicle in slot 0 while queue head is BLUE
	var v_red := VehicleModel.new()
	v_red.id = 1
	v_red.code = "RED_1"
	v_red.color_id = "red"
	v_red.capacity = 4
	v_red.state = VehicleModel.VehicleState.PARKED

	parking.reserve_slot(v_red.id)
	parking.confirm_arrival(0, v_red.id)

	var vehicles: Dictionary = { v_red.id: v_red }

	var evts := boarding.evaluate_boarding(queue, parking, vehicles)
	if not evts.is_empty():
		failures.append("No boarding should occur when queue head (blue) does not match parked vehicle (red)")
	elif v_red.passenger_occupancy != 0:
		failures.append("Red vehicle occupancy should remain 0")
	elif queue.get_head_color() != "blue":
		failures.append("Queue head should remain blue (no skipping allowed)")
	else:
		print("  [PASS] Non-matching queue head: red vehicle did not board, blue head was NOT skipped")

	# 2. Matching vehicle arrives:
	# Park a BLUE vehicle in slot 1
	var v_blue := VehicleModel.new()
	v_blue.id = 2
	v_blue.code = "BLUE_1"
	v_blue.color_id = "blue"
	v_blue.capacity = 4
	v_blue.state = VehicleModel.VehicleState.PARKED

	parking.reserve_slot(v_blue.id)
	parking.confirm_arrival(1, v_blue.id)
	vehicles[v_blue.id] = v_blue

	evts = boarding.evaluate_boarding(queue, parking, vehicles)
	if evts.size() != 2: # Blue boards group 0 (fills), then Red in slot 0 boards group 1 (fills)!
		failures.append("Expected 2 boarding events (blue then red), got %d" % evts.size())
	else:
		print("  [PASS] Blue boarded, filled, and queue advanced to Red which boarded slot 0!")

	if not v_blue.is_full() or v_blue.state != VehicleModel.VehicleState.FULL:
		failures.append("Blue vehicle should be FULL")
	if not v_red.is_full() or v_red.state != VehicleModel.VehicleState.FULL:
		failures.append("Red vehicle should be FULL")

	# Depart them
	parking.release_slot(0)
	parking.release_slot(1)
	v_blue.state = VehicleModel.VehicleState.COMPLETED
	v_red.state = VehicleModel.VehicleState.COMPLETED

	# Now queue head should be Yellow (6 passengers)
	if queue.get_head_color() != "yellow":
		failures.append("Queue head should now be yellow, got '%s'" % queue.get_head_color())
	else:
		print("  [PASS] Queue successfully advanced to Yellow")

	# 3. Partial boarding:
	# Yellow vehicle with capacity 4 arrives (group has 6)
	var v_yellow := VehicleModel.new()
	v_yellow.id = 3
	v_yellow.code = "YELLOW_1"
	v_yellow.color_id = "yellow"
	v_yellow.capacity = 4
	v_yellow.state = VehicleModel.VehicleState.PARKED

	parking.reserve_slot(v_yellow.id)
	parking.confirm_arrival(0, v_yellow.id)
	vehicles[v_yellow.id] = v_yellow

	evts = boarding.evaluate_boarding(queue, parking, vehicles)
	if v_yellow.passenger_occupancy != 4 or not v_yellow.is_full():
		failures.append("Yellow vehicle should have boarded 4 and become FULL")
	elif queue.get_head_group().remaining_count != 2:
		failures.append("Yellow group should have 2 remaining passengers, got %d" % queue.get_head_group().remaining_count)
	else:
		print("  [PASS] Partial boarding: yellow took 4, 2 remaining in queue head")

	# 4. Conservation of Passengers
	var total_boarded := v_blue.passenger_occupancy + v_red.passenger_occupancy + v_yellow.passenger_occupancy # 4 + 4 + 4 = 12
	var total_remaining := queue.get_remaining_total() # 2
	if (total_boarded + total_remaining) != initial_total:
		failures.append("Conservation violated: boarded (%d) + remaining (%d) != initial (%d)" % [total_boarded, total_remaining, initial_total])
	else:
		print("  [PASS] Conservation of Passengers strictly verified: 12 boarded + 2 remaining = 14 initial")

	if failures.is_empty():
		print("=== All Boarding & Queue Tests Passed (0 failures) ===")
		quit(0)
	else:
		print("=== Boarding Tests FAILED: %s ===" % str(failures))
		quit(1)
