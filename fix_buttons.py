import os

files = ["scripts/main.gd", "scripts/gameplay/car_jam_level.gd"]

for filepath in files:
    with open(filepath, "r") as f:
        content = f.read()
    
    # We want to replace stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
    # with stretch_mode = TextureButton.STRETCH_SCALE
    # and add ignore_texture_size = true
    # and texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST (or LINEAR)
    
    content = content.replace("STRETCH_KEEP_CENTERED", "STRETCH_SCALE")
    
    # After custom_minimum_size, we inject the ignore_size
    lines = content.split('\n')
    new_lines = []
    for line in lines:
        new_lines.append(line)
        if "custom_minimum_size =" in line and "btn" in line:
            indent = line.split("btn")[0]
            btn_name = line.split(".custom_minimum_size")[0].strip().split(" ")[-1]
            if "btn" in btn_name or "btn" in line:
                # Some are named `play_btn`, some `btn_restart`
                btn_name = btn_name.replace("var ", "")
                new_lines.append(indent + btn_name + ".ignore_texture_size = true")
                new_lines.append(indent + btn_name + ".texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR")
    
    with open(filepath, "w") as f:
        f.write('\n'.join(new_lines))

print("Fixed buttons")
