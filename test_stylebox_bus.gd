extends SceneTree

func _init():
	var root = Control.new()
	root.name = "BusRoot"
	
	# Base 
	var w = 70.0
	var h = 70.0 # Small bus
	
	var shadow_y = 12.0
	
	# 3D Depth Layer (Lower)
	var depth_panel = Panel.new()
	var sb_depth = StyleBoxFlat.new()
	sb_depth.bg_color = Color("1e3a8a") # Dark blue
	sb_depth.corner_radius_top_left = 16
	sb_depth.corner_radius_top_right = 16
	sb_depth.corner_radius_bottom_left = 16
	sb_depth.corner_radius_bottom_right = 16
	sb_depth.shadow_color = Color(0,0,0,0.5)
	sb_depth.shadow_size = 6
	sb_depth.shadow_offset = Vector2(0, 4)
	depth_panel.add_theme_stylebox_override("panel", sb_depth)
	depth_panel.size = Vector2(w, h)
	depth_panel.position = Vector2(-w/2, -h/2 + shadow_y)
	root.add_child(depth_panel)
	
	# Top Layer
	var top_panel = Panel.new()
	var sb_top = StyleBoxFlat.new()
	sb_top.bg_color = Color("3b82f6") # Bright blue
	sb_top.corner_radius_top_left = 14
	sb_top.corner_radius_top_right = 14
	sb_top.corner_radius_bottom_left = 18
	sb_top.corner_radius_bottom_right = 18
	# Highlight / Bevel
	sb_top.border_width_top = 3
	sb_top.border_color = Color(1,1,1,0.4)
	sb_top.border_blend = true
	top_panel.add_theme_stylebox_override("panel", sb_top)
	top_panel.size = Vector2(w, h)
	top_panel.position = Vector2(-w/2, -h/2)
	root.add_child(top_panel)
	
	# Window
	var win_panel = Panel.new()
	var sb_win = StyleBoxFlat.new()
	sb_win.bg_color = Color("0f172a") # Dark glass
	sb_win.corner_radius_top_left = 6
	sb_win.corner_radius_top_right = 6
	sb_win.corner_radius_bottom_left = 2
	sb_win.corner_radius_bottom_right = 2
	win_panel.add_theme_stylebox_override("panel", sb_win)
	win_panel.size = Vector2(w - 12, h * 0.25)
	win_panel.position = Vector2(-w/2 + 6, -h/2 + 6)
	root.add_child(win_panel)
	
	# Arrow
	# (Use _draw for arrow)
	
	var pack = PackedScene.new()
	pack.pack(root)
	ResourceSaver.save(pack, "res://test_bus_style.tscn")
	quit()
