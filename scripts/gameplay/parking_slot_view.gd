extends Node2D
class_name ParkingSlotView

## 2.5D Recessed Parking Slot View
## Features an embossed/recessed asphalt bay well with inner shadow,
## 3D neon stencil border, glowing VIP slot badge, and 3D unlock button.

var slot_id: int = 0
var slot_state: int = CarJamParkingManager.SlotState.EMPTY
var is_unlocked: bool = true
var bay_kind: int = CarJamParkingManager.BayKind.REGULAR

const SLOT_WIDTH: float = 48.0
const SLOT_HEIGHT: float = 94.0

var custom_width: float = 0.0
var custom_height: float = 0.0

var _vip_label: Label
var _draw_node: Node2D

func setup(id: int, p_unlocked: bool = true, p_w: float = 0.0, p_h: float = 0.0, p_kind: int = CarJamParkingManager.BayKind.REGULAR) -> void:
	slot_id = id
	is_unlocked = p_unlocked
	custom_width = p_w
	custom_height = p_h
	bay_kind = p_kind
	name = "Slot_%d" % id

	_build_visuals()

func set_state(p_state: int) -> void:
	slot_state = p_state
	_update_visual_state()

func set_unlocked(p_unlocked: bool) -> void:
	is_unlocked = p_unlocked
	_update_visual_state()

func _build_visuals() -> void:
	_draw_node = Node2D.new()
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw_lines)
	
	var w = custom_width if custom_width > 0.0 else SLOT_WIDTH
	_vip_label = Label.new()
	_vip_label.text = "VIP"
	_vip_label.add_theme_font_size_override("font_size", 16)
	_vip_label.add_theme_color_override("font_color", Color("fef08a"))
	_vip_label.add_theme_color_override("font_outline_color", Color("854d0e"))
	_vip_label.add_theme_constant_override("outline_size", 4)
	_vip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vip_label.position = Vector2(-w / 2.0, -16.0)
	_vip_label.size = Vector2(w, 32.0)
	_vip_label.visible = false
	add_child(_vip_label)

	_update_visual_state()

func _update_visual_state() -> void:
	var is_vip = (slot_id == 0)
	var is_locked = not is_unlocked and not is_vip
	if slot_state == CarJamParkingManager.SlotState.EMPTY and not is_locked:
		_vip_label.visible = is_vip
	else:
		_vip_label.visible = false
	_draw_node.queue_redraw()

func _on_draw_lines() -> void:
	var is_vip = (slot_id == 0)
	var is_plus = (bay_kind == CarJamParkingManager.BayKind.PLUS)
	var is_locked = not is_unlocked and not is_vip
	var is_unlocked_plus = is_plus and is_unlocked
	var is_reserved = (slot_state == CarJamParkingManager.SlotState.RESERVED)
	var is_departing = (slot_state == CarJamParkingManager.SlotState.DEPARTING)

	var w = custom_width if custom_width > 0.0 else SLOT_WIDTH
	var h = custom_height if custom_height > 0.0 else SLOT_HEIGHT
	var hw = w / 2.0
	var hh = h / 2.0
	var r: float = 8.0

	# 1. 2.5D Recessed Asphalt Well with Inner Depth Shadow
	# Outer subtle drop shadow around well
	var sb_shadow := StyleBoxFlat.new()
	sb_shadow.bg_color = Color(0.0, 0.0, 0.0, 0.15)
	sb_shadow.set_corner_radius_all(int(r + 1.0))
	sb_shadow.draw(_draw_node.get_canvas_item(), Rect2(-hw - 1.0, -hh - 1.0, w + 2.0, h + 2.0))

	# Recessed base floor (PLUS-unlocked bays get a green-tinted floor for visual distinctness)
	var sb_floor := StyleBoxFlat.new()
	var floor_color_locked := Color("3f404d")
	var floor_color_vip := Color("4a4635")
	var floor_color_plus_unlocked := Color("3a5a3a")
	var floor_color_default := Color("4d4e5c")
	sb_floor.bg_color = floor_color_locked if is_locked else (floor_color_vip if is_vip else (floor_color_plus_unlocked if is_unlocked_plus else floor_color_default))
	sb_floor.set_corner_radius_all(int(r))
	sb_floor.draw(_draw_node.get_canvas_item(), Rect2(-hw, -hh, w, h))

	# Top and left inner shadow for 3D indentation
	var inner_top_shade = PackedVector2Array([
		Vector2(-hw + r, -hh), Vector2(hw - r, -hh),
		Vector2(hw - r, -hh + 3.0), Vector2(-hw + r, -hh + 3.0)
	])
	_draw_node.draw_colored_polygon(inner_top_shade, Color(0.0, 0.0, 0.0, 0.28))

	# 2. 3D Painted Stencil Outline with Break Gap at Entrance
	var outline_color: Color = Color("facc15") if is_vip else (Color("22c55e") if is_unlocked_plus else (Color("4ade80", 0.75) if is_locked else Color("d1d5db")))
	if is_departing:
		outline_color = Color("fbbf24")

	var stencil_pts := PackedVector2Array()
	# Start at bottom right of 10px break gap
	stencil_pts.append(Vector2(5.0, hh))
	stencil_pts.append(Vector2(hw - r, hh))

	# Bottom-right corner arc
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

	# Draw subtle glow under stencil
	if is_vip:
		_draw_node.draw_polyline(stencil_pts, Color("eab308", 0.35), 4.5, true)
	elif is_unlocked_plus:
		_draw_node.draw_polyline(stencil_pts, Color("86efac", 0.30), 4.5, true)
	_draw_node.draw_polyline(stencil_pts, outline_color, 2.2, true)

	# Small green "+" indicator on unlocked PLUS bays (top-right of slot)
	if is_unlocked_plus:
		var plus_col := Color("86efac")
		var cx: float = hw - 10.0
		var cy: float = -hh + 10.0
		_draw_node.draw_line(Vector2(cx - 3.5, cy), Vector2(cx + 3.5, cy), plus_col, 1.6)
		_draw_node.draw_line(Vector2(cx, cy - 3.5), Vector2(cx, cy + 3.5), plus_col, 1.6)

	# 3. Locked slot 3D green "+" unlock pill button (matching reference)
	if is_locked:
		var btn_pos := Vector2(0, 0)
		# Shadow
		_draw_node.draw_circle(btn_pos + Vector2(0, 2), 11.0, Color(0, 0, 0, 0.3))
		# Green button face
		_draw_node.draw_circle(btn_pos, 10.0, Color("15803d"))
		_draw_node.draw_circle(btn_pos + Vector2(0, -1), 9.0, Color("22c55e"))
		# White plus sign
		_draw_node.draw_line(btn_pos + Vector2(-5, -1), btn_pos + Vector2(5, -1), Color.WHITE, 2.4)
		_draw_node.draw_line(btn_pos + Vector2(0, -6), btn_pos + Vector2(0, 4), Color.WHITE, 2.4)

	# 4. Reserved chevrons when bus is incoming
	if is_reserved:
		var chev_c = Color("38bdf8", 0.95)
		var chev_dim = Color("38bdf8", 0.50)
		_draw_node.draw_line(Vector2(-8, -6), Vector2(0, -14), chev_c, 2.2)
		_draw_node.draw_line(Vector2(0, -14), Vector2(8, -6), chev_c, 2.2)
		_draw_node.draw_line(Vector2(-8, 4), Vector2(0, -4), chev_c, 2.2)
		_draw_node.draw_line(Vector2(0, -4), Vector2(8, 4), chev_c, 2.2)
		_draw_node.draw_line(Vector2(-8, 14), Vector2(0, 6), chev_dim, 2.0)
		_draw_node.draw_line(Vector2(0, 6), Vector2(8, 14), chev_dim, 2.0)

	# 5. Departing hatch indicator
	if is_departing:
		var hatch_c: Color = Color("fef08a", 0.75)
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
				_draw_node.draw_line(Vector2(cax, cay), Vector2(cbx, cby), hatch_c, 1.4)
			start_x += hatch_step
