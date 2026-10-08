from PIL import Image
import math

# We will start from the original full image so we have all the original anti-aliased pixels
img = Image.open("assets/coin_counter_full.png").convert("RGBA")
w, h = img.size
pixels = img.load()

# Let's find the exact center of the coin.
# The coin is yellow.
# Left edge: x=0. Right edge: x=90. So center_x = 45.
# Top edge: y=10. Bottom edge: y=100. So center_y = 55.
c1_x, c1_y = 45, 55
r1 = 45

# Let's find the exact center of the green plus.
# Green plus is green.
# Left edge: x=65. Right edge: x=105. So center_x = 85.
# Top edge: y=70. Bottom edge: y=110. So center_y = 90.
c2_x, c2_y = 85, 90
r2 = 21

for x in range(w):
    for y in range(h):
        # Distance to coin center
        d1 = math.hypot(x - c1_x, y - c1_y)
        # Distance to plus center
        d2 = math.hypot(x - c2_x, y - c2_y)
        
        # Soft masking for anti-aliasing
        # If distance is less than radius, keep alpha 255.
        # If distance is between radius and radius + 2, scale alpha.
        # Else alpha 0.
        
        # We take the minimum distance to either circle
        
        # Actually, let's just use the existing alpha, but cap it using the distance.
        alpha1 = 0
        if d1 <= r1: alpha1 = 255
        elif d1 <= r1 + 1.5: alpha1 = int(255 * (1 - (d1 - r1)/1.5))
        
        alpha2 = 0
        if d2 <= r2: alpha2 = 255
        elif d2 <= r2 + 1.5: alpha2 = int(255 * (1 - (d2 - r2)/1.5))
        
        mask_alpha = max(alpha1, alpha2)
        
        r, g, b, a = pixels[x, y]
        new_a = min(a, mask_alpha)
        
        if new_a == 0:
            pixels[x, y] = (0, 0, 0, 0)
        else:
            pixels[x, y] = (r, g, b, new_a)

# Crop
bb = img.getbbox()
if bb:
    img = img.crop(bb)
img.save("assets/pure_coin.png")
print("Saved mathematically masked pure_coin.png")
