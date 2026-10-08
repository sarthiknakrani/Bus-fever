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
var _shadow_sprite: NinePatchRect
var _base_sprite: NinePatchRect
var _roof_sprite: NinePatchRect
var _glass_sprite: NinePatchRect
var _arrow_sprite: Sprite2D
var _wheels: Array[Sprite2D] = []

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
	var cells_w: float = float(vehicle_footprint.size()) if vehicle_dir == CarJamVehicleData.Direction.RIGHT or vehicle_dir == CarJamVehicleData.Direction.LEFT else 1.0
	var cells_h: float = float(vehicle_footprint.size()) if vehicle_dir == CarJamVehicleData.Direction.UP or vehicle_dir == CarJamVehicleData.Direction.DOWN else 1.0

	var pixel_w = cells_w * CELL_SIZE - 10.0
	var pixel_h = cells_h * CELL_SIZE - 10.0
	
	var tex_body = _load_interim_sprite("res://assets/sprites/interim/bus_body.png")
	var tex_roof = _load_interim_sprite("res://assets/sprites/interim/bus_roof.png")
	var tex_glass = _load_interim_sprite("res://assets/sprites/interim/bus_window.png")
	var tex_wheel = _load_interim_sprite("res://assets/sprites/interim/bus_wheel.png")
	var tex_arrow = _load_interim_sprite("res://assets/sprites/interim/arrow.png")
	
	# Clear existing
	for c in get_children():
		if c is NinePatchRect or c is Sprite2D:
			c.queue_free()
	_wheels.clear()
	
	var create_np = func(tex, color, w, h, y_off):
		var np = NinePatchRect.new()
		if tex: np.texture = tex
		np.modulate = color
		np.patch_margin_left = 24
		np.patch_margin_right = 24
		np.patch_margin_top = 24
		np.patch_margin_bottom = 24
		np.size = Vector2(w, h)
		np.position = Vector2(-w/2.0, -h/2.0 + y_off)
		add_child(np)
		return np

	# 1. Shadow
	_shadow_sprite = create_np.call(tex_body, Color(0,0,0,0.3), pixel_w, pixel_h, 8)
	
	# 2. Wheels
	var wheel_w = 12.0
	var wheel_h = 24.0
	var wx = pixel_w/2.0 - 4
	var wy = pixel_h/2.0 - 20
	
	var w_pts = []
	if cells_h > cells_w: # Vertical
		w_pts = [Vector2(-wx, -wy), Vector2(wx, -wy), Vector2(-wx, wy), Vector2(wx, wy)]
	else:
		w_pts = [Vector2(-wy, -wx), Vector2(wy, -wx), Vector2(-wy, wx), Vector2(wy, wx)]
		
	for p in w_pts:
		var s = Sprite2D.new()
		if tex_wheel: s.texture = tex_wheel
		s.position = p
		if cells_w > cells_h: s.rotation = PI/2.0
		s.scale = Vector2(wheel_w / 32.0, wheel_h / 64.0)
		add_child(s)
		_wheels.append(s)
		
	# 3. Base Body
	_base_sprite = create_np.call(tex_body, vehicle_color.darkened(0.2), pixel_w, pixel_h, 0)
	
	# 4. Glass
	_glass_sprite = create_np.call(tex_glass, Color.WHITE, pixel_w - 8, pixel_h - 8, 0)
	_glass_sprite.patch_margin_left = 8
	_glass_sprite.patch_margin_top = 8
	_glass_sprite.patch_margin_right = 8
	_glass_sprite.patch_margin_bottom = 8
	
	# 5. Roof
	_roof_sprite = create_np.call(tex_roof, vehicle_color, pixel_w - 16, pixel_h - 16, -6)
	
	# 6. Arrow
	_arrow_sprite = Sprite2D.new()
	if tex_arrow: _arrow_sprite.texture = tex_arrow
	_arrow_sprite.position = Vector2(0, -6)
	_arrow_sprite.scale = Vector2(0.4, 0.4)
	if vehicle_dir == CarJamVehicleData.Direction.UP: _arrow_sprite.rotation = 0
	elif vehicle_dir == CarJamVehicleData.Direction.DOWN: _arrow_sprite.rotation = PI
	elif vehicle_dir == CarJamVehicleData.Direction.LEFT: _arrow_sprite.rotation = -PI/2.0
	elif vehicle_dir == CarJamVehicleData.Direction.RIGHT: _arrow_sprite.rotation = PI/2.0
	add_child(_arrow_sprite)

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
	_badge_node = Node2D.new()
	_badge_node.name = "CapacityBadge"
	_badge_node.position = Vector2(0, CELL_SIZE * 0.7)
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
