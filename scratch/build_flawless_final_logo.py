import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/6452_logo.png').convert('RGBA')
W, H = base.size
SCALE = 4
SW, SH = W * SCALE, H * SCALE

b_pix = base.load()

# -------------------------------------------------------------------------
# Step 1: Clean Letter Tops on B, U, S in base
# -------------------------------------------------------------------------
# 1a. Clean the dark scratches on golden bevel of B (y in 42..47, x in 180..260)
for y in range(41, 48):
    for x in range(175, 265):
        r, g, b, a = b_pix[x, y]
        if a > 40 and (b > r + 25 or (r < 75 and g < 75)):
            b_pix[x, y] = (255, 216, 82, 255)

# 1b. Clean the dark scratches on golden bevel of S (y in 41..48, x in 490..565)
for y in range(41, 48):
    for x in range(485, 565):
        r, g, b, a = b_pix[x, y]
        if a > 40 and (b > r + 25 or (r < 75 and g < 75)):
            b_pix[x, y] = (255, 216, 82, 255)

# 1c. Seamlessly mirror the pristine left stem of U onto the right stem:
# Left stem is [300, 365], width 65. Right stem is [390, 455], width 65.
# Crop y in [44, 84] (height 40)
left_cap = base.crop((300, 44, 365, 84))
right_cap = left_cap.transpose(Image.FLIP_LEFT_RIGHT).convert('RGBA')
rc_pix = right_cap.load()
cw, ch = right_cap.size

# Smooth alpha fade on the bottom 10 rows of the cap for a 100% seamless blend
for y in range(ch - 10, ch):
    alpha_mul = (ch - 1 - y) / 10.0
    for x in range(cw):
        r, g, b, a = rc_pix[x, y]
        # Blend with existing pixel on right stem
        ex_r, ex_g, ex_b, ex_a = b_pix[390 + x, 44 + y]
        nr = int(r * alpha_mul + ex_r * (1.0 - alpha_mul))
        ng = int(g * alpha_mul + ex_g * (1.0 - alpha_mul))
        nb = int(b * alpha_mul + ex_b * (1.0 - alpha_mul))
        na = int(a * alpha_mul + ex_a * (1.0 - alpha_mul))
        rc_pix[x, y] = (nr, ng, nb, na)

base.alpha_composite(right_cap, (390, 44))
b_pix = base.load()
print("Letters B, U, S bevels and right stem restored to 100% perfection.")

# -------------------------------------------------------------------------
# Step 2: Unconditionally Erase Old Wavy Purple Tray & Line above y=44
# -------------------------------------------------------------------------
# This erases ALL pixels (including the old wavy white line) above y=44
for y in range(0, 45):
    for x in range(140, 592):
        b_pix[x, y] = (0, 0, 0, 0)

print("Old wavy caterpillar line and artifacts completely eliminated.")

# -------------------------------------------------------------------------
# Step 3: Draw Flawless 3D Purple Crown Arch
# -------------------------------------------------------------------------
X_LEFT = 144.0
X_RIGHT = 586.0
Y_APEX = 24.0
Y_SHOULDER = 58.0

arch_pts = []
N_PTS = 260
for i in range(N_PTS):
    u = i / float(N_PTS - 1)
    x = X_LEFT + u * (X_RIGHT - X_LEFT)
    theta = u * math.pi
    y = Y_APEX + (Y_SHOULDER - Y_APEX) * (1.0 - math.sin(theta)**0.88)
    arch_pts.append((x, y))

# Draw tray on 4x supersampled canvas
tray_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

poly_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]
poly_4x.append((X_RIGHT * SCALE, 65.0 * SCALE))
poly_4x.append((X_LEFT * SCALE, 65.0 * SCALE))

# Fill with rich royal purple matching the existing badge (#4E2069)
tdraw.polygon(poly_4x, fill=(78, 32, 105, 255))

pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]

# 1. Dark outer midnight shadow bevel (width 5.2px, #260D3A)
for i in range(len(pts_top_4x) - 1):
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(38, 13, 58, 255), width=int(round(5.0 * SCALE)))

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

# Composite tray BEHIND the letters
final = Image.alpha_composite(tray_1x, base)

final = final.filter(ImageFilter.UnsharpMask(radius=1.1, percent=120, threshold=1))
final.save('assets/ui/logo/bus_fever_party_logo.png')
final.save('/tmp/flawless_final_logo.png')
print("Successfully generated assets/ui/logo/bus_fever_party_logo.png!")

# Render on home screen simulation
bg = Image.open('assets/home_bg_retina.jpg').convert('RGBA')
bw, bh = bg.size
scaled = final.resize((int(732 * 0.54), int(664 * 0.54)), Image.Resampling.LANCZOS)
lx = (bw - scaled.size[0]) // 2
ly = 80
bg.alpha_composite(scaled, (lx, ly))

crop = bg.crop((lx - 20, ly - 20, lx + scaled.size[0] + 20, ly + 180))
crop.save('/tmp/flawless_screen_crop.png')
print("Saved /tmp/flawless_screen_crop.png!")
