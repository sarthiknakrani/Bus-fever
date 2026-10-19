import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

clean_letters = Image.open('/tmp/clean_letters_1x.png').convert('RGBA')
base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size

# Base without yellow bus (below y=442)
clean_base = base.copy()
cb_pix = clean_base.load()
for y in range(0, 442):
    for x in range(w):
        cb_pix[x, y] = (0, 0, 0, 0)

# Build Letter Mask of BUS
cl_pix = clean_letters.load()
mask = Image.new('L', (w, h), 0)
mpix = mask.load()
for y in range(434, 620):
    for x in range(300, 770):
        if cl_pix[x, y][3] > 60:
            mpix[x, y] = 255

# -------------------------------------------------------------
# OPTION 1: Tight, Uniform 3D Cartoon Outer Bevel (6px)
# -------------------------------------------------------------
# Dilate mask by 6px with smooth rounded edges
dilated_6 = mask.filter(ImageFilter.MaxFilter(13))
# Smooth anti-aliasing
dilated_smooth = dilated_6.filter(ImageFilter.GaussianBlur(1.0))
d_pix = dilated_smooth.load()

opt1_backing = Image.new('RGBA', (w, h), (0, 0, 0, 0))
o1_pix = opt1_backing.load()

for y in range(426, 620):
    for x in range(290, 780):
        val = d_pix[x, y]
        if val > 15:
            # Deep royal purple/navy 3D drop shadow bevel (#2E1952 to #1F103A)
            # Subtle vertical gradient matching FEVER tray
            t = (y - 426) / float(620 - 426)
            r = int(65 * (1 - t) + 38 * t)
            g = int(32 * (1 - t) + 24 * t)
            b = int(98 * (1 - t) + 68 * t)
            a = int(val)
            o1_pix[x, y] = (r, g, b, a)

# In the canyon of U and valleys, fill cleanly down to FEVER
for y in range(436, 545):
    t = (y - 436) / float(545 - 436)
    vr = int(65 * (1 - t) + 40 * t)
    vg = int(32 * (1 - t) + 25 * t)
    vb = int(98 * (1 - t) + 70 * t)
    for x in range(526, 572):
        if cl_pix[x, y][3] < 120:
            o1_pix[x, y] = (vr, vg, vb, 255)

# Composite Option 1: Backing -> Clean Base -> Clean Letters
comp1 = Image.alpha_composite(opt1_backing, clean_base)
comp1 = Image.alpha_composite(comp1, clean_letters)
comp1.save('/tmp/option1_tight_bevel.png')

# -------------------------------------------------------------
# OPTION 2: Pure Letters Standing Tall (Zero purple above golden domes)
# -------------------------------------------------------------
# Only fill the valleys between letters and canyon, NO purple above letter apexes
opt2_backing = Image.new('RGBA', (w, h), (0, 0, 0, 0))
o2_pix = opt2_backing.load()

for y in range(440, 545):
    t = (y - 440) / float(545 - 440)
    vr = int(65 * (1 - t) + 40 * t)
    vg = int(32 * (1 - t) + 25 * t)
    vb = int(98 * (1 - t) + 70 * t)
    for x in range(526, 572):
        if cl_pix[x, y][3] < 120:
            o2_pix[x, y] = (vr, vg, vb, 255)
    for x in range(438, 472):
        if cl_pix[x, y][3] < 120:
            o2_pix[x, y] = (vr, vg, vb, 255)
    for x in range(622, 646):
        if cl_pix[x, y][3] < 120:
            o2_pix[x, y] = (vr, vg, vb, 255)

comp2 = Image.alpha_composite(opt2_backing, clean_base)
comp2 = Image.alpha_composite(comp2, clean_letters)
comp2.save('/tmp/option2_pure_letters.png')

# -------------------------------------------------------------
# OPTION 3: Single Continuous Smooth Pillowed Arch (Geometric Crest)
# -------------------------------------------------------------
# A single, smooth, elegant circular arch centered at x=540, radius R=280
opt3_backing = Image.new('RGBA', (w, h), (0, 0, 0, 0))
o3_pix = opt3_backing.load()

# Arch equation: centered at (540, 710), radius R=285
for y in range(425, 480):
    for x in range(320, 760):
        dx = x - 540.0
        # Smooth circular arch:
        # peak at (540, 426)
        y_arch = 426.0 + 14.0 * ((dx / 220.0) ** 2)
        dist = y - y_arch
        if dist >= -1.0:
            a = min(255, max(0, int((dist + 1.0) * 255)))
            # Outer 2px specular highlight rim
            if dist < 2.5:
                o3_pix[x, y] = (195, 172, 225, a)
            else:
                o3_pix[x, y] = (120, 65, 148, a)

for y in range(436, 545):
    for x in range(526, 572):
        if cl_pix[x, y][3] < 120:
            o3_pix[x, y] = (120, 65, 148, 255)

comp3 = Image.alpha_composite(opt3_backing, clean_base)
comp3 = Image.alpha_composite(comp3, clean_letters)
comp3.save('/tmp/option3_smooth_arch.png')

print('Generated Option 1, Option 2, Option 3 successfully!')
