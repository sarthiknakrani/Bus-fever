class_name PlatformGeometry
extends Resource

## Data-Driven Puzzle Platform Definition.
## Decouples platform geometry, playable boundaries, and slot placement templates
## from individual bus data, supporting both GRID MODE and FREEFORM MODE.

enum Mode {
	GRID,
	FREEFORM
}

enum LayoutType {
	RECTANGULAR_PACKED,
	CONCENTRIC_RINGS,
	NESTED_RECTANGLES,
	U_SHAPED,
	SPIRAL,
	DIAGONAL_BANDS,
	IRREGULAR_CLUSTERS
}

@export var mode: int = Mode.FREEFORM
@export var layout_type: int = LayoutType.RECTANGULAR_PACKED
@export var title: String = "Platform Layout"
@export var playable_bounds: Rect2 = Rect2(-240.0, -240.0, 480.0, 480.0)
@export var boundary_polygon: PackedVector2Array = []
@export var bus_length: float = BusCollisionGeometry.DEFAULT_BUS_LENGTH
@export var bus_width: float = BusCollisionGeometry.DEFAULT_BUS_WIDTH
@export var min_clearance: float = BusCollisionGeometry.DEFAULT_MIN_CLEARANCE
@export var deterministic_seed: int = 12345
@export var exit_boundary_radius: float = 380.0
@export var slots: Array[PlatformSlotDef] = []

## Helper to create a rectangular boundary polygon matching playable_bounds.
func setup_default_boundary() -> void:
	if boundary_polygon.is_empty():
		boundary_polygon = PackedVector2Array([
			playable_bounds.position,
			Vector2(playable_bounds.position.x + playable_bounds.size.x, playable_bounds.position.y),
			playable_bounds.position + playable_bounds.size,
			Vector2(playable_bounds.position.x, playable_bounds.position.y + playable_bounds.size.y)
		])

func add_slot(slot: PlatformSlotDef) -> void:
	slots.append(slot)

func get_slot_by_vehicle_id(vehicle_id: int) -> PlatformSlotDef:
	for s in slots:
		if s.assigned_vehicle_id == vehicle_id:
			return s
	return null

func get_slot_count() -> int:
	return slots.size()

## Validates that every placed slot is collision-free and respects min_clearance.
func validate_physical_placements() -> Dictionary:
	var overlaps: Array[Dictionary] = []
	var n := slots.size()

	for i in range(n):
		var a := slots[i]
		# 1. Bounds check
		if not boundary_polygon.is_empty():
			if not BusCollisionGeometry.is_obb_inside_bounds(a.position, a.rotation, a.length, a.width, boundary_polygon):
				overlaps.append({
					"type": "out_of_bounds",
					"slot_a": a.slot_id,
					"slot_b": -1
				})

		# 2. Pairwise OBB overlap check
		for j in range(i + 1, n):
			var b := slots[j]
			var is_overlap := BusCollisionGeometry.test_obb_overlap(
				a.position, a.rotation, a.length, a.width,
				b.position, b.rotation, b.length, b.width,
				min_clearance
			)
			if is_overlap:
				overlaps.append({
					"type": "bus_collision",
					"slot_a": a.slot_id,
					"slot_b": b.slot_id
				})

	return {
		"is_valid": overlaps.is_empty(),
		"overlaps": overlaps,
		"slot_count": n
	}

func clone() -> PlatformGeometry:
	var c := PlatformGeometry.new()
	c.mode = mode
	c.layout_type = layout_type
	c.title = title
	c.playable_bounds = playable_bounds
	c.boundary_polygon = boundary_polygon.duplicate()
	c.bus_length = bus_length
	c.bus_width = bus_width
	c.min_clearance = min_clearance
	c.deterministic_seed = deterministic_seed
	c.exit_boundary_radius = exit_boundary_radius
	for s in slots:
		c.slots.append(s.clone())
	return c
