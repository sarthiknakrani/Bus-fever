import math
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size

work = base.copy()
wpix = work.load()

# 1. Clear everything above y=412
for y in range(0, 412):
    for x in range(w):
        wpix[x, y] = (0, 0, 0, 0)

# 2. Clear bus / tire residue between y=412 and y=444
for y in range(412, 444):
    for x in range(280, 780):
        r, g, b, a = wpix[x, y]
        if a > 0:
            # Tire rubber / dark grey / bumper grey
            if (r < 110 and g < 110 and b < 110) or (abs(r - g) < 22 and abs(g - b) < 22 and r < 155):
                wpix[x, y] = (0, 0, 0, 0)
            # Yellow bus body
            elif r > 180 and g > 140 and b < 110 and y < 440:
                wpix[x, y] = (0, 0, 0, 0)

# Clear the small tire notch on B top right (x in [400, 435], y in [432, 444])
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

# 3. Clean restoration of the right arm cap of 'U'
# Left arm cap: x in [481, 530], y in [438, 450] (width 50)
# Right arm: x in [572, 621], y in [438, 450] (offset = +91px)
for dx in range(50):
    for dy in range(12):
        sx = 481 + dx
        sy = 438 + dy
        tx = 572 + dx
        ty = 438 + dy
        sr, sg, sb, sa = wpix[sx, sy]
        if sa > 150 and (sr > 170 or (sr > 130 and sg > 70)):
            wpix[tx, ty] = (sr, sg, sb, sa)

# 4. Generate the 8x supersampled smooth pillowed purple backing tray
SCALE = 8
sw, sh = w * SCALE, h * SCALE

# Control points for the top contour: (x, y)
# Peaks at 416..417, shallow gentle dips at 422..424
ctrl_points = [
    (314, 436),
    (322, 428),
    (340, 420),
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
    (738, 422),
    (755, 428),
    (764, 436),  # Right shoulder
]

# Interpolate smooth curve using Catmull-Rom spline
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

# Scale to high-res canvas
scaled_poly = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
# Close polygon down to y=465
scaled_poly.append((int(ctrl_points[-1][0] * SCALE), int(465 * SCALE)))
scaled_poly.append((int(ctrl_points[0][0] * SCALE), int(465 * SCALE)))

tray_hi = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

# Base purple fill
# Rich authentic purple: (92, 54, 126)
tdraw.polygon(scaled_poly, fill=(92, 54, 126, 255))

# Top rim specular highlight (3.5px wide in 1x space = ~28px in 8x)
rim_pts = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
for i in range(len(rim_pts) - 1):
    tdraw.line([rim_pts[i], rim_pts[i + 1]], fill=(185, 160, 215, 255), width=int(3.2 * SCALE))

# Soft interior bevel highlight: 1.5px below top rim
rim_inner = [(int(pt[0] * SCALE), int((pt[1] + 1.6) * SCALE)) for pt in curve_points]
for i in range(len(rim_inner) - 1):
    tdraw.line([rim_inner[i], rim_inner[i + 1]], fill=(140, 95, 175, 200), width=int(2.0 * SCALE))

# Downscale to 1x with Lanczos
tray_1x = tray_hi.resize((w, h), Image.Resampling.LANCZOS)
tpix = tray_1x.load()

# Composite tray BEHIND existing letters
out = work.copy()
opix = out.load()

for y in range(405, 465):
    for x in range(300, 780):
        tr, tg, tb, ta = tpix[x, y]
        wr, wg, wb, wa = wpix[x, y]
        
        # Is work pixel a letter pixel?
        # Golden border: wr > 200, wg > 140, wb < 110
        # Red candy: wr > 180, wg < 130
        # White specular: wr > 220, wg > 210, wb > 170
        is_letter = wa > 120 and ((wr > 170 and wg > 45) or (wr > 220 and wg > 200 and wb > 160) or (wr > 130 and wg > 65 and wb < 75))
        
        if is_letter:
            opix[x, y] = (wr, wg, wb, wa)
        elif ta > 0:
            if wa > 80:
                # Smoothly merge with existing purple background below
                factor = ta / 255.0
                fr = int(tr * factor + wr * (1 - factor))
                fg = int(tg * factor + wg * (1 - factor))
                fb = int(tb * factor + wb * (1 - factor))
                opix[x, y] = (fr, fg, fb, max(ta, wa))
            else:
                opix[x, y] = (tr, tg, tb, ta)

out.save('/tmp/test_pillowed_tray.png')
print('Saved /tmp/test_pillowed_tray.png')
