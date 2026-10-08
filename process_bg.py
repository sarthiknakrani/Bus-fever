from PIL import Image, ImageFilter

img = Image.open("assets/home_bg.png").convert("RGBA")
w, h = img.size
pixels = img.load()

# Let's see what the image looks like by doing some smart smudging

# 1. Erase Logo (roughly y=90 to y=330)
# The logo is from x=50 to x=310 roughly.
# Let's take the row of pixels at y=90 (mostly blue sky and clouds)
# and stretch it down to y=330.
for y in range(90, 330):
    # To make it look slightly better than a flat stretch, we can blend y=90 with y=330
    blend = (y - 90) / (330 - 90)
    for x in range(w):
        r1, g1, b1, a1 = pixels[x, 90]
        r2, g2, b2, a2 = pixels[x, 330]
        # But wait! y=330 has the tops of the buses and buildings!
        # Let's just stretch y=90 downwards.
        pixels[x, y] = (r1, g1, b1, 255)

# 2. Erase Loading Bar (roughly y=630 to y=660)
# The loading bar is a green pill on a dark road.
# Let's just take y=620 and stretch it down to y=670.
for y in range(610, 670):
    for x in range(w):
        r, g, b, a = pixels[x, 610]
        pixels[x, y] = (r, g, b, 255)

img = img.filter(ImageFilter.SMOOTH)
img.save("assets/home_bg_clean.png")
print("Processed background.")
