import sys
from PIL import Image

def grid_color(filename):
    print(f"--- {filename} ---")
    img = Image.open(filename).convert('RGBA')
    w, h = img.size
    grid_w, grid_h = 10, 10
    step_x = w // grid_w
    step_y = h // grid_h
    
    for gy in range(grid_h):
        row = ""
        for gx in range(grid_w):
            x = min(gx * step_x + step_x // 2, w - 1)
            y = min(gy * step_y + step_y // 2, h - 1)
            r, g, b, a = img.getpixel((x, y))
            
            if a < 128: row += " . "
            else:
                if r > 150 and g < 100 and b < 100: row += " R " # Red/Orange
                elif g > 150 and r < 100 and b < 100: row += " G " # Green
                elif b > 150 and r < 100 and g < 100: row += " B " # Blue
                elif r > 150 and g > 150 and b < 100: row += " Y " # Yellow
                elif r > 150 and g > 150 and b > 150: row += " W " # White
                elif r < 100 and g < 100 and b < 100: row += " D " # Dark
                else: row += " # " # Mixed/Bg
        print(row)

for f in sys.argv[1:]:
    grid_color(f)
