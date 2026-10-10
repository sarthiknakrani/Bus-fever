import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# We need to find where the action buttons are added to r_vbox in the result_overlay.
# It is around:
# 	# Action Buttons (Home and Restart)
# 	var r_btn_home := Button.new()
#	r_btn_home.text = "Home"

replacement = """	# Action Buttons
	var gc = get_tree().root.get_node_or_null("GameController")
	var is_level_1 = (gc != null and gc.current_level_number == 1)
	if is_level_1:
		var r_btn_next := Button.new()
		r_btn_next.text = "NEXT LEVEL ➔"
		r_btn_next.add_theme_font_size_override("font_size", 24)
		r_btn_next.add_theme_color_override("font_color", Color.WHITE)
		r_btn_next.add_theme_stylebox_override("normal", SimpleStyle.make_extruded_style(
			Color("22c55e"), Color("15803d"), 16, 7, 0))
		r_btn_next.add_theme_stylebox_override("hover", SimpleStyle.make_extruded_style(
			Color("4ade80"), Color("15803d"), 16, 7, 0))
		r_btn_next.add_theme_stylebox_override("pressed", SimpleStyle.make_extruded_style(
			Color("16a34a"), Color("14532d"), 16, 0, 7))
		r_btn_next.custom_minimum_size = Vector2(240, 60)
		r_btn_next.pressed.connect(func():
			_play_sfx("ui")
			if gc: gc.next_level()
		)
		r_vbox.add_child(r_btn_next)

	var r_btn_home := Button.new()
	r_btn_home.text = "Home"
"""

content = content.replace('	# Action Buttons (Home and Restart)\n	var r_btn_home := Button.new()\n	r_btn_home.text = "Home"\n', replacement)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("Next level button patched")
