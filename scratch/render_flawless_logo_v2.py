import math
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size
base_pix = base.load()

# -------------------------------------------------------------
# 1. Build Pristine Foreground Layer (Letters B, U, S)
# -------------------------------------------------------------
fg = Image.new('RGBA', (w, h), (0, 0, 0, 0))
fg_pix = fg.load()

# Clean extraction of letters B, U, S
for y in range(437, 620):
    for x in range(300, 770):
        r, g, b, a = base_pix[x, y]
        if a > 80:
            # Skip non-letter background valleys
            in_bu_valley = (x >= 435 and x <= 478 and y < 455)
            in_u_canyon = (x >= 531 and x <= 565 and y < 545)
            in_us_valley = (x >= 618 and x <= 645 and y < 455)
            
            if in_bu_valley or in_u_canyon or in_us_valley:
                continue
                
            # Exclude tire shadows at the very top
            if y < 443 and r < 125 and g < 75 and b < 80:
                continue
                
            is_gold = (r > 135 and g > 70 and b < 130)
            is_body = (r > 175 and g < 150)
            is_gloss = (r > 210 and g > 190 and b > 150)
            
            if is_gold or is_body or is_gloss or y >= 445:
                fg_pix[x, y] = (r, g, b, a)

# Seamlessly restore right arm cap of 'U' from left cap (height 15 to fully replace wheel shadow)
left_cap = base.crop((481, 438, 531, 453))
flipped = left_cap.transpose(Image.FLIP_LEFT_RIGHT).convert('RGBA')
fw, fh = flipped.size
fpix = flipped.load()

for y in range(fh - 4, fh):
    alpha_factor = (fh - 1 - y) / 4.0
    for x in range(fw):
        r, g, b, a = fpix[x, y]
        fpix[x, y] = (r, g, b, int(a * alpha_factor))

fg.alpha_composite(flipped, (571, 438))
fg_pix = fg.load()

# Touch up golden border at top of B (around x=410..435, y=437..440)
for x in range(410, 435):
    for y in range(437, 441):
        if fg_pix[x, y][3] == 0 and fg_pix[x, y + 2][3] > 150:
            fg_pix[x, y] = fg_pix[x, y + 2]

# -------------------------------------------------------------
# 2. Build 8x Supersampled Tailored Purple Backing Tray
# -------------------------------------------------------------
SCALE = 8
sw, sh = w * SCALE, h * SCALE

ctrl_points = [
    (320, 475),
    (320, 465),
    (320, 455),
    (322, 447),
    (326, 439),
    (334, 432),
    (346, 426),
    (368, 422),  # Peak over B
    (405, 423),
    (440, 426),  # Gentle dip between B and U
    (475, 423),
    (505, 422),  # Peak over U left
    (535, 424),
    (550, 425),  # Shallow dip in U center
    (565, 424),
    (595, 422),  # Peak over U right
    (625, 424),
    (645, 426),  # Gentle dip between U and S
    (665, 422),
    (680, 421),  # Peak over S
    (710, 423),
    (728, 427),
    (740, 434),
    (749, 442),
    (756, 450),
    (759, 458),
    (760, 468),
    (760, 475),
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

# Outer bevel shadow
outer_bevel_pts = [(int(pt[0] * SCALE), int((pt[1] - 1.4) * SCALE)) for pt in curve_points]
outer_poly = list(outer_bevel_pts)
outer_poly.append((int(ctrl_points[-1][0] * SCALE), int(480 * SCALE)))
outer_poly.append((int(ctrl_points[0][0] * SCALE), int(480 * SCALE)))
tdraw.polygon(outer_poly, fill=(65, 32, 85, 255))

# Rich purple body fill (120, 65, 148)
scaled_poly = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
scaled_poly.append((int(ctrl_points[-1][0] * SCALE), int(480 * SCALE)))
scaled_poly.append((int(ctrl_points[0][0] * SCALE), int(480 * SCALE)))
tdraw.polygon(scaled_poly, fill=(120, 65, 148, 255))

# Lavender specular highlight rim
rim_pts = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
for i in range(len(rim_pts) - 1):
    tdraw.line([rim_pts[i], rim_pts[i + 1]], fill=(195, 172, 225, 255), width=int(2.6 * SCALE))

# Soft interior blend
rim_inner = [(int(pt[0] * SCALE), int((pt[1] + 1.4) * SCALE)) for pt in curve_points]
for i in range(len(rim_inner) - 1):
    tdraw.line([rim_inner[i], rim_inner[i + 1]], fill=(148, 98, 180, 200), width=int(1.8 * SCALE))

tray_1x = tray_hi.resize((w, h), Image.Resampling.LANCZOS)
tpix = tray_1x.load()

# -------------------------------------------------------------
# 3. Clean Base Layer (FEVER, PARTY!, Lower Tray)
# -------------------------------------------------------------
out_base = base.copy()
ob_pix = out_base.load()

# Clear everything above y=442 in out_base
for y in range(0, 442):
    for x in range(w):
        ob_pix[x, y] = (0, 0, 0, 0)

# Clear any residue white/grey pixels with alpha < 15 or white specks
for y in range(0, h):
    for x in range(w):
        r, g, b, a = ob_pix[x, y]
        if a > 0 and a < 15 and r > 200 and g > 200 and b > 200:
            ob_pix[x, y] = (0, 0, 0, 0)

# Composite tray behind lower base
composite = Image.alpha_composite(tray_1x, out_base)
cpix = composite.load()

# Fill U canyon between the pillars (x in [532, 565], y from 425 to 544)
for y in range(425, 544):
    t = (y - 425) / float(544 - 425)
    vr = int(120 * (1 - t) + 75 * t)
    vg = int(65 * (1 - t) + 50 * t)
    vb = int(148 * (1 - t) + 134 * t)
    for x in range(532, 565):
        r, g, b, a = cpix[x, y]
        is_letter = (a > 150) and (r > 180 or (r > 140 and g > 75))
        if not is_letter:
            cpix[x, y] = (vr, vg, vb, 255)

# Alpha-composite the pristine letters ON TOP of the tray!
final = Image.alpha_composite(composite, fg)
fpix = final.load()

# Clean up any stray pixels above the tray boundary
min_y_map = {}
for pt in curve_points:
    ix = int(round(pt[0]))
    iy = int(math.floor(pt[1] - 2.0))
    if ix not in min_y_map or iy < min_y_map[ix]:
        min_y_map[ix] = iy

all_xs = sorted(min_y_map.keys())
for i in range(len(all_xs) - 1):
    x1, x2 = all_xs[i], all_xs[i + 1]
    y1, y2 = min_y_map[x1], min_y_map[x2]
    for x in range(x1 + 1, x2):
        t = (x - x1) / float(x2 - x1)
        min_y_map[x] = int(y1 + t * (y2 - y1))

for x in range(w):
    limit_y = min_y_map.get(x, 475)
    for y in range(0, limit_y):
        fpix[x, y] = (0, 0, 0, 0)

# Clean any tiny specks with alpha < 10
for y in range(0, h):
    for x in range(w):
        if fpix[x, y][3] < 10:
            fpix[x, y] = (0, 0, 0, 0)

# Crop to tight bounding box and center on (732, 664)
bbox = final.getbbox()
print("Tight bounding box:", bbox)
cropped = final.crop(bbox)
cw, ch = cropped.size
print(f"Cropped dimensions: {cw}x{ch}")

TARGET_W, TARGET_H = 732, 664
master = Image.new('RGBA', (TARGET_W, TARGET_H), (0, 0, 0, 0))
paste_x = (TARGET_W - cw) // 2
paste_y = (TARGET_H - ch) // 2
master.alpha_composite(cropped, (paste_x, paste_y))

dest_path = 'assets/ui/logo/bus_fever_party_logo.png'
master.save(dest_path)
print(f"Successfully saved {dest_path} ({TARGET_W}x{TARGET_H})")
