import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

pattern = r'\s*# D\. Bottom-center Play button \(Glossy Blue 3D SVG\).*?hud\.add_child\(play_btn\)'
match = re.search(pattern, content, re.MULTILINE | re.DOTALL)

if not match:
    print("Could not find Play button section in main.gd")
    exit(1)

new_play_btn = """	# D. Bottom-center Play button (Glossy Blue 3D SVG)
	var play_btn := TextureButton.new()
	play_btn.texture_normal = load("res://assets/ui/buttons/play_normal.svg")
	play_btn.texture_pressed = load("res://assets/ui/buttons/play_pressed.svg")
	play_btn.ignore_texture_size = true
	play_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	play_btn.anchor_left = 0.5
	play_btn.anchor_right = 0.5
	play_btn.anchor_top = 0.85
	play_btn.anchor_bottom = 0.85
	play_btn.offset_left = -160.0
	play_btn.offset_right = 160.0
	play_btn.offset_top = -80.0
	play_btn.offset_bottom = 0.0
	play_btn.pivot_offset = Vector2(160, 40)
	play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	play_btn.button_down.connect(func():
		var tw = play_btn.create_tween()
		tw.set_parallel(true)
		# The SVG itself handles the 3D button face depression. 
		# We add a subtle physical scale down of the entire node for extra tactile feel.
		tw.tween_property(play_btn, "scale", Vector2(0.96, 0.96), 0.05).set_trans(Tween.TRANS_QUAD)
		# A tiny real downward nudge of the whole node
		tw.tween_property(play_btn, "position:y", play_btn.position.y + 2.0, 0.05).set_trans(Tween.TRANS_QUAD)
	)
	
	play_btn.button_up.connect(func():
		var tw = play_btn.create_tween()
		tw.set_parallel(true)
		tw.tween_property(play_btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
		# Restore original position based on anchors/offsets rather than hardcoded Y
		tw.tween_property(play_btn, "position:y", play_btn.position.y - 2.0, 0.1).set_trans(Tween.TRANS_QUAD)
	)
	
	play_btn.pressed.connect(func():
		# Prevent double click bugs
		if play_btn.disabled: return
		play_btn.disabled = true
		_on_play_pressed()
	)
	hud.add_child(play_btn)"""

content = content[:match.start()] + "\n" + new_play_btn + content[match.end():]

with open("scripts/main.gd", "w") as f:
    f.write(content)
print("main.gd patched properly")
