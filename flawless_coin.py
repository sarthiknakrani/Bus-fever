from PIL import Image
import collections

img = Image.open("assets/coin_counter_full.png").convert("RGBA")
w, h = img.size
pixels = img.load()

# The text "Coin counter" is at the bottom (y > 110 or so).
# Let's first just wipe the bottom completely.
for x in range(w):
    for y in range(120, h):
        pixels[x, y] = (0, 0, 0, 0)

# The white pill extends to the right. Let's find a pixel on the far right that is part of the pill.
# We'll flood fill from (w-10, h//2 - 20)
start_x = w - 10
start_y = 50

# We consider a pixel part of the pill if it is light colored
def is_pill(x, y):
    p = pixels[x, y]
    if p[3] < 50: return False
    # The pill is white/light-blue. Even the shadow is light gray.
    # The coin is yellow/gold (high R/G, low B). The plus is green (high G, low R/B).
    # So if it's gray/white/blue (B is high, or R/G/B are similar), it's the pill.
    # Let's say if B > 200, it's pill. Or if it's very bright (R>200, G>200, B>200)
    # The green plus has low B. The gold coin has low B.
    # The white plus INSIDE the green circle has high R/G/B, but it's surrounded by green.
    if p[2] > 180: # High blue means white/gray/blue
        return True
    if p[0] > 180 and p[1] > 180 and p[2] > 180:
        return True
    return False

q = collections.deque()
visited = set()

# Find a starting point on the right edge that is pill
for y in range(20, 100):
    if is_pill(w-10, y):
        q.append((w-10, y))
        visited.add((w-10, y))
        break
        
if not q:
    # Just add right edge
    for y in range(h):
        q.append((w-5, y))
        visited.add((w-5, y))

bg_pixels = set()

while q:
    x, y = q.popleft()
    if is_pill(x, y) or pixels[x, y][3] < 50:
        bg_pixels.add((x, y))
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                visited.add((nx, ny))
                q.append((nx, ny))

# Soften/Dilate to catch anti-aliasing edges of the pill touching the coin
dilated = set(bg_pixels)
for x, y in bg_pixels:
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h:
                p = pixels[nx, ny]
                # If it's a light pixel, eat it
                if p[2] > 150 or (p[0]>150 and p[1]>150 and p[2]>150):
                    dilated.add((nx, ny))

for x in range(w):
    for y in range(h):
        if (x, y) in dilated or (x, y) in bg_pixels:
            pixels[x, y] = (0, 0, 0, 0)

# Crop the image to its bounding box
bb = img.getbbox()
if bb:
    img = img.crop(bb)

img.save("assets/pure_coin.png")
print("Saved flawless pure_coin.png")
