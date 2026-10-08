extends SceneTree
func _init():
    var lvl = ResourceLoader.load("res://levels/level_001.tres")
    for v in lvl.vehicles:
        print("Vehicle: id=", v.id, " color=", v.color_id, " dir=", v.direction, " anchor=", v.anchor, " footprint=", v.footprint)
    quit()
