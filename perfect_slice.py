from PIL import Image
import collections

img_path = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c/.user_uploaded/media_1791444849730_9202030b.png"
img = Image.open(img_path).convert("RGBA")
pixels = img.load()
w, h = img.size

# We want to identify the exact background.
# Background is everything connected to the edges that has max(R,G,B) < 70
def is_bg(x, y):
    p = pixels[x, y]
    # Check max rgb
    return max(p[0], p[1], p[2]) < 70

bg_pixels = set()
q = collections.deque()

for x in range(w):
    q.append((x, 0))
    q.append((x, h-1))
for y in range(h):
    q.append((0, y))
    q.append((w-1, y))

# Add all edges
visited = set(q)

while q:
    x, y = q.popleft()
    if is_bg(x, y):
        bg_pixels.add((x, y))
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                visited.add((nx, ny))
                q.append((nx, ny))

# Dilation to catch antialiased borders
dilated_bg = set(bg_pixels)
for x, y in bg_pixels:
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h:
                # Only add if it's somewhat dark (don't eat into bright colors)
                p = pixels[nx, ny]
                if max(p[0], p[1], p[2]) < 100:
                    dilated_bg.add((nx, ny))

# Now clear the bg
for x in range(w):
    for y in range(h):
        if (x, y) in bg_pixels:
            pixels[x, y] = (0, 0, 0, 0)
        elif (x, y) in dilated_bg:
            # Soft edge
            p = pixels[x, y]
            m = max(p[0], p[1], p[2])
            # map 70->0, 100->255
            alpha = int(max(0, min(255, (m - 70) * 255 / 30)))
            pixels[x, y] = (p[0], p[1], p[2], alpha)

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
