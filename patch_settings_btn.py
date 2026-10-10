import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

pattern = r'\s*# C\. Top-right Settings button.*?hud\.add_child\(settings_btn\)'
match = re.search(pattern, content, re.MULTILINE | re.DOTALL)

if not match:
    print("Could not find Settings button section in main.gd")
    exit(1)

new_settings_btn = """	# C. Top-right Settings button (Glossy Blue SVG)
	var settings_btn := TextureButton.new()
	settings_btn.texture_normal = load("res://assets/ui/buttons/settings_gear_normal.svg")
	settings_btn.texture_pressed = load("res://assets/ui/buttons/settings_gear_pressed.svg")
	settings_btn.ignore_texture_size = true
	settings_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.anchor_top = 0.0
	settings_btn.anchor_bottom = 0.0
	settings_btn.offset_left = -64.0
	settings_btn.offset_right = 0.0
	settings_btn.offset_top = 0.0
	settings_btn.offset_bottom = 64.0
	settings_btn.pivot_offset = Vector2(32, 32)
	settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	settings_btn.button_down.connect(func():
		var tw = settings_btn.create_tween()
		tw.tween_property(settings_btn, "scale", Vector2(0.92, 0.92), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	
	settings_btn.button_up.connect(func():
		var tw = settings_btn.create_tween()
		tw.tween_property(settings_btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
	)
	
	settings_btn.pressed.connect(_on_settings_pressed)
	hud.add_child(settings_btn)"""

content = content[:match.start()] + "\n" + new_settings_btn + content[match.end():]

with open("scripts/main.gd", "w") as f:
    f.write(content)
print("main.gd patched for Settings button")
