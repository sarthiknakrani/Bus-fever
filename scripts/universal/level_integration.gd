extends RefCounted
class_name LevelIntegration

## Bridge between the existing CarJamLevelData + CarJamController and the
## universal passenger system. Never mutates source data; produces new
## PassengerDemand, WavePlan and PassengerSequence objects the runtime
## can consume alongside (or instead of) the legacy passenger_groups.
##
## Behavior:
##  - If a level's authored passenger_groups match the buses' capacities
##    per color (the existing validator's requirement), they are
##    converted 1:1 into a WavePlan (each group becomes one wave).
##  - If a level has zero authored passenger_groups, the universal
##    procedural generator is invoked. Difficulty knobs can be set per
##    level through the level's "generation_config" sub-resource when
##    used in procedural pipelines.
##  - The flat per-passenger color sequence is then exposed via
##    PassengerSequence for the feeder to consume.
##
## IMPORTANT: This file does NOT touch any working gameplay files. It is
## additive. The existing CarJamController and car_jam_level.gd keep
## their legacy code paths. To migrate, the user moves
## controller.queue setup to consume a PassengerSequence instead of the
## legacy queue.

## Convert the existing authored passenger_groups into a WavePlan. Each
## legacy group becomes one wave (color == group.color_id, count ==
## group.initial_count). Returns null if the plan cannot satisfy demand
## (e.g. groups missing).
static func plan_from_authored_groups(lvl):
	if lvl == null:
		return null
	var demand_script: GDScript = load("res://scripts/universal/passenger_demand.gd")
	var demand = demand_script.from_carjam_level(lvl)
	if demand.total == 0:
		return null
	var p = (load("res://scripts/universal/wave_plan.gd") as GDScript).new()
	var groups = lvl.passenger_groups if "passenger_groups" in lvl else []
	if groups.is_empty():
		return null
	for i in groups.size():
		var g = groups[i]
		p.waves.append({"color": String(g.color_id), "count": int(g.initial_count), "source_group_id": i, "group_id": i})
	var errs = p.validate_against(demand)
	if not errs.is_empty():
		push_error("[Universal] Authored groups do not satisfy demand: " + str(errs))
		return null
	return p

## Convert the published flat color list (car_jam_level's
## controller.queue flat colors) directly to a WavePlan.
static func plan_from_flat_colors(lvl, flat_colors: Array):
	var p = (load("res://scripts/universal/wave_plan.gd") as GDScript).new()
	var idx := 0
	while idx < flat_colors.size():
		var c = String(flat_colors[idx])
		var n := 1
		while idx + n < flat_colors.size() and String(flat_colors[idx + n]) == c:
			n += 1
		p.waves.append({"color": c, "count": n})
		idx += n
	if lvl == null:
		return p
	var demand_script: GDScript = load("res://scripts/universal/passenger_demand.gd")
	var demand = demand_script.from_carjam_level(lvl)
	var errs = p.validate_against(demand)
	if not errs.is_empty():
		push_error("[Universal] Flat colors do not satisfy demand: " + str(errs))
		return null
	return p

## Build a fully prepared runtime for a level. Returns a Dictionary:
## {
##   demand: PassengerDemand,
##   plan: WavePlan,
##   sequence: PassengerSequence,
##   validation: SolvabilityValidator.Result
## }
## Caller chooses how to feed sequence into the runtime.
static func build_runtime(lvl, initial_circulating_count: int = 40, slot_count: int = 4) -> Dictionary:
	var demand_script: GDScript = load("res://scripts/universal/passenger_demand.gd")
	var demand = demand_script.from_carjam_level(lvl)
	var groups = lvl.passenger_groups if "passenger_groups" in lvl else []
	var plan = plan_from_authored_groups(lvl)
	if plan == null:
		var gen_script: GDScript = load("res://scripts/universal/wave_generator.gd")
		plan = gen_script.generate(demand)
		if plan != null and not groups.is_empty():
			plan.assign_source_groups(groups)
	var seq_script: GDScript = load("res://scripts/universal/passenger_sequence.gd")
	var sequence = seq_script.new(plan, initial_circulating_count, groups)
	var val_script: GDScript = load("res://scripts/universal/solvability_validator.gd")
	var validation = val_script.validate(demand, plan, slot_count)
	return {
		"demand": demand,
		"plan": plan,
		"sequence": sequence,
		"validation": validation
	}

## Compatibility helper: produce the flat color sequence (Array[String])
## that legacy code paths need (e.g. controller.queue.setup with the
## flat list semantics). Returns [] if the level has no valid plan.
static func flat_color_sequence(lvl) -> Array:
	var plan = plan_from_authored_groups(lvl)
	if plan == null:
		return []
	var flat = plan.flatten()
	var out: Array = []
	for entry in flat:
		out.append(String(entry["color"]))
	return out

## Convenience: count of passengers whose color matches `target`,
## regardless of state. Useful for the existing boarding progress UI.
static func color_count_in_plan(plan, target: String) -> int:
	if plan == null:
		return 0
	var n := 0
	for w in plan.waves:
		if String(w.get("color", "")) == target:
			n += int(w.get("count", 0))
	return n
