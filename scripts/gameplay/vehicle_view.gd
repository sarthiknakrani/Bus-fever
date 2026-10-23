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
var is_mystery: bool = false

const CELL_SIZE: float = 78.0

# Canonical short bus dimensions (proportional without distortion)
const CANONICAL_BODY_LENGTH: float = 102.0
const CANONICAL_BODY_WIDTH_V: float = 48.0
const CANONICAL_BODY_WIDTH_H: float = 46.0
const CANONICAL_CANVAS_WIDTH: float = 62.0
const CANONICAL_CANVAS_HEIGHT: float = 110.0

# Authoritative visual scale factor (~15% reduction across all short buses in parking)
const BUS_VISUAL_SCALE: float = 0.85

# Board bus cell-fit parameters (tightens spacing on board to compact 5.0px gap matching reference)
# BOARD_BUS_TARGET_WIDTH is the target visible body WIDTH in board-local px.
# At 50.0 px, adjacent parallel buses leave 4.7-5.3 px on-screen clearance with 0 overlaps across all levels.
# BOARD_ANCHOR_SHIFT is 0.0 to prevent cross-cluster divergence and frontal overlaps.
const BOARD_BUS_TARGET_WIDTH: float = 50.0
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

# Mystery "?" reveal UI: large centered "?" mark + dark scrim. Both fade out
# when the player taps the bus for the first time (handled by reveal_mystery()).
var _mystery_overlay: Label = null
var _mystery_scrim: ColorRect = null
var _mystery_reveal_tween: Tween = null
var _badge_tween: Tween = null
var _pop_tween: Tween = null
var _arrow_cover: ColorRect = null

# Sprite nodes for modular art replacement
var _shadow_sprite: Sprite2D
var _base_sprite: Sprite2D
var _roof_sprite: Sprite2D
var _glass_sprite: Sprite2D
var _arrow_sprite: Sprite2D
var _wheels: Array[Sprite2D] = []
var boarding_anchor: Marker2D
var boarding_layer: Node2D

func _update_mystery_visuals() -> void:
	if _mystery_overlay == null or _mystery_scrim == null:
		return
	_mystery_overlay.visible = is_mystery
	_mystery_scrim.visible = is_mystery

func setup(p_id: int, p_code: String, p_col_id: String, p_dir: int, p_cap: int, p_footprint: Array[Vector2i] = [Vector2i.ZERO], p_is_mystery: bool = false) -> void:
	vehicle_id = p_id
	vehicle_code = p_code
	vehicle_color_id = p_col_id.to_lower()
	vehicle_color = CarJamVehicleData.color_to_rgb(p_col_id)
	vehicle_dir = p_dir
	vehicle_capacity = p_cap
	vehicle_footprint = p_footprint
	passenger_occupancy = 0
	is_in_parking = false
	is_mystery = p_is_mystery
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
			_update_badge_transform()
	if in_parking and _base_sprite != null:
		_base_sprite.position = Vector2.ZERO
		_base_sprite.scale = Vector2.ONE

func _process(_delta: float) -> void:
	if _badge_node != null and _badge_node.visible:
		_update_badge_transform()

func _update_badge_transform() -> void:
	if _badge_node == null:
		return
	# In parking bay (-22 deg), rear of bus is along the longitudinal bay axis Vector2(0, 1).rotated(-22 deg).
	# Centering badge along this axis at rear bumper (+46px) with 0.0 global rotation ensures it sits
	# cleanly inside the bottom stencil break gap of its slot without protruding into neighbor bays.
	var rear_vec := Vector2(0.0, 1.0).rotated(deg_to_rad(-22.0))
	_badge_node.global_position = global_position + rear_vec * 46.0
	_badge_node.global_rotation = 0.0

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

func set_color(new_color_id: String) -> void:
	vehicle_color_id = new_color_id.to_lower()
	vehicle_color = CarJamVehicleData.color_to_rgb(new_color_id)
	var dir_str := "down"
	if vehicle_dir == CarJamVehicleData.Direction.UP: dir_str = "up"
	elif vehicle_dir == CarJamVehicleData.Direction.LEFT: dir_str = "left"
	elif vehicle_dir == CarJamVehicleData.Direction.RIGHT: dir_str = "right"
	var col_str := vehicle_color_id
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
	if _base_sprite != null and tex_bus != null:
		_base_sprite.texture = tex_bus
		_apply_bus_cell_fit()

func play_jumble_pop() -> void:
	var tw := create_tween()
	var orig_scale: Vector2 = scale
	tw.tween_property(self, "scale", orig_scale * Vector2(1.14, 1.14), 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", orig_scale, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
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

	# Mystery "?" overlay + scrim: shown while is_mystery, hidden permanently after reveal_mystery().
	if _mystery_overlay == null:
		_mystery_overlay = Label.new()
		_mystery_overlay.name = "MysteryBadge"
		_mystery_overlay.text = "?"
		_mystery_overlay.add_theme_font_size_override("font_size", 72)
		_mystery_overlay.add_theme_color_override("font_color", Color("fef3c7"))
		_mystery_overlay.add_theme_color_override("font_outline_color", Color("0f172a"))
		_mystery_overlay.add_theme_constant_override("outline_size", 8)
		_mystery_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mystery_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_mystery_overlay.position = Vector2(-40.0, -64.0)
		_mystery_overlay.size = Vector2(80.0, 128.0)
		_mystery_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _mystery_overlay.is_inside_tree():
		add_child(_mystery_overlay)

	if _mystery_scrim == null:
		_mystery_scrim = ColorRect.new()
		_mystery_scrim.name = "MysteryScrim"
		_mystery_scrim.color = Color(0.16, 0.18, 0.24, 0.78)
		_mystery_scrim.custom_minimum_size = Vector2(120.0, 200.0)
		_mystery_scrim.size = Vector2(120.0, 200.0)
		_mystery_scrim.position = Vector2(-60.0, -100.0)
		_mystery_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _mystery_scrim.is_inside_tree():
		add_child(_mystery_scrim)
	# Scrim sits under the bus sprite but above any background so it tints the body visibly.
	if _base_sprite != null:
		move_child(_mystery_scrim, _base_sprite.get_index() + 1)
		# Overlay always renders on top of scrim and bus sprite.
	if _mystery_overlay.is_inside_tree():
		move_child(_mystery_overlay, get_child_count() - 1)

	_update_mystery_visuals()

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

	# Keep touch area collision shape synchronized with sprite scale and offset
	if _touch_area != null and _touch_area.get_child_count() > 0:
		var cs = _touch_area.get_child(0) as CollisionShape2D
		if cs != null and cs.shape is RectangleShape2D:
			_update_touch_shape(cs.shape as RectangleShape2D, cs)

func _setup_touch_area() -> void:
	if _touch_area != null: return
	_touch_area = Area2D.new()
	_touch_area.name = "TouchArea"
	var col_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	
	_update_touch_shape(rect_shape, col_shape)
	
	col_shape.shape = rect_shape
	_touch_area.add_child(col_shape)
	_touch_area.input_event.connect(_on_touch_input)
	add_child(_touch_area)

func _update_touch_shape(rect_shape: RectangleShape2D, col_shape: CollisionShape2D) -> void:
	var is_vert: bool = (vehicle_dir == CarJamVehicleData.Direction.UP or
			vehicle_dir == CarJamVehicleData.Direction.DOWN)
	var body_w: float = (CANONICAL_BODY_WIDTH_V if is_vert else CANONICAL_BODY_LENGTH) * board_scale_factor
	var body_h: float = (CANONICAL_BODY_LENGTH if is_vert else CANONICAL_BODY_WIDTH_H) * board_scale_factor
	# Silhouette-matched hitbox with 0.95 factor guarantees tight containment inside rendered bus sprite,
	# completely eliminating hitbox protrusion and neighbor overlaps
	rect_shape.size = Vector2(body_w * 0.95, body_h * 0.95)
	if _base_sprite != null:
		col_shape.position = _base_sprite.position

var is_dispatched: bool = false
var _shake_tween: Tween
var _orig_board_pos: Vector2 = Vector2.ZERO
var _is_shaking: bool = false

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

## Smoothly lifts and lands the bus to its new board position during an Arrange move.
## Calls on_complete when the animation finishes (model is already updated by then).
func play_arrange_move(new_pos: Vector2, on_complete: Callable) -> void:
	var tw := create_tween()
	# Brief pause before lift
	tw.tween_interval(0.05)
	# Lift (scale up slightly) and move simultaneously
	tw.set_parallel(true)
	tw.tween_property(self, "scale", scale * Vector2(1.1, 1.1), 0.12)
	tw.tween_property(self, "position", new_pos, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.set_parallel(false)
	# Land (scale back to original)
	var orig_scale := scale
	tw.tween_property(self, "scale", orig_scale, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(on_complete)

var _highlight_tween: Tween = null

func play_blocker_highlight() -> void:
	if _highlight_tween != null and _highlight_tween.is_valid():
		_highlight_tween.kill()
	modulate = Color(1.35, 1.35, 1.35, 1.0)
	_highlight_tween = create_tween()
	_highlight_tween.tween_property(self, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func play_blocked_shake() -> void:
	if is_in_parking or is_dispatched:
		return
	if not _is_shaking:
		_orig_board_pos = position
		_is_shaking = true
	elif _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		position = _orig_board_pos

	var nudge_vec := Vector2(CarJamVehicleData.dir_to_vector(vehicle_dir)) * 14.0
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position", _orig_board_pos + nudge_vec, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_property(self, "position", _orig_board_pos, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_callback(func():
		position = _orig_board_pos
		_is_shaking = false
	)

func play_angry_shake() -> void:
	if not _is_shaking:
		_orig_board_pos = position
		_is_shaking = true
	elif _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		position = _orig_board_pos

	_shake_tween = create_tween()
	# Two extra-strong horizontal shakes (10px, 0.18s each, EASE_BACK)
	_shake_tween.tween_property(self, "position", _orig_board_pos + Vector2(10.0, 0), 0.045).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_property(self, "position", _orig_board_pos - Vector2(10.0, 0), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	_shake_tween.tween_property(self, "position", _orig_board_pos, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_property(self, "position", _orig_board_pos + Vector2(10.0, 0), 0.045).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_property(self, "position", _orig_board_pos - Vector2(10.0, 0), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	_shake_tween.tween_property(self, "position", _orig_board_pos, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_callback(func():
		position = _orig_board_pos
		_is_shaking = false
	)

func set_arrow_visible(p_vis: bool) -> void:
	if _arrow_sprite != null:
		_arrow_sprite.visible = p_vis
	if _arrow_cover != null:
		_arrow_cover.visible = false

## Called by the controller after a successful tap on a mystery bus. Animates the
## "?" overlay and dark scrim out, then flips is_mystery=false so the bus's true
## color is exposed. Safe to call from a non-mystery bus (no-op).
func reveal_mystery() -> void:
	if not is_mystery:
		return
	is_mystery = false
	if _mystery_reveal_tween != null and _mystery_reveal_tween.is_valid():
		_mystery_reveal_tween.kill()
	if _mystery_overlay != null and is_instance_valid(_mystery_overlay):
		_mystery_reveal_tween = create_tween()
		_mystery_reveal_tween.set_parallel(true)
		_mystery_reveal_tween.tween_property(_mystery_overlay, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_mystery_reveal_tween.tween_property(_mystery_scrim, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Pop the ? badge inward as it fades for a satisfying reveal moment.
		_mystery_reveal_tween.tween_property(_mystery_overlay, "scale", Vector2(0.4, 0.4), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_mystery_reveal_tween.tween_callback(_on_reveal_complete)

func _on_reveal_complete() -> void:
	if _mystery_overlay != null and is_instance_valid(_mystery_overlay):
		_mystery_overlay.visible = false
		_mystery_overlay.modulate.a = 1.0
		_mystery_overlay.scale = Vector2.ONE
	if _mystery_scrim != null and is_instance_valid(_mystery_scrim):
		_mystery_scrim.visible = false
		_mystery_scrim.modulate.a = 1.0
	_mystery_reveal_tween = null

func play_badge_pulse() -> void:
	if _badge_node != null:
		if _badge_tween != null and _badge_tween.is_valid():
			_badge_tween.kill()
		_badge_node.scale = Vector2.ONE
		_badge_tween = create_tween()
		_badge_tween.tween_property(_badge_node, "scale", Vector2(1.15, 1.15), 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_badge_tween.tween_property(_badge_node, "scale", Vector2(1.0, 1.0), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func play_boarding_pop() -> void:
	play_badge_pulse()
	if _base_sprite != null:
		if _pop_tween != null and _pop_tween.is_valid():
			_pop_tween.kill()
		_base_sprite.scale = Vector2(1.06, 1.06)
		_pop_tween = create_tween()
		_pop_tween.tween_property(_base_sprite, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _setup_capacity_badge() -> void:
	if _badge_node != null: return
	
	# Compact claymorphism pill badge matching bus color, styled with crisp white border and bold white text
	# Sized (40 x 24 px) to fit comfortably within the 48px slot without colliding with neighbor slots
	_badge_node = Node2D.new()
	_badge_node.name = "CapacityBadge"
	_badge_node.position = Vector2(0, 46.0)
	_badge_node.visible = false
	_badge_node.z_index = 10

	var badge_draw := Node2D.new()
	badge_draw.draw.connect(func():
		var bw: float = 40.0
		var bh: float = 24.0
		var rect := Rect2(-bw / 2.0, -bh / 2.0, bw, bh)
		var ci = badge_draw.get_canvas_item()

		var sb_shadow = StyleBoxFlat.new()
		sb_shadow.bg_color = Color(0, 0, 0, 0.35)
		sb_shadow.set_corner_radius_all(8)
		sb_shadow.draw(ci, Rect2(-bw / 2.0, -bh / 2.0 + 2.0, bw, bh))
		
		var sb_face = StyleBoxFlat.new()
		sb_face.bg_color = vehicle_color
		sb_face.set_corner_radius_all(8)
		sb_face.border_width_left = 2
		sb_face.border_width_top = 2
		sb_face.border_width_right = 2
		sb_face.border_width_bottom = 2
		sb_face.border_color = Color.WHITE
		sb_face.draw(ci, rect)
	)
	_badge_node.add_child(badge_draw)

	_badge_label = Label.new()
	_badge_label.text = str(vehicle_capacity)
	_badge_label.add_theme_font_size_override("font_size", 16)
	_badge_label.add_theme_color_override("font_color", Color.WHITE)
	_badge_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_badge_label.add_theme_constant_override("shadow_offset_x", 0)
	_badge_label.add_theme_constant_override("shadow_offset_y", 1)
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.position = Vector2(-20.0, -12.0)
	_badge_label.size = Vector2(40.0, 24.0)
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
