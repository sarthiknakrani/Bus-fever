import math
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size

work = base.copy()
wpix = work.load()

# Clear everything above y=412
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

ctrl_points = [
    (318, 475),
    (318, 462),
    (320, 452),
    (324, 442),
    (332, 432),
    (345, 424),
    (365, 418),
    (410, 414),
    (480, 412),
    (540, 412),
    (600, 412),
    (670, 414),
    (715, 418),
    (735, 424),
    (748, 432),
    (756, 442),
    (760, 452),
    (762, 462),
    (762, 475),
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

# Layer A: Dark purple outer bevel rim (offset 1.4px outwards)
outer_bevel_pts = [(int(pt[0] * SCALE), int((pt[1] - 1.4) * SCALE)) for pt in curve_points]
outer_poly = list(outer_bevel_pts)
outer_poly.append((int(ctrl_points[-1][0] * SCALE), int(480 * SCALE)))
outer_poly.append((int(ctrl_points[0][0] * SCALE), int(480 * SCALE)))
tdraw.polygon(outer_poly, fill=(65, 32, 85, 255))

# Layer B: Rich purple body fill - exact match to original backing (120, 65, 148)
scaled_poly = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
scaled_poly.append((int(ctrl_points[-1][0] * SCALE), int(480 * SCALE)))
scaled_poly.append((int(ctrl_points[0][0] * SCALE), int(480 * SCALE)))
tdraw.polygon(scaled_poly, fill=(120, 65, 148, 255))

# Layer C: Lavender specular highlight rim
rim_pts = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
for i in range(len(rim_pts) - 1):
    tdraw.line([rim_pts[i], rim_pts[i + 1]], fill=(195, 172, 225, 255), width=int(2.8 * SCALE))

# Layer D: Soft interior blend
rim_inner = [(int(pt[0] * SCALE), int((pt[1] + 1.5) * SCALE)) for pt in curve_points]
for i in range(len(rim_inner) - 1):
    tdraw.line([rim_inner[i], rim_inner[i + 1]], fill=(148, 98, 180, 200), width=int(2.0 * SCALE))

tray_1x = tray_hi.resize((w, h), Image.Resampling.LANCZOS)
tpix = tray_1x.load()

final = work.copy()
fpix = final.load()

# Clear ALL pixels above y=412 everywhere
for y in range(0, 412):
    for x in range(w):
        fpix[x, y] = (0, 0, 0, 0)

# Merge tray behind letters
for y in range(412, 475):
    for x in range(300, 780):
        tr, tg, tb, ta = tpix[x, y]
        wr, wg, wb, wa = wpix[x, y]
        
        is_letter = (y >= 436) and wa > 120 and (
            (wr > 170 and wg > 45) or 
            (wr > 220 and wg > 200 and wb > 160) or 
            (wr > 130 and wg > 65 and wb < 75)
        )
        
        if is_letter:
            fpix[x, y] = (wr, wg, wb, wa)
        elif ta > 0:
            if wa > 80:
                # Feather blend smoothly into existing purple
                if y >= 436 and y <= 444:
                    blend_factor = (444 - y) / 8.0
                elif y > 444:
                    blend_factor = 0.0
                else:
                    blend_factor = 1.0
                fr = int(tr * blend_factor + wr * (1 - blend_factor))
                fg = int(tg * blend_factor + wg * (1 - blend_factor))
                fb = int(tb * blend_factor + wb * (1 - blend_factor))
                fpix[x, y] = (fr, fg, fb, max(ta, wa))
            else:
                fpix[x, y] = (tr, tg, tb, ta)
        else:
            if y < 455 and not is_letter:
                fpix[x, y] = (0, 0, 0, 0)

# Fill U canyon between the pillars (x in [532, 564], y from 415 to 544)
for y in range(415, 544):
    t = (y - 415) / float(544 - 415)
    # Gradient matching the natural purple depth: (120, 65, 148) at top to (75, 50, 134) at bottom
    vr = int(120 * (1 - t) + 75 * t)
    vg = int(65 * (1 - t) + 50 * t)
    vb = int(148 * (1 - t) + 134 * t)
    for x in range(532, 565):
        r, g, b, a = fpix[x, y]
        is_letter = (a > 150) and (r > 180 or (r > 140 and g > 75))
        if not is_letter:
            fpix[x, y] = (vr, vg, vb, 255)

final.save('/tmp/test_unified_color.png')
print('Saved /tmp/test_unified_color.png')
