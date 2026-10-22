class_name PlatformSlotDef
extends Resource

## Authoritative definition of a bus placement slot on a puzzle platform.
## Holds exact physical position, rotation, escape direction, and collision geometry.

@export var slot_id: int = 0
@export var position: Vector2 = Vector2.ZERO
@export var rotation: float = 0.0 # Heading in radians (0 = Vector2(1, 0) / RIGHT, -PI/2 = UP)
@export var escape_direction: Vector2 = Vector2(0, -1) # Unit vector for legal escape route
@export var length: float = 86.0
@export var width: float = 42.0

# Assigned vehicle properties
@export var assigned_vehicle_id: int = -1
@export var assigned_color_id: String = "blue"
@export var assigned_capacity: int = 40
@export var is_mystery: bool = false
@export var grid_anchor: Vector2i = Vector2i.ZERO # For GRID mode backward compatibility
@export var grid_footprint: Array[Vector2i] = [Vector2i.ZERO]

## Returns the 4 corners of the oriented bounding box in platform-local coordinates.
func get_obb_vertices(margin: float = 0.0) -> PackedVector2Array:
	return BusCollisionGeometry.get_obb_vertices(position, rotation, length, width, margin)

## Returns the unit vector along the bus's forward heading.
func get_forward_vector() -> Vector2:
	return Vector2(cos(rotation), sin(rotation))

## Returns the swept convex polygon along its legal escape direction out to escape_distance.
func get_swept_polygon(escape_distance: float = 380.0) -> PackedVector2Array:
	var dir := escape_direction
	if dir.length_squared() < 0.0001:
		dir = get_forward_vector()
	return BusCollisionGeometry.compute_swept_polygon(position, rotation, length, width, dir.normalized(), escape_distance)

func clone() -> PlatformSlotDef:
	var c := PlatformSlotDef.new()
	c.slot_id = slot_id
	c.position = position
	c.rotation = rotation
	c.escape_direction = escape_direction
	c.length = length
	c.width = width
	c.assigned_vehicle_id = assigned_vehicle_id
	c.assigned_color_id = assigned_color_id
	c.assigned_capacity = assigned_capacity
	c.is_mystery = is_mystery
	c.grid_anchor = grid_anchor
	c.grid_footprint = grid_footprint.duplicate()
	return c
