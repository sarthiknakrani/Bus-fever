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

# -------------------------------------------------------------------------
# 2. Extract TRUE Pristine BUS Letters (Zero bus pixels, perfectly clean)
# -------------------------------------------------------------------------
bus_clean = Image.new('RGBA', (W, H), (0, 0, 0, 0))
bc_pix = bus_clean.load()
src_pix = src.load()

# Copy pristine original pixels below y=232
for y in range(232, 435):
    for x in range(120, 690):
        r, g, b, a = src_pix[x, y]
        bc_pix[x, y] = (r, g, b, a)

# Copy pristine letter B pixels above y=232 (x in 130..315, y in 220..232)
# Only copy warm candy red/orange/gold pixels (no grey tires, no yellow roof)
for y in range(218, 232):
    for x in range(130, 315):
        r, g, b, a = src_pix[x, y]
        if a > 40:
            is_candy = (r > 170 and g < 140 and b < 80) or (r > 190 and g > 120 and b < 90) or (r > 220 and g > 180 and b > 130)
            is_dark_bevel = (r > 130 and g > 50 and b < 60)
            if is_candy or is_dark_bevel:
                bc_pix[x, y] = (r, g, b, a)

# Copy pristine letter S pixels above y=232 (x in 490..680, y in 220..232)
for y in range(220, 232):
    for x in range(490, 680):
        r, g, b, a = src_pix[x, y]
        if a > 40:
            is_candy = (r > 170 and g < 140 and b < 75) or (r > 190 and g > 120 and b < 90) or (r > 220 and g > 180 and b > 130)
            is_dark_bevel = (r > 130 and g > 50 and b < 60)
            if is_candy or is_dark_bevel:
                bc_pix[x, y] = (r, g, b, a)

# Scale up 4x for surgical dome sculpting on U stems
bus_hi = bus_clean.resize((SW, SH), Image.Resampling.LANCZOS)
bpix_hi = bus_hi.load()

def sculpt_dome(cx_1x, cy_1x, rx_1x, ry_1x, y_blend_1x):
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
            
            if y > y_blend - 4 * SCALE:
                wb = (y - (y_blend - 4 * SCALE)) / float(5 * SCALE)
                wb = min(1.0, max(0.0, wb))
                ex = bpix_hi[x, y]
                if ex[3] > 40:
                    rc = int(rc * (1 - wb) + ex[0] * wb)
                    gc = int(gc * (1 - wb) + ex[1] * wb)
                    bc = int(bc * (1 - wb) + ex[2] * wb)
            
            bpix_hi[x, y] = (rc, gc, bc, int(255 * alpha))

# Sculpt U left dome (cx=371, cy=245, rx=20.5, ry=19.0)
sculpt_dome(371.0, 245.0, 20.5, 19.0, 250.0)
# Sculpt U right dome (cx=451, cy=245, rx=24.5, ry=20.0)
sculpt_dome(451.0, 245.0, 24.5, 20.0, 250.0)

clean_bus_letters = bus_hi.resize((W, H), Image.Resampling.LANCZOS)
print("Pristine sculpted candy letters ready.")

# -------------------------------------------------------------------------
# 3. BUILD THE FLAWLESS, SYMMETRICAL 3D PURPLE CROWN ARCH
# -------------------------------------------------------------------------
# We construct a single, unbroken, mathematically pure C^2 continuous curve:
# Parameter t in [0, 1] maps the entire top perimeter from left shoulder to right shoulder.

arch_points = []
NUM_PTS = 300

# Geometry parameters
X_START = 138.0
X_END = 672.0
X_CENTER = (X_START + X_END) / 2.0 # 405.0
W_SPAN = X_END - X_START # 534.0

Y_APEX = 196.0 # Majestic apex 24px above U domes
Y_SHOULDER = 214.0 # Height at B/S shoulders
Y_BOTTOM = 360.0 # Height where tray joins FEVER sides

# Shoulder blend x-coordinates
X_L_SHOULDER = 215.0
X_R_SHOULDER = 595.0

# 1. Left descending shoulder (x: 138 -> 215)
# Smooth S-curve (Hermite / Bezier)
for i in range(60):
    u = i / 59.0
    # Ease in-out
    su = 3 * u**2 - 2 * u**3
    x = X_START + u * (X_L_SHOULDER - X_START)
    y = Y_BOTTOM * (1.0 - su) + Y_SHOULDER * su
    arch_points.append((x, y))

# 2. Main Crown Arch (x: 215 -> 595)
# Pure parabolic crown: apex at X_CENTER = 405, Y_APEX = 196
for i in range(180):
    u = i / 179.0
    x = X_L_SHOULDER + u * (X_R_SHOULDER - X_L_SHOULDER)
    # Normalized position from center (-1 to +1)
    norm_x = (x - X_CENTER) / (X_R_SHOULDER - X_CENTER)
    # Parabolic rise
    y = Y_APEX + (Y_SHOULDER - Y_APEX) * (norm_x ** 2)
    arch_points.append((x, y))

# 3. Right descending shoulder (x: 595 -> 672)
for i in range(60):
    u = i / 59.0
    su = 3 * u**2 - 2 * u**3
    x = X_R_SHOULDER + u * (X_END - X_R_SHOULDER)
    y = Y_SHOULDER * (1.0 - su) + Y_BOTTOM * su
    arch_points.append((x, y))

print(f"Flawless arch points generated: {len(arch_points)} points.")

# Draw Tray on 4x canvas
tray_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

poly_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_points]
poly_4x.append((X_END * SCALE, 442.0 * SCALE))
poly_4x.append((X_START * SCALE, 442.0 * SCALE))

# Fill with rich royal purple (#58247D down to #3C1554)
tdraw.polygon(poly_4x, fill=(88, 36, 125, 255))

# Draw the 3D PURPLE RIM LINE:
pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_points]

# 1. Outer Dark Midnight Bevel Shadow (width 5.5px, #260D3A)
for i in range(len(pts_top_4x) - 1):
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(38, 13, 58, 255), width=int(round(5.5 * SCALE)))

# 2. Main Vibrant Glowing Purple Line (width 3.6px, #9E48E5 -> #BD64F8 -> #9E48E5)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    cf = math.sin(t * math.pi)
    r = int(160 + 32 * cf)
    g = int(74 + 30 * cf)
    b = int(230 + 18 * cf)
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(r, g, b, 255), width=int(round(3.6 * SCALE)))

# 3. Delicate Sunlit Specular Glint (width 1.4px, #F4E2FF along center 70%)
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
final_logo.save('/tmp/flawless_arch_logo.png')
print("Successfully generated assets/ui/logo/bus_fever_party_logo.png!")
