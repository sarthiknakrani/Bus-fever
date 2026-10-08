import re
import os

files = ["scripts/main.gd", "scripts/gameplay/car_jam_level.gd"]

for filepath in files:
    with open(filepath, "r") as f:
        code = f.read()
    
    # We want to find all instances of StyleBoxFlat.new() and add a top border highlight
    # We can do this by looking for 'border_width_bottom' and inserting 'border_width_top' and 'border_color' for highlight
    
    lines = code.split("\n")
    out_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out_lines.append(line)
        if "border_width_bottom =" in line and "pb_pressed" not in line and "sb_pressed" not in line and "c_pressed" not in line and "bst_pressed" not in line:
            # Found a base style
            var_name = line.strip().split(".")[0]
            if var_name in ["pb_style", "sb_style", "close_style", "bst_style", "bg_style", "r_style", "rhb_style", "rrb_style", "ph_style", "pc_style", "phb_style", "prb_style", "p_style", "thumb_style"]:
                # Add top highlight!
                indent = line.split(var_name)[0]
                # Only add if we haven't already
                if i+1 < len(lines) and "border_width_top" not in lines[i+1]:
                    out_lines.append(f"{indent}{var_name}.border_width_top = 4")
                    out_lines.append(f"{indent}{var_name}.border_blend = true")
                    
                    # For the border_color, the highlight is usually semi-transparent white
                    # But the stylebox might only have one border_color. 
                    # If we set border_blend=true and border_width_top=4, the single border_color applies to both top and bottom!
                    # Wait, if border_color is dark blue (for the bottom shadow), then the top highlight will ALSO be dark blue!
                    # StyleBoxFlat only supports a single `border_color`.
        i += 1
