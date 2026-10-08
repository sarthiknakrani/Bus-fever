from PIL import Image

img = Image.open("assets/coin_counter_full.png").convert("RGBA")
w, h = img.size
pixels = img.load()

# The coin is on the left. The text is at the bottom (y > 120).
# The pill is bluish-white.
# We will create a perfect cut of the coin. 
# We'll just take the left 110 pixels, and cut off the bottom text.
crop = img.crop((0, 0, 110, 120))
cw, ch = crop.size
pixels_c = crop.load()

# Remove the white pill part from the right edge
for x in range(cw):
    for y in range(ch):
        p = pixels_c[x, y]
        if p[3] > 0:
            # If it's very bright (white pill) and on the right side, remove it.
            # But don't remove the white plus sign! The plus sign is inside the green circle (which is green).
            if x > 80:
                # the pill has R>200, G>210, B>230
                if p[0] > 200 and p[1] > 200 and p[2] > 220:
                    pixels_c[x, y] = (0,0,0,0)

crop.save("assets/pure_coin.png")
print("Saved pure_coin.png")
