import math
from PIL import Image, ImageDraw, ImageFilter

# 1. Load the original base logo with bus (commit 40a8b83)
base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size

# Make a working canvas
work = base.copy()
wpix = work.load()

# 2. Clear all yellow bus and tires above the letters:
# Above y=412, clear everything
for y in range(0, 414):
    for x in range(w):
        wpix[x, y] = (0, 0, 0, 0)

# Clear any tire rubber / bumper residue between y=414 and y=444
for y in range(414, 444):
    for x in range(260, 800):
        r, g, b, a = wpix[x, y]
        if a > 0:
            # Tire rubber / dark grey / bumper grey
            if (r < 110 and g < 110 and b < 110) or (abs(r - g) < 22 and abs(g - b) < 22 and r < 155):
                wpix[x, y] = (0, 0, 0, 0)
            # Yellow bus body
            elif r > 180 and g > 140 and b < 110 and y < 440:
                wpix[x, y] = (0, 0, 0, 0)

# Clear tire contact on B top right (x in [400, 435], y in [432, 444])
for x in range(400, 435):
    for y in range(432, 444):
        r, g, b, a = wpix[x, y]
        if a > 0 and (r < 120 and g < 120 and b < 120):
            wpix[x, y] = (0, 0, 0, 0)

# Clear slot in U valley (x in [532, 568], y < 455)
for x in range(532, 568):
    for y in range(432, 455):
        r, g, b, a = wpix[x, y]
        if a > 0 and (r < 110 and g < 110 and b < 110):
            wpix[x, y] = (0, 0, 0, 0)

# Clear any residue above S (x in [630, 710], y in [414, 435])
for x in range(630, 710):
    for y in range(414, 435):
        r, g, b, a = wpix[x, y]
        if a > 0 and (r < 120 and g < 120 and b < 120):
            wpix[x, y] = (0, 0, 0, 0)

# 3. Restore the right pillar cap of 'U'
# Left arm cap is pristine at x in [481, 531], y in [438, 455] (50px wide)
left_cap = base.crop((481, 438, 531, 455))
flipped = left_cap.transpose(Image.FLIP_LEFT_RIGHT).convert('RGBA')
fw, fh = flipped.size
fpix = flipped.load()

# Smooth alpha feather on bottom 4 rows for seamless blend into pillar body
for y in range(fh - 4, fh):
    alpha_factor = (fh - 1 - y) / 4.0
    for x in range(fw):
        r, g, b, a = fpix[x, y]
        fpix[x, y] = (r, g, b, int(a * alpha_factor))

# Alpha composite flipped cap at exact offset (571, 438)
work.alpha_composite(flipped, (571, 438))
wpix = work.load()

# 4. Generate the 8x supersampled smooth pillowed purple backing tray
SCALE = 8
sw, sh = w * SCALE, h * SCALE

# Smooth tangent control points:
ctrl_points = [
    (319, 457),
    (322, 446),
    (328, 436),
    (338, 426),
    (352, 419),
    (370, 415),  # Peak over B
    (410, 417),
    (445, 423),  # Dip between B and U
    (475, 419),
    (505, 416),  # Peak over U left
    (535, 420),
    (550, 422),  # Dip in U center
    (565, 420),
    (595, 416),  # Peak over U right
    (625, 419),
    (642, 423),  # Dip between U and S
    (660, 418),
    (678, 415),  # Peak over S
    (710, 418),
    (730, 423),
    (745, 432),
    (752, 442),
    (758, 452),  # Right shoulder tangent
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

# High-res polygon
scaled_poly = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
scaled_poly.append((int(ctrl_points[-1][0] * SCALE), int(465 * SCALE)))
scaled_poly.append((int(ctrl_points[0][0] * SCALE), int(465 * SCALE)))

tray_hi = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

# Fill with rich 3D shaded purple gradient
tdraw.polygon(scaled_poly, fill=(94, 57, 126, 255))

# Top rim specular highlight line
rim_pts = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
for i in range(len(rim_pts) - 1):
    tdraw.line([rim_pts[i], rim_pts[i + 1]], fill=(190, 165, 220, 255), width=int(3.2 * SCALE))

# Soft inner bevel highlight line
rim_inner = [(int(pt[0] * SCALE), int((pt[1] + 1.6) * SCALE)) for pt in curve_points]
for i in range(len(rim_inner) - 1):
    tdraw.line([rim_inner[i], rim_inner[i + 1]], fill=(135, 92, 170, 200), width=int(2.2 * SCALE))

# Downscale tray with Lanczos
tray_1x = tray_hi.resize((w, h), Image.Resampling.LANCZOS)
tpix = tray_1x.load()

# Create ambient occlusion drop shadow above letters
# Shadow layer
shadow_hi = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
sdraw = ImageDraw.Draw(shadow_hi)
# Shadow contour sits 3px above the letters (y around 432..436)
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
    sdraw.line([shadow_pts[i], shadow_pts[i + 1]], fill=(40, 20, 60, 180), width=int(5.0 * SCALE))

shadow_1x = shadow_hi.resize((w, h), Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(1.5))
spix = shadow_1x.load()

# Composite:
final = work.copy()
fpix = final.load()

# Pre-calculate min y of tray for each x
min_y_per_x = {}
for pt in curve_points:
    ix = int(round(pt[0]))
    iy = int(math.floor(pt[1]))
    if ix not in min_y_per_x or iy < min_y_per_x[ix]:
        min_y_per_x[ix] = iy

# Clear any floating pixels above the tray contour
for x in range(280, 800):
    if x in min_y_per_x:
        for y in range(0, min_y_per_x[x]):
            fpix[x, y] = (0, 0, 0, 0)

# Merge tray behind letters
for y in range(410, 465):
    for x in range(300, 780):
        tr, tg, tb, ta = tpix[x, y]
        wr, wg, wb, wa = wpix[x, y]
        sr, sg, sb, sa = spix[x, y]
        
        # Letter check:
        # Golden border: wr > 200, wg > 140, wb < 110
        # Red candy: wr > 180, wg < 130
        # White gloss: wr > 220, wg > 200, wb > 160
        is_letter = wa > 120 and ((wr > 170 and wg > 45) or (wr > 220 and wg > 200 and wb > 160) or (wr > 130 and wg > 65 and wb < 75))
        
        if is_letter:
            fpix[x, y] = (wr, wg, wb, wa)
        elif ta > 0:
            # Apply ambient shadow if any
            if sa > 0:
                s_factor = sa / 255.0 * 0.4
                tr = int(tr * (1 - s_factor) + sr * s_factor)
                tg = int(tg * (1 - s_factor) + sg * s_factor)
                tb = int(tb * (1 - s_factor) + sb * s_factor)
                
            if wa > 80:
                # Merge into existing purple
                factor = ta / 255.0
                fr = int(tr * factor + wr * (1 - factor))
                fg = int(tg * factor + wg * (1 - factor))
                fb = int(tb * factor + wb * (1 - factor))
                fpix[x, y] = (fr, fg, fb, max(ta, wa))
            else:
                fpix[x, y] = (tr, tg, tb, ta)

# Save master full-size restored logo
final.save('/tmp/perfect_logo_master.png')
print('Successfully generated /tmp/perfect_logo_master.png')
