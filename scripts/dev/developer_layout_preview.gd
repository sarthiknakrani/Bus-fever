extends Node2D
class_name DeveloperLayoutPreview

## Lightweight Developer-Only Platform Preview.
## Visualizes new platform layout formations, exact physical OBB footprints,
## escape vectors, real-time blocking relationships, and solver status.
## Completely isolated from shipped Level 1 and Level 2 scenes.

var current_template_index: int = 0
var current_platform: PlatformGeometry = null
var current_solver_result: Dictionary = {}
var template_list: Array[Dictionary] = [
	{
		"name": "Concentric Rings",
		"type": PlatformGeometry.LayoutType.CONCENTRIC_RINGS,
		"params": {"radii": [95.0, 175.0]}
	},
	{
		"name": "Diagonal Bands",
		"type": PlatformGeometry.LayoutType.DIAGONAL_BANDS,
		"params": {"angle_degrees": 35.0, "num_bands": 3, "buses_per_band": 3}
	},
	{
		"name": "Nested Rounded Rectangles",
		"type": PlatformGeometry.LayoutType.NESTED_RECTANGLES,
		"params": {
			"layers": [
				{"w": 200.0, "h": 140.0, "r": 28.0},
				{"w": 360.0, "h": 260.0, "r": 45.0}
			]
		}
	},
	{
		"name": "U-Shaped Horseshoe",
		"type": PlatformGeometry.LayoutType.U_SHAPED,
		"params": {}
	},
	{
		"name": "Spiral Formation",
		"type": PlatformGeometry.LayoutType.SPIRAL,
		"params": {}
	},
	{
		"name": "Rectangular Packed",
		"type": PlatformGeometry.LayoutType.RECTANGULAR_PACKED,
		"params": {"rows": 3, "cols": 4, "stagger": true}
	},
	{
		"name": "Irregular Cluster",
		"type": PlatformGeometry.LayoutType.IRREGULAR_CLUSTERS,
		"params": {}
	}
]

var inspected_slot_id: int = -1
var ui_label: Label = null

func _ready() -> void:
	_setup_ui()
	load_template(0)

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	ui_label = Label.new()
	ui_label.name = "DevPreviewHUD"
	ui_label.position = Vector2(24, 24)
	ui_label.add_theme_font_size_override("font_size", 16)
	ui_label.modulate = Color(0.95, 0.95, 1.0)
	canvas.add_child(ui_label)

func load_template(index: int) -> void:
	current_template_index = index % template_list.size()
	var def: Dictionary = template_list[current_template_index]
	current_platform = PlatformLayoutGenerator.generate_layout(def["type"], def["params"], 12345)
	current_solver_result = FreeformPuzzleSolver.solve_platform(current_platform, 4)
	_update_hud()
	queue_redraw()

func _update_hud() -> void:
	if ui_label == null or current_platform == null:
		return

	var def: Dictionary = template_list[current_template_index]
	var bg_res := FreeformPuzzleSolver.compute_blocking_graph(current_platform)
	var accessible: Array = bg_res["accessible_ids"]
	var status_str := "INCONCLUSIVE"
	if current_solver_result.get("status") == FreeformPuzzleSolver.SolvabilityStatus.SOLVABLE:
		status_str = "SOLVABLE (%d moves)" % current_solver_result.get("moves", []).size()
	elif current_solver_result.get("status") == FreeformPuzzleSolver.SolvabilityStatus.UNSOLVABLE:
		status_str = "UNSOLVABLE"

	ui_label.text = "[DEV PREVIEW] %s\n" % def["name"]
	ui_label.text += "Mode: FREEFORM | Seed: %d\n" % current_platform.deterministic_seed
	ui_label.text += "Buses Placed: %d | Accessible Initial: %d\n" % [current_platform.slots.size(), accessible.size()]
	ui_label.text += "Puzzle Solver: %s\n" % status_str
	ui_label.text += "Controls: [SPACE / CLICK] Next Template\n"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		load_template(current_template_index + 1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		load_template(current_template_index + 1)

func _draw() -> void:
	if current_platform == null:
		return

	# 1. Draw platform playable bounds
	var bounds := current_platform.playable_bounds
	draw_rect(bounds, Color(0.18, 0.22, 0.26, 0.6), true)
	draw_rect(bounds, Color(0.4, 0.6, 0.8, 0.8), false, 2.0)

	var bg_res := FreeformPuzzleSolver.compute_blocking_graph(current_platform)
	var accessible: Array = bg_res["accessible_ids"]
	var graph: Dictionary = bg_res["blocking_graph"]

	# 2. Draw slots and buses
	for s in current_platform.slots:
		var is_acc: bool = accessible.has(s.assigned_vehicle_id)
		var obb := s.get_obb_vertices()
		var col_fill := CarJamVehicleData.color_to_rgb(s.assigned_color_id)
		col_fill.a = 0.85

		# Draw bus body OBB
		draw_colored_polygon(obb, col_fill)
		var stroke_color := Color(0.2, 0.9, 0.4) if is_acc else Color(0.9, 0.3, 0.3)
		draw_polyline(PackedVector2Array([obb[0], obb[1], obb[2], obb[3], obb[0]]), stroke_color, 2.5)

		# Draw forward/escape arrow
		var arrow_start := s.position
		var arrow_end := s.position + (s.escape_direction.normalized() * 32.0)
		draw_line(arrow_start, arrow_end, stroke_color, 3.0)
		# Arrow tip
		var arrow_tan := s.escape_direction.normalized()
		var arrow_norm := Vector2(-arrow_tan.y, arrow_tan.x)
		var tip_left := arrow_end - (arrow_tan * 8.0) + (arrow_norm * 6.0)
		var tip_right := arrow_end - (arrow_tan * 8.0) - (arrow_norm * 6.0)
		draw_colored_polygon(PackedVector2Array([arrow_end, tip_left, tip_right]), stroke_color)

		# Draw Bus ID & Blocker info
		var blockers: Array = graph.get(s.assigned_vehicle_id, [])
		var label_text := "#%d" % s.assigned_vehicle_id
		if not blockers.is_empty():
			var b_strs: Array[String] = []
			for bid in blockers: b_strs.append(str(bid))
			label_text += " [x:%s]" % ",".join(b_strs)
		draw_string(ThemeDB.fallback_font, s.position + Vector2(-16, 4), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)

	# 3. Draw inspected swept escape corridor if active
	if inspected_slot_id != -1:
		var target := current_platform.get_slot_by_vehicle_id(inspected_slot_id)
		if target != null:
			var swept := target.get_swept_polygon(380.0)
			draw_colored_polygon(swept, Color(1.0, 1.0, 0.2, 0.25))
			draw_polyline(swept, Color(1.0, 1.0, 0.2, 0.8), 1.5)
