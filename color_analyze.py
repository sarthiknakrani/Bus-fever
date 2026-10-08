from PIL import Image
import os
import colorsys

for f in sorted(os.listdir('assets/ui')):
    if not f.endswith('.png'): continue
    img = Image.open(f"assets/ui/{f}").convert("RGBA")
    w, h = img.size
    pixels = img.getdata()
    
    r_sum = g_sum = b_sum = count = 0
    for p in pixels:
        if p[3] > 128:
            r_sum += p[0]
            g_sum += p[1]
            b_sum += p[2]
            count += 1
            
    if count == 0: continue
    
    avg_r = r_sum // count
    avg_g = g_sum // count
    avg_b = b_sum // count
    
    h_sv, l, s = colorsys.rgb_to_hls(avg_r/255.0, avg_g/255.0, avg_b/255.0)
    
    color_name = "Gray"
    if s > 0.3:
        h_deg = h_sv * 360
        if h_deg < 30 or h_deg > 330: color_name = "Red"
        elif h_deg < 60: color_name = "Orange/Yellow"
        elif h_deg < 150: color_name = "Green"
        elif h_deg < 240: color_name = "Blue"
        elif h_deg < 300: color_name = "Purple"
        elif h_deg < 330: color_name = "Pink"
        
    print(f"{f} ({w}x{h}): AvgColorRGB({avg_r},{avg_g},{avg_b}) - {color_name}")
