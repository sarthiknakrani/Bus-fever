import math
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/6452_logo.png').convert('RGBA')
W, H = base.size
SCALE = 4
SW, SH = W * SCALE, H * SCALE

# 1. Mirror pristine left U stem onto right U stem
left_stem = base.crop((306, 46, 352, 86))
right_stem = left_stem.transpose(Image.FLIP_LEFT_RIGHT).convert('RGBA')
base.alpha_composite(right_stem, (404, 46))

# 2. Extract BUS candy letters with 100% purity (only red/orange face and golden bevel)
b_pix = base.load()
bus_candy = Image.new('RGBA', (W, H), (0, 0, 0, 0))
bc_pix = bus_candy.load()

clean_base = base.copy()
cb_pix = clean_base.load()

# Erase ALL pixels in BUS zone y in [0, 202] in clean_base
for y in range(0, 203):
    for x in range(120, 610):
        cb_pix[x, y] = (0, 0, 0, 0)

# Extract pristine candy
for y in range(45, 218):
    for x in range(145, 590):
        r, g, b, a = b_pix[x, y]
        if a > 40:
            is_candy = (r > 150 and r > b + 35) or (r > 200 and g > 140 and b < 100)
            is_purple = (b > r + 10) or (b > 100 and r < 100)
            if is_candy and not is_purple:
                bc_pix[x, y] = (r, g, b, a)

# Precision contour spline control points for BUS:
ctrls = [
    # B left shoulder: curves smoothly into FEVER junction at y=200
    (146.0, 200.0),
    (146.0, 160.0),
    (145.0, 120.0),
    (146.0, 85.0),
    (148.0, 65.0),
    (152.0, 50.0),
    (164.0, 38.0),
    (185.0, 32.5),
    (215.0, 30.5),
    (245.0, 31.5),
    (265.0, 38.0),
    (278.0, 56.0),
    # Dip between B and U
    (288.0, 82.0),
    (294.0, 95.0),
    (300.0, 82.0),
    # Left stem of U
    (308.0, 56.0),
    (316.0, 38.0),
    (330.0, 32.5),
    (346.0, 38.0),
    (354.0, 56.0),
    # Deep Canyon inside U (curving down along inner walls)
    (364.0, 95.0),
    (372.0, 134.0),
    (380.0, 142.0),
    (388.0, 134.0),
    (396.0, 95.0),
    # Right stem of U
    (406.0, 56.0),
    (414.0, 38.0),
    (428.0, 32.5),
    (444.0, 38.0),
    (452.0, 56.0),
    # Dip between U and S
    (460.0, 78.0),
    (465.0, 90.0),
    (470.0, 78.0),
    # Letter S
    (476.0, 56.0),
    (488.0, 38.0),
    (515.0, 31.0),
    (545.0, 31.5),
    (568.0, 38.0),
    (578.0, 50.0),
    (583.0, 65.0),
    (586.0, 85.0),
    (585.0, 120.0),
    (580.0, 160.0),
    (574.0, 200.0)
]

def catmull_rom(p0, p1, p2, p3, t):
    t2 = t * t
    t3 = t2 * t
    x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
    y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
    return (x, y)

curve_pts = []
for i in range(len(ctrls) - 1):
    p0 = ctrls[max(0, i - 1)]
    p1 = ctrls[i]
    p2 = ctrls[i + 1]
    p3 = ctrls[min(len(ctrls) - 1, i + 2)]
    steps = 30
    for s in range(steps):
        t = s / float(steps)
        curve_pts.append(catmull_rom(p0, p1, p2, p3, t))
curve_pts.append(ctrls[-1])

# Supersampled canvas for unified royal navy border
border_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
bdraw = ImageDraw.Draw(border_hi)

poly_4x = [(x * SCALE, y * SCALE) for (x, y) in curve_pts]
poly_4x.append((574.0 * SCALE, 203.0 * SCALE))
poly_4x.append((146.0 * SCALE, 203.0 * SCALE))

# Fill with authoritative royal navy matching FEVER and PARTY (#1D317B)
bdraw.polygon(poly_4x, fill=(29, 49, 123, 255))

pts_4x = [(x * SCALE, y * SCALE) for (x, y) in curve_pts]

# 1. Dark outer midnight shadow bevel (width 4.8px in 4x, #0E1532)
for i in range(len(pts_4x) - 1):
    bdraw.line([pts_4x[i], pts_4x[i+1]], fill=(14, 21, 50, 255), width=int(round(4.8 * SCALE)))

# 2. Main vibrant royal blue stroke (width 3.4px in 4x, #2A48A8)
for i in range(len(pts_4x) - 1):
    bdraw.line([pts_4x[i], pts_4x[i+1]], fill=(42, 72, 168, 255), width=int(round(3.3 * SCALE)))

# 3. Sunlit specular rim glint (width 1.2px in 4x, #D8EAFF along top dome lobes)
for i in range(len(pts_4x) - 1):
    t = i / float(len(pts_4x) - 1)
    is_dome = (0.08 <= t <= 0.22) or (0.30 <= t <= 0.39) or (0.59 <= t <= 0.68) or (0.77 <= t <= 0.90)
    if is_dome:
        p0 = pts_4x[i]
        p1 = pts_4x[i+1]
        dx = p1[0] - p0[0]
        dy = p1[1] - p0[1]
        L = math.hypot(dx, dy)
        if L > 0:
            nx = -dy / L * 1.0 * SCALE
            ny = dx / L * 1.0 * SCALE
            bdraw.line([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny)], fill=(225, 238, 255, 240), width=int(round(1.2 * SCALE)))

border_1x = border_hi.resize((W, H), Image.Resampling.LANCZOS)

# Composite layers:
stage1 = Image.alpha_composite(clean_base, border_1x)
final = Image.alpha_composite(stage1, bus_candy)

final.save('/tmp/perfect_sculpted_logo.png')
print('Saved /tmp/perfect_sculpted_logo.png!')

# Render on home screen simulation
bg = Image.open('assets/home_bg_retina.jpg').convert('RGBA')
bw, bh = bg.size
scaled = final.resize((int(732 * 0.54), int(664 * 0.54)), Image.Resampling.LANCZOS)
lx = (bw - scaled.size[0]) // 2
ly = 80
bg.alpha_composite(scaled, (lx, ly))

crop = bg.crop((lx - 20, ly - 20, lx + scaled.size[0] + 20, ly + 220))
crop.save('/tmp/perfect_sculpted_screen_crop.png')
print('Saved /tmp/perfect_sculpted_screen_crop.png!')
