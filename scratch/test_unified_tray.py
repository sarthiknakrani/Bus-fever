import math
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size

# Clean base: remove bus
work = base.copy()
wpix = work.load()

# Clear everything above y=418
for y in range(0, 420):
    for x in range(w):
        wpix[x, y] = (0, 0, 0, 0)

# Clear any residue between y=420 and y=442
for y in range(420, 444):
    for x in range(290, 780):
        r, g, b, a = wpix[x, y]
        if a > 0:
            # Tire rubber / bumper grey / yellow bus
            if (r < 100 and g < 100 and b < 100) or (abs(r - g) < 20 and abs(g - b) < 20 and r < 150):
                wpix[x, y] = (0, 0, 0, 0)
            elif r > 180 and g > 150 and b < 100 and y < 440:
                wpix[x, y] = (0, 0, 0, 0)

# Also clear the small tire notch on B (around x=405..435, y in [434, 442])
for x in range(405, 435):
    for y in range(432, 444):
        r, g, b, a = wpix[x, y]
        if a > 0 and (r < 120 and g < 120 and b < 120):
            wpix[x, y] = (0, 0, 0, 0)

# Also clear the slot inside U valley (x in [532, 564], y < 455)
for x in range(532, 564):
    for y in range(435, 455):
        r, g, b, a = wpix[x, y]
        if a > 0 and (r < 100 and g < 100 and b < 100):
            wpix[x, y] = (0, 0, 0, 0)

# Fix right arm of U (x in [566, 618], y from 437 to 446)
# Left arm top cap is at x in [480, 532], y from 437 to 446 (width 52)
# Let's clone the pristine left cap onto the right arm, matching the curvature
for dx in range(53):
    for dy in range(12):
        sx = 480 + dx
        sy = 437 + dy
        tx = 566 + dx
        ty = 437 + dy
        sr, sg, sb, sa = wpix[sx, sy]
        if sa > 150 and (sr > 180 or (sr > 140 and sg > 80)): # letter or golden border
            wpix[tx, ty] = (sr, sg, sb, sa)

# Now let's create a smooth, high-resolution purple backing tray
# We will draw it supersampled 4x for ultimate sub-pixel smoothness!
SCALE = 4
sw, sh = w * SCALE, h * SCALE

tray = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray)

# Profile of the top purple tray:
# Left shoulder: (318, 430)
# Arching smoothly:
# x=318 -> y=430
# x=340 -> y=420
# x=370 -> y=412
# x=450 -> y=411
# x=540 -> y=412
# x=630 -> y=411
# x=710 -> y=413
# x=740 -> y=422
# x=760 -> y=432
# Downwards to y=455 to merge with existing purple backing
points = []
# Generate smooth curve using cubic spline / cosine interpolation
def get_tray_top_y(x):
    # Smooth arch with gentle pillowed curvature
    if x < 318:
        return 450.0
    elif x <= 370:
        # Left shoulder round-off
        t = (x - 318) / 52.0
        # Ease out
        return 430.0 - 18.0 * math.sin(t * math.pi * 0.5)
    elif x >= 710 and x <= 760:
        # Right shoulder round-off
        t = (x - 710) / 50.0
        # Ease in
        return 413.0 + 19.0 * (1.0 - math.cos(t * math.pi * 0.5))
    elif x > 760:
        return 450.0
    else:
        # Center section: very gentle wave following letters
        # x=370 (B center), x=505 (U left), x=590 (U right), x=675 (S center)
        # B peak: x=370, y=411
        # B-U dip: x=445, y=414
        # U-peak: x=550, y=412
        # U-S dip: x=635, y=414
        # S-peak: x=675, y=411
        # All within 411..414, extremely gentle and smooth!
        wave = math.sin((x - 370) * 0.035) * 1.5
        return 412.5 + wave

poly_points = []
for xi in range(318 * SCALE, 761 * SCALE):
    x = xi / SCALE
    y = get_tray_top_y(x)
    poly_points.append((xi, int(y * SCALE)))

# Close the polygon at the bottom
poly_points.append((760 * SCALE, 460 * SCALE))
poly_points.append((318 * SCALE, 460 * SCALE))

# Draw the deep purple base
tdraw.polygon(poly_points, fill=(96, 58, 130, 255))

# Draw lavender specular highlight along the top rim (3px wide)
for i in range(len(poly_points) - 2):
    p1 = poly_points[i]
    p2 = poly_points[i + 1] if i + 1 < len(poly_points) - 2 else poly_points[i]
    # Highlight color: (185, 160, 215)
    tdraw.line([p1, p2], fill=(195, 175, 225, 255), width=3 * SCALE)

# Downscale with high quality Lanczos filter for perfect anti-aliasing
tray_aa = tray.resize((w, h), Image.Resampling.LANCZOS)
tpix = tray_aa.load()

# Composite tray BEHIND existing letters:
# If work pixel has high alpha and is letter/border, PRESERVE IT!
# Otherwise, take tray pixel!
final_img = work.copy()
fpix = final_img.load()

for y in range(400, 465):
    for x in range(300, 780):
        tr, tg, tb, ta = tpix[x, y]
        wr, wg, wb, wa = wpix[x, y]
        
        # Check if work pixel is a foreground letter or golden border
        # Letters are orange/red/yellow: wr > 180 or (wr > 140 and wg > 70 and wb < 80)
        # Specular gloss is bright cream/white: wr > 220 and wg > 210 and wb > 180
        is_letter = wa > 150 and ((wr > 170 and wg > 50) or (wr > 220 and wg > 200 and wb > 170) or (wr > 130 and wg > 65 and wb < 75))
        
        if is_letter:
            # Keep pristine letter
            fpix[x, y] = (wr, wg, wb, wa)
        elif ta > 0:
            if wa > 100:
                # Blend with existing purple
                alpha_blend = ta / 255.0
                fr = int(tr * alpha_blend + wr * (1 - alpha_blend))
                fg = int(tg * alpha_blend + wg * (1 - alpha_blend))
                fb = int(tb * alpha_blend + wb * (1 - alpha_blend))
                fpix[x, y] = (fr, fg, fb, max(ta, wa))
            else:
                fpix[x, y] = (tr, tg, tb, ta)

final_img.save('/tmp/test_unified_tray.png')
print('Saved /tmp/test_unified_tray.png')
