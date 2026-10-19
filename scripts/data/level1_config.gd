extends Resource
class_name Level1Config

## Level 1 Authoritative Reference Specification (1080 x 1920 Reference)
## Contains exact layout zones, parking bays, bus grid coordinates & headings,
## and passenger batch arrays matching the game specification.

# --- SCREEN PROPORTIONS (1080 x 1920) ---
@export_group("Layout Zones")
@export var reference_size := Vector2(1080.0, 1920.0)

# Zone 1: Passenger Queue & Track (Y: 0.00 – 0.37 / 0 – 710 px)
@export var zone1_track_y_min: float = 0.00
@export var zone1_track_y_max: float = 0.37
@export var track_width: float = 860.0
@export var track_height: float = 420.0

# Zone 2: Parking / Boarding Dock (Y: 0.37 – 0.51 / 710 – 980 px)
@export var zone2_dock_y_min: float = 0.37
@export var zone2_dock_y_max: float = 0.51
@export var dock_highway_y: float = 0.43 # Centerline of parking highway
@export var dock_highway_height: float = 270.0
@export var departure_lane_y: float = 0.49 # Down-right departure road

# Zone 3: Bus Puzzle Lot (Y: 0.51 – 1.00 / 980 – 1920 px)
@export var zone3_lot_y_min: float = 0.51
@export var zone3_lot_y_max: float = 1.00

# --- PARKING SLOTS CONFIGURATION ---
@export_group("Parking Bays")
@export var bay_tilt_deg: float = -28.0
@export var bay_width: float = 95.0
@export var bay_height: float = 165.0
@export var bay_spacing: float = 105.0 # Center-to-center spacing
@export var bay_x_start: float = 0.14  # Slot 0 center X
@export var bay_x_end: float = 0.88    # Slot 7 center X
@export var total_slots_count: int = 8

# Slot 0: Leftmost VIP bay (yellow border, ignored by standard tap pathing)
# Slots 1-6: 6 active standard bays (white borders)
# Slot 7: Rightmost unused/locked bay
@export var standard_slot_start: int = 1
@export var standard_slot_end: int = 6

# --- BUS SPECIFICATIONS (6 BUSES, CAPACITY 40 EACH) ---
@export_group("Bus Grid")
@export var lot_bus_size := Vector2(110.0, 220.0)
@export var parked_bus_scale: float = 0.85 # Tween scale down to 0.85x in slot
@export var bus_capacity: int = 40

# Bus definitions: id, color_id, normalized position (x, y), heading degrees (0 deg is -Y/up: -60 deg is ↖, +30 deg is ↗)
@export var buses_data: Array[Dictionary] = [
	{
		"id": 1,
		"color": "blue",
		"pos": Vector2(0.70, 0.64), # (756, 1229 px)
		"heading": -60.0,           # ↖ Up-Left
		"expected_tap_order": 1,
		"target_slot": 1,
		"desc": "Blue Bus 1 - Unblocked"
	},
	{
		"id": 2,
		"color": "yellow",
		"pos": Vector2(0.68, 0.72), # (734, 1382 px)
		"heading": 30.0,            # ↗ Up-Right
		"expected_tap_order": 2,
		"target_slot": 2,
		"desc": "Yellow Bus 1 - Unblocked"
	},
	{
		"id": 3,
		"color": "yellow",
		"pos": Vector2(0.57, 0.69), # (616, 1325 px)
		"heading": 30.0,            # ↗ Up-Right
		"expected_tap_order": 3,
		"target_slot": 3,
		"desc": "Yellow Bus 2 - Blocked by Bus 1"
	},
	{
		"id": 4,
		"color": "blue",
		"pos": Vector2(0.25, 0.71), # (270, 1363 px)
		"heading": 30.0,            # ↗ Up-Right
		"expected_tap_order": 4,
		"target_slot": 4,
		"desc": "Blue Bus 2 - Unblocked"
	},
	{
		"id": 5,
		"color": "red",
		"pos": Vector2(0.41, 0.74), # (443, 1421 px)
		"heading": -60.0,           # ↖ Up-Left
		"expected_tap_order": 5,
		"target_slot": 5,
		"desc": "Red Bus 1 - Blocked by Bus 4"
	},
	{
		"id": 6,
		"color": "red",
		"pos": Vector2(0.36, 0.79), # (389, 1517 px)
		"heading": -60.0,           # ↖ Up-Left
		"expected_tap_order": 6,
		"target_slot": 6,
		"desc": "Red Bus 2 - Blocked by Bus 4"
	}
]

# --- PASSENGER BATCH DATA (240 PASSENGERS = 60 ROWS OF 4) ---
@export_group("Passenger Queue Batches")
@export var row_stride: float = 26.0 # target_dist(i) = i * 26.0 px
@export var queue_speed: float = 220.0
@export var spawn_interval: float = 0.035 # Runner dispatch cadence
@export var passenger_sprite_size := Vector2(38.0, 38.0)
@export var lane_spacing: float = 28.0

# 7 Batches from front (Row 0 at Gate) to back (Row 59 on Feeder Ramp):
# Total = 9 + 7 + 10 + 9 + 1 + 13 + 11 = 60 rows = 240 passengers
@export var passenger_batches: Array[Dictionary] = [
	{
		"batch_id": 1,
		"color": "blue",
		"rows": 9,
		"passengers": 36,
		"desc": "Boards Blue Bus 1 (Slot 1), drops counter 40 -> 4"
	},
	{
		"batch_id": 2,
		"color": "red",
		"rows": 7,
		"passengers": 28,
		"desc": "Boards Red Bus 1 (Slot 5), drops counter 40 -> 12"
	},
	{
		"batch_id": 3,
		"color": "blue",
		"rows": 10,
		"passengers": 40,
		"desc": "First 4 fill Blue Bus 1 (4 -> 0, departs); next 36 board Blue Bus 2 (Slot 4) (40 -> 4)"
	},
	{
		"batch_id": 4,
		"color": "yellow",
		"rows": 9,
		"passengers": 36,
		"desc": "Boards Yellow Bus 1 (Slot 2), drops counter 40 -> 4"
	},
	{
		"batch_id": 5,
		"color": "blue",
		"rows": 1,
		"passengers": 4,
		"desc": "Fills remaining 4 seats of Blue Bus 2 (Slot 4) (4 -> 0, departs)"
	},
	{
		"batch_id": 6,
		"color": "red",
		"rows": 13,
		"passengers": 52,
		"desc": "First 12 fill Red Bus 1 (12 -> 0, departs); next 40 fill Red Bus 2 (Slot 6) (40 -> 0, departs)"
	},
	{
		"batch_id": 7,
		"color": "yellow",
		"rows": 11,
		"passengers": 44,
		"desc": "First 4 fill Yellow Bus 1 (4 -> 0, departs); next 40 fill Yellow Bus 2 (Slot 3) (40 -> 0, departs)"
	}
]

# --- 1D CLOCKWISE (↻) SPLINE KEYPOINTS ---
@export_group("1D Clockwise Spline Waypoints")
# Traced backward from the exit gate: dist = 0.0 is the exit gate.
# Decreasing a row's distance toward 0.0 moves passengers strictly clockwise (↻).
@export var spline_normalized_points: Array[Vector2] = [
	Vector2(0.53, 0.31), # Point 0 (dist = 0 px): Exit Gate
	Vector2(0.72, 0.27), # Point 1: Bottom-Right Curve
	Vector2(0.74, 0.14), # Point 2: Top-Right Merge / Curve
	Vector2(0.50, 0.12), # Point 3: Top-Center Straight
	Vector2(0.23, 0.15), # Point 4: Top-Left Curve
	Vector2(0.23, 0.28), # Point 5: Bottom-Left Curve
	Vector2(0.45, 0.31), # Point 6: Bottom-Center (Left of Gate)
	Vector2(0.72, 0.27), # Point 7: Bottom-Right Curve (Full loop back)
	Vector2(0.74, 0.14), # Point 8: Top-Right Merge
	Vector2(0.82, 0.15), # Point 9: Feeder Ramp Entrance
	Vector2(0.96, 0.02)  # Point 10: Feeder Ramp Tail (top-right offscreen)
]

func get_total_passengers() -> int:
	var total := 0
	for b in passenger_batches:
		total += int(b["passengers"])
	return total

func get_total_rows() -> int:
	var total := 0
	for b in passenger_batches:
		total += int(b["rows"])
	return total

func generate_full_row_sequence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var row_idx := 0
	var p_id := 0
	for b in passenger_batches:
		var c: String = b["color"]
		var num_rows: int = b["rows"]
		for r in num_rows:
			var pass_list: Array[Dictionary] = []
			for lane in 4:
				pass_list.append({
					"id": p_id,
					"color_id": c,
					"lane": lane,
					"state": "QUEUED"
				})
				p_id += 1
			result.append({
				"row_id": row_idx,
				"color_id": c,
				"passengers": pass_list
			})
			row_idx += 1
	return result
