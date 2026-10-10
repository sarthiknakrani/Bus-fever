extends Node2D
class_name ParkingSlotView

var slot_id: int = 0
var slot_state: int = CarJamParkingManager.SlotState.EMPTY

const SLOT_WIDTH: float = 62.0
const SLOT_HEIGHT: float = 110.0

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
	_draw_node = Node2D.new()
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw_lines)
	
	_vip_label = Label.new()
	_vip_label.text = "VIP"
	_vip_label.add_theme_font_size_override("font_size", 16)
	_vip_label.add_theme_color_override("font_color", Color("fbbf24"))
	_vip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vip_label.position = Vector2(-SLOT_WIDTH/2.0, 15)
	_vip_label.size = Vector2(SLOT_WIDTH, 30)
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
	
	# Approved blue-grey UI styling
	var border_color = Color("e2e8f0")
	var inner_color = Color("94a3b8") 
	
	if is_vip:
		border_color = Color("fde68a")
		inner_color = Color("d97706")
	elif is_locked:
		border_color = Color("94a3b8", 0.6)
		inner_color = Color("64748b", 0.5)
		
	var w = SLOT_WIDTH
	var h = SLOT_HEIGHT
	var hw = w/2.0
	var hh = h/2.0
	
	# Raised Outer Border
	var sb_outer = StyleBoxFlat.new()
	sb_outer.bg_color = border_color
	sb_outer.set_corner_radius_all(12)
	sb_outer.shadow_color = Color(0, 0, 0, 0.25)
	sb_outer.shadow_size = 4
	sb_outer.shadow_offset = Vector2(0, 4)
	sb_outer.draw(_draw_node.get_canvas_item(), Rect2(-hw, -hh, w, h))
	
	# Recessed Inner Parking Surface
	var sb_inner = StyleBoxFlat.new()
	sb_inner.bg_color = inner_color
	sb_inner.set_corner_radius_all(8)
	sb_inner.border_width_top = 4
	sb_inner.border_width_left = 2
	sb_inner.border_color = Color(0, 0, 0, 0.15) # Inner shadow effect
	sb_inner.draw(_draw_node.get_canvas_item(), Rect2(-hw + 6, -hh + 6, w - 12, h - 12))
	
	if is_locked:
		var lock_c = Color("e2e8f0", 0.8)
		# Padlock body
		_draw_node.draw_rect(Rect2(-8, -2, 16, 12), lock_c, true)
		# Padlock hoop
		var sb_hoop = StyleBoxFlat.new()
		sb_hoop.bg_color = Color.TRANSPARENT
		sb_hoop.border_color = lock_c
		sb_hoop.border_width_left = 3
		sb_hoop.border_width_right = 3
		sb_hoop.border_width_top = 3
		sb_hoop.set_corner_radius_all(6)
		sb_hoop.draw(_draw_node.get_canvas_item(), Rect2(-6, -10, 12, 10))

