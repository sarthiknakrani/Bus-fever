from PIL import Image, ImageFilter
import random

img = Image.open("assets/home_bg.png").convert("RGBA")
w, h = img.size
pixels = img.load()

# The sky from y=20 to y=110 is 90 pixels tall.
# We will copy it to y=110..200, y=200..290, y=290..380
sky_chunk = img.crop((0, 20, w, 110))

# We'll paste it smoothly
img.paste(sky_chunk, (0, 110))
img.paste(sky_chunk, (0, 200))
img.paste(sky_chunk, (0, 290))
img.paste(sky_chunk, (0, 380))

# Now let's blur the transition edges
# And blur the loading bar area
for y in range(620, 670):
    for x in range(w):
        r, g, b, a = pixels[x, 615]
        pixels[x, y] = (r, g, b, 255)

# Add some gaussian blur to the sky area to hide seams
mask = Image.new('L', img.size, 0)
from PIL import ImageDraw
draw = ImageDraw.Draw(mask)
draw.rectangle([0, 90, w, 400], fill=255)
blurred = img.filter(ImageFilter.GaussianBlur(10))
img.paste(blurred, mask=mask)

img.save("assets/home_bg_clean.png")
print("Processed background with tiling.")
