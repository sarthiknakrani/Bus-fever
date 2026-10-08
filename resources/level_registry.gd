extends RefCounted
class_name LevelRegistry

## Central registry for all game levels.
## Provides level building, level count, titles, and metadata.

const Level1Factory := preload("res://resources/level_1.gd")
const Level2Factory := preload("res://resources/level_2.gd")
const Level3Factory := preload("res://resources/level_3.gd")
const Level4Factory := preload("res://resources/level_4.gd")
const Level5Factory := preload("res://resources/level_5.gd")

static func get_level_count() -> int:
	return 5

static func get_level(level_number: int) -> LevelData:
	match level_number:
		1: return Level1Factory.new().build()
		2: return Level2Factory.new().build()
		3: return Level3Factory.new().build()
		4: return Level4Factory.new().build()
		5: return Level5Factory.new().build()
		_: return Level1Factory.new().build()

static func get_level_title(level_number: int) -> String:
	match level_number:
		1: return "Level 1: First Departure"
		2: return "Level 2: Downtown Rush"
		3: return "Level 3: Crossroad Jam"
		4: return "Level 4: Highway Roundabout"
		5: return "Level 5: Grand Terminal"
		_: return "Level %d" % level_number
