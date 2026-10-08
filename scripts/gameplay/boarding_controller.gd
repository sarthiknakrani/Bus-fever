extends RefCounted
class_name CarJamBoardingController

## Single authoritative boarding scheduler.
## Serializes passenger transfers from the queue head to matching parked vehicles.
## Strictly enforces queue-order priority and earliest-slot allocation.

signal boarding_executed(vehicle_id: int, slot_id: int, color_id: String, count: int)
signal vehicle_filled(vehicle_id: int, slot_id: int)

## Evaluates and executes all legal boardings atomically.
## Returns an array of event dictionaries: { vehicle_id, slot_id, color_id, count, is_full }.
func evaluate_boarding(queue: CarJamPassengerQueue, parking: CarJamParkingManager, vehicles: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var progress := true

	while progress:
		progress = false
		var head_group := queue.get_head_group()
		if head_group == null:
			break

		var head_color := head_group.color_id

		# Find earliest parked vehicle matching head_color with free capacity
		var target_vehicle: VehicleModel = null
		var target_slot_id: int = -1

		for i in parking.get_slot_count():
			var slot := parking.get_slot(i)
			if slot == null or slot.state != CarJamParkingManager.SlotState.OCCUPIED:
				continue

			var v: VehicleModel = vehicles.get(slot.vehicle_id, null)
			if v == null:
				continue

			if v.color_id == head_color and v.remaining_capacity() > 0:
				target_vehicle = v
				target_slot_id = slot.slot_id
				break # Prioritize earliest slot

		if target_vehicle == null:
			# Non-matching queue head cannot board! Never skip.
			break

		# Calculate transfer count
		var needed := target_vehicle.remaining_capacity()
		var available := head_group.remaining_count
		var transfer_count := mini(needed, available)

		if transfer_count <= 0:
			break

		# Execute atomic logical transfer
		var actual_consumed := queue.consume_head(transfer_count)
		var actual_boarded := target_vehicle.board(actual_consumed)

		var was_filled := target_vehicle.is_full()
		if was_filled:
			target_vehicle.state = VehicleModel.VehicleState.FULL

		var evt := {
			"vehicle_id": target_vehicle.id,
			"slot_id": target_slot_id,
			"color_id": head_color,
			"count": actual_boarded,
			"is_full": was_filled
		}
		events.append(evt)
		boarding_executed.emit(target_vehicle.id, target_slot_id, head_color, actual_boarded)
		if was_filled:
			vehicle_filled.emit(target_vehicle.id, target_slot_id)

		progress = true

	return events
