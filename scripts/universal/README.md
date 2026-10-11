# Universal Passenger System

A self-contained, level-independent module for the Bus Fever Party clone
that builds on (but does not replace) the existing CarJamLevelData / 
CarJamController / CarJamPassengerQueue code.

## Why a separate module?

The existing `scripts/gameplay/` tree is a working, tested 2.5D
production pipeline. The universal system is intentionally **additive**:
it ships as a parallel library that the legacy code can consume via
`LevelIntegration.build_runtime()` without rewriting the rendering /
boarding animation layers.

## Files

| File | Role |
|---|---|
| `passenger_demand.gd` | Calculates per-color demand and per-bus remaining from any level |
| `wave_plan.gd` | Ordered (color, count) wave plan + validation + flatten to per-passenger |
| `wave_generator.gd` | Procedural wave generator with difficulty knobs + seeded RNG |
| `solvability_validator.gd` | Deterministic validator that proves at least one winning action sequence exists |
| `passenger_sequence.gd` | Runtime feeder FSM: pending → feeder → circulating → boarding → completed |
| `level_integration.gd` | Bridge adapters that convert CarJamLevelData into the universal types |
| `README.md` | This file |

## Properties

* **Level-independent.** Works with 2 colors × 4 small buses (easy), 4
  colors × 14 buses × 56 passengers (hard), or 5 buses × 40 passengers
  × 240 total (stress) — no logic changes.
* **Authored or procedural.** Authored `.gd` / `.tres` levels can
  specify exact waves; the generator produces seeded plans for
  procedural levels.
* **Solvability-checked.** `SolvabilityValidator.is_solvable` proves
  the existence of at least one winning player-action sequence under
  the actual gameplay rules (parking atomicity, color matching, partial
  fills). Failed plans are rejected before play.
* **No hardcoded counts.** The 240-passenger / 40-capacity numbers in
  Level 1 are an example, not a global rule.

## Quick usage

```gdscript
const LevelIntegration = preload("res://scripts/universal/level_integration.gd")

# 1. Build runtime for an existing level resource
var runtime = LevelIntegration.build_runtime(lvl_data, 40, 4)
assert(runtime.validation.solvable, runtime.validation.reason)

# 2. Read the feeder
var sequence: PassengerSequence = runtime.sequence
var head_color = sequence.head_color()
var run_len = sequence.head_run_length()

# 3. Release more passengers as feeder space allows
while feeder_has_space:
    var released = sequence.try_release_one_to_feeder()
    if released < 0:
        break

# 4. Boarding
var claimed = sequence.try_claim_for_boarding(bus.color_id)
if claimed >= 0:
    animate_passenger(claimed, bus)
    # ... after animation:
    sequence.mark_boarded(claimed)
```

## Testing

```
godot --headless --script res://tests/test_universal_passenger.gd
```

Covers Easy / Medium / Hard / Stress configurations and verifies the
universal logic never over-allocates, never under-serves, and never
accepts an unsolvable plan.
