class_name FreeformPuzzleSolver
extends RefCounted

## Continuous Geometric Swept-Escape Evaluator and Deterministic BFS Puzzle Solver.
## Handles arbitrary-angle and curved platform formations without grid restrictions.
## Computes exact physical blocking relationships, diagnostic graphs, and full
## solution paths accounting for parking bay capacity and passenger color demand.

enum SolvabilityStatus {
	SOLVABLE,
	UNSOLVABLE,
	INCONCLUSIVE
}

## Evaluates swept escape for a single bus on a platform.
## Returns { "can_escape": bool, "blockers": Array[int], "swept_poly": PackedVector2Array }
static func check_bus_escape(
	target_slot: PlatformSlotDef,
	all_slots: Array[PlatformSlotDef],
	active_vehicle_ids: Array[int],
	escape_distance: float = 450.0
) -> Dictionary:
	var swept_poly := target_slot.get_swept_polygon(escape_distance)
	var blockers: Array[int] = []

	for s in all_slots:
		if s.slot_id == target_slot.slot_id:
			continue
		if not active_vehicle_ids.has(s.assigned_vehicle_id):
			continue # Already departed or not on platform

		var blocker_obb := s.get_obb_vertices()
		# Fast SAT check between target's swept polygon and other bus's OBB
		if BusCollisionGeometry.test_polygon_overlap(swept_poly, blocker_obb):
			blockers.append(s.assigned_vehicle_id)

	return {
		"can_escape": blockers.is_empty(),
		"blockers": blockers,
		"swept_poly": swept_poly
	}

## Computes the authoritative blocking graph for all active buses on the platform.
## Returns { "blocking_graph": Dictionary, "accessible_ids": Array[int] }
static func compute_blocking_graph(
	plat: PlatformGeometry,
	active_vehicle_ids: Array = []
) -> Dictionary:
	var typed_active: Array[int] = []
	if active_vehicle_ids.is_empty():
		for s in plat.slots:
			typed_active.append(s.assigned_vehicle_id)
	else:
		for v in active_vehicle_ids:
			typed_active.append(int(v))

	var graph: Dictionary = {}
	var accessible: Array[int] = []

	for s in plat.slots:
		if not typed_active.has(s.assigned_vehicle_id):
			continue
		var res := check_bus_escape(s, plat.slots, typed_active, plat.exit_boundary_radius + 100.0)
		graph[s.assigned_vehicle_id] = res["blockers"]
		if res["can_escape"]:
			accessible.append(s.assigned_vehicle_id)

	return {
		"blocking_graph": graph,
		"accessible_ids": accessible
	}

## Solves the puzzle formation deterministically using BFS state-space search.
## Simulates circulating oval passenger demand and parking bay capacity.
static func solve_platform(
	plat: PlatformGeometry,
	parking_capacity: int = 4,
	passenger_queue: Array[String] = [],
	max_states: int = 5000
) -> Dictionary:
	if plat == null or plat.slots.is_empty():
		return {"status": SolvabilityStatus.INCONCLUSIVE, "moves": [], "initial_moves": 0}

	# Initial check
	var initial_bg := compute_blocking_graph(plat)
	var initial_accessible: Array = initial_bg["accessible_ids"]
	if initial_accessible.is_empty():
		return {
			"status": SolvabilityStatus.UNSOLVABLE,
			"moves": [],
			"initial_moves": 0,
			"blocking_graph": initial_bg["blocking_graph"]
		}

	# Build passenger color counts pool
	var color_pool: Dictionary = {}
	if not passenger_queue.is_empty():
		for col in passenger_queue:
			color_pool[col] = color_pool.get(col, 0) + 1
	else:
		for s in plat.slots:
			color_pool[s.assigned_color_id] = color_pool.get(s.assigned_color_id, 0) + 1

	var initial_active: Array = []
	for s in plat.slots:
		initial_active.append(s.assigned_vehicle_id)
	initial_active.sort()

	var start_state := {
		"active": initial_active,
		"parked": [],
		"pool": color_pool.duplicate(),
		"history": []
	}

	var queue: Array[Dictionary] = [start_state]
	var visited := {}
	visited[_hash_state(initial_active, [], 0)] = true
	var states_evaluated := 0

	while not queue.is_empty():
		states_evaluated += 1
		if states_evaluated > max_states:
			return {
				"status": SolvabilityStatus.INCONCLUSIVE,
				"moves": [],
				"initial_moves": initial_accessible.size(),
				"blocking_graph": initial_bg["blocking_graph"]
			}

		var curr: Dictionary = queue.pop_front()
		var curr_active: Array = curr["active"]
		var curr_parked: Array = curr["parked"]
		var curr_pool: Dictionary = curr["pool"]
		var curr_hist: Array = curr["history"]

		# Goal condition: All buses cleared from platform and parking bays
		if curr_active.is_empty() and curr_parked.is_empty():
			return {
				"status": SolvabilityStatus.SOLVABLE,
				"moves": curr_hist,
				"initial_moves": initial_accessible.size(),
				"blocking_graph": initial_bg["blocking_graph"]
			}

		var bg_res := compute_blocking_graph(plat, curr_active)
		var escapable: Array = bg_res["accessible_ids"]

		if curr_parked.size() < parking_capacity:
			for vid in escapable:
				var slot := plat.get_slot_by_vehicle_id(vid)
				if slot == null:
					continue

				var next_active := curr_active.duplicate()
				next_active.erase(vid)
				var next_pool := curr_pool.duplicate()
				var next_parked := curr_parked.duplicate()

				# Circulating oval boarding check:
				# Does the circulating passenger pool have matching demand?
				var color := slot.assigned_color_id
				if next_pool.get(color, 0) > 0:
					next_pool[color] -= 1
					# Bus boards from oval, fills, and departs!
				else:
					# Bus remains waiting in parking bay
					next_parked.append(vid)

				var h_key: String = "%s|%s" % [",".join(next_active), ",".join(next_parked)]
				if not visited.has(h_key):
					visited[h_key] = true
					var next_hist := curr_hist.duplicate()
					next_hist.append(vid)
					queue.append({
						"active": next_active,
						"parked": next_parked,
						"pool": next_pool,
						"history": next_hist
					})

	return {
		"status": SolvabilityStatus.UNSOLVABLE,
		"moves": [],
		"initial_moves": initial_accessible.size(),
		"blocking_graph": initial_bg["blocking_graph"]
	}

static func _hash_state(active: Array, parked: Array, p_idx: int) -> String:
	var act_str := ",".join(active)
	var pk_parts: Array[String] = []
	for p in parked:
		pk_parts.append("%d:%s:%d" % [p["id"], p["color"], p["rem"]])
	return "%s|%s|%d" % [act_str, ",".join(pk_parts), p_idx]
