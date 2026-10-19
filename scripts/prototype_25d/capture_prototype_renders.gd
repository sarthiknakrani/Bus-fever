extends SceneTree

const ProtoScene = preload("res://scenes/prototype_25d/prototype_world_3d.tscn")
const ARTIFACT_DIR = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c"

func _init() -> void:
	_capture_renders()

func _capture_renders() -> void:
	var proto = ProtoScene.instantiate()
	root.add_child(proto)
	
	# Wait for rendering pipeline to initialize
	for f in 10:
		await process_frame
	
	var configs = [
		{"name": "prototype_3d_25deg.png", "tilt": 25.0, "ortho": true},
		{"name": "prototype_3d_30deg.png", "tilt": 30.0, "ortho": true},
		{"name": "prototype_3d_perspective.png", "tilt": 28.0, "ortho": false}
	]
	
	for cfg in configs:
		proto.set_camera_angle(cfg["tilt"], cfg["ortho"])
		for f in 10:
			await process_frame
			
		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/%s" % [ARTIFACT_DIR, cfg["name"]]
		var err = img.save_png(out_path)
		if err == OK:
			print("[3D PROTOTYPE] Saved render: %s (tilt=%.1f, ortho=%s)" % [out_path, cfg["tilt"], str(cfg["ortho"])])
		else:
			printerr("[3D PROTOTYPE] Failed to save %s (err %d)" % [out_path, err])
			
	quit(0)
