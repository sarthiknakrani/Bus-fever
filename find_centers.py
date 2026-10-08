from PIL import Image
import math

img = Image.open("assets/coin_counter_full.png").convert("RGBA")
w, h = img.size
pixels = img.load()

yellow_xs, yellow_ys = [], []
green_xs, green_ys = [], []

for x in range(w):
    for y in range(h):
        r, g, b, a = pixels[x, y]
        if a < 100: continue
        # Yellow
        if r > 200 and g > 150 and b < 100:
            yellow_xs.append(x)
            yellow_ys.append(y)
        # Green
        if g > 150 and r < 150 and b < 150:
            green_xs.append(x)
            green_ys.append(y)

c1_x = (min(yellow_xs) + max(yellow_xs)) / 2
c1_y = (min(yellow_ys) + max(yellow_ys)) / 2
r1 = (max(yellow_xs) - min(yellow_xs)) / 2

c2_x = (min(green_xs) + max(green_xs)) / 2
c2_y = (min(green_ys) + max(green_ys)) / 2
r2 = (max(green_xs) - min(green_xs)) / 2

print(f"Coin center: {c1_x}, {c1_y}, radius: {r1}")
print(f"Plus center: {c2_x}, {c2_y}, radius: {r2}")

# Now do the exact mask!
for x in range(w):
    for y in range(h):
        d1 = math.hypot(x - c1_x, y - c1_y)
        d2 = math.hypot(x - c2_x, y - c2_y)
        
        alpha1 = 0
        if d1 <= r1 - 0.5: alpha1 = 255
        elif d1 <= r1 + 1.5: alpha1 = int(255 * (1 - (d1 - (r1 - 0.5))/2.0))
        
        alpha2 = 0
        if d2 <= r2 - 0.5: alpha2 = 255
        elif d2 <= r2 + 1.5: alpha2 = int(255 * (1 - (d2 - (r2 - 0.5))/2.0))
        
        mask_alpha = max(alpha1, alpha2)
        
        r, g, b, a = pixels[x, y]
        new_a = min(a, mask_alpha)
        
        if new_a == 0:
            pixels[x, y] = (0, 0, 0, 0)
        else:
            pixels[x, y] = (r, g, b, new_a)

bb = img.getbbox()
if bb:
    img = img.crop(bb)
img.save("assets/pure_coin.png")
print("Saved perfect mathematically masked pure_coin.png")
