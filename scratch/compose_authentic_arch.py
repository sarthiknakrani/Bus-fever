import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

src = Image.open('test_transparent_logo_clean.png').convert('RGBA')
W, H = src.size
SCALE = 4
SW, SH = W * SCALE, H * SCALE

# -------------------------------------------------------------------------
# 1. Base Layer (FEVER, PARTY, Road Ribbon, Orange P)
# -------------------------------------------------------------------------
base = src.copy()
b_pix = base.load()

# Clear everything above y=435 in base
for y in range(0, 435):
    for x in range(W):
        b_pix[x, y] = (0, 0, 0, 0)

# Perfect Orange Recolor on face of P:
# Bounding box of P in src: x in [113, 259], y in [500, 716]
for y in range(500, 716):
    for x in range(113, 259):
        r, g, b, a = b_pix[x, y]
        if a > 40:
            h_val, s_val, v_val = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            h_deg = h_val * 360.0
            # Check for cyan face
            if 165 <= h_deg <= 218 and v_val > 0.45:
                lum = 0.299 * r/255.0 + 0.587 * g/255.0 + 0.114 * b/255.0
                if lum > 0.65:
                    th, ts, tv = 32.0/360.0, 0.90, min(1.0, v_val * 1.05)
                elif lum > 0.40:
                    th, ts, tv = 22.0/360.0, 0.95, v_val
                else:
                    th, ts, tv = 16.0/360.0, 0.98, max(0.5, v_val)
                nr, ng, nb = colorsys.hsv_to_rgb(th, ts, tv)
                b_pix[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)

print("Base with recolored orange P ready.")

# -------------------------------------------------------------------------
# 2. Extract Authentic BUS Letters from src
# -------------------------------------------------------------------------
bus_letters = Image.new('RGBA', (W, H), (0, 0, 0, 0))
bl_pix = bus_letters.load()
s_pix = src.load()

# Copy pristine letter pixels:
# Below y=232, all BUS pixels are 100% pristine:
for y in range(232, 435):
    for x in range(120, 690):
        bl_pix[x, y] = s_pix[x, y]

# For Letter B (x in 130..315):
# B is pristine above y=232 up to y=215, EXCEPT the tire at x in [220..255], y in [215..228]
for y in range(215, 232):
    for x in range(130, 315):
        r, g, b, a = s_pix[x, y]
        if a > 40:
            is_candy = (r > 170 and g > 60 and b < 100) or (r > 190 and g > 110) or (r > 220 and g > 150)
            is_bevel = (r > 120 and g > 35 and b < 65)
            # Tire is dark grey/black:
            is_tire = (r < 75 and g < 75 and b < 75)
            if (is_candy or is_bevel) and not is_tire:
                bl_pix[x, y] = (r, g, b, a)

# For Letter U (x in 335..485):
# Left stem is 100% pristine up to y=215!
for y in range(215, 232):
    for x in range(335, 396):
        r, g, b, a = s_pix[x, y]
        if a > 40:
            is_candy = (r > 170 and g > 60 and b < 100) or (r > 190 and g > 110) or (r > 220 and g > 150)
            is_bevel = (r > 120 and g > 35 and b < 65)
            is_tire = (r < 75 and g < 75 and b < 75)
            if (is_candy or is_bevel) and not is_tire:
                bl_pix[x, y] = (r, g, b, a)

# Right stem of U: Mirror the pristine left stem cap!
# Left stem cap is x in [342, 396], y in [215, 235] (width 54, height 20)
left_u_cap = bus_letters.crop((342, 215, 396, 235))
right_u_cap = left_u_cap.transpose(Image.FLIP_LEFT_RIGHT)
# Right stem is centered at x=444, so x from 417 to 471
bus_letters.alpha_composite(right_u_cap, (417, 215))

# For Letter S (x in 485..680):
# S is pristine up to y=220!
for y in range(218, 232):
    for x in range(485, 680):
        r, g, b, a = s_pix[x, y]
        if a > 40:
            is_candy = (r > 170 and g > 60 and b < 100) or (r > 190 and g > 110) or (r > 220 and g > 150)
            is_bevel = (r > 120 and g > 35 and b < 65)
            is_tire = (r < 75 and g < 75 and b < 75)
            if (is_candy or is_bevel) and not is_tire:
                bl_pix[x, y] = (r, g, b, a)

print("Authentic BUS letters isolated and mirrored.")

# -------------------------------------------------------------------------
# 3. Build Smooth Purple Plaque & Flawless Purple Line
# -------------------------------------------------------------------------
# The purple rim connects seamlessly into the original outer shoulders:
# Left shoulder: (136, 320) up to (150, 240) up to (180, 212)
# Over B: smooth curve peaking at (225, 206)
# Over U: smooth curve peaking at (405, 202)
# Over S: smooth curve peaking at (580, 210)
# Down to right shoulder: (640, 240) down to (665, 320)

# We use a smooth Bezier spline:
spline_ctrls = [
    (136.0, 320.0),
    (142.0, 260.0),
    (156.0, 222.0),
    (180.0, 210.0),
    (220.0, 205.0), # Peak over B
    (290.0, 204.0),
    (360.0, 202.0), # Peak over U left
    (405.0, 201.0), # Crest over U center
    (450.0, 202.0), # Peak over U right
    (520.0, 204.0),
    (580.0, 207.0), # Peak over S
    (625.0, 218.0),
    (650.0, 255.0),
    (665.0, 320.0)
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
    steps = 30
    for s in range(steps):
        t = s / float(steps)
        arch_pts.append(catmull_rom(p0, p1, p2, p3, t))
arch_pts.append(spline_ctrls[-1])

# Draw on 4x supersampled canvas
tray_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

poly_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]
poly_4x.append((665.0 * SCALE, 442.0 * SCALE))
poly_4x.append((136.0 * SCALE, 442.0 * SCALE))

# Rich purple fill
tdraw.polygon(poly_4x, fill=(78, 32, 105, 255))

pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]

# 1. Dark outer midnight bevel (width 5.0px, #260D3A)
for i in range(len(pts_top_4x) - 1):
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(38, 13, 58, 255), width=int(round(4.8 * SCALE)))

# 2. Main radiant glowing purple line (width 3.4px, #A852EC -> #C870FF -> #A852EC)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    cf = math.sin(t * math.pi)
    r = int(168 + 28 * cf)
    g = int(82 + 26 * cf)
    b = int(236 + 19 * cf)
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(r, g, b, 255), width=int(round(3.2 * SCALE)))

# 3. Delicate sunlit specular glint (width 1.2px, #F5E6FF)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    if 0.12 <= t <= 0.88:
        gt = (t - 0.12) / 0.76
        alpha = int(240 * (math.sin(gt * math.pi) ** 1.3))
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
# 1. Tray
# 2. Base (FEVER + PARTY with Orange P + road)
# 3. Clean authentic BUS letters
comp = Image.alpha_composite(tray_1x, base)
comp = Image.alpha_composite(comp, bus_letters)

# Target 732x664
bbox = comp.getbbox()
cr = comp.crop(bbox)
final = Image.new('RGBA', (732, 664), (0, 0, 0, 0))
final.alpha_composite(cr, ((732 - cr.size[0]) // 2, (664 - cr.size[1]) // 2))
final = final.filter(ImageFilter.UnsharpMask(radius=1.1, percent=125, threshold=1))

final.save('/tmp/authentic_arch_logo.png')
print("Successfully generated /tmp/authentic_arch_logo.png!")

# Render on home screen
bg = Image.open('assets/home_bg_retina.jpg').convert('RGBA')
bw, bh = bg.size
scaled = final.resize((int(732 * 0.54), int(664 * 0.54)), Image.Resampling.LANCZOS)
lx = (bw - scaled.size[0]) // 2
ly = 80
bg.alpha_composite(scaled, (lx, ly))

crop = bg.crop((lx - 20, ly - 20, lx + scaled.size[0] + 20, ly + 180))
crop.save('/tmp/authentic_screen_crop.png')
print("Saved /tmp/authentic_screen_crop.png!")
