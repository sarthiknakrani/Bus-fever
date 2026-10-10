extends SceneTree
func _init():
	var lbl = Label3D.new()
	print(lbl.pixel_size)
	var spr = Sprite3D.new()
	print(spr.pixel_size)
	quit()
