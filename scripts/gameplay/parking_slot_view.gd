extends Node2D
class_name ParkingSlotView

var slot_id: int = 0
var slot_state: int = CarJamParkingManager.SlotState.EMPTY

const SLOT_WIDTH: float = 46.0
const SLOT_HEIGHT: float = 88.0

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
	_vip_label.add_theme_font_size_override("font_size", 13)
	_vip_label.add_theme_color_override("font_color", Color("facc15"))
	_vip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vip_label.position = Vector2(-SLOT_WIDTH / 2.0, -13.0)
	_vip_label.size = Vector2(SLOT_WIDTH, 26.0)
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
	var is_reserved = (slot_state == CarJamParkingManager.SlotState.RESERVED)
	var is_departing = (slot_state == CarJamParkingManager.SlotState.DEPARTING)

	var w = SLOT_WIDTH
	var h = SLOT_HEIGHT
	var hw = w / 2.0
	var hh = h / 2.0
	var r: float = 6.0

	# 1. Flat recessed asphalt bay polygon (Color("585967") fill, corner_radius = 6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("585967")
	sb.set_corner_radius_all(int(r))
	sb.draw(_draw_node.get_canvas_item(), Rect2(-hw, -hh, w, h))

	# 2. Crisp 2.0px painted stencil outline around the bay with a 10px break gap at bottom edge center
	var outline_color: Color = Color("facc15") if is_vip else Color("d8dee9")
	if is_departing:
		outline_color = Color("fbbf24")

	var stencil_pts := PackedVector2Array()
	# Start at bottom right of the 10px break gap
	stencil_pts.append(Vector2(5.0, hh))
	stencil_pts.append(Vector2(hw - r, hh))

	# Bottom-right corner arc (from PI/2 to 0)
	var c_br := Vector2(hw - r, hh - r)
	for k in range(1, 5):
		var ang: float = PI / 2.0 - (float(k) / 4.0) * (PI / 2.0)
		stencil_pts.append(c_br + Vector2(cos(ang), sin(ang)) * r)

	# Right edge to top-right corner
	stencil_pts.append(Vector2(hw, -hh + r))
	var c_tr := Vector2(hw - r, -hh + r)
	for k in range(1, 5):
		var ang: float = 0.0 - (float(k) / 4.0) * (PI / 2.0)
		stencil_pts.append(c_tr + Vector2(cos(ang), sin(ang)) * r)

	# Top edge to top-left corner
	stencil_pts.append(Vector2(-hw + r, -hh))
	var c_tl := Vector2(-hw + r, -hh + r)
	for k in range(1, 5):
		var ang: float = -PI / 2.0 - (float(k) / 4.0) * (PI / 2.0)
		stencil_pts.append(c_tl + Vector2(cos(ang), sin(ang)) * r)

	# Left edge to bottom-left corner
	stencil_pts.append(Vector2(-hw, hh - r))
	var c_bl := Vector2(-hw + r, hh - r)
	for k in range(1, 5):
		var ang: float = PI - (float(k) / 4.0) * (PI / 2.0)
		stencil_pts.append(c_bl + Vector2(cos(ang), sin(ang)) * r)

	# Bottom edge to bottom left of the 10px break gap
	stencil_pts.append(Vector2(-5.0, hh))

	_draw_node.draw_polyline(stencil_pts, outline_color, 2.0, true)

	# 3. Reserved chevrons when bus is incoming
	if is_reserved:
		var chev_c = Color("bae6fd", 0.95)
		var chev_dim = Color("bae6fd", 0.50)
		_draw_node.draw_line(Vector2(-8, -6), Vector2(0, -14), chev_c, 2.0)
		_draw_node.draw_line(Vector2(0, -14), Vector2(8, -6), chev_c, 2.0)
		_draw_node.draw_line(Vector2(-8, 4), Vector2(0, -4), chev_c, 2.0)
		_draw_node.draw_line(Vector2(0, -4), Vector2(8, 4), chev_c, 2.0)
		_draw_node.draw_line(Vector2(-8, 14), Vector2(0, 6), chev_dim, 1.8)
		_draw_node.draw_line(Vector2(0, 6), Vector2(8, 14), chev_dim, 1.8)

	# 4. Departing hatch indicator
	if is_departing:
		var hatch_c: Color = Color("fef3c7", 0.7)
		var hatch_step: float = 8.0
		var x0: float = -hw + 4.0
		var y0: float = -hh + 4.0
		var x1: float = hw - 4.0
		var y1: float = hh - 4.0
		var start_x: float = x0 - (y1 - y0)
		while start_x < x1:
			var sx: float = start_x
			var ex: float = start_x + (y1 - y0)
			var cax: float = max(sx, x0)
			var cbx: float = min(ex, x1)
			if cax < cbx:
				var cay: float = max(y0, (cax - sx) + y0)
				var cby: float = min(y1, (cbx - sx) + y0)
				_draw_node.draw_line(Vector2(cax, cay), Vector2(cbx, cby), hatch_c, 1.2)
			start_x += hatch_step

