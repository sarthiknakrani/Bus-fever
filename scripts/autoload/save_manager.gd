extends Node
## Persistent save data. Tiny KV store backed by user://save.cfg.
## Keys are strings; values can be bool/int/float/String.

const KEY_TUTORIAL_DONE := "tutorial_done"
const KEY_LEVEL_1_DONE := "level_1_done"
const KEY_CURRENT_LEVEL := "current_level"
const KEY_MAX_UNLOCKED_LEVEL := "max_unlocked_level"
const KEY_COINS := "coins"
const KEY_HINTS := "booster_hints"
const KEY_UNDOS := "booster_undos"
const KEY_EXTRA_BAYS := "booster_extra_bays"

var _data: Dictionary = {}
var _path := "user://save.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	set_value(KEY_COINS, 0)
	_init_defaults()

func _init_defaults() -> void:
	if not _data.has(KEY_CURRENT_LEVEL):
		_data[KEY_CURRENT_LEVEL] = 1
	if not _data.has(KEY_MAX_UNLOCKED_LEVEL):
		_data[KEY_MAX_UNLOCKED_LEVEL] = 1
	if not _data.has(KEY_COINS):
		_data[KEY_COINS] = 0
	if not _data.has(KEY_HINTS):
		_data[KEY_HINTS] = 5
	if not _data.has(KEY_UNDOS):
		_data[KEY_UNDOS] = 5
	if not _data.has(KEY_EXTRA_BAYS):
		_data[KEY_EXTRA_BAYS] = 3

func apply_defaults(defaults: Dictionary) -> void:
	for k in defaults.keys():
		if not _data.has(k):
			_data[k] = defaults[k]

func get_bool(k: String, fallback: bool = false) -> bool:
	if not _data.has(k):
		return fallback
	var v = _data[k]
	if v is bool:
		return v
	if v is int or v is float:
		return bool(v)
	if v is String:
		return v == "1" or v.to_lower() == "true"
	return fallback

func get_int(k: String, fallback: int = 0) -> int:
	if not _data.has(k):
		return fallback
	return int(_data[k])

func set_value(k: String, v: Variant) -> void:
	_data[k] = v
	_save()

func has_key(k: String) -> bool:
	return _data.has(k)

func get_value(k: String, fallback: Variant = null) -> Variant:
	if not _data.has(k):
		return fallback
	return _data[k]

func tutorial_done() -> bool:
	return get_bool(KEY_TUTORIAL_DONE, false)

func set_tutorial_done(v: bool) -> void:
	set_value(KEY_TUTORIAL_DONE, v)

func level_1_done() -> bool:
	return get_bool(KEY_LEVEL_1_DONE, false)

func set_level_1_done(v: bool) -> void:
	set_value(KEY_LEVEL_1_DONE, v)

func get_current_level() -> int:
	return get_int(KEY_CURRENT_LEVEL, 1)

func set_current_level(lvl: int) -> void:
	set_value(KEY_CURRENT_LEVEL, maxi(1, lvl))

func get_max_unlocked_level() -> int:
	return get_int(KEY_MAX_UNLOCKED_LEVEL, 1)

func unlock_level(lvl: int) -> void:
	var cur := get_max_unlocked_level()
	if lvl > cur:
		set_value(KEY_MAX_UNLOCKED_LEVEL, lvl)

func get_coins() -> int:
	return get_int(KEY_COINS, 0)

func add_coins(amount: int) -> void:
	var c := get_coins() + amount
	set_value(KEY_COINS, maxi(0, c))

func get_booster_count(booster: String) -> int:
	match booster:
		"hint": return get_int(KEY_HINTS, 5)
		"undo": return get_int(KEY_UNDOS, 5)
		"extra_bay": return get_int(KEY_EXTRA_BAYS, 3)
		_: return 0

func use_booster(booster: String) -> bool:
	var cnt := get_booster_count(booster)
	if cnt <= 0:
		return false
	match booster:
		"hint": set_value(KEY_HINTS, cnt - 1)
		"undo": set_value(KEY_UNDOS, cnt - 1)
		"extra_bay": set_value(KEY_EXTRA_BAYS, cnt - 1)
	return true

func add_booster(booster: String, count: int = 1) -> void:
	var cnt := get_booster_count(booster) + count
	match booster:
		"hint": set_value(KEY_HINTS, cnt)
		"undo": set_value(KEY_UNDOS, cnt)
		"extra_bay": set_value(KEY_EXTRA_BAYS, cnt)

func get_level_stars(lvl: int) -> int:
	return get_int("level_%d_stars" % lvl, 0)

func set_level_stars(lvl: int, stars: int) -> void:
	var prev := get_level_stars(lvl)
	if stars > prev:
		set_value("level_%d_stars" % lvl, clampi(stars, 0, 3))

func _save() -> void:
	var cfg := ConfigFile.new()
	for k in _data.keys():
		cfg.set_value("data", k, _data[k])
	var err := cfg.save(_path)
	if err != OK:
		push_warning("SaveManager: failed to save %s (err %d)" % [_path, err])

func _load() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(_path)
	if err != OK:
		# First launch / missing save — fine.
		_data = {}
		return
	_data = {}
	for k in cfg.get_section_keys("data"):
		_data[k] = cfg.get_value("data", k)

func wipe() -> void:
	_data = {}
	_save()