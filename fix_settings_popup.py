import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

pattern = r"var ps := StyleBoxFlat\.new\(\).*?_settings_panel\.add_child\(pop_gloss\)"

replacement = """var ps := StyleBoxFlat.new()
	ps.bg_color = Color("fcf8ef")
	ps.border_width_bottom = 6
	ps.border_color = Color("e0d2b8")
	ps.corner_radius_all = 32
	ps.shadow_color = Color(0,0,0,0.3)
	ps.shadow_size = 12
	ps.shadow_offset = Vector2(0, 8)
	_settings_panel.add_theme_stylebox_override("panel", ps)
	# REMOVED clip_children because it breaks the shadow and layout!
	wrapper.add_child(_settings_panel)
	
	# Add the gloss Panel OVER the settings panel as a sibling so it doesn't break PanelContainer layout
	var pop_gloss = Panel.new()
	pop_gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_gloss.anchor_bottom = 0.5
	pop_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pg_style = StyleBoxFlat.new()
	pg_style.bg_color = Color(1, 1, 1, 0.4)
	pg_style.corner_radius_top_left = 32
	pg_style.corner_radius_top_right = 32
	pop_gloss.add_theme_stylebox_override("panel", pg_style)
	wrapper.add_child(pop_gloss)"""

code = re.sub(pattern, replacement, code, flags=re.DOTALL)

# Fix toggles too! Toggles use clip_children which breaks the layout/shadow?
# Actually toggles don't have a shadow, they just have a corner radius.
# But just in case, I'll make sure toggles don't have shadow bugs. The toggles only had border_color.
# Wait, I didn't change the close button. Does the close button have clip_children? Yes.
# Close button has a shadow!
pattern_close = r"\tclose_btn\.clip_children = CanvasItem\.CLIP_CHILDREN_AND_DRAW\n\t\n\tvar c_style = StyleBoxFlat\.new\(\)\n\tc_style\.bg_color = Color\(\"ef4444\"\)\n\tc_style\.corner_radius_all = 24\n\tc_style\.shadow_color = Color\(0, 0, 0, 0\.3\)\n\tc_style\.shadow_size = 6\n\tc_style\.shadow_offset = Vector2\(0, 4\)\n\tclose_btn\.add_theme_stylebox_override\(\"normal\", c_style\)\n\t\n\tvar c_hover = c_style\.duplicate\(\)\n\tc_hover\.bg_color = Color\(\"f87171\"\)\n\tclose_btn\.add_theme_stylebox_override\(\"hover\", c_hover\)\n\t\n\tvar c_pressed = c_style\.duplicate\(\)\n\tc_pressed\.bg_color = Color\(\"dc2626\"\)\n\tclose_btn\.add_theme_stylebox_override\(\"pressed\", c_pressed\)\n\t\n\tvar cg = Panel\.new\(\)\n\tcg\.set_anchors_preset\(Control\.PRESET_TOP_WIDE\)\n\tcg\.anchor_bottom = 0\.5\n\tcg\.mouse_filter = Control\.MOUSE_FILTER_IGNORE\n\tvar cgs = StyleBoxFlat\.new\(\)\n\tcgs\.bg_color = Color\(1, 1, 1, 0\.3\)\n\tcg\.add_theme_stylebox_override\(\"panel\", cgs\)\n\tclose_btn\.add_child\(cg\)"

replacement_close = """	# NO clip_children to prevent shadow bug
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color("ef4444")
	c_style.corner_radius_all = 24
	c_style.shadow_color = Color(0, 0, 0, 0.3)
	c_style.shadow_size = 6
	c_style.shadow_offset = Vector2(0, 4)
	close_btn.add_theme_stylebox_override("normal", c_style)
	
	var c_hover = c_style.duplicate()
	c_hover.bg_color = Color("f87171")
	close_btn.add_theme_stylebox_override("hover", c_hover)
	
	var c_pressed = c_style.duplicate()
	c_pressed.bg_color = Color("dc2626")
	c_pressed.shadow_size = 0
	c_pressed.shadow_offset = Vector2(0,0)
	close_btn.add_theme_stylebox_override("pressed", c_pressed)
	
	var cg = Panel.new()
	cg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cg.anchor_bottom = 0.5
	cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cgs = StyleBoxFlat.new()
	cgs.bg_color = Color(1, 1, 1, 0.3)
	cgs.corner_radius_top_left = 24
	cgs.corner_radius_top_right = 24
	cg.add_theme_stylebox_override("panel", cgs)
	close_btn.add_child(cg)"""

code = re.sub(pattern_close, replacement_close, code, flags=re.DOTALL)

with open("scripts/main.gd", "w") as f:
    f.write(code)
print("Updated settings popup shadows and layout.")
