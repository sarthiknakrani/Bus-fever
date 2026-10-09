import re

# ==========================================
# 1. Fix Pause Overlay in car_jam_level.gd
# ==========================================
with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# p_main custom_minimum_size
code = re.sub(r"p_main\.custom_minimum_size\s*=\s*Vector2\(\d+,\s*\d+\)", "p_main.custom_minimum_size = Vector2(300, 480)", code)

# p_header custom_minimum_size
code = re.sub(r"p_header\.custom_minimum_size\s*=\s*Vector2\(\d+,\s*\d+\)", "p_header.custom_minimum_size = Vector2(300, 60)", code)

# SETTINGS font size
code = re.sub(r"ph_lbl\.add_theme_font_size_override\(\"font_size\",\s*36\)", "ph_lbl.add_theme_font_size_override(\"font_size\", 24)", code)

# Close button size and position
code = re.sub(r"p_close\.custom_minimum_size\s*=\s*Vector2\(\d+,\s*\d+\)", "p_close.custom_minimum_size = Vector2(44, 44)", code)
code = re.sub(r"p_close\.offset_left\s*=\s*-\d+\.0", "p_close.offset_left = -52.0", code)
code = re.sub(r"p_close\.offset_top\s*=\s*\d+\.0", "p_close.offset_top = -22.0", code)
code = re.sub(r"p_close\.add_theme_font_size_override\(\"font_size\",\s*28\)", "p_close.add_theme_font_size_override(\"font_size\", 20)", code)

# Settings icons box custom_minimum_size
code = re.sub(r"btn\.custom_minimum_size\s*=\s*Vector2\(96,\s*96\)", "btn.custom_minimum_size = Vector2(64, 64)", code)
code = re.sub(r"icon\.add_theme_font_size_override\(\"font_size\",\s*48\)", "icon.add_theme_font_size_override(\"font_size\", 32)", code)
# In car_jam_level.gd, there might be labels for the icons (e.g. Sound, Music).
code = re.sub(r"lbl\.add_theme_font_size_override\(\"font_size\",\s*24\)", "lbl.add_theme_font_size_override(\"font_size\", 16)", code)

# Action Buttons (Home, Restart)
code = re.sub(r"p_btn_home\.custom_minimum_size\s*=\s*Vector2\(\d+,\s*\d+\)", "p_btn_home.custom_minimum_size = Vector2(240, 60)", code)
code = re.sub(r"p_btn_restart\.custom_minimum_size\s*=\s*Vector2\(\d+,\s*\d+\)", "p_btn_restart.custom_minimum_size = Vector2(240, 60)", code)
code = re.sub(r"p_btn_home\.add_theme_font_size_override\(\"font_size\",\s*36\)", "p_btn_home.add_theme_font_size_override(\"font_size\", 26)", code)
code = re.sub(r"p_btn_restart\.add_theme_font_size_override\(\"font_size\",\s*36\)", "p_btn_restart.add_theme_font_size_override(\"font_size\", 26)", code)
code = re.sub(r"p_btn_home\.position\.y\s*\+=\s*6", "p_btn_home.position.y += 3", code)
code = re.sub(r"p_btn_home\.position\.y\s*-=\s*6", "p_btn_home.position.y -= 3", code)
code = re.sub(r"p_btn_restart\.position\.y\s*\+=\s*6", "p_btn_restart.position.y += 3", code)
code = re.sub(r"p_btn_restart\.position\.y\s*-=\s*6", "p_btn_restart.position.y -= 3", code)


with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)


# ==========================================
# 2. Fix Settings Overlay in main.gd
# ==========================================
with open("scripts/main.gd", "r") as f:
    code = f.read()

# wrapper size
code = re.sub(r"wrapper\.custom_minimum_size\s*=\s*Vector2\(400,\s*500\)", "wrapper.custom_minimum_size = Vector2(300, 380)", code)

# Title size
code = re.sub(r"title\.add_theme_font_size_override\(\"font_size\",\s*28\)", "title.add_theme_font_size_override(\"font_size\", 24)", code)
code = re.sub(r"title\.custom_minimum_size\s*=\s*Vector2\(0,\s*60\)", "title.custom_minimum_size = Vector2(0, 50)", code)

# Close button size and pos
code = re.sub(r"close_btn\.custom_minimum_size\s*=\s*Vector2\(48,\s*48\)", "close_btn.custom_minimum_size = Vector2(40, 40)", code)
code = re.sub(r"close_btn\.position\s*=\s*Vector2\(376,\s*-24\)", "close_btn.position = Vector2(280, -20)", code)
code = re.sub(r"close_btn\.add_theme_font_size_override\(\"font_size\",\s*24\)", "close_btn.add_theme_font_size_override(\"font_size\", 18)", code)

# Toggles (in _create_custom_toggle)
code = re.sub(r"toggle\.custom_minimum_size\s*=\s*Vector2\(80,\s*40\)", "toggle.custom_minimum_size = Vector2(60, 30)", code)
code = re.sub(r"icon\.add_theme_font_size_override\(\"font_size\",\s*20\)", "icon.add_theme_font_size_override(\"font_size\", 16)", code)
code = re.sub(r"lbl\.add_theme_font_size_override\(\"font_size\",\s*20\)", "lbl.add_theme_font_size_override(\"font_size\", 16)", code)

# For the knob inside toggle
# The knob is added to toggle: var knob = Panel.new(); knob.size = Vector2(32, 32); knob.position = Vector2(4, 4)
# Make knob smaller for 60x30: knob 24x24, pos 3, 3
code = re.sub(r"knob\.size\s*=\s*Vector2\(32,\s*32\)", "knob.size = Vector2(24, 24)", code)
code = re.sub(r"knob\.position\s*=\s*Vector2\(4,\s*4\)", "knob.position = Vector2(3, 3)", code)
# Toggle animation positions (4 to 44) -> (3 to 33)
code = re.sub(r"\"position:x\",\s*44\.0", "\"position:x\", 33.0", code)
code = re.sub(r"\"position:x\",\s*4\.0", "\"position:x\", 3.0", code)

with open("scripts/main.gd", "w") as f:
    f.write(code)

print("Fixed overlay sizes!")
