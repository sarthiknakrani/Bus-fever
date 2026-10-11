extends Resource
class_name WavePlan

## A complete, ordered passenger wave plan for a level. Each wave is a
## (color, count) pair. The sequence of waves preserves deterministic
## ordering from authoring or generation. The plan can be expanded into
## the flat per-passenger sequence expected by the runtime feeder.

@export var waves: Array[Dictionary] = [] # [{"color": String, "count": int}]

## Build a plan from an ordered list of color strings (one entry per
## passenger). Useful for migration of legacy .tres levels.
static func from_color_list(colors: Array) -> WavePlan:
	var p: WavePlan = (load("res://scripts/universal/wave_plan.gd") as GDScript).new()
	var idx := 0
	while idx < colors.size():
		var c = String(colors[idx])
		var n := 1
		while idx + n < colors.size() and String(colors[idx + n]) == c:
			n += 1
		p.waves.append({"color": c, "count": n})
		idx += n
	return p

## Build a plan from a Demand and a sequence of waves (each
## {color, count}). Validates: total counts == demand total, color totals
## == demand per color. Returns null if invalid (with errors pushed).
static func from_demand_and_waves(demand, raw_waves: Array):
	var p = (load("res://scripts/universal/wave_plan.gd") as GDScript).new()
	for w in raw_waves:
		p.waves.append({"color": String(w.get("color", "")), "count": int(w.get("count", 0))})
	var errs = p.validate_against(demand)
	if not errs.is_empty():
		push_error("WavePlan validation failed: " + str(errs))
		return null
	return p

## Total passengers across the plan.
func total() -> int:
	var t := 0
	for w in waves:
		t += int(w.get("count", 0))
	return t

## Number of waves.
func wave_count() -> int:
	return waves.size()

## Flat sequence (one entry per passenger). Each entry is {"color": String, "wave_index": int}.
func flatten() -> Array:
	var out: Array = []
	for i in waves.size():
		var w: Dictionary = waves[i]
		for j in int(w.get("count", 0)):
			out.append({"color": String(w.get("color", "")), "wave_index": i})
	return out

## Per-color totals across all waves.
func totals_by_color() -> Dictionary:
	var d: Dictionary = {}
	for w in waves:
		var c = String(w.get("color", ""))
		d[c] = int(d.get(c, 0)) + int(w.get("count", 0))
	return d

## Validate against a Demand. Returns Array[String] of errors (empty if OK).
func validate_against(demand) -> Array:
	var errs: Array[String] = []
	if waves.is_empty():
		errs.append("WavePlan has no waves")
		errs.append("WavePlan total %d does not match demand total %d" % [total(), demand.total])
		return errs
	var totals = totals_by_color()
	for c in demand.by_color.keys():
		var need = int(demand.by_color[c])
		var have = int(totals.get(c, 0))
		if need != have:
			errs.append("Color %s: demand %d, plan total %d" % [c, need, have])
	for c in totals.keys():
		if not demand.by_color.has(c):
			errs.append("WavePlan has color %s which is not in demand" % c)
	for w in waves:
		if int(w.get("count", 0)) <= 0:
			errs.append("Wave has count <= 0: %s" % w)
	return errs

## Returns the position of the first passenger who could begin boarding a
## vehicle of `color` given the feeder has released exactly `released`
## passengers into the loop. Equivalent to "what's the index of the next
## matching passenger that has emerged from the feeder?"
##
## Returns -1 if no matching passenger exists in the first `released` slots.
func first_eligible_after(color: String, released: int) -> int:
	var flat = flatten()
	var upto = mini(released, flat.size())
	for i in upto:
		if String(flat[i]["color"]) == color:
			return i
	return -1

## Returns the count of consecutive matching-color passengers starting at
## `index` (used by boarding logic to know how many can board in one batch).
func run_length_at(index: int, color: String) -> int:
	var flat = flatten()
	if index < 0 or index >= flat.size():
		return 0
	var run := 0
	var i = index
	while i < flat.size() and String(flat[i]["color"]) == color:
		run += 1
		i += 1
	return run

## Number of waves whose color == given color.
func wave_count_for(color: String) -> int:
	var n := 0
	for w in waves:
		if String(w.get("color", "")) == color:
			n += 1
	return n

## Returns a debug string.
func describe() -> String:
	var parts: Array = []
	for i in waves.size():
		var w: Dictionary = waves[i]
		parts.append("%s×%d" % [w["color"], w["count"]])
	return "WavePlan[%d waves, %d passengers: %s]" % [waves.size(), total(), ", ".join(parts)]

## Snapshot to dict (for save files / debugging).
func snapshot() -> Dictionary:
	var out: Dictionary = {"waves": []}
	for w in waves:
		out["waves"].append({"color": w["color"], "count": w["count"]})
	return out
