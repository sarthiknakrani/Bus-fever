extends SceneTree

func _init():
	var scene = ResourceLoader.load("res://scenes/level1.tscn")
	var instance = scene.instantiate()
	root.add_child(instance)
	print("Scene instantiated successfully.")
	quit()
