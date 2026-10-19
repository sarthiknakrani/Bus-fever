import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

base = Image.open('/tmp/6452_logo.png').convert('RGBA')
W, H = base.size

# We will modify only the top purple region: x in [140, 590], y in [0, 65]
# Let's inspect how the arch looks at 4x supersampling

def create_arch_variant(apex_y, shoulder_y, x_left=148.0, x_right=582.0):
    img = base.copy()
    SCALE = 4
    SW, SH = W * SCALE, H * SCALE
    
    # Extract only the clean letters below y=42 in the region x in [140, 590]
    # And clear the old lumpy purple tray above y=45
    pix = img.load()
    
    # 1. Generate smooth arch points
    arch_pts = []
    x_center = (x_left + x_right) / 2.0
    
    # We use a cosine-based or parabolic smooth convex arch
    N_PTS = 200
    for i in range(N_PTS):
        u = i / float(N_PTS - 1)
        x = x_left + u * (x_right - x_left)
        # Cosine arch: from shoulder to apex to shoulder
        # theta in [0, pi]
        theta = u * math.pi
        # y = apex_y + (shoulder_y - apex_y) * (1.0 - math.sin(theta))
        # Even smoother: sin^0.85
        y = apex_y + (shoulder_y - apex_y) * (1.0 - math.sin(theta)**0.85)
        arch_pts.append((x, y))
        
    # Draw new purple tray and rim on 4x supersampled layer
    tray_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
    tdraw = ImageDraw.Draw(tray_hi)
    
    poly_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]
    poly_4x.append((x_right * SCALE, 68 * SCALE))
    poly_4x.append((x_left * SCALE, 68 * SCALE))
    
    # Rich royal purple gradient fill matching the existing badge
    # (#58247D to #3C1554)
    tdraw.polygon(poly_4x, fill=(78, 32, 105, 255))
    
    pts_top_4x = [(x * SCALE, y * SCALE) for (x, y) in arch_pts]
    
    # Multi-layer 3D glowing purple rim:
    # 1. Dark outer shadow bevel (width 5.0px, #260D3A)
    for i in range(len(pts_top_4x) - 1):
        tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(38, 13, 58, 255), width=int(round(4.8 * SCALE)))
        
    # 2. Main radiant purple line (width 3.4px, #A852EC -> #C46CFF -> #A852EC)
    for i in range(len(pts_top_4x) - 1):
        t = i / float(len(pts_top_4x) - 1)
        cf = math.sin(t * math.pi)
        r = int(168 + 28 * cf)
        g = int(82 + 26 * cf)
        b = int(236 + 19 * cf)
        tdraw.line([pts_top_4x[i], pts_top_4x[i+1]], fill=(r, g, b, 255), width=int(round(3.2 * SCALE)))
        
    # 3. Delicate sunlit specular glint (width 1.2px, #F5E6FF)
    for i in range(len(pts_top_4x) - 1):
        t = i / float(len(pts_top_4x) - 1)
        if 0.12 <= t <= 0.88:
            gt = (t - 0.12) / 0.76
            alpha = int(240 * (math.sin(gt * math.pi) ** 1.2))
            p0 = pts_top_4x[i]
            p1 = pts_top_4x[i+1]
            dx = p1[0] - p0[0]
            dy = p1[1] - p0[1]
            L = math.hypot(dx, dy)
            if L > 0:
                nx = -dy / L * 1.0 * SCALE
                ny = dx / L * 1.0 * SCALE
                tdraw.line([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny)], fill=(245, 230, 255, alpha), width=int(round(1.2 * SCALE)))

    tray_1x = tray_hi.resize((W, H), Image.Resampling.LANCZOS)
    
    # Composite:
    # Clear old lumpy region in base:
    # Any pixel above y=46 that is purple/rim or background
    for y in range(0, 60):
        for x in range(int(x_left) - 10, int(x_right) + 10):
            r, g, b, a = pix[x, y]
            # Don't erase candy letters if any exist at bottom
            is_candy = (r > 190 and g > 110 and b < 100) or (r > 210 and g > 160)
            if not is_candy:
                pix[x, y] = (0, 0, 0, 0)
                
    # Composite tray behind letters:
    # Tray is under the letters, letters on top
    comp = Image.alpha_composite(tray_1x, img)
    return comp

# Generate 3 options:
opt_A = create_arch_variant(apex_y=20.0, shoulder_y=54.0)
opt_A.save('/tmp/logo_var_A_crown.png')

opt_B = create_arch_variant(apex_y=24.0, shoulder_y=54.0)
opt_B.save('/tmp/logo_var_B_mid.png')

opt_C = create_arch_variant(apex_y=27.0, shoulder_y=54.0)
opt_C.save('/tmp/logo_var_C_low.png')

print("All 3 purple line variants generated successfully.")

# Now render live home screen simulation for each
bg = Image.open('assets/home_bg_retina.jpg').convert('RGBA')
bw, bh = bg.size

for name, logo_img in [('var_A_crown', opt_A), ('var_B_mid', opt_B), ('var_C_low', opt_C)]:
    scaled = logo_img.resize((int(732 * 0.54), int(664 * 0.54)), Image.Resampling.LANCZOS)
    screen = bg.copy()
    lx = (bw - scaled.size[0]) // 2
    ly = 80
    screen.alpha_composite(scaled, (lx, ly))
    
    # Save crop showing top sky, clouds, and BUS text with the purple line
    crop = screen.crop((lx - 20, ly - 20, lx + scaled.size[0] + 20, ly + 180))
    crop.save(f'/tmp/screen_{name}.png')
    print(f'Saved /tmp/screen_{name}.png')
