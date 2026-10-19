extends Node
## Global game state: current scene, transitions, haptics, etc.

signal scene_loaded(scene_path: String)
signal back_to_home()

var _current_level_path: String = ""
var current_level_number: int = 1

const MAIN_SCENE := "res://scenes/main.tscn"
const GAMEPLAY_SCENE := "res://scenes/level1.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Always open the game at Level 1 on fresh launch. Player progression through the
	# levels is still recorded in SaveManager (per-level completion, max-unlocked), but
	# `current_level_number` deliberately does NOT auto-load from the saved state —
	# otherwise every launch skipped ahead to wherever the player last completed. The
	# play button (main.gd) reads this field when the user taps PLAY, so it stays at 1
	# until the user explicitly advances via the result panel's NEXT button or restarts.
	current_level_number = 1

func start_level(level_num: int) -> void:
	current_level_number = level_num
	SaveManager.set_current_level(level_num)
	goto_scene(GAMEPLAY_SCENE)

func next_level() -> void:
	var next_num := current_level_number + 1
	if has_level(next_num):
		start_level(next_num)
	else:
		# No further level authored — return to home.
		goto_scene(MAIN_SCENE)

## Authoritative check: does a level resource exist for the given 1-based number?
## Uses the actual disk files (res://levels/level_NNN.tres) rather than a hard-coded
## count, so the game never silently wraps around to Level 1.
func has_level(level_num: int) -> bool:
	if level_num < 1:
		return false
	var path := "res://levels/level_%03d.tres" % level_num
	return ResourceLoader.exists(path)

## Total authored level count — used by Level Select UI to know how many
## buttons to render and what the last available level is.
func available_level_count() -> int:
	var n := 1
	while has_level(n):
		n += 1
	return n - 1

func next_available_level(level_num: int) -> int:
	var n := level_num + 1
	while has_level(n):
		n += 1
	return n  # first non-existent level after `level_num`

func goto_scene(path: String) -> void:
	# Use SceneTree change_scene_to for clean transitions.
	var st := get_tree()
	if st == null:
		return
	var err := st.change_scene_to_file(path)
	if err != OK:
		push_error("Failed to load scene: %s (err %d)" % [path, err])
		return
	_current_level_path = path
	emit_signal("scene_loaded", path)

func current_scene_path() -> String:
	return _current_level_path

func is_mobile() -> bool:
	return OS.has_feature("mobile")

func haptic_light() -> void:
	if not SettingsManager.haptics_enabled():
		return
	Input.vibrate_handheld(15)

func haptic_medium() -> void:
	if not SettingsManager.haptics_enabled():
		return
	Input.vibrate_handheld(35)

func haptic_failure() -> void:
	if not SettingsManager.haptics_enabled():
		return
	Input.vibrate_handheld(80)

func haptic_success() -> void:
	if not SettingsManager.haptics_enabled():
		return
	Input.vibrate_handheld(60)
