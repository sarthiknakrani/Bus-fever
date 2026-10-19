import math
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size

work = base.copy()
wpix = work.load()

# Step 1: In base, the yellow bus is strictly at y < 437.
# Let's inspect what is in base between y=415 and 437:
# It's yellow bus body, tires, and grey bumper.
# Below y=437, letter B and S and U-left are 100% untouched!
# Let's cleanly restore the right pillar cap of 'U' from y=438 to 445:
# Left cap is at x in [481, 531], y in [438, 447] (width 50)
left_cap = base.crop((481, 438, 531, 448))
flipped = left_cap.transpose(Image.FLIP_LEFT_RIGHT).convert('RGBA')
fw, fh = flipped.size
fpix = flipped.load()

# Feather the bottom 3 rows
for y in range(fh - 3, fh):
    alpha_factor = (fh - 1 - y) / 3.0
    for x in range(fw):
        r, g, b, a = fpix[x, y]
        fpix[x, y] = (r, g, b, int(a * alpha_factor))

# Composite onto right pillar at (571, 438)
work.alpha_composite(flipped, (571, 438))
wpix = work.load()

# Now, create the tailored 8x supersampled purple tray
SCALE = 8
sw, sh = w * SCALE, h * SCALE

# Control points: perfectly tailored ~14-16px above letter crowns
# B top is at y=439 -> tray peak at y=423
# U left top is at y=439 -> tray peak at y=423
# U right top is at y=439 -> tray peak at y=423
# S top is at y=437 -> tray peak at y=421
ctrl_points = [
    (318, 475),
    (318, 460),
    (320, 450),
    (325, 442),
    (334, 435),
    (348, 429),
    (370, 423),  # Peak over B
    (405, 424),
    (440, 427),  # Gentle dip between B and U
    (475, 424),
    (505, 423),  # Peak over U left
    (535, 425),
    (550, 426),  # Shallow dip in U center
    (565, 425),
    (595, 423),  # Peak over U right
    (625, 425),
    (645, 427),  # Gentle dip between U and S
    (662, 423),
    (680, 421),  # Peak over S
    (710, 423),
    (730, 428),
    (745, 435),
    (754, 444),
    (759, 454),
    (761, 465),
    (761, 475),
]

def catmull_rom(p0, p1, p2, p3, t):
    t2 = t * t
    t3 = t2 * t
    x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
    y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
    return (x, y)

curve_points = []
n = len(ctrl_points)
for i in range(n - 1):
    p0 = ctrl_points[max(0, i - 1)]
    p1 = ctrl_points[i]
    p2 = ctrl_points[i + 1]
    p3 = ctrl_points[min(n - 1, i + 2)]
    steps = 40
    for s in range(steps):
        t = s / float(steps)
        pt = catmull_rom(p0, p1, p2, p3, t)
        curve_points.append(pt)
curve_points.append(ctrl_points[-1])

tray_hi = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

# Layer A: Dark purple outer bevel rim (1.4px offset)
outer_bevel_pts = [(int(pt[0] * SCALE), int((pt[1] - 1.4) * SCALE)) for pt in curve_points]
outer_poly = list(outer_bevel_pts)
outer_poly.append((int(ctrl_points[-1][0] * SCALE), int(480 * SCALE)))
outer_poly.append((int(ctrl_points[0][0] * SCALE), int(480 * SCALE)))
tdraw.polygon(outer_poly, fill=(65, 32, 85, 255))

# Layer B: Rich purple body fill (120, 65, 148)
scaled_poly = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
scaled_poly.append((int(ctrl_points[-1][0] * SCALE), int(480 * SCALE)))
scaled_poly.append((int(ctrl_points[0][0] * SCALE), int(480 * SCALE)))
tdraw.polygon(scaled_poly, fill=(120, 65, 148, 255))

# Layer C: Lavender specular highlight rim
rim_pts = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
for i in range(len(rim_pts) - 1):
    tdraw.line([rim_pts[i], rim_pts[i + 1]], fill=(195, 172, 225, 255), width=int(2.6 * SCALE))

# Layer D: Soft interior blend
rim_inner = [(int(pt[0] * SCALE), int((pt[1] + 1.4) * SCALE)) for pt in curve_points]
for i in range(len(rim_inner) - 1):
    tdraw.line([rim_inner[i], rim_inner[i + 1]], fill=(148, 98, 180, 200), width=int(1.8 * SCALE))

tray_1x = tray_hi.resize((w, h), Image.Resampling.LANCZOS)

# Composite:
# We start with the smooth tray:
result = tray_1x.copy()

# Underneath y=437:
# The letters and background from 'work' are pasted ON TOP of the tray!
# BUT ONLY letter pixels or existing background pixels below y=437!
# Let's inspect: in 'work', all pixels with y >= 437 belong to the letters and original logo!
# At y < 437: there are NO letters! (Only bus was there, which is removed!)
# At y >= 437: 'work' has the letters!
# If we take 'work' with everything above y=437 cleared, and alpha-composite 'work' OVER result:
# THEN THE LETTERS WILL REST ON TOP OF THE TRAY WITH 100% PRISTINE, ORIGINAL EDGES!
clean_foreground = work.copy()
cpix = clean_foreground.load()
for y in range(0, 437):
    for x in range(w):
        cpix[x, y] = (0, 0, 0, 0)

# Also clear the bus tire contact that touched x in [570, 600], y in [437, 444]
# (already restored with flipped cap above)

# Composite clean letters OVER the smooth purple tray!
result.alpha_composite(clean_foreground, (0, 0))

# Fill U canyon between the pillars (x in [532, 564], y from 426 to 544)
rpix = result.load()
for y in range(426, 544):
    t = (y - 426) / float(544 - 426)
    vr = int(120 * (1 - t) + 75 * t)
    vg = int(65 * (1 - t) + 50 * t)
    vb = int(148 * (1 - t) + 134 * t)
    for x in range(532, 565):
        r, g, b, a = rpix[x, y]
        is_letter = (a > 150) and (r > 180 or (r > 140 and g > 75))
        if not is_letter:
            rpix[x, y] = (vr, vg, vb, 255)

# Save result
result.save('/tmp/test_tailored_tray.png')
print('Saved /tmp/test_tailored_tray.png')
