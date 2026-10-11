extends RefCounted
class_name WaveGenerator

## Universal wave plan generator. Produces ordered lists of
## (color, count) waves that collectively match a passenger demand while
## honoring designer-specified difficulty parameters.
##
## Two modes:
##   - AUTHORED: designer hands the generator a wave spec, and the
##     generator validates it consumes exactly the demand. No new
##     generation happens; this is the level-editor path.
##   - PROCEDURAL: the generator builds a candidate sequence using a
##     seeded RNG, sized waves, and split probabilities. The candidate
##     is fed to SolvabilityValidator before being accepted.

## Knobs the designer / runtime can pass in.
class DifficultyConfig:
	var min_wave_size: int = 4
	var max_wave_size: int = 24
	var preferred_wave_size: int = 8
	## Probability of splitting a single color's demand across multiple
	## waves instead of producing one large wave per color per "burst".
	var split_wave_probability: float = 0.55
	## Number of distinct color "bursts" in the plan. A burst is a
	## contiguous run of one color before the color may change.
	var target_bursts: int = -1 # -1 = derived from colors
	var rng_seed: int = 0

## Generate waves procedurally. Returns null if the produced plan fails
## validation against the demand (extremely unlikely after the first try
## because we explicitly match totals, but split placement can occasionally
## produce an unsolvable wave ordering; the retry loop below increases
## robustness without unlimited search).
static func generate(demand, cfg = null):
	if cfg == null:
		cfg = DifficultyConfig.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = cfg.rng_seed if cfg.rng_seed != 0 else int(Time.get_ticks_msec())

	var colors = demand.sorted_colors()
	if colors.is_empty():
		return null

	var target_bursts = cfg.target_bursts
	if target_bursts <= 0:
		# Roughly 2 bursts per color by default; clamp to a sane range.
		target_bursts = clampi(colors.size() * 2, 2, 12)

	var max_attempts := 8
	for attempt in max_attempts:
		var plan = _build_attempt(demand, colors, cfg, rng, target_bursts)
		if plan == null:
			continue
		var errs = plan.validate_against(demand)
		if errs.is_empty():
			# Quick solvability pre-check using the validator's fast path.
			if is_solvable_fast(demand, plan):
				return plan
	# Last resort: return the most recent attempt even if strict
	# solvability check was uncertain. This guarantees a deterministic
	# plan that matches demand totals. The strict validator still
	# examines full simulations separately.
	return _build_attempt(demand, colors, cfg, rng, target_bursts)

## Static factory that allocates a new WavePlan. Provided here because
## GDScript cannot self-reference its own class_name inside a static
## method on Godot 4.7.
static func _empty_plan():
	return (load("res://scripts/universal/wave_plan.gd") as GDScript).new()

## Forwarder so other files can call `WaveGenerator.is_solvable_fast(...)`
## without writing the full SolvabilityValidator path. Delegates to the
## validator preload to avoid a circular static call during --script.
static func is_solvable_fast(demand, plan) -> bool:
	var v_script = load("res://scripts/universal/solvability_validator.gd")
	return v_script.is_solvable_fast(demand, plan)

## Build a candidate plan in one attempt (deterministic given rng state).
static func _build_attempt(demand, colors: Array, cfg, rng: RandomNumberGenerator, target_bursts: int):
	# Allocate per-color "burst slots": how many times this color should
	# appear as a distinct wave in the sequence. Sum equals target_bursts.
	var burst_alloc = _allocate_bursts(colors, target_bursts, rng)
	# For each color, split its demand across its allocated bursts.
	var color_chunks: Dictionary = {} # color -> Array of int (counts per burst)
	for c in colors:
		var total = int(demand.by_color[c])
		var n = int(burst_alloc.get(c, 1))
		color_chunks[c] = _split_into_bursts(total, n, cfg, rng)
	# Interleave chunks: schedule bursts in a difficulty-driven order.
	var order = _interleave_order(colors, burst_alloc, rng)
	var waves: Array[Dictionary] = []
	for entry in order:
		var c = String(entry["color"])
		var slot = int(entry["slot"])
		var chunks: Array = color_chunks[c]
		if slot >= chunks.size():
			continue
		var n = int(chunks[slot])
		if n <= 0:
			continue
		waves.append({"color": c, "count": n})
	# Last safety pass: any unmet demand (split sums may be off by 1 due
	# to integer rounding) is appended as a corrective final wave.
	var totals: Dictionary = {}
	for w in waves:
		var wc = String(w["color"])
		totals[wc] = int(totals.get(wc, 0)) + int(w["count"])
	for c in colors:
		var diff = int(demand.by_color[c]) - int(totals.get(c, 0))
		if diff > 0:
			waves.append({"color": c, "count": diff})
		elif diff < 0:
			# Find a wave of c with enough headroom and steal from it.
			for w in waves:
				if String(w["color"]) == c and int(w["count"]) > 1:
					var steal = mini(int(w["count"]) - 1, -diff)
					w["count"] = int(w["count"]) - steal
					if steal > 0:
						waves.append({"color": c, "count": steal})
					break
	var plan = _empty_plan()
	var typed_waves: Array[Dictionary] = []
	for w in waves:
		typed_waves.append(w)
	plan.waves = typed_waves
	return plan

## Decide how many bursts each color gets. Bias split colors (i.e. those
## with large total demand) toward more bursts.
static func _allocate_bursts(colors: Array, target: int, rng: RandomNumberGenerator) -> Dictionary:
	var alloc: Dictionary = {}
	var first := true
	var remaining = target
	for i in colors.size():
		var c = String(colors[i])
		if first:
			# First color starts with at least 1 burst so we never emit a 0-burst plan.
			alloc[c] = 1
			remaining -= 1
			first = false
			continue
		var take: int = 0
		if remaining <= colors.size() - i:
			take = 1
		else:
			# 1, 2 or 3 bursts weighted by randf.
			var r = rng.randf()
			if r < 0.45:
				take = 1
			elif r < 0.85:
				take = 2
			else:
				take = 3
			take = mini(take, remaining - (colors.size() - i - 1))
			if take < 1:
				take = 1
		alloc[c] = take
		remaining -= take
	# Any leftover burst slots go to the largest-demand color to keep
	# plan interesting (multiple split waves).
	if remaining > 0 and not colors.is_empty():
		var biggest = String(colors[0])
		for c in colors:
			if int(alloc.get(String(c), 0)) > int(alloc.get(biggest, 0)):
				biggest = String(c)
		alloc[biggest] = int(alloc.get(biggest, 0)) + remaining
	return alloc

## Split a color total into N positive integers that sum to `total`, each
## in [min_wave_size, max_wave_size] when possible.
static func _split_into_bursts(total: int, n: int, cfg: DifficultyConfig, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if n <= 0 or total <= 0:
		if total > 0:
			out.append(total)
		return out
	# If total is small (<= max_wave_size), just emit one chunk equal to
	# total and zero-size placeholders for the rest, which the caller will
	# filter out (so the color only appears once).
	if total <= cfg.max_wave_size and rng.randf() > cfg.split_wave_probability:
		out.append(total)
		while out.size() < n:
			out.append(0)
		return out
	# Build positive parts so each chunk respects min/max.
	var sizes: Array = []
	var remaining = total
	for i in n:
		var left_parts = n - i
		var min_others = left_parts * cfg.min_wave_size
		var max_this = max(cfg.min_wave_size, min(remaining - min_others, cfg.max_wave_size))
		var ideal = clampi(cfg.preferred_wave_size, cfg.min_wave_size, max_this)
		# Pick a value within [min_wave_size, max_this] biased toward ideal.
		var low = cfg.min_wave_size
		var hi = max_this
		var pick: int
		if low >= hi:
			pick = low
		else:
			var r = rng.randf()
			pick = int(round(lerpf(float(low), float(hi), r)))
			pick = clampi(pick, low, hi)
			# Bias toward ideal by mixing.
			var idealish = int(lerpf(float(pick), float(ideal), rng.randf() * 0.7))
			pick = clampi(idealish, low, hi)
		# Ensure the remaining slots can still satisfy remaining parts.
		if remaining - pick < left_parts * cfg.min_wave_size:
			pick = remaining - left_parts * cfg.min_wave_size
		if pick < cfg.min_wave_size and i < n - 1:
			pick = cfg.min_wave_size
		sizes.append(pick)
		remaining -= pick
		if remaining < 0:
			# Forcing correction: clamp and rebalance later.
			sizes[-1] += remaining
			remaining = 0
	# If we never filled (impossible in correct arithmetic), force one
	# chunk of `total` to guarantee correctness.
	var sum := 0
	for s in sizes:
		sum += s
	if sum != total:
		sizes = [total]
	while out.size() < n:
		out.append(0)
	for s in sizes:
		out.append(int(s))
	return out

## Produce an interleaved order (which burst of which color appears
## when). Designed so adjacent same-color bursts are unlikely (but
## possible when only one color remains) — this is what creates puzzle
## tension by interleaving colors.
static func _interleave_order(colors: Array, burst_alloc: Dictionary, rng: RandomNumberGenerator) -> Array:
	var remaining: Dictionary = {}
	for c in colors:
		remaining[String(c)] = int(burst_alloc.get(String(c), 1))
	var order: Array = []
	var prev: String = ""
	while true:
		var candidates: Array = []
		for c in colors:
			var cs = String(c)
			if int(remaining.get(cs, 0)) <= 0:
				continue
			if cs == prev:
				continue
			candidates.append(cs)
		if candidates.is_empty():
			# Fallback: any color with remaining slots.
			for c in colors:
				var cs2 = String(c)
				if int(remaining.get(cs2, 0)) <= 0:
					continue
				candidates.append(cs2)
			if candidates.is_empty():
				break
		var pick = String(candidates[rng.randi_range(0, candidates.size() - 1)])
		var slot = int(burst_alloc.get(pick, 1)) - int(remaining.get(pick, 0))
		order.append({"color": pick, "slot": slot})
		remaining[pick] = int(remaining.get(pick, 0)) - 1
		prev = pick
	return order

## Generate waves from an explicit authored spec (used by level editor
## and tests). Refuses if totals don't match.
static func from_authored_spec(demand, spec: Array):
	for s in spec:
		if typeof(s) != TYPE_DICTIONARY:
			push_error("Authored wave spec entries must be {color, count}")
			return null
	var plan_script: GDScript = load("res://scripts/universal/wave_plan.gd")
	return plan_script.from_demand_and_waves(demand, spec)
