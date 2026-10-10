from PIL import Image
import math

def color_dist(c1, c2):
    return math.sqrt((c1[0]-c2[0])**2 + (c1[1]-c2[1])**2 + (c1[2]-c2[2])**2)

def strip(in_path, out_path):
    print(f"Processing {in_path}...")
    img = Image.open(in_path).convert('RGBA')
    w, h = img.size
    pixels = img.load()
    
    # We assume the border/background has a distinct blue or green color.
    # Let's sample a few points near the edge (but not transparent) to find the bg color
    bg_color = None
    for y in range(h//2, h//2+10):
        for x in range(w):
            if pixels[x, y][3] > 200:
                bg_color = pixels[x, y]
                break
        if bg_color: break
        
    print(f"Detected bg color: {bg_color}")
    
    # Also sample bottom edge for the shadow color
    shadow_color = None
    for y in range(h-1, -1, -1):
        for x in range(w//2, w//2+10):
            if pixels[x, y][3] > 200:
                shadow_color = pixels[x, y]
                break
        if shadow_color: break
        
    print(f"Detected shadow color: {shadow_color}")
    
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a > 0:
                d1 = color_dist((r,g,b), bg_color[:3]) if bg_color else 999
                d2 = color_dist((r,g,b), shadow_color[:3]) if shadow_color else 999
                
                # If it's very close to the bg or shadow, make it transparent
                # (We use a generous threshold because the button is a gradient)
                if d1 < 60 or d2 < 60:
                    pixels[x, y] = (r, g, b, 0)
                else:
                    # Keep it opaque
                    pixels[x, y] = (r, g, b, 255)
                    
    img.save(out_path)

strip("assets/btn_vip.png", "assets/ui/gameplay_buttons/icon_vip.png")
strip("assets/btn_arrange.png", "assets/ui/gameplay_buttons/icon_arrange.png")
strip("assets/btn_jumble.png", "assets/ui/gameplay_buttons/icon_jumble.png")
