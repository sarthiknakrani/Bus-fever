import math
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size

# Extract pristine letters as a clean foreground layer:
fg = Image.new('RGBA', (w, h), (0, 0, 0, 0))
fg_pix = fg.load()
base_pix = base.load()

# 1. Copy letter pixels from base
for y in range(437, 620):
    for x in range(300, 770):
        r, g, b, a = base_pix[x, y]
        if a > 80:
            # Check if this pixel is inside the letters B, U, S
            # Exclude non-letter valleys:
            in_bu_valley = (x >= 435 and x <= 478 and y < 455)
            in_u_canyon = (x >= 532 and x <= 565 and y < 545)
            in_us_valley = (x >= 618 and x <= 645 and y < 455)
            
            if in_bu_valley or in_u_canyon or in_us_valley:
                continue # Purple backing, not letter
                
            # Exclude tire shadows (dark grey / dark brownish residue at the very top)
            is_tire_residue = (y < 443) and (r < 125 and g < 75 and b < 80)
            if is_tire_residue:
                continue
                
            # Letter check: golden border, candy red/orange, or white gloss
            is_gold = (r > 135 and g > 70 and b < 130)
            is_body = (r > 175 and g < 150)
            is_gloss = (r > 210 and g > 190 and b > 150)
            
            if is_gold or is_body or is_gloss or y >= 445:
                fg_pix[x, y] = (r, g, b, a)

# 2. Add the seamlessly restored right arm cap of 'U'
left_cap = base.crop((481, 438, 531, 448))
flipped = left_cap.transpose(Image.FLIP_LEFT_RIGHT).convert('RGBA')
fw, fh = flipped.size
fpix = flipped.load()

for y in range(fh - 3, fh):
    alpha_factor = (fh - 1 - y) / 3.0
    for x in range(fw):
        r, g, b, a = fpix[x, y]
        fpix[x, y] = (r, g, b, int(a * alpha_factor))

fg.alpha_composite(flipped, (571, 438))

# 3. Touch up golden border at top of B (around x=400..435, y=438..442)
# If any tiny gap in the golden arc:
fg_pix = fg.load()
for x in range(410, 435):
    for y in range(437, 441):
        if fg_pix[x, y][3] == 0 and fg_pix[x, y + 2][3] > 150:
            # Fill with adjacent golden border color
            fg_pix[x, y] = fg_pix[x, y + 2]

# 4. Generate the tailored 8x supersampled purple tray
SCALE = 8
sw, sh = w * SCALE, h * SCALE

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

outer_bevel_pts = [(int(pt[0] * SCALE), int((pt[1] - 1.4) * SCALE)) for pt in curve_points]
outer_poly = list(outer_bevel_pts)
outer_poly.append((int(ctrl_points[-1][0] * SCALE), int(480 * SCALE)))
outer_poly.append((int(ctrl_points[0][0] * SCALE), int(480 * SCALE)))
tdraw.polygon(outer_poly, fill=(65, 32, 85, 255))

scaled_poly = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
scaled_poly.append((int(ctrl_points[-1][0] * SCALE), int(480 * SCALE)))
scaled_poly.append((int(ctrl_points[0][0] * SCALE), int(480 * SCALE)))
tdraw.polygon(scaled_poly, fill=(120, 65, 148, 255))

rim_pts = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
for i in range(len(rim_pts) - 1):
    tdraw.line([rim_pts[i], rim_pts[i + 1]], fill=(195, 172, 225, 255), width=int(2.6 * SCALE))

rim_inner = [(int(pt[0] * SCALE), int((pt[1] + 1.4) * SCALE)) for pt in curve_points]
for i in range(len(rim_inner) - 1):
    tdraw.line([rim_inner[i], rim_inner[i + 1]], fill=(148, 98, 180, 200), width=int(1.8 * SCALE))

tray_1x = tray_hi.resize((w, h), Image.Resampling.LANCZOS)

# Start with the pristine base logo (which has all FEVER, PARTY, and lower tray)
out = base.copy()
opix = out.load()

# Clear everything above y=442 in out
for y in range(0, 442):
    for x in range(w):
        opix[x, y] = (0, 0, 0, 0)

# Paste tray behind
out = Image.alpha_composite(tray_1x, out)

# Fill U canyon between the pillars (x in [532, 565], y from 426 to 544)
opix = out.load()
for y in range(426, 544):
    t = (y - 426) / float(544 - 426)
    vr = int(120 * (1 - t) + 75 * t)
    vg = int(65 * (1 - t) + 50 * t)
    vb = int(148 * (1 - t) + 134 * t)
    for x in range(532, 565):
        r, g, b, a = opix[x, y]
        is_letter = (a > 150) and (r > 180 or (r > 140 and g > 75))
        if not is_letter:
            opix[x, y] = (vr, vg, vb, 255)

# Alpha-composite the pristine letters ON TOP of the tray!
out.alpha_composite(fg, (0, 0))

out.save('/tmp/test_clean_foreground.png')
print('Saved /tmp/test_clean_foreground.png')
