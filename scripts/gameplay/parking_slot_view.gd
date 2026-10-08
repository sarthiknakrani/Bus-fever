extends Node2D
class_name ParkingSlotView

## Visual representation of a single parking bay.
## Communicates EMPTY, RESERVED, and OCCUPIED states with clear color coding.

var slot_id: int = 0
var slot_state: int = CarJamParkingManager.SlotState.EMPTY

const SLOT_WIDTH: float = 64.0
const SLOT_HEIGHT: float = 88.0

func setup(id: int) -> void:
	slot_id = id
	name = "Slot_%d" % id
	queue_redraw()

func set_state(p_state: int) -> void:
	slot_state = p_state
	queue_redraw()

func _draw() -> void:
	var bg_col := Color("141c28", 0.0) # Transparent background
	var border_col := Color("9ca3af")
	var width := 2.0
	
	if slot_id == 0:
		border_col = Color("fbbf24") # VIP Yellow
	elif slot_id >= 4:
		border_col = Color("4ade80") # Locked Green

	match slot_state:
		CarJamParkingManager.SlotState.RESERVED:
			border_col = Color("38bdf8") # Blue glow
			width = 3.0
		CarJamParkingManager.SlotState.OCCUPIED:
			border_col = Color("ffffff")
			width = 3.0
		CarJamParkingManager.SlotState.RELEASING:
			border_col = Color("f59e0b")
			width = 3.0

	var shear := 12.0
	var p1 = Vector2(-SLOT_WIDTH / 2.0 + shear, -SLOT_HEIGHT / 2.0)
	var p2 = Vector2(SLOT_WIDTH / 2.0 + shear, -SLOT_HEIGHT / 2.0)
	var p3 = Vector2(SLOT_WIDTH / 2.0 - shear, SLOT_HEIGHT / 2.0)
	var p4 = Vector2(-SLOT_WIDTH / 2.0 - shear, SLOT_HEIGHT / 2.0)

	var pts = PackedVector2Array([p1, p2, p3, p4, p1])
	
	# Bay floor (optional, but reference is mostly transparent outline)
	draw_colored_polygon(pts, Color(0,0,0,0.1))
	
	# Outline
	draw_polyline(pts, border_col, width, true)
	
	# VIP or Plus Text
	if slot_id == 0 and slot_state == CarJamParkingManager.SlotState.EMPTY:
		# VIP text rotated inside
		var tr = Transform2D()
		tr = tr.rotated(deg_to_rad(-15))
		tr.origin = Vector2(5, 5)
		draw_set_transform_matrix(tr)
		draw_string(ThemeDB.fallback_font, Vector2(-12, 5), "VIP", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("fbbf24"))
		draw_set_transform_matrix(Transform2D())
	elif slot_id >= 4 and slot_state == CarJamParkingManager.SlotState.EMPTY:
		draw_string(ThemeDB.fallback_font, Vector2(-6, 5), "+", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color("4ade80"))