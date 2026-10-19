import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

src = Image.open('test_transparent_logo_clean.png').convert('RGBA')
W, H = src.size

SCALE = 4
SW, SH = W * SCALE, H * SCALE

# -------------------------------------------------------------------------
# Step 1: Prepare Clean Base (FEVER, PARTY with Orange P, Road Ribbon)
# -------------------------------------------------------------------------
clean_base = src.copy()
cb_pix = clean_base.load()
for y in range(0, 442):
    for x in range(W):
        cb_pix[x, y] = (0, 0, 0, 0)

# Orange recolor on face of P in clean_base
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
# Step 2: Extract pristine BUS letters and sculpt U stems at 4x
# -------------------------------------------------------------------------
# We start with the original image below y=242 (which is 100% pristine!)
bus_clean = Image.new('RGBA', (W, H), (0, 0, 0, 0))
bc_pix = bus_clean.load()
src_pix = src.load()

for y in range(242, 442):
    for x in range(120, 690):
        r, g, b, a = src_pix[x, y]
        if a > 40:
            bc_pix[x, y] = (r, g, b, a)

# Also copy pristine parts of B above y=242 (x < 330, y >= 218)
for y in range(218, 242):
    for x in range(130, 330):
        r, g, b, a = src_pix[x, y]
        # Ignore tire pixels
        if a > 40 and not (r < 75 and g < 75 and b < 75):
            bc_pix[x, y] = (r, g, b, a)

# Also copy pristine parts of S above y=242 (x > 480, y >= 200)
for y in range(200, 242):
    for x in range(480, 680):
        r, g, b, a = src_pix[x, y]
        if a > 40 and not (r < 75 and g < 75 and b < 75):
            bc_pix[x, y] = (r, g, b, a)

# Supersample 4x to sculpt smooth tops of B, U, and S
bus_hi = bus_clean.resize((SW, SH), Image.Resampling.LANCZOS)
bpix_hi = bus_hi.load()

def sculpt_candy_cap(cx_1x, cy_1x, rx_1x, ry_1x, y_blend_1x):
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
                # Golden candy bevel
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
                # Candy body fill
                ny = min(1.0, max(0.0, (y - y_top) / float(ry * 2.5)))
                rc = 255
                gc = int(176 * (1.0 - ny * 0.42))
                bc = int(80 * (1.0 - ny * 0.65))
                
                # Specular curved gloss glint (top left)
                gdx = (x - (cx - rx * 0.28)) / (rx * 0.50)
                gdy = (y - (cy - ry * 0.68)) / (ry * 0.40)
                d2 = gdx*gdx + gdy*gdy
                if d2 < 1.0:
                    sh = (1.0 - math.sqrt(d2)) ** 1.3 * 0.95
                    rc = int(rc * (1 - sh) + 255 * sh)
                    gc = int(gc * (1 - sh) + 255 * sh)
                    bc = int(bc * (1 - sh) + 255 * sh)
            
            # Blend smoothly into existing letter body
            if y > y_blend - 4 * SCALE:
                w_blend = (y - (y_blend - 4 * SCALE)) / float(6 * SCALE)
                w_blend = min(1.0, max(0.0, w_blend))
                existing = bpix_hi[x, y]
                if existing[3] > 40:
                    rc = int(rc * (1 - w_blend) + existing[0] * w_blend)
                    gc = int(gc * (1 - w_blend) + existing[1] * w_blend)
                    bc = int(bc * (1 - w_blend) + existing[2] * w_blend)
            
            bpix_hi[x, y] = (rc, gc, bc, int(255 * alpha))

# Sculpt U left dome (cx=371, cy=244, rx=19.5, ry=19.0)
sculpt_candy_cap(371.0, 244.0, 19.5, 19.0, 252.0)
# Sculpt U right dome (cx=451, cy=244, rx=24.0, ry=20.0)
sculpt_candy_cap(451.0, 244.0, 24.0, 20.0, 252.0)

# Also ensure top of B (cx=246, cy=226, rx=68, ry=12) is smoothly capped
for y in range(int(215 * SCALE), int(228 * SCALE)):
    for x in range(int(260 * SCALE), int(330 * SCALE)):
        # clean any tire remnants
        cur = bpix_hi[x, y]
        if cur[3] > 40 and cur[0] < 120 and cur[1] < 120 and cur[2] < 120:
            bpix_hi[x, y] = (0, 0, 0, 0)

# Sculpt the top right shoulder of B smoothly
sculpt_candy_cap(298.0, 228.0, 28.0, 12.0, 234.0)

# Clean top hook of S
for y in range(int(195 * SCALE), int(215 * SCALE)):
    for x in range(int(480 * SCALE), int(530 * SCALE)):
        cur = bpix_hi[x, y]
        if cur[3] > 40 and cur[0] < 120 and cur[1] < 120 and cur[2] < 120:
            bpix_hi[x, y] = (0, 0, 0, 0)

# Sculpt top left hook of S smoothly
sculpt_candy_cap(510.0, 218.0, 26.0, 12.0, 225.0)

print("Candy letters sculpting completed.")

# -------------------------------------------------------------------------
# Step 3: BUILD THE ULTRA-SMOOTH PURPLE RIM LINE & BACKING TRAY
# -------------------------------------------------------------------------
# The authentic purple rim line is a smooth, elegant contour:
# We build high-precision control points for the top rim path:
# 1. Left of B: starts at (136, 320), curves up around B shoulder to (235, 215)
# 2. Valley B-U: dips gently to (315, 228)
# 3. Peak U left: curves over left U dome to (371, 222)
# 4. Valley inside U: dips into U-canyon to (410, 238)
# 5. Peak U right: curves over right U dome to (451, 218)
# 6. Valley U-S: dips gently to (485, 226)
# 7. Peak S: curves over S crown to (560, 206)
# 8. Right of S: curves down around S shoulder to (670, 310)

key_pts = [
    (136.0, 340.0),
    (140.0, 275.0),
    (160.0, 240.0),
    (195.0, 220.0),
    (245.0, 214.0), # peak B
    (290.0, 218.0),
    (322.0, 228.0), # valley B-U
    (350.0, 224.0),
    (371.0, 220.0), # peak U left
    (392.0, 225.0),
    (410.0, 234.0), # canyon U
    (430.0, 224.0),
    (451.0, 216.0), # peak U right
    (472.0, 222.0),
    (488.0, 228.0), # valley U-S
    (515.0, 218.0),
    (555.0, 206.0), # peak S
    (605.0, 214.0),
    (645.0, 238.0),
    (666.0, 275.0),
    (672.0, 340.0)
]

# Generate smooth Catmull-Rom / cubic spline interpolation
def get_spline_points(pts, num_steps=20):
    spline = []
    # Add phantom endpoints
    p_extended = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(p_extended) - 2):
        p0 = p_extended[i - 1]
        p1 = p_extended[i]
        p2 = p_extended[i + 1]
        p3 = p_extended[i + 2]
        for step in range(num_steps):
            t = step / float(num_steps)
            t2 = t * t
            t3 = t2 * t
            # Catmull-Rom formula
            x = 0.5 * ((2 * p1[0]) +
                       (-p0[0] + p2[0]) * t +
                       (2*p0[0] - 5*p1[0] + 4*p2[0] - p3[0]) * t2 +
                       (-p0[0] + 3*p1[0] - 3*p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) +
                       (-p0[1] + p2[1]) * t +
                       (2*p0[1] - 5*p1[1] + 4*p2[1] - p3[1]) * t2 +
                       (-p0[1] + 3*p1[1] - 3*p2[1] + p3[1]) * t3)
            spline.append((x, y))
    spline.append(pts[-1])
    return spline

smooth_contour_1x = get_spline_points(key_pts, num_steps=25)
print(f"Smooth spline generated: {len(smooth_contour_1x)} points.")

# Create the 4x Purple Tray Layer
tray_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

# Create closed polygon for backing fill:
poly_4x = [(x * SCALE, y * SCALE) for (x, y) in smooth_contour_1x]
# Close down into FEVER at y=442
poly_4x.append((672.0 * SCALE, 442.0 * SCALE))
poly_4x.append((136.0 * SCALE, 442.0 * SCALE))

# Fill with rich authentic royal purple:
# Authentic purple gradient: top (#5B267E) to bottom (#3E1656)
tdraw.polygon(poly_4x, fill=(91, 38, 126, 255))

# Draw the 3-Layer 3D Cartoon Purple Rim Line:
pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in smooth_contour_1x]

def draw_curve_stroke(draw, pts, width_px, col):
    for i in range(len(pts) - 1):
        draw.line([pts[i], pts[i+1]], fill=col, width=int(round(width_px)))

# Layer 1: Dark outer bevel shadow (thickness 5.5px, color #2A0F3D)
draw_curve_stroke(tdraw, pts_top_4x, 5.5 * SCALE, (42, 15, 61, 255))

# Layer 2: Main Radiant Glossy Purple Line (thickness 3.5px, color #A44CE8 to #BA60F4)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    # Peak highlight in center
    cf = math.sin(t * math.pi)
    r = int(160 + 26 * cf)
    g = int(72 + 28 * cf)
    b = int(230 + 16 * cf)
    tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(r, g, b, 255), width=int(round(3.4 * SCALE)))

# Layer 3: Sunlit Specular Glint (thickness 1.3px, color #F3E2FF along upper arcs)
for i in range(len(pts_top_4x) - 1):
    t = i / float(len(pts_top_4x) - 1)
    p0 = pts_top_4x[i]
    p1 = pts_top_4x[i+1]
    # Highlight is bright over B (t in 0.12..0.30), U (t in 0.35..0.65), S (t in 0.70..0.92)
    in_b = (0.12 <= t <= 0.30)
    in_u = (0.35 <= t <= 0.65)
    in_s = (0.70 <= t <= 0.92)
    if in_b or in_u or in_s:
        # inward offset 1.2px
        dx = p1[0] - p0[0]
        dy = p1[1] - p0[1]
        L = math.hypot(dx, dy)
        if L > 0:
            nx = -dy / L * 1.2 * SCALE
            ny = dx / L * 1.2 * SCALE
            tdraw.line([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny)], fill=(245, 228, 255, 240), width=int(round(1.3 * SCALE)))

# Composite in 4x:
# 1. Tray
# 2. Existing valleys & letters from bus_hi
comp_hi = tray_hi.copy()
comp_hi.alpha_composite(bus_hi)

# Downscale to 1x
comp_bus_1x = comp_hi.resize((W, H), Image.Resampling.LANCZOS)

# Now composite with clean_base (FEVER, PARTY)
final_logo = clean_base.copy()
final_logo.alpha_composite(comp_bus_1x)

# Crop tight to content
bbox = final_logo.getbbox()
print("Final tight bbox:", bbox)
cropped = final_logo.crop(bbox)
cw, ch = cropped.size

# Standard target 732x664
TARGET_W, TARGET_H = 732, 664
out_img = Image.new('RGBA', (TARGET_W, TARGET_H), (0, 0, 0, 0))
paste_x = (TARGET_W - cw) // 2
paste_y = (TARGET_H - ch) // 2
out_img.alpha_composite(cropped, (paste_x, paste_y))

# Apply subtle crisp unsharp mask
sharpened = out_img.filter(ImageFilter.UnsharpMask(radius=1.1, percent=130, threshold=1))
sharpened.save('assets/ui/logo/bus_fever_party_logo.png')
sharpened.save('/tmp/perfect_sculpted_logo.png')
print("Successfully saved assets/ui/logo/bus_fever_party_logo.png and /tmp/perfect_sculpted_logo.png!")
