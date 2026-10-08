extends Node2D
class_name VehicleView

signal tapped(vehicle_id: int)

var vehicle_id: int = -1
var vehicle_code: String = "A"
var vehicle_color: Color = Color("3b82f6")
var vehicle_dir: int = 0
var vehicle_capacity: int = 4
var vehicle_footprint: Array[Vector2i] = [Vector2i.ZERO]
var passenger_occupancy: int = 0
var is_in_parking: bool = false

const CELL_SIZE: float = 78.0
var _badge_node: Node2D
var _badge_label: Label
var _touch_area: Area2D

func setup(p_id: int, p_code: String, p_col_id: String, p_dir: int, p_cap: int, p_footprint: Array[Vector2i] = [Vector2i.ZERO]) -> void:
	vehicle_id = p_id
	vehicle_code = p_code
	vehicle_color = CarJamVehicleData.color_to_rgb(p_col_id)
	vehicle_dir = p_dir
	vehicle_capacity = p_cap
	vehicle_footprint = p_footprint
	passenger_occupancy = 0
	is_in_parking = false
	name = "Vehicle_%s" % p_code
	queue_redraw()

func _ready() -> void:
	_setup_touch_area()
	_setup_capacity_badge()
	process_mode = Node.PROCESS_MODE_INHERIT

func set_occupancy(occ: int) -> void:
	passenger_occupancy = occ
	if _badge_label != null:
		var rem := maxi(0, vehicle_capacity - passenger_occupancy)
		_badge_label.text = str(rem)
	queue_redraw()

func set_parking_mode(in_parking: bool) -> void:
	is_in_parking = in_parking
	if _badge_node != null:
		_badge_node.visible = in_parking
	queue_redraw()

func _setup_touch_area() -> void:
	_touch_area = Area2D.new()
	_touch_area.name = "TouchArea"
	var col_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	
	var min_x = 0; var max_x = 0; var min_y = 0; var max_y = 0
	for p in vehicle_footprint:
		if p.x < min_x: min_x = p.x
		if p.x > max_x: max_x = p.x
		if p.y < min_y: min_y = p.y
		if p.y > max_y: max_y = p.y
	
	var cells_w = max_x - min_x + 1
	var cells_h = max_y - min_y + 1
	rect_shape.size = Vector2(cells_w * CELL_SIZE * 0.92, cells_h * CELL_SIZE * 0.92)
	
	col_shape.shape = rect_shape
	_touch_area.add_child(col_shape)
	_touch_area.input_event.connect(_on_touch_input)
	add_child(_touch_area)

func _on_touch_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.double_click:
			tapped.emit(vehicle_id)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not st.double_tap:
			tapped.emit(vehicle_id)

func play_blocked_shake() -> void:
	var nudge_vec := Vector2(CarJamVehicleData.dir_to_vector(vehicle_dir)) * 14.0
	var tw := create_tween()
	tw.tween_property(self, "position", position + nudge_vec, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", position, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func play_badge_pulse() -> void:
	if _badge_node != null:
		var tw := create_tween()
		tw.tween_property(_badge_node, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_badge_node, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _draw() -> void:
	var cells_w: float = float(vehicle_footprint.size()) if vehicle_dir == CarJamVehicleData.Direction.RIGHT or vehicle_dir == CarJamVehicleData.Direction.LEFT else 1.0
	var cells_h: float = float(vehicle_footprint.size()) if vehicle_dir == CarJamVehicleData.Direction.UP or vehicle_dir == CarJamVehicleData.Direction.DOWN else 1.0

	var pixel_w = cells_w * CELL_SIZE - 10.0
	var pixel_h = cells_h * CELL_SIZE - 10.0
	var rect = Rect2(-pixel_w/2.0, -pixel_h/2.0, pixel_w, pixel_h)
	
	# Premium 2D Art Layering
	
	# 1. Soft Ground Shadow
	var shadow_rect = rect
	shadow_rect.position.y += 6
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.35)
	shadow_style.set_corner_radius_all(16)
	shadow_style.shadow_color = Color(0, 0, 0, 0.2)
	shadow_style.shadow_size = 12
	draw_style_box(shadow_style, shadow_rect)
	
	# 2. Wheels
	var wheel_color = Color("1e293b")
	var wheel_w = 6.0
	var wheel_h = 16.0
	var wheel_inset_x = pixel_w / 2.0 - 4
	var wheel_inset_y = pixel_h / 2.0 - 18
	
	# Adjust wheels based on orientation so they are on the sides
	if cells_h > cells_w: # Vertical bus
		draw_rect(Rect2(-wheel_inset_x - wheel_w, -wheel_inset_y, wheel_w, wheel_h), wheel_color, true)
		draw_rect(Rect2(wheel_inset_x, -wheel_inset_y, wheel_w, wheel_h), wheel_color, true)
		draw_rect(Rect2(-wheel_inset_x - wheel_w, wheel_inset_y - wheel_h, wheel_w, wheel_h), wheel_color, true)
		draw_rect(Rect2(wheel_inset_x, wheel_inset_y - wheel_h, wheel_w, wheel_h), wheel_color, true)
	else: # Horizontal bus
		draw_rect(Rect2(-wheel_inset_x, -wheel_inset_y - wheel_w, wheel_h, wheel_w), wheel_color, true)
		draw_rect(Rect2(-wheel_inset_x, wheel_inset_y, wheel_h, wheel_w), wheel_color, true)
		draw_rect(Rect2(wheel_inset_x - wheel_h, -wheel_inset_y - wheel_w, wheel_h, wheel_w), wheel_color, true)
		draw_rect(Rect2(wheel_inset_x - wheel_h, wheel_inset_y, wheel_h, wheel_w), wheel_color, true)

	# 3. Side Body (Base)
	var body_style = StyleBoxFlat.new()
	body_style.bg_color = vehicle_color.darkened(0.2)
	body_style.set_corner_radius_all(16)
	body_style.border_width_bottom = 8
	body_style.border_color = vehicle_color.darkened(0.35)
	draw_style_box(body_style, rect)
	
	# 4. Windshields and Windows (Dark Glass)
	var glass_style = StyleBoxFlat.new()
	glass_style.bg_color = Color("0f172a") # Very dark blue/grey glass
	glass_style.set_corner_radius_all(8)
	var glass_rect = rect.grow(-4)
	draw_style_box(glass_style, glass_rect)
	
	# 5. Roof Layer
	var roof_rect = rect.grow(-10)
	roof_rect.position.y -= 8 # 3D depth shift
	var roof_style = StyleBoxFlat.new()
	roof_style.bg_color = vehicle_color
	roof_style.set_corner_radius_all(12)
	
	# Add glossy highlight to roof
	roof_style.border_width_top = 4
	roof_style.border_color = Color(1, 1, 1, 0.4)
	roof_style.border_blend = true
	draw_style_box(roof_style, roof_rect)
	
	# Roof details (AC unit / ridges)
	var detail_rect = roof_rect.grow(-8)
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = vehicle_color.lightened(0.15)
	detail_style.set_corner_radius_all(6)
	draw_style_box(detail_style, detail_rect)
	
	# 6. Directional Arrow
	var center = roof_rect.get_center()
	var arr_size = 14.0
	var p1 = center
	var p2 = center
	var p3 = center
	var arr_offset = 0.0
	
	if vehicle_dir == CarJamVehicleData.Direction.UP:
		p1 += Vector2(0, -arr_size + arr_offset)
		p2 += Vector2(-arr_size, arr_size + arr_offset)
		p3 += Vector2(arr_size, arr_size + arr_offset)
	elif vehicle_dir == CarJamVehicleData.Direction.DOWN:
		p1 += Vector2(0, arr_size + arr_offset)
		p2 += Vector2(-arr_size, -arr_size + arr_offset)
		p3 += Vector2(arr_size, -arr_size + arr_offset)
	elif vehicle_dir == CarJamVehicleData.Direction.LEFT:
		p1 += Vector2(-arr_size + arr_offset, 0)
		p2 += Vector2(arr_size + arr_offset, -arr_size)
		p3 += Vector2(arr_size + arr_offset, arr_size)
	elif vehicle_dir == CarJamVehicleData.Direction.RIGHT:
		p1 += Vector2(arr_size + arr_offset, 0)
		p2 += Vector2(-arr_size + arr_offset, -arr_size)
		p3 += Vector2(-arr_size + arr_offset, arr_size)
		
	var arr_pts = PackedVector2Array([p1, p2, p3])
	
	# Arrow shadow
	var arr_shadow = PackedVector2Array([p1 + Vector2(0, 2), p2 + Vector2(0, 2), p3 + Vector2(0, 2)])
	draw_colored_polygon(arr_shadow, Color(0, 0, 0, 0.2))
	
	# Arrow body
	draw_colored_polygon(arr_pts, Color.WHITE)

func _setup_capacity_badge() -> void:
	_badge_node = Node2D.new()
	_badge_node.name = "CapacityBadge"
	_badge_node.position = Vector2(0, CELL_SIZE * 0.7)
	_badge_node.visible = false
	_badge_node.z_index = 10 # Keep above overlapping cars

	var badge_draw := Node2D.new()
	badge_draw.draw.connect(func():
		var bw: float = 46.0
		var bh: float = 28.0
		var rect := Rect2(-bw / 2.0, -bh / 2.0, bw, bh)
		var ci = badge_draw.get_canvas_item()

		var sb_shadow = StyleBoxFlat.new()
		sb_shadow.bg_color = Color(0,0,0,0.5)
		sb_shadow.set_corner_radius_all(14)
		sb_shadow.draw(ci, Rect2(-bw/2.0, -bh/2.0 + 4, bw, bh))
		
		var sb_depth = StyleBoxFlat.new()
		sb_depth.bg_color = vehicle_color.darkened(0.5)
		sb_depth.set_corner_radius_all(14)
		sb_depth.draw(ci, Rect2(-bw/2.0, -bh/2.0 + 2, bw, bh))

		var sb_face = StyleBoxFlat.new()
		sb_face.bg_color = vehicle_color
		sb_face.set_corner_radius_all(14)
		sb_face.border_width_top = 2
		sb_face.border_color = Color.WHITE
		sb_face.draw(ci, rect)
	)
	_badge_node.add_child(badge_draw)

	_badge_label = Label.new()
	_badge_label.text = str(vehicle_capacity)
	_badge_label.add_theme_font_size_override("font_size", 18)
	_badge_label.add_theme_color_override("font_color", Color.WHITE)
	_badge_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_badge_label.add_theme_constant_override("shadow_offset_x", 0)
	_badge_label.add_theme_constant_override("shadow_offset_y", 2)
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.position = Vector2(-23, -14)
	_badge_label.size = Vector2(46, 28)
	_badge_node.add_child(_badge_label)

	add_child(_badge_node)
