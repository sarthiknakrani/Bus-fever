import math
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size

work = base.copy()
wpix = work.load()

# 1. Clear everything above y=410
for y in range(0, 412):
    for x in range(w):
        wpix[x, y] = (0, 0, 0, 0)

# 2. Clear any tire residue / bus yellow / bumper grey between y=412 and y=444
for y in range(412, 444):
    for x in range(260, 800):
        r, g, b, a = wpix[x, y]
        if a > 0:
            if (r < 110 and g < 110 and b < 110) or (abs(r - g) < 22 and abs(g - b) < 22 and r < 155):
                wpix[x, y] = (0, 0, 0, 0)
            elif r > 180 and g > 140 and b < 110 and y < 440:
                wpix[x, y] = (0, 0, 0, 0)

for x in range(400, 435):
    for y in range(430, 444):
        r, g, b, a = wpix[x, y]
        if a > 0 and (r < 120 and g < 120 and b < 120):
            wpix[x, y] = (0, 0, 0, 0)

for x in range(530, 570):
    for y in range(430, 455):
        r, g, b, a = wpix[x, y]
        if a > 0 and (r < 110 and g < 110 and b < 110):
            wpix[x, y] = (0, 0, 0, 0)

for x in range(630, 715):
    for y in range(412, 435):
        r, g, b, a = wpix[x, y]
        if a > 0 and (r < 120 and g < 120 and b < 120):
            wpix[x, y] = (0, 0, 0, 0)

# 3. Seamlessly restore right arm cap of 'U'
left_cap = base.crop((481, 438, 531, 455))
flipped = left_cap.transpose(Image.FLIP_LEFT_RIGHT).convert('RGBA')
fw, fh = flipped.size
fpix = flipped.load()

for y in range(fh - 4, fh):
    alpha_factor = (fh - 1 - y) / 4.0
    for x in range(fw):
        r, g, b, a = fpix[x, y]
        fpix[x, y] = (r, g, b, int(a * alpha_factor))

work.alpha_composite(flipped, (571, 438))
wpix = work.load()

# 4. Generate the 8x supersampled 3D purple backing tray
SCALE = 8
sw, sh = w * SCALE, h * SCALE

# Control points for the top contour:
ctrl_points = [
    (319, 458),
    (322, 448),
    (327, 438),
    (336, 428),
    (350, 420),
    (370, 415),  # Peak over B
    (410, 417),
    (445, 423),  # Gentle dip between B and U
    (475, 419),
    (505, 416),  # Peak over U left
    (535, 420),
    (550, 422),  # Dip in U center
    (565, 420),
    (595, 416),  # Peak over U right
    (625, 419),
    (642, 423),  # Gentle dip between U and S
    (660, 418),
    (678, 415),  # Peak over S
    (710, 418),
    (730, 424),
    (744, 432),
    (752, 444),
    (758, 454),  # Right shoulder tangent
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

# Supersampled layers
tray_hi = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

# Layer A: Dark purple outer bevel rim (offset 1.5px upwards)
outer_bevel_pts = [(int(pt[0] * SCALE), int((pt[1] - 1.5) * SCALE)) for pt in curve_points]
outer_poly = list(outer_bevel_pts)
outer_poly.append((int(ctrl_points[-1][0] * SCALE), int(465 * SCALE)))
outer_poly.append((int(ctrl_points[0][0] * SCALE), int(465 * SCALE)))
tdraw.polygon(outer_poly, fill=(52, 28, 76, 255))

# Layer B: Rich purple body fill
scaled_poly = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
scaled_poly.append((int(ctrl_points[-1][0] * SCALE), int(465 * SCALE)))
scaled_poly.append((int(ctrl_points[0][0] * SCALE), int(465 * SCALE)))
tdraw.polygon(scaled_poly, fill=(94, 57, 126, 255))

# Layer C: Lavender specular highlight rim
rim_pts = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
for i in range(len(rim_pts) - 1):
    tdraw.line([rim_pts[i], rim_pts[i + 1]], fill=(195, 172, 225, 255), width=int(2.8 * SCALE))

# Layer D: Soft interior blend
rim_inner = [(int(pt[0] * SCALE), int((pt[1] + 1.5) * SCALE)) for pt in curve_points]
for i in range(len(rim_inner) - 1):
    tdraw.line([rim_inner[i], rim_inner[i + 1]], fill=(135, 90, 168, 200), width=int(2.0 * SCALE))

# Downscale to 1x with Lanczos
tray_1x = tray_hi.resize((w, h), Image.Resampling.LANCZOS)
tpix = tray_1x.load()

# Ambient shadow directly above letters
shadow_hi = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
sdraw = ImageDraw.Draw(shadow_hi)
shadow_pts = [
    (int(335 * SCALE), int(440 * SCALE)),
    (int(370 * SCALE), int(434 * SCALE)),
    (int(445 * SCALE), int(438 * SCALE)),
    (int(505 * SCALE), int(435 * SCALE)),
    (int(550 * SCALE), int(438 * SCALE)),
    (int(595 * SCALE), int(435 * SCALE)),
    (int(642 * SCALE), int(438 * SCALE)),
    (int(678 * SCALE), int(434 * SCALE)),
    (int(745 * SCALE), int(440 * SCALE)),
]
for i in range(len(shadow_pts) - 1):
    sdraw.line([shadow_pts[i], shadow_pts[i + 1]], fill=(40, 20, 60, 180), width=int(4.5 * SCALE))

shadow_1x = shadow_hi.resize((w, h), Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))
spix = shadow_1x.load()

# Interpolate exact min_y for all integer x across the curve
min_y_map = {}
for pt in curve_points:
    ix = int(round(pt[0]))
    iy = int(math.floor(pt[1] - 2.0))
    if ix not in min_y_map or iy < min_y_map[ix]:
        min_y_map[ix] = iy

# Fill any missing x in range
all_xs = sorted(min_y_map.keys())
for i in range(len(all_xs) - 1):
    x1, x2 = all_xs[i], all_xs[i + 1]
    y1, y2 = min_y_map[x1], min_y_map[x2]
    for x in range(x1 + 1, x2):
        t = (x - x1) / float(x2 - x1)
        min_y_map[x] = int(y1 + t * (y2 - y1))

final = work.copy()
fpix = final.load()

# Clear ALL pixels above the tray boundary across the entire width of the logo!
for x in range(w):
    limit_y = min_y_map.get(x, 460 if (x < 319 or x > 758) else 412)
    for y in range(0, limit_y):
        fpix[x, y] = (0, 0, 0, 0)

# Merge tray behind letters
for y in range(410, 465):
    for x in range(300, 780):
        tr, tg, tb, ta = tpix[x, y]
        wr, wg, wb, wa = wpix[x, y]
        sr, sg, sb, sa = spix[x, y]
        
        is_letter = wa > 120 and ((wr > 170 and wg > 45) or (wr > 220 and wg > 200 and wb > 160) or (wr > 130 and wg > 65 and wb < 75))
        
        if is_letter:
            fpix[x, y] = (wr, wg, wb, wa)
        elif ta > 0:
            if sa > 0:
                s_factor = sa / 255.0 * 0.4
                tr = int(tr * (1 - s_factor) + sr * s_factor)
                tg = int(tg * (1 - s_factor) + sg * s_factor)
                tb = int(tb * (1 - s_factor) + sb * s_factor)
                
            if wa > 80:
                factor = ta / 255.0
                fr = int(tr * factor + wr * (1 - factor))
                fg = int(tg * factor + wg * (1 - factor))
                fb = int(tb * factor + wb * (1 - factor))
                fpix[x, y] = (fr, fg, fb, max(ta, wa))
            else:
                fpix[x, y] = (tr, tg, tb, ta)

# Save master full-size restored logo
final.save('/tmp/flawless_logo_master.png')
print('Successfully generated /tmp/flawless_logo_master.png')
