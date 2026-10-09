import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# p_main container size
code = code.replace("p_main.custom_minimum_size = Vector2(300, 480)", "p_main.custom_minimum_size = Vector2(225, 360)")

# p_header size and label
code = code.replace("p_header.custom_minimum_size = Vector2(300, 60)", "p_header.custom_minimum_size = Vector2(225, 45)")
code = code.replace('ph_lbl.add_theme_font_size_override("font_size", 16)', 'ph_lbl.add_theme_font_size_override("font_size", 12)')

# p_close button
code = code.replace("p_close.custom_minimum_size = Vector2(44, 44)", "p_close.custom_minimum_size = Vector2(33, 33)")
code = code.replace("p_close.offset_left = -52.0", "p_close.offset_left = -39.0")
code = code.replace("p_close.offset_top = 8.0", "p_close.offset_top = 6.0")

# margins in pb_margin
code = code.replace('pb_margin.add_theme_constant_override("margin_left", 32)', 'pb_margin.add_theme_constant_override("margin_left", 24)')
code = code.replace('pb_margin.add_theme_constant_override("margin_right", 32)', 'pb_margin.add_theme_constant_override("margin_right", 24)')
code = code.replace('pb_margin.add_theme_constant_override("margin_top", 32)', 'pb_margin.add_theme_constant_override("margin_top", 24)')
code = code.replace('pb_margin.add_theme_constant_override("margin_bottom", 24)', 'pb_margin.add_theme_constant_override("margin_bottom", 18)')

# separation in pb_vbox and p_icons
code = code.replace('pb_vbox.add_theme_constant_override("separation", 24)', 'pb_vbox.add_theme_constant_override("separation", 18)')
code = code.replace('p_icons.add_theme_constant_override("separation", 24)', 'p_icons.add_theme_constant_override("separation", 18)')

# Home and Restart action buttons in PauseOverlay
code = code.replace('p_btn_home.custom_minimum_size = Vector2(240, 60)', 'p_btn_home.custom_minimum_size = Vector2(180, 45)')
code = code.replace('p_btn_home.add_theme_font_size_override("font_size", 26)', 'p_btn_home.add_theme_font_size_override("font_size", 20)')
code = code.replace('p_btn_restart.custom_minimum_size = Vector2(240, 60)', 'p_btn_restart.custom_minimum_size = Vector2(180, 45)')
code = code.replace('p_btn_restart.add_theme_font_size_override("font_size", 26)', 'p_btn_restart.add_theme_font_size_override("font_size", 20)')

# Footer terms
code = code.replace('p_footer.add_theme_font_size_override("font_size", 18)', 'p_footer.add_theme_font_size_override("font_size", 13)')

# Inside _create_settings_icon_button (Top-level scope find/replace)
code = code.replace('btn.custom_minimum_size = Vector2(64, 64)', 'btn.custom_minimum_size = Vector2(48, 48)')
code = code.replace('style.border_width_bottom = 6', 'style.border_width_bottom = 4')
code = code.replace('icon.add_theme_font_size_override("font_size", 32)', 'icon.add_theme_font_size_override("font_size", 24)')

# slash for disabled states
code = code.replace('slash.size = Vector2(100, 8)', 'slash.size = Vector2(75, 6)')
code = code.replace('slash.pivot_offset = Vector2(50, 4)', 'slash.pivot_offset = Vector2(37, 3)')
code = code.replace('slash.position = Vector2(-2, 44)', 'slash.position = Vector2(-2, 33)')

# Labels below icon buttons
code = code.replace('lbl.add_theme_font_size_override("font_size", 22)', 'lbl.add_theme_font_size_override("font_size", 16)')

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Pause overlay shrunk to 75%!")
