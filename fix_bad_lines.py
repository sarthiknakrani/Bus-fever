import re

files = ["scripts/gameplay/car_jam_level.gd", "scripts/main.gd"]

for filepath in files:
    with open(filepath, "r") as f:
        content = f.read()
    
    # We replace any line containing `ignore_texture_size = true` that has an `=` before it.
    new_lines = []
    for line in content.split("\n"):
        if ".ignore_texture_size = true" in line and "=" in line.split(".ignore_texture_size")[0]:
            continue
        if ".texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR" in line and "=" in line.split(".texture_filter")[0]:
            continue
        new_lines.append(line)
        
    with open(filepath, "w") as f:
        f.write('\n'.join(new_lines))

print("Cleaned up bad lines")
