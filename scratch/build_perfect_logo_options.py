import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

# 1. Load clean original master
src = Image.open('test_transparent_logo_clean.png').convert('RGBA')
W, H = src.size

SCALE = 4
SW, SH = W * SCALE, H * SCALE

# -------------------------------------------------------------------------
# A. Base: FEVER, PARTY, Road Ribbon (y >= 435) with Orange P
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
# B. Extract Pristine BUS Letters below y=235 and Sculpt Smooth Caps at 4x
# -------------------------------------------------------------------------
bus_clean = Image.new('RGBA', (W, H), (0, 0, 0, 0))
bc_pix = bus_clean.load()
src_pix = src.load()

# Copy 100% pristine letters below y=235
for y in range(235, 435):
    for x in range(120, 690):
        bc_pix[x, y] = src_pix[x, y]

# Copy clean parts of B (x in 140..250, y in 220..235)
for y in range(220, 235):
    for x in range(140, 260):
        r, g, b, a = src_pix[x, y]
        if a > 60 and (r > 150 or (r > 120 and g > 60)):
            bc_pix[x, y] = (r, g, b, a)

# Copy clean parts of S (x in 520..675, y in 200..235)
for y in range(200, 235):
    for x in range(520, 675):
        r, g, b, a = src_pix[x, y]
        if a > 60 and (r > 150 or (r > 120 and g > 60)):
            bc_pix[x, y] = (r, g, b, a)

# Scale up 4x for pristine surgical dome sculpting
bus_hi = bus_clean.resize((SW, SH), Image.Resampling.LANCZOS)
bpix_hi = bus_hi.load()

def draw_dome_4x(cx_1x, cy_1x, rx_1x, ry_1x, y_blend_1x):
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
            bevel = 5.2 * SCALE
            
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
                
                # Specular curved gloss
                gdx = (x - (cx - rx * 0.28)) / (rx * 0.50)
                gdy = (y - (cy - ry * 0.68)) / (ry * 0.40)
                d2 = gdx*gdx + gdy*gdy
                if d2 < 1.0:
                    sh = (1.0 - math.sqrt(d2)) ** 1.3 * 0.95
                    rc = int(rc * (1 - sh) + 255 * sh)
                    gc = int(gc * (1 - sh) + 255 * sh)
                    bc = int(bc * (1 - sh) + 255 * sh)
            
            # Blend smoothly into existing letter
            if y > y_blend - 4 * SCALE:
                wb = (y - (y_blend - 4 * SCALE)) / float(6 * SCALE)
                wb = min(1.0, max(0.0, wb))
                ex = bpix_hi[x, y]
                if ex[3] > 40:
                    rc = int(rc * (1 - wb) + ex[0] * wb)
                    gc = int(gc * (1 - wb) + ex[1] * wb)
                    bc = int(bc * (1 - wb) + ex[2] * wb)
            
            bpix_hi[x, y] = (rc, gc, bc, int(255 * alpha))

# Sculpt dome caps:
# B top right shoulder: cx=285, cy=230, rx=35, ry=14
draw_dome_4x(285.0, 230.0, 35.0, 14.0, 236.0)
# U left stem: cx=371, cy=244, rx=21.0, ry=20.0
draw_dome_4x(371.0, 244.0, 21.0, 20.0, 252.0)
# U right stem: cx=451, cy=244, rx=25.0, ry=21.0
draw_dome_4x(451.0, 244.0, 25.0, 21.0, 252.0)
# S top left hook: cx=515, cy=220, rx=28.0, ry=14.0
draw_dome_4x(515.0, 220.0, 28.0, 14.0, 228.0)

clean_bus_letters = bus_hi.resize((W, H), Image.Resampling.LANCZOS)
print("BUS letters sculpted.")

# -------------------------------------------------------------------------
# OPTION 1: FLAWLESS CONTINUOUS PURPLE CROWN ARCH
# -------------------------------------------------------------------------
# A single, smooth, continuous, elegant convex arch that crowns over B, U, S!
# NO wavy 4 humps! NO dips! A pure, majestic 3D cartoon purple arch.
arch_pts_1x = []
# S-curve up left of B: from (138, 360) up around to (220, 212)
for i in range(40):
    t = i / 39.0
    x = 138.0 + t * (220.0 - 138.0)
    # smooth bezier ease
    y = 360.0 * (1 - t)**2 + 230.0 * 2 * (1 - t) * t + 212.0 * t**2
    arch_pts_1x.append((x, y))

# Sweeping Crown Arch over BUS: from (220, 212) across to (590, 196)
# Apex at x=415, y=190 (graceful curve with 22px clearance above all letters)
for i in range(120):
    t = i / 119.0
    x = 220.0 + t * (590.0 - 220.0)
    # Quadratic arch
    # p0 = (220, 212), p_mid = (410, 186), p1 = (590, 196)
    y = (1 - t)**2 * 212.0 + 2 * (1 - t) * t * 186.0 + t**2 * 196.0
    arch_pts_1x.append((x, y))

# Curve down right of S: from (590, 196) down to (674, 360)
for i in range(40):
    t = i / 39.0
    x = 590.0 + t * (674.0 - 590.0)
    y = 196.0 * (1 - t)**2 + 220.0 * 2 * (1 - t) * t + 360.0 * t**2
    arch_pts_1x.append((x, y))

tray_hi_opt1 = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw1 = ImageDraw.Draw(tray_hi_opt1)

# Backing polygon
poly1_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts_1x]
poly1_4x.append((674.0 * SCALE, 442.0 * SCALE))
poly1_4x.append((138.0 * SCALE, 442.0 * SCALE))

# Fill with rich royal purple (#562378 down to #3C1554)
tdraw1.polygon(poly1_4x, fill=(86, 35, 120, 255))

# Draw the 3D PURPLE RIM LINE:
pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts_1x]

# 1. Outer Dark Midnight Bevel (width 5.5px)
for i in range(len(pts_top_4x) - 1):
    tdraw1.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(38, 14, 55, 255), width=int(round(5.5 * SCALE)))

# 2. Main Vibrant Glowing Purple Line (width 3.6px, #9E48E5 -> #BD64F8 -> #9E48E5)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    cf = math.sin(t * math.pi)
    r = int(158 + 32 * cf)
    g = int(72 + 30 * cf)
    b = int(228 + 20 * cf)
    tdraw1.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(r, g, b, 255), width=int(round(3.6 * SCALE)))

# 3. Delicate Sunlit Specular Glint (width 1.4px, #F2E0FF along center 70%)
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
            tdraw1.line([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny)], fill=(242, 224, 255, alpha), width=int(round(1.4 * SCALE)))

# Downscale to 1x and composite
tray_opt1 = tray_hi_opt1.resize((W, H), Image.Resampling.LANCZOS)
comp_opt1 = Image.alpha_composite(tray_opt1, clean_base)
comp_opt1 = Image.alpha_composite(comp_opt1, clean_bus_letters)

# Standard target 732x664
bbox1 = comp_opt1.getbbox()
cr1 = comp_opt1.crop(bbox1)
final_opt1 = Image.new('RGBA', (732, 664), (0, 0, 0, 0))
final_opt1.alpha_composite(cr1, ((732 - cr1.size[0]) // 2, (664 - cr1.size[1]) // 2))
final_opt1 = final_opt1.filter(ImageFilter.UnsharpMask(radius=1.1, percent=125, threshold=1))
final_opt1.save('/tmp/logo_option_1_purple_arch.png')
print("Option 1 saved to /tmp/logo_option_1_purple_arch.png")


# -------------------------------------------------------------------------
# OPTION 2: UNIFIED ROYAL NAVY ARCH (Cohesive with FEVER and PARTY)
# -------------------------------------------------------------------------
tray_hi_opt2 = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw2 = ImageDraw.Draw(tray_hi_opt2)
tdraw2.polygon(poly1_4x, fill=(28, 46, 102, 255))

# Outer bevel
for i in range(len(pts_top_4x) - 1):
    tdraw2.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(16, 26, 62, 255), width=int(round(5.5 * SCALE)))

# Navy/Cyan highlight rim line matching FEVER
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    cf = math.sin(t * math.pi)
    r = int(45 + 35 * cf)
    g = int(88 + 45 * cf)
    b = int(195 + 45 * cf)
    tdraw2.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(r, g, b, 255), width=int(round(3.6 * SCALE)))

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
            tdraw2.line([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny)], fill=(210, 240, 255, alpha), width=int(round(1.4 * SCALE)))

tray_opt2 = tray_hi_opt2.resize((W, H), Image.Resampling.LANCZOS)
comp_opt2 = Image.alpha_composite(tray_opt2, clean_base)
comp_opt2 = Image.alpha_composite(comp_opt2, clean_bus_letters)

bbox2 = comp_opt2.getbbox()
cr2 = comp_opt2.crop(bbox2)
final_opt2 = Image.new('RGBA', (732, 664), (0, 0, 0, 0))
final_opt2.alpha_composite(cr2, ((732 - cr2.size[0]) // 2, (664 - cr2.size[1]) // 2))
final_opt2 = final_opt2.filter(ImageFilter.UnsharpMask(radius=1.1, percent=125, threshold=1))
final_opt2.save('/tmp/logo_option_2_navy_arch.png')
print("Option 2 saved to /tmp/logo_option_2_navy_arch.png")

print("Both options built successfully!")
