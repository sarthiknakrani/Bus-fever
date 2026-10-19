import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

# 1. Load clean original master image
src = Image.open('test_transparent_logo_clean.png').convert('RGBA')
W, H = src.size

SCALE = 4
SW, SH = W * SCALE, H * SCALE

# -------------------------------------------------------------------------
# A. Isolate clean BUS letters (B, U, S)
# -------------------------------------------------------------------------
# We extract only the candy letters B, U, S without any old bus or background.
letters = Image.new('RGBA', (W, H), (0, 0, 0, 0))
src_pix = src.load()
l_pix = letters.load()

# B: x in [155, 335], y in [215, 455]
# U: x in [335, 485], y in [230, 455]
# S: x in [485, 665], y in [195, 455]

for y in range(190, 455):
    for x in range(150, 675):
        r, g, b, a = src_pix[x, y]
        if a < 40:
            continue
        # Exclude yellow toy bus parts (bright pale yellow roof/windshield/tires)
        is_yellow_bus = (r > 230 and g > 195 and b < 120 and y < 240)
        is_bus_glass = (b > 180 and g > 160 and r < 120 and y < 240)
        is_bus_tire = (r < 70 and g < 70 and b < 70 and y < 245)
        is_purple_bg = (b > 80 and r > 40 and g < 60 and (b > r or r - b < 25) and a > 100)
        
        # Check if pixel belongs to candy letter body or golden bevel
        # Candy body: warm red/orange/gold
        is_candy_red = (r > 160 and g < 140 and b < 80)
        is_candy_orange = (r > 200 and g > 100 and b < 110)
        is_candy_gold = (r > 180 and g > 140 and b < 90)
        is_candy_highlight = (r > 235 and g > 200 and b > 140)
        
        # Don't include purple valleys or tires
        if (is_candy_red or is_candy_orange or is_candy_gold or is_candy_highlight):
            if not is_yellow_bus and not is_bus_glass and not is_bus_tire:
                l_pix[x, y] = (r, g, b, a)

# Also capture the bottom loops of B, U, S down to y=450
for y in range(240, 455):
    for x in range(150, 675):
        r, g, b, a = src_pix[x, y]
        if a > 80:
            # check if not navy blue fever tray
            is_navy = (b > 100 and g < 80 and r < 60)
            is_purple = (r > 50 and b > 80 and g < 50)
            if not is_navy and not is_purple:
                if l_pix[x, y][3] == 0:
                    # check if candy color
                    if r > 140 or (r > 100 and g > 50 and b < 60):
                        l_pix[x, y] = (r, g, b, a)

print("Candy letters initial extraction done.")

# -------------------------------------------------------------------------
# B. High-Res 4x Sculpting of U Domes
# -------------------------------------------------------------------------
letters_hi = letters.resize((SW, SH), Image.Resampling.LANCZOS)
lpix_hi = letters_hi.load()

def draw_candy_dome_4x(cx_1x, cy_base_1x, rx_1x, ry_1x, y_bottom_1x):
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
            bevel_th = 5.2 * SCALE
            
            if dist_from_edge < bevel_th:
                # Golden Candy Bevel matching U
                u_b = dist_from_edge / bevel_th
                if u_b < 0.22:
                    r_c = int(140 + u_b * 4.5 * 115)
                    g_c = int(40 + u_b * 4.5 * 160)
                    b_c = int(25 + u_b * 4.5 * 65)
                else:
                    tb = (u_b - 0.22) / 0.78
                    r_c = int(255 * (1 - tb) + 255 * tb)
                    g_c = int(218 * (1 - tb) + 165 * tb)
                    b_c = int(105 * (1 - tb) + 55 * tb)
            else:
                # Juicy Candy Body Fill
                norm_y = (y - (cy_base - ry)) / float(ry * 2.2)
                norm_y = min(1.0, max(0.0, norm_y))
                r_c = 255
                g_c = int(178 * (1.0 - norm_y * 0.45))
                b_c = int(82 * (1.0 - norm_y * 0.70))
                
                # Specular curved gloss glint (top left)
                glint_dx = (x - (cx - rx * 0.25)) / (rx * 0.55)
                glint_dy = (y - (cy_base - ry * 0.65)) / (ry * 0.45)
                d_sq = glint_dx * glint_dx + glint_dy * glint_dy
                if d_sq < 1.0:
                    shine_str = (1.0 - math.sqrt(d_sq)) ** 1.3 * 0.95
                    r_c = int(r_c * (1 - shine_str) + 255 * shine_str)
                    g_c = int(g_c * (1 - shine_str) + 255 * shine_str)
                    b_c = int(b_c * (1 - shine_str) + 255 * shine_str)
            
            lpix_hi[x, y] = (r_c, g_c, b_c, int(255 * alpha_edge))

# Left stem of U: center x=371, cy_base=244, rx=19.5, ry=19.0
draw_candy_dome_4x(371.0, 244.0, 19.5, 19.0, 248.0)
# Right stem of U: center x=451, cy_base=244, rx=24.0, ry=20.0
draw_candy_dome_4x(451.0, 244.0, 24.0, 20.0, 248.0)

clean_bus_letters = letters_hi.resize((W, H), Image.Resampling.LANCZOS)
clean_bus_letters.save('/tmp/clean_bus_letters.png')
print("Pristine sculpted BUS letters saved to /tmp/clean_bus_letters.png")
