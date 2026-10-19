import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

src = Image.open('test_transparent_logo_clean.png').convert('RGBA')
W, H = src.size

SCALE = 4
SW, SH = W * SCALE, H * SCALE

# -------------------------------------------------------------------------
# 1. Base Layer (FEVER, PARTY, Road Ribbon) below y=435 with Orange P
# -------------------------------------------------------------------------
clean_base = src.copy()
cb_pix = clean_base.load()
for y in range(0, 435):
    for x in range(W):
        cb_pix[x, y] = (0, 0, 0, 0)

# Orange recolor on face of P
for y in range(650, H):
    for x in range(200, 360):
        r, g, b, a = cb_pix[x, y]
        if a > 40:
            h_val, s_val, v_val = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            if 170 <= h_val * 360 <= 225 and v_val > 0.45:
                lum = 0.299 * r/255.0 + 0.587 * g/255.0 + 0.114 * b/255.0
                if lum > 0.65:
                    th, ts, tv = 32.0/360.0, 0.90, min(1.0, v_val * 1.05)
                elif lum > 0.40:
                    th, ts, tv = 22.0/360.0, 0.95, v_val
                else:
                    th, ts, tv = 16.0/360.0, 0.98, max(0.5, v_val)
                nr, ng, nb = colorsys.hsv_to_rgb(th, ts, tv)
                cb_pix[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)

print("Base FEVER + PARTY with Orange P prepared.")

# -------------------------------------------------------------------------
# 2. Extract TRUE Pristine BUS Letters (Strictly below y=227, zero bus pixels)
# -------------------------------------------------------------------------
bus_clean = Image.new('RGBA', (W, H), (0, 0, 0, 0))
bc_pix = bus_clean.load()
src_pix = src.load()

# Copy pristine original pixels below y=227
for y in range(227, 435):
    for x in range(120, 690):
        r, g, b, a = src_pix[x, y]
        # Skip tire shadow if any at y=227..235
        if y < 236 and (r < 60 and g < 60 and b < 60):
            continue
        bc_pix[x, y] = (r, g, b, a)

# Also copy left-most spine of B at y=220..226 (x in 135..155)
for y in range(220, 227):
    for x in range(135, 155):
        bc_pix[x, y] = src_pix[x, y]

# Supersample 4x to sculpt smooth tops of B, U, and S
bus_hi = bus_clean.resize((SW, SH), Image.Resampling.LANCZOS)
bpix_hi = bus_hi.load()

def draw_candy_cap(cx_1x, cy_1x, rx_1x, ry_1x, y_blend_1x):
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
            bevel = 5.4 * SCALE
            
            if dist < bevel:
                ub = dist / bevel
                if ub < 0.22:
                    rc = int(140 + ub * 4.5 * 115)
                    gc = int(40 + ub * 4.5 * 160)
                    bc = int(25 + ub * 4.5 * 65)
                else:
                    tb = (ub - 0.22) / 0.78
                    rc = int(255 * (1 - tb) + 255 * tb)
                    gc = int(218 * (1 - tb) + 165 * tb)
                    bc = int(105 * (1 - tb) + 55 * tb)
            else:
                ny = min(1.0, max(0.0, (y - y_top) / float(ry * 2.5)))
                rc = 255
                gc = int(176 * (1.0 - ny * 0.42))
                bc = int(80 * (1.0 - ny * 0.65))
                
                # Specular gloss
                gdx = (x - (cx - rx * 0.28)) / (rx * 0.50)
                gdy = (y - (cy - ry * 0.68)) / (ry * 0.40)
                d2 = gdx*gdx + gdy*gdy
                if d2 < 1.0:
                    sh = (1.0 - math.sqrt(d2)) ** 1.3 * 0.95
                    rc = int(rc * (1 - sh) + 255 * sh)
                    gc = int(gc * (1 - sh) + 255 * sh)
                    bc = int(bc * (1 - sh) + 255 * sh)
            
            # Blend smoothly into existing letter
            if y > y_blend - 5 * SCALE:
                wb = (y - (y_blend - 5 * SCALE)) / float(7 * SCALE)
                wb = min(1.0, max(0.0, wb))
                ex = bpix_hi[x, y]
                if ex[3] > 40:
                    rc = int(rc * (1 - wb) + ex[0] * wb)
                    gc = int(gc * (1 - wb) + ex[1] * wb)
                    bc = int(bc * (1 - wb) + ex[2] * wb)
            
            bpix_hi[x, y] = (rc, gc, bc, int(255 * alpha))

# 1. Sculpt top bar of B:
# B left spine top corner: cx=150, cy=227, rx=14, ry=9
draw_candy_cap(150.0, 227.0, 14.0, 9.0, 230.0)
# B top bar dome: cx=220, cy=232, rx=72, ry=11
draw_candy_cap(220.0, 232.0, 72.0, 11.0, 236.0)
# B top right shoulder: cx=290, cy=234, rx=24, ry=11
draw_candy_cap(290.0, 234.0, 24.0, 11.0, 238.0)

# 2. Sculpt U domes:
# U left stem dome: cx=371, cy=245, rx=20.5, ry=19.5
draw_candy_cap(371.0, 245.0, 20.5, 19.5, 252.0)
# U right stem dome: cx=451, cy=245, rx=24.5, ry=20.5
draw_candy_cap(451.0, 245.0, 24.5, 20.5, 252.0)

# 3. Sculpt top of S:
# S top hook dome: cx=546, cy=233, rx=35, ry=11
draw_candy_cap(546.0, 233.0, 35.0, 11.0, 238.0)
# S top right curve: cx=585, cy=236, rx=28, ry=12
draw_candy_cap(585.0, 236.0, 28.0, 12.0, 240.0)

clean_bus_letters = bus_hi.resize((W, H), Image.Resampling.LANCZOS)
clean_bus_letters.save('/tmp/clean_sculpted_bus.png')
print("Clean sculpted letters saved.")

# -------------------------------------------------------------------------
# 3. BUILD THE PERFECT CROWN ARCH PURPLE TRAY & PURPLE RIM LINE
# -------------------------------------------------------------------------
# Smooth mathematical Crown Arch across the top of BUS:
# Left connection at (136, 340)
# Curves up smoothly over B: apex of B curve at (220, 210)
# Spans majestically across center (U): apex at (395, 202)
# Curves smoothly over S: apex of S curve at (570, 208)
# Curves down to right connection at (674, 340)

arch_pts_1x = []
# 1. Left curve (shoulder of B): x in 136..220
for i in range(40):
    t = i / 39.0
    x = 136.0 + t * (220.0 - 136.0)
    y = 340.0 * (1 - t)**2 + 230.0 * 2 * (1 - t) * t + 210.0 * t**2
    arch_pts_1x.append((x, y))

# 2. Main Crown Arch across B, U, S: x in 220..570
for i in range(140):
    t = i / 139.0
    x = 220.0 + t * (570.0 - 220.0)
    # Quadratic arch with peak at y=202 (giving generous 26px padding above U domes)
    p0 = 210.0
    pm = 202.0
    p1 = 208.0
    y = (1 - t)**2 * p0 + 2 * (1 - t) * t * pm + t**2 * p1
    arch_pts_1x.append((x, y))

# 3. Right curve (shoulder of S): x in 570..674
for i in range(40):
    t = i / 39.0
    x = 570.0 + t * (674.0 - 570.0)
    y = 208.0 * (1 - t)**2 + 230.0 * 2 * (1 - t) * t + 340.0 * t**2
    arch_pts_1x.append((x, y))

tray_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

poly_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts_1x]
poly_4x.append((674.0 * SCALE, 442.0 * SCALE))
poly_4x.append((136.0 * SCALE, 442.0 * SCALE))

# Fill with rich royal purple (#562378 down to #3C1554)
tdraw.polygon(poly_4x, fill=(86, 35, 120, 255))

# Draw the 3D PURPLE RIM LINE:
pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts_1x]

# 1. Outer Dark Midnight Bevel (width 5.5px, #260D3A)
for i in range(len(pts_top_4x) - 1):
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(38, 14, 55, 255), width=int(round(5.5 * SCALE)))

# 2. Main Radiant Glossy Purple Line (width 3.6px, #9E48E5 -> #BD64F8 -> #9E48E5)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    cf = math.sin(t * math.pi)
    r = int(160 + 32 * cf)
    g = int(74 + 30 * cf)
    b = int(230 + 18 * cf)
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(r, g, b, 255), width=int(round(3.6 * SCALE)))

# 3. Sunlit Specular Glint (width 1.4px, #F4E2FF along center 70%)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    if 0.15 <= t <= 0.85:
        gt = (t - 0.15) / 0.70
        alpha = int(245 * math.sin(gt * math.pi) ** 1.3)
        p0 = pts_top_4x[i]
        p1 = pts_top_4x[i+1]
        dx = p1[0] - p0[0]
        dy = p1[1] - p0[1]
        L = math.hypot(dx, dy)
        if L > 0:
            nx = -dy / L * 1.2 * SCALE
            ny = dx / L * 1.2 * SCALE
            tdraw.line([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny)], fill=(244, 226, 255, alpha), width=int(round(1.4 * SCALE)))

# Downscale to 1x and composite
tray_opt = tray_hi.resize((W, H), Image.Resampling.LANCZOS)
comp = Image.alpha_composite(tray_opt, clean_base)
comp = Image.alpha_composite(comp, clean_bus_letters)

# Standard target 732x664
bbox = comp.getbbox()
cr = comp.crop(bbox)
final_logo = Image.new('RGBA', (732, 664), (0, 0, 0, 0))
final_logo.alpha_composite(cr, ((732 - cr.size[0]) // 2, (664 - cr.size[1]) // 2))
final_logo = final_logo.filter(ImageFilter.UnsharpMask(radius=1.1, percent=125, threshold=1))
final_logo.save('assets/ui/logo/bus_fever_party_logo.png')
final_logo.save('/tmp/flawless_purple_arch_logo.png')
print("Successfully generated assets/ui/logo/bus_fever_party_logo.png!")
