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
const DEPTH: float = 14.0 # 3D extrusion wall thickness

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
	
	# Approximate bounds for the click area
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
	
	var tile_w = 80.0
	var tile_h = 46.0
	var height = 35.0
	var margin = 0.15 # 15% margin
	
	# Compute logical corners in local grid space (centered at 0,0)
	var hw = cells_w / 2.0 - margin
	var hh = cells_h / 2.0 - margin
	
	# Helper to convert local grid coords to local isometric coords
	var to_iso = func(lx: float, ly: float) -> Vector2:
		return Vector2((lx - ly) * (tile_w / 2.0), (lx + ly) * (tile_h / 2.0))
	
	# The 4 corners on the ground
	# 0: top, 1: right, 2: bottom, 3: left in grid space
	var g0 = to_iso.call(-hw, -hh)
	var g1 = to_iso.call(hw, -hh)
	var g2 = to_iso.call(hw, hh)
	var g3 = to_iso.call(-hw, hh)
	
	# Shift up for 3D roof
	var up = Vector2(0, -height)
	var r0 = g0 + up
	var r1 = g1 + up
	var r2 = g2 + up
	var r3 = g3 + up
	
	var c_top = vehicle_color.lightened(0.15)
	var c_left = vehicle_color
	var c_right = vehicle_color.darkened(0.25)
	
	# Draw Left Face (g3, g2, r2, r3)
	draw_colored_polygon(PackedVector2Array([g3, g2, r2, r3]), c_left)
	
	# Draw Right Face (g2, g1, r1, r2)
	draw_colored_polygon(PackedVector2Array([g2, g1, r1, r2]), c_right)
	
	# Draw Top Face (r0, r1, r2, r3)
	draw_colored_polygon(PackedVector2Array([r0, r1, r2, r3]), c_top)
	
	# Outline for pop
	var oc = Color(0,0,0, 0.4)
	draw_line(r0, r1, oc, 2.0)
	draw_line(r1, r2, oc, 2.0)
	draw_line(r2, r3, oc, 2.0)
	draw_line(r3, r0, oc, 2.0)
	draw_line(g2, r2, oc, 2.0)
	draw_line(g3, r3, oc, 2.0)
	draw_line(g1, r1, oc, 2.0)
	
	# Draw directional arrow on top face
	var arrow_dir = Vector2.ZERO
	if vehicle_dir == CarJamVehicleData.Direction.UP:
		arrow_dir = Vector2(0, -1)
	elif vehicle_dir == CarJamVehicleData.Direction.DOWN:
		arrow_dir = Vector2(0, 1)
	elif vehicle_dir == CarJamVehicleData.Direction.LEFT:
		arrow_dir = Vector2(-1, 0)
	elif vehicle_dir == CarJamVehicleData.Direction.RIGHT:
		arrow_dir = Vector2(1, 0)
		
	# Center of roof
	var roof_center = (r0 + r2) / 2.0
	
	# Compute arrow tip in grid space, then project
	var arrow_len = 0.35
	var arrow_tip_g = arrow_dir * arrow_len
	var arrow_back_g = -arrow_dir * (arrow_len * 0.5)
	var arrow_left_g = arrow_back_g + Vector2(arrow_dir.y, -arrow_dir.x) * 0.2
	var arrow_right_g = arrow_back_g + Vector2(-arrow_dir.y, arrow_dir.x) * 0.2
	
	var a_tip = roof_center + to_iso.call(arrow_tip_g.x, arrow_tip_g.y)
	var a_left = roof_center + to_iso.call(arrow_left_g.x, arrow_left_g.y)
	var a_right = roof_center + to_iso.call(arrow_right_g.x, arrow_right_g.y)
	
	draw_colored_polygon(PackedVector2Array([a_tip, a_right, a_left]), Color(1,1,1,0.8))
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
