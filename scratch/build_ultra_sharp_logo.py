import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

print("--- 1. Loading Base Logo ---")
base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size
base_pix = base.load()

# -------------------------------------------------------------
# 1. Build Pristine Foreground Layer (Letters B, U, S)
# -------------------------------------------------------------
fg = Image.new('RGBA', (w, h), (0, 0, 0, 0))
fg_pix = fg.load()

for y in range(436, 620):
    for x in range(300, 770):
        r, g, b, a = base_pix[x, y]
        if a > 80:
            in_bu_valley = (x >= 435 and x <= 478 and y < 455)
            in_u_canyon = (x >= 531 and x <= 565 and y < 545)
            in_us_valley = (x >= 618 and x <= 645 and y < 455)
            
            if in_bu_valley or in_u_canyon or in_us_valley:
                continue
                
            # Exclude tire shadows at the very top of valleys
            if y < 442 and r < 125 and g < 75 and b < 80:
                continue
                
            is_gold = (r > 135 and g > 70 and b < 130)
            is_body = (r > 175 and g < 150)
            is_gloss = (r > 210 and g > 190 and b > 150)
            
            if is_gold or is_body or is_gloss or y >= 443:
                fg_pix[x, y] = (r, g, b, a)

# Seamlessly restore right arm cap of 'U' from left cap:
# Left cap width 36 (x from 481 to 517), right pillar is width 36 (x from 579 to 615)
left_cap = base.crop((481, 437, 517, 452))
flipped = left_cap.transpose(Image.FLIP_LEFT_RIGHT).convert('RGBA')
fw, fh = flipped.size
fpix = flipped.load()

for y in range(fh - 4, fh):
    alpha_factor = (fh - 1 - y) / 4.0
    for x in range(fw):
        r, g, b, a = fpix[x, y]
        fpix[x, y] = (r, g, b, int(a * alpha_factor))

fg.alpha_composite(flipped, (579, 437))
fg_pix = fg.load()

# -------------------------------------------------------------
# 2. Build 8x Supersampled Tailored Purple Backing Tray
# -------------------------------------------------------------
SCALE = 8
sw, sh = w * SCALE, h * SCALE

ctrl_points = [
    (320, 475),
    (320, 465),
    (320, 455),
    (322, 447),
    (326, 439),
    (334, 432),
    (346, 426),
    (368, 422),  # Peak over B
    (405, 423),
    (440, 426),  # Gentle dip between B and U
    (475, 423),
    (505, 422),  # Peak over U left
    (535, 424),
    (550, 425),  # Shallow dip in U center
    (565, 424),
    (595, 422),  # Peak over U right
    (625, 424),
    (645, 426),  # Gentle dip between U and S
    (665, 422),
    (680, 421),  # Peak over S
    (710, 423),
    (728, 427),
    (740, 434),
    (749, 442),
    (756, 450),
    (759, 458),
    (760, 468),
    (760, 475),
]

def catmull_rom(p0, p1, p2, p3, t):
    t2 = t * t
    t3 = t2 * t
    x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
    y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
    return (x, y)

curve_points = []
n = len(ctrl_points)
for i in range(n - 1):
    p0 = ctrl_points[max(0, i - 1)]
    p1 = ctrl_points[i]
    p2 = ctrl_points[i + 1]
    p3 = ctrl_points[min(n - 1, i + 2)]
    steps = 40
    for s in range(steps):
        t = s / float(steps)
        pt = catmull_rom(p0, p1, p2, p3, t)
        curve_points.append(pt)
curve_points.append(ctrl_points[-1])

tray_hi = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
tdraw = ImageDraw.Draw(tray_hi)

# Outer bevel shadow
outer_bevel_pts = [(int(pt[0] * SCALE), int((pt[1] - 1.4) * SCALE)) for pt in curve_points]
outer_poly = list(outer_bevel_pts)
outer_poly.append((int(ctrl_points[-1][0] * SCALE), int(480 * SCALE)))
outer_poly.append((int(ctrl_points[0][0] * SCALE), int(480 * SCALE)))
tdraw.polygon(outer_poly, fill=(65, 32, 85, 255))

# Rich purple body fill
scaled_poly = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
scaled_poly.append((int(ctrl_points[-1][0] * SCALE), int(480 * SCALE)))
scaled_poly.append((int(ctrl_points[0][0] * SCALE), int(480 * SCALE)))
tdraw.polygon(scaled_poly, fill=(120, 65, 148, 255))

# Lavender specular highlight rim
rim_pts = [(int(pt[0] * SCALE), int(pt[1] * SCALE)) for pt in curve_points]
for i in range(len(rim_pts) - 1):
    tdraw.line([rim_pts[i], rim_pts[i + 1]], fill=(195, 172, 225, 255), width=int(2.6 * SCALE))

rim_inner = [(int(pt[0] * SCALE), int((pt[1] + 1.4) * SCALE)) for pt in curve_points]
for i in range(len(rim_inner) - 1):
    tdraw.line([rim_inner[i], rim_inner[i + 1]], fill=(148, 98, 180, 200), width=int(1.8 * SCALE))

tray_1x = tray_hi.resize((w, h), Image.Resampling.LANCZOS)

# -------------------------------------------------------------
# 3. Clean Base Layer (FEVER, PARTY!, Lower Tray)
# -------------------------------------------------------------
out_base = base.copy()
ob_pix = out_base.load()

for y in range(0, 442):
    for x in range(w):
        ob_pix[x, y] = (0, 0, 0, 0)

composite = Image.alpha_composite(tray_1x, out_base)
cpix = composite.load()

# Fill U canyon
for y in range(425, 544):
    t = (y - 425) / float(544 - 425)
    vr = int(120 * (1 - t) + 75 * t)
    vg = int(65 * (1 - t) + 50 * t)
    vb = int(148 * (1 - t) + 134 * t)
    for x in range(532, 565):
        r, g, b, a = cpix[x, y]
        is_letter = (a > 150) and (r > 180 or (r > 140 and g > 75))
        if not is_letter:
            cpix[x, y] = (vr, vg, vb, 255)

# Alpha-composite the pristine letters ON TOP of the tray
final = Image.alpha_composite(composite, fg)
fpix = final.load()

# Clean up pixels above tray boundary
min_y_map = {}
for pt in curve_points:
    ix = int(round(pt[0]))
    iy = int(math.floor(pt[1] - 2.0))
    if ix not in min_y_map or iy < min_y_map[ix]:
        min_y_map[ix] = iy

all_xs = sorted(min_y_map.keys())
for i in range(len(all_xs) - 1):
    x1, x2 = all_xs[i], all_xs[i + 1]
    y1, y2 = min_y_map[x1], min_y_map[x2]
    for x in range(x1 + 1, x2):
        t = (x - x1) / float(x2 - x1)
        min_y_map[x] = int(y1 + t * (y2 - y1))

for x in range(w):
    limit_y = min_y_map.get(x, 475)
    for y in range(0, limit_y):
        fpix[x, y] = (0, 0, 0, 0)

# -------------------------------------------------------------
# 4. Perfect Recolor of Letter 'P':
#    - Candy cushion face: 100% Candy Orange
#    - Outer border / 3D extrusion: 100% Dark Royal Blue (matching 'A')
# -------------------------------------------------------------
seeds = [(350, 800), (325, 865)] # global coords in base (offset ~+215 in x, +385 in y)
# Let's verify coordinates of P in 'final':
# In base, let's find P's candy face using connected region from seeds:
# Let's inspect where P is in final:
# In final (1080x1250), P is around x=320..425, y=780..915
p_seeds = [(370, 815), (345, 875)]
visited = set()
p_face_mask = {}

for sx, sy in p_seeds:
    if (sx, sy) in visited:
        continue
    queue = [(sx, sy)]
    visited.add((sx, sy))
    while queue:
        cx, cy = queue.pop(0)
        p_face_mask[(cx, cy)] = 1.0
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = cx + dx, cy + dy
            if (nx, ny) not in visited and 315 <= nx <= 430 and 780 <= ny <= 918:
                r, g, b, a = fpix[nx, ny]
                if a > 40:
                    h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
                    h_deg = h * 360.0
                    
                    # Inner counter hole shadow (x in 355..385, y in 820..850):
                    if 355 <= nx <= 385 and 820 <= ny <= 852 and v < 0.65:
                        continue
                    # Left 3D extrusion boundary:
                    if nx < 323:
                        continue
                    # Bottom 3D extrusion boundary:
                    if ny > 914:
                        continue
                    # Dark navy border boundary:
                    if v <= 0.46 or (v <= 0.52 and h_deg >= 216):
                        continue
                        
                    is_face = (v > 0.46 and (165 <= h_deg <= 222 or s < 0.40))
                    if is_face:
                        visited.add((nx, ny))
                        queue.append((nx, ny))

print(f"Detected {len(p_face_mask)} face pixels of letter P in base!")

# Dilate edge by 1px
dilated_p = dict(p_face_mask)
for (x, y) in p_face_mask:
    for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
        nx, ny = x + dx, y + dy
        if (nx, ny) not in dilated_p and 315 <= nx <= 430 and 780 <= ny <= 918:
            r, g, b, a = fpix[nx, ny]
            h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            if v > 0.45 and (165 <= h*360 <= 225 or s < 0.40):
                dilated_p[(nx, ny)] = 0.75

# Recolor P's face to Candy Orange
for (x, y), weight in dilated_p.items():
    r, g, b, a = fpix[x, y]
    rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
    h_val, s_val, v_val = colorsys.rgb_to_hsv(rf, gf, bf)
    is_specular = (v_val > 0.82 and s_val < 0.40 and (bf >= rf or gf >= rf))
    lum = 0.299 * rf + 0.587 * gf + 0.114 * bf
    
    if is_specular:
        target_h = 36.0 / 360.0
        target_s = s_val * 0.4
        target_v = v_val
    elif lum > 0.65:
        t = (lum - 0.65) / 0.35
        target_h = (25.0 + 9.0 * t) / 360.0
        target_s = min(0.95, s_val * 1.15)
        target_v = min(1.0, v_val * 1.05)
    elif lum > 0.40:
        t = (lum - 0.40) / 0.25
        target_h = (19.0 + 6.0 * t) / 360.0
        target_s = min(0.98, s_val * 1.20)
        target_v = min(1.0, v_val * 1.02)
    else:
        t = (lum - 0.18) / 0.22
        target_h = (15.0 + 4.0 * max(0.0, t)) / 360.0
        target_s = min(0.98, s_val * 1.25)
        target_v = max(0.48, v_val * 1.05)
        
    nr, ng, nb = colorsys.hsv_to_rgb(target_h, target_s, target_v)
    nr_i, ng_i, nb_i = int(nr * 255), int(ng * 255), int(nb * 255)
    
    final_r = int(r * (1.0 - weight) + nr_i * weight)
    final_g = int(g * (1.0 - weight) + ng_i * weight)
    final_b = int(b * (1.0 - weight) + nb_i * weight)
    fpix[x, y] = (final_r, final_g, final_b, a)

# Recolor P's 3D extrusion to DARK ROYAL BLUE (identical to 'A', 'R', 'T', 'Y')
for y in range(780, 930):
    for x in range(305, 435):
        if (x, y) in dilated_p:
            continue
        r, g, b, a = fpix[x, y]
        if a < 30:
            continue
        h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
        if 175 <= h * 360 <= 230 and v > 0.25 and s > 0.20:
            target_h = 226.0 / 360.0
            target_s = 0.72
            target_v = 0.24 + 0.25 * min(1.0, v)
            nr, ng, nb = colorsys.hsv_to_rgb(target_h, target_s, target_v)
            fpix[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)

# Crop tight bounding box
bbox = final.getbbox()
print("Tight bounding box:", bbox)
cropped = final.crop(bbox)
cw, ch = cropped.size
print(f"Cropped dimensions: {cw}x{ch}")

# Center on (732, 664) standard canvas
TARGET_W, TARGET_H = 732, 664
master = Image.new('RGBA', (TARGET_W, TARGET_H), (0, 0, 0, 0))
paste_x = (TARGET_W - cw) // 2
paste_y = (TARGET_H - ch) // 2
master.alpha_composite(cropped, (paste_x, paste_y))

# Apply subtle Unsharp Mask to enhance edge sharpness and 3D micro-contrast
sharpened_master = master.filter(ImageFilter.UnsharpMask(radius=1.2, percent=135, threshold=1))

dest_path = 'assets/ui/logo/bus_fever_party_logo.png'
sharpened_master.save(dest_path)
print(f"Successfully saved {dest_path} with pristine sharpness and dark blue border!")
