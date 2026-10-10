import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# Replace the TextureButton creations in ResultOverlay
old_restart = r'''	var res_btn_restart := TextureButton\.new\(\)
	res_btn_restart\.texture_normal = load\("res://assets/btn_restart\.png"\)
	res_btn_restart\.ignore_texture_size = true
	res_btn_restart\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED
	res_btn_restart\.custom_minimum_size = Vector2\(200, 56\)
	res_btn_restart\.button_down\.connect\(func\(\):
		var tw = res_btn_restart\.create_tween\(\)
		tw\.tween_property\(res_btn_restart, "position:y", 4\.0, 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(res_btn_restart, "modulate", Color\(0\.85, 0\.85, 0\.85\), 0\.05\)
	\)
	res_btn_restart\.button_up\.connect\(func\(\):
		var tw = res_btn_restart\.create_tween\(\)
		tw\.tween_property\(res_btn_restart, "position:y", 0\.0, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(res_btn_restart, "modulate", Color\.WHITE, 0\.1\)
	\)'''

new_restart = r'''	var res_btn_restart := Button3D.new()
	res_btn_restart.setup_3d("res://assets/models/btn_180x56.obj", Color("22c55e"), "", "Restart", Vector2(180, 56), false, 12.0)'''
content = re.sub(old_restart, new_restart, content)

old_home = r'''	var res_btn_home := TextureButton\.new\(\)
	res_btn_home\.texture_normal = load\("res://assets/btn_home\.png"\)
	res_btn_home\.ignore_texture_size = true
	res_btn_home\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED
	res_btn_home\.custom_minimum_size = Vector2\(200, 56\)
	res_btn_home\.button_down\.connect\(func\(\):
		var tw = res_btn_home\.create_tween\(\)
		tw\.tween_property\(res_btn_home, "position:y", 4\.0, 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(res_btn_home, "modulate", Color\(0\.85, 0\.85, 0\.85\), 0\.05\)
	\)
	res_btn_home\.button_up\.connect\(func\(\):
		var tw = res_btn_home\.create_tween\(\)
		tw\.tween_property\(res_btn_home, "position:y", 0\.0, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(res_btn_home, "modulate", Color\.WHITE, 0\.1\)
	\)'''

new_home = r'''	var res_btn_home := Button3D.new()
	res_btn_home.setup_3d("res://assets/models/btn_180x56.obj", Color("f97316"), "", "Home", Vector2(180, 56), false, 12.0)'''
content = re.sub(old_home, new_home, content)

# Adjust the panel height from 360 to something more appropriate (like 200 or 220)
content = content.replace('res_panel.custom_minimum_size = Vector2(300, 360)', 'res_panel.custom_minimum_size = Vector2(280, 220)')
content = content.replace('res_vbox.add_theme_constant_override("separation", 20)', 'res_vbox.add_theme_constant_override("separation", 16)')

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("Patched ResultOverlay")
