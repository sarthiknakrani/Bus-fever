extends Node2D
class_name ParkingSlotView

var slot_id: int = 0
var slot_state: int = CarJamParkingManager.SlotState.EMPTY

const SLOT_WIDTH: float = 72.0
const SLOT_HEIGHT: float = 120.0

var _bay_sprite: NinePatchRect
var _vip_label: Label
var _draw_node: Node2D

func setup(id: int) -> void:
	slot_id = id
	name = "Slot_%d" % id
	
	_build_visuals()

func set_state(p_state: int) -> void:
	slot_state = p_state
	_update_visual_state()

func _build_visuals() -> void:
	var tex_bay = _load_interim_sprite("res://assets/sprites/interim/parking_bay.png")
	
	_bay_sprite = NinePatchRect.new()
	if tex_bay: _bay_sprite.texture = tex_bay
	_bay_sprite.modulate = Color("334155") # Dark Asphalt
	_bay_sprite.patch_margin_left = 16
	_bay_sprite.patch_margin_right = 16
	_bay_sprite.patch_margin_top = 16
	_bay_sprite.patch_margin_bottom = 16
	_bay_sprite.size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
	_bay_sprite.position = Vector2(-SLOT_WIDTH/2.0, -SLOT_HEIGHT/2.0)
	add_child(_bay_sprite)
	
	_draw_node = Node2D.new()
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw_lines)
	
	_vip_label = Label.new()
	_vip_label.text = "VIP"
	_vip_label.add_theme_font_size_override("font_size", 22)
	_vip_label.add_theme_color_override("font_color", Color("fbbf24"))
	_vip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vip_label.position = Vector2(-36, 12)
	_vip_label.size = Vector2(72, 30)
	_vip_label.visible = false
	add_child(_vip_label)

	_update_visual_state()

func _update_visual_state() -> void:
	var is_vip = (slot_id == 0)
	if slot_state == CarJamParkingManager.SlotState.EMPTY:
		_vip_label.visible = is_vip
	else:
		_vip_label.visible = false
	_draw_node.queue_redraw()

func _on_draw_lines() -> void:
	var is_vip = (slot_id == 0)
	var is_locked = (slot_id >= 4)
	var border_color = Color.WHITE
	
	if is_vip:
		border_color = Color("fbbf24")
	elif is_locked:
		border_color = Color(1, 1, 1, 0.4)
		
	var rect = Rect2(-SLOT_WIDTH/2.0 + 3, -SLOT_HEIGHT/2.0 + 3, SLOT_WIDTH - 6, SLOT_HEIGHT - 6)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_color = border_color
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(12)
	
	if is_locked:
		# Draw lock icon
		var lock_c = border_color
		_draw_node.draw_rect(Rect2(-8, 0, 16, 12), lock_c, true)
		_draw_node.draw_polyline(PackedVector2Array([Vector2(-4, 0), Vector2(-4, -6), Vector2(4, -6), Vector2(4, 0)]), lock_c, 3.0, true)
		# Fake dashed effect by drawing thick transparent over it?
		# Or just stick to solid faded white as locked indicator
		
	sb.draw(_draw_node.get_canvas_item(), rect)

func _load_interim_sprite(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	# Fallback to direct image load if not imported
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null
