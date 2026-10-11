extends SceneTree

## Headless test runner for the universal passenger system.
## Run with:
##   godot --headless --script res://tests/test_universal_passenger.gd
##
## During `--script` execution the editor's global class_name registry is
## not available. We bind each universal class to a local Script
## reference, and route every call through Callable.call() because
## static methods cannot be invoked via dot-syntax on a bare Script
## reference at runtime (the GDScript runtime only resolves them through
## the static class_name lookup, not through Script.dynamic-call).

const UD: GDScript = preload("res://scripts/universal/passenger_demand.gd")
const UP: GDScript = preload("res://scripts/universal/wave_plan.gd")
const UG: GDScript = preload("res://scripts/universal/wave_generator.gd")
const UV: GDScript = preload("res://scripts/universal/solvability_validator.gd")
const US: GDScript = preload("res://scripts/universal/passenger_sequence.gd")
const UI: GDScript = preload("res://scripts/universal/level_integration.gd")

var failures: int = 0
var passes: int = 0

# --- Convenience helpers (every call routed through .call) ---------------
func _demand(buses: Array):
	return UD.call("from_bus_dicts", buses)

func _make_plan(spec: Array):
	return UG.call("from_authored_spec", _demand([{"id": "x", "color": "blue", "capacity": 0}]), spec) if false else UG.call("from_authored_spec", null, spec)
	# Above is intentionally NOT how we usually invoke; see _demand_plan below.

func _demand_from_dicts(buses: Array):
	return UD.call("from_bus_dicts", buses)

func _plan_authored(demand, spec: Array):
	return UG.call("from_authored_spec", demand, spec)

func _plan_generate(demand, cfg = null):
	if cfg == null:
		return UG.call("generate", demand)
	return UG.call("generate", demand, cfg)

func _is_solvable(demand, plan, slots: int = 4):
	return UV.call("is_solvable", demand, plan, slots)

func _validate(demand, plan, slots: int = 4):
	return UV.call("validate", demand, plan, slots)

func _is_solvable_fast(demand, plan):
	return UV.call("is_solvable_fast", demand, plan)

func _seq_new(plan, initial: int = 40):
	return US.call("new", plan, initial)

func _build_runtime(lvl, initial: int = 40, slots: int = 4):
	return UI.call("build_runtime", lvl, initial, slots)

func _init() -> void:
	_run_easy()
	_run_medium()
	_run_hard()
	_run_stress()
	_run_authored_validation()
	_run_partial_fill_lifecycle()
	_run_double_board_safety()
	_run_returning_color_continues_boarding()
	_run_seed_determinism()
	_run_initial_on_loop_population()
	_run_feeder_release_idempotence()
	_run_legacy_carjam_level_1_round_trip()
	_summary()
	if failures > 0:
		quit(1)
	else:
		quit(0)

func _expect(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % label)
	else:
		failures += 1
		print("  [FAIL] %s" % label)

func _section(name: String) -> void:
	print("\n--- %s ---" % name)

# --- EASY -----------------------------------------------------------------
func _run_easy() -> void:
	_section("EASY: 2 colors, small demand, simple waves")
	var demand = _demand_from_dicts([
		{"id": "B0", "color": "red", "capacity": 4},
		{"id": "B1", "color": "blue", "capacity": 4}
	])
	_expect(demand.total == 8, "Demand total = 8")
	var sorted = demand.sorted_colors()
	_expect(sorted == ["blue", "red"], "Demand has 2 colors")
	var plan = _plan_authored(demand, [
		{"color": "red", "count": 4},
		{"color": "blue", "count": 4}
	])
	_expect(plan != null, "Authored plan accepted")
	_expect(plan.total() == 8, "Plan total = 8")
	_expect(_is_solvable(demand, plan, 4), "Easy plan is solvable")

# --- MEDIUM ---------------------------------------------------------------
func _run_medium() -> void:
	_section("MEDIUM: 3 colors, split waves, returning colors")
	var buses := []
	var id := 0
	for c in ["red", "blue", "yellow"]:
		for n in 3:
			buses.append({"id": "bus_%d" % id, "color": c, "capacity": 8})
			id += 1
	var demand = _demand_from_dicts(buses)
	_expect(demand.total == 72, "Total demand = 72")
	_expect(demand.color_count() == 3, "3 colors")
	var plan = _plan_generate(demand)
	_expect(plan != null, "Generated plan exists")
	var errs = plan.validate_against(demand)
	_expect(errs.is_empty(), "Plan matches demand: " + str(errs))
	var res = _validate(demand, plan, 4)  # actual parking constraint
	_expect(res.solvable, "Medium plan solvable under 4 slots (reason: %s)" % res.reason)

# --- HARD -----------------------------------------------------------------
func _run_hard() -> void:
	_section("HARD: 4 colors, multiple splits, tight parking")
	var buses := []
	var colors := ["red", "blue", "yellow", "green"]
	var id := 0
	for c in colors:
		var n_buses := 3 if c == "red" else (4 if c == "blue" else 3)
		for n in n_buses:
			buses.append({"id": "b%d" % id, "color": c, "capacity": 4})
			id += 1
	var demand = _demand_from_dicts(buses)
	# 3 red + 4 blue + 3 yellow + 3 green × 4 capacity = 52
	_expect(demand.total == 52, "Hard total = 52 (3+4+3+3 buses × 4)")
	_expect(demand.color_count() == 4, "4 colors")
	var plan = _plan_generate(demand)
	_expect(plan != null, "Hard plan exists")
	_expect(plan.validate_against(demand).is_empty(), "Hard plan matches demand")
	var res = _validate(demand, plan, 4)  # actual parking constraint
	_expect(res.solvable, "Hard plan solvable under 4 slots (reason: %s)" % res.reason)
	_expect(res.dispatched.size() == buses.size(), "Validator dispatched every bus")

# --- STRESS ---------------------------------------------------------------
func _run_stress() -> void:
	_section("STRESS: 240-passenger, 6 buses capacity 40")
	var buses := []
	for i in 6:
		var c = "red" if i < 2 else ("blue" if i < 4 else "yellow")
		buses.append({"id": "bus%d" % i, "color": c, "capacity": 40})
	var demand = _demand_from_dicts(buses)
	_expect(demand.total == 240, "Total = 240")
	var plan = _plan_generate(demand)
	_expect(plan != null and plan.validate_against(demand).is_empty(), "Stress plan matches demand")
	var res = _validate(demand, plan, 7)
	_expect(res.solvable, "Stress plan solvable (reason: %s)" % res.reason)
	var seq = _seq_new(plan, 40)
	_expect(seq.initial_total() == 40, "Initial 40 on loop")
	_expect(seq.size() == 240, "Sequence size = 240")
	while seq.try_release_one_to_feeder() >= 0:
		pass
	_expect(seq.pending_count() == 0, "All pending released")
	_expect(seq.feeder_count() == 200, "200 in feeder")
	while seq.try_advance_feeder_to_loop() >= 0:
		pass
	_expect(seq.circulating_count() == 240, "All 240 circulating")

# --- Authored validation --------------------------------------------------
func _run_authored_validation() -> void:
	_section("Authored wave validation: rejects mismatched totals")
	var demand = _demand_from_dicts([
		{"id": "A", "color": "red", "capacity": 4},
		{"id": "B", "color": "blue", "capacity": 4}
	])
	var bad = _plan_authored(demand, [
		{"color": "red", "count": 5},
		{"color": "blue", "count": 3}
	])
	_expect(bad == null, "Mis-totalled authored plan rejected")
	var good = _plan_authored(demand, [
		{"color": "red", "count": 4},
		{"color": "blue", "count": 4}
	])
	_expect(good != null, "Balanced authored plan accepted")
	_expect(_is_solvable(demand, good, 4), "Balanced authored plan solvable")

# --- Partial-fill bus lifecycle ------------------------------------------
func _run_partial_fill_lifecycle() -> void:
	_section("Partial fill: bus fills across non-contiguous waves")
	# 1 red bus (cap 6) + 1 blue bus (cap 1) so both colors are supported
	var demand = _demand_from_dicts([
		{"id": "R1", "color": "red", "capacity": 6},
		{"id": "B1", "color": "blue", "capacity": 1}
	])
	var plan = _plan_authored(demand, [
		{"color": "red", "count": 2},
		{"color": "blue", "count": 1},
		{"color": "red", "count": 4}
	])
	_expect(plan != null, "Partial-fill plan accepted")
	var seq = _seq_new(plan, 4)
	_expect(seq.head_color() == "red", "Head begins red")
	var claimed_a = seq.try_claim_for_boarding("red")
	_expect(claimed_a >= 0, "First red claim succeeded")
	seq.mark_boarded(claimed_a)
	_expect(seq.completed_count() == 1, "1 completed")
	var boarded := 1
	while true:
		var c = seq.try_claim_for_boarding("red")
		if c < 0:
			break
		seq.mark_boarded(c)
		boarded += 1
	_expect(boarded >= 2, "At least 2 reds boarded (got %d)" % boarded)

# --- Double-board safety -------------------------------------------------
func _run_double_board_safety() -> void:
	_section("Double-board safety: cannot board same passenger twice")
	var demand = _demand_from_dicts([
		{"id": "R1", "color": "red", "capacity": 2}
	])
	var plan = _plan_authored(demand, [{"color": "red", "count": 2}])
	_expect(plan != null, "Authored plan accepted")
	var seq = _seq_new(plan, 2)
	var a = seq.try_claim_for_boarding("red")
	_expect(a >= 0, "First claim ok")
	var b = seq.try_claim_for_boarding("red")
	_expect(b >= 0 and b != a, "Second claim ok, different index")
	var c = seq.try_claim_for_boarding("red")
	_expect(c == -1, "Third claim fails (no circulating of red)")
	seq.mark_boarded(a)
	seq.mark_boarded(b)
	_expect(seq.completed_count() == 2, "Both passengers completed exactly once")
	_expect(seq.is_complete(), "Sequence complete")

# --- Returning color -----------------------------------------------------
func _run_returning_color_continues_boarding() -> void:
	_section("Returning color: later red wave resumes boarding on parked bus")
	# red bus cap 5 + blue bus cap 4
	var demand = _demand_from_dicts([
		{"id": "R1", "color": "red", "capacity": 5},
		{"id": "B1", "color": "blue", "capacity": 4}
	])
	var plan = _plan_authored(demand, [
		{"color": "red", "count": 2},
		{"color": "blue", "count": 4},
		{"color": "red", "count": 3}
	])
	_expect(plan != null, "Returning-color plan accepted")
	var seq = _seq_new(plan, 4)
	_expect(seq.size() == 9, "Sequence size = 9")
	_expect(seq.head_color() == "red", "Head color = red")
	var filled := 0
	while true:
		var cid = seq.try_claim_for_boarding("red")
		if cid < 0:
			break
		seq.mark_boarded(cid)
		filled += 1
	_expect(filled >= 2, "Some reds boarded (got %d)" % filled)

# --- Seed determinism ----------------------------------------------------
func _run_seed_determinism() -> void:
	_section("Generator determinism with same seed")
	var demand = _demand_from_dicts([
		{"id": "A", "color": "red", "capacity": 20},
		{"id": "B", "color": "blue", "capacity": 20},
		{"id": "C", "color": "yellow", "capacity": 20}
	])
	var cfg_script: GDScript = load("res://scripts/universal/wave_generator.gd")
	var cfg_a = cfg_script.DifficultyConfig.new()
	cfg_a.rng_seed = 42
	var cfg_b = cfg_script.DifficultyConfig.new()
	cfg_b.rng_seed = 42
	var plan_a = _plan_generate(demand, cfg_a)
	var plan_b = _plan_generate(demand, cfg_b)
	_expect(plan_a != null and plan_b != null, "Both plans generated")
	var same = plan_a.waves.size() == plan_b.waves.size()
	if same:
		for i in plan_a.waves.size():
			if plan_a.waves[i]["color"] != plan_b.waves[i]["color"]:
				same = false
			if plan_a.waves[i]["count"] != plan_b.waves[i]["count"]:
				same = false
	_expect(same, "Same seed produces identical plan")
	var cfg_c = cfg_script.DifficultyConfig.new()
	cfg_c.rng_seed = 999
	var plan_c = _plan_generate(demand, cfg_c)
	var differs = false
	if plan_c and plan_a:
		if plan_c.waves.size() != plan_a.waves.size():
			differs = true
		else:
			for i in plan_c.waves.size():
				if plan_c.waves[i]["color"] != plan_a.waves[i]["color"] or \
				   plan_c.waves[i]["count"] != plan_a.waves[i]["count"]:
					differs = true
					break
	_expect(differs, "Different seed produces different plan")

# --- Initial on-loop population -------------------------------------------
func _run_initial_on_loop_population() -> void:
	_section("Initial on-loop count never exceeds plan total")
	var demand = _demand_from_dicts([
		{"id": "B1", "color": "red", "capacity": 5}
	])
	var plan = _plan_authored(demand, [{"color": "red", "count": 5}])
	var seq = _seq_new(plan, 4)
	_expect(seq.circulating_count() == 4, "4 circulating initially (capped by initial_count)")
	_expect(seq.pending_count() == 1, "1 pending feeder entry")
	var snap = seq.snapshot()
	var first_four_colors: Array = []
	for i in 4:
		first_four_colors.append(String(snap["passengers"][i]["color"]))
	var all_red := true
	for c in first_four_colors:
		if String(c) != "red":
			all_red = false
	_expect(all_red, "First 4 pre-circulating all red")

# --- Feeder release idempotence -------------------------------------------
func _run_feeder_release_idempotence() -> void:
	_section("Feeder release never duplicates, never skips")
	var demand = _demand_from_dicts([
		{"id": "B1", "color": "red", "capacity": 8}
	])
	var plan = _plan_authored(demand, [{"color": "red", "count": 8}])
	var seq = _seq_new(plan, 0)
	_expect(seq.feeder_count() == 0, "Feeder empty initially")
	_expect(seq.pending_count() == 8, "8 pending")
	var seen: Dictionary = {}
	for i in 8:
		var rid = seq.try_release_one_to_feeder()
		_expect(rid == i, "Release order matches passenger id #%d" % i)
		_expect(not seen.has(rid), "No duplicate release at step %d" % i)
		seen[rid] = true
	_expect(seq.feeder_count() == 8, "Feeder now has 8")
	_expect(seq.try_release_one_to_feeder() == -1, "No more to release")

# --- Legacy CarJamLevelData round-trip ------------------------------------
## We don't import the legacy factory here because of a Godot 4.7 typed
## Array assignment quirk (`v.footprint = [...]` where the LHS is
## `Array[Vector2i]`). Instead, we mimic the same authored groups
## structure inline and verify the universal layer accepts it.
func _run_legacy_carjam_level_1_round_trip() -> void:
	_section("Legacy CarJamLevelData round-trip (mimicked, no factory)")
	# 6 buses capacity 40 with colors {red×2, blue×2, yellow×2}, 6 groups of 40 each.
	var buses := []
	for i in 6:
		var c = "red" if i < 2 else ("blue" if i < 4 else "yellow")
		buses.append({"id": "bus%d" % i, "color": c, "capacity": 40})
	var demand = _demand_from_dicts(buses)
	var groups := []
	var queue_colors := ["red", "blue", "yellow", "red", "blue", "yellow"]
	for i in queue_colors.size():
		groups.append({"color_id": queue_colors[i], "initial_count": 40, "remaining_count": 40})
	# Convert to wave plan.
	var plan = UP.call("new")
	for g in groups:
		plan.waves.append({"color": String(g["color_id"]), "count": int(g["initial_count"])})
	var errs = plan.validate_against(demand)
	_expect(errs.is_empty(), "Mimicked legacy plan matches demand")
	var res = _validate(demand, plan, 7)
	_expect(res.solvable, "Mimicked legacy Level 1 solvable via universal validator")
	var seq = _seq_new(plan, 40)
	_expect(seq.size() == 240, "Mimicked sequence has 240 entries")
	var totals = plan.totals_by_color()
	_expect(int(totals.get("red", 0)) == 80, "Red plan total = 80")
	_expect(int(totals.get("blue", 0)) == 80, "Blue plan total = 80")
	_expect(int(totals.get("yellow", 0)) == 80, "Yellow plan total = 80")

func _summary() -> void:
	print("\n==========================================")
	if failures == 0:
		print("=== ALL %d UNIVERSAL PASSENGER TESTS PASSED (0 FAILURES) ===" % passes)
	else:
		print("=== %d FAILED, %d PASSED ===" % [failures, passes])
	print("==========================================\n")
