from PIL import Image

def analyze_crop(filename):
    img = Image.open(filename).convert('RGBA')
    w, h = img.size
    print(f"--- {filename} ({w}x{h}) ---")
    
    # Let's find the bounding box of non-transparent pixels
    min_x, max_x, min_y, max_y = w, 0, h, 0
    pixels = img.load()
    for y in range(h):
        for x in range(w):
            if pixels[x, y][3] > 128:
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)
    print(f"Content bbox: X({min_x}-{max_x}), Y({min_y}-{max_y})")

analyze_crop("assets/btn_vip.png")
analyze_crop("assets/btn_arrange.png")
analyze_crop("assets/btn_jumble.png")
