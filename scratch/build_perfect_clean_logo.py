import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

# 1. Load the trusted base with orange P and navy border
base_6452 = Image.open('/tmp/6452_logo.png').convert('RGBA')
W, H = base_6452.size

SCALE = 4
SW, SH = W * SCALE, H * SCALE

# 2. Extract BUS letters from base_6452
# In base_6452, the candy letters are located at:
# B: x in [148, 275], y in [44, 200]
# U: x in [285, 455], y in [45, 200]
# S: x in [465, 582], y in [44, 200]

# Let's inspect the candy pixels of B, U, S and build a pristine letter layer
letters_only = Image.new('RGBA', (W, H), (0, 0, 0, 0))
l_pix = letters_only.load()
b_pix = base_6452.load()

for y in range(40, 215):
    for x in range(140, 595):
        r, g, b, a = b_pix[x, y]
        if a > 40:
            # Check if this pixel is letter candy (red/orange/gold face/bevel)
            # or letter drop shadow
            h_val, s_val, v_val = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            h_deg = h_val * 360.0
            
            # Candy colors: red/orange/yellow: h_deg < 55 or h_deg > 340, or high saturation/brightness
            is_candy = (r > 165 and g > 50 and b < 120) or (r > 200 and g > 130) or (r > 220 and g > 180 and b > 120)
            is_bevel = (r > 120 and g > 40 and b < 70)
            
            # Exclude purple tray pixels (h_deg in 240..320 with purple tones)
            is_purple_tray = (230 <= h_deg <= 320 and b > r and b > g) or (245 <= h_deg <= 315)
            
            if (is_candy or is_bevel) and not is_purple_tray:
                # Also filter out the flat brown crease cutoffs at y < 48 on U
                if 300 <= x <= 450 and y < 47:
                    continue
                l_pix[x, y] = (r, g, b, a)

# Now, supersample letters 4x and sculpt pristine smooth rounded candy dome tops on U stems!
letters_hi = letters_only.resize((SW, SH), Image.Resampling.LANCZOS)
lh_pix = letters_hi.load()

def sculpt_dome_cap(cx_1x, cy_1x, rx_1x, ry_1x, y_blend_1x):
    cx = cx_1x * SCALE
    cy = cy_1x * SCALE
    rx = rx_1x * SCALE
    ry = ry_1x * SCALE
    y_blend = y_blend_1x * SCALE
    y_top = cy - ry
    
    for y in range(int(y_top - 2), int(y_blend + 2)):
        for x in range(int(cx - rx - 2), int(cx + rx + 3)):
            dx = (x - cx) / float(rx)
            if abs(dx) > 1.0:
                continue
            cur_ytop = cy - ry * math.sqrt(max(0.0, 1.0 - dx * dx))
            dist = y - cur_ytop
            if dist < -1.0:
                continue
            alpha = min(1.0, max(0.0, dist + 1.0))
            bevel = 4.8 * SCALE
            
            if dist < bevel:
                ub = dist / bevel
                if ub < 0.25:
                    rc = int(145 + ub * 4.0 * 110)
                    gc = int(45 + ub * 4.0 * 155)
                    bc = int(25 + ub * 4.0 * 65)
                else:
                    tb = (ub - 0.25) / 0.75
                    rc = int(255)
                    gc = int(200 * (1 - tb) + 160 * tb)
                    bc = int(90 * (1 - tb) + 50 * tb)
            else:
                ny = min(1.0, max(0.0, (y - y_top) / float(ry * 2.2)))
                rc = 255
                gc = int(175 * (1.0 - ny * 0.40))
                bc = int(75 * (1.0 - ny * 0.65))
                
                # Specular gloss highlight
                gdx = (x - (cx - rx * 0.25)) / (rx * 0.50)
                gdy = (y - (cy - ry * 0.65)) / (ry * 0.40)
                d2 = gdx*gdx + gdy*gdy
                if d2 < 1.0:
                    sh = (1.0 - math.sqrt(d2)) ** 1.3 * 0.92
                    rc = int(rc * (1 - sh) + 255 * sh)
                    gc = int(gc * (1 - sh) + 255 * sh)
                    bc = int(bc * (1 - sh) + 255 * sh)
            
            # Blend smoothly into existing letter body
            if y > y_blend - 4 * SCALE:
                wb = (y - (y_blend - 4 * SCALE)) / float(5 * SCALE)
                wb = min(1.0, max(0.0, wb))
                ex = lh_pix[x, y]
                if ex[3] > 40:
                    rc = int(rc * (1 - wb) + ex[0] * wb)
                    gc = int(gc * (1 - wb) + ex[1] * wb)
                    bc = int(bc * (1 - wb) + ex[2] * wb)
            
            lh_pix[x, y] = (rc, gc, bc, int(255 * alpha))

# Sculpt smooth candy domes on U left stem: cx=328, cy=52, rx=18, ry=14
sculpt_dome_cap(328.0, 52.0, 18.0, 14.0, 56.0)
# Sculpt smooth candy domes on U right stem: cx=424, cy=52, rx=19, ry=14
sculpt_dome_cap(424.0, 52.0, 19.0, 14.0, 56.0)

# Also smooth top bevel cap of B: cx=205, cy=46, rx=48, ry=8
sculpt_dome_cap(205.0, 46.0, 48.0, 8.0, 50.0)

letters_sculpted = letters_hi.resize((W, H), Image.Resampling.LANCZOS)
print("Pristine sculpted candy letters ready.")

# 3. BUILD THE FLAWLESS, CONTINUOUS 3D PURPLE CROWN ARCH
# Left shoulder at x=146, y=62
# Apex at x=365, y=22 (giving generous, elegant 16px crown above U domes)
# Right shoulder at x=584, y=62

X_LEFT = 146.0
X_RIGHT = 584.0
X_CENTER = (X_LEFT + X_RIGHT) / 2.0 # 365.0
Y_APEX = 22.0
Y_SHOULDER = 62.0

arch_pts = []
N_PTS = 240
for i in range(N_PTS):
    u = i / float(N_PTS - 1)
    x = X_LEFT + u * (X_RIGHT - X_LEFT)
    theta = u * math.pi
    # Smooth sine arch: apex in center, smooth shoulders
    y = Y_APEX + (Y_SHOULDER - Y_APEX) * (1.0 - math.sin(theta)**0.88)
    arch_pts.append((x, y))

# Draw tray on 4x supersampled canvas
tray_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

poly_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]
poly_4x.append((X_RIGHT * SCALE, 120.0 * SCALE))
poly_4x.append((X_LEFT * SCALE, 120.0 * SCALE))

# Fill with rich royal purple matching the existing badge (#542176 down to #3C1554)
tdraw.polygon(poly_4x, fill=(76, 30, 102, 255))

pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]

# 1. Dark outer midnight shadow bevel (width 5.2px, #260D3A)
for i in range(len(pts_top_4x) - 1):
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(38, 13, 58, 255), width=int(round(5.0 * SCALE)))

# 2. Main radiant glowing purple line (width 3.4px, #9E48E5 -> #C46CFF -> #9E48E5)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    cf = math.sin(t * math.pi)
    r = int(162 + 32 * cf)
    g = int(76 + 28 * cf)
    b = int(232 + 20 * cf)
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(r, g, b, 255), width=int(round(3.4 * SCALE)))

# 3. Sunlit specular glint (width 1.2px, #F5E6FF along center 72%)
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
            nx = -dy / L * 1.1 * SCALE
            ny = dx / L * 1.1 * SCALE
            tdraw.line([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny)], fill=(245, 230, 255, alpha), width=int(round(1.2 * SCALE)))

tray_1x = tray_hi.resize((W, H), Image.Resampling.LANCZOS)
print("Flawless crown arch tray and purple rim line ready.")

# 4. Composite final logo:
# Base with lower half (FEVER, PARTY, road, stars, orange P)
clean_base = base_6452.copy()
cb_pix = clean_base.load()

# Clear entire old top region above y=75 in x in [140, 595]
for y in range(0, 75):
    for x in range(138, 598):
        cb_pix[x, y] = (0, 0, 0, 0)

# Composite order:
# Layer 1: Clean base (lower half)
# Layer 2: Flawless crown arch tray (behind BUS letters)
# Layer 3: Pristine sculpted BUS candy letters (on top of tray)

comp = Image.alpha_composite(clean_base, tray_1x)
comp = Image.alpha_composite(comp, letters_sculpted)

# Unsharp mask for crisp retina clarity
final = comp.filter(ImageFilter.UnsharpMask(radius=1.1, percent=120, threshold=1))

final.save('assets/ui/logo/bus_fever_party_logo.png')
final.save('/tmp/perfect_flawless_logo.png')
print("Successfully saved assets/ui/logo/bus_fever_party_logo.png!")

# Verify pixel checks
img_check = final.load()
print("Pixel at (140, 420):", img_check[140, 420])
print("Pixel at (84, 470):", img_check[84, 470])
