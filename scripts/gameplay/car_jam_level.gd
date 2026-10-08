extends Node2D
class_name CarJamLevel

## Production-quality Car Jam single-level gameplay scene.
## Pure Godot 2D architecture with 2.5D pseudo-3D layered buses,
## exactly 4 parking slots, swept-footprint collision, and ordered passenger queue.

const CarJamLevelData := preload("res://data/level_data.gd")
const CarJamLevelFactory := preload("res://scripts/gameplay/level_factory.gd")
const CarJamController := preload("res://scripts/gameplay/car_jam_controller.gd")
const BoardView := preload("res://scripts/gameplay/board_view.gd")
const VehicleView := preload("res://scripts/gameplay/vehicle_view.gd")
const ParkingSlotView := preload("res://scripts/gameplay/parking_slot_view.gd")
const PassengerView := preload("res://scripts/gameplay/passenger_view.gd")
const VehicleMovement := preload("res://scripts/gameplay/vehicle_movement.gd")

# Metrics
const CELL_SIZE: float = 78.0
const BOARD_Y: float = 720.0
const PARKING_Y: float = 405.0
const PASSENGER_TRACK_Y: float = 195.0
const FUNNEL_Y: float = 315.0

# Hierarchy Nodes
var world_root: Node2D
var board_root: Node2D
var board_bg: BoardView
var vehicle_layer: Node2D
var board_effects: Node2D

var parking_root: Node2D
var parking_slots_node: Node2D
var parked_vehicles_node: Node2D

var passenger_track_root: Node2D
var passenger_visuals: Node2D
var boarding_effects: Node2D

var transit_layer: Node2D
var camera_2d: Camera2D

# HUD Nodes
var hud: CanvasLayer
var safe_area_root: Control
var top_bar: Control
var booster_bar: Control
var pause_overlay: Control
var result_overlay: Control

var level_title_label: Label
var result_title_label: Label
var result_btn: TextureButton

# Authoritative Controller
var controller: CarJamController
var vehicle_views: Dictionary = {} # int id -> VehicleView
var slot_views: Array[ParkingSlotView] = []

# Continuous Passenger Track State
var passenger_track: Path2D
var active_passengers: Array[Dictionary] = []
var track_time: float = 0.0
const PASSENGER_SPACING := 32.0
const TRACK_SPEED := 40.0


var _anim_clock: float = 0.0


func _process(delta: float) -> void:
	if passenger_track == null: return
	if controller.state == CarJamController.GameState.PLAYING:
		track_time -= TRACK_SPEED * delta
		var track_len = passenger_track.curve.get_baked_length()
		if track_time < 0: track_time += track_len
		
		for i in active_passengers.size():
			var p = active_passengers[i]
			var pf: PathFollow2D = p["follower"]
			var target_prog = track_time + i * PASSENGER_SPACING
			
			# Wrap around logic for smooth lerping
			target_prog = fmod(target_prog, track_len)
			if target_prog < 0: target_prog += track_len
			
			var diff = target_prog - pf.progress
			if diff > track_len / 2.0: diff -= track_len
			if diff < -track_len / 2.0: diff += track_len
			
			pf.progress += diff * 10.0 * delta # Smooth catch up

func _ready() -> void:
	_build_scene_hierarchy()
	_setup_controller()
	_load_level_1()

	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_update_layout)
	_update_layout()



func _build_scene_hierarchy() -> void:
	# 1. WorldRoot
	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)

	# World Background
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	var bg := TextureRect.new()
	var grad_tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.add_point(0.0, Color("e0f2fe"))
	grad.add_point(0.5, Color("bae6fd"))
	grad.add_point(1.0, Color("7dd3fc"))
	grad_tex.gradient = grad
	grad_tex.fill_to = Vector2(0, 1)
	grad_tex.fill_from = Vector2(0, 0)
	bg.texture = grad_tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	add_child(bg_layer)


	# 1.1 BoardRoot
	board_root = Node2D.new()
	board_root.name = "BoardRoot"
	board_root.rotation = deg_to_rad(45)
	board_root.scale = Vector2(1.0, 0.6) # Isometric-ish tilt
	
	board_root.position = Vector2(0, BOARD_Y)
	world_root.add_child(board_root)

	board_bg = BoardView.new()
	board_bg.name = "BoardBackground"
	board_root.add_child(board_bg)

	vehicle_layer = Node2D.new()
	vehicle_layer.name = "VehicleLayer"
	board_root.add_child(vehicle_layer)

	board_effects = Node2D.new()
	board_effects.name = "BoardEffects"
	board_root.add_child(board_effects)

	# 1.2 ParkingRoot
	parking_root = Node2D.new()
	parking_root.name = "ParkingRoot"
	parking_root.position = Vector2(0, PARKING_Y)
	world_root.add_child(parking_root)

	parking_slots_node = Node2D.new()
	parking_slots_node.name = "ParkingSlots"
	parking_root.add_child(parking_slots_node)

	parked_vehicles_node = Node2D.new()
	parked_vehicles_node.name = "ParkedVehicles"
	parking_root.add_child(parked_vehicles_node)

	# 1.3 PassengerTrack
	passenger_track_root = Node2D.new()
	passenger_track_root.name = "PassengerTrack"
	passenger_track_root.position = Vector2(0, PASSENGER_TRACK_Y)
	world_root.add_child(passenger_track_root)

	passenger_visuals = Node2D.new()
	passenger_visuals.name = "PassengerVisuals"
	passenger_track_root.add_child(passenger_visuals)

	boarding_effects = Node2D.new()
	boarding_effects.name = "BoardingEffects"
	world_root.add_child(boarding_effects)

	# 1.4 TransitLayer
	transit_layer = Node2D.new()
	transit_layer.name = "TransitLayer"
	world_root.add_child(transit_layer)

	# 2. Camera2D
	camera_2d = Camera2D.new()
	camera_2d.name = "Camera2D"
	add_child(camera_2d)

	# 3. HUD
	_build_hud()

func _setup_controller() -> void:
	controller = CarJamController.new()
	controller.name = "CarJamController"
	add_child(controller)

	controller.vehicle_dispatch_started.connect(_on_vehicle_dispatch_started)
	controller.vehicle_parked.connect(_on_vehicle_parked)
	controller.vehicle_blocked.connect(_on_vehicle_blocked)
	controller.boarding_started.connect(_on_boarding_started)
	controller.vehicle_filled.connect(_on_vehicle_filled)
	controller.vehicle_departed.connect(_on_vehicle_departed)
	controller.parking_updated.connect(_on_parking_updated)
	controller.queue_updated.connect(_on_queue_updated)
	controller.level_completed.connect(_on_level_completed)
	controller.puzzle_failed.connect(_on_puzzle_failed)

func _load_level_1() -> void:
	var lvl: CarJamLevelData = null
	if ResourceLoader.exists("res://levels/level_001.tres"):
		lvl = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	if lvl == null:
		lvl = CarJamLevelFactory.create_level_1()

	controller.load_level(lvl)
	_setup_visuals(lvl)

func _setup_visuals(lvl: CarJamLevelData) -> void:
	# Clear previous visuals
	for v in vehicle_views.values():
		if is_instance_valid(v): v.queue_free()
	vehicle_views.clear()
	for c in boarding_effects.get_children():
		c.queue_free()
	for c in transit_layer.get_children():
		c.queue_free()


	for s in slot_views:
		if is_instance_valid(s): s.queue_free()
	slot_views.clear()

	for p in active_passengers:
		if is_instance_valid(p["view"]): p["view"].queue_free()
		if is_instance_valid(p["follower"]): p["follower"].queue_free()
	active_passengers.clear()
	if is_instance_valid(passenger_track):
		passenger_track.queue_free()
		passenger_track = null

	# 1. Board Background
	board_bg.setup(lvl.board_size)

	# 2. Parking Slots (Exactly 4 slots)
	var slot_spacing := 72.0
	var total_span: float = float(lvl.parking_slots_count - 1) * slot_spacing
	
	# Draw a slanted grey background behind all slots
	var bg = Polygon2D.new()
	bg.color = Color("8c92a1") # Light grey like the reference
	var bg_shear = 20.0
	var bg_w = total_span + 100.0
	var bg_h = 110.0
	var p1 = Vector2(-bg_w/2 + bg_shear, -bg_h/2)
	var p2 = Vector2(bg_w/2 + bg_shear, -bg_h/2)
	var p3 = Vector2(bg_w/2 - bg_shear, bg_h/2)
	var p4 = Vector2(-bg_w/2 - bg_shear, bg_h/2)
	bg.polygon = PackedVector2Array([p1, p2, p3, p4])
	parking_slots_node.add_child(bg)

	for i in lvl.parking_slots_count:
		var slot_view := ParkingSlotView.new()
		slot_view.setup(i)
		slot_view.position = Vector2(-total_span / 2.0 + float(i) * slot_spacing, 0)
		parking_slots_node.add_child(slot_view)
		slot_views.append(slot_view)

	# 3. Vehicles
	for vd in lvl.vehicles:
		var vv := VehicleView.new()
		vv.setup(vd.id, vd.code, vd.color_id, vd.direction, vd.capacity, vd.footprint)
		var center_offset = _calc_footprint_center_offset(vd.footprint)
		vv.position = _cell_to_board_local(vd.anchor, lvl.board_size) + center_offset
		vv.tapped.connect(_on_vehicle_tapped)
		vehicle_layer.add_child(vv)
		vehicle_views[vd.id] = vv

	# 4. Passenger Queue
	_init_passenger_track()

func _calc_footprint_center_offset(footprint: Array[Vector2i]) -> Vector2:
	if footprint.size() <= 1: return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in footprint:
		sum += Vector2(p)
	var avg = sum / float(footprint.size())
	return avg * CELL_SIZE

func _cell_to_board_local(c: Vector2i, b_size: Vector2i) -> Vector2:
	var lx = float(c.x) - float(b_size.x - 1) / 2.0
	var ly = float(c.y) - float(b_size.y - 1) / 2.0
	
	var tile_w = 80.0
	var tile_h = 46.0
	
	var ix = (lx - ly) * (tile_w / 2.0)
	var iy = (lx + ly) * (tile_h / 2.0)
	
	return Vector2(ix, iy)

func _get_slot_world_pos(slot_id: int) -> Vector2:
	if slot_id >= 0 and slot_id < slot_views.size():
		return parking_root.position + slot_views[slot_id].position
	return Vector2(0, PARKING_Y)

func _init_passenger_track() -> void:
	passenger_track = Path2D.new()
	var curve = Curve2D.new()
	# Create an oval track
	var center = Vector2(0, -60)
	var rx = 180.0
	var ry = 70.0
	var pts = 32
	for i in range(pts + 1):
		var t = float(i) / pts * PI * 2.0
		curve.add_point(center + Vector2(cos(t)*rx, sin(t)*ry))
	passenger_track.curve = curve
	passenger_visuals.add_child(passenger_track)
	track_time = curve.get_baked_length() * 0.25

	_fill_passenger_track()

func _fill_passenger_track() -> void:
	if passenger_track == null: return
	var needed = min(20, controller.queue.get_remaining_total())
	if active_passengers.size() >= needed: return
	
	var visible_groups := controller.queue.get_visible_groups(needed)
	var current_idx = 0
	
	# Skip ones we already spawned
	for g in visible_groups:
		for i in g.remaining_count:
			if current_idx >= active_passengers.size() and current_idx < needed:
				var pv := PassengerView.new()
				pv.setup(g.color_id)
				var pf := PathFollow2D.new()
				pf.loop = true
				pf.rotates = false
				pf.add_child(pv)
				passenger_track.add_child(pf)
				
				# Initial position behind the last one
				var start_prog = track_time + current_idx * PASSENGER_SPACING
				pf.progress = start_prog
				
				active_passengers.append({
					"view": pv,
					"follower": pf,
					"color_id": g.color_id
				})
			current_idx += 1

func _on_vehicle_tapped(vehicle_id: int) -> void:
	_play_sfx("select")
	controller.tap_vehicle(vehicle_id)

func _on_vehicle_dispatch_started(vehicle_id: int, slot_id: int, corridor: Array[Vector2i]) -> void:
	_play_sfx("move")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv == null:
		return

	# Reparent to TransitLayer preserving global position
	var global_start := vv.global_position
	vv.get_parent().remove_child(vv)
	transit_layer.add_child(vv)
	vv.global_position = global_start

	var target_slot_pos := _get_slot_world_pos(slot_id)
	var exit_cell: Vector2i = corridor.back() if not corridor.is_empty() else vv.position
	var exit_pos := board_root.position + _cell_to_board_local(exit_cell, controller.level_data.board_size)

	VehicleMovement.animate_dispatch(
		vv,
		vv.position,
		exit_pos,
		target_slot_pos,
		controller.session_token,
		controller,
		vehicle_id,
		slot_id
	)

func _on_vehicle_parked(vehicle_id: int, slot_id: int) -> void:
	_play_sfx("parking")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null and slot_id < slot_views.size():
		# Reparent to ParkedVehicles
		var global_pos := vv.global_position
		vv.get_parent().remove_child(vv)
		parked_vehicles_node.add_child(vv)
		vv.global_position = global_pos
		slot_views[slot_id].set_state(CarJamParkingManager.SlotState.OCCUPIED)

func _on_vehicle_blocked(vehicle_id: int, _blocker_id: int) -> void:
	_play_sfx("blocked")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null:
		vv.play_blocked_shake()

func _on_boarding_started(vehicle_id: int, color_id: String, count: int, slot_id: int) -> void:
	_play_sfx("board")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null:
		var v_model: VehicleModel = controller.vehicles.get(vehicle_id, null)
		if v_model != null:
			vv.set_occupancy(v_model.passenger_occupancy)
		vv.play_badge_pulse()

	var slot_pos := _get_slot_world_pos(slot_id)

	# Extract real passengers from the track
	for i in count:
		if active_passengers.is_empty(): break
		
		# Find first matching passenger (should be at front of queue)
		var p_idx = -1
		for j in active_passengers.size():
			if active_passengers[j]["color_id"] == color_id:
				p_idx = j
				break
		
		if p_idx == -1: break
		
		var p_dict = active_passengers.pop_at(p_idx)
		var pv: PassengerView = p_dict["view"]
		var pf: PathFollow2D = p_dict["follower"]
		
		var global_p = pv.global_position
		pf.remove_child(pv)
		boarding_effects.add_child(pv)
		pv.global_position = global_p
		pf.queue_free()
		
		var delay: float = float(i) * 0.12
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(pv, "position", slot_pos + Vector2(0, 12), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(pv.queue_free)

func _on_vehicle_filled(vehicle_id: int, slot_id: int) -> void:
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv == null:
		return

	# Schedule departure after brief acknowledgment
	var tw := create_tween()
	tw.tween_interval(0.40)
	tw.tween_callback(func():
		_play_sfx("depart")
		var slot_pos := _get_slot_world_pos(slot_id)
		VehicleMovement.animate_departure(
			vv,
			slot_pos,
			controller.session_token,
			controller,
			vehicle_id,
			slot_id
		)
	)

func _on_vehicle_departed(_vehicle_id: int, slot_id: int) -> void:
	if slot_id < slot_views.size():
		slot_views[slot_id].set_state(CarJamParkingManager.SlotState.EMPTY)

func _on_parking_updated() -> void:
	for i in slot_views.size():
		var slot := controller.parking.get_slot(i)
		if slot != null:
			slot_views[i].set_state(slot.state)

func _on_queue_updated() -> void:
	_fill_passenger_track()

func _on_level_completed() -> void:
	_play_sfx("victory")
	result_title_label.text = "🏆 LEVEL CLEAR!"
	result_title_label.add_theme_color_override("font_color", Color("facc15"))
	result_overlay.visible = true

func _on_puzzle_failed() -> void:
	_play_sfx("failure")
	result_title_label.text = "⚠️ NO MOVES LEFT!"
	result_title_label.add_theme_color_override("font_color", Color("ef4444"))
	result_overlay.visible = true

# -----------------------------------------------------------------
# RESPONSIVE HUD & SAFE AREA
# -----------------------------------------------------------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	safe_area_root = Control.new()
	safe_area_root.name = "SafeAreaRoot"
	safe_area_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(safe_area_root)

	# TopBar: Level 1, Restart, Pause
	top_bar = Control.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 20.0
	top_bar.offset_right = -20.0
	top_bar.offset_top = 24.0
	top_bar.offset_bottom = 90.0
	safe_area_root.add_child(top_bar)

	var btn_restart := TextureButton.new()
	btn_restart.texture_normal = load("res://assets/btn_back.png")
	btn_restart.stretch_mode = TextureButton.STRETCH_SCALE
	btn_restart.custom_minimum_size = Vector2(77, 81)
	btn_restart.button_down.connect(func(): btn_restart.position.y += 4)
	btn_restart.button_up.connect(func(): btn_restart.position.y -= 4)
	btn_restart.pressed.connect(_on_restart_pressed)
	top_bar.add_child(btn_restart)

	level_title_label = Label.new()
	level_title_label.text = "Level 1"
	level_title_label.add_theme_font_size_override("font_size", 32)
	level_title_label.add_theme_color_override("font_color", Color("ffffff"))
	level_title_label.add_theme_color_override("font_outline_color", Color("000000"))
	level_title_label.add_theme_constant_override("outline_size", 4)
	level_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_title_label.anchor_left = 0.25
	level_title_label.anchor_right = 0.75
	level_title_label.anchor_top = 0.0
	level_title_label.anchor_bottom = 1.0
	top_bar.add_child(level_title_label)

	var btn_pause := TextureButton.new()
	btn_pause.texture_normal = load("res://assets/btn_pause.png")
	btn_pause.stretch_mode = TextureButton.STRETCH_SCALE
	btn_pause.custom_minimum_size = Vector2(80, 81)
	btn_pause.button_down.connect(func(): btn_pause.position.y += 4)
	btn_pause.button_up.connect(func(): btn_pause.position.y -= 4)
	btn_pause.anchor_left = 1.0
	btn_pause.offset_left = -80.0
	btn_pause.pressed.connect(_on_pause_pressed)
	top_bar.add_child(btn_pause)

	# BoosterBar (VIP, Arrange, Jumble) marked locked/unavailable as per Phase 7
	booster_bar = Control.new()
	booster_bar.name = "BoosterBar"
	booster_bar.anchor_left = 0.0
	booster_bar.anchor_right = 1.0
	booster_bar.anchor_top = 1.0
	booster_bar.anchor_bottom = 1.0
	booster_bar.offset_left = 20.0
	booster_bar.offset_right = -20.0
	booster_bar.offset_top = -120.0
	booster_bar.offset_bottom = -20.0
	safe_area_root.add_child(booster_bar)

	var b_hbox := HBoxContainer.new()
	b_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	b_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	b_hbox.add_theme_constant_override("separation", 24)
	booster_bar.add_child(b_hbox)

	var bst_style = StyleBoxFlat.new()
	bst_style.bg_color = Color("38bdf8") # light blue
	bst_style.border_width_bottom = 12
	bst_style.border_color = Color("ffffff") # white rim
	bst_style.corner_radius_top_left = 24
	bst_style.corner_radius_top_right = 24
	bst_style.corner_radius_bottom_left = 24
	bst_style.corner_radius_bottom_right = 24
	bst_style.shadow_color = Color("0284c7") # dark blue shadow
	bst_style.shadow_size = 1
	bst_style.shadow_offset = Vector2(0, 12)

	bst_style.border_width_top = 8
	bst_style.border_blend = true

	
	var bst_pressed = bst_style.duplicate()
	bst_pressed.border_width_bottom = 6
	bst_pressed.shadow_offset = Vector2(0, 6)
	bst_pressed.content_margin_top = 6

	for b_name in ["VIP", "Arrange", "Jumble"]:
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		
		# Base button uses procedural style to remain crisp and clean
		var btn := Button.new()
		btn.add_theme_stylebox_override("normal", bst_style)
		btn.add_theme_stylebox_override("hover", bst_style)
		btn.add_theme_stylebox_override("pressed", bst_pressed)
		btn.add_theme_stylebox_override("disabled", bst_style)
		btn.disabled = true
		btn.custom_minimum_size = Vector2(100, 100)
		
		# Clean icon
		var icon_name = "icon_car_clean.png" if b_name == "VIP" else ("icon_bus_clean.png" if b_name == "Arrange" else "icon_ball_clean.png")
		var icon_rect = TextureRect.new()
		icon_rect.texture = load("res://assets/" + icon_name)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		# slightly smaller to fit in the box nicely
		icon_rect.offset_left = 12
		icon_rect.offset_right = -12
		icon_rect.offset_top = 12
		icon_rect.offset_bottom = -16
		btn.add_child(icon_rect)
		
		# Add a green '+' circle
		var plus := Label.new()
		plus.text = "✚"
		plus.add_theme_font_size_override("font_size", 18)
		plus.add_theme_color_override("font_color", Color("ffffff"))
		plus.add_theme_color_override("font_outline_color", Color("166534"))
		plus.add_theme_constant_override("outline_size", 4)
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("22c55e")
		p_style.corner_radius_top_left = 20
		p_style.corner_radius_top_right = 20
		p_style.corner_radius_bottom_left = 20
		p_style.corner_radius_bottom_right = 20
		p_style.border_width_bottom = 2
		p_style.border_color = Color("16a34a")
		plus.add_theme_stylebox_override("normal", p_style)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.size = Vector2(28, 28)
		plus.position = Vector2(80, -8)
		btn.add_child(plus)
		
		vbox.add_child(btn)
		
		var lbl = Label.new()
		lbl.text = b_name
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color("ffffff"))
		lbl.add_theme_color_override("font_outline_color", Color("1e293b"))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)
		
		b_hbox.add_child(vbox)

	# PauseOverlay
	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(pause_overlay)

	var p_bg := ColorRect.new()
	p_bg.color = Color(0, 0, 0, 0.7)
	p_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(p_bg)

	var p_center := CenterContainer.new()
	p_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(p_center)
	
	var p_main := Control.new()
	p_main.custom_minimum_size = Vector2(460, 520)
	p_center.add_child(p_main)
	
	var p_vbox := VBoxContainer.new()
	p_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_vbox.add_theme_constant_override("separation", 0)
	p_main.add_child(p_vbox)

	# Blue Header
	var p_header := PanelContainer.new()
	var ph_style := StyleBoxFlat.new()
	ph_style.bg_color = Color("4b7bec")
	ph_style.corner_radius_top_left = 24
	ph_style.corner_radius_top_right = 24
	p_header.add_theme_stylebox_override("panel", ph_style)
	p_header.custom_minimum_size = Vector2(460, 80)
	p_vbox.add_child(p_header)
	
	var ph_lbl := Label.new()
	ph_lbl.text = "SETTINGS"
	ph_lbl.add_theme_font_size_override("font_size", 36)
	ph_lbl.add_theme_color_override("font_color", Color("ffffff"))
	ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_header.add_child(ph_lbl)
	
	# Close button inside header
	var p_close := Button.new()
	var pc_style := StyleBoxFlat.new()
	pc_style.bg_color = Color("eb3b5a")
	pc_style.border_width_bottom = 6
	pc_style.border_color = Color("b71540")
	pc_style.corner_radius_top_left = 16
	pc_style.corner_radius_top_right = 16
	pc_style.corner_radius_bottom_left = 16
	pc_style.corner_radius_bottom_right = 16
	p_close.add_theme_stylebox_override("normal", pc_style)
	p_close.add_theme_stylebox_override("hover", pc_style)
	p_close.add_theme_stylebox_override("pressed", pc_style)
	p_close.text = "✖"
	p_close.add_theme_font_size_override("font_size", 28)
	p_close.add_theme_color_override("font_color", Color("ffffff"))
	p_close.custom_minimum_size = Vector2(64, 64)
	p_close.anchor_left = 1.0
	p_close.anchor_right = 1.0
	p_close.offset_left = -76.0
	p_close.offset_top = 8.0
	p_close.pressed.connect(_on_resume_pressed)
	p_main.add_child(p_close)

	# White/Light Blue Body
	var p_body := PanelContainer.new()
	var pb_style := StyleBoxFlat.new()
	pb_style.bg_color = Color("e8f4fa")
	pb_style.corner_radius_bottom_left = 24
	pb_style.corner_radius_bottom_right = 24
	p_body.add_theme_stylebox_override("panel", pb_style)
	p_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p_vbox.add_child(p_body)
	
	var pb_margin := MarginContainer.new()
	pb_margin.add_theme_constant_override("margin_left", 32)
	pb_margin.add_theme_constant_override("margin_right", 32)
	pb_margin.add_theme_constant_override("margin_top", 32)
	pb_margin.add_theme_constant_override("margin_bottom", 24)
	p_body.add_child(pb_margin)
	
	var pb_vbox := VBoxContainer.new()
	pb_vbox.add_theme_constant_override("separation", 24)
	pb_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pb_margin.add_child(pb_vbox)

	# Icons Row
	var p_icons := HBoxContainer.new()
	p_icons.add_theme_constant_override("separation", 24)
	p_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	pb_vbox.add_child(p_icons)
	
	var sm_sfx = true
	var sm_music = true
	var sm_haptics = true
	if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
		var sm = get_tree().root.get_node("SettingsManager")
		sm_sfx = sm.sfx_enabled()
		sm_music = sm.music_enabled()
		sm_haptics = sm.haptics_enabled()

	p_icons.add_child(_create_settings_icon_button("Sound", "🔊", sm_sfx, func(on):
		if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
			get_tree().root.get_node("SettingsManager").set_sfx(on)
	))
	p_icons.add_child(_create_settings_icon_button("Music", "🎵", sm_music, func(on): 
		if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
			get_tree().root.get_node("SettingsManager").set_music(on)
		if is_inside_tree() and get_tree().root.has_node("AudioManager"):
			var am = get_tree().root.get_node("AudioManager")
			if on: am.play_music()
			else: am.stop_music()
	))
	p_icons.add_child(_create_settings_icon_button("Vibrate", "📳", sm_haptics, func(on):
		if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
			get_tree().root.get_node("SettingsManager").set_haptics(on)
	))
	
	# Action Buttons
	var p_btn_home := TextureButton.new()
	p_btn_home.texture_normal = load("res://assets/btn_home.png")
	p_btn_home.stretch_mode = TextureButton.STRETCH_SCALE
	p_btn_home.custom_minimum_size = Vector2(264, 118)
	p_btn_home.button_down.connect(func(): p_btn_home.position.y += 8)
	p_btn_home.button_up.connect(func(): p_btn_home.position.y -= 8)
	p_btn_home.pressed.connect(_on_home_pressed)
	
	var home_center = CenterContainer.new()
	home_center.custom_minimum_size = Vector2(270, 120)
	var hc_wrap = Control.new()
	hc_wrap.custom_minimum_size = p_btn_home.custom_minimum_size
	hc_wrap.add_child(p_btn_home)
	home_center.add_child(hc_wrap)
	pb_vbox.add_child(home_center)
	
	var p_btn_restart := TextureButton.new()
	p_btn_restart.texture_normal = load("res://assets/btn_restart.png")
	p_btn_restart.stretch_mode = TextureButton.STRETCH_SCALE
	p_btn_restart.custom_minimum_size = Vector2(296, 102)
	p_btn_restart.button_down.connect(func(): p_btn_restart.position.y += 8)
	p_btn_restart.button_up.connect(func(): p_btn_restart.position.y -= 8)
	p_btn_restart.pressed.connect(_on_restart_pressed)
	
	var restart_center = CenterContainer.new()
	restart_center.custom_minimum_size = Vector2(300, 110)
	var rc_wrap = Control.new()
	rc_wrap.custom_minimum_size = p_btn_restart.custom_minimum_size
	rc_wrap.add_child(p_btn_restart)
	restart_center.add_child(rc_wrap)
	pb_vbox.add_child(restart_center)
	
	var p_spacer2 := Control.new()
	p_spacer2.custom_minimum_size = Vector2(0, 4)
	pb_vbox.add_child(p_spacer2)
	
	var p_footer := Label.new()
	p_footer.text = "Terms of Service  &  Privacy Policy"
	p_footer.add_theme_font_size_override("font_size", 18)
	p_footer.add_theme_color_override("font_color", Color("3b82f6"))
	p_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_vbox.add_child(p_footer)


	# ResultOverlay
	result_overlay = Control.new()
	result_overlay.name = "ResultOverlay"
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	result_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(result_overlay)

	var r_bg := ColorRect.new()
	r_bg.color = Color(0, 0, 0, 0.7)
	r_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(r_bg)

	var r_center := CenterContainer.new()
	r_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(r_center)
	
	var r_panel := PanelContainer.new()
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color("e8f4fa")
	r_style.border_width_top = 8
	r_style.border_color = Color("4b7bec")
	r_style.corner_radius_top_left = 24
	r_style.corner_radius_top_right = 24
	r_style.corner_radius_bottom_left = 24
	r_style.corner_radius_bottom_right = 24
	r_panel.add_theme_stylebox_override("panel", r_style)
	r_panel.custom_minimum_size = Vector2(460, 320)
	r_center.add_child(r_panel)
	
	var r_margin := MarginContainer.new()
	r_margin.add_theme_constant_override("margin_left", 32)
	r_margin.add_theme_constant_override("margin_right", 32)
	r_margin.add_theme_constant_override("margin_top", 40)
	r_margin.add_theme_constant_override("margin_bottom", 40)
	r_panel.add_child(r_margin)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 24)
	r_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	r_margin.add_child(r_vbox)

	result_title_label = Label.new()
	result_title_label.text = "LEVEL CLEAR!"
	result_title_label.add_theme_font_size_override("font_size", 42)
	result_title_label.add_theme_color_override("font_color", Color("4b7bec"))
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_vbox.add_child(result_title_label)
	
	# Action Buttons (Home and Restart)
	var r_btn_home := TextureButton.new()
	r_btn_home.texture_normal = load("res://assets/btn_home.png")
	r_btn_home.stretch_mode = TextureButton.STRETCH_SCALE
	r_btn_home.custom_minimum_size = Vector2(264, 118)
	r_btn_home.button_down.connect(func(): r_btn_home.position.y += 8)
	r_btn_home.button_up.connect(func(): r_btn_home.position.y -= 8)
	r_btn_home.pressed.connect(_on_home_pressed)
	
	var r_home_center = CenterContainer.new()
	r_home_center.custom_minimum_size = Vector2(270, 120)
	var rhc_wrap = Control.new()
	rhc_wrap.custom_minimum_size = r_btn_home.custom_minimum_size
	rhc_wrap.add_child(r_btn_home)
	r_home_center.add_child(rhc_wrap)
	r_vbox.add_child(r_home_center)
	
	result_btn = TextureButton.new()
	result_btn.stretch_mode = TextureButton.STRETCH_SCALE
	result_btn.custom_minimum_size = Vector2(296, 102)
	result_btn.button_down.connect(func(): result_btn.position.y += 8)
	result_btn.button_up.connect(func(): result_btn.position.y -= 8)
	result_btn.pressed.connect(_on_restart_pressed)
	
	var r_restart_center = CenterContainer.new()
	r_restart_center.custom_minimum_size = Vector2(300, 110)
	var rrc_wrap = Control.new()
	rrc_wrap.custom_minimum_size = result_btn.custom_minimum_size
	rrc_wrap.add_child(result_btn)
	r_restart_center.add_child(rrc_wrap)
	r_vbox.add_child(r_restart_center)

func _update_layout() -> void:
	if world_root == null:
		return
	var vp := get_viewport()
	var vp_size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(720, 1880)
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	# Calculate scale to fit the board comfortably with some padding
	var board_pixel_width = 7 * 78.0 # 546.0
	var scale_factor = (vp_size.x * 0.95) / board_pixel_width
	
	# If the window is extremely tall (e.g. narrow phone), we might want to clamp scale
	# so it doesn't get ridiculously huge. 
	# Also ensure it fits vertically. The total gameplay area height is roughly 1100 pixels.
	scale_factor = clampf(vp_size.x / 600.0, 0.5, 2.0)
	
	# Keep world centered at (0,0) which is where the Camera2D looks
	world_root.scale = Vector2(scale_factor, scale_factor)
	world_root.position = Vector2.ZERO

	var half_h = (vp_size.y / 2.0) / scale_factor

	# Parking between passenger track and board
	if parking_root != null:
		parking_root.position = Vector2(0, -half_h + 650)

	# Board below parking
	if board_root != null:
		board_root.position = Vector2(0, -half_h + 1050)

	# Passenger track right above the parking
	if passenger_track_root != null:
		passenger_track_root.position = Vector2(0, -half_h + 350)


func _on_restart_pressed() -> void:
	_play_sfx("ui")
	get_tree().paused = false
	var gc = get_tree().root.get_node_or_null("GameController")
	if gc:
		gc.start_level(1)

func _on_home_pressed() -> void:
	_play_sfx("ui")
	get_tree().paused = false
	var gc = get_tree().root.get_node_or_null("GameController")
	if gc:
		gc.goto_scene("res://scenes/main.tscn")

func _on_pause_pressed() -> void:
	_play_sfx("ui")
	get_tree().paused = true
	pause_overlay.visible = true

func _on_resume_pressed() -> void:
	_play_sfx("ui")
	get_tree().paused = false
	pause_overlay.visible = false

func _play_sfx(sfx_name: String) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var am: Node = tree.root.get_node_or_null("AudioManager")
	if am != null and am.has_method("play"):
		am.play(sfx_name)

func _create_settings_icon_button(label_text: String, icon_text: String, is_on: bool, on_toggle: Callable) -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(96, 96)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("4b7bec")
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_bottom = 6
	style.border_color = Color("3867d6")
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	var icon = Label.new()
	icon.text = icon_text
	icon.add_theme_font_size_override("font_size", 48)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(icon)
	
	var slash = ColorRect.new()
	slash.color = Color("eb3b5a")
	slash.size = Vector2(100, 8)
	slash.pivot_offset = Vector2(50, 4)
	slash.position = Vector2(-2, 44)
	slash.rotation = deg_to_rad(45)
	slash.visible = not is_on
	btn.add_child(slash)
	
	var state = {"on": is_on}
	btn.pressed.connect(func():
		_play_sfx("ui")
		state.on = not state.on
		slash.visible = not state.on
		on_toggle.call(state.on)
	)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color("64748b"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	vbox.add_child(btn)
	vbox.add_child(lbl)
	
	return vbox
