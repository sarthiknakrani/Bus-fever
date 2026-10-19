import math
from PIL import Image, ImageDraw, ImageFilter

# Load the base logo before the bus was butchered (commit 40a8b83)
# We extracted it earlier to /tmp/logo_with_bus.png
base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size

# We work on a clean copy
restored = base.copy()
rpix = restored.load()

# Step 1: In base, the bus is strictly at y < 442 in the region x in [240, 840].
# But let's be extremely precise about what is bus and what is letter.
# In the original image:
# - 'S' (x in [620, 740], y in [430, 600]) is 100% original. The rear wheel was above y=430.
# - 'B' (x in [330, 460], y in [430, 600]) has letter pixels from y=438 down.
# - 'U' left pillar (x in [480, 530], y in [438, 600]) is 100% original.
# - 'U' right pillar (x in [565, 615], y in [444, 600]) is 100% original from y=444 down.

# Let's inspect the exact crop in global coordinates (offset x=0, y=0 in base)
# Letter top level in base is y=436..442.
# Everything above y=415 is bus or background!
# Let's erase the bus: for y < 415, everything is set to transparent (0, 0, 0, 0)
for y in range(0, 418):
    for x in range(w):
        rpix[x, y] = (0, 0, 0, 0)

# Clear any tire / bumper residue between y=418 and y=442
for y in range(418, 444):
    for x in range(300, 780):
        r, g, b, a = rpix[x, y]
        if a > 0:
            # Tire rubber / dark grey / bumper grey
            if (r < 95 and g < 95 and b < 95) or (abs(r - g) < 20 and abs(g - b) < 20 and r < 140):
                rpix[x, y] = (0, 0, 0, 0)
            # Yellow bus body remnants
            elif r > 180 and g > 150 and b < 100 and y < 438:
                rpix[x, y] = (0, 0, 0, 0)

restored.save('/tmp/restored_step1.png')
print('Saved /tmp/restored_step1.png')
