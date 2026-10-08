extends Node2D

## 100% 2D Level Scene — "Bus Fever Party!"
## Features 100% Godot 2D architecture (Node2D, custom 2D drawing, 2D curves)
## with rich 2.5D pseudo-3D bus bodies (extruded side walls, drop shadows,
## glossy roofs, headlights, roof direction arrows) and 3D embossed capacity badges.

const LevelRegistryScript := preload("res://resources/level_registry.gd")
const Level1Resource := preload("res://resources/level_1.gd")

# 2D Metrics
const CELL: float = 78.0
const BOARD_Y: float = 720.0
const BAY_Y: float = 405.0
const FUNNEL_Y: float = 315.0
const TRACK_LOOP_Y: float = 185.0

var _controller: LevelController
var _game_world: Node2D
var _env_root: Node2D
var _board_node: Node2D
var _bay_root: Node2D
var _vehicle_root: Node2D
var _track_root: Node2D
var _passenger_root: Node2D
var _vfx_root: Node2D

var _vehicle_nodes: Array = []
var _bay_nodes: Array[Node2D] = []
var _track_passengers: Array[Node2D] = []
var _capacity_badges: Dictionary = {} # bay_idx -> Node2D

var _hint_vehicle_index: int = -1
var _session_token: int = 0
var _anim_clock: float = 0.0

# HUD & Overlays
var _hud: CanvasLayer
var _level_title_lbl: Label
var _btn_hint: Button
var _btn_undo: Button
var _btn_extra_bay: Button
var _overlay: Control

# Autoload references with safe fallback
var _game_ctrl: Node = null
var _save_mgr: Node = null
var _audio_mgr: Node = null

func _get_game_controller() -> Node:
	if _game_ctrl == null and is_inside_tree():
		_game_ctrl = get_node_or_null("/root/GameController")
	return _game_ctrl

func _get_save_manager() -> Node:
	if _save_mgr == null and is_inside_tree():
		_save_mgr = get_node_or_null("/root/SaveManager")
	return _save_mgr

func _get_audio_manager() -> Node:
	if _audio_mgr == null and is_inside_tree():
		_audio_mgr = get_node_or_null("/root/AudioManager")
	return _audio_mgr

func _play_sfx(sfx_name: String) -> void:
	var am := _get_audio_manager()
	if am != null and am.has_method("play"):
		am.play(sfx_name)

func _get_cur_level() -> int:
	var gc := _get_game_controller()
	if gc != null and "current_level_number" in gc:
		return int(gc.current_level_number)
	return 1

func _ready() -> void:
	_session_token += 1
	_build_scene_tree()
	_build_hud()
	_init_level()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_update_layout)
	_update_layout()

func _process(delta: float) -> void:
	_anim_clock += delta
	# Subtle rhythmic bounce for passengers in the queue
	for i in _track_passengers.size():
		var p: Node2D = _track_passengers[i]
		if is_instance_valid(p):
			p.position.y = p.get_meta("base_y", p.position.y) + sin(_anim_clock * 4.5 + float(i) * 0.4) * 2.5

# -----------------------------------------------------------------
# 2D SCENE GRAPH
# -----------------------------------------------------------------

func _build_scene_tree() -> void:
	_game_world = Node2D.new()
	_game_world.name = "GameWorld"
	add_child(_game_world)

	_env_root = Node2D.new()
	_env_root.name = "Environment"
	_game_world.add_child(_env_root)

	_board_node = Node2D.new()
	_board_node.name = "Board"
	_game_world.add_child(_board_node)

	_bay_root = Node2D.new()
	_bay_root.name = "Bays"
	_game_world.add_child(_bay_root)

	_track_root = Node2D.new()
	_track_root.name = "TrackPassengers"
	_game_world.add_child(_track_root)

	_passenger_root = Node2D.new()
	_passenger_root.name = "WalkingPassengers"
	_game_world.add_child(_passenger_root)

	_vehicle_root = Node2D.new()
	_vehicle_root.name = "Vehicles"
	_game_world.add_child(_vehicle_root)

	_vfx_root = Node2D.new()
	_vfx_root.name = "VFX"
	_game_world.add_child(_vfx_root)

	_build_environment()

# -----------------------------------------------------------------
# DYNAMIC RESPONSIVE LAYOUT (Centers 2D Game World on ANY Screen Ratio)
# -----------------------------------------------------------------

func _update_layout() -> void:
	if _game_world == null:
		return
	var vp := get_viewport()
	var vp_size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(720, 1880)
	if vp_size.y <= 0 or vp_size.x <= 0:
		return

	# Center horizontally
	_game_world.position.x = vp_size.x / 2.0

	# Available vertical space between top HUD (y=98) and bottom dock (y=vp_size.y - 120)
	var top_margin: float = 100.0
	var bottom_margin: float = 124.0
	var avail_h: float = vp_size.y - (top_margin + bottom_margin)
	const CONTENT_H: float = 980.0
	const CONTENT_W: float = 620.0

	var scale_h: float = avail_h / CONTENT_H
	var scale_w: float = vp_size.x / CONTENT_W
	var final_scale: float = clampf(minf(scale_h, scale_w), 0.72, 1.25)

	_game_world.scale = Vector2(final_scale, final_scale)
	_game_world.position.y = top_margin + (avail_h - CONTENT_H * final_scale) / 2.0

# -----------------------------------------------------------------
# 2D ENVIRONMENT (Pastel Park, Roadway, Trees, Curb Trim)
# -----------------------------------------------------------------

func _build_environment() -> void:
	# Background custom drawing node
	var bg_draw := Node2D.new()
	bg_draw.name = "EnvBackground"
	_env_root.add_child(bg_draw)
	bg_draw.draw.connect(func():
		# Soft pastel stone/park ground
		bg_draw.draw_rect(Rect2(-360, -40, 720, 1100), Color("dce5ed"))

		# Passenger Track curved asphalt band
		bg_draw.draw_rect(Rect2(-240, TRACK_LOOP_Y - 80, 480, 160), Color("334155"), true, -1, true) # dark track
		bg_draw.draw_rect(Rect2(-240, TRACK_LOOP_Y - 80, 480, 160), Color("ffffff"), false, 4.0)

		# Funnel exit road leading down to waiting bays
		bg_draw.draw_rect(Rect2(-45, FUNNEL_Y - 60, 90, 110), Color("334155"), true)
		bg_draw.draw_line(Vector2(-45, FUNNEL_Y - 60), Vector2(-45, FUNNEL_Y + 50), Color("ffffff"), 4.0)
		bg_draw.draw_line(Vector2(45, FUNNEL_Y - 60), Vector2(45, FUNNEL_Y + 50), Color("ffffff"), 4.0)

		# Waiting bay asphalt roadway
		bg_draw.draw_rect(Rect2(-260, BAY_Y - 50, 520, 100), Color("1e293b"), true)
		bg_draw.draw_line(Vector2(-260, BAY_Y - 50), Vector2(260, BAY_Y - 50), Color("64748b"), 3.0)
		bg_draw.draw_line(Vector2(-260, BAY_Y + 50), Vector2(260, BAY_Y + 50), Color("64748b"), 3.0)

		# Main puzzle asphalt lot
		bg_draw.draw_rect(Rect2(-245, BOARD_Y - 230, 490, 460), Color("18202c"), true)
		# Curb borders with bevel
		bg_draw.draw_rect(Rect2(-245, BOARD_Y - 230, 490, 460), Color("94a3b8"), false, 4.0)
	)

	# "▼ GO! ▼" Gate Label
	var go_lbl := Label.new()
	go_lbl.text = "▼ GO! ▼"
	go_lbl.add_theme_font_size_override("font_size", 16)
	go_lbl.add_theme_color_override("font_color", Color("ffd700"))
	go_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_lbl.position = Vector2(-40, FUNNEL_Y + 14)
	go_lbl.size = Vector2(80, 24)
	_env_root.add_child(go_lbl)

	# Decorative 2.5D Trees flanking the scene
	var tree_positions := [
		Vector2(-275, 140), Vector2(275, 140),
		Vector2(-280, 240), Vector2(280, 240),
		Vector2(-285, 400), Vector2(285, 400),
		Vector2(-285, 620), Vector2(285, 620),
		Vector2(-285, 840), Vector2(285, 840)
	]
	for pos in tree_positions:
		var is_cherry: bool = (pos.y < 300.0)
		var tree := _make_2d_tree(is_cherry)
		tree.position = pos
		_env_root.add_child(tree)

func _make_2d_tree(is_cherry: bool) -> Node2D:
	var t := Node2D.new()
	t.draw.connect(func():
		# Trunk drop shadow
		t.draw_ellipse(Vector2(2, 28), 18.0, 8.0, Color(0, 0, 0, 0.25))
		# Trunk
		t.draw_rect(Rect2(-5, 8, 10, 20), Color("5c3c24"), true)
		# Crown shadow layer
		var crown_col: Color = Color("f472b6") if is_cherry else Color("22c55e")
		t.draw_circle(Vector2(0, -6), 26.0, crown_col.darkened(0.25))
		# Crown main layer
		t.draw_circle(Vector2(-2, -10), 24.0, crown_col)
		# Crown highlight
		t.draw_circle(Vector2(-8, -16), 14.0, crown_col.lightened(0.25))
	)
	return t

# -----------------------------------------------------------------
# LEVEL SETUP & CORE CONTROLLER
# -----------------------------------------------------------------

func _init_level() -> void:
	_controller = LevelController.new()
	_controller.name = "LevelController"
	add_child(_controller)

	var cur_lvl_num: int = _get_cur_level()
	var lvl: LevelData = LevelRegistryScript.get_level(cur_lvl_num)
	if lvl == null:
		lvl = Level1Resource.new().build()

	_controller.load_level(lvl)

	_controller.bay_state_changed.connect(_on_bay_state_changed)
	_controller.vehicle_state_changed.connect(_on_vehicle_state_changed)
	_controller.passenger_state_changed.connect(_on_passenger_state_changed)
	_controller.game_state_changed.connect(_on_game_state_changed)
	_controller.request_move_animation.connect(_on_request_move_animation)
	_controller.request_board_animation.connect(_on_request_board_animation)
	_controller.request_depart_animation.connect(_on_request_depart_animation)
	_controller.request_hint_pulse.connect(_on_request_hint_pulse)
	_controller.request_blocked_shake.connect(_on_request_blocked_shake)

	_draw_parking_grid(lvl)
	_build_bays()
	_build_vehicles()
	_build_passenger_track_queue()
	_update_hud_stats()

# ---------- Coordinate Conversion ----------

func _cell_to_world_2d(p: Vector2i) -> Vector2:
	var lvl: LevelData = _controller.level_resource
	var ox: float = float(lvl.board_size.x - 1) / 2.0
	var oy: float = float(lvl.board_size.y - 1) / 2.0
	var wx: float = (float(p.x) - ox) * CELL
	var wy: float = BOARD_Y + (float(p.y) - oy) * CELL
	return Vector2(wx, wy)

func _bay_to_world_2d(bay_index: int) -> Vector2:
	var total_slots: int = 7
	var slot_spacing: float = 68.0
	var span: float = float(total_slots - 1) * slot_spacing
	var wx: float = -span / 2.0 + float(bay_index) * slot_spacing
	return Vector2(wx, BAY_Y)

# ---------- Parking Grid Floor Markings ----------

func _draw_parking_grid(lvl: LevelData) -> void:
	for c in _board_node.get_children():
		c.queue_free()

	var grid_draw := Node2D.new()
	grid_draw.name = "GridMarkings"
	_board_node.add_child(grid_draw)

	grid_draw.draw.connect(func():
		var ox: float = float(lvl.board_size.x - 1) / 2.0
		var oy: float = float(lvl.board_size.y - 1) / 2.0
		for y in lvl.board_size.y:
			for x in lvl.board_size.x:
				var wx: float = (float(x) - ox) * CELL
				var wy: float = BOARD_Y + (float(y) - oy) * CELL

				# Slot floor tile
				grid_draw.draw_rect(Rect2(wx - CELL * 0.46, wy - CELL * 0.46, CELL * 0.92, CELL * 0.92), Color("141c26"), true)

				# Yellow corner marks
				for cx in [-1, 1]:
					for cy in [-1, 1]:
						var mx: float = wx + float(cx) * CELL * 0.42
						var my: float = wy + float(cy) * CELL * 0.42
						grid_draw.draw_rect(Rect2(mx - 3, my - 3, 6, 6), Color("f59e0b"), true)
	)

# -----------------------------------------------------------------
# 7 WAITING BAYS & 3D EMBOSSED CAPACITY BADGES
# -----------------------------------------------------------------

func _build_bays() -> void:
	for n in _bay_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_bay_nodes.clear()
	_capacity_badges.clear()

	var total_slots: int = 7
	for i in total_slots:
		var slot_pos := _bay_to_world_2d(i)
		var bay_node := _make_bay_slot(i, slot_pos)
		_bay_nodes.append(bay_node)

func _make_bay_slot(idx: int, pos: Vector2) -> Node2D:
	var slot := Node2D.new()
	slot.position = pos

	var slot_draw := Node2D.new()
	slot_draw.draw.connect(func():
		var is_vip := (idx == 0)
		var is_extra := (idx >= 5)
		var bay_rect := Rect2(-30, -42, 60, 84)

		# Slot background
		var bg_col := Color("142236") if is_vip else (Color("101724") if is_extra else Color("192333"))
		slot_draw.draw_rect(bay_rect, bg_col, true)

		# Slot border
		if is_vip:
			slot_draw.draw_rect(bay_rect, Color("ffd700"), false, 2.5) # Gold VIP border
			# Wheel stop curb
			slot_draw.draw_rect(Rect2(-24, -38, 48, 6), Color("ffd700"), true)
		elif is_extra:
			slot_draw.draw_rect(bay_rect, Color("475569"), false, 2.0) # Dashed locked
		else:
			slot_draw.draw_rect(bay_rect, Color("e2e8f0"), false, 2.0) # White parking line
			slot_draw.draw_rect(Rect2(-24, -38, 48, 6), Color("f59e0b"), true) # Yellow wheel stop
	)
	slot.add_child(slot_draw)

	# Label stencil (VIP / "+")
	if idx == 0:
		var vip_lbl := Label.new()
		vip_lbl.text = "★ VIP"
		vip_lbl.add_theme_font_size_override("font_size", 12)
		vip_lbl.add_theme_color_override("font_color", Color("ffd700"))
		vip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vip_lbl.position = Vector2(-28, 22)
		vip_lbl.size = Vector2(56, 18)
		slot.add_child(vip_lbl)
	elif idx >= 5:
		var plus_lbl := Label.new()
		plus_lbl.text = "🔒 +"
		plus_lbl.add_theme_font_size_override("font_size", 13)
		plus_lbl.add_theme_color_override("font_color", Color("64748b"))
		plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus_lbl.position = Vector2(-28, -8)
		plus_lbl.size = Vector2(56, 20)
		slot.add_child(plus_lbl)

	# 3D EMBOSSED CAPACITY BADGE / COUNTER
	# Floating directly beneath the parked bus
	var badge_root := Node2D.new()
	badge_root.name = "CapacityBadge"
	badge_root.position = Vector2(0, 50.0)
	badge_root.visible = false

	var badge_draw := Node2D.new()
	badge_draw.name = "BadgeDraw"
	badge_root.add_child(badge_draw)

	var badge_lbl := Label.new()
	badge_lbl.name = "BadgeNum"
	badge_lbl.text = "0"
	badge_lbl.add_theme_font_size_override("font_size", 17)
	badge_lbl.add_theme_color_override("font_color", Color.WHITE)
	badge_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	badge_lbl.add_theme_constant_override("shadow_offset_x", 1)
	badge_lbl.add_theme_constant_override("shadow_offset_y", 2)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.position = Vector2(-26, -15)
	badge_lbl.size = Vector2(52, 30)
	badge_root.add_child(badge_lbl)

	slot.add_child(badge_root)
	_capacity_badges[idx] = badge_root
	_bay_root.add_child(slot)
	return slot

func _draw_3d_capacity_badge(draw_node: Node2D, color: Color) -> void:
	# 3D Embossed Badge rendering
	var bw: float = 48.0
	var bh: float = 28.0
	var rect := Rect2(-bw / 2.0, -bh / 2.0, bw, bh)

	# 1. Soft deep drop shadow
	draw_node.draw_rect(Rect2(-bw / 2.0 + 1, -bh / 2.0 + 4, bw, bh), Color(0, 0, 0, 0.45), true, -1, true)

	# 2. 3D Bottom Bevel Rim (Extruded depth)
	draw_node.draw_rect(Rect2(-bw / 2.0, -bh / 2.0 + 3, bw, bh), color.darkened(0.45), true, -1, true)

	# 3. Outer Metallic White/Gold Ring
	draw_node.draw_rect(rect, Color("ffffff"), false, 2.0)

	# 4. Main Badge Color Fill
	draw_node.draw_rect(rect, color, true, -1, true)

	# 5. Upper Convex Glass Highlight (3D bubble shine)
	var hl_rect := Rect2(-bw / 2.0 + 3, -bh / 2.0 + 2, bw - 6, bh * 0.42)
	draw_node.draw_rect(hl_rect, Color(1, 1, 1, 0.38), true, -1, true)

func _apply_bay_visual(bay, i: int) -> void:
	var badge_root: Node2D = _capacity_badges.get(i, null)
	if badge_root == null:
		return

	if bay == null or bay.state == BayManager.State.FREE:
		badge_root.visible = false
	elif bay.state == BayManager.State.RESERVED or bay.state == BayManager.State.OCCUPIED:
		var v = _controller.get_vehicle_by_id(bay.vehicle_id)
		if v != null:
			badge_root.visible = true
			var badge_draw: Node2D = badge_root.get_node_or_null("BadgeDraw")
			var badge_lbl: Label = badge_root.get_node_or_null("BadgeNum")
			if badge_draw != null:
				var col: Color = _bus_color(v.color)
				if badge_draw.draw.is_connected(_draw_3d_capacity_badge):
					badge_draw.draw.disconnect(_draw_3d_capacity_badge)
				badge_draw.draw.connect(_draw_3d_capacity_badge.bind(badge_draw, col))
				badge_draw.queue_redraw()
			if badge_lbl != null:
				badge_lbl.text = "%d" % v.remaining_count()
		else:
			badge_root.visible = false

# -----------------------------------------------------------------
# 2.5D PSEUDO-3D BUSES (Drop Shadows, Extruded Walls, Roof & Arrows)
# -----------------------------------------------------------------

func _build_vehicles() -> void:
	for n in _vehicle_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_vehicle_nodes.clear()

	for v in _controller._vehicles:
		var node: Node2D = _make_bus_node(v)
		_vehicle_nodes.append(node)

func _make_bus_node(v: Vehicle) -> Node2D:
	var root := Node2D.new()
	root.position = _cell_to_world_2d(v.position)
	root.set_meta("vehicle_index", v.index)
	root.set_meta("original_pos", root.position)

	var color: Color = _bus_color(v.color)

	# 2.5D Pseudo-3D Vehicle Body Drawer
	var bus_draw := Node2D.new()
	bus_draw.name = "BusVisual"
	bus_draw.draw.connect(_draw_25d_bus.bind(bus_draw, v, color))
	root.add_child(bus_draw)

	# Interactive Area2D for mobile touch
	var area := Area2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()

	var is_vert: bool = (v.direction == VehicleData.Direction.NORTH or v.direction == VehicleData.Direction.SOUTH)
	var v_len: int = 1
	if "length" in v:
		v_len = v.length
	elif v.data != null and "length" in v.data:
		v_len = v.data.length

	var bw: float = CELL * 0.82 if is_vert else CELL * (0.86 if v_len <= 1 else 1.84)
	var bh: float = CELL * (0.86 if v_len <= 1 else 1.84) if is_vert else CELL * 0.82
	shape.size = Vector2(bw, bh)
	col.shape = shape
	area.add_child(col)
	area.set_meta("vehicle_index", v.index)
	area.input_event.connect(_on_vehicle_input.bind(area))
	root.add_child(area)

	_vehicle_root.add_child(root)
	return root

func _draw_25d_bus(draw_node: Node2D, v: Vehicle, color: Color) -> void:
	var is_vert: bool = (v.direction == VehicleData.Direction.NORTH or v.direction == VehicleData.Direction.SOUTH)
	var v_len: int = 1
	if v != null and "length" in v:
		v_len = v.length
	elif v != null and v.data != null and "length" in v.data:
		v_len = v.data.length

	var bw: float = CELL * 0.80 if is_vert else CELL * (0.84 if v_len <= 1 else 1.82)
	var bh: float = CELL * (0.84 if v_len <= 1 else 1.82) if is_vert else CELL * 0.80
	const DEPTH: float = 12.0 # 3D vertical extrusion depth

	# 1. Deep Soft Drop Shadow (Offset diagonally)
	var shadow_rect := Rect2(-bw / 2.0 + 4, -bh / 2.0 + DEPTH + 4, bw, bh)
	draw_node.draw_rect(shadow_rect, Color(0, 0, 0, 0.35), true, -1, true)

	# 2. Four Rubber Tires peeking out on sides
	var tire_col := Color("111827")
	var hub_col := Color("94a3b8")
	var tire_w: float = 8.0
	var tire_h: float = 14.0
	if is_vert:
		for tx in [-bw / 2.0 - 2, bw / 2.0 - 6]:
			for ty in [-bh * 0.35, bh * 0.25]:
				draw_node.draw_rect(Rect2(tx, ty, tire_w, tire_h), tire_col, true)
				draw_node.draw_rect(Rect2(tx + 2, ty + 4, tire_w - 4, tire_h - 8), hub_col, true)
	else:
		for ty in [-bh / 2.0 - 2, bh / 2.0 - 6]:
			for tx in [-bw * 0.35, bw * 0.25]:
				draw_node.draw_rect(Rect2(tx, ty, tire_h, tire_w), tire_col, true)
				draw_node.draw_rect(Rect2(tx + 4, ty + 2, tire_h - 8, tire_w - 4), hub_col, true)

	# 3. 3D Extruded Lower Body / Side Walls (Darker shade for physical depth)
	var wall_rect := Rect2(-bw / 2.0, -bh / 2.0 + DEPTH, bw, bh)
	draw_node.draw_rect(wall_rect, color.darkened(0.36), true, -1, true)

	# Chrome lower rocker stripe
	draw_node.draw_line(Vector2(-bw / 2.0 + 4, bh / 2.0 + DEPTH - 4), Vector2(bw / 2.0 - 4, bh / 2.0 + DEPTH - 4), Color("ffffff"), 2.0)

	# 4. Front & Rear Chrome Bumpers + Headlights / Taillights
	_draw_bus_lights_and_grille(draw_node, v.direction, bw, bh, DEPTH)

	# 5. Top Roof Surface (Vibrant color, elevated face)
	var roof_rect := Rect2(-bw / 2.0, -bh / 2.0, bw, bh)
	draw_node.draw_rect(roof_rect, color.lightened(0.08), true, -1, true)

	# 3D Highlight Bevel on top & left perimeter
	draw_node.draw_line(Vector2(-bw / 2.0 + 2, -bh / 2.0 + 2), Vector2(bw / 2.0 - 2, -bh / 2.0 + 2), color.lightened(0.32), 2.0)
	draw_node.draw_line(Vector2(-bw / 2.0 + 2, -bh / 2.0 + 2), Vector2(-bw / 2.0 + 2, bh / 2.0 - 2), color.lightened(0.32), 2.0)
	# 3D Dark Bevel on bottom & right
	draw_node.draw_line(Vector2(-bw / 2.0 + 2, bh / 2.0 - 1), Vector2(bw / 2.0 - 2, bh / 2.0 - 1), color.darkened(0.24), 2.0)
	draw_node.draw_line(Vector2(bw / 2.0 - 1, -bh / 2.0 + 2), Vector2(bw / 2.0 - 1, bh / 2.0 - 2), color.darkened(0.24), 2.0)

	# 6. Glossy Windshield & Side Windows with Specular Glass Sheen
	_draw_bus_windows(draw_node, v.direction, bw, bh)

	# 7. Prominent White Direction Arrow on Roof
	_draw_roof_direction_arrow(draw_node, v.direction, bw, bh)

func _draw_bus_lights_and_grille(draw_node: Node2D, dir: int, bw: float, bh: float, depth: float) -> void:
	var head_col := Color("fef08a") # Warm yellow headlights
	var tail_col := Color("f87171") # Red taillights
	var chrome_col := Color("cbd5e1")

	if dir == VehicleData.Direction.SOUTH:
		# Front is bottom
		var fy: float = bh / 2.0 + depth - 2
		draw_node.draw_circle(Vector2(-bw * 0.32, fy), 5.0, head_col)
		draw_node.draw_circle(Vector2(bw * 0.32, fy), 5.0, head_col)
		# Radiator chrome grille
		draw_node.draw_line(Vector2(-bw * 0.16, fy), Vector2(bw * 0.16, fy), chrome_col, 3.0)
		# Rear taillights at top
		draw_node.draw_rect(Rect2(-bw * 0.35, -bh / 2.0, 8, 3), tail_col, true)
		draw_node.draw_rect(Rect2(bw * 0.35 - 8, -bh / 2.0, 8, 3), tail_col, true)
	elif dir == VehicleData.Direction.NORTH:
		# Front is top
		var fy: float = -bh / 2.0 + 2
		draw_node.draw_circle(Vector2(-bw * 0.32, fy), 5.0, head_col)
		draw_node.draw_circle(Vector2(bw * 0.32, fy), 5.0, head_col)
		# Rear taillights at bottom
		draw_node.draw_rect(Rect2(-bw * 0.35, bh / 2.0 + depth - 4, 8, 4), tail_col, true)
		draw_node.draw_rect(Rect2(bw * 0.35 - 8, bh / 2.0 + depth - 4, 8, 4), tail_col, true)
	elif dir == VehicleData.Direction.EAST:
		# Front is right
		var fx: float = bw / 2.0 - 2
		draw_node.draw_circle(Vector2(fx, -bh * 0.28 + depth * 0.5), 5.0, head_col)
		draw_node.draw_circle(Vector2(fx, bh * 0.28 + depth * 0.5), 5.0, head_col)
		# Rear taillights at left
		draw_node.draw_rect(Rect2(-bw / 2.0, -bh * 0.35 + depth * 0.5, 4, 8), tail_col, true)
		draw_node.draw_rect(Rect2(-bw / 2.0, bh * 0.35 - 8 + depth * 0.5, 4, 8), tail_col, true)
	elif dir == VehicleData.Direction.WEST:
		# Front is left
		var fx: float = -bw / 2.0 + 2
		draw_node.draw_circle(Vector2(fx, -bh * 0.28 + depth * 0.5), 5.0, head_col)
		draw_node.draw_circle(Vector2(fx, bh * 0.28 + depth * 0.5), 5.0, head_col)
		# Rear taillights at right
		draw_node.draw_rect(Rect2(bw / 2.0 - 4, -bh * 0.35 + depth * 0.5, 4, 8), tail_col, true)
		draw_node.draw_rect(Rect2(bw / 2.0 - 4, bh * 0.35 - 8 + depth * 0.5, 4, 8), tail_col, true)

func _draw_bus_windows(draw_node: Node2D, dir: int, bw: float, bh: float) -> void:
	var glass_col := Color("0f172a") # Glossy dark glass
	var sheen_col := Color(1, 1, 1, 0.32) # Diagonal glass shine

	if dir == VehicleData.Direction.SOUTH:
		# Front curved windshield near bottom
		var w_rect := Rect2(-bw * 0.38, bh * 0.16, bw * 0.76, bh * 0.24)
		draw_node.draw_rect(w_rect, glass_col, true, -1, true)
		draw_node.draw_line(Vector2(-bw * 0.25, bh * 0.36), Vector2(-bw * 0.10, bh * 0.20), sheen_col, 2.0)
	elif dir == VehicleData.Direction.NORTH:
		# Front curved windshield near top
		var w_rect := Rect2(-bw * 0.38, -bh * 0.40, bw * 0.76, bh * 0.24)
		draw_node.draw_rect(w_rect, glass_col, true, -1, true)
		draw_node.draw_line(Vector2(-bw * 0.25, -bh * 0.20), Vector2(-bw * 0.10, -bh * 0.36), sheen_col, 2.0)
	elif dir == VehicleData.Direction.EAST:
		var w_rect := Rect2(bw * 0.16, -bh * 0.38, bw * 0.24, bh * 0.76)
		draw_node.draw_rect(w_rect, glass_col, true, -1, true)
		draw_node.draw_line(Vector2(bw * 0.20, -bh * 0.15), Vector2(bw * 0.36, -bh * 0.30), sheen_col, 2.0)
	elif dir == VehicleData.Direction.WEST:
		var w_rect := Rect2(-bw * 0.40, -bh * 0.38, bw * 0.24, bh * 0.76)
		draw_node.draw_rect(w_rect, glass_col, true, -1, true)
		draw_node.draw_line(Vector2(-bw * 0.36, -bh * 0.15), Vector2(-bw * 0.20, -bh * 0.30), sheen_col, 2.0)

func _draw_roof_direction_arrow(draw_node: Node2D, dir: int, _bw: float, _bh: float) -> void:
	# White 3D arrow with drop shadow
	var arrow_col := Color.WHITE
	var shadow_col := Color(0, 0, 0, 0.45)

	var p_tip: Vector2
	var p_left: Vector2
	var p_right: Vector2
	var p_base: Vector2

	var s: float = 16.0 # Arrow magnitude
	if dir == VehicleData.Direction.SOUTH:
		p_tip = Vector2(0, s)
		p_left = Vector2(-s * 0.65, -s * 0.1)
		p_right = Vector2(s * 0.65, -s * 0.1)
		p_base = Vector2(0, -s * 0.9)
	elif dir == VehicleData.Direction.NORTH:
		p_tip = Vector2(0, -s)
		p_left = Vector2(-s * 0.65, s * 0.1)
		p_right = Vector2(s * 0.65, s * 0.1)
		p_base = Vector2(0, s * 0.9)
	elif dir == VehicleData.Direction.EAST:
		p_tip = Vector2(s, 0)
		p_left = Vector2(-s * 0.1, -s * 0.65)
		p_right = Vector2(-s * 0.1, s * 0.65)
		p_base = Vector2(-s * 0.9, 0)
	else: # WEST
		p_tip = Vector2(-s, 0)
		p_left = Vector2(s * 0.1, -s * 0.65)
		p_right = Vector2(s * 0.1, s * 0.65)
		p_base = Vector2(s * 0.9, 0)

	# Shadow
	var so := Vector2(1, 2)
	draw_node.draw_line(p_base + so, p_tip + so, shadow_col, 7.0)
	draw_node.draw_colored_polygon(PackedVector2Array([p_tip + so, p_left + so, p_right + so]), shadow_col)

	# Main White Arrow
	draw_node.draw_line(p_base, p_tip, arrow_col, 7.0)
	draw_node.draw_colored_polygon(PackedVector2Array([p_tip, p_left, p_right]), arrow_col)

# -----------------------------------------------------------------
# CHIBI 2D PASSENGER QUEUE & PARTICLES
# -----------------------------------------------------------------

func _build_passenger_track_queue() -> void:
	for n in _track_passengers:
		if is_instance_valid(n):
			n.queue_free()
	_track_passengers.clear()

	var pm: PassengerManager = _controller.get_passenger_manager()
	if pm == null:
		return

	var start_idx: int = pm.active_index()
	var remaining: int = pm.size() - start_idx
	var draw_count: int = mini(36, remaining)
	if draw_count <= 0:
		return

	for i in draw_count:
		var p_data = pm.passenger_at(start_idx + i)
		if p_data == null:
			continue
		var col: Color = _bus_color(p_data.color)
		var p_node := _make_2d_chibi_passenger(col)
		var pos := _get_track_point_2d(i)
		p_node.position = pos
		p_node.set_meta("base_y", pos.y)
		_track_root.add_child(p_node)
		_track_passengers.append(p_node)

func _get_track_point_2d(index: int) -> Vector2:
	if index < 6:
		# Straight funnel leading down to exit gate
		var fy: float = FUNNEL_Y - float(index) * 22.0
		return Vector2(0.0, fy)
	else:
		# Curved horseshoe loop arch
		var loop_idx := index - 6
		var side := -1.0 if (loop_idx % 2 == 0) else 1.0
		var progress: float = float(loop_idx / 2) * 0.38
		var angle: float = clampf(progress * 0.40, 0.0, PI)
		var rx: float = 170.0
		var ry: float = 75.0
		var x: float = side * (32.0 + sin(angle) * rx)
		var y: float = TRACK_LOOP_Y - cos(angle) * ry
		return Vector2(x, y)

func _make_2d_chibi_passenger(col: Color) -> Node2D:
	var root := Node2D.new()
	root.draw.connect(func():
		# 1. Ground shadow
		root.draw_ellipse(Vector2(0, 14), 10.0, 4.0, Color(0, 0, 0, 0.28))

		# 2. Shoes (Sneakers)
		root.draw_circle(Vector2(-4, 12), 3.0, Color("ffffff"))
		root.draw_circle(Vector2(4, 12), 3.0, Color("ffffff"))

		# 3. Pants (Dark denim)
		root.draw_rect(Rect2(-5, 5, 10, 7), Color("1e293b"), true)

		# 4. Hoodie/Torso (Group color)
		root.draw_rect(Rect2(-7, -4, 14, 10), col, true, -1, true)
		# White collar trim
		root.draw_circle(Vector2(0, -4), 3.0, Color("ffffff"))

		# 5. Head (Chibi skin tone)
		var skin_col := Color("fed7aa")
		root.draw_circle(Vector2(0, -11), 9.0, skin_col)

		# 6. Eyes & Cheeks (Cute anime expression)
		root.draw_circle(Vector2(-3, -11), 1.6, Color("0f172a"))
		root.draw_circle(Vector2(3, -11), 1.6, Color("0f172a"))
		root.draw_circle(Vector2(-2.5, -11.5), 0.6, Color("ffffff"))
		root.draw_circle(Vector2(3.5, -11.5), 0.6, Color("ffffff"))
		# Blush
		root.draw_circle(Vector2(-5, -8), 2.0, Color("fb7185"))
		root.draw_circle(Vector2(5, -8), 2.0, Color("fb7185"))

		# 7. Cap & Visor Brim (Group color)
		var cap_col := col.darkened(0.20)
		root.draw_arc(Vector2(0, -11), 9.0, PI, 0.0, 16, cap_col, 4.0)
		root.draw_rect(Rect2(-7, -13, 14, 3), cap_col.darkened(0.15), true)
	)
	return root

# -----------------------------------------------------------------
# TOUCH INPUT & BLOCKED BOUNCE
# -----------------------------------------------------------------

func _on_vehicle_input(_viewport: Node, event: InputEvent, _shape_idx: int, area: Area2D) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or mb.double_click:
			return
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed or st.double_tap:
			return
	else:
		return

	if _controller.is_interaction_locked():
		return
	var idx: int = int(area.get_meta("vehicle_index"))
	_controller.tap_vehicle(idx)

func _on_request_blocked_shake(vehicle_index: int) -> void:
	_play_sfx("blocked")
	var gc := _get_game_controller()
	if gc != null and gc.has_method("haptic_blocked"):
		gc.haptic_blocked()

	if vehicle_index < 0 or vehicle_index >= _vehicle_nodes.size():
		return
	var node: Node2D = _vehicle_nodes[vehicle_index]
	if node == null or not is_instance_valid(node):
		return
	var v := _controller.get_vehicle(vehicle_index)
	if v == null:
		return

	var orig_pos: Vector2 = node.get_meta("original_pos", node.position)
	var nudge: Vector2 = Vector2(VehicleData.dir_to_vector(v.direction)) * 14.0

	var tw := create_tween()
	tw.tween_property(node, "position", orig_pos + nudge, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", orig_pos, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# -----------------------------------------------------------------
# ANIMATIONS: VEHICLE ESCAPE, BOARDING STREAM, DEPARTURE
# -----------------------------------------------------------------

func _on_request_move_animation(vehicle_index: int, _from_cell: Vector2i, _to_cell: Vector2i, target_bay_index: int, _bus_color: String = "", _bus_id: String = "") -> void:
	_play_sfx("move")
	var gc := _get_game_controller()
	if gc != null and gc.has_method("haptic_selection"):
		gc.haptic_selection()

	if vehicle_index < 0 or vehicle_index >= _vehicle_nodes.size():
		_controller.on_move_animation_completed(vehicle_index, target_bay_index)
		return

	var node: Node2D = _vehicle_nodes[vehicle_index]
	if node == null or not is_instance_valid(node):
		_controller.on_move_animation_completed(vehicle_index, target_bay_index)
		return

	var target_pos := _bay_to_world_2d(target_bay_index)
	var start_pos: Vector2 = node.position
	var mid_y: float = (start_pos.y + target_pos.y) / 2.0
	var mid_pos := Vector2(target_pos.x * 0.7 + start_pos.x * 0.3, mid_y)

	# Smooth curve drive via Tween
	var tw := create_tween().set_parallel(false)
	tw.tween_property(node, "position", mid_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", target_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		_spawn_2d_dust(target_pos)
		_controller.on_move_animation_completed(vehicle_index, target_bay_index)
	)

func _on_request_board_animation(vehicle_index: int, count: int) -> void:
	_play_sfx("board")
	var gc := _get_game_controller()
	if gc != null and gc.has_method("haptic_selection"):
		gc.haptic_selection()

	var v := _controller.get_vehicle(vehicle_index)
	if v == null or v.bay_index == -1:
		_controller.on_board_animation_completed(vehicle_index, count)
		return

	var bay_pos := _bay_to_world_2d(v.bay_index)
	var col := _bus_color(v.color)

	# Pulse the 3D Capacity Badge on the bus
	var badge_root: Node2D = _capacity_badges.get(v.bay_index, null)
	if badge_root != null:
		var btw := create_tween()
		btw.tween_property(badge_root, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		btw.tween_property(badge_root, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Spawn chibi passengers walking in a stream down to the bus door
	for i in count:
		var p := _make_2d_chibi_passenger(col)
		p.position = Vector2(0, FUNNEL_Y)
		_passenger_root.add_child(p)

		var delay: float = float(i) * 0.12
		var ptw := create_tween()
		ptw.tween_interval(delay)
		ptw.tween_property(p, "position", bay_pos + Vector2(0, 10), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ptw.tween_callback(p.queue_free)

	var total_dur: float = float(count) * 0.12 + 0.40
	var finish_tw := create_tween()
	finish_tw.tween_interval(total_dur)
	finish_tw.tween_callback(func():
		_controller.on_board_animation_completed(vehicle_index, count)
	)

func _on_request_depart_animation(vehicle_index: int, bay_index: int) -> void:
	_play_sfx("parking")
	var gc := _get_game_controller()
	if gc != null and gc.has_method("haptic_selection"):
		gc.haptic_selection()

	if vehicle_index < 0 or vehicle_index >= _vehicle_nodes.size():
		_controller.on_depart_animation_completed(vehicle_index, bay_index)
		return

	var node: Node2D = _vehicle_nodes[vehicle_index]
	if node == null or not is_instance_valid(node):
		_controller.on_depart_animation_completed(vehicle_index, bay_index)
		return

	var badge_root: Node2D = _capacity_badges.get(bay_index, null)
	if badge_root != null:
		badge_root.visible = false

	# Drive bus off-screen to the right with acceleration
	var exit_pos := node.position + Vector2(500.0, 0.0)
	var tw := create_tween()
	tw.tween_property(node, "position", exit_pos, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_spawn_2d_dust(node.position)
		node.visible = false
		_controller.on_depart_animation_completed(vehicle_index, bay_index)
	)

func _on_request_hint_pulse(vehicle_index: int) -> void:
	_play_sfx("ui")
	if vehicle_index < 0 or vehicle_index >= _vehicle_nodes.size():
		return
	var node: Node2D = _vehicle_nodes[vehicle_index]
	if node == null or not is_instance_valid(node):
		return

	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _spawn_2d_dust(pos: Vector2) -> void:
	for i in 4:
		var p := Node2D.new()
		p.position = pos + Vector2(randf_range(-15, 15), randf_range(-6, 6))
		p.draw.connect(func():
			p.draw_circle(Vector2.ZERO, randf_range(4, 9), Color(0.9, 0.9, 0.9, 0.5))
		)
		_vfx_root.add_child(p)
		var tw := create_tween()
		tw.tween_property(p, "scale", Vector2(1.8, 1.8), 0.25)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.25)
		tw.tween_callback(p.queue_free)

# -----------------------------------------------------------------
# STATE CHANGED HANDLERS
# -----------------------------------------------------------------

func _on_vehicle_state_changed(vehicle_index: int) -> void:
	if vehicle_index == -1:
		for v in _controller._vehicles:
			if v.index < _vehicle_nodes.size():
				_update_vehicle_visual(_vehicle_nodes[v.index], v)
		return
	if vehicle_index >= 0 and vehicle_index < _vehicle_nodes.size():
		var v := _controller.get_vehicle(vehicle_index)
		_update_vehicle_visual(_vehicle_nodes[vehicle_index], v)

func _update_vehicle_visual(node: Node2D, v: Vehicle) -> void:
	if node == null or not is_instance_valid(node) or v == null:
		return
	var bus_draw: Node2D = node.get_node_or_null("BusVisual")
	if bus_draw != null:
		bus_draw.queue_redraw()

func _on_bay_state_changed() -> void:
	for i in _controller._bay_manager.bay_count():
		var bay = _controller._bay_manager.bay(i)
		_apply_bay_visual(bay, i)

func _on_passenger_state_changed() -> void:
	_build_passenger_track_queue()
	_update_hud_stats()

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		LevelController.GameState.WIN:
			_play_sfx("ui")
			var gc := _get_game_controller()
			if gc != null and gc.has_method("haptic_success"):
				gc.haptic_success()
			var sm := _get_save_manager()
			if sm != null:
				sm.unlock_level(_get_cur_level() + 1)
				sm.set_level_stars(_get_cur_level(), 3)
				sm.add_coins(50)
			_show_win_overlay()
		LevelController.GameState.FAIL:
			_play_sfx("blocked")
			var gc := _get_game_controller()
			if gc != null and gc.has_method("haptic_failure"):
				gc.haptic_failure()
			_show_fail_overlay()
		LevelController.GameState.PAUSED:
			_show_pause_overlay()
		LevelController.GameState.PLAYING:
			_clear_overlays()

func _bus_color(color_id: String) -> Color:
	return VehicleData.color_to_rgb(color_id)

# -----------------------------------------------------------------
# RESPONSIVE HUD & BOOSTER DOCK
# -----------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	_build_top_hud()
	_build_bottom_boosters()

func _build_top_hud() -> void:
	var top := Control.new()
	top.anchor_left = 0.0
	top.anchor_right = 1.0
	top.anchor_top = 0.0
	top.anchor_bottom = 0.0
	top.offset_left = 0.0
	top.offset_right = 0.0
	top.offset_top = 18.0
	top.offset_bottom = 98.0
	_hud.add_child(top)

	# TOP LEFT: Restart ↺
	var btn_restart := Button.new()
	btn_restart.text = "↺"
	btn_restart.add_theme_font_size_override("font_size", 30)
	btn_restart.anchor_left = 0.0
	btn_restart.anchor_right = 0.0
	btn_restart.anchor_top = 0.5
	btn_restart.anchor_bottom = 0.5
	btn_restart.offset_left = 20.0
	btn_restart.offset_right = 84.0
	btn_restart.offset_top = -32.0
	btn_restart.offset_bottom = 32.0
	btn_restart.pressed.connect(_on_restart_pressed)
	top.add_child(btn_restart)

	# TOP CENTER: Level Pill
	var level_pill := Panel.new()
	level_pill.anchor_left = 0.5
	level_pill.anchor_right = 0.5
	level_pill.anchor_top = 0.5
	level_pill.anchor_bottom = 0.5
	level_pill.offset_left = -110.0
	level_pill.offset_right = 110.0
	level_pill.offset_top = -28.0
	level_pill.offset_bottom = 28.0
	top.add_child(level_pill)

	_level_title_lbl = Label.new()
	var lvl_num: int = _get_cur_level()
	_level_title_lbl.text = "Level %d" % lvl_num
	_level_title_lbl.add_theme_font_size_override("font_size", 26)
	_level_title_lbl.add_theme_color_override("font_color", Color.WHITE)
	_level_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_title_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_pill.add_child(_level_title_lbl)

	# TOP RIGHT: Pause ⏸
	var btn_pause := Button.new()
	btn_pause.text = "⏸"
	btn_pause.add_theme_font_size_override("font_size", 26)
	btn_pause.anchor_left = 1.0
	btn_pause.anchor_right = 1.0
	btn_pause.anchor_top = 0.5
	btn_pause.anchor_bottom = 0.5
	btn_pause.offset_left = -84.0
	btn_pause.offset_right = -20.0
	btn_pause.offset_top = -32.0
	btn_pause.offset_bottom = 32.0
	btn_pause.pressed.connect(_on_pause_pressed)
	top.add_child(btn_pause)

func _build_bottom_boosters() -> void:
	var bottom := Control.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 16.0
	bottom.offset_right = -16.0
	bottom.offset_top = -116.0
	bottom.offset_bottom = -20.0
	_hud.add_child(bottom)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	bottom.add_child(hbox)

	var sm := _get_save_manager()
	var h_count: int = sm.get_booster_count("hint") if (sm != null and sm.has_method("get_booster_count")) else 5
	var u_count: int = sm.get_booster_count("undo") if (sm != null and sm.has_method("get_booster_count")) else 5
	var b_count: int = sm.get_booster_count("extra_bay") if (sm != null and sm.has_method("get_booster_count")) else 3

	_btn_hint = _make_booster_btn(hbox, "💡", "Hint", h_count, _on_hint_pressed)
	_btn_undo = _make_booster_btn(hbox, "↺", "Undo", u_count, _on_undo_pressed)
	_btn_extra_bay = _make_booster_btn(hbox, "🅿️", "+1 Bay", b_count, _on_extra_bay_pressed)

func _make_booster_btn(parent: Container, icon: String, label: String, count: int, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = "%s %s  (+%d)" % [icon, label, count]
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(190, 80)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn

func _update_hud_stats() -> void:
	var sm := _get_save_manager()
	var h_count: int = sm.get_booster_count("hint") if (sm != null and sm.has_method("get_booster_count")) else 5
	var u_count: int = sm.get_booster_count("undo") if (sm != null and sm.has_method("get_booster_count")) else 5
	var b_count: int = sm.get_booster_count("extra_bay") if (sm != null and sm.has_method("get_booster_count")) else 3

	if _btn_hint != null:
		_btn_hint.text = "💡 Hint (+%d)" % h_count
	if _btn_undo != null:
		_btn_undo.text = "↺ Undo (+%d)" % u_count
	if _btn_extra_bay != null:
		_btn_extra_bay.text = "🅿️ +1 Bay (+%d)" % b_count

# -----------------------------------------------------------------
# BOOSTER HANDLERS
# -----------------------------------------------------------------

func _on_hint_pressed() -> void:
	_play_sfx("ui")
	var sm := _get_save_manager()
	var cnt: int = sm.get_booster_count("hint") if (sm != null and sm.has_method("get_booster_count")) else 5
	if cnt <= 0:
		return
	if _controller.trigger_hint():
		if sm != null and sm.has_method("use_booster"):
			sm.use_booster("hint")
		_update_hud_stats()

func _on_undo_pressed() -> void:
	_play_sfx("ui")
	var sm := _get_save_manager()
	var cnt: int = sm.get_booster_count("undo") if (sm != null and sm.has_method("get_booster_count")) else 5
	if cnt <= 0:
		return
	if _controller.trigger_undo():
		if sm != null and sm.has_method("use_booster"):
			sm.use_booster("undo")
		_update_hud_stats()
		# Restore bus positions
		for v in _controller._vehicles:
			if v.index < _vehicle_nodes.size():
				var node: Node2D = _vehicle_nodes[v.index]
				if node != null and is_instance_valid(node):
					node.visible = true
					if v.bay_index != -1:
						node.position = _bay_to_world_2d(v.bay_index)
					else:
						node.position = _cell_to_world_2d(v.position)

func _on_extra_bay_pressed() -> void:
	_play_sfx("ui")
	var sm := _get_save_manager()
	var cnt: int = sm.get_booster_count("extra_bay") if (sm != null and sm.has_method("get_booster_count")) else 3
	if cnt <= 0:
		return
	if _controller.unlock_extra_bay():
		if sm != null and sm.has_method("use_booster"):
			sm.use_booster("extra_bay")
		_update_hud_stats()
		_on_bay_state_changed()

func _on_restart_pressed() -> void:
	_play_sfx("ui")
	_controller.restart_level()
	for v in _controller._vehicles:
		if v.index < _vehicle_nodes.size():
			var node: Node2D = _vehicle_nodes[v.index]
			if node != null and is_instance_valid(node):
				node.visible = true
				node.position = _cell_to_world_2d(v.position)
				node.scale = Vector2.ONE
	_build_passenger_track_queue()
	_update_hud_stats()
	_clear_overlays()

func _on_pause_pressed() -> void:
	_play_sfx("ui")
	_controller.pause()

# -----------------------------------------------------------------
# RESPONSIVE OVERLAYS (Victory, Fail, Pause)
# -----------------------------------------------------------------

func _show_win_overlay() -> void:
	_clear_overlays()
	_spawn_2d_confetti()

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 440)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "🎉 LEVEL CLEAR! 🎉"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("ffd700"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var stars := Label.new()
	stars.text = "⭐ ⭐ ⭐"
	stars.add_theme_font_size_override("font_size", 44)
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stars)

	var reward := Label.new()
	reward.text = "+50 COINS EARNED!"
	reward.add_theme_font_size_override("font_size", 24)
	reward.add_theme_color_override("font_color", Color("a8f08a"))
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reward)

	var next_btn := Button.new()
	next_btn.text = "NEXT LEVEL ➔"
	next_btn.add_theme_font_size_override("font_size", 28)
	next_btn.custom_minimum_size = Vector2(440, 70)
	next_btn.pressed.connect(func():
		_play_sfx("ui")
		var gc := _get_game_controller()
		if gc != null and gc.has_method("next_level"):
			gc.next_level()
	)
	vbox.add_child(next_btn)

	var replay_btn := Button.new()
	replay_btn.text = "Replay Level"
	replay_btn.add_theme_font_size_override("font_size", 22)
	replay_btn.custom_minimum_size = Vector2(440, 54)
	replay_btn.pressed.connect(func():
		_clear_overlays()
		_on_restart_pressed()
	)
	vbox.add_child(replay_btn)

	_hud.add_child(_overlay)

func _show_fail_overlay() -> void:
	_clear_overlays()

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 440)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "⚠️ PARKING LOT FULL!"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("ff4c4c"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "No waiting bus matches the queue.\nUse a booster to keep playing!"
	desc.add_theme_font_size_override("font_size", 20)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	var extra_btn := Button.new()
	extra_btn.text = "🅿️ Unlock +1 Extra Bay"
	extra_btn.add_theme_font_size_override("font_size", 24)
	extra_btn.custom_minimum_size = Vector2(440, 64)
	extra_btn.pressed.connect(func():
		_clear_overlays()
		_on_extra_bay_pressed()
		_controller.resume()
	)
	vbox.add_child(extra_btn)

	var undo_btn := Button.new()
	undo_btn.text = "↺ Undo Last Move"
	undo_btn.add_theme_font_size_override("font_size", 22)
	undo_btn.custom_minimum_size = Vector2(440, 56)
	undo_btn.pressed.connect(func():
		_clear_overlays()
		_on_undo_pressed()
		_controller.resume()
	)
	vbox.add_child(undo_btn)

	var retry_btn := Button.new()
	retry_btn.text = "🔄 Retry Level"
	retry_btn.add_theme_font_size_override("font_size", 20)
	retry_btn.custom_minimum_size = Vector2(440, 50)
	retry_btn.pressed.connect(func():
		_clear_overlays()
		_on_restart_pressed()
	)
	vbox.add_child(retry_btn)

	_hud.add_child(_overlay)

func _show_pause_overlay() -> void:
	_clear_overlays()

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 360)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.add_theme_font_size_override("font_size", 24)
	resume_btn.custom_minimum_size = Vector2(400, 56)
	resume_btn.pressed.connect(func():
		_clear_overlays()
		_controller.resume()
	)
	vbox.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Restart Level"
	restart_btn.add_theme_font_size_override("font_size", 22)
	restart_btn.custom_minimum_size = Vector2(400, 54)
	restart_btn.pressed.connect(func():
		_clear_overlays()
		_on_restart_pressed()
	)
	vbox.add_child(restart_btn)

	var home_btn := Button.new()
	home_btn.text = "Main Menu"
	home_btn.add_theme_font_size_override("font_size", 22)
	home_btn.custom_minimum_size = Vector2(400, 50)
	home_btn.pressed.connect(func():
		_play_sfx("ui")
		var gc := _get_game_controller()
		if gc != null and gc.has_method("goto_scene"):
			gc.goto_scene("res://scenes/main.tscn")
	)
	vbox.add_child(home_btn)

	_hud.add_child(_overlay)

func _clear_overlays() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null

func _spawn_2d_confetti() -> void:
	var colors := [Color("ffd700"), Color("38bdf8"), Color("f472b6"), Color("4ade80"), Color("f87171")]
	for i in 40:
		var c := ColorRect.new()
		c.color = colors[i % colors.size()]
		c.size = Vector2(12, 12)
		c.position = Vector2(randf_range(-250, 250), 100.0)
		_vfx_root.add_child(c)

		var tw := create_tween()
		var end_pos := c.position + Vector2(randf_range(-120, 120), randf_range(300, 700))
		tw.tween_property(c, "position", end_pos, randf_range(1.2, 2.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "rotation", randf_range(-6.0, 6.0), 2.0)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 2.0)
		tw.tween_callback(c.queue_free)