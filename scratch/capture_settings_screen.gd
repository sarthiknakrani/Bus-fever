extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(390, 844)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	
	var scn = load("res://scenes/main.tscn")
	var main = scn.instantiate()
	vp.add_child(main)
	
	await create_timer(0.2).timeout
	
	var s_btn: TextureButton = main.get_node("HomeRoot/HUD/settings_btn")
	s_btn.emit_signal("pressed")
	
	await create_timer(0.3).timeout
	
	var img = vp.get_texture().get_image()
	if img != null:
		img.save_png("scratch/settings_dialog_rendered.png")
		print("[SUCCESS] Saved scratch/settings_dialog_rendered.png")
	else:
		print("[ERROR] SubViewport image is null")
	
	quit()
