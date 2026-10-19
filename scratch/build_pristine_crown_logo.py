import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/6452_logo.png').convert('RGBA')
W, H = base.size
SCALE = 4
SW, SH = W * SCALE, H * SCALE

b_pix = base.load()

# -------------------------------------------------------------------------
# Step 1: Clean Letter Tops & Bevels (Zero glitches, zero tire debris)
# -------------------------------------------------------------------------

# 1a. Surgical cleanup of Letter B's top bevel (x in 180..270, y in 44..50):
# Replace any tire shadow / indigo / corrupted pixels with the pristine golden bevel & candy face
for y in range(43, 50):
    for x in range(180, 270):
        r, g, b, a = b_pix[x, y]
        # Any pixel with high blue (indigo artifact) or dark tire shadow
        is_glitch = (b > 130 and r < 140) or (r < 75 and g < 75) or (b > r + 20)
        if is_glitch:
            # Distance from top edge of B
            if y <= 46:
                # Top golden bevel: (255, 225, 95)
                b_pix[x, y] = (255, 225, 95, 255)
            elif y == 47:
                # Bevel transition: (255, 195, 80)
                b_pix[x, y] = (255, 195, 80, 255)
            else:
                # Candy face: (255, 160, 65)
                b_pix[x, y] = (255, 160, 65, 255)

# 1b. Surgical cleanup of Letter S's top bevel (x in 480..565, y in 43..49):
for y in range(43, 49):
    for x in range(480, 565):
        r, g, b, a = b_pix[x, y]
        is_glitch = (b > 130 and r < 140) or (r < 75 and g < 75) or (b > r + 20)
        if is_glitch:
            if y <= 45:
                b_pix[x, y] = (255, 225, 95, 255)
            else:
                b_pix[x, y] = (255, 185, 75, 255)

# 1c. Perfect mirror of Left U Stem onto Right U Stem:
# Left stem: [300, 365], width 65. Right stem: [390, 455], width 65.
# Crop y in [44, 82]
left_cap = base.crop((300, 44, 365, 82))
right_cap = left_cap.transpose(Image.FLIP_LEFT_RIGHT).convert('RGBA')
rc_pix = right_cap.load()
cw, ch = right_cap.size

for y in range(ch - 10, ch):
    alpha_mul = (ch - 1 - y) / 10.0
    for x in range(cw):
        r, g, b, a = rc_pix[x, y]
        ex_r, ex_g, ex_b, ex_a = b_pix[390 + x, 44 + y]
        nr = int(r * alpha_mul + ex_r * (1.0 - alpha_mul))
        ng = int(g * alpha_mul + ex_g * (1.0 - alpha_mul))
        nb = int(b * alpha_mul + ex_b * (1.0 - alpha_mul))
        na = int(a * alpha_mul + ex_a * (1.0 - alpha_mul))
        rc_pix[x, y] = (nr, ng, nb, na)

base.alpha_composite(right_cap, (390, 44))
b_pix = base.load()

# -------------------------------------------------------------------------
# Step 2: Unconditionally Erase Old Wavy Purple Tray & Line above y=44
# -------------------------------------------------------------------------
for y in range(0, 45):
    for x in range(140, 592):
        b_pix[x, y] = (0, 0, 0, 0)

# -------------------------------------------------------------------------
# Step 3: Draw Flawless 3D Purple Crown Arch with Seamless Shoulder Blends
# -------------------------------------------------------------------------
# Spline control points that smoothly flow into the original plaque shoulders:
# Left shoulder: (144, 75) -> (146, 56) -> (156, 40) -> (175, 30)
# Apex: (365, 23)
# Right shoulder: (555, 30) -> (574, 40) -> (584, 56) -> (586, 75)

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
# 1. New tray with flawless arch
# 2. Base (contains letters, FEVER, PARTY!, road, stars)
final = Image.alpha_composite(tray_1x, base)
final = final.filter(ImageFilter.UnsharpMask(radius=1.1, percent=120, threshold=1))

final.save('assets/ui/logo/bus_fever_party_logo.png')
final.save('/tmp/pristine_crown_logo.png')
print("Successfully saved assets/ui/logo/bus_fever_party_logo.png!")

# Render on home screen
bg = Image.open('assets/home_bg_retina.jpg').convert('RGBA')
bw, bh = bg.size
scaled = final.resize((int(732 * 0.54), int(664 * 0.54)), Image.Resampling.LANCZOS)
lx = (bw - scaled.size[0]) // 2
ly = 80
bg.alpha_composite(scaled, (lx, ly))

crop = bg.crop((lx - 20, ly - 20, lx + scaled.size[0] + 20, ly + 180))
crop.save('/tmp/pristine_screen_crop.png')
print("Saved /tmp/pristine_screen_crop.png!")
