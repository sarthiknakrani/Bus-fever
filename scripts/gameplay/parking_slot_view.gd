extends Node2D
class_name ParkingSlotView

var slot_id: int = 0
var slot_state: int = CarJamParkingManager.SlotState.EMPTY

const SLOT_WIDTH: float = 72.0
const SLOT_HEIGHT: float = 120.0

func setup(id: int) -> void:
	slot_id = id
	name = "Slot_%d" % id
	queue_redraw()

func set_state(p_state: int) -> void:
	slot_state = p_state
	queue_redraw()

func _draw() -> void:
	var is_vip = (slot_id == 0)
	var is_locked = (slot_id >= 4)
	
	var rect = Rect2(-SLOT_WIDTH/2.0, -SLOT_HEIGHT/2.0, SLOT_WIDTH, SLOT_HEIGHT)
	
	# Draw Asphalt Base
	var asphalt = StyleBoxFlat.new()
	asphalt.bg_color = Color("475569") # Slate grey asphalt
	asphalt.set_corner_radius_all(12)
	draw_style_box(asphalt, rect)

	# Draw border lines
	var border_color = Color.WHITE
	if is_vip:
		border_color = Color("fbbf24") # VIP Yellow
	elif is_locked:
		border_color = Color(1, 1, 1, 0.4) # Faded white for locked

	if is_locked:
		# Fake dashed line by drawing multiple small lines or a faded box
		var dashed_box = StyleBoxFlat.new()
		dashed_box.bg_color = Color.TRANSPARENT
		dashed_box.border_color = border_color
		dashed_box.border_width_left = 3
		dashed_box.border_width_right = 3
		dashed_box.border_width_top = 3
		dashed_box.border_width_bottom = 3
		dashed_box.set_corner_radius_all(12)
		draw_style_box(dashed_box, rect.grow(-4))
	else:
		var solid_box = StyleBoxFlat.new()
		solid_box.bg_color = Color.TRANSPARENT
		solid_box.border_color = border_color
		solid_box.border_width_left = 4
		solid_box.border_width_right = 4
		solid_box.border_width_top = 4
		solid_box.border_width_bottom = 4
		solid_box.set_corner_radius_all(12)
		draw_style_box(solid_box, rect.grow(-4))

	# Icons
	if is_vip and slot_state == CarJamParkingManager.SlotState.EMPTY:
		# Draw Crown/VIP text
		draw_string(ThemeDB.fallback_font, Vector2(-16, 12), "VIP", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, border_color)
		# Crown poly
		var crown_c = Vector2(0, -12)
		draw_colored_polygon(PackedVector2Array([crown_c+Vector2(-12,-6), crown_c+Vector2(-6,2), crown_c+Vector2(0,-10), crown_c+Vector2(6,2), crown_c+Vector2(12,-6), crown_c+Vector2(8,6), crown_c+Vector2(-8,6)]), border_color)
	
	if is_locked and slot_state == CarJamParkingManager.SlotState.EMPTY:
		# Lock Icon
		var lock_c = border_color
		draw_rect(Rect2(-8, 0, 16, 12), lock_c, true)
		draw_polyline(PackedVector2Array([Vector2(-4, 0), Vector2(-4, -6), Vector2(4, -6), Vector2(4, 0)]), lock_c, 3.0, true)
