import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/logo_with_bus.png').convert('RGBA')
w, h = base.size
base_pix = base.load()

# -------------------------------------------------------------------------
# Step 1: Build the Pristine Letters Layer at 8x Supersampling for Subpixel Smoothness
# -------------------------------------------------------------------------
SCALE = 4
sw, sh = w * SCALE, h * SCALE

# Start by extracting existing pristine pixels of B, U, S into an RGBA layer
letters_1x = Image.new('RGBA', (w, h), (0, 0, 0, 0))
lpix = letters_1x.load()

# 1. Base copy below y=446
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

# 2. Pristine top of B (x=325..408, y=438..446)
for y in range(438, 446):
    for x in range(325, 409):
        r, g, b, a = base_pix[x, y]
        if a > 80 and (r > 130 or g > 60):
            lpix[x, y] = (r, g, b, a)

# 3. Pristine top of S (x=665..760, y=438..446)
for y in range(438, 446):
    for x in range(665, 760):
        r, g, b, a = base_pix[x, y]
        if a > 80 and (r > 130 or g > 60):
            lpix[x, y] = (r, g, b, a)

# Upscale to supersampled canvas for surgical sculpting
letters_hi = letters_1x.resize((sw, sh), Image.Resampling.LANCZOS)
lpix_hi = letters_hi.load()

# Function to sculpt a 3D candy dome
def render_candy_dome(cx_1x, cy_base_1x, rx_1x, ry_1x, y_bottom_1x, gloss_x_offset=-0.2):
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
            
            # Dome curve at this x
            cur_y_top = cy_base - ry * math.sqrt(max(0.0, 1.0 - dx * dx))
            
            # Distance from outer dome edge (positive inside, negative outside)
            dist_from_edge = y - cur_y_top
            if dist_from_edge < -1.0:
                continue
            
            # Anti-aliasing alpha factor at top edge
            alpha_edge = min(1.0, max(0.0, dist_from_edge + 1.0))
            
            # Normalised depth inside dome [0.0 = top edge, 1.0 = deep body]
            # Dome height in pixels
            total_depth = (y_bot - cur_y_top)
            t_depth = max(0.0, min(1.0, dist_from_edge / max(1.0, total_depth)))
            
            bevel_thickness = 5.2 * SCALE
            gloss_start = bevel_thickness
            gloss_end = 11.0 * SCALE
            
            # Shading layers:
            if dist_from_edge < bevel_thickness:
                # OUTER GOLDEN BEVEL
                # Outer bevel gradient: bright sunny gold on top to rich amber gold
                u_bevel = dist_from_edge / bevel_thickness
                if u_bevel < 0.25:
                    # Dark accent rim on absolute outer perimeter
                    r_col = int(140 + u_bevel * 4 * 115)
                    g_col = int(40 + u_bevel * 4 * 160)
                    b_col = int(25 + u_bevel * 4 * 65)
                else:
                    # Vibrant sunny gold (#FFE082 to #FFA000)
                    t_b = (u_bevel - 0.25) / 0.75
                    r_col = int(255 * (1 - t_b) + 255 * t_b)
                    g_col = int(218 * (1 - t_b) + 165 * t_b)
                    b_col = int(105 * (1 - t_b) + 55 * t_b)
            else:
                # INNER CANDY CUSHION & SPECULAR GLOSS
                # Base candy orange gradient vertically
                t_vert = (y - y_top) / float(max(1, y_bot - y_top))
                base_r = 255
                base_g = int(165 * (1 - t_vert) + 138 * t_vert)
                base_b = int(95 * (1 - t_vert) + 80 * t_vert)
                
                # Specular gloss highlight:
                # Centered around (cx + gloss_x_offset * rx, cy_base - ry * 0.45)
                gx = cx + gloss_x_offset * rx
                gy = cy_base - ry * 0.35
                dist_gloss = math.hypot((x - gx) / (rx * 0.55), (y - gy) / (ry * 0.45))
                gloss_factor = max(0.0, 1.0 - dist_gloss)
                gloss_factor = math.pow(gloss_factor, 1.8)
                
                # Blend specular highlight (warm ivory-white gloss #FFFDF0)
                r_col = int(base_r * (1 - gloss_factor) + 255 * gloss_factor)
                g_col = int(base_g * (1 - gloss_factor) + 248 * gloss_factor)
                b_col = int(base_b * (1 - gloss_factor) + 225 * gloss_factor)
            
            # Blend smoothly with existing pixels near y_bot
            cur_a = int(255 * alpha_edge)
            if y > y_bot - (3 * SCALE):
                blend_t = (y_bot - y) / float(3 * SCALE)
                # Alpha blend over existing
                old = lpix_hi[x, y]
                if old[3] > 0:
                    r_col = int(r_col * blend_t + old[0] * (1 - blend_t))
                    g_col = int(g_col * blend_t + old[1] * (1 - blend_t))
                    b_col = int(b_col * blend_t + old[2] * (1 - blend_t))
            
            lpix_hi[x, y] = (r_col, g_col, b_col, max(lpix_hi[x, y][3], cur_a))

# Sculpt Left Pillar Dome of U (cx=500.0, rx=24.0, ry=12.0, base at y=448, bottom blend at y=450)
render_candy_dome(500.0, 448.0, 24.0, 12.0, 451.0, gloss_x_offset=-0.25)

# Sculpt Right Pillar Dome of U (cx=598.5, rx=23.5, ry=12.0, base at y=448, bottom blend at y=451)
render_candy_dome(598.5, 448.0, 23.5, 12.0, 451.0, gloss_x_offset=-0.20)

# Sculpt Golden Bevel on top-right curve of B (x=405..435, y=438..452)
# Parabolic arch curving down from (405, 439) to (432, 452)
for x_1x in range(405, 434):
    t = (x_1x - 405) / float(433 - 405)
    y_arc_1x = 439.0 + 13.0 * (t * t)
    
    # Draw a 5.2px golden stroke along this curve
    for dy_1x in [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]:
        y_pt_1x = y_arc_1x + dy_1x
        sx = int(round(x_1x * SCALE))
        sy = int(round(y_pt_1x * SCALE))
        if 0 <= sx < sw and 0 <= sy < sh:
            u_b = (dy_1x + 1.5) / 5.5
            if u_b < 0.2:
                col = (140, 40, 25, 255)
            elif u_b < 0.8:
                col = (255, 195, 75, 255)
            else:
                col = (255, 150, 70, 255)
            for ox in range(SCALE):
                for oy in range(SCALE):
                    lpix_hi[sx + ox, sy + oy] = col

# Sculpt Golden Bevel on top-left curve of S (x=645..670, y=438..452)
for x_1x in range(645, 671):
    t = (670 - x_1x) / float(670 - 645)
    y_arc_1x = 439.0 + 13.0 * (t * t)
    for dy_1x in [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]:
        y_pt_1x = y_arc_1x + dy_1x
        sx = int(round(x_1x * SCALE))
        sy = int(round(y_pt_1x * SCALE))
        if 0 <= sx < sw and 0 <= sy < sh:
            u_b = (dy_1x + 1.5) / 5.5
            if u_b < 0.2:
                col = (140, 40, 25, 255)
            elif u_b < 0.8:
                col = (255, 195, 75, 255)
            else:
                col = (255, 150, 70, 255)
            for ox in range(SCALE):
                for oy in range(SCALE):
                    lpix_hi[sx + ox, sy + oy] = col

# Downsample sculpted letters to 1x with Lanczos for razor-sharp antialiasing
clean_letters_1x = letters_hi.resize((w, h), Image.Resampling.LANCZOS)
clean_letters_1x.save('/tmp/clean_letters_1x.png')
print('Flawless 3D sculpted letters created and saved to /tmp/clean_letters_1x.png!')
