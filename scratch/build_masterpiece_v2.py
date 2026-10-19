import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/6452_logo.png').convert('RGBA')
W, H = base.size
SCALE = 4
SW, SH = W * SCALE, H * SCALE

b_pix = base.load()

# -------------------------------------------------------------------------
# Step 1: Restore Pristine Candy Tops
# -------------------------------------------------------------------------

# 1a. Erase all old tray pixels, tire glitches, and white lines above y=45
# Clean slate for the letters below y=45
for y in range(0, 46):
    for x in range(140, 592):
        b_pix[x, y] = (0, 0, 0, 0)

# 1b. Clean any isolated glitch pixels on letter B at y=46..48
for y in range(46, 49):
    for x in range(180, 270):
        r, g, b, a = b_pix[x, y]
        if a > 40:
            # Indigo / tire glitches: high blue or low luminance
            if (b > r + 20 and b > 120) or (r < 70 and g < 70 and b < 70):
                # Clean golden bevel
                b_pix[x, y] = (255, 215, 80, 255)

# 1c. Clean any isolated glitch pixels on letter S at y=46..48
for y in range(46, 49):
    for x in range(480, 565):
        r, g, b, a = b_pix[x, y]
        if a > 40:
            if (b > r + 20 and b > 120) or (r < 70 and g < 70 and b < 70):
                b_pix[x, y] = (255, 215, 80, 255)

# 1d. Surgical mirroring of Left U stem onto Right U stem:
# Left stem candy is x in [306, 351] (width 46), y in [46, 86] (height 41)
# Right stem candy is x in [404, 449] (width 46), y in [46, 86]
left_stem_crop = base.crop((306, 46, 352, 86))
right_stem_cap = left_stem_crop.transpose(Image.FLIP_LEFT_RIGHT).convert('RGBA')
rc_pix = right_stem_cap.load()
cw, ch = right_stem_cap.size

# Feather the bottom 12 rows for smooth candy blend
for y in range(ch - 12, ch):
    alpha_mul = (ch - 1 - y) / 12.0
    for x in range(cw):
        r, g, b, a = rc_pix[x, y]
        ex_r, ex_g, ex_b, ex_a = b_pix[404 + x, 46 + y]
        nr = int(r * alpha_mul + ex_r * (1.0 - alpha_mul))
        ng = int(g * alpha_mul + ex_g * (1.0 - alpha_mul))
        nb = int(b * alpha_mul + ex_b * (1.0 - alpha_mul))
        na = int(a * alpha_mul + ex_a * (1.0 - alpha_mul))
        rc_pix[x, y] = (nr, ng, nb, na)

base.alpha_composite(right_stem_cap, (404, 46))
b_pix = base.load()

# -------------------------------------------------------------------------
# Step 2: Draw the Flawless 3D Purple Crown Arch
# -------------------------------------------------------------------------
# Spline control points that smoothly flow into the original plaque shoulders:
spline_ctrls = [
    (143.0, 80.0),
    (145.0, 62.0),
    (150.0, 47.0),
    (162.0, 36.0),
    (185.0, 29.0),
    (240.0, 25.0), # Smoothly over B
    (310.0, 23.5),
    (365.0, 23.0), # Apex over U center
    (420.0, 23.5),
    (490.0, 25.0), # Smoothly over S
    (545.0, 29.0),
    (568.0, 36.0),
    (580.0, 47.0),
    (585.0, 62.0),
    (587.0, 80.0)
]

def catmull_rom(p0, p1, p2, p3, t):
    t2 = t * t
    t3 = t2 * t
    x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
    y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
    return (x, y)

arch_pts = []
for i in range(len(spline_ctrls) - 1):
    p0 = spline_ctrls[max(0, i - 1)]
    p1 = spline_ctrls[i]
    p2 = spline_ctrls[i + 1]
    p3 = spline_ctrls[min(len(spline_ctrls) - 1, i + 2)]
    steps = 25
    for s in range(steps):
        t = s / float(steps)
        arch_pts.append(catmull_rom(p0, p1, p2, p3, t))
arch_pts.append(spline_ctrls[-1])

# Draw on 4x supersampled canvas
tray_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

poly_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]
poly_4x.append((587.0 * SCALE, 82.0 * SCALE))
poly_4x.append((143.0 * SCALE, 82.0 * SCALE))

# Rich royal purple fill matching existing badge (#4E2069)
tdraw.polygon(poly_4x, fill=(78, 32, 105, 255))

pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]

# 1. Dark outer midnight shadow bevel (width 5.0px, #260D3A)
for i in range(len(pts_top_4x) - 1):
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(38, 13, 58, 255), width=int(round(4.8 * SCALE)))

# 2. Main radiant glowing purple line (width 3.4px, #A852EC -> #C870FF -> #A852EC)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    cf = math.sin(t * math.pi)
    r = int(168 + 28 * cf)
    g = int(82 + 26 * cf)
    b = int(236 + 19 * cf)
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(r, g, b, 255), width=int(round(3.3 * SCALE)))

# 3. Delicate sunlit specular glint (width 1.2px, #F5E6FF along center 72%)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    if 0.14 <= t <= 0.86:
        gt = (t - 0.14) / 0.72
        alpha = int(245 * (math.sin(gt * math.pi) ** 1.3))
        p0 = pts_top_4x[i]
        p1 = pts_top_4x[i+1]
        dx = p1[0] - p0[0]
        dy = p1[1] - p0[1]
        L = math.hypot(dx, dy)
        if L > 0:
            nx = -dy / L * 1.0 * SCALE
            ny = dx / L * 1.0 * SCALE
            tdraw.line([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny)], fill=(245, 230, 255, alpha), width=int(round(1.2 * SCALE)))

tray_1x = tray_hi.resize((W, H), Image.Resampling.LANCZOS)

# Composite:
# Layer 1: New tray with flawless arch
# Layer 2: Base (contains letters, FEVER, PARTY!, road, stars)
final = Image.alpha_composite(tray_1x, base)
final = final.filter(ImageFilter.UnsharpMask(radius=1.1, percent=120, threshold=1))

final.save('assets/ui/logo/bus_fever_party_logo.png')
final.save('/tmp/masterpiece_v2.png')
print("Saved assets/ui/logo/bus_fever_party_logo.png and /tmp/masterpiece_v2.png!")

# Render on home screen simulation
bg = Image.open('assets/home_bg_retina.jpg').convert('RGBA')
bw, bh = bg.size
scaled = final.resize((int(732 * 0.54), int(664 * 0.54)), Image.Resampling.LANCZOS)
lx = (bw - scaled.size[0]) // 2
ly = 80
bg.alpha_composite(scaled, (lx, ly))

crop = bg.crop((lx - 20, ly - 20, lx + scaled.size[0] + 20, ly + 180))
crop.save('/tmp/masterpiece_v2_screen_crop.png')
print("Saved /tmp/masterpiece_v2_screen_crop.png!")
