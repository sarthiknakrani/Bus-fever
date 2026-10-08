extends Node
## Persistent player settings. Persists to user://settings.cfg via SaveManager.

const KEY_MUSIC := "music"
const KEY_SFX := "sfx"
const KEY_HAPTICS := "haptics"

var _music: bool = true
var _sfx: bool = true
var _haptics: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Default values applied; SaveManager will load any persisted overrides.
	_save.apply_defaults({
		KEY_MUSIC: true, KEY_SFX: true, KEY_HAPTICS: true,
	})
	_music = _save.get_bool(KEY_MUSIC, true)
	_sfx = _save.get_bool(KEY_SFX, true)
	_haptics = _save.get_bool(KEY_HAPTICS, true)

@onready var _save: Node = get_node_or_null("/root/SaveManager")

func set_music(enabled: bool) -> void:
	_music = enabled
	if _save:
		_save.set_value(KEY_MUSIC, enabled)

func set_sfx(enabled: bool) -> void:
	_sfx = enabled
	if _save:
		_save.set_value(KEY_SFX, enabled)

func set_haptics(enabled: bool) -> void:
	_haptics = enabled
	if _save:
		_save.set_value(KEY_HAPTICS, enabled)

func music_enabled() -> bool: return _music
func sfx_enabled() -> bool: return _sfx
func haptics_enabled() -> bool: return _haptics