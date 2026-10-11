extends RefCounted
class_name SolvabilityValidator

## Validates that a WavePlan + PassengerDemand pair is winnable by at
## least one sequence of legal player taps.
##
## "Solvable" here means: a valid action sequence exists in which the
## player dispatches every bus, the head-of-queue color matches the bus
## color at the moment of dispatch, and no deadlock (parking full, no
## matching color) occurs before all buses have departed.
##
## Simulation rule (faithful to the runtime):
##   Each step:
##     1. Board up to head_len matching passengers onto any parked bus
##        whose color matches head_color (FIFO into the head run).
##     2. Any parked bus whose remaining seats == 0 immediately
##        "departs" — its slot is freed in the next substep.
##     3. If a bus of head_color is available AND there is a free slot,
##        dispatch it (park it in the slot).
##   Termination:
##     - All buses completed (dispatched, full, departed) AND feeder
##       served all passengers -> SOLVABLE.
##     - Parked buses > 0 all mismatched with head_color AND no bus of
##       head_color can be dispatched AND queue still has head_color ->
##       DEADLOCK.
##
## The validator operates ONLY on the data abstractions (PassengerDemand
## and WavePlan). It does not consult the visual runtime, the feeder
## animation, or the bus movement animation.

const MAX_SIM_DEPTH := 8192 # safety bound to keep searches finite

class Result:
	var solvable: bool = false
	var reason: String = ""
	var dispatched: Array = [] # ordered list of bus ids that successfully dispatched
	var simulated_seats_filled: Dictionary = {} # bus_id -> total filled
	var steps: int = 0

## Returns true if the level is solvable. Convenience wrapper around
## validate; discards detail.
static func is_solvable(demand, plan, slot_count: int = 4) -> bool:
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
	# Demand totals must be achievable. Demand per color must equal sum of
	# capacities per color (already covered by plan.validate_against).
	return true

## Full deterministic validation. Calls the iterative bounded simulator.
static func validate(demand, plan, slot_count: int = 4):
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
	var queue_head: int = 0
	var steps := 0
	while steps < MAX_SIM_DEPTH:
		steps += 1
		# Compute head color of feeder (only considering what's released).
		var head_color := ""
		var head_len := 0
		if queue_head < flat.size():
			head_color = String(flat[queue_head]["color"])
			var i = queue_head
			while i < flat.size() and String(flat[i]["color"]) == head_color:
				head_len += 1
				i += 1
		# Check success: every bus dispatched & no passenger demand left.
		var all_dispatched := true
		var all_bus_filled_dispatched := true
		for b in buses:
			if not b["dispatched"]:
				all_dispatched = false
			if not b["dispatched"] or int(b["remaining"]) > 0:
				all_bus_filled_dispatched = false
		if all_bus_filled_dispatched and queue_head >= flat.size():
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
				# Bus departs; it stays in 'dispatched' for accounting.
				slots[slot_i] = -1
		# Auto-finalize FULL buses that are NOT yet in slots (legal only if
		# they were dispatched directly into "departing" state).
		# (Not applicable in this rule set.)
		# BOARD: fill any parked bus of head_color with the head run.
		var boarded_some := false
		if head_color != "":
			for slot_i in slots.size():
				var bus_idx2 = slots[slot_i]
				if bus_idx2 < 0:
					continue
				var bb: Dictionary = buses[bus_idx2]
				if String(bb["color"]) != head_color:
					continue
				if int(bb["remaining"]) <= 0:
					continue
				# Take min(bus_remaining, head_len).
				var want = mini(int(bb["remaining"]), head_len)
				if want <= 0:
					continue
				bb["remaining"] = int(bb["remaining"]) - want
				head_len -= want
				boarded_some = true
				queue_head += want # advance feeder
		# Re-free any slot whose bus just became full.
		for slot_i in slots.size():
			var bus_idx3 = slots[slot_i]
			if bus_idx3 < 0:
				continue
			var bbb: Dictionary = buses[bus_idx3]
			if int(bbb["remaining"]) <= 0:
				slots[slot_i] = -1
		# DISPATCH: pick a free slot; park a bus of head_color.
		var dispatched_one := false
		if head_color != "":
			var free_slot = -1
			for slot_i in slots.size():
				if slots[slot_i] == -1:
					free_slot = slot_i
					break
			if free_slot != -1:
				for bus_i in buses.size():
					var b: Dictionary = buses[bus_i]
					if b["dispatched"]:
						continue
					if int(b["remaining"]) <= 0:
						continue
					if String(b["color"]) != head_color:
						continue
					b["dispatched"] = true
					b["slot"] = free_slot
					slots[free_slot] = bus_i
					out.dispatched.append(b["id"])
					dispatched_one = true
					break
		# Check termination: did nothing this step and we're stuck.
		if not boarded_some and not dispatched_one:
			# Determine why we're stuck.
			var pending := flat.size() - queue_head
			if pending <= 0 and all_dispatched:
				out.success = true
				out.filled = _fill_amounts(buses)
				out.steps = steps
				return out
			# No boarding happened -> head_color has no parked bus OR no match.
			# No dispatch happened -> no slot free OR no bus of head_color.
			var any_matching_bus := false
			for b in buses:
				if not b["dispatched"] and String(b["color"]) == head_color:
					any_matching_bus = true
					break
			var any_free_slot := false
			for s in slots:
				if s == -1:
					any_free_slot = true
					break
			if any_matching_bus and any_free_slot:
				# Should have dispatched — treat as a soft pass through to retry.
				# Try harder: scan dispatchable buses again on next iteration.
				if steps >= MAX_SIM_DEPTH - 1:
					out.reason = "Stuck without progress but possible match"
					break
				continue
			out.reason = "Deadlock: head=%s, parked=%d, free_slots=%d, queued_remaining=%d" % [head_color, _occupied_slot_count(slots), slots.size() - _occupied_slot_count(slots), pending]
			break
	out.steps = steps
	return out

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
