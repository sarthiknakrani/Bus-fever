
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	print("Checking current setup:")
	print("Circulating rows count: ", node._circulating_rows.size())
	print("Feeder rows count: ", node._feeder_rows.size())
	quit()
