import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/6452_logo.png').convert('RGBA')
W, H = base.size

SCALE = 4
SW, SH = W * SCALE, H * SCALE

b_pix = base.load()

# -------------------------------------------------------------------------
# Step 1: Clean the letters B, U, S in base
# -------------------------------------------------------------------------
# 1a. Clean the black/blue scratches on B (x in 190..260, y in 42..47)
for y in range(40, 48):
    for x in range(180, 260):
        r, g, b, a = b_pix[x, y]
        # Dark scratches: r < 120 and (b > 120 or (r < 60 and g < 60))
        if a > 40 and (b > r + 30 or (r < 70 and g < 70)):
            # Golden bevel color: (255, 215, 80)
            b_pix[x, y] = (255, 215, 80, 255)

# 1b. Clean the black/blue scratches on S (x in 490..560, y in 40..47)
for y in range(40, 48):
    for x in range(490, 560):
        r, g, b, a = b_pix[x, y]
        if a > 40 and (b > r + 30 or (r < 70 and g < 70)):
            b_pix[x, y] = (255, 215, 80, 255)

# 1c. Replace right stem of U with mirrored pristine left stem of U:
# In base, left stem is x in [306, 350], y in [45, 95] (width 44, height 50)
# Right stem is x in [400, 446], y in [45, 95] (width 46, height 50)
left_stem_cap = base.crop((306, 45, 350, 95))
right_stem_cap = left_stem_cap.transpose(Image.FLIP_LEFT_RIGHT)
# Alpha composite smoothly on right stem at (402, 45)
base.alpha_composite(right_stem_cap, (402, 45))
b_pix = base.load()

print("Letters B, U, S cleaned and right stem mirrored.")

# -------------------------------------------------------------------------
# Step 2: Clear the old lumpy purple tray above y=44
# -------------------------------------------------------------------------
# Erase old wavy purple pixels and line in x in [142, 588], y in [0, 45]
for y in range(0, 46):
    for x in range(142, 588):
        r, g, b, a = b_pix[x, y]
        # Keep candy letter pixels if any exist at y=44..45
        is_candy = (r > 200 and g > 120 and b < 100) or (r > 230 and g > 180)
        if not is_candy:
            b_pix[x, y] = (0, 0, 0, 0)

# -------------------------------------------------------------------------
# Step 3: Draw the Flawless 3D Purple Crown Arch
# -------------------------------------------------------------------------
# Smooth convex curve spanning from x=146 to x=584
# Left shoulder: (146, 56)
# Apex: (365, 23)
# Right shoulder: (584, 56)

X_LEFT = 146.0
X_RIGHT = 584.0
Y_APEX = 23.0
Y_SHOULDER = 56.0

arch_pts = []
N_PTS = 240
for i in range(N_PTS):
    u = i / float(N_PTS - 1)
    x = X_LEFT + u * (X_RIGHT - X_LEFT)
    theta = u * math.pi
    # Gentle, perfectly rounded convex curve
    y = Y_APEX + (Y_SHOULDER - Y_APEX) * (1.0 - math.sin(theta)**0.86)
    arch_pts.append((x, y))

# Draw tray on 4x canvas
tray_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

poly_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]
poly_4x.append((X_RIGHT * SCALE, 60.0 * SCALE))
poly_4x.append((X_LEFT * SCALE, 60.0 * SCALE))

# Fill with rich royal purple matching the existing badge (#502170 down to #3C1554)
tdraw.polygon(poly_4x, fill=(78, 32, 105, 255))

pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]

# 1. Dark outer midnight shadow bevel (width 5.0px, #260D3A)
for i in range(len(pts_top_4x) - 1):
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(38, 13, 58, 255), width=int(round(5.0 * SCALE)))

# 2. Main radiant glowing purple line (width 3.4px, #9E48E5 -> #C870FF -> #9E48E5)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    cf = math.sin(t * math.pi)
    r = int(166 + 30 * cf)
    g = int(80 + 28 * cf)
    b = int(235 + 20 * cf)
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
# Place the new crown tray BEHIND the letters, but IN FRONT of transparent background
# Layer 1: tray_1x
# Layer 2: base (contains letters, FEVER, PARTY!, road, stars)
final = Image.alpha_composite(tray_1x, base)

final = final.filter(ImageFilter.UnsharpMask(radius=1.1, percent=120, threshold=1))
final.save('/tmp/masterpiece_logo.png')
final.save('assets/ui/logo/bus_fever_party_logo.png')
print("Saved assets/ui/logo/bus_fever_party_logo.png and /tmp/masterpiece_logo.png!")

# Render on home screen
bg = Image.open('assets/home_bg_retina.jpg').convert('RGBA')
bw, bh = bg.size
scaled = final.resize((int(732 * 0.54), int(664 * 0.54)), Image.Resampling.LANCZOS)
lx = (bw - scaled.size[0]) // 2
ly = 80
bg.alpha_composite(scaled, (lx, ly))

crop = bg.crop((lx - 20, ly - 20, lx + scaled.size[0] + 20, ly + 180))
crop.save('/tmp/masterpiece_screen_crop.png')
print("Saved /tmp/masterpiece_screen_crop.png!")
