extends RefCounted
class_name CarJamPuzzleSolver

## Deterministic state-space solver (BFS) for Car Jam puzzle levels.
## Operates purely on authoritative models independently of graphics/tweens.
## Verifies that authored levels are mathematically and logically solvable without boosters.

class SimVehicle:
	var id: int
	var code: String
	var color_id: String
	var capacity: int
	var occupancy: int
	var anchor: Vector2i
	var footprint: Array[Vector2i]
	var direction: int
	var state: int # 0: ON_BOARD, 1: PARKED, 2: COMPLETED
	var slot_id: int = -1

	func clone() -> SimVehicle:
		var v := SimVehicle.new()
		v.id = id
		v.code = code
		v.color_id = color_id
		v.capacity = capacity
		v.occupancy = occupancy
		v.anchor = anchor
		v.footprint = footprint.duplicate()
		v.direction = direction
		v.state = state
		v.slot_id = slot_id
		return v

	func remaining_capacity() -> int:
		return maxi(0, capacity - occupancy)

class SimState:
	var size: Vector2i
	var grid: Array = [] # [y][x] -> vehicle_id
	var vehicles: Dictionary = {} # id -> SimVehicle
	var slots: Array = [] # 4 slots: vehicle_id (-1 for empty)
	var queue_groups: Array = [] # [{ "color_id": str, "remaining": int }]
	var head_index: int = 0
	var history: Array[int] = []

	func clone() -> SimState:
		var s := SimState.new()
		s.size = size
		s.grid = []
		for row in grid:
			s.grid.append(row.duplicate())
		for vid in vehicles:
			s.vehicles[vid] = vehicles[vid].clone()
		s.slots = slots.duplicate()
		s.queue_groups = []
		for g in queue_groups:
			s.queue_groups.append(g.duplicate())
		s.head_index = head_index
		s.history = history.duplicate()
		return s

	func get_hash_key() -> String:
		var parts: Array[String] = []
		# 1. On-board vehicles
		var board_v: Array[int] = []
		for vid in vehicles:
			if vehicles[vid].state == 0:
				board_v.append(vid)
		board_v.sort()
		parts.append("B:" + ",".join(board_v))
		# 2. Parking slots
		var p_str := "P:"
		for i in slots.size():
			var vid: int = slots[i]
			if vid != -1:
				var v: SimVehicle = vehicles[vid]
				p_str += "%d(%s,%d)/" % [i, v.color_id, v.occupancy]
			else:
				p_str += "%d(.)/" % i
		parts.append(p_str)
		# 3. Queue head
		if head_index < queue_groups.size():
			parts.append("Q:%d,%s,%d" % [head_index, queue_groups[head_index]["color_id"], queue_groups[head_index]["remaining"]])
		else:
			parts.append("Q:DONE")
		return "|".join(parts)

	func is_goal() -> bool:
		for vid in vehicles:
			if vehicles[vid].state != 2: # COMPLETED
				return false
		return head_index >= queue_groups.size()

	func find_free_slot() -> int:
		for i in slots.size():
			if slots[i] == -1:
				return i
		return -1

	func can_vehicle_escape(v: SimVehicle) -> bool:
		if v.state != 0:
			return false
		var d := CarJamVehicleData.dir_to_vector(v.direction)
		var step := 1
		var max_steps: int = maxi(size.x, size.y) + 4
		while step <= max_steps:
			var any_in_bounds := false
			for offset in v.footprint:
				var c := v.anchor + offset + (d * step)
				if c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y:
					any_in_bounds = true
					var occ: int = grid[c.y][c.x]
					if occ != -1 and occ != v.id:
						return false
			if not any_in_bounds:
				return true
			step += 1
		return false

	func run_boarding() -> void:
		var progress := true
		while progress:
			progress = false
			while head_index < queue_groups.size() and queue_groups[head_index]["remaining"] <= 0:
				head_index += 1
			if head_index >= queue_groups.size():
				break

			var head_color: String = queue_groups[head_index]["color_id"]
			var target_v: SimVehicle = null
			var target_slot := -1

			for i in slots.size():
				var vid: int = slots[i]
				if vid == -1:
					continue
				var v: SimVehicle = vehicles[vid]
				if v.color_id == head_color and v.remaining_capacity() > 0:
					target_v = v
					target_slot = i
					break

			if target_v == null:
				break

			var needed := target_v.remaining_capacity()
			var available: int = queue_groups[head_index]["remaining"]
			var count := mini(needed, available)

			queue_groups[head_index]["remaining"] -= count
			target_v.occupancy += count

			if target_v.occupancy >= target_v.capacity:
				# Depart!
				target_v.state = 2 # COMPLETED
				slots[target_slot] = -1

			progress = true

static func solve(lvl: CarJamLevelData, max_iterations: int = 50000) -> Dictionary:
	var init_state := SimState.new()
	init_state.size = lvl.board_size

	init_state.grid = []
	init_state.grid.resize(lvl.board_size.y)
	for y in lvl.board_size.y:
		var row: Array = []
		row.resize(lvl.board_size.x)
		row.fill(-1)
		init_state.grid[y] = row

	for vd in lvl.vehicles:
		var sv := SimVehicle.new()
		sv.id = vd.id
		sv.code = vd.code
		sv.color_id = vd.color_id
		sv.capacity = vd.capacity
		sv.occupancy = 0
		sv.anchor = vd.anchor
		sv.footprint = vd.footprint.duplicate()
		sv.direction = vd.direction
		sv.state = 0
		init_state.vehicles[sv.id] = sv
		for offset in sv.footprint:
			var c := sv.anchor + offset
			init_state.grid[c.y][c.x] = sv.id

	init_state.slots = []
	for i in lvl.parking_slots_count:
		init_state.slots.append(-1)

	init_state.queue_groups = []
	for g in lvl.passenger_groups:
		init_state.queue_groups.append({
			"color_id": g.color_id,
			"remaining": g.initial_count
		})
	init_state.head_index = 0

	# Initial boarding check (if any vehicles started in slots, though in Level 1 all start on board)
	init_state.run_boarding()

	if init_state.is_goal():
		return {"solvable": true, "moves": [], "iterations": 0}

	# BFS Queue
	var queue: Array[SimState] = [init_state]
	var visited: Dictionary = {}
	visited[init_state.get_hash_key()] = true

	var iters := 0

	while not queue.is_empty() and iters < max_iterations:
		iters += 1
		var current: SimState = queue.pop_front()

		if current.is_goal():
			return {
				"solvable": true,
				"moves": current.history,
				"iterations": iters
			}

		var free_slot := current.find_free_slot()
		if free_slot == -1:
			# Parking is full, cannot dispatch any vehicle from board
			continue

		# Explore each vehicle on board that can legally escape
		for vid in current.vehicles:
			var v: SimVehicle = current.vehicles[vid]
			if v.state != 0:
				continue

			if current.can_vehicle_escape(v):
				var next_state := current.clone()
				var next_v: SimVehicle = next_state.vehicles[vid]

				# 1. Clear from grid
				for offset in next_v.footprint:
					var c := next_v.anchor + offset
					next_state.grid[c.y][c.x] = -1

				# 2. Park in free slot
				var slot_idx := next_state.find_free_slot()
				next_state.slots[slot_idx] = vid
				next_v.state = 1 # PARKED
				next_v.slot_id = slot_idx

				# 3. Process boarding
				next_state.run_boarding()

				# 4. Record move
				next_state.history.append(vid)

				var key := next_state.get_hash_key()
				if not visited.has(key):
					visited[key] = true
					queue.append(next_state)

	return {
		"solvable": false,
		"moves": [],
		"iterations": iters
	}
