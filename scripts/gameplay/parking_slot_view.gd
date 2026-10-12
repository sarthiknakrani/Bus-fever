extends Node2D
class_name ParkingSlotView

var slot_id: int = 0
var slot_state: int = CarJamParkingManager.SlotState.EMPTY

const SLOT_WIDTH: float = 53.0
const SLOT_HEIGHT: float = 94.0

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
	_vip_label.add_theme_font_size_override("font_size", 14)
	_vip_label.add_theme_color_override("font_color", Color("fbbf24"))
	_vip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vip_label.position = Vector2(-SLOT_WIDTH / 2.0, 12)
	_vip_label.size = Vector2(SLOT_WIDTH, 26)
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
	var is_reserved = (slot_state == CarJamParkingManager.SlotState.RESERVED)
	var is_occupied = (slot_state == CarJamParkingManager.SlotState.OCCUPIED)
	var is_departing = (slot_state == CarJamParkingManager.SlotState.DEPARTING)

	# Approved blue-grey UI styling — visual contract:
	#   FREE       → light blue-grey border, neutral inner (looks "available")
	#   RESERVED   → bright sky-blue border, darker blue inner (looks "claimed by incoming bus")
	#   OCCUPIED   → green/teal border, dark green inner (looks "in use — bus is parked")
	#   DEPARTING  → amber/warning border, dark amber inner (looks "unavailable, bus leaving")
	#   LOCKED     → muted grey with padlock (looks "inaccessible")
	#
	# The DEPARTING state is intentionally distinct from FREE so the player never
	# mistakes a slot that's emptying out for one they can immediately reuse.
	var border_color = Color("e2e8f0")
	var inner_color = Color("94a3b8")

	if is_vip:
		border_color = Color("fde68a")
		inner_color = Color("d97706")
	elif is_locked:
		border_color = Color("94a3b8", 0.6)
		inner_color = Color("64748b", 0.5)
	elif is_departing:
		# Distinguish from FREE: warmer/amber, never mistaken for available.
		border_color = Color("fbbf24")
		inner_color = Color("b45309", 0.85)
	elif is_occupied:
		border_color = Color("10b981")
		inner_color = Color("047857", 0.85)
	elif is_reserved:
		border_color = Color("38bdf8")
		inner_color = Color("0284c7", 0.75)

	var w = SLOT_WIDTH
	var h = SLOT_HEIGHT
	var hw = w / 2.0
	var hh = h / 2.0

	# Raised Outer Border
	var sb_outer = StyleBoxFlat.new()
	sb_outer.bg_color = border_color
	sb_outer.set_corner_radius_all(10)
	sb_outer.shadow_color = Color(0, 0, 0, 0.25)
	sb_outer.shadow_size = 3
	sb_outer.shadow_offset = Vector2(0, 3)
	sb_outer.draw(_draw_node.get_canvas_item(), Rect2(-hw, -hh, w, h))

	# Recessed Inner Parking Surface
	var sb_inner = StyleBoxFlat.new()
	sb_inner.bg_color = inner_color
	sb_inner.set_corner_radius_all(7)
	sb_inner.border_width_top = 3
	sb_inner.border_width_left = 2
	sb_inner.border_color = Color(0, 0, 0, 0.15) # Inner shadow effect
	sb_inner.draw(_draw_node.get_canvas_item(), Rect2(-hw + 5, -hh + 5, w - 10, h - 10))

	if is_locked:
		var lock_c = Color("e2e8f0", 0.8)
		# Padlock body
		_draw_node.draw_rect(Rect2(-7, -2, 14, 10), lock_c, true)
		# Padlock hoop
		var sb_hoop = StyleBoxFlat.new()
		sb_hoop.bg_color = Color.TRANSPARENT
		sb_hoop.border_color = lock_c
		sb_hoop.border_width_left = 2
		sb_hoop.border_width_right = 2
		sb_hoop.border_width_top = 2
		sb_hoop.set_corner_radius_all(5)
		sb_hoop.draw(_draw_node.get_canvas_item(), Rect2(-5, -8, 10, 8))

	if is_departing:
		# Draw a small diagonal hatch so the slot reads as "in transition",
		# not as the same neutral grey-blue that means FREE.
		var hatch_c: Color = Color("fef3c7", 0.9)
		var hatch_step: float = 7.0
		var x0: float = -hw + 5.0
		var y0: float = -hh + 5.0
		var x1: float = x0 + (w - 10.0)
		var y1: float = y0 + (h - 10.0)
		# Diagonal lines from top-left to bottom-right of inner rect.
		var start_x: float = x0 - (y1 - y0)
		while start_x < x1:
			var sx: float = start_x
			var ex: float = start_x + (y1 - y0)
			# Clip inside the inner rect.
			var cax: float = max(sx, x0)
			var cbx: float = min(ex, x1)
			if cax < cbx:
				# Map back: y = (x - sx) since slope is 1
				var cay: float = max(y0, (cax - sx) + y0)
				var cby: float = min(y1, (cbx - sx) + y0)
				_draw_node.draw_line(Vector2(cax, cay), Vector2(cbx, cby), hatch_c, 1.2)
			start_x += hatch_step

