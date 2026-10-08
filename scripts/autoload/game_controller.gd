extends Node
## Global game state: current scene, transitions, haptics, etc.

signal scene_loaded(scene_path: String)
signal back_to_home()

var _current_level_path: String = ""
var current_level_number: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	current_level_number = SaveManager.get_current_level()

func start_level(level_num: int) -> void:
	current_level_number = level_num
	SaveManager.set_current_level(level_num)
	goto_scene("res://scenes/level1.tscn")

func next_level() -> void:
	var next_num := current_level_number + 1
	var total := 5
	if next_num > total:
		next_num = 1
	start_level(next_num)

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