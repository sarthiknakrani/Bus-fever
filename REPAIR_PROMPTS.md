# Repair Prompts — Bus Fever Party Clone

Curated, scoped repair tasks for an AI agentic coding tool. Each prompt is self-contained, has a single goal, and includes a clear success criterion. Run them in order; later prompts may depend on earlier ones.

---

## Context block (paste this once at the start of any session)

```
Project: Bus Fever Party clone — Godot 4 puzzle game.
Layout:
  - scripts/core/         pure puzzle logic (no scene refs)
  - scripts/autoload/     singletons (GameController, SaveManager, AudioManager, SettingsManager)
  - scripts/gameplay/     second implementation (Car Jam variant) — 3D-looking sprites, oval passenger track
  - resources/            pure data (level_1..5.gd, level_registry.gd)
  - scripts/main.gd, scripts/level1.gd   main menu and 2.5D level scene (older Bus Fever variant)
  - tests/                30+ headless tests in tests/test_*.gd

Two parallel implementations exist. The 2.5D "Bus Fever" scene is loaded via scenes/level1.tscn and uses
scripts/level1.gd + the scripts/core/ controllers. The 3D-looking "Car Jam" scene is loaded via
scenes/gameplay/car_jam_level.tscn and uses scripts/gameplay/ + the CarJamController in scripts/gameplay/car_jam_controller.gd.

When making changes, decide which implementation is in scope based on the user's wording. If unclear, ask.
Run the headless tests after any change to scripts/core/ with:
    godot --headless --path . --script res://tests/test_level.gd
    godot --headless --path . --script res://tests/test_all_levels.gd
```

---

## R-01: Fix the `is_dead_end` solver lying about BFS

**Goal**: Make `HintSolver.is_dead_end` actually run BFS as its docstring claims, or change the docstring to match reality.

**File**: `scripts/core/hint_solver.gd`

**Current** (last 7 lines of `is_dead_end`):
```gdscript
func is_dead_end(state: SimState, max_nodes: int = 1500) -> bool:
    if _is_win(state):
        return false
    var moves := enumerate_moves(state)
    if moves.size() > 0:
        return false
    return true  # immediate dead node
```

**Success criteria**:
- If you keep the "no immediate moves = dead end" approximation, update the docstring to drop the "We approximate by re-running BFS" lie. Note that this is sound only because the surrounding `_check_win_fail` is called after every player action, so a forced move that does not reach WIN can itself trigger the dead-end check.
- If you implement the BFS, return true only when `find_solution(state, max_nodes)` returns an empty list. Add a unit test in `tests/test_level.gd` that constructs a known dead-end state and asserts `is_dead_end` returns true.

---

## R-02: Remove the unreachable `return active == ""` in `_is_pure_dead_end`

**Goal**: Tighten a dead branch.

**File**: `scripts/core/hint_solver.gd`, in `func _is_pure_dead_end`.

**Current** (last 3 lines):
```gdscript
    # Now check: if every bus that can still escape is wrong-color, AND every
    # parked bus that matches active has no free bay to swap into, dead.
    # Simpler: if no on-board match AND no parked match, dead.
    return active == ""  # shouldn't happen since _is_win caught
```

**Success criterion**:
- The `return active == ""` is unreachable (the only caller is `find_solution`, which short-circuits on `_is_win` first). Replace it with a `return false` plus a `push_warning` so the impossible state is logged if it ever happens. Or, more defensively, replace with a `return _is_pure_dead_end_by_state(state)` helper that walks the state.

---

## R-03: Bound `_all_path_cells` to board size

**Goal**: Stop the dead helper from producing out-of-bounds cells.

**File**: `scripts/core/hint_solver.gd`, in `func _all_path_cells`.

**Current**:
```gdscript
func _all_path_cells(v: VehicleData) -> Array:
    var d: Vector2i = VehicleDataScript.dir_to_vector(v.direction)
    var path: Array = []
    var p: Vector2i = v.position + d
    while p.x >= 0 and p.y >= 0:
        path.append(p)
        p += d
    return path
```

**Success criterion**:
- Add a `board_size: Vector2i` parameter and check `p.x < board_size.x` and `p.y < board_size.y` in the loop. Since the function is currently dead code (no caller), also confirm it has no callers via `grep`; if it has none, delete it instead.

---

## R-04: Add a deadlock test

**Goal**: Lock in deadlock detection with a real test.

**File**: new file `tests/test_deadlock.gd`.

**Success criteria**:
- Create a small custom `LevelData` (e.g. 3×3 board, 1 blue bus facing NORTH, 1 red bus facing NORTH blocking it, 1 red bus in front of the blue one — so neither can move, and no parked bus matches the active color).
- Load it into a `LevelController`, simulate a state where one wrong-color bus is parked and no on-board bus can escape, then call `_check_win_fail` (or whatever entry point is public).
- Assert `game_state == LevelController.GameState.FAIL`.
- Wire the new test into the suite so `godot --headless --path . --script res://tests/test_deadlock.gd` returns exit 0 on pass.

---

## R-05: Fix `_check_win_fail` clobbering the interaction lock

**Goal**: WIN and FAIL states should keep `_interaction_locked = true` so the player cannot tap buses after the game is decided, even before the visual depart animation finishes.

**File**: `scripts/core/level_controller.gd`, in `func _on_arrived_at_bay` (the trailing `_interaction_locked = false` line).

**Current** (last 2 lines):
```gdscript
    _check_win_fail()
    _interaction_locked = false
```

**Success criterion**:
- Change the final line so it only unlocks when `game_state == GameState.PLAYING`. Suggested replacement:
  ```gdscript
  if game_state == GameState.PLAYING:
      _interaction_locked = false
  ```
- Update or add a test in `tests/test_level.gd` that asserts `_interaction_locked` stays true after a winning move is played and the game reaches WIN.

---

## R-06: Type `Vehicle.data` and remove the dead-code read

**Goal**: Make `Vehicle.data` typed, or drop it.

**File**: `scripts/core/vehicle.gd` (declaration) and `scripts/level1.gd` (read at line ~491-492 of the read we did, currently `if v.data != null and "length" in v.data: v_len = v.data.length`).

**Success criteria**:
- Either:
  1. Change `var data` to `@export var data: VehicleData`, and update `level1.gd` to use it: `var v_len: int = v.data.length if v.data else 1`. Or
  2. Delete `data` entirely from `Vehicle` (and from `Vehicle.setup`). It is only used in `level1.gd` and the read is dead because Level 1's vehicles never have `length` set.
- Whichever you choose, the existing 10 unit tests in `test_level.gd` must still pass.

---

## R-07: Use `LevelData.tutorial_triggers` or delete it

**Goal**: Either wire tutorial triggers into the 2.5D HUD or stop carrying the field.

**File**: `scripts/core/level_data.gd` (field), `resources/level_1.gd` (sets 4 triggers), `scripts/level1.gd` (never reads).

**Success criteria**:
- If you want to ship tutorials: in `level1.gd._init_level`, after building the scene, create a `Tween` that fires at each trigger's `after_seconds` and shows a Label/Hint popup near the bus at `vehicle_id`. Use `_controller.get_vehicle_by_id(vehicle_id).position` to place the hint.
- If you don't: remove `tutorial_triggers` from `LevelData`, remove the population in `level_1.gd` (and any other level that sets it).

---

## R-08: Drop the dead `LevelData.board_origin` / `bay_panel_origin` fields

**Goal**: Stop carrying config the scene ignores.

**File**: `scripts/core/level_data.gd` (declarations at lines ~13 and ~15), `resources/level_*.gd` (sets them).

**Success criteria**:
- Confirm via `grep` that `board_origin` and `bay_panel_origin` are read nowhere in the project (other than the writes in the level resource files).
- If confirmed, remove the fields from `LevelData` and the `lvl.board_origin = ...` / `lvl.bay_panel_origin = ...` lines from all 5 level files.
- Run `tests/test_all_levels.gd` to confirm validation still passes.

---

## R-09: Drop the dead `_to_cell` parameter from the move signal

**Goal**: Clean up an unused signal argument.

**File**: `scripts/core/level_controller.gd` (signal declaration at line 13), `scripts/level1.gd` (handler `_on_request_move_animation` ignores it via `_to_cell`).

**Success criteria**:
- Remove the `_to_cell: Vector2i` parameter from the `request_move_animation` signal and update the `emit_signal` site in `tap_vehicle` to match.
- Update the handler signature in `level1.gd` to drop the parameter. The existing placeholder `_to_cell` is fine to leave as a renamed variable, but the signal should not carry it.

---

## R-10: Replace the misleading README feature list with verified truth

**Goal**: Stop the README from lying about the visual style and the bus counts.

**File**: `README.md`.

**Issues**:
- README claims "Stylized 3D buses" and "3D Visual" but `scripts/level1.gd` line 3 declares "100% 2D Level Scene" with pseudo-3D 2D drawing. The 3D-looking visuals come from the Car Jam variant, not from this scene.
- README says "5 curated, validated levels" but does not list per-level bus counts. The table it shows for "Level 1" lists 12 buses; for Level 5 the README is silent but the level actually has 14.

**Success criteria**:
- Update the opening paragraph to mention that the project ships two presentation layers: a 2.5D "Bus Fever" scene (scripts/level1.gd) and a 3D-style "Car Jam" scene (scenes/gameplay/car_jam_level.tscn). Pick one as the headline visual.
- Add a small per-level table that lists bus count and passenger count for all 5 levels (read from `resources/level_*.gd`).
- Remove or rewrite the "3D embossed capacity badges" bullet to match the actual implementation.

---

## R-11: Confirm the 2.5D scene still runs end-to-end

**Goal**: After all the recent controller-API changes (R-01 through R-09 plus the earlier "best fix" patch), make sure tapping a bus, boarding, departure, undo, hint, restart, and win all behave.

**Files**: `scenes/level1.tscn` and the script `scripts/level1.gd`.

**Success criteria**:
- Open the project in Godot 4.7+, run `scenes/level1.tscn`, tap a free bus, watch it park, board passengers, and depart.
- Tap Hint — the suggested bus pulses.
- Tap Undo — the previous state is restored and the visual buses snap to their logical positions.
- Tap Restart — the board, queue, and HUD all reset.
- Win the level and confirm the Victory overlay appears.

(If a manual run is not feasible, write a smoke test that drives the controller through the same steps and asserts the final state is WIN.)

---

## R-12: Mark the Car Jam tests as the integration suite

**Goal**: There are 30+ test files in `tests/`. Most of the `test_*_qa.gd` files exercise `CarJamController` rather than the `LevelController`. The README only references `test_level.gd` and `test_all_levels.gd`. Wire a runner.

**File**: new file `tests/run_all.sh` (or `.bat`).

**Success criteria**:
- A shell script that runs every `tests/test_*.gd` (except `render_color_and_deadlock_screens.gd`, which is a one-off render) in headless mode, captures pass/fail counts, and exits 0 only if all pass.
- The script must tolerate missing tests (skip rather than fail) so adding new tests doesn't require editing the script.
- Document the script in the README under a new "Test Suite" subsection.

---

## Notes for the agent

- Always grep for callers before deleting a field, signal parameter, or method.
- Keep the controller's signal-based public surface stable: the scene layer (`level1.gd`) consumes `vehicle_state_changed`, `bay_state_changed`, `passenger_state_changed`, `game_state_changed`, `request_move_animation`, `request_board_animation`, `request_depart_animation`, `request_hint_pulse`, `request_blocked_shake`. Do not rename any of these.
- The `_on_arrived_at_bay` private method is called directly by `tests/test_level.gd`. Do not delete it; if you rename it, update the tests.
- After any change to `scripts/core/`, run the headless tests with `godot --headless --path . --script res://tests/test_level.gd` and `res://tests/test_all_levels.gd` before reporting success.
