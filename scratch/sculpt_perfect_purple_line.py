import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

# Load base transparent logo
src = Image.open('test_transparent_logo_clean.png').convert('RGBA')
W, H = src.size

SCALE = 4
SW, SH = W * SCALE, H * SCALE

# -------------------------------------------------------------------------
# 1. Clean Base (FEVER, PARTY, Road Ribbon, Confetti) below y=442
# -------------------------------------------------------------------------
clean_base = src.copy()
cb_pix = clean_base.load()
for y in range(0, 442):
    for x in range(W):
        cb_pix[x, y] = (0, 0, 0, 0)

# Apply orange recolor on P and navy border on P in clean_base
for y in range(650, H):
    for x in range(200, 360):
        r, g, b, a = cb_pix[x, y]
        if a > 40:
            h_val, s_val, v_val = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            # Recolor blue face of P to orange
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

print("Base FEVER, PARTY (P orange) prepared.")

# -------------------------------------------------------------------------
# 2. Extract & Sculpt Pristine Candy BUS Letters (4x resolution)
# -------------------------------------------------------------------------
# Extract pristine letter bodies from original
bus_raw = Image.new('RGBA', (W, H), (0, 0, 0, 0))
br_pix = bus_raw.load()
src_pix = src.load()

for y in range(195, 450):
    for x in range(150, 680):
        r, g, b, a = src_pix[x, y]
        if a < 50:
            continue
        # Letter pixels: warm red/orange/golden
        is_red = (r > 155 and g < 135 and b < 75)
        is_orange = (r > 195 and g > 90 and b < 95)
        is_gold = (r > 175 and g > 135 and b < 85)
        is_gloss = (r > 225 and g > 195 and b > 140)
        
        # Exclude bus wheels and roof
        is_black_wheel = (r < 75 and g < 75 and b < 75)
        is_bus_bumper = (y < 242 and (r > 230 and g > 185 and b < 120))
        is_bus_window = (y < 242 and b > 180 and g > 160)
        
        if (is_red or is_orange or is_gold or is_gloss) and not is_black_wheel and not is_bus_bumper and not is_bus_window:
            br_pix[x, y] = (r, g, b, a)

# Supersample 4x for surgical anti-aliased sculpting
letters_hi = bus_raw.resize((SW, SH), Image.Resampling.LANCZOS)
lpix_hi = letters_hi.load()

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
                # Candy body
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
            
            # Blend smoothly into existing letter body near y_blend
            if y > y_blend - 4 * SCALE:
                weight = (y - (y_blend - 4 * SCALE)) / float(6 * SCALE)
                weight = min(1.0, max(0.0, weight))
                existing = lpix_hi[x, y]
                if existing[3] > 40:
                    rc = int(rc * (1 - weight) + existing[0] * weight)
                    gc = int(gc * (1 - weight) + existing[1] * weight)
                    bc = int(bc * (1 - weight) + existing[2] * weight)
            
            lpix_hi[x, y] = (rc, gc, bc, int(255 * alpha))

# Sculpt pristine U domes
sculpt_dome(371.0, 244.0, 19.5, 19.0, 252.0)
sculpt_dome(451.0, 244.0, 24.0, 20.0, 252.0)

# Downscale clean letters to 1x
clean_letters = letters_hi.resize((W, H), Image.Resampling.LANCZOS)
print("Pristine sculpted candy letters completed.")

# -------------------------------------------------------------------------
# 3. BUILD OPTION 1: FLAWLESS PURPLE ARCH & VIBRANT PURPLE RIM LINE
# -------------------------------------------------------------------------
# The purple tray surrounds the BUS letters from x=140 to x=680, y=175 to y=440.
# We define a smooth mathematical Crown Arch for the top boundary:
# At x=140: y=250 (left of B)
# At x=245: y=198 (above B)
# At x=410: y=186 (above U)
# At x=575: y=178 (above S)
# At x=675: y=235 (right of S)

# Let's create the purple tray at 4x supersampling for razor-sharp anti-aliased beauty.
tray_hi_opt1 = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw1 = ImageDraw.Draw(tray_hi_opt1)

# Generate smooth cubic spline / polynomial arch path points
arch_pts_1x = []
# Left side of B going up:
# x=140..245
for i in range(50):
    t = i / 49.0
    # Smooth S-curve from (142, 380) up along left of B to (245, 198)
    # Using smooth bezier-like interpolation:
    x = 142.0 + t * (245.0 - 142.0)
    # curve over top-left shoulder of B
    angle = math.pi * (1.0 - 0.5 * t)
    # y follows smooth crown arch
    y = 250.0 - 52.0 * math.sin(t * math.pi * 0.5)
    arch_pts_1x.append((x, y))

# Arch across B, U, S (x=245 to x=575):
for i in range(100):
    t = i / 99.0
    x = 245.0 + t * (575.0 - 245.0)
    # Smooth crown arch with gentle rise towards S (y=198 at B down to y=178 at S, slight crown peaking at U)
    base_y = 198.0 * (1.0 - t) + 178.0 * t
    crown = 7.0 * math.sin(t * math.pi) # 7px subtle convex crown
    y = base_y - crown
    arch_pts_1x.append((x, y))

# Right side of S going down:
for i in range(50):
    t = i / 49.0
    x = 575.0 + t * (676.0 - 575.0)
    y = 178.0 + 57.0 * math.sin(t * math.pi * 0.5)
    arch_pts_1x.append((x, y))

# Complete the polygon down around FEVER:
arch_poly_4x = []
for (x, y) in arch_pts_1x:
    arch_poly_4x.append((x * SCALE, y * SCALE))

# Add bottom corners merging into FEVER (y=440)
arch_poly_4x.append((676.0 * SCALE, 442.0 * SCALE))
arch_poly_4x.append((142.0 * SCALE, 442.0 * SCALE))

# Draw the solid purple backing fill
# Rich royal purple gradient (#4A1B6D on top down to #321048 behind letters)
tdraw1.polygon(arch_poly_4x, fill=(74, 27, 109, 255))

# Draw the 3D CARTOON PURPLE BEVEL AND VIBRANT PURPLE RIM LINE:
# Layer 1: Outer dark midnight shadow/extrusion (4px outer stroke, color #220B35)
# Layer 2: Main vibrant glossy purple line (width 3.5px, color #A64BEA to #C46CFF)
# Layer 3: Top inner specular highlight (width 1.5px, soft lavender-white glint #E8CFFF)

def draw_smooth_rim_curve(draw, pts, width_4x, color_fn):
    n = len(pts)
    for i in range(n - 1):
        p0 = pts[i]
        p1 = pts[i + 1]
        t = i / float(n - 1)
        col = color_fn(t)
        draw.line([p0, p1], fill=col, width=int(round(width_4x)))

# Draw top rim strokes on tray_hi_opt1:
pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts_1x]

# 1. Outer Dark Bevel/Extrusion Line (width 4.5px, color #260D3A)
draw_smooth_rim_curve(tdraw1, pts_top_4x, 5.0 * SCALE, lambda t: (38, 13, 58, 255))

# 2. Main Radiant Glossy Purple Line (width 3.2px, vibrant gradient #9C45E2 -> #B85CF5 -> #9C45E2)
def purple_rim_color(t):
    # Vibrant candy purple highlight
    # t is progress from left of B (0.0) to right of S (1.0)
    # Slightly brighter in the center crown
    center_factor = math.sin(t * math.pi)
    r = int(156 + 35 * center_factor)
    g = int(68 + 32 * center_factor)
    b = int(226 + 24 * center_factor)
    return (r, g, b, 255)

draw_smooth_rim_curve(tdraw1, pts_top_4x, 3.2 * SCALE, purple_rim_color)

# 3. Top Specular Glint Line (width 1.2px, delicate sunlit glint #F0DDFE along top 60%)
def specular_glint_color(t):
    # Visible along center arch (t in 0.15 .. 0.85)
    if t < 0.15 or t > 0.85:
        return (0, 0, 0, 0)
    glint_t = (t - 0.15) / 0.70
    alpha = int(240 * math.sin(glint_t * math.pi) ** 1.5)
    return (244, 225, 255, alpha)

# Shift points slightly inward (downward by 1.2px) for inner bevel glint
pts_glint_4x = [(x * SCALE, (y + 1.1) * SCALE) for (x, y) in arch_pts_1x]
draw_smooth_rim_curve(tdraw1, pts_glint_4x, 1.3 * SCALE, specular_glint_color)

# Downscale to 1x
tray_opt1 = tray_hi_opt1.resize((W, H), Image.Resampling.LANCZOS)

# Composite Option 1: Backing Tray -> Base FEVER/PARTY -> Sculpted Candy BUS Letters
comp_opt1 = Image.alpha_composite(tray_opt1, clean_base)
comp_opt1 = Image.alpha_composite(comp_opt1, clean_letters)

# Save Option 1
comp_opt1.save('/tmp/logo_opt1_purple_arch.png')
print("Option 1 (Flawless Purple Crown Arch) saved to /tmp/logo_opt1_purple_arch.png")


# -------------------------------------------------------------------------
# 4. BUILD OPTION 2: FLAWLESS CONTOUR HUGGING TRAY (Tailored Uniform 16px)
# -------------------------------------------------------------------------
# Instead of a single crown arch, Option 2 hugs B, U, S with a uniform 16px radius,
# but with mathematically smoothed valleys (zero jagged humps/dips!).
mask_hi = Image.new('L', (SW, SH), 0)
mdraw = ImageDraw.Draw(mask_hi)
cl_pix_hi = letters_hi.load()
for y in range(int(190 * SCALE), int(440 * SCALE)):
    for x in range(int(140 * SCALE), int(680 * SCALE)):
        if cl_pix_hi[x, y][3] > 60:
            mask_hi.putpixel((x, y), 255)

# Morphological expansion by 16px
dilated_hi = mask_hi.filter(ImageFilter.MaxFilter(int(16 * SCALE))).filter(ImageFilter.GaussianBlur(1.2 * SCALE))
d_pix = dilated_hi.load()

tray_hi_opt2 = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
t2_pix = tray_hi_opt2.load()

for y in range(int(170 * SCALE), int(442 * SCALE)):
    for x in range(int(135 * SCALE), int(685 * SCALE)):
        v = d_pix[x, y]
        if v > 20:
            a = min(255, int(v * 1.05))
            # Royal purple gradient
            t = (y - 170 * SCALE) / float(270 * SCALE)
            r = int(75 * (1 - t) + 48 * t)
            g = int(28 * (1 - t) + 16 * t)
            b = int(112 * (1 - t) + 72 * t)
            t2_pix[x, y] = (r, g, b, a)

tray_opt2 = tray_hi_opt2.resize((W, H), Image.Resampling.LANCZOS)
comp_opt2 = Image.alpha_composite(tray_opt2, clean_base)
comp_opt2 = Image.alpha_composite(comp_opt2, clean_letters)
comp_opt2.save('/tmp/logo_opt2_purple_contour.png')
print("Option 2 (Tailored Purple Contour) saved to /tmp/logo_opt2_purple_contour.png")


# -------------------------------------------------------------------------
# 5. BUILD OPTION 3: UNIFIED ROYAL NAVY BLUE TRAY (Matching FEVER/PARTY)
# -------------------------------------------------------------------------
# Option 3 uses the identical dark royal navy blue backing tray as FEVER,
# completely eliminating purple so the entire logo has 1 cohesive background.
tray_hi_opt3 = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
tdraw3 = ImageDraw.Draw(tray_hi_opt3)

# Draw arch with Royal Navy Blue (#1C2E66 to #2A3F7E)
tdraw3.polygon(arch_poly_4x, fill=(28, 46, 102, 255))
# Outer bevel
draw_smooth_rim_curve(tdraw3, pts_top_4x, 5.0 * SCALE, lambda t: (18, 30, 72, 255))
# Cyan/Navy rim line matching FEVER
def navy_rim_color(t):
    cf = math.sin(t * math.pi)
    r = int(45 + 30 * cf)
    g = int(85 + 40 * cf)
    b = int(195 + 45 * cf)
    return (r, g, b, 255)

draw_smooth_rim_curve(tdraw3, pts_top_4x, 3.2 * SCALE, navy_rim_color)
draw_smooth_rim_curve(tdraw3, pts_glint_4x, 1.3 * SCALE, lambda t: (180, 220, 255, int(220 * math.sin(t * math.pi))))

tray_opt3 = tray_hi_opt3.resize((W, H), Image.Resampling.LANCZOS)
comp_opt3 = Image.alpha_composite(tray_opt3, clean_base)
comp_opt3 = Image.alpha_composite(comp_opt3, clean_letters)
comp_opt3.save('/tmp/logo_opt3_navy_unified.png')
print("Option 3 (Unified Royal Navy Arch) saved to /tmp/logo_opt3_navy_unified.png")

print("All 3 options successfully generated!")
