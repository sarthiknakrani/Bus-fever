extends SceneTree
func _init():
    var dir = DirAccess.open("user://")
    if dir and dir.file_exists("save.cfg"):
        dir.remove("save.cfg")
    print("Wiped save.")
    quit()
