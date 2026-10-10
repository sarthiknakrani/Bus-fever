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

# Sprite nodes for modular art replacement
var _shadow_sprite: Sprite2D
var _base_sprite: Sprite2D
var _roof_sprite: Sprite2D
var _glass_sprite: Sprite2D
var _arrow_sprite: Sprite2D
var _wheels: Array[Sprite2D] = []
var boarding_anchor: Marker2D
var boarding_layer: Node2D

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
	
	_build_visuals()

func _ready() -> void:
	_setup_touch_area()
	_setup_capacity_badge()
	process_mode = Node.PROCESS_MODE_INHERIT

func set_occupancy(occ: int) -> void:
	passenger_occupancy = occ
	if _badge_label != null:
		var rem := maxi(0, vehicle_capacity - passenger_occupancy)
		_badge_label.text = str(rem)

func set_parking_mode(in_parking: bool) -> void:
	is_in_parking = in_parking
	if _badge_node != null:
		_badge_node.visible = in_parking

func _build_visuals() -> void:
	# Clear existing interim visuals
	for c in get_children():
		if c is NinePatchRect or c is Sprite2D:
			c.queue_free()
	_wheels.clear()
	
	# Determine Premium Asset
	var length_str = "short"
	if vehicle_footprint.size() > 2:
		length_str = "long"
		
	var dir_str = "down"
	if vehicle_dir == CarJamVehicleData.Direction.UP: dir_str = "up"
	elif vehicle_dir == CarJamVehicleData.Direction.LEFT: dir_str = "left"
	elif vehicle_dir == CarJamVehicleData.Direction.RIGHT: dir_str = "right"
	
	var col_str = "red"
	if vehicle_color.is_equal_approx(CarJamVehicleData.color_to_rgb("blue")): col_str = "blue"
	elif vehicle_color.is_equal_approx(CarJamVehicleData.color_to_rgb("yellow")): col_str = "yellow"
	
	var tex_path = "res://assets/sprites/premium_buses/bus_%s_%s_%s.png" % [length_str, col_str, dir_str]
	var tex_bus = _load_interim_sprite(tex_path)
	
	_base_sprite = Sprite2D.new()
	if tex_bus:
		_base_sprite.texture = tex_bus
	
	# The asset is pre-scaled accurately to the WxH grid, we just center it.
	# The default Sprite2D is centered on its origin, which matches the node's center.
	add_child(_base_sprite)
	
	# Boarding Layer and Anchor
	if not boarding_layer:
		boarding_layer = Node2D.new()
		boarding_layer.name = "BoardingLayer"
	else:
		boarding_layer.get_parent().remove_child(boarding_layer)
	add_child(boarding_layer)
	
	if not boarding_anchor:
		boarding_anchor = Marker2D.new()
		boarding_anchor.name = "BoardingAnchor"
	else:
		boarding_anchor.get_parent().remove_child(boarding_anchor)
	boarding_layer.add_child(boarding_anchor)
	boarding_anchor.position = Vector2(0, 0)
func _setup_touch_area() -> void:
	if _touch_area != null: return
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

func _setup_capacity_badge() -> void:
	if _badge_node != null: return
	
	var arrow_draw := Node2D.new()
	arrow_draw.draw.connect(func():
		var ci = arrow_draw.get_canvas_item()
		var p1 = Vector2(0, -22)
		var p2 = Vector2(-12, -4)
		var p3 = Vector2(-4, -4)
		var p4 = Vector2(-4, 18)
		var p5 = Vector2(4, 18)
		var p6 = Vector2(4, -4)
		var p7 = Vector2(12, -4)
		var pts = PackedVector2Array([p1, p2, p3, p4, p5, p6, p7])
		var col = Color.WHITE
		# shadow
		var shadow_pts = PackedVector2Array()
		for p in pts:
			shadow_pts.append(p + Vector2(0, 4))
		arrow_draw.draw_polygon(shadow_pts, PackedColorArray([Color(0,0,0,0.4)]))
		arrow_draw.draw_polygon(pts, PackedColorArray([col]))
		
		# Add a thick, crisp outline so the white arrow is highly visible against yellow buses
		var outline_pts = PackedVector2Array([p1, p2, p3, p4, p5, p6, p7, p1])
		arrow_draw.draw_polyline(outline_pts, Color(0, 0, 0, 0.75), 3.0, true)
	)
	
	if vehicle_dir == CarJamVehicleData.Direction.UP:
		arrow_draw.rotation = 0
	elif vehicle_dir == CarJamVehicleData.Direction.DOWN:
		arrow_draw.rotation = PI
	elif vehicle_dir == CarJamVehicleData.Direction.LEFT:
		arrow_draw.rotation = -PI / 2.0
	elif vehicle_dir == CarJamVehicleData.Direction.RIGHT:
		arrow_draw.rotation = PI / 2.0
		
	# Add it to self, because there is no _v_root in the current vehicle_view.gd!
	add_child(arrow_draw)
	
	_badge_node = Node2D.new()
	_badge_node.name = "CapacityBadge"
	_badge_node.position = Vector2.ZERO # Centered perfectly on the geometric center of the bus footprint
	_badge_node.visible = false
	_badge_node.z_index = 10 

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

func _load_interim_sprite(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	# Fallback to direct image load if not imported
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null
