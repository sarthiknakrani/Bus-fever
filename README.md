# Bus Fever Party! — Clone

A full-featured 3D traffic-blocking bus puzzle game built in Godot 4, matching the mechanics and presentation of the hit mobile game **Bus Fever Party!** (`gridplus.busjam.carpuzzle`).

---

## Features & Enhancements

1. **Vibrant 3D Visuals & Parking Lot Setting**:
   - Stylized 3D buses with roof directional arrows, passenger seats, chibi occupants, headlights, and taillights.
   - Asphalt parking lot with yellow stall lines, dashed lane dividers, zebra crosswalks, concrete curbs, and traffic cones.
   - Stylized Bus Stop Shelter with sign, and roadside trees.
   - Visible 3D passenger queue line of chibi characters waiting on the sidewalk.
2. **Dynamic Escape Navigation & Animations**:
   - Multi-stage escape drive: buses surge forward along their clear path, steer towards the road, and pull into bays with suspension settle.
   - Parabolic hopping passenger boarding animations straight into the bus seats.
   - Departure celebrations with bus horn, speed burst, and tire smoke / dust particles (`CPUParticles3D`).
3. **Procedural Sound Synthesis & Looping Music**:
   - High-quality 16-bit 22050Hz audio synthesized in `AudioManager` (`AudioStreamWAV`).
   - Sound effects: tactile UI clicks, bus tap chirp, blocked horn, engine zoom, parking brake, passenger boarding chimes, departure horn, victory fanfare, fail buzzer, booster sparkle.
   - Gentle, relaxing acoustic puzzle groove looping in the background.
4. **Levels & Progression**:
   - 5 curated, validated levels registered in `LevelRegistry`:
     - **Level 1**: First Departure (7×7, 12 buses, 48 passengers)
     - **Level 2**: Downtown Rush (6×6, 8 buses, 32 passengers)
     - **Level 3**: Crossroad Jam (7×7, 10 buses, 40 passengers)
     - **Level 4**: Highway Roundabout (7×7, 12 buses, 48 passengers)
     - **Level 5**: Grand Terminal (8×8, 14 buses, 56 passengers)
   - Progression tracking, stars rating (⭐⭐⭐), and level unlock system saved in `SaveManager`.
5. **Boosters & Casual Mobile UI**:
   - Modern casual HUD with Level title badge, passenger queue counter, coins display, and star ratings.
   - Booster dock:
     - 💡 **Hint**: Highlights optimal bus with pulsating bounce.
     - ↺ **Undo**: Reverses the previous move.
     - 🅿️ **+1 Bay**: Unlocks 6th temporary parking bay.
     - 🔀 **VIP Shuffle**: Highlights available buses.
   - Juicy celebration modals with celebratory confetti particles and star rating slams.

---

## Run the Game

```sh
godot --path .                     # launches the main menu
godot --path . scenes/level1.tscn  # jumps straight to gameplay
```

---

## Run the Test Suite

```sh
godot --headless --script res://tests/test_level.gd
godot --headless --script res://tests/test_all_levels.gd
```

All 10 tests in `test_level.gd` and all level validations in `test_all_levels.gd` pass with 0 failures.

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
| Hint Solver | `scripts/core/hint_solver.gd` | BFS over logical states; proves solvability and finds hints |
| Undo Manager | `scripts/core/undo_manager.gd` | Snapshot stack for rollbacks |
| Audio | `scripts/autoload/audio_manager.gd` | Procedural sound effect and music synthesis |
| Save / Settings | `scripts/autoload/save_manager.gd` | Persistent save file (coins, boosters, level progress, stars) |
| Game Controller | `scripts/autoload/game_controller.gd` | Scene transitions and level navigation |
| Gameplay Scene | `scripts/level1.gd`, `scenes/level1.tscn` | 3D presentation, procedural meshes, animations, HUD |
| Main Menu | `scripts/main.gd`, `scenes/main.tscn` | Title menu, level select modal, settings overlay |