from PIL import Image, ImageFilter
import math

def color_dist(c1, c2):
    return math.sqrt((c1[0]-c2[0])**2 + (c1[1]-c2[1])**2 + (c1[2]-c2[2])**2)

def extract(in_path, out_path):
    img = Image.open(in_path).convert('RGBA')
    w, h = img.size
    pixels = img.load()
    
    # We want to remove the green plus badge (top right) and the text (bottom)
    # Plus badge is roughly x > w * 0.65, y < h * 0.4
    # Text is roughly y > h * 0.75
    
    # Pass 1: Remove badge and text by overwriting with edge background color
    for y in range(h):
        left_bg = pixels[5, y]
        for x in range(w):
            if x > w * 0.65 and y < h * 0.4:
                # Top right corner (badge area)
                pixels[x, y] = left_bg
            if y > h * 0.78:
                # Bottom text area
                pixels[x, y] = pixels[x, int(h * 0.75)]
                
    # Pass 2: Extract the foreground
    # We estimate background color for row y by interpolating left and right edges
    out_img = Image.new('RGBA', (w, h), (0,0,0,0))
    out_pixels = out_img.load()
    
    for y in range(h):
        c_left = pixels[5, y]
        c_right = pixels[w-6, y]
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 128:
                continue
                
            # interpolate bg
            t = x / float(w)
            bg_r = c_left[0] * (1-t) + c_right[0] * t
            bg_g = c_left[1] * (1-t) + c_right[1] * t
            bg_b = c_left[2] * (1-t) + c_right[2] * t
            
            dist = color_dist((r,g,b), (bg_r, bg_g, bg_b))
            
            # If distance is high, it's the foreground
            # We use a soft transition
            threshold = 30
            if dist > threshold:
                alpha = min(255, int((dist - threshold) * 8))
                out_pixels[x, y] = (r, g, b, alpha)
                
    # Crop the image to the actual content
    bbox = out_img.getbbox()
    if bbox:
        out_img = out_img.crop(bbox)
        
    out_img.save(out_path)
    print(f"Extracted {in_path} to {out_path} (bbox: {bbox})")

extract("assets/btn_vip.png", "assets/ui/gameplay_buttons/icon_vip.png")
extract("assets/btn_arrange.png", "assets/ui/gameplay_buttons/icon_arrange.png")
extract("assets/btn_jumble.png", "assets/ui/gameplay_buttons/icon_jumble.png")
