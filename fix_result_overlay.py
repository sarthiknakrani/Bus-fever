import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# r_panel container size
code = code.replace('r_panel.custom_minimum_size = Vector2(460, 320)', 'r_panel.custom_minimum_size = Vector2(300, 240)')

# margins
code = code.replace('r_margin.add_theme_constant_override("margin_left", 32)', 'r_margin.add_theme_constant_override("margin_left", 24)')
code = code.replace('r_margin.add_theme_constant_override("margin_right", 32)', 'r_margin.add_theme_constant_override("margin_right", 24)')
code = code.replace('r_margin.add_theme_constant_override("margin_top", 40)', 'r_margin.add_theme_constant_override("margin_top", 24)')
code = code.replace('r_margin.add_theme_constant_override("margin_bottom", 40)', 'r_margin.add_theme_constant_override("margin_bottom", 24)')

# r_vbox separation
code = code.replace('r_vbox.add_theme_constant_override("separation", 24)', 'r_vbox.add_theme_constant_override("separation", 16)')

# Title label
code = code.replace('result_title_label.add_theme_font_size_override("font_size", 42)', 'result_title_label.add_theme_font_size_override("font_size", 28)')

# Home button
code = code.replace('r_btn_home.add_theme_font_size_override("font_size", 36)', 'r_btn_home.add_theme_font_size_override("font_size", 24)')
code = code.replace('r_btn_home.custom_minimum_size = Vector2(260, 100)', 'r_btn_home.custom_minimum_size = Vector2(180, 56)')
code = code.replace('func(): r_btn_home.position.y += 6', 'func(): r_btn_home.position.y += 4')
code = code.replace('func(): r_btn_home.position.y -= 6', 'func(): r_btn_home.position.y -= 4')

# Result (Texture) button
code = code.replace('result_btn.custom_minimum_size = Vector2(296, 102)', 'result_btn.custom_minimum_size = Vector2(180, 62)')
code = code.replace('func(): result_btn.position.y += 8', 'func(): result_btn.position.y += 4')
code = code.replace('func(): result_btn.position.y -= 8', 'func(): result_btn.position.y -= 4')

# Center wrapper for result button
code = code.replace('r_restart_center.custom_minimum_size = Vector2(300, 110)', 'r_restart_center.custom_minimum_size = Vector2(200, 70)')

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Result overlay shrunk!")
