import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size
base_pix = base.load()

SCALE = 4
sw, sh = w * SCALE, h * SCALE

# -------------------------------------------------------------------------
# 1. Clean Base Layer (FEVER, PARTY, Road Ribbon) below y=442
# -------------------------------------------------------------------------
clean_base = base.copy()
cb_pix = clean_base.load()
for y in range(0, 442):
    for x in range(w):
        cb_pix[x, y] = (0, 0, 0, 0)

# -------------------------------------------------------------------------
# 2. Extract Pristine BUS Letters
# -------------------------------------------------------------------------
letters_1x = Image.new('RGBA', (w, h), (0, 0, 0, 0))
lpix = letters_1x.load()

# Base letter copy below y=446
for y in range(446, 620):
    for x in range(300, 770):
        r, g, b, a = base_pix[x, y]
        if a > 80:
            in_bu_valley = (x >= 435 and x <= 475 and y < 455)
            in_u_canyon = (x >= 528 and x <= 572 and y < 545)
            in_us_valley = (x >= 622 and x <= 645 and y < 455)
            if in_bu_valley or in_u_canyon or in_us_valley:
                continue
            is_gold = (r > 135 and g > 70 and b < 130)
            is_body = (r > 175 and g < 150)
            is_gloss = (r > 210 and g > 190 and b > 150)
            if is_gold or is_body or is_gloss or y >= 450:
                lpix[x, y] = (r, g, b, a)

# Pristine top of B (x=325..408, y=438..446)
for y in range(438, 446):
    for x in range(325, 409):
        r, g, b, a = base_pix[x, y]
        if a > 80 and (r > 130 or g > 60):
            lpix[x, y] = (r, g, b, a)

# Pristine top of S (x=665..760, y=438..446)
for y in range(438, 446):
    for x in range(665, 760):
        r, g, b, a = base_pix[x, y]
        if a > 80 and (r > 130 or g > 60):
            lpix[x, y] = (r, g, b, a)

# -------------------------------------------------------------------------
# 3. Supersampled Surgical 3D Sculpting of U Domes, B Bevel & S Bevel
# -------------------------------------------------------------------------
letters_hi = letters_1x.resize((sw, sh), Image.Resampling.LANCZOS)
lpix_hi = letters_hi.load()

def render_candy_dome(cx_1x, cy_base_1x, rx_1x, ry_1x, y_bottom_1x, gloss_x_offset=-0.22):
    cx = cx_1x * SCALE
    cy_base = cy_base_1x * SCALE
    rx = rx_1x * SCALE
    ry = ry_1x * SCALE
    y_bot = int(y_bottom_1x * SCALE)
    y_top = int(cy_base - ry)
    
    x_min = int(cx - rx - 2)
    x_max = int(cx + rx + 2)
    
    for y in range(y_top, y_bot + 1):
        for x in range(x_min, x_max + 1):
            dx = (x - cx) / float(rx)
            if abs(dx) > 1.0:
                continue
            cur_y_top = cy_base - ry * math.sqrt(max(0.0, 1.0 - dx * dx))
            dist_from_edge = y - cur_y_top
            if dist_from_edge < -1.0:
                continue
            
            alpha_edge = min(1.0, max(0.0, dist_from_edge + 1.0))
            bevel_thickness = 5.4 * SCALE
            
            if dist_from_edge < bevel_thickness:
                # Golden Candy Bevel
                u_bevel = dist_from_edge / bevel_thickness
                if u_bevel < 0.22:
                    # Dark outer accent
                    r_col = int(140 + u_bevel * 4.5 * 115)
                    g_col = int(40 + u_bevel * 4.5 * 160)
                    b_col = int(25 + u_bevel * 4.5 * 65)
                else:
                    t_b = (u_bevel - 0.22) / 0.78
                    r_col = int(255 * (1 - t_b) + 255 * t_b)
                    g_col = int(218 * (1 - t_b) + 165 * t_b)
                    b_col = int(105 * (1 - t_b) + 55 * t_b)
            else:
                # Candy Orange Cushion & Specular Gloss
                t_vert = (y - y_top) / float(max(1, y_bot - y_top))
                base_r = 255
                base_g = int(165 * (1 - t_vert) + 138 * t_vert)
                base_b = int(95 * (1 - t_vert) + 80 * t_vert)
                
                gx = cx + gloss_x_offset * rx
                gy = cy_base - ry * 0.35
                dist_gloss = math.hypot((x - gx) / (rx * 0.55), (y - gy) / (ry * 0.45))
                gloss_factor = math.pow(max(0.0, 1.0 - dist_gloss), 1.8)
                
                r_col = int(base_r * (1 - gloss_factor) + 255 * gloss_factor)
                g_col = int(base_g * (1 - gloss_factor) + 248 * gloss_factor)
                b_col = int(base_b * (1 - gloss_factor) + 225 * gloss_factor)
            
            cur_a = int(255 * alpha_edge)
            if y > y_bot - (3 * SCALE):
                blend_t = (y_bot - y) / float(3 * SCALE)
                old = lpix_hi[x, y]
                if old[3] > 0:
                    r_col = int(r_col * blend_t + old[0] * (1 - blend_t))
                    g_col = int(g_col * blend_t + old[1] * (1 - blend_t))
                    b_col = int(b_col * blend_t + old[2] * (1 - blend_t))
            
            lpix_hi[x, y] = (r_col, g_col, b_col, max(lpix_hi[x, y][3], cur_a))

# Sculpt Left & Right U Domes
render_candy_dome(500.0, 448.0, 24.0, 12.0, 451.0, gloss_x_offset=-0.25)
render_candy_dome(598.5, 448.0, 23.5, 12.0, 451.0, gloss_x_offset=-0.20)

# Sculpt Top-Right Golden Bevel of B (x=405..434)
for x_1x in range(405, 434):
    t = (x_1x - 405) / float(433 - 405)
    y_arc_1x = 439.0 + 13.0 * (t * t)
    for dy_1x in [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]:
        sx = int(round(x_1x * SCALE))
        sy = int(round((y_arc_1x + dy_1x) * SCALE))
        if 0 <= sx < sw and 0 <= sy < sh:
            u_b = (dy_1x + 1.5) / 5.5
            col = (140, 40, 25, 255) if u_b < 0.2 else ((255, 195, 75, 255) if u_b < 0.8 else (255, 150, 70, 255))
            for ox in range(SCALE):
                for oy in range(SCALE):
                    lpix_hi[sx + ox, sy + oy] = col

# Sculpt Top-Left Golden Bevel of S (x=645..670)
for x_1x in range(645, 671):
    t = (670 - x_1x) / float(670 - 645)
    y_arc_1x = 439.0 + 13.0 * (t * t)
    for dy_1x in [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]:
        sx = int(round(x_1x * SCALE))
        sy = int(round((y_arc_1x + dy_1x) * SCALE))
        if 0 <= sx < sw and 0 <= sy < sh:
            u_b = (dy_1x + 1.5) / 5.5
            col = (140, 40, 25, 255) if u_b < 0.2 else ((255, 195, 75, 255) if u_b < 0.8 else (255, 150, 70, 255))
            for ox in range(SCALE):
                for oy in range(SCALE):
                    lpix_hi[sx + ox, sy + oy] = col

clean_letters_1x = letters_hi.resize((w, h), Image.Resampling.LANCZOS)
cl_pix = clean_letters_1x.load()

# -------------------------------------------------------------------------
# 4. Build Royal Dark Navy Blue 3D Cartoon Outer Bevel (6.5px)
# -------------------------------------------------------------------------
mask = Image.new('L', (w, h), 0)
mpix = mask.load()
for y in range(434, 620):
    for x in range(300, 770):
        if cl_pix[x, y][3] > 60:
            mpix[x, y] = 255

dilated_mask = mask.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(0.8))
d_pix = dilated_mask.load()

backing = Image.new('RGBA', (w, h), (0, 0, 0, 0))
b_pix = backing.load()

# Fill 6.5px outer 3D border with authentic Royal Dark Navy Blue (#1C2E66 to #2A3F7E)
for y in range(426, 620):
    for x in range(290, 780):
        val = d_pix[x, y]
        if val > 15:
            t = (y - 426) / float(620 - 426)
            # Royal navy gradient matching PARTY border
            r = int(28 * (1 - t) + 35 * t)
            g = int(46 * (1 - t) + 54 * t)
            b = int(102 * (1 - t) + 125 * t)
            a = int(val)
            b_pix[x, y] = (r, g, b, a)

# In the canyon of U and valleys, fill cleanly down to FEVER with royal navy
for y in range(436, 545):
    t = (y - 436) / float(545 - 436)
    vr = int(28 * (1 - t) + 35 * t)
    vg = int(46 * (1 - t) + 54 * t)
    vb = int(102 * (1 - t) + 125 * t)
    for x in range(526, 572):
        if cl_pix[x, y][3] < 120:
            b_pix[x, y] = (vr, vg, vb, 255)
    for x in range(436, 474):
        if cl_pix[x, y][3] < 120:
            b_pix[x, y] = (vr, vg, vb, 255)
    for x in range(622, 646):
        if cl_pix[x, y][3] < 120:
            b_pix[x, y] = (vr, vg, vb, 255)

# Composite: Backing -> Clean Base -> Clean Letters
composite = Image.alpha_composite(backing, clean_base)
composite = Image.alpha_composite(composite, clean_letters_1x)
fpix = composite.load()

# -------------------------------------------------------------------------
# 5. Perfect Candy Orange Recolor on Face of Letter 'P'
#    & Royal Dark Navy 3D Extrusion on Border of 'P'
# -------------------------------------------------------------------------
p_seeds = [(370, 815), (345, 875)]
visited = set()
p_face_mask = {}
for sx, sy in p_seeds:
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
                    h_val, s_val, v_val = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
                    h_deg = h_val * 360.0
                    if 355 <= nx <= 385 and 820 <= ny <= 852 and v_val < 0.65: continue
                    if nx < 323 or ny > 914: continue
                    if v_val <= 0.46 or (v_val <= 0.52 and h_deg >= 216): continue
                    if v_val > 0.46 and (165 <= h_deg <= 222 or s_val < 0.40):
                        visited.add((nx, ny))
                        queue.append((nx, ny))

dilated_p = dict(p_face_mask)
for (x, y) in p_face_mask:
    for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
        nx, ny = x + dx, y + dy
        if (nx, ny) not in dilated_p and 315 <= nx <= 430 and 780 <= ny <= 918:
            r, g, b, a = fpix[nx, ny]
            h_val, s_val, v_val = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            if v_val > 0.45 and (165 <= h_val*360 <= 225 or s_val < 0.40):
                dilated_p[(nx, ny)] = 0.75

for (x, y), weight in dilated_p.items():
    r, g, b, a = fpix[x, y]
    rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
    h_val, s_val, v_val = colorsys.rgb_to_hsv(rf, gf, bf)
    is_specular = (v_val > 0.82 and s_val < 0.40 and (bf >= rf or gf >= rf))
    lum = 0.299 * rf + 0.587 * gf + 0.114 * bf
    if is_specular:
        th, ts, tv = 36.0/360.0, s_val * 0.4, v_val
    elif lum > 0.65:
        t = (lum - 0.65) / 0.35
        th, ts, tv = (25.0 + 9.0 * t)/360.0, min(0.95, s_val * 1.15), min(1.0, v_val * 1.05)
    elif lum > 0.40:
        t = (lum - 0.40) / 0.25
        th, ts, tv = (19.0 + 6.0 * t)/360.0, min(0.98, s_val * 1.20), min(1.0, v_val * 1.02)
    else:
        t = (lum - 0.18) / 0.22
        th, ts, tv = (15.0 + 4.0 * max(0.0, t))/360.0, min(0.98, s_val * 1.25), max(0.48, v_val * 1.05)
    nr, ng, nb = colorsys.hsv_to_rgb(th, ts, tv)
    fpix[x, y] = (int(r * (1-weight) + nr*255 * weight), int(g * (1-weight) + ng*255 * weight), int(b * (1-weight) + nb*255 * weight), a)

for y in range(780, 930):
    for x in range(305, 435):
        if (x, y) in dilated_p: continue
        r, g, b, a = fpix[x, y]
        if a < 30: continue
        h_val, s_val, v_val = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
        if 175 <= h_val * 360 <= 230 and v_val > 0.25 and s_val > 0.20:
            nr, ng, nb = colorsys.hsv_to_rgb(226.0/360.0, 0.72, 0.24 + 0.25 * min(1.0, v_val))
            fpix[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)

# -------------------------------------------------------------------------
# 6. Center on Standard 732x664 Canvas & Apply Unsharp Masking
# -------------------------------------------------------------------------
bbox = composite.getbbox()
print("Composite tight bbox:", bbox)
cropped = composite.crop(bbox)
cw, ch = cropped.size
print(f"Cropped dimensions: {cw}x{ch}")

TARGET_W, TARGET_H = 732, 664
final_logo = Image.new('RGBA', (TARGET_W, TARGET_H), (0, 0, 0, 0))
paste_x = (TARGET_W - cw) // 2
paste_y = (TARGET_H - ch) // 2
final_logo.alpha_composite(cropped, (paste_x, paste_y))

# Apply crisp unsharp mask
sharpened = final_logo.filter(ImageFilter.UnsharpMask(radius=1.2, percent=140, threshold=1))
out_file = 'assets/ui/logo/bus_fever_party_logo.png'
sharpened.save(out_file)
print(f"Master logo successfully saved to {out_file}!")
