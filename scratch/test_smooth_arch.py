import math
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size

work = base.copy()
wpix = work.load()

# Clear everything above y=410
for y in range(0, 412):
    for x in range(w):
        wpix[x, y] = (0, 0, 0, 0)

# Clear any tire rubber / bus yellow / bumper grey between y=412 and y=444
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

# Seamlessly restore right arm cap of 'U'
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

SCALE = 8
sw, sh = w * SCALE, h * SCALE

# Smooth continuous convex arch control points:
# Pure, elegant, pillowed dome across the top of BUS:
ctrl_points = [
    (319, 457),
    (322, 446),
    (328, 436),
    (338, 427),
    (352, 420),
    (375, 415),
    (430, 413),
    (500, 412),
    (540, 412),
    (580, 412),
    (650, 413),
    (705, 415),
    (728, 420),
    (742, 427),
    (752, 436),
    (758, 446),
    (761, 457),
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

# Layer A: Dark purple outer bevel rim (offset 1.5px upwards)
outer_bevel_pts = [(int(pt[0] * SCALE), int((pt[1] - 1.5) * SCALE)) for pt in curve_points]
outer_poly = list(outer_bevel_pts)
outer_poly.append((int(ctrl_points[-1][0] * SCALE), int(465 * SCALE)))
outer_poly.append((int(ctrl_points[0][0] * SCALE), int(465 * SCALE)))
tdraw.polygon(outer_poly, fill=(50, 26, 74, 255))

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

tray_1x = tray_hi.resize((w, h), Image.Resampling.LANCZOS)
tpix = tray_1x.load()

final = work.copy()
fpix = final.load()

# Clear ANY pixel above the tray:
# If y < 455 and in x range [280, 800]: if tpix has alpha == 0 and not a letter, make transparent!
for y in range(400, 465):
    for x in range(300, 780):
        tr, tg, tb, ta = tpix[x, y]
        wr, wg, wb, wa = wpix[x, y]
        
        is_letter = wa > 120 and ((wr > 170 and wg > 45) or (wr > 220 and wg > 200 and wb > 160) or (wr > 130 and wg > 65 and wb < 75))
        
        if is_letter:
            fpix[x, y] = (wr, wg, wb, wa)
        elif ta > 0:
            if wa > 80:
                factor = ta / 255.0
                fr = int(tr * factor + wr * (1 - factor))
                fg = int(tg * factor + wg * (1 - factor))
                fb = int(tb * factor + wb * (1 - factor))
                fpix[x, y] = (fr, fg, fb, max(ta, wa))
            else:
                fpix[x, y] = (tr, tg, tb, ta)
        else:
            # Above tray or outside tray, and not a letter -> MUST BE TRANSPARENT
            fpix[x, y] = (0, 0, 0, 0)

final.save('/tmp/test_smooth_arch.png')
print('Saved /tmp/test_smooth_arch.png')
