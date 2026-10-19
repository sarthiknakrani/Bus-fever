import math
import colorsys
from PIL import Image, ImageDraw, ImageFilter

bg = Image.open('assets/home_bg_retina.jpg').convert('RGBA')
bw, bh = bg.size

for opt_num, opt_name in [(1, 'option1_tight_bevel'), (2, 'option2_pure_letters'), (3, 'option3_smooth_arch')]:
    logo_base = Image.open(f'/tmp/{opt_name}.png').convert('RGBA')
    
    # Recolor P face and extrusion
    fpix = logo_base.load()
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

    # Crop tight bounding box
    bbox = logo_base.getbbox()
    cropped = logo_base.crop(bbox)
    cw, ch = cropped.size
    master = Image.new('RGBA', (732, 664), (0, 0, 0, 0))
    master.alpha_composite(cropped, ((732 - cw)//2, (664 - ch)//2))
    master = master.filter(ImageFilter.UnsharpMask(radius=1.2, percent=135, threshold=1))
    master.save(f'/tmp/final_logo_opt{opt_num}.png')
    
    # Overlay on home screen background at actual HUD scale (~0.58)
    sim_screen = bg.copy()
    scaled_logo = master.resize((int(732 * 0.54), int(664 * 0.54)), Image.Resampling.LANCZOS)
    # Position centered at top clouds (y=80)
    lx = (bw - scaled_logo.size[0]) // 2
    ly = 80
    sim_screen.alpha_composite(scaled_logo, (lx, ly))
    
    # Crop top region showing clouds and BUS text
    preview_crop = sim_screen.crop((lx - 20, ly - 20, lx + scaled_logo.size[0] + 20, ly + 180))
    preview_crop.save(f'/tmp/preview_screen_opt{opt_num}.png')
    print(f'Option {opt_num} rendered and saved to /tmp/preview_screen_opt{opt_num}.png!')
