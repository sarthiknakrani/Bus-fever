extends SceneTree
func _init():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Actually generating a proper UV-mapped rounded box in code is 100+ lines.
	# A simpler 3D proxy: two capsules crossed, or standard mesh.
	quit()
