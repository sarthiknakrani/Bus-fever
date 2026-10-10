import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# Replace restart button
old_restart = r'''	# Restart \(Premium TextureButton\)
	var btn_restart := TextureButton\.new\(\)
	btn_restart\.texture_normal = load\("res://assets/ui/gameplay_buttons/restart_normal\.svg"\)
	btn_restart\.texture_pressed = load\("res://assets/ui/gameplay_buttons/restart_pressed\.svg"\)
	btn_restart\.ignore_texture_size = true
	btn_restart\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED
	btn_restart\.custom_minimum_size = Vector2\(50, 50\)
	btn_restart\.button_down\.connect\(func\(\):
		var tw = btn_restart\.create_tween\(\)
		tw\.tween_property\(btn_restart, "position:y", 4\.0, 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(btn_restart, "modulate", Color\(0\.85, 0\.85, 0\.85\), 0\.05\)
	\)
	btn_restart\.button_up\.connect\(func\(\):
		var tw = btn_restart\.create_tween\(\)
		tw\.tween_property\(btn_restart, "position:y", 0\.0, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(btn_restart, "modulate", Color\.WHITE, 0\.1\)
	\)'''

new_restart = r'''	# Restart (Premium Button3D)
	var btn_restart := Button3D.new()
	btn_restart.setup_3d("res://assets/models/btn_50x50.obj", Color("3b82f6"), "res://assets/ui/gameplay_buttons/icon_restart.svg", "", Vector2(50, 50), false, 8.0)'''

content = re.sub(old_restart, new_restart, content)

# Replace pause button icon
old_pause = r'''	var btn_pause := Button3D\.new\(\)
	btn_pause\.setup_3d\("res://assets/models/btn_50x50\.obj", Color\("3b82f6"\), "res://assets/ui/gameplay_buttons/pause_normal\.svg", "", Vector2\(50, 50\), false, 8\.0\)'''

new_pause = r'''	var btn_pause := Button3D.new()
	btn_pause.setup_3d("res://assets/models/btn_50x50.obj", Color("3b82f6"), "res://assets/ui/gameplay_buttons/icon_pause.svg", "", Vector2(50, 50), false, 8.0)'''

content = re.sub(old_pause, new_pause, content)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("Fixed topbar buttons")
