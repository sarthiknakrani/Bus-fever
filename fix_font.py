import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

# Fix logo sizes: 110 -> 80, 62 -> 42
code = re.sub(r"ls_shadow\.font_size\s*=\s*\d+", "ls_shadow.font_size = 80", code)
code = re.sub(r"ls_front\.font_size\s*=\s*\d+", "ls_front.font_size = 80", code)
code = re.sub(r"ls_shadow\.outline_size\s*=\s*\d+", "ls_shadow.outline_size = 20", code)
code = re.sub(r"ls_front\.outline_size\s*=\s*\d+", "ls_front.outline_size = 16", code)

code = re.sub(r"ls_fps\.font_size\s*=\s*\d+", "ls_fps.font_size = 42", code)
code = re.sub(r"ls_fpf\.font_size\s*=\s*\d+", "ls_fpf.font_size = 42", code)
code = re.sub(r"ls_fps\.outline_size\s*=\s*\d+", "ls_fps.outline_size = 12", code)
code = re.sub(r"ls_fpf\.outline_size\s*=\s*\d+", "ls_fpf.outline_size = 8", code)

# Fix play button width to be responsive or just smaller width
# Make sure play_shadow is small enough
code = re.sub(r"play_shadow\.offset_left\s*=\s*[-]?\d+", "play_shadow.offset_left = -110", code)
code = re.sub(r"play_shadow\.offset_right\s*=\s*[-]?\d+", "play_shadow.offset_right = 110", code)

with open("scripts/main.gd", "w") as f:
    f.write(code)
print("Fixed fonts")
