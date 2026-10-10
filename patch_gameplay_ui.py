import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# PATCH RESTART
p_restart = re.compile(
    r'(var btn_restart := TextureButton\.new\(\)\s*)'
    r'btn_restart\.texture_normal = load\("res://assets/btn_restart\.png"\)\s*'
    r'btn_restart\.ignore_texture_size = true\s*'
    r'btn_restart\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED'
)
rep_restart = r'''\1btn_restart.texture_normal = load("res://assets/ui/gameplay_buttons/restart_normal.svg")
	btn_restart.texture_pressed = load("res://assets/ui/gameplay_buttons/restart_pressed.svg")
	btn_restart.ignore_texture_size = true
	btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED'''
content = p_restart.sub(rep_restart, content)

# PATCH PAUSE
p_pause = re.compile(
    r'(var btn_pause := TextureButton\.new\(\)\s*)'
    r'btn_pause\.texture_normal = load\("res://assets/btn_pause\.png"\)\s*'
    r'btn_pause\.ignore_texture_size = true\s*'
    r'btn_pause\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED'
)
rep_pause = r'''\1btn_pause.texture_normal = load("res://assets/ui/gameplay_buttons/pause_normal.svg")
	btn_pause.texture_pressed = load("res://assets/ui/gameplay_buttons/pause_pressed.svg")
	btn_pause.ignore_texture_size = true
	btn_pause.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED'''
content = p_pause.sub(rep_pause, content)

# PATCH BOOSTERS
p_boosters = re.compile(
    r'		var btn := TextureButton\.new\(\)\s*'
    r'		btn\.texture_normal = load\(b_info\["icon"\]\)\s*'
    r'		btn\.ignore_texture_size = true\s*'
    r'		btn\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED\s*'
    r'		btn\.set_anchors_preset\(Control\.PRESET_FULL_RECT\)'
)
rep_boosters = r'''		var btn := TextureButton.new()
		btn.texture_normal = load("res://assets/ui/gameplay_buttons/base_booster_normal.svg")
		btn.texture_pressed = load("res://assets/ui/gameplay_buttons/base_booster_pressed.svg")
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# Add the illustration PNG on top
		var icon_rect = TextureRect.new()
		icon_rect.texture = load(b_info["icon"])
		icon_rect.ignore_texture_size = true
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# slight padding inside the SVG base
		icon_rect.offset_left = 6
		icon_rect.offset_right = -6
		icon_rect.offset_top = 6
		icon_rect.offset_bottom = -12
		btn.add_child(icon_rect)'''
content = p_boosters.sub(rep_boosters, content)

# Remove the scale effect of the button and position:y tweens for texture-based pressed state if it's there
# Actually wait, in my previous session I added tweens to move them.
# The user wants "When tapped: 1. Button depresses slightly. 2. Glossy surface transitions to pressed state. 3. The button moves down a few visual pixels. 4. It returns smoothly on release."
# So I should leave the tween_property(btn, "position:y", ...) intact!
# But wait, my SVG also has the face moving down. If I tween position.y on the whole button, it might shift too much!
# I will change it to scale tweening instead of position.y to be consistent with the Home Screen, but the prompt says: "The button moves down a few visual pixels. It returns smoothly on release."
# I will just keep the existing tween!

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("car_jam_level.gd patched for gameplay buttons.")
