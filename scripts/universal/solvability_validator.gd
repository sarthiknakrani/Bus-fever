extends RefCounted
class_name SolvabilityValidator

## Validates that a WavePlan + PassengerDemand pair is winnable by at
## least one sequence of legal player taps.
##
## "Solvable" here means: a valid action sequence exists in which the
## player dispatches every bus, buses board passengers from the active
## oval loop (capacity 152), freed oval capacity admits waiting feeder
## passengers, and no deadlock (parking full, no matching color on oval)
## occurs before all buses have departed.
##
## Simulation rule (faithful to the runtime):
##   1. Active circular oval holds up to 152 passengers.
##   2. Feeder holds remaining passengers until boarding frees space on oval.
##   3. Parked buses board matching circulating passengers from the oval.
##   4. Any parked bus whose remaining seats == 0 departs and frees its slot.
##   5. If a slot is free, an undispatched matching bus is dispatched.
##   Termination:
##     - All buses completed (dispatched, full, departed) AND all passengers
##       served -> SOLVABLE.
##     - Parked buses full, none can board from oval, feeder blocked -> DEADLOCK.

const MAX_SIM_DEPTH := 8192 # safety bound to keep searches finite
const DEFAULT_SLOT_COUNT := 3
const OVAL_CAPACITY := 152

class Result:
	var solvable: bool = false
	var reason: String = ""
	var dispatched: Array = [] # ordered list of bus ids that successfully dispatched
	var simulated_seats_filled: Dictionary = {} # bus_id -> total filled
	var steps: int = 0

## Returns true if the level is solvable. Convenience wrapper around
## validate; discards detail.
static func is_solvable(demand, plan, slot_count: int = DEFAULT_SLOT_COUNT) -> bool:
	var r = validate(demand, plan, slot_count)
	return r.solvable

## Cheap necessary-condition pre-check used by wave generation. Only
## rejects plans that are *guaranteed* impossible. Most plans pass this;
## the full validator is the source of truth.
static func is_solvable_fast(demand, plan) -> bool:
	if demand == null or plan == null:
		return false
	var errs = plan.validate_against(demand)
	if not errs.is_empty():
		return false
	return true

## Full deterministic validation. Calls the iterative bounded simulator.
static func validate(demand, plan, slot_count: int = DEFAULT_SLOT_COUNT):
	var res = Result.new()
	if demand == null or plan == null or plan.waves.is_empty():
		res.reason = "Empty plan"
		return res
	var errs = plan.validate_against(demand)
	if not errs.is_empty():
		res.reason = "Plan violates demand: " + str(errs)
		return res
	# Build authoritative bus list (color-keyed, deterministic order).
	var buses: Array = []
	for c in demand.sorted_colors():
		for b in demand.buses_by_color[c]:
			buses.append({
				"id": String(b["id"]),
				"color": String(c),
				"capacity": int(b["capacity"]),
				"remaining": int(b["capacity"]),
				"dispatched": false,
				"slot": -1
			})
	var flat = plan.flatten()
	# Mutating simulator with bounded iterations.
	var sim := _run_simulator(buses, flat, slot_count)
	res.solvable = sim.success
	res.steps = sim.steps
	res.dispatched = sim.dispatched
	res.simulated_seats_filled = sim.filled
	if not res.solvable:
		res.reason = sim.reason
	return res

# --- Simulator ------------------------------------------------------------

class SimResult:
	var success: bool = false
	var dispatched: Array = []
	var filled: Dictionary = {}
	var steps: int = 0
	var reason: String = ""

## Faithful simulation of the real game rules. Deterministic and bounded.
static func _run_simulator(buses: Array, flat: Array, slot_count: int) -> SimResult:
	var out := SimResult.new()
	var slots: Array = []
	for i in slot_count:
		slots.append(-1) # -1 = free, else bus index

	# Initial circular oval population & feeder state
	var init_oval_count: int = mini(flat.size(), OVAL_CAPACITY)
	var feeder_index: int = init_oval_count
	var oval_counts: Dictionary = {}
	for i in init_oval_count:
		var c = String(flat[i]["color"])
		oval_counts[c] = oval_counts.get(c, 0) + 1

	var steps := 0
	while steps < MAX_SIM_DEPTH:
		steps += 1

		# Check success: every bus dispatched & no passenger demand left.
		var all_bus_filled_dispatched := true
		for b in buses:
			if not b["dispatched"] or int(b["remaining"]) > 0:
				all_bus_filled_dispatched = false
				break
		var oval_empty := _sum_oval(oval_counts) == 0
		if all_bus_filled_dispatched and feeder_index >= flat.size() and oval_empty:
			out.success = true
			out.dispatched = _bus_ids_in_dispatch_order(buses)
			out.filled = _fill_amounts(buses)
			out.steps = steps
			return out

		# Auto-finalize any FULL parked bus: free its slot.
		for slot_i in slots.size():
			var bus_idx = slots[slot_i]
			if bus_idx < 0:
				continue
			var bbus: Dictionary = buses[bus_idx]
			if int(bbus["remaining"]) <= 0:
				slots[slot_i] = -1

		# BOARD: fill any parked bus with matching passengers circulating on the oval.
		var boarded_some := false
		for slot_i in slots.size():
			var bus_idx2 = slots[slot_i]
			if bus_idx2 < 0:
				continue
			var bb: Dictionary = buses[bus_idx2]
			var b_color: String = String(bb["color"])
			if int(bb["remaining"]) <= 0:
				continue
			var available: int = oval_counts.get(b_color, 0)
			if available <= 0:
				continue

			var want: int = mini(int(bb["remaining"]), available)
			bb["remaining"] = int(bb["remaining"]) - want
			oval_counts[b_color] -= want
			boarded_some = true

			# Each boarded passenger creates capacity on the oval, admitting from feeder
			for k in want:
				if feeder_index < flat.size():
					var incoming: String = String(flat[feeder_index]["color"])
					feeder_index += 1
					oval_counts[incoming] = oval_counts.get(incoming, 0) + 1

			# Re-free slot if bus became full
			if int(bb["remaining"]) <= 0:
				slots[slot_i] = -1

		# DISPATCH: if a slot is free, park an undispatched bus.
		var dispatched_one := false
		var free_slot := -1
		for slot_i in slots.size():
			if slots[slot_i] == -1:
				free_slot = slot_i
				break

		if free_slot != -1:
			# Priority 1: Dispatch a bus whose color is currently circulating on the oval
			var chosen_bus_idx := -1
			for bus_i in buses.size():
				var b: Dictionary = buses[bus_i]
				if b["dispatched"]:
					continue
				if int(b["remaining"]) <= 0:
					continue
				if oval_counts.get(String(b["color"]), 0) > 0:
					chosen_bus_idx = bus_i
					break

			# Priority 2: If none matches current oval, dispatch a bus whose color appears earliest in feeder
			if chosen_bus_idx == -1:
				var earliest_feeder_pos := 999999
				for bus_i in buses.size():
					var b: Dictionary = buses[bus_i]
					if b["dispatched"] or int(b["remaining"]) <= 0:
						continue
					var c: String = String(b["color"])
					# Find earliest position in remaining feeder
					for f_i in range(feeder_index, flat.size()):
						if String(flat[f_i]["color"]) == c:
							if f_i < earliest_feeder_pos:
								earliest_feeder_pos = f_i
								chosen_bus_idx = bus_i
							break

			if chosen_bus_idx != -1:
				var chosen_bus: Dictionary = buses[chosen_bus_idx]
				chosen_bus["dispatched"] = true
				chosen_bus["slot"] = free_slot
				slots[free_slot] = chosen_bus_idx
				out.dispatched.append(chosen_bus["id"])
				dispatched_one = true

		# Check termination: did nothing this step and we're stuck.
		if not boarded_some and not dispatched_one:
			var pending := (flat.size() - feeder_index) + _sum_oval(oval_counts)
			var all_done := true
			for b in buses:
				if not b["dispatched"] or int(b["remaining"]) > 0:
					all_done = false
					break
			if pending <= 0 and all_done:
				out.success = true
				out.filled = _fill_amounts(buses)
				out.steps = steps
				return out

			out.reason = "Deadlock: parked=%d, free_slots=%d, remaining_passengers=%d, oval_counts=%s" % [
				_occupied_slot_count(slots),
				slots.size() - _occupied_slot_count(slots),
				pending,
				str(oval_counts)
			]
			break

	out.steps = steps
	return out

static func _sum_oval(counts: Dictionary) -> int:
	var total := 0
	for c in counts:
		total += int(counts[c])
	return total

static func _bus_ids_in_dispatch_order(buses: Array) -> Array:
	var out := []
	for b in buses:
		if b["dispatched"]:
			out.append(b["id"])
	return out

static func _fill_amounts(buses: Array) -> Dictionary:
	var out := {}
	for b in buses:
		out[b["id"]] = int(b["capacity"]) - int(b["remaining"])
	return out

static func _occupied_slot_count(slots: Array) -> int:
	var n := 0
	for s in slots:
		if s != -1:
			n += 1
	return n
