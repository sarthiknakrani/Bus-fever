extends SceneTree

var resolutions := [
	{"name": "390x844", "size": Vector2i(390, 844)},
	{"name": "720x1280", "size": Vector2i(720, 1280)},
	{"name": "810x1746", "size": Vector2i(810, 1746)}
]
var res_idx := 0

func _init():
	_run_next()

func _run_next():
	if res_idx >= resolutions.size():
		print("[CAPTURE] All resolutions captured successfully!")
		quit()
		return
	
	var r = resolutions[res_idx]
	print("[CAPTURE] Running resolution: ", r["name"])
	DisplayServer.window_set_size(r["size"])
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	change_scene_to_packed(scene)
	call_deferred("_snap_current", r["name"])

func _snap_current(res_name: String):
	# Wait for layout and visuals to initialize
	await create_timer(1.2).timeout
	var img = get_root().get_texture().get_image()
	if img != null:
		var path = "capture_%s.png" % res_name
		img.save_png(path)
		print("[CAPTURE] Saved ", path)
	
	res_idx += 1
	_run_next()
