import re

code = """extends Node2D
class_name VehicleView

var vehicle_id: int = 0
var vehicle_color: Color = Color.WHITE
var vehicle_footprint: Array[Vector2i] = []
var vehicle_dir: int = 0
var vehicle_capacity: int = 4
var passenger_occupancy: int = 0
var is_parking: bool = false

const CELL_SIZE: float = 78.0

func setup(v_model: VehicleModel) -> void:
	vehicle_id = v_model.id
	vehicle_color = CarJamVehicleData.color_to_rgb(v_model.color_id)
	vehicle_footprint = v_model.footprint
	vehicle_dir = v_model.direction
	vehicle_capacity = v_model.capacity
	queue_redraw()

func set_occupancy(occ: int) -> void:
	passenger_occupancy = occ
	queue_redraw()

func set_parking_mode(p: bool) -> void:
	is_parking = p
	queue_redraw()

func play_badge_pulse() -> void:
	var tw = create_tween()
	scale = Vector2(1.1, 1.1)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var cells_w: float = float(vehicle_footprint.size()) if vehicle_dir == CarJamVehicleData.Direction.RIGHT or vehicle_dir == CarJamVehicleData.Direction.LEFT else 1.0
	var cells_h: float = float(vehicle_footprint.size()) if vehicle_dir == CarJamVehicleData.Direction.UP or vehicle_dir == CarJamVehicleData.Direction.DOWN else 1.0

	var pixel_w = cells_w * CELL_SIZE - 12.0
	var pixel_h = cells_h * CELL_SIZE - 12.0
	var rect = Rect2(-pixel_w/2.0, -pixel_h/2.0, pixel_w, pixel_h)
	
	var style_base = StyleBoxFlat.new()
	style_base.bg_color = vehicle_color.darkened(0.2)
	style_base.set_corner_radius_all(16)
	style_base.shadow_color = Color(0, 0, 0, 0.3)
	style_base.shadow_size = 8
	style_base.shadow_offset = Vector2(0, 8)
	
	var style_roof = StyleBoxFlat.new()
	style_roof.bg_color = vehicle_color
	style_roof.set_corner_radius_all(12)
	
	var style_glass = StyleBoxFlat.new()
	style_glass.bg_color = Color("93c5fd") # light blue glass
	style_glass.set_corner_radius_all(8)
	
	# Draw Base with shadow
	draw_style_box(style_base, rect)
	
	# Draw Glass (Windshields)
	var glass_rect = rect.grow(-4)
	draw_style_box(style_glass, glass_rect)
	
	# Draw Roof
	var roof_rect = rect.grow(-12)
	roof_rect.position.y -= 4 # fake perspective shift
	draw_style_box(style_roof, roof_rect)
	
	# Draw Directional Arrow on roof
	var center = roof_rect.get_center()
	var arr_size = 12.0
	var p1 = center
	var p2 = center
	var p3 = center
	
	if vehicle_dir == CarJamVehicleData.Direction.UP:
		p1 += Vector2(0, -arr_size)
		p2 += Vector2(-arr_size, arr_size)
		p3 += Vector2(arr_size, arr_size)
	elif vehicle_dir == CarJamVehicleData.Direction.DOWN:
		p1 += Vector2(0, arr_size)
		p2 += Vector2(-arr_size, -arr_size)
		p3 += Vector2(arr_size, -arr_size)
	elif vehicle_dir == CarJamVehicleData.Direction.LEFT:
		p1 += Vector2(-arr_size, 0)
		p2 += Vector2(arr_size, -arr_size)
		p3 += Vector2(arr_size, arr_size)
	elif vehicle_dir == CarJamVehicleData.Direction.RIGHT:
		p1 += Vector2(arr_size, 0)
		p2 += Vector2(-arr_size, -arr_size)
		p3 += Vector2(-arr_size, arr_size)
		
	var arr_pts = PackedVector2Array([p1, p2, p3])
	draw_colored_polygon(arr_pts, Color(1, 1, 1, 0.8))

	# Capacity Badge
	if is_parking:
		var rem = vehicle_capacity - passenger_occupancy
		if rem > 0:
			var badge = StyleBoxFlat.new()
			badge.bg_color = Color(1, 1, 1, 0.95)
			badge.set_corner_radius_all(14)
			badge.border_width_bottom = 2
			badge.border_color = Color(0.8, 0.8, 0.8)
			badge.shadow_color = Color(0, 0, 0, 0.2)
			badge.shadow_size = 4
			badge.shadow_offset = Vector2(0, 2)
			
			var b_rect = Rect2(center.x - 14, center.y - 14, 28, 28)
			draw_style_box(badge, b_rect)
			draw_string(ThemeDB.fallback_font, Vector2(center.x - 4, center.y + 6), str(rem), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, vehicle_color.darkened(0.4))
"""

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(code)

print("Replaced vehicle_view.gd with 2D style boxes")
