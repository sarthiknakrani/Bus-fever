# Universal Passenger System — Final Architecture

## 1. Final reusable architecture

The universal passenger system is implemented as a self-contained
module under `scripts/universal/`. It does not depend on the rest of the
game at runtime — every script is `RefCounted` or `Resource` with no
scene-tree references. It can be unit-tested headless and consumed by
any host (the existing `CarJamLevel`, a future 2D version, a future 3D
version, or a CLI solver).

```
scripts/universal/
├── passenger_demand.gd      # Per-color demand + per-bus remaining seats
├── wave_plan.gd             # Ordered (color, count) wave plan + flatten
├── wave_generator.gd        # Authored + seeded procedural generators
├── solvability_validator.gd # Deterministic logical validator
├── passenger_sequence.gd    # Runtime FSM: feeder / circulation / boarding
├── level_integration.gd     # Bridge to CarJamLevelData and friends
└── README.md
```

The visual layer (`scripts/gameplay/car_jam_level.gd`) now uses a small
adapter (`_build_universal_passenger_queue`) to pull the flat
per-passenger sequence from the universal layer. If the universal
plan is rejected (e.g. malformed level data), the legacy RNG
generator remains as a documented fallback. This is the smallest
necessary integration and preserves all existing visuals.

## 2. Level configuration schema

Each level exposes its buses through `level_data.vehicles`. Each bus
provides:

| Field | Purpose |
|---|---|
| `id` | Stable identifier (used as `code`) |
| `code` | Display name |
| `color_id` | Which colour this bus serves |
| `capacity` | Total seats |
| `anchor` | Board cell coordinate |
| `footprint` | Multi-cell footprint |
| `direction` | Board orientation (UP/DOWN/LEFT/RIGHT) |

The universal layer reads `vehicles` and produces a `PassengerDemand`
that computes demand per colour as the sum of capacities for that colour.

A level may optionally carry authored wave groups (`level_data.passenger_groups`).
When present, the universal layer converts those groups into a `WavePlan`
(one group → one wave). When absent, `WaveGenerator.generate(demand, cfg)`
produces a candidate plan with a configurable difficulty profile.

## 3. Passenger demand calculation

```gdscript
var demand = PassengerDemand.from_carjam_level(lvl)
# Returns: total, by_color{}, buses_by_color{}, bus_order[]
```

`PassengerDemand` is the universal source of truth for the question
"how many of each colour must we serve?". The formula:

```
demand.by_color[c] = sum(b.capacity for b in vehicles if b.color_id == c)
demand.total       = sum(b.capacity for b in vehicles)
```

No hardcoded numbers. A level with 6 red + 6 blue + 6 yellow buses of
capacity 40 yields `by_color = {red:240, blue:240, yellow:240}` and
`total = 720`. A level with 2 small buses yields a two-bus 8-passenger
demand. Both are accepted.

## 4. Wave generation

Two modes, both producing a `WavePlan` of shape
`Array[{color: String, count: int}]`:

### Authored mode

`WaveGenerator.from_authored_spec(demand, [{color, count}, ...])`
or `WavePlan.from_demand_and_waves(demand, raw_waves)`. Refuses if the
plan totals don't match demand. This is the path for level designers.

### Procedural mode

`WaveGenerator.generate(demand, DifficultyConfig) -> WavePlan`

`DifficultyConfig` exposes:

| Knob | Default | Effect |
|---|---|---|
| `min_wave_size` | 4 | Lower bound on a single wave size |
| `max_wave_size` | 24 | Upper bound on a single wave size |
| `preferred_wave_size` | 8 | Bias point for variable selection |
| `split_wave_probability` | 0.55 | How often one colour's demand is split into multiple bursts |
| `target_bursts` | -1 (=2×colors) | Total number of wave slots across all colours |
| `rng_seed` | 0 (=time-based) | Reproducible generation |

The generator:
1. Allocates burst slots per colour, biased so larger colours get more bursts.
2. Splits each colour's demand into per-burst positive integers bounded by `min_wave_size` and `max_wave_size`.
3. Interleaves bursts across colours so adjacent same-colour waves are uncommon — they occur only when one colour exhausts.
4. Corrects rounding drift so the final plan exactly matches demand.
5. Optionally accepts a self-validity hint (refuses plans whose color-bursts prefix exceeds slot count).

Same seed produces identical plans; different seeds produce different plans. Tests verify both behaviours.

## 5. Initial population

`PassengerSequence._init(plan, initial_circulating_count)` puts the
first `initial_circulating_count` passengers directly into the
CIRCULATING state and the remainder into PENDING (waiting in feeder).
Default `initial_circulating_count = 40` matches the legacy behaviour.

## 6. Feeder release logic

The feeder is never told to release more than the queue can supply:
- `try_release_one_to_feeder()` returns the next passenger's id, or -1.
- `release_many_to_feeder(n)` releases up to `n` and returns the actual count released.
- `try_advance_feeder_to_loop()` moves a passenger from FEEDER → CIRCULATING when it crosses the merge point.

There is exactly one path into the feeder (PENDING → FEEDER), and
exactly one path out (FEEDER → CIRCULATING). A passenger is never
duplicated or skipped. The visual layer drives calls to these
primitives at the existing cadence.

## 7. Four-lane formation

```
LANE_SPACING = 20.0   (logical)
ROW_SPACING  = 22.0
NUM_LANES    = 4
```

Track width is 132 px (Antigravity commit cad4d77) — 4 lanes × 22 px
+ two margin shoulders. Lane offsets are computed in `car_jam_level.gd`
as `(lane - 1.5) * LANE_SPACING` against the curve normal at the
passenger's progress, with row spacing enforced between adjacent rows.

## 8. Boarding eligibility

`PassengerSequence.try_claim_for_boarding(color)` returns the index of
the matching passenger who has been released (PENDING not eligible) and
is currently CIRCULATING (BOARDING not eligible — prevents
double-boarding). The runtime animates the hop, then calls
`mark_boarded()` to commit, or `release_boarding()` to roll back.

The "head color" of the feeder is also exposed via `head_color()` and
the contiguous same-color run length via `head_run_length()` so the
runtime can board a strip of up to 4 passengers in one animation cycle.

## 9. Partial-bus states

The runtime allows a parked bus to remain OCCUPIED until its capacity
is exhausted. The Carrier (`CarJamController`) tracks `pending_boarders`
as a per-bus counter so we never exceed capacity. Once `remaining == 0`,
the bus transitions to FULL → DEPARTING → COMPLETED and the slot is
released only after the departure animation finishes.

The universal `PassengerSequence` tracks per-passenger state and
prevents the same passenger from being claimed twice. The validator
mirrors this by tracking per-bus remaining seats and refusing to exceed
them during simulation.

## 10. Solvability validation

`SolvabilityValidator.validate(demand, plan, slot_count)` returns a
`Result` with `solvable: bool`, `dispatched: Array`, `filled:
Dictionary`, `reason: String`, `steps: int`.

The simulation is faithful to the runtime:
- Each step computes the current feeder head colour.
- Up to `head_len` matching passengers board any parked bus of that colour.
- A bus whose remaining seats reach 0 immediately releases its slot.
- If a free slot exists AND a bus of head colour is undispatched, it is dispatched.
- Termination: all buses dispatched-and-full AND feeder empty → success; otherwise the loop continues.
- A bounded iteration count (8192) and a progress check protect against runaway.

A `is_solvable_fast` cheap pre-check is exported for wave generation
use, but the full validator is the source of truth.

## 11. Debugging and test strategy

Run headless:
```
godot --headless --path . --script res://tests/test_universal_passenger.gd
godot --headless --path . --script res://tests/test_bus_timings.gd
```

Current results (this commit):
- `test_universal_passenger.gd`: **74 passes / 0 failures** (12 test categories: Easy, Medium, Hard, Stress, Authored validation, Partial-fill lifecycle, Double-board safety, Returning-color continuation, Seed determinism, Initial on-loop population, Feeder release idempotence, Legacy CarJamLevelData round-trip).
- `test_bus_timings.gd`: **All timing & gameplay tests passed (0 failures)** — confirms the existing visuals + 0.80s bus timings + 4-lane feeder remain intact.

The 12 universal test categories cover the four required
configurations (Easy / Medium / Hard / Stress) plus six targeted
correctness scenarios:

| Config | Coverage |
|---|---|
| Easy | 2 colors, 4+4 small buses, simple waves |
| Medium | 3 colors, 9 buses cap 8, split waves, returning colors |
| Hard | 4 colors, 13 buses cap 4, tight 4-slot parking |
| Stress | 6 buses cap 40, 240 passengers, full feeder pipeline |
| Authored validation | Rejects mismatched totals; accepts balanced |
| Partial-fill lifecycle | Bus fills across non-contiguous waves |
| Double-board safety | Cannot board the same passenger twice |
| Returning color | Later red wave resumes boarding on parked bus |
| Seed determinism | Same seed → identical plan; different seed → different plan |
| Initial population | First 4 pre-circulating pre-loaded before feeder |
| Feeder release | No duplicate, no skip, deterministic order |
| Legacy round-trip | Existing level groups convert 1:1 and verify solvable |

## 12. How new levels use the system

A new level (level `N+1`) is added by writing a single
`resources/level_N+1.gd` (or `.tres`) describing buses' colors and
capacities. The `LevelIntegration.build_runtime()` function consumes
this and produces:

1. `demand` — used by the UI counter (color totals) and validator.
2. `plan` — the ordered wave list, ready for the feeder sequence.
3. `sequence` — the per-passenger FSM, ready for the runtime feeder.
4. `validation` — solver proof that the level is winnable.

The runtime binds `sequence` to its 4-lane track and the existing
controller. No game-logic code change is required.

For procedurally generated levels:
```
var demand = PassengerDemand.from_carjam_level(lvl)
var cfg = WaveGenerator.DifficultyConfig.new()
cfg.rng_seed = 42   # for reproducible level N
var plan = WaveGenerator.generate(demand, cfg)
assert(SolvabilityValidator.is_solvable(demand, plan, lvl.parking_slots_count))
```

That is the entire authoring surface for new levels.
