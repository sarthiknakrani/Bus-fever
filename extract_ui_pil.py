from PIL import Image, ImageDraw
import os

img_path = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c/.user_uploaded/media_1791443621518_e7d34d45.jpg"
out_dir = "assets/ui"
os.makedirs(out_dir, exist_ok=True)

img = Image.open(img_path).convert("RGBA")
pixels = img.load()
width, height = img.size

# Threshold to find non-black regions
# Black background is around (10,10,10)
visited = set()

def flood_fill(start_x, start_y):
    queue = [(start_x, start_y)]
    region_pixels = []
    min_x, max_x = start_x, start_x
    min_y, max_y = start_y, start_y
    
    while queue:
        x, y = queue.pop(0)
        if (x, y) in visited:
            continue
        visited.add((x, y))
        
        r, g, b, a = pixels[x, y]
        if r < 20 and g < 20 and b < 20: # background
            continue
            
        region_pixels.append((x, y))
        min_x = min(min_x, x)
        max_x = max(max_x, x)
        min_y = min(min_y, y)
        max_y = max(max_y, y)
        
        # neighbors
        for nx, ny in [(x+1, y), (x-1, y), (x, y+1), (x, y-1)]:
            if 0 <= nx < width and 0 <= ny < height:
                if (nx, ny) not in visited:
                    queue.append((nx, ny))
                    
    return region_pixels, min_x, max_x, min_y, max_y

count = 0
for y in range(height):
    for x in range(width):
        if (x, y) not in visited:
            r, g, b, a = pixels[x, y]
            if r >= 20 or g >= 20 or b >= 20:
                region, mx, Mx, my, My = flood_fill(x, y)
                w = Mx - mx + 1
                h = My - my + 1
                if w > 30 and h > 30:
                    # Create new transparent image
                    new_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                    new_pixels = new_img.load()
                    for px, py in region:
                        new_pixels[px - mx, py - my] = pixels[px, py]
                        
                    out_path = os.path.join(out_dir, f"element_{count}.png")
                    new_img.save(out_path)
                    print(f"Saved {out_path} (w={w}, h={h})")
                    count += 1
