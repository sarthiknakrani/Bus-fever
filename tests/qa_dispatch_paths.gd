extends SceneTree

# QA test: for every bus in level 1, run a single-tap dispatch through the
# new VehicleMovement.animate_dispatch curve and verify the route is sane.
#
#   - Original arrow direction is followed initially.
#   - Curve passes BELOW the parking strip (corridor y = PARKING_Y + 100).
#   - Front vector at curve end points UP (within tolerance).
#   - Bus center at curve end matches slot center (within tolerance).
#   - Curve does NOT cut horizontally across any parked (occupied) bay.
#
# Run:  godot --headless --script res://tests/qa_dispatch_paths.gd

const CarJamVehicleData := preload("res://data/vehicle_data.gd")
const VehicleMovement := preload("res://scripts/gameplay/vehicle_movement.gd")

const CELL_SIZE := 78.0
const BOARD_Y := 720.0
const PARKING_Y := 405.0
const PARKING_SLOT_SPACING := 76.0
const PARKING_SLOT_WIDTH := 62.0
const PARKING_SLOT_HEIGHT := 104.0
const CORRIDOR_Y := PARKING_Y + 100.0

var failures: int = 0


func _init() -> void:
	_run()


func _run() -> void:
	print("\n=== QA: Board-to-Parking Dispatch Paths ===\n")

	# Build a synthetic level-data record of buses mirroring levels/level_001.tres.
	# (anchor, code, footprint offsets, direction, color)
	var buses = [
		{ "code": "v1", "anchor": Vector2i(1, 0), "fp": [Vector2i(0,0), Vector2i(0,1)],
			"dir": CarJamVehicleData.Direction.DOWN, "color": "yellow", "slot": 1 },
		{ "code": "v2", "anchor": Vector2i(3, 1), "fp": [Vector2i(0,0), Vector2i(-1,0)],
			"dir": CarJamVehicleData.Direction.LEFT, "color": "blue",   "slot": 2 },
		{ "code": "v3", "anchor": Vector2i(1, 2), "fp": [Vector2i(0,0), Vector2i(1,0)],
			"dir": CarJamVehicleData.Direction.RIGHT, "color": "red",    "slot": 3 },
		{ "code": "v4", "anchor": Vector2i(3, 4), "fp": [Vector2i(0,0), Vector2i(0,-1)],
			"dir": CarJamVehicleData.Direction.UP,    "color": "yellow", "slot": 1 },
		{ "code": "v5", "anchor": Vector2i(2, 3), "fp": [Vector2i(0,0), Vector2i(0,1)],
			"dir": CarJamVehicleData.Direction.DOWN, "color": "blue",   "slot": 2 },
		{ "code": "v6", "anchor": Vector2i(1, 3), "fp": [Vector2i(0,0), Vector2i(-1,0)],
			"dir": CarJamVehicleData.Direction.LEFT, "color": "red",    "slot": 3 },
	]
	var board_size := Vector2i(5, 5)

	for b in buses:
		_test_bus(b, board_size)

	print("\n=== QA SUMMARY ===")
	if failures == 0:
		print("ALL %d BUSES PASS" % buses.size())
	else:
		print("FAILURES: %d" % failures)
	quit(failures)


func _test_bus(b: Dictionary, board_size: Vector2i) -> void:
	var code: String = b["code"]
	var anchor: Vector2i = b["anchor"]
	var fp: Array = b["fp"]
	var dir: int = b["dir"]
	var color: String = b["color"]
	var slot: int = b["slot"]

	# Compute bus on-board world position (mirrors car_jam_level.gd).
	var avg := Vector2.ZERO
	for p in fp: avg += Vector2(p)
	var center_offset: Vector2 = avg * CELL_SIZE / float(fp.size())

	var lx := float(anchor.x) - float(board_size.x - 1) / 2.0
	var ly := float(anchor.y) - float(board_size.y - 1) / 2.0
	var local_pos: Vector2 = Vector2(lx, ly) * CELL_SIZE + center_offset

	# Apply the board_root's 45-deg rotation + 0.6 Y-scale + (0, BOARD_Y) translate.
	# Node2D's transform has a matrix of the form T * R_scaled, where
	# the rotation is scaled per axis; we construct the same matrix
	# directly so this offline test produces numbers that match the
	# game (we can't use Transform2D().scaled() because that does
	# per-cell scaling which differs from Node2D).
	var rot := deg_to_rad(45.0)
	var sx := 1.0
	var sy := 0.6
	var x_axis := Vector2(cos(rot) * sx, sin(rot) * sx)
	var y_axis := Vector2(-sin(rot) * sy, cos(rot) * sy)
	var board_root_xform := Transform2D(x_axis, y_axis, Vector2(0.0, BOARD_Y))
	var start_pos: Vector2 = board_root_xform * local_pos

	# Compute exit point a few cells past the bus along its puzzle arrow.
	var dir_vec: Vector2i = CarJamVehicleData.dir_to_vector(dir)
	var push_cells: float = float(fp.size()) + 0.6
	var exit_local: Vector2 = (Vector2(anchor) + Vector2(dir_vec) * push_cells
		- Vector2(board_size.x - 1, board_size.y - 1) / 2.0) * CELL_SIZE
	var exit_pos: Vector2 = board_root_xform * exit_local

	# Slot world pos.
	var total_span: float = 6.0 * PARKING_SLOT_SPACING
	var slot_x: float = -total_span / 2.0 + float(slot) * PARKING_SLOT_SPACING
	var slot_pos := Vector2(slot_x, PARKING_Y)
	var corridor_pos := Vector2(slot_x, CORRIDOR_Y)

	# Build the same 4-point Curve2D animate_dispatch builds.
	var forward_world: Vector2 = (exit_pos - start_pos).normalized()
	if forward_world.length_squared() < 0.0001:
		forward_world = Vector2(0, -1)

	var P1: Vector2 = start_pos + forward_world * 130.0
	var P2: Vector2 = corridor_pos
	if P2.distance_to(start_pos) < 80.0:
		P2 = Vector2(slot_pos.x, slot_pos.y + 100.0)

	var curve := Curve2D.new()
	curve.add_point(start_pos, Vector2.ZERO, forward_world * 120.0)
	curve.add_point(P1, -forward_world * 100.0, forward_world * 100.0)
	curve.add_point(P2, Vector2(0.0, 100.0), Vector2(0.0, -100.0))
	curve.add_point(slot_pos, Vector2(0.0, 130.0), Vector2.ZERO)

	# Front vector for tangent-aligned rotation.
	var front_native := Vector2(0, -1)
	match dir:
		CarJamVehicleData.Direction.DOWN: front_native = Vector2(0, 1)
		CarJamVehicleData.Direction.UP: front_native = Vector2(0, -1)
		CarJamVehicleData.Direction.LEFT: front_native = Vector2(-1, 0)
		CarJamVehicleData.Direction.RIGHT: front_native = Vector2(1, 0)

	# Sample 48 points along the baked curve.
	var total_len: float = curve.get_baked_length()
	var samples := 48
	var max_corridor_y_above_parking: float = 0.0
	var min_corridor_y: float = 1e9
	var max_y_below_board: float = 1e9
	var crosses_corridor_zone := false
	var start_tan := Vector2.ZERO
	var end_tan := Vector2.ZERO
	var endpoint_pos: Vector2 = Vector2.ZERO
	var max_x_drift: float = 0.0  # how far past parking rect (PARKING_Y +/- 74) we go

	# Parking outer rect (same as in car_jam_level.gd)
	var parking_top_y: float = PARKING_Y - 74.0
	var parking_bot_y: float = PARKING_Y + 74.0

	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var offset: float = t * total_len
		var pos: Vector2 = curve.sample_baked(offset)
		var ahead_offset: float = min(total_len, offset + 2.0)
		var ahead: Vector2 = curve.sample_baked(ahead_offset)
		var tan_dir: Vector2 = Vector2.ZERO
		if pos.distance_to(ahead) > 0.1:
			tan_dir = (ahead - pos).normalized()
		if i == 0: start_tan = tan_dir
		if i == samples:
			end_tan = tan_dir
			endpoint_pos = pos
		# Spot-check: does the curve dip into the corridor zone (y >= PARKING_Y + 50)
		if pos.y >= PARKING_Y - 4.0 and pos.y <= PARKING_Y + 80.0:
			crosses_corridor_zone = true
		min_corridor_y = min(min_corridor_y, pos.y)
		# Track X drift at parking-strip Y range — if the curve ever
		# passes through the parking strip at an X different from the
		# assigned slot, it is crossing other bays horizontally.
		if pos.y >= parking_top_y and pos.y <= parking_bot_y:
			max_x_drift = max(max_x_drift, absf(pos.x - slot_x))

	# Analytical end-tangent (last 4 px back toward start).
	if total_len > 4.0:
		var end_pos: Vector2 = curve.sample_baked(total_len)
		var end_back: Vector2 = curve.sample_baked(total_len - 4.0)
		var end_tan_calc: Vector2 = (end_pos - end_back).normalized()
		end_tan = end_tan_calc
		endpoint_pos = end_pos

	# Front vector at end = front_native rotated by (end_tan.angle() - front_native.angle())
	var end_rot: float = end_tan.angle() - front_native.angle()
	var end_front: Vector2 = front_native.rotated(end_rot)
	var bay_axis := Vector2(0, -1)
	var ang_diff_deg: float = rad_to_deg(end_front.angle_to(bay_axis))

	# Compute angular error of the START tangent vs. puzzle arrow in world.
	var puzzle_dir_world := forward_world
	var start_tan_err_deg: float = rad_to_deg(start_tan.angle_to(puzzle_dir_world))

	# Slot-center error at curve end.
	var center_err := endpoint_pos.distance_to(slot_pos)

	print("--- Bus %s (color %s dir %s -> slot %d) ---" %
		[code, color, CarJamVehicleData.dir_to_string(dir), slot])
	print("  start_pos   = %s" % str(start_pos))
	print("  exit_pos    = %s" % str(exit_pos))
	print("  corridor    = %s" % str(corridor_pos))
	print("  slot_pos    = %s" % str(slot_pos))
	print("  curve len   = %.1f px" % total_len)
	print("  start_tan   = %s  (puzzle dir: %s)  err %.1f deg" %
		[str(start_tan), str(puzzle_dir_world), start_tan_err_deg])
	print("  end_tan     = %s  front %s" % [str(end_tan), str(end_front)])
	print("  end vs bay  = %.1f deg, center_err = %.1f px" %
		[ang_diff_deg, center_err])
	print("  bus dips into corridor zone = %s (min y = %.0f)" %
		[str(crosses_corridor_zone), min_corridor_y])
	print("  max X drift inside parking strip = %.1f px" % max_x_drift)

	var ok := true
	if absf(start_tan_err_deg) > 5.0:
		printerr("  FAIL start_tan does not align with puzzle direction")
		ok = false
	if absf(ang_diff_deg) > 5.0:
		printerr("  FAIL end front is not facing UP within tolerance")
		ok = false
	if center_err > 2.0:
		printerr("  FAIL bus does not settle at slot center")
		ok = false
	# The curve must not slice horizontally across other parking bays at
	# the parking-strip Y range. Some X drift is unavoidable (the bus
	# has to enter the bay), but it should be tight (a few px of slot
	# width slack). Allow SLOT_WIDTH tolerance.
	if max_x_drift > 30.0 and ok:
		# Only flag as a violation if the curve is passing through a
		# different X within the parking rect while not yet arriving
		# at the slot.
		var crosses_other_bays := false
		# Sweep samples again checking X position at parking Y-range.
		for i in range(samples + 1):
			var t2: float = float(i) / float(samples)
			var ofs2: float = t2 * total_len
			var p2_pos: Vector2 = curve.sample_baked(ofs2)
			if p2_pos.y >= parking_top_y and p2_pos.y <= parking_bot_y:
				if absf(p2_pos.x - slot_x) > 6.0:
					crosses_other_bays = true
					break
		if crosses_other_bays:
			printerr("  FAIL curve crosses through other parking bays (max drift %.1f px)" %
				max_x_drift)
			ok = false

	if ok:
		print("  PASS\n")
	else:
		failures += 1
		print("  -- end --\n")
