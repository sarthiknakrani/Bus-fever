from PIL import Image
import collections

img_path = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c/.user_uploaded/media_1791444849730_9202030b.png"
img = Image.open(img_path).convert("RGBA")
pixels = img.load()
w, h = img.size

# Flood fill from all edges to find background
def is_bg(p):
    # Dark colors are background
    return p[0] < 50 and p[1] < 50 and p[2] < 50

bg_pixels = set()
q = collections.deque()

for x in range(w):
    q.append((x, 0))
    q.append((x, h-1))
for y in range(h):
    q.append((0, y))
    q.append((w-1, y))

visited = set(q)

while q:
    x, y = q.popleft()
    if is_bg(pixels[x, y]):
        bg_pixels.add((x, y))
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                visited.add((nx, ny))
                q.append((nx, ny))

# Soften the edges (1 pixel dilation for alpha blending if needed)
for x in range(w):
    for y in range(h):
        if (x, y) in bg_pixels:
            pixels[x, y] = (0, 0, 0, 0)
        else:
            # Let's check distance to bg for smooth alpha
            # If it's very dark and NOT bg, it might be a shadow inside the object
            pass

w_third = w // 3

def save_part(x0, x1, name):
    crop = img.crop((x0, 0, x1, h))
    bb = crop.getbbox()
    if bb:
        crop = crop.crop(bb)
    crop.save(f"assets/{name}.png")
    print(f"Saved {name}.png")

save_part(0, w_third, "icon_ball_clean")
save_part(w_third, w_third*2, "icon_car_clean")
save_part(w_third*2, w, "icon_bus_clean")
