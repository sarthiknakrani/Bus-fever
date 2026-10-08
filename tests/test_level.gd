extends SceneTree

## Headless test runner. Run via:
##     godot --headless --path . --script res://tests/test_level.gd
##
## Prints PASS / FAIL lines to stdout. Exit code is 0 on all-pass, 1
## otherwise. Designed for the validation criteria listed in section 35
## of the build directive.

const Level1Factory := preload("res://resources/level_1.gd")
const VehicleData := preload("res://scripts/core/vehicle_data.gd")
const HintSolver := preload("res://scripts/core/hint_solver.gd")

var _failures: Array[String] = []

func _init() -> void:
	print("=== Bus Fever Party Clone — headless tests ===")
	_test_level_data()
	_test_initial_availability()
	_test_solver_finds_solution()
	_test_passenger_capacity_match()
	_test_undo_round_trip()
	_test_bay_allocation()
	_test_full_game_flow()
	_test_restart()
	_test_extra_bay_runtime()
	_test_no_double_reservation()
	_summary()
	if _failures.is_empty():
		quit(0)
	else:
		quit(1)

func _build_level() -> LevelData:
	var factory := Level1Factory.new()
	return factory.build()

func _expect(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % name)
	else:
		print("  [FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])
		_failures.append(name)

func _summary() -> void:
	print("=== %d failures ===" % _failures.size())

func _test_level_data() -> void:
	print("\n[level_data] checking Level 1 layout")
	var lvl := _build_level()
	var r: Dictionary = lvl.validate()
	_expect(r.ok, "level validates", ", ".join(r.errors))
	_expect(lvl.vehicles.size() == 12, "12 vehicles", "got %d" % lvl.vehicles.size())
	var color_counts := {}
	for v in lvl.vehicles:
		var c := String(v["color"])
		if color_counts.has(c):
			color_counts[c] += 1
		else:
			color_counts[c] = 1
	for c in VehicleData.ALL_COLORS:
		_expect(int(color_counts.get(c, 0)) == 2, "color '%s' appears twice" % c, "got %d" % int(color_counts.get(c, 0)))
	_expect(lvl.passenger_order.size() == 48, "48 passengers", "got %d" % lvl.passenger_order.size())

func _test_initial_availability() -> void:
	print("\n[initial availability] expected: free A,D,G,J,L; blocked B,C,E,F,H,I,K")
	var lvl := _build_level()
	var solver := HintSolver.new()
	var st := solver.build_initial_state(lvl, false)
	var results := {}
	for id in st.vehicles.keys():
		var v: HintSolver.SimVehicle = st.vehicles[id]
		var can := solver._can_escape(st, v)
		results[id] = can
	var expect_free := ["A", "D", "G", "J", "L"]
	var expect_blocked := ["B", "C", "E", "F", "H", "I", "K"]
	for id in expect_free:
		_expect(bool(results.get(id, false)), "%s initially FREE" % id)
	for id in expect_blocked:
		_expect(not bool(results.get(id, true)), "%s initially BLOCKED" % id)

func _test_solver_finds_solution() -> void:
	print("\n[solver] finding winning path")
	var lvl := _build_level()
	var solver := HintSolver.new()
	var st := solver.build_initial_state(lvl, false)
	var path: Array = solver.find_solution(st)
	_expect(path.size() > 0, "solver finds at least one winning path")
	if path.size() > 0:
		print("  solution length: %d moves" % path.size())
		var cur := st
		for m in path:
			if m.type == "reevaluate":
				cur = m.state
			else:
				var v: HintSolver.SimVehicle = cur.vehicles[m.vehicle]
				cur = solver.apply_move(cur, v, int(m.bay))
				if cur == null:
					_expect(false, "move apply_move returns non-null")
					break
				cur = solver.reevaluate_waiting(cur)
		_expect(solver._is_win(cur), "replayed path reaches WIN")
		print("  full move order (vehicle, bay_index):")
		var i := 0
		for m in path:
			if m.has("vehicle"):
				print("    %2d. %s -> bay %s" % [i + 1, m.vehicle, m.bay])
			else:
				print("    %2d. (re-evaluation completes queue)" % [i + 1])
			i += 1

func _test_passenger_capacity_match() -> void:
	print("\n[capacity] per-color demand equals per-color capacity")
	var lvl := _build_level()
	var demand := {}
	for col in lvl.passenger_order:
		if demand.has(col):
			demand[col] += 1
		else:
			demand[col] = 1
	var capacity := {}
	for v in lvl.vehicles:
		var col := String(v["color"])
		if capacity.has(col):
			capacity[col] += int(v["capacity"])
		else:
			capacity[col] = int(v["capacity"])
	for col in demand.keys():
		_expect(int(demand[col]) == int(capacity.get(col, 0)), "%s demand %d == capacity %d" % [col, demand[col], capacity.get(col, 0)])

func _test_undo_round_trip() -> void:
	print("\n[undo] undo manager round-trip")
	var lvl := _build_level()
	var LC := preload("res://scripts/core/level_controller.gd")
	var lc = LC.new()
	get_root().add_child(lc)
	lc.load_level(lvl)
	var board_snap_before: Array = lc.get_board().snapshot()
	var bay_snap_before: Array = lc.get_bay_manager().snapshot()
	var active_before: int = lc.get_passenger_manager().active_index()
	var a_idx := lc.get_vehicle_index_by_id("A")
	var ok := lc.tap_vehicle(a_idx)
	_expect(ok, "tap A succeeds")
	var v_a := lc.get_vehicle(a_idx)
	# Simulate visual arrival.
	lc._on_arrived_at_bay(a_idx, v_a.bay_index)
	# Now undo.
	var undone := lc.undo()
	_expect(undone, "undo succeeded")
	var board_snap_after: Array = lc.get_board().snapshot()
	var bay_snap_after: Array = lc.get_bay_manager().snapshot()
	_expect(_boards_equal(board_snap_before, board_snap_after), "board restored after undo")
	_expect(_bays_equal(bay_snap_before, bay_snap_after), "bays restored after undo")
	_expect(lc.get_passenger_manager().active_index() == active_before, "active passenger index restored")
	lc.queue_free()

func _boards_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for y in a.size():
		var ra: Array = a[y]
		var rb: Array = b[y]
		if ra.size() != rb.size():
			return false
		for x in ra.size():
			if String(ra[x]) != String(rb[x]):
				return false
	return true

func _bays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var da: Dictionary = a[i]
		var db: Dictionary = b[i]
		if int(da["state"]) != int(db["state"]):
			return false
		if String(da["vehicle_id"]) != String(db["vehicle_id"]):
			return false
	return true

func _test_bay_allocation() -> void:
	print("\n[bay] allocation determinism + double-reservation guard")
	var BM := preload("res://scripts/core/bay_manager.gd")
	var bm = BM.new()
	bm.setup(5)
	_expect(bm.reserve_for("X") == 0, "first reserve returns bay 0")
	_expect(bm.reserve_for("Y") == 1, "second reserve returns bay 1")
	_expect(bm.reserve_for("Z") == 2, "third reserve returns bay 2")
	bm.confirm_occupancy(0)
	bm.release(0)
	_expect(bm.find_free_bay() == 0, "released bay becomes free again")
	# Fresh state for extra-bay test.
	bm = BM.new()
	bm.setup(5)
	bm.unlock_extra_bay()
	_expect(bm.bay_count() == 6, "extra bay unlocks 6th")
	# Fill all 5 original bays so the next reserve must use bay 5.
	for i in 5:
		bm.reserve_for("bus_%d" % i)
	var sixth := bm.reserve_for("Q")
	_expect(sixth == 5, "sixth reserve returns bay 5 when originals full")
	bm.reset_extra_bay()
	_expect(bm.bay_count() == 5, "extra bay reset returns to 5")

func _make_controller():
	var LC := preload("res://scripts/core/level_controller.gd")
	var lc = LC.new()
	var factory := Level1Factory.new()
	var lvl := factory.build()
	lc.load_level(lvl)
	return lc

func _test_full_game_flow() -> void:
	print("\n[full game flow] verified 12-move WIN sequence")
	var lc = _make_controller()
	_expect(lc.is_playing(), "starts in PLAYING")
	_expect(lc.vehicle_count() == 12, "12 vehicles loaded")
	var moves := ["A", "D", "L", "B", "C", "E", "F", "G", "H", "J", "I", "K"]
	for vid in moves:
		var vi: int = lc.get_vehicle_index_by_id(vid)
		_expect(vi >= 0, "vehicle %s exists" % vid)
		var ok: bool = lc.tap_vehicle(vi)
		_expect(ok, "tap %s" % vid)
		var bay: int = lc.get_bay_manager().get_bay_for(vid)
		lc._on_arrived_at_bay(vi, bay)
	_expect(lc.get_passenger_manager().all_completed(), "all 48 passengers served")
	_expect(lc.game_state == lc.GameState.WIN, "game_state == WIN")

func _test_restart() -> void:
	print("\n[restart] restores fresh state and undo round-trip")
	var lc = _make_controller()
	# Tap A, simulate arrival+boarding, then restart.
	var vi: int = lc.get_vehicle_index_by_id("A")
	lc.tap_vehicle(vi)
	var bay: int = lc.get_bay_manager().get_bay_for("A")
	lc._on_arrived_at_bay(vi, bay)
	_expect(lc.get_passenger_manager().active_index() == 4, "blue group served after A")
	lc.restart()
	_expect(lc.game_state == lc.GameState.PLAYING, "game back to PLAYING")
	_expect(lc.vehicle_count() == 12, "12 vehicles restored")
	_expect(lc.get_passenger_manager().active_index() == 0, "passenger queue reset")
	# Now tap A, then undo.
	lc.tap_vehicle(vi)
	bay = lc.get_bay_manager().get_bay_for("A")
	lc._on_arrived_at_bay(vi, bay)
	var undone: bool = lc.undo()
	_expect(undone, "undo returns true")
	_expect(lc.get_passenger_manager().active_index() == 0, "queue restored after undo")
	# Vehicle A is back on board.
	_expect(lc.get_vehicle(vi).bay_index == -1, "A off bay after undo")

func _test_extra_bay_runtime() -> void:
	print("\n[extra bay] runtime activation")
	var lc = _make_controller()
	var ok: bool = lc.unlock_extra_bay()
	_expect(ok, "extra bay unlocks")
	_expect(lc.get_bay_manager().bay_count() == 6, "6 bays total")
	lc.reset_extra_bay()
	_expect(lc.get_bay_manager().bay_count() == 5, "reset returns to 5 bays")

func _test_no_double_reservation() -> void:
	print("\n[no double reservation] simultaneous reservations get unique bays")
	var lc = _make_controller()
	var bm = lc.get_bay_manager()
	var r0 = bm.reserve_for("bus0")
	var r1 = bm.reserve_for("bus1")
	var r2 = bm.reserve_for("bus2")
	var r3 = bm.reserve_for("bus3")
	var r4 = bm.reserve_for("bus4")
	var r5 = bm.reserve_for("bus5")
	_expect(r0 == 0 and r1 == 1 and r2 == 2 and r3 == 3 and r4 == 4, "5 reservations get bays 0-4")
	_expect(r5 == -1, "6th reservation refused")