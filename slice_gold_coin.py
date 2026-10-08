from PIL import Image

img_path = "assets/coin_counter_full.png"
img = Image.open(img_path).convert("RGBA")
w, h = img.size

# The coin and green + are on the left. The white pill extends to the right.
# Let's crop the left part. We'll find the rightmost extent of the green + or coin.
# Wait, just hardcode the crop. The image is probably 320x150.
# The coin is roughly the first 120-140 pixels.
crop = img.crop((0, 0, 130, h))
# Let's make anything that is whiteish (the pill) transparent.
pixels = crop.load()
cw, ch = crop.size
for x in range(cw):
    for y in range(ch):
        p = pixels[x, y]
        # Pill color is bluish-white, e.g. 230-255
        if p[3] > 0:
            # Check if it's whiteish (pill)
            if p[0] > 200 and p[1] > 210 and p[2] > 230:
                pixels[x, y] = (0, 0, 0, 0)

crop.save("assets/gold_coin_only.png")
print("Saved gold_coin_only.png")
