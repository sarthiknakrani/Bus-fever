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
	style_glass.bg_color = Color("93c5fd")
	style_glass.set_corner_radius_all(8)
	
	draw_style_box(style_base, rect)
	
	var glass_rect = rect.grow(-4)
	draw_style_box(style_glass, glass_rect)
	
	var roof_rect = rect.grow(-12)
	roof_rect.position.y -= 4
	draw_style_box(style_roof, roof_rect)
	
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

func _setup_capacity_badge() -> void:
	_badge_node = Node2D.new()
	_badge_node.name = "CapacityBadge"
	_badge_node.position = Vector2(0, CELL_SIZE * 0.6)
	_badge_node.visible = false

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
