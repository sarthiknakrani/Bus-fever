extends Node2D
class_name VehicleView

signal tapped(vehicle_id: int)

var vehicle_id: int = -1
var vehicle_code: String = "A"
var vehicle_color: Color = Color("3b82f6")
var vehicle_color_id: String = "blue"
var vehicle_dir: int = 0
var vehicle_capacity: int = 4
var vehicle_footprint: Array[Vector2i] = [Vector2i.ZERO]
var passenger_occupancy: int = 0
var is_in_parking: bool = false

const CELL_SIZE: float = 78.0

# Canonical short bus dimensions (proportional without distortion)
const CANONICAL_BODY_LENGTH: float = 102.0
const CANONICAL_BODY_WIDTH_V: float = 48.0
const CANONICAL_BODY_WIDTH_H: float = 46.0
const CANONICAL_CANVAS_WIDTH: float = 62.0
const CANONICAL_CANVAS_HEIGHT: float = 110.0

# Authoritative visual scale factor (~15% reduction across all short buses in parking)
const BUS_VISUAL_SCALE: float = 0.85

# Board bus cell-fit parameters (tightens spacing on board to compact 7.6px gap matching reference)
# BOARD_BUS_TARGET_WIDTH is the target visible body WIDTH in board-local px.
# At 68.0 px, adjacent parallel buses leave 7.6-8.0 px on-screen clearance without intersecting.
# BOARD_ANCHOR_SHIFT is 0.0 to prevent cross-cluster divergence and frontal overlaps.
const BOARD_BUS_TARGET_WIDTH: float = 68.0
const BOARD_ANCHOR_SHIFT: float = 0.0

var board_scale_factor: float = 1.0
var board_anchor_offset: Vector2 = Vector2.ZERO

# Rendered target dimensions across board, transit and parking
const RENDERED_BODY_LENGTH: float = CANONICAL_BODY_LENGTH * BUS_VISUAL_SCALE # 86.7
const RENDERED_BODY_WIDTH_V: float = CANONICAL_BODY_WIDTH_V * BUS_VISUAL_SCALE # 40.8
const RENDERED_BODY_WIDTH_H: float = CANONICAL_BODY_WIDTH_H * BUS_VISUAL_SCALE # 39.1
const RENDERED_CANVAS_WIDTH: float = CANONICAL_CANVAS_WIDTH * BUS_VISUAL_SCALE # 52.7
const RENDERED_CANVAS_HEIGHT: float = CANONICAL_CANVAS_HEIGHT * BUS_VISUAL_SCALE # 93.5

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
	vehicle_color_id = p_col_id.to_lower()
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
		if in_parking:
			_badge_node.global_rotation = 0.0
	if in_parking and _base_sprite != null:
		_base_sprite.position = Vector2.ZERO
		_base_sprite.scale = Vector2.ONE

func _process(_delta: float) -> void:
	if _badge_node != null and _badge_node.visible:
		_badge_node.global_rotation = 0.0
		if is_in_parking:
			_badge_node.global_position = global_position + Vector2(0.0, 38.0)

func _build_visuals() -> void:
	# Clear existing interim visuals
	for c in get_children():
		if c is NinePatchRect or c is Sprite2D:
			c.queue_free()
	_wheels.clear()
	
	# Determine Asset properties: Only approved short bus artwork is used throughout the game
	var length_str = "short"
		
	var dir_str = "down"
	if vehicle_dir == CarJamVehicleData.Direction.UP: dir_str = "up"
	elif vehicle_dir == CarJamVehicleData.Direction.LEFT: dir_str = "left"
	elif vehicle_dir == CarJamVehicleData.Direction.RIGHT: dir_str = "right"
	
	# Centralized 7-color mapping with graceful fallback
	var valid_colors := ["red", "blue", "yellow", "orange", "green", "purple", "pink"]
	var col_str := "red"
	if vehicle_color_id in valid_colors:
		col_str = vehicle_color_id
	else:
		for c in valid_colors:
			if vehicle_color.is_equal_approx(CarJamVehicleData.color_to_rgb(c)):
				col_str = c
				break
	
	var tex_paths := [
		"res://assets/sprites/premium_buses/bus_short_%s_%s.png" % [col_str, dir_str],
		"res://assets/buses/short_%s_%s.png" % [col_str, dir_str],
		"res://assets/buses/%s_%s.png" % [col_str, dir_str]
	]
	
	var tex_bus: Texture2D = null
	for p in tex_paths:
		tex_bus = _load_interim_sprite(p)
		if tex_bus != null:
			break
	
	_base_sprite = Sprite2D.new()
	_base_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if tex_bus:
		_base_sprite.texture = tex_bus
	else:
		push_warning("VehicleView: Missing bus texture for %s %s %s" % [length_str, col_str, dir_str])
	
	# Add base sprite and apply tightened board cell-fitting and leading-edge anchor shift
	add_child(_base_sprite)
	_apply_bus_cell_fit()
	
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

## Computes uniform scale so the bus visible body occupies ~74px of the 78px cell
## (leaves ~4px gap between parallel neighbors) and anchors the bus front towards
## the leading edge along its escape direction.
## Uses the canonical visible body width (not the canvas dimension, which includes
## ~7px of transparent padding on each side) to avoid undersizing the bus on board.
func _apply_bus_cell_fit() -> void:
	if _base_sprite == null or _base_sprite.texture == null:
		return
	board_scale_factor = BOARD_BUS_TARGET_WIDTH / CANONICAL_BODY_WIDTH_V
	_base_sprite.scale = Vector2(board_scale_factor, board_scale_factor)

	# Keep bus centered in its cell without anchor distortion
	var dir_vec := Vector2(CarJamVehicleData.dir_to_vector(vehicle_dir))
	board_anchor_offset = dir_vec * BOARD_ANCHOR_SHIFT
	_base_sprite.position = board_anchor_offset


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
	if _base_sprite != null:
		col_shape.position = _base_sprite.position
	_touch_area.add_child(col_shape)
	_touch_area.input_event.connect(_on_touch_input)
	add_child(_touch_area)

var is_dispatched: bool = false

func _on_touch_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_dispatched or is_in_parking:
		return
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

func play_angry_shake() -> void:
	var orig_pos := position
	var tw := create_tween()
	# Two extra-strong horizontal shakes (10px, 0.18s each, EASE_BACK)
	tw.tween_property(self, "position", orig_pos + Vector2(10.0, 0), 0.045).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", orig_pos - Vector2(10.0, 0), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", orig_pos, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", orig_pos + Vector2(10.0, 0), 0.045).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", orig_pos - Vector2(10.0, 0), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", orig_pos, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func play_badge_pulse() -> void:
	if _badge_node != null:
		var tw := create_tween()
		tw.tween_property(_badge_node, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_badge_node, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _setup_capacity_badge() -> void:
	if _badge_node != null: return
	
	# Bottom-anchored capacity pill at the rear bumper of the parked bus (matching reference '40' badge).
	_badge_node = Node2D.new()
	_badge_node.name = "CapacityBadge"
	_badge_node.position = Vector2(0, 42.0)
	_badge_node.visible = false
	_badge_node.z_index = 10

	var badge_draw := Node2D.new()
	badge_draw.draw.connect(func():
		var bw: float = 38.0
		var bh: float = 22.0
		var rect := Rect2(-bw / 2.0, -bh / 2.0, bw, bh)
		var ci = badge_draw.get_canvas_item()

		var sb_shadow = StyleBoxFlat.new()
		sb_shadow.bg_color = Color(0, 0, 0, 0.35)
		sb_shadow.set_corner_radius_all(7)
		sb_shadow.draw(ci, Rect2(-bw / 2.0, -bh / 2.0 + 3, bw, bh))
		
		var sb_face = StyleBoxFlat.new()
		sb_face.bg_color = vehicle_color
		sb_face.set_corner_radius_all(7)
		sb_face.draw(ci, rect)
	)
	_badge_node.add_child(badge_draw)

	_badge_label = Label.new()
	_badge_label.text = str(vehicle_capacity)
	_badge_label.add_theme_font_size_override("font_size", 15)
	_badge_label.add_theme_color_override("font_color", Color.WHITE)
	_badge_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_badge_label.add_theme_constant_override("shadow_offset_x", 0)
	_badge_label.add_theme_constant_override("shadow_offset_y", 2)
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.position = Vector2(-19, -11)
	_badge_label.size = Vector2(38, 22)
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

## Returns the unscaled pixel dimensions of the bus when rotated into parking (facing UP)
func get_unscaled_parked_size() -> Vector2:
	if _base_sprite != null and _base_sprite.texture != null:
		var tex_sz := _base_sprite.texture.get_size()
		# When parked vertical UP:
		# LEFT / RIGHT buses are rotated 90 degrees, so width is tex_sz.y, length is tex_sz.x
		if vehicle_dir == CarJamVehicleData.Direction.LEFT or vehicle_dir == CarJamVehicleData.Direction.RIGHT:
			return Vector2(tex_sz.y, tex_sz.x)
		else:
			return Vector2(tex_sz.x, tex_sz.y)
	
	# Authoritative canonical short bus parked dimensions matching parking slot (62x110)
	return Vector2(CANONICAL_CANVAS_WIDTH, CANONICAL_CANVAS_HEIGHT)

## Returns the rendered pixel dimensions of the bus when rotated into parking (facing UP) at BUS_VISUAL_SCALE
func get_rendered_parked_size() -> Vector2:
	return get_unscaled_parked_size() * BUS_VISUAL_SCALE
