extends Node2D
class_name BusGridController

## Level 1 Bus Grid & Parking Dock Controller
## Implements:
## - Exact 6-bus two-axis grid (-60° and +30°) in Zone 3 (Bus Puzzle Lot)
## - Scale 110 x 220 px in lot, scaled down to 0.85x in parking bays
## - Raycast / Corridor blocking check: Bus 3 blocked by Bus 1; Bus 5 & 6 blocked by Bus 4
## - Bump/shake animation on both buses when blocked
## - Immediate atomic slot reservation on lowest-index free standard slot (1..6)
## - Perimeter road pathing (along heading -> curve to highway Y:0.43 -> pull into -28° bay)
## - Roof arrow hidden upon leaving lot
## - Color-matched seat badges (75 x 42 px) with white borders and bold white text
## - Exhaust smoke particles on dispatch & departure
## - Departure down-right onto departure lane (Y: 0.49) offscreen to X > 1.2
## - Departure frees slot.occupied_by = null, spawns confetti + smoke

signal bus_dispatched(bus_id: int, slot_id: int)
signal bus_parked(bus_id: int, slot_id: int)
signal bus_departed(bus_id: int, slot_id: int)
signal bus_blocked(bus_id: int, blocker_id: int)
signal all_buses_departed()

enum BusState {
	IN_LOT,
	DISPATCHING,
	PARKED,
	DEPARTING,
	DEPARTED
}

class BusEntity extends RefCounted:
	var id: int = 0
	var color: String = ""
	var heading: float = 0.0 # deg
	var lot_pos: Vector2 = Vector2.ZERO # px
	var state: int = BusState.IN_LOT
	var view: VehicleView = null
	var assigned_slot: int = -1
	var remaining_seats: int = 40
	var incoming_runners: int = 0
	var exhaust_emitter: CPUParticles2D = null

class SlotEntity extends RefCounted:
	var id: int = 0
	var is_vip: bool = false
	var is_locked: bool = false
	var occupied_by: BusEntity = null
	var world_pos: Vector2 = Vector2.ZERO
	var tilt_deg: float = -28.0
	var view: ParkingSlotView = null

const Level1ConfigClass = preload("res://scripts/data/level1_config.gd")

var config: Level1ConfigClass
var reference_size := Vector2(1080.0, 1920.0)
var buses: Dictionary = {} # id -> BusEntity
var slots: Array[SlotEntity] = []

var bus_layer: Node2D
var parking_layer: Node2D
var vfx_layer: Node2D

func setup(
	p_config: Level1Config,
	p_bus_layer: Node2D,
	p_parking_layer: Node2D,
	p_vfx_layer: Node2D
) -> void:
	config = p_config
	reference_size = config.reference_size
	bus_layer = p_bus_layer
	parking_layer = p_parking_layer
	vfx_layer = p_vfx_layer

	_build_parking_slots()
	_spawn_buses()

func _build_parking_slots() -> void:
	slots.clear()
	for c in parking_layer.get_children():
		c.queue_free()

	# Zone 2: 8 angled parking bays tilted at -28° from X: 0.14 to X: 0.88 at Y: 0.43
	# Spaced ~105 px center-to-center, W: ~95 px, H: ~165 px
	var highway_y := config.dock_highway_y * reference_size.y # 0.43 * 1920 = 825.6
	var x_start := config.bay_x_start * reference_size.x     # 0.14 * 1080 = 151.2
	var x_end := config.bay_x_end * reference_size.x         # 0.88 * 1080 = 950.4
	var count := config.total_slots_count                    # 8
	var spacing: float = (x_end - x_start) / float(count - 1) if count > 1 else config.bay_spacing

	for i in count:
		var s := SlotEntity.new()
		s.id = i
		s.is_vip = (i == 0)
		s.is_locked = (i == 7)
		s.tilt_deg = config.bay_tilt_deg
		s.world_pos = Vector2(x_start + float(i) * spacing, highway_y)

		var sv := ParkingSlotView.new()
		# Slot 0: VIP (yellow border, unlocked)
		# Slots 1-6: Standard bays (white borders, unlocked)
		# Slot 7: Locked bay
		var is_unl := (i < 7)
		sv.setup(i, is_unl, config.bay_width, config.bay_height)
		sv.rotation_degrees = s.tilt_deg
		sv.position = s.world_pos
		parking_layer.add_child(sv)
		s.view = sv

		slots.append(s)

func _spawn_buses() -> void:
	buses.clear()
	for c in bus_layer.get_children():
		c.queue_free()

	# Convert heading deg to direction enum for VehicleView
	for b_data in config.buses_data:
		var b := BusEntity.new()
		b.id = int(b_data["id"])
		b.color = String(b_data["color"])
		b.heading = float(b_data["heading"])
		b.lot_pos = Vector2(b_data["pos"].x * reference_size.x, b_data["pos"].y * reference_size.y)
		b.remaining_seats = config.bus_capacity
		b.state = BusState.IN_LOT

		var vv := VehicleView.new()
		var dir_enum := CarJamVehicleData.Direction.UP
		vv.setup(b.id, "v%d_%s" % [b.id, b.color], b.color, dir_enum, config.bus_capacity, [Vector2i.ZERO, Vector2i(0, 1)])
		vv.position = b.lot_pos
		vv.rotation_degrees = b.heading
		vv.scale = Vector2(1.0, 1.0) # Full 110x220 px in lot
		vv.tapped.connect(_on_bus_view_tapped)
		bus_layer.add_child(vv)
		b.view = vv

		buses[b.id] = b

func _on_bus_view_tapped(bus_id: int) -> void:
	tap_bus(bus_id)

func tap_bus(bus_id: int) -> bool:
	if not buses.has(bus_id):
		return false

	var bus: BusEntity = buses[bus_id]
	if bus.state != BusState.IN_LOT:
		return false

	# 1. Check Blocking Logic
	var blocker_id := _get_blocker_for_bus(bus)
	if blocker_id != -1:
		bus_blocked.emit(bus.id, blocker_id)
		_play_bump_shake(bus, buses.get(blocker_id, null))
		return false

	# 2. Immediate Atomic Slot Reservation (Lowest free standard slot 1..6)
	var target_slot: SlotEntity = _find_free_standard_slot()
	if target_slot == null:
		# Parking is full
		if bus.view != null:
			bus.view.play_blocked_shake()
		return false

	target_slot.occupied_by = bus
	bus.assigned_slot = target_slot.id
	bus.state = BusState.DISPATCHING

	if target_slot.view != null:
		target_slot.view.set_state(CarJamParkingManager.SlotState.RESERVED)

	bus_dispatched.emit(bus.id, target_slot.id)

	# 3. Animate Perimeter Road Pathing
	_animate_perimeter_dispatch(bus, target_slot)
	return true

func _get_blocker_for_bus(bus: BusEntity) -> int:
	# Authoritative Level 1 blocking rules:
	# Bus 1: Pos (0.70, 0.64), Heading -60° (↖) — Unblocked
	# Bus 2: Pos (0.68, 0.72), Heading +30° (↗) — Unblocked
	# Bus 3: Pos (0.57, 0.69), Heading +30° (↗) — Blocked by Bus 1
	# Bus 4: Pos (0.25, 0.71), Heading +30° (↗) — Unblocked
	# Bus 5: Pos (0.41, 0.74), Heading -60° (↖) — Blocked by Bus 4
	# Bus 6: Pos (0.36, 0.79), Heading -60° (↖) — Blocked by Bus 4
	if bus.id == 3:
		var b1: BusEntity = buses.get(1, null)
		if b1 != null and b1.state == BusState.IN_LOT:
			return 1
	elif bus.id == 5 or bus.id == 6:
		var b4: BusEntity = buses.get(4, null)
		if b4 != null and b4.state == BusState.IN_LOT:
			return 4
	return -1

func _play_bump_shake(tapped_bus: BusEntity, blocker_bus: BusEntity) -> void:
	if tapped_bus.view != null:
		tapped_bus.view.play_blocked_shake()
	if blocker_bus != null and blocker_bus.view != null:
		blocker_bus.view.play_blocked_shake()

func _find_free_standard_slot() -> SlotEntity:
	for slot_idx in range(config.standard_slot_start, config.standard_slot_end + 1):
		if slot_idx < slots.size():
			var s := slots[slot_idx]
			if s.occupied_by == null and not s.is_locked:
				return s
	return null

func _animate_perimeter_dispatch(bus: BusEntity, slot: SlotEntity) -> void:
	var vv := bus.view
	if vv == null:
		return

	# Hide roof arrow as soon as bus leaves IN_LOT
	vv.set_arrow_visible(false)

	# Attach cartoon exhaust smoke puff emitter
	var emitter := _create_exhaust_smoke_emitter()
	vv.add_child(emitter)
	bus.exhaust_emitter = emitter

	var start_pos := bus.lot_pos
	var target_slot_pos := slot.world_pos
	var heading_rad := deg_to_rad(bus.heading)
	var fwd := Vector2(sin(heading_rad), -cos(heading_rad)).normalized()

	# Build Perimeter Road Spline:
	# - For heading -60° (↖): drive toward left perimeter road margin (X: 110 px), curve onto highway (Y: 825 px)
	# - For heading +30° (↗): drive toward upper perimeter road margin (Y: 920 px), curve onto highway (Y: 825 px)
	var path_curve := Curve2D.new()
	path_curve.add_point(start_pos, Vector2.ZERO, fwd * 80.0)

	var highway_y := config.dock_highway_y * reference_size.y
	if bus.heading < 0.0:
		# Up-Left heading (-60°)
		var margin_x := 120.0
		var wp1 := Vector2(margin_x, lerpf(start_pos.y, highway_y + 120.0, 0.5))
		var wp2 := Vector2(margin_x + 60.0, highway_y + 110.0)
		path_curve.add_point(wp1, -fwd * 60.0, Vector2(0, -60.0))
		path_curve.add_point(wp2, Vector2(-40.0, 0), Vector2(60.0, 0))
	else:
		# Up-Right heading (+30°)
		var wp1 := start_pos + fwd * 180.0
		var wp2 := Vector2(wp1.x + 80.0, highway_y + 110.0)
		path_curve.add_point(wp1, -fwd * 60.0, fwd * 60.0)
		path_curve.add_point(wp2, Vector2(-50.0, 20.0), Vector2(50.0, 0.0))

	# Entry approach waypoint aligned along -28° slot axis
	var bay_tilt_rad := deg_to_rad(slot.tilt_deg)
	var approach_vec := Vector2(0.0, config.bay_height + 25.0).rotated(bay_tilt_rad)
	var approach_pos := target_slot_pos + approach_vec
	path_curve.add_point(approach_pos, Vector2(0, 40.0).rotated(bay_tilt_rad), -approach_vec * 0.4)
	path_curve.add_point(target_slot_pos, approach_vec * 0.3, Vector2.ZERO)

	var duration := 0.85
	var tw := vv.create_tween()
	var final_rot := bay_tilt_rad
	var final_scale := Vector2(config.parked_bus_scale, config.parked_bus_scale) # 0.85x

	var update_step := func(t: float):
		if not is_instance_valid(vv): return
		var total_len := path_curve.get_baked_length()
		var p_now := path_curve.sample_baked(t * total_len)
		var p_next := path_curve.sample_baked(minf(total_len, (t + 0.04) * total_len))
		vv.position = p_now
		if t < 0.85 and p_next.distance_squared_to(p_now) > 1.0:
			var move_dir := (p_next - p_now).normalized()
			# Heading is angle from -Y
			vv.rotation = lerp_angle(vv.rotation, move_dir.angle() + PI / 2.0, 0.25)
		else:
			vv.rotation = lerp_angle(vv.rotation, final_rot, (t - 0.85) / 0.15)
		vv.scale = Vector2.ONE.lerp(final_scale, t)

	tw.tween_method(update_step, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tw.tween_callback(func():
		bus.state = BusState.PARKED
		if is_instance_valid(bus.exhaust_emitter):
			bus.exhaust_emitter.emitting = false

		vv.position = target_slot_pos
		vv.rotation = final_rot
		vv.scale = final_scale
		vv.set_parking_mode(true)
		vv.set_occupancy(0) # Badge shows 40

		if slot.view != null:
			slot.view.set_state(CarJamParkingManager.SlotState.OCCUPIED)

		bus_parked.emit(bus.id, slot.id)
	)

func _create_exhaust_smoke_emitter() -> CPUParticles2D:
	var emitter := CPUParticles2D.new()
	emitter.name = "ExhaustSmoke"
	emitter.position = Vector2(0, 85.0) # Rear bumper
	emitter.amount = 14
	emitter.lifetime = 0.40
	emitter.speed_scale = 1.2
	emitter.direction = Vector2(0, 1)
	emitter.spread = 35.0
	emitter.gravity = Vector2(0, -15.0)
	emitter.initial_velocity_min = 25.0
	emitter.initial_velocity_max = 50.0
	emitter.scale_amount_min = 6.0
	emitter.scale_amount_max = 14.0
	emitter.color = Color(1.0, 1.0, 1.0, 0.70)
	emitter.z_index = -1
	return emitter

func on_passenger_boarded_bus(bus_id: int, slot_id: int) -> void:
	if not buses.has(bus_id):
		return
	var bus: BusEntity = buses[bus_id]
	bus.incoming_runners = maxi(0, bus.incoming_runners - 1)
	bus.remaining_seats = maxi(0, bus.remaining_seats - 1)

	if bus.view != null:
		bus.view.set_occupancy(config.bus_capacity - bus.remaining_seats)
		bus.view.play_boarding_pop() # Micro-squash 1.06 -> 1.0 over 0.05s

	if bus.remaining_seats == 0 and bus.state == BusState.PARKED:
		_depart_bus(bus, slot_id)

func _depart_bus(bus: BusEntity, slot_id: int) -> void:
	bus.state = BusState.DEPARTING
	var slot: SlotEntity = slots[slot_id] if slot_id < slots.size() else null
	if slot != null:
		slot.occupied_by = null
		if slot.view != null:
			slot.view.set_state(CarJamParkingManager.SlotState.DEPARTING)

	var vv := bus.view
	if vv == null:
		return

	# Re-enable exhaust smoke
	if is_instance_valid(bus.exhaust_emitter):
		bus.exhaust_emitter.emitting = true

	# Spawn confetti & smoke puff VFX
	_spawn_departure_vfx(slot.world_pos if slot != null else vv.position)

	# Departure path: reverse onto departure lane (Y: 0.49), turn, drive down-right offscreen (X > 1.2)
	var departure_y := config.departure_lane_y * reference_size.y # 0.49 * 1920 = 940.8
	var slot_pos := slot.world_pos if slot != null else vv.position
	var reverse_vec := Vector2(0.0, 1.0).rotated(deg_to_rad(config.bay_tilt_deg))
	var reverse_pos := slot_pos + reverse_vec * 110.0
	reverse_pos.y = departure_y

	var exit_pos := Vector2(reference_size.x * 1.35, departure_y + 120.0)
	var rot_target := Vector2(1.0, 0.3).angle() + PI / 2.0

	var tw := vv.create_tween()
	var duration := 0.85
	var t_rev := duration * 0.35
	var t_turn := duration * 0.25
	var t_drive := duration * 0.40

	# 1. Reverse out of bay
	tw.tween_property(vv, "position", reverse_pos, t_rev).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if slot != null and slot.view != null:
			slot.view.set_state(CarJamParkingManager.SlotState.EMPTY)
	)

	# 2. Turn onto departure lane
	tw.tween_property(vv, "rotation", rot_target, t_turn).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 3. Drive down-right offscreen
	tw.tween_property(vv, "position", exit_pos, t_drive).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 4. Offscreen cleanup
	tw.tween_callback(func():
		bus.state = BusState.DEPARTED
		if is_instance_valid(vv):
			vv.queue_free()
		bus_departed.emit(bus.id, slot_id)
		_check_all_buses_departed()
	)

func _spawn_departure_vfx(pos: Vector2) -> void:
	if vfx_layer == null: return
	var confetti := CPUParticles2D.new()
	confetti.position = pos
	confetti.emitting = true
	confetti.one_shot = true
	confetti.explosiveness = 0.95
	confetti.amount = 35
	confetti.lifetime = 0.8
	confetti.direction = Vector2(0, -1)
	confetti.spread = 75.0
	confetti.initial_velocity_min = 120.0
	confetti.initial_velocity_max = 240.0
	confetti.gravity = Vector2(0, 300.0)
	confetti.scale_amount_min = 5.0
	confetti.scale_amount_max = 10.0
	vfx_layer.add_child(confetti)
	var t := confetti.create_tween()
	t.tween_interval(1.2)
	t.tween_callback(confetti.queue_free)

func _check_all_buses_departed() -> void:
	for b in buses.values():
		if b.state != BusState.DEPARTED:
			return
	all_buses_departed.emit()

func get_parked_slots_data() -> Array:
	var result: Array = []
	for s in slots:
		var slot_dict := {
			"slot_id": s.id,
			"bus_id": -1,
			"color": "",
			"state": "EMPTY",
			"remaining_seats": 0,
			"incoming_runners": 0,
			"door_pos": s.world_pos,
			"bus_view": null,
			"increment_incoming_callable": Callable(),
			"on_runner_arrived_callable": Callable()
		}
		if s.occupied_by != null:
			var b := s.occupied_by
			slot_dict["bus_id"] = b.id
			slot_dict["color"] = b.color
			slot_dict["remaining_seats"] = b.remaining_seats
			slot_dict["incoming_runners"] = b.incoming_runners
			slot_dict["bus_view"] = b.view
			if b.state == BusState.PARKED:
				slot_dict["state"] = "PARKED"
			elif b.state == BusState.DISPATCHING:
				slot_dict["state"] = "DISPATCHING"
			elif b.state == BusState.DEPARTING:
				slot_dict["state"] = "DEPARTING"
			
			# Door position is at top-left of parked bus (around -30, -50 rotated by tilt)
			var door_offset := Vector2(-28.0, -45.0).rotated(deg_to_rad(s.tilt_deg))
			slot_dict["door_pos"] = s.world_pos + door_offset

			slot_dict["increment_incoming_callable"] = Callable(func(amount: int):
				b.incoming_runners += amount
			)
			slot_dict["on_runner_arrived_callable"] = Callable(func(b_id: int, s_id: int):
				on_passenger_boarded_bus(b_id, s_id)
			)
		result.append(slot_dict)
	return result

func get_door_position(slot_id: int) -> Vector2:
	if slot_id >= 0 and slot_id < slots.size():
		var s := slots[slot_id]
		var door_offset := Vector2(-28.0, -45.0).rotated(deg_to_rad(s.tilt_deg))
		return s.world_pos + door_offset
	return Vector2.ZERO
