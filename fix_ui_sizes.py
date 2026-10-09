import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

# 1. Fix Logo Sizes
# "font_size = 130" -> 90
code = re.sub(r"bus_ls\.font_size\s*=\s*\d+", "bus_ls.font_size = 90", code)
code = re.sub(r"bus_ls\.outline_size\s*=\s*\d+", "bus_ls.outline_size = 20", code)
code = re.sub(r"bus_ls\.shadow_offset\s*=\s*Vector2\([^)]+\)", "bus_ls.shadow_offset = Vector2(0, 8)", code)

code = re.sub(r"fp_ls\.font_size\s*=\s*\d+", "fp_ls.font_size = 50", code)
code = re.sub(r"fp_ls\.outline_size\s*=\s*\d+", "fp_ls.outline_size = 12", code)
code = re.sub(r"fp_ls\.shadow_offset\s*=\s*Vector2\([^)]+\)", "fp_ls.shadow_offset = Vector2(0, 6)", code)

# 2. Fix Settings Button Size
# Make it 60x60 instead of 72x72
code = re.sub(r"settings_btn\.offset_left\s*=\s*[-]?\d+\.?\d*", "settings_btn.offset_left = -70.0", code)
code = re.sub(r"settings_btn\.offset_right\s*=\s*[-]?\d+\.?\d*", "settings_btn.offset_right = -16.0", code)
code = re.sub(r"settings_btn\.offset_top\s*=\s*[-]?\d+\.?\d*", "settings_btn.offset_top = 16.0", code)
code = re.sub(r"settings_btn\.offset_bottom\s*=\s*[-]?\d+\.?\d*", "settings_btn.offset_bottom = 70.0", code)

# Settings button corner radius (27 for a 54x54 button)
code = re.sub(r"sb_style\.set_corner_radius_all\(\d+\)", "sb_style.set_corner_radius_all(27)", code)
code = re.sub(r"sg_style\.corner_radius_top_left\s*=\s*\d+", "sg_style.corner_radius_top_left = 27", code)
code = re.sub(r"sg_style\.corner_radius_top_right\s*=\s*\d+", "sg_style.corner_radius_top_right = 27", code)

# Settings button font size
code = re.sub(r"ls_s\.font_size\s*=\s*\d+", "ls_s.font_size = 36", code)

# 3. Fix Play Button Size
# Make it 220x80 instead of 280x100
code = re.sub(r"play_shadow\.offset_left\s*=\s*[-]?\d+", "play_shadow.offset_left = -110", code)
code = re.sub(r"play_shadow\.offset_right\s*=\s*[-]?\d+", "play_shadow.offset_right = 110", code)
code = re.sub(r"play_shadow\.offset_top\s*=\s*[-]?\d+", "play_shadow.offset_top = -80", code)

# Play button corner radius (40)
code = re.sub(r"shadow_sb\.set_corner_radius_all\(\d+\)", "shadow_sb.set_corner_radius_all(40)", code)
code = re.sub(r"p_style\.set_corner_radius_all\(\d+\)", "p_style.set_corner_radius_all(40)", code)

# Play button font size
code = re.sub(r"ls_play\.font_size\s*=\s*\d+", "ls_play.font_size = 46", code)

with open("scripts/main.gd", "w") as f:
    f.write(code)
print("Updated UI Sizes")
