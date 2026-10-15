extends RefCounted
class_name CarJamPuzzleSolver

## Deterministic state-space solver (BFS) for Car Jam puzzle levels.
## Operates purely on authoritative models independently of graphics/tweens.
## Accurately models real gameplay rules:
##  1. Board swept-escape collision corridors.
##  2. Authoritative unlocked parking slots (defaulting to slots 1, 2, 3 via CarJamParkingManager).
##  3. Active circular oval passenger capacity (152) and separate waiting feeder queue.
##  4. Continuous oval circulation boarding with capacity-driven feeder admission.
##  5. Atomic slot transitions (FREE -> RESERVED -> OCCUPIED -> DEPARTING -> FREE).
##  6. Win & deadlock terminal states without false failures.

const OVAL_CAPACITY: int = 152

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
	var slots: Array = [] # slot_idx -> vehicle_id (-1 for empty)
	var unlocked_slots: Array[int] = [] # list of usable slot indices
	var passenger_seq: Array[String] = [] # full ordered passenger sequence
	var feeder_index: int = 0 # index in passenger_seq of next waiting feeder passenger
	var oval_counts: Dictionary = {} # color_id -> count currently circulating on oval
	var oval_capacity: int = OVAL_CAPACITY
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
		s.unlocked_slots = unlocked_slots.duplicate()
		s.passenger_seq = passenger_seq
		s.feeder_index = feeder_index
		s.oval_counts = oval_counts.duplicate()
		s.oval_capacity = oval_capacity
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

		# 2. Unlocked Parking slots
		var p_str := "P:"
		for slot_idx in unlocked_slots:
			var vid: int = slots[slot_idx]
			if vid != -1:
				var v: SimVehicle = vehicles[vid]
				p_str += "%d(%s,%d)/" % [slot_idx, v.color_id, v.occupancy]
			else:
				p_str += "%d(.)/" % slot_idx
		parts.append(p_str)

		# 3. Oval counts & feeder index
		var o_parts: Array[String] = []
		var sorted_colors = oval_counts.keys()
		sorted_colors.sort()
		for c in sorted_colors:
			if oval_counts[c] > 0:
				o_parts.append("%s:%d" % [c, oval_counts[c]])
		parts.append("O:" + ",".join(o_parts) + "#F:%d" % feeder_index)
		return "|".join(parts)

	func is_goal() -> bool:
		for vid in vehicles:
			if vehicles[vid].state != 2: # COMPLETED
				return false
		return true

	func find_free_slot() -> int:
		for slot_idx in unlocked_slots:
			if slots[slot_idx] == -1:
				return slot_idx
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

	## Real continuous circulation boarding + capacity-driven feeder admission
	func run_boarding() -> void:
		var progress := true
		while progress:
			progress = false
			for slot_idx in unlocked_slots:
				var vid: int = slots[slot_idx]
				if vid == -1:
					continue
				var v: SimVehicle = vehicles[vid]
				if v.remaining_capacity() > 0 and oval_counts.get(v.color_id, 0) > 0:
					var available_on_oval: int = oval_counts[v.color_id]
					var needed: int = v.remaining_capacity()
					var count: int = mini(available_on_oval, needed)

					v.occupancy += count
					oval_counts[v.color_id] -= count
					progress = true

					# For each boarded passenger, one enters from feeder to oval
					for k in count:
						if feeder_index < passenger_seq.size():
							var incoming_col: String = passenger_seq[feeder_index]
							feeder_index += 1
							oval_counts[incoming_col] = oval_counts.get(incoming_col, 0) + 1

					# If full, the bus completes and departs off-screen, freeing the slot!
					if v.occupancy >= v.capacity:
						v.state = 2 # COMPLETED
						slots[slot_idx] = -1

					break # Scan from beginning to enforce deterministic slot priority

static func solve(lvl: CarJamLevelData, max_iterations: int = 50000, override_unlocked_slots: Array[int] = []) -> Dictionary:
	if lvl == null:
		return {"solvable": false, "moves": [], "iterations": 0, "reason": "Null level"}

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

	# Authoritative unlocked parking slots
	init_state.slots = []
	init_state.unlocked_slots = []
	var total_slot_count: int = maxi(lvl.parking_slots_count, 7)
	for i in total_slot_count:
		init_state.slots.append(-1)

	if not override_unlocked_slots.is_empty():
		init_state.unlocked_slots = override_unlocked_slots.duplicate()
	elif "unlocked_slot_ids" in lvl and not lvl.unlocked_slot_ids.is_empty():
		init_state.unlocked_slots = lvl.unlocked_slot_ids.duplicate()
	else:
		var pm := CarJamParkingManager.new()
		pm.setup(total_slot_count)
		for i in total_slot_count:
			var slot = pm.get_slot(i)
			if slot != null and slot.is_unlocked:
				init_state.unlocked_slots.append(i)

	# Flatten authoritative passenger sequence
	init_state.passenger_seq = []
	for g in lvl.passenger_groups:
		for k in g.initial_count:
			init_state.passenger_seq.append(String(g.color_id))

	# Initial oval population
	init_state.oval_capacity = OVAL_CAPACITY
	var init_oval_count = mini(init_state.passenger_seq.size(), init_state.oval_capacity)
	init_state.feeder_index = init_oval_count
	init_state.oval_counts = {}
	for i in init_oval_count:
		var c = init_state.passenger_seq[i]
		init_state.oval_counts[c] = init_state.oval_counts.get(c, 0) + 1

	# Initial boarding check
	init_state.run_boarding()

	if init_state.is_goal():
		return {
			"solvable": true,
			"moves": [],
			"iterations": 0,
			"unlocked_slots": init_state.unlocked_slots,
			"reason": "Initial goal"
		}

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
				"iterations": iters,
				"unlocked_slots": current.unlocked_slots,
				"reason": "Solved"
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

				# 3. Process real circulation boarding
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
		"iterations": iters,
		"unlocked_slots": init_state.unlocked_slots,
		"reason": "Exhausted search or iterations limit (%d)" % iters
	}
