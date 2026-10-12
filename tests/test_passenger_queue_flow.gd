extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	_run_queue_flow_tests()

func _run_queue_flow_tests() -> void:
	await create_timer(0.3).timeout
	print("\n==========================================")
	print("=== PASSENGER QUEUE FLOW & BACKPRESSURE QA ===")
	print("==========================================")

	var failures := 0

	# ----------------------------------------------------
	# TEST 1: Level 1 (240 Total Demand) Distribution
	# ----------------------------------------------------
	print("\n--- TEST 1: Level 1 Dense Oval & Feeder Distribution ---")
	var l1: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l1)
	if not l1.is_node_ready():
		l1._ready()
	await create_timer(0.15).timeout

	var l1_oval := l1.circulating_ids.size()
	var l1_feeder := l1._feeder_passengers.size() + l1._pending_feeder_passengers.size()
	var l1_total := l1_oval + l1_feeder

	print("  [MEASURED] Level 1 Oval circulating: %d" % l1_oval)
	print("  [MEASURED] Level 1 Feeder waiting: %d" % l1_feeder)
	print("  [MEASURED] Level 1 Total: %d" % l1_total)

	if l1_oval == 152:
		print("  [PASS] Oval starts densely packed with exactly 152 passengers (38 rows x 4 lanes)")
	else:
		print("  [FAIL] Expected 152 passengers on oval, got %d" % l1_oval)
		failures += 1

	if l1_feeder == 88:
		print("  [PASS] Feeder queue starts with remaining 88 passengers waiting")
	else:
		print("  [FAIL] Expected 88 feeder passengers, got %d" % l1_feeder)
		failures += 1

	if l1_total == 240:
		print("  [PASS] Total demand strictly conserved (240 passengers)")
	else:
		print("  [FAIL] Total demand mismatch: expected 240, got %d" % l1_total)
		failures += 1

	# ----------------------------------------------------
	# TEST 2: Backpressure Invariant — Zero Merge Without Boarding
	# ----------------------------------------------------
	print("\n--- TEST 2: Zero Feeder Merge Without Boarding (Backpressure Gate) ---")
	# Simulate 1.5 seconds of queue circulation without tapping any bus
	await create_timer(1.5).timeout

	var l1_oval_after := l1.circulating_ids.size()
	var l1_feeder_after := l1._feeder_passengers.size() + l1._pending_feeder_passengers.size()

	print("  [MEASURED] After 1.5s unboarded circulation: Oval=%d, Feeder=%d" % [l1_oval_after, l1_feeder_after])

	if l1_oval_after == 152 and l1_feeder_after == 88:
		print("  [PASS] Zero feeder passengers merged into oval while unboarded (Backpressure strictly enforced)")
	else:
		print("  [FAIL] Premature feeder merge detected: Oval=%d, Feeder=%d" % [l1_oval_after, l1_feeder_after])
		failures += 1

	# ----------------------------------------------------
	# TEST 3: Boarding-Driven Capacity Release
	# ----------------------------------------------------
	print("\n--- TEST 3: Boarding-Driven Feeder Merge Release ---")
	# Tap vehicle 3 (Red bus, capacity 40)
	var tapped := l1.controller.tap_vehicle(3)
	if not tapped:
		print("  [FAIL] Could not tap vehicle 3")
		failures += 1
	else:
		print("  [PASS] Bus 3 tapped. Waiting for arrival, full boarding, and feeder merge...")
		# Wait for bus arrival (0.8s) + full boarding (3.5s) + train tail to pass entrance and feeder merge (5.0s)
		await create_timer(9.5).timeout

		var v3 = l1.controller.vehicles[3]
		var boarded = v3.passenger_occupancy
		var in_flight = l1.controller.pending_boarders.get(3, 0)
		var total_boarded_or_boarding = boarded + in_flight

		var current_oval = l1.circulating_ids.size()
		var current_feeder = l1._feeder_passengers.size() + l1._pending_feeder_passengers.size()
		var total_active_and_served = current_oval + current_feeder + total_boarded_or_boarding

		print("  [MEASURED] Boarded/Boarding: %d | Oval: %d | Feeder: %d | Sum: %d" % [
			total_boarded_or_boarding, current_oval, current_feeder, total_active_and_served
		])

		if total_boarded_or_boarding > 0:
			print("  [PASS] Boarding active: %d passengers departed oval into bus" % total_boarded_or_boarding)
		else:
			print("  [FAIL] No passengers boarded bus 3")
			failures += 1

		# Invariant: total sum must equal 240
		if total_active_and_served == 240:
			print("  [PASS] Authoritative Conservation Invariant holds: Total demand strictly preserved at 240")
		else:
			print("  [FAIL] Demand leak! Total was %d, expected 240" % total_active_and_served)
			failures += 1

		# Feeder must have released at least some passengers to replace departed oval passengers
		if current_feeder < 80:
			print("  [PASS] Feeder released passengers (%d remaining < 80) driven by oval boarding" % current_feeder)
		else:
			print("  [FAIL] Feeder did not release any passengers despite boarding occurring")
			failures += 1

	l1.queue_free()

	# ----------------------------------------------------
	# TEST 4: Level 2 (48 Total Demand) Distribution
	# ----------------------------------------------------
	print("\n--- TEST 4: Level 2 Low-Demand Oval Distribution ---")
	var gc = root.get_node_or_null("GameController")
	if gc:
		gc.current_level_number = 2

	var l2: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l2)
	if not l2.is_node_ready():
		l2._ready()
	await create_timer(0.15).timeout

	var l2_oval := l2.circulating_ids.size()
	var l2_feeder := l2._feeder_passengers.size() + l2._pending_feeder_passengers.size()
	var l2_total := l2_oval + l2_feeder

	print("  [MEASURED] Level 2 Oval circulating: %d" % l2_oval)
	print("  [MEASURED] Level 2 Feeder waiting: %d" % l2_feeder)
	print("  [MEASURED] Level 2 Total: %d" % l2_total)

	if l2_oval == 152 and l2_feeder == 328 and l2_total == 480:
		print("  [PASS] Level 2 (480 demand): Oval starts with 152, Feeder starts with 328, Total 480 strictly conserved")
	else:
		print("  [FAIL] Level 2 distribution unexpected: Oval=%d, Feeder=%d, Total=%d" % [l2_oval, l2_feeder, l2_total])
		failures += 1

	l2.queue_free()
	if gc:
		gc.current_level_number = 1

	print("\n==========================================")
	if failures == 0:
		print("=== ALL QUEUE FLOW & BACKPRESSURE TESTS PASSED (0 FAILURES) ===")
	else:
		print("=== %d QUEUE FLOW TESTS FAILED ===" % failures)
	print("==========================================\n")

	quit(failures)
