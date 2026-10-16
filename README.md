# Bus Fever Party! — Clone

A full-featured traffic-blocking bus puzzle game built in Godot 4, matching the mechanics and presentation of the hit casual mobile game **Bus Fever Party!** (`gridplus.busjam.carpuzzle`).

The project ships two dedicated presentation layers:
1. **3D-Style "Car Jam" Scene** ([`scenes/gameplay/car_jam_level.tscn`](file:///Users/nakranisarthikashokbhai/Documents/Bus%20Fever%20Party%20clone/scenes/gameplay/car_jam_level.tscn)): Features 3D-shaded vehicles, animated oval racetrack passenger boarding, 45° diagonal manicured garden environment, and dynamic bus departures.
2. **2.5D "Bus Fever" Scene** ([`scenes/level1.tscn`](file:///Users/nakranisarthikashokbhai/Documents/Bus%20Fever%20Party%20clone/scenes/level1.tscn)): Lightweight procedural 2.5D presentation with smooth tween-based vehicle pathfinding, passenger queue stream, and parking bays.

---

## Levels & Content

All 5 curated, validated levels are registered in `LevelRegistry` with balanced capacity and demand:

| Level | Name | Board Size | Vehicles | Total Passengers | Bays |
|---|---|---|---|---|---|
| **Level 1** | First Departure | 7 × 7 | 12 | 48 | 5 |
| **Level 2** | Downtown Rush | 6 × 6 | 8 | 32 | 5 |
| **Level 3** | Crossroad Jam | 7 × 7 | 10 | 40 | 5 |
| **Level 4** | Highway Roundabout | 7 × 7 | 12 | 48 | 5 |
| **Level 5** | Grand Terminal | 8 × 8 | 14 | 56 | 5 |

---

## Features & Gameplay Mechanics

1. **Title Logo & Home Screen Presentation**:
   - Razor-sharp 3D candy lettering with unsharp masking and retina mipmaps.
   - Royal dark navy blue outer bevel framing all letters ("BUS", "FEVER", "PARTY!").
   - Letter "P" in "PARTY!" features vibrant 3D candy orange cushion face with matching royal dark navy 3D extrusion.
   - Thinner, calm periodic diagonal glossy shine sweep animation (`Tween.TRANS_SINE`).
2. **Garden & Track Environment**:
   - Manicured 45-degree diagonal lawn mower grass stripes (`#6CBF4B` light grass green and `#63B544` medium lawn green).
   - Stylized cartoon hedges, daisy accents, and smooth racetrack asphalt curb.
3. **Core Puzzle Logic & Simulation**:
   - Authoritative grid clearance and directional raycasting (NORTH, SOUTH, EAST, WEST).
   - Real-time deadlock detection (`HintSolver.is_dead_end` and `LevelController._check_win_fail`).
   - FIFO passenger queue matching, seat reservation, and deterministic bay allocation.
   - Snapshot-based Undo stack and hint BFS solver.
4. **Procedural Sound & Audio**:
   - Synthesized 16-bit 22050Hz audio in `AudioManager` (`AudioStreamWAV`).
   - Sound effects: tactile UI clicks, bus taps, departure horns, boarding chimes, victory fanfare, and relaxing acoustic background music.

---

## Running the Game

```sh
# Launch main menu & home screen
godot --path .

# Jump directly to 2.5D Bus Fever level scene
godot --path . scenes/level1.tscn

# Jump directly to 3D Car Jam gameplay scene
godot --path . scenes/gameplay/car_jam_level.tscn
```

---

## Test Suite

The project includes an extensive suite of automated headless QA tests covering puzzle mechanics, deadlock detection, responsive resolutions, and visual rendering:

```sh
# Run the complete test suite runner
./tests/run_all.sh

# Run core puzzle logic & validation tests
godot --headless --path . --script res://tests/test_level.gd
godot --headless --path . --script res://tests/test_all_levels.gd
godot --headless --path . --script res://tests/test_deadlock.gd

# Run visual & UI tests
godot --headless --path . --script res://tests/test_qa_title_logo.gd
godot --headless --path . --script res://tests/test_car_jam_level_integration.gd
```

---

## Architecture

| System | File | Responsibility |
|---|---|---|
| Level Registry | `resources/level_registry.gd` | Maps levels 1–5, provides level count and metadata |
| Level Resources | `resources/level_*.gd` | Pure data specifications for each level layout & queue |
| Level Data | `scripts/core/level_data.gd` | Data validation (capacity == demand, bounds, overlaps) |
| Board | `scripts/core/board.gd` | Authoritative 2D grid occupancy and escape path clearance |
| Bay Manager | `scripts/core/bay_manager.gd` | Allocation & states of parking bays (FREE / RESERVED / OCCUPIED) |
| Passenger Manager | `scripts/core/passenger_manager.gd` | FIFO queue, color matching, seat reservation |
| Vehicles | `scripts/core/vehicle.gd` | State machine: IDLE, AVAILABLE, BLOCKED, MOVING, WAITING, FULL, DEPARTING |
| Level Controller | `scripts/core/level_controller.gd` | Unidirectional authoritative gameplay controller |
| Hint Solver | `scripts/core/hint_solver.gd` | BFS over logical states; proves solvability, finds hints, and detects dead ends |
| Undo Manager | `scripts/core/undo_manager.gd` | Snapshot stack for rollbacks |
| Audio Manager | `scripts/autoload/audio_manager.gd` | Procedural sound effect and music synthesis |
| Save Manager | `scripts/autoload/save_manager.gd` | Persistent save file (coins, boosters, level progress, stars) |
| Game Controller | `scripts/autoload/game_controller.gd` | Scene transitions and level navigation |
| Car Jam Gameplay | `scripts/gameplay/` | 3D-style presentation, oval track, stylized garden, vehicle animations |
| 2.5D Gameplay | `scripts/level1.gd`, `scenes/level1.tscn` | 2.5D presentation, procedural drawing, HUD, animations |
| Main Menu | `scripts/main.gd`, `scenes/main.tscn` | Home screen, static resort backdrop, title logo with gloss shine |