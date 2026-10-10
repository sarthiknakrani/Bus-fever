import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

# 1. Fix Settings Button position
code = code.replace('settings_btn.offset_top = 16.0', 'settings_btn.offset_top = -4.0')
code = code.replace('settings_btn.offset_bottom = 70.0', 'settings_btn.offset_bottom = 50.0')
code = code.replace('settings_btn.offset_left = -70.0', 'settings_btn.offset_left = -60.0') # push a little right
code = code.replace('settings_btn.offset_right = -16.0', 'settings_btn.offset_right = -6.0')

# 2. Fix Logo separation and boxes
code = code.replace('logo_container.add_theme_constant_override("separation", 0)', 'logo_container.add_theme_constant_override("separation", -10)')
code = code.replace('bus_box.custom_minimum_size = Vector2(0, 130)', 'bus_box.custom_minimum_size = Vector2(0, 85)')
code = code.replace('fever_box.custom_minimum_size = Vector2(0, 90)', 'fever_box.custom_minimum_size = Vector2(0, 50)')
code = code.replace('logo_container.anchor_top = 0.08', 'logo_container.anchor_top = 0.12') # push slightly down to center

# 3. Increase 3D extrusion on BUS
code = code.replace('bus_shadow.position.y += 12', 'bus_shadow.position.y += 16')
code = code.replace('ls_shadow.shadow_offset = Vector2(0, 16)', 'ls_shadow.shadow_offset = Vector2(0, 20)')

# 4. Make FEVER PARTY same color and 3D
code = code.replace('Color("0284c7")', 'Color("b45309")') # Replace dark blue with dark orange
code = code.replace('Color("38bdf8")', 'Color("f59e0b")') # Replace light blue with yellow/gold
code = code.replace('ls_fpf.outline_color = Color("0284c7")', 'ls_fpf.outline_color = Color.WHITE')
code = code.replace('fp_shadow.position.y += 8', 'fp_shadow.position.y += 12')
code = code.replace('ls_fps.shadow_offset = Vector2(0, 10)', 'ls_fps.shadow_offset = Vector2(0, 14)')
code = code.replace('ls_fpf.outline_size = 8', 'ls_fpf.outline_size = 12')
code = code.replace('ls_fps.outline_size = 12', 'ls_fps.outline_size = 16')


with open("scripts/main.gd", "w") as f:
    f.write(code)

print("Home UI Patched!")
