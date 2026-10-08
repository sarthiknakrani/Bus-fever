from PIL import Image

img_path = "assets/coin_counter_full.png"
img = Image.open(img_path).convert("RGBA")
pixels = img.load()
w, h = img.size

# We want to find the blue text "40" and turn it into the background color.
# The text is on the right side of the pill.
# Let's find the most common color in the right half of the image that isn't transparent.
bg_colors = []
for x in range(w // 2, w - 10):
    for y in range(h // 2 - 20, h // 2 + 20):
        p = pixels[x, y]
        if p[3] > 200:
            bg_colors.append(p)

from collections import Counter
most_common_bg = Counter(bg_colors).most_common(1)[0][0]
print("Background color:", most_common_bg)

# Now iterate over the right half and replace any dark/blueish pixels with the background color
for x in range(w // 3, w):
    for y in range(0, h):
        p = pixels[x, y]
        if p[3] > 100:
            # Check if it's blue/dark
            if p[0] < 100 and p[1] < 120 and p[2] < 150:
                # It's part of the text "40"
                pixels[x, y] = most_common_bg
            # We can also do a simple distance check: if it's far from white/light-grey, it's text.
            # Most common is usually (234, 239, 245) or something.
            dist = sum(abs(p[i] - most_common_bg[i]) for i in range(3))
            if dist > 50:
                # Keep some antialiasing if it's edge, but let's just make it background
                pixels[x, y] = most_common_bg

img.save("assets/coin_counter_empty.png")
print("Saved empty coin counter")
