#!/usr/bin/env python3
"""
BUS PARTY — High-End 3D Casual Mobile Game Logo Generator
Generates a studio-quality 3D-extruded, candy-glossed, multicolor game logo
with per-letter vibrant hues, unified badge silhouette, and rich lighting.
"""

import math, os
from PIL import Image, ImageFont, ImageDraw, ImageFilter, ImageChops

FONT_PATH = "assets/fonts/arial_rounded_bold.ttf"
OUTPUT_PNG = "assets/ui/logo/bus_party_logo.png"
LEGACY_OUTPUT_PNG = "assets/ui/logo/bus_fever_party_logo.png"

CANVAS_W = 1400
CANVAS_H = 900
CENTER_X = CANVAS_W // 2

# Harmonious, super-vibrant casual palette
# [highlight, face_top, face_bottom, bevel_shade, ext_top, ext_mid, ext_base]
LETTER_PALETTES = {
    # Line 1: B U S
    "B": {
        "name": "Golden Yellow",
        "highlight": (255, 255, 220),
        "face_top": (255, 230, 45),
        "face_bottom": (255, 170, 0),
        "bevel_shade": (235, 130, 0),
        "ext_top": (215, 95, 0),
        "ext_mid": (175, 55, 0),
        "ext_base": (95, 20, 0),
    },
    "U": {
        "name": "Vivid Orange",
        "highlight": (255, 240, 210),
        "face_top": (255, 140, 20),
        "face_bottom": (245, 80, 0),
        "bevel_shade": (210, 55, 0),
        "ext_top": (185, 40, 0),
        "ext_mid": (145, 20, 0),
        "ext_base": (80, 10, 0),
    },
    "S": {
        "name": "Crimson Red",
        "highlight": (255, 225, 230),
        "face_top": (255, 60, 75),
        "face_bottom": (225, 15, 35),
        "bevel_shade": (190, 5, 25),
        "ext_top": (165, 0, 20),
        "ext_mid": (125, 0, 15),
        "ext_base": (70, 0, 10),
    },
    # Line 2: P A R T Y
    "P": {
        "name": "Sunny Yellow",
        "highlight": (255, 255, 220),
        "face_top": (255, 235, 55),
        "face_bottom": (255, 190, 10),
        "bevel_shade": (235, 150, 0),
        "ext_top": (210, 105, 0),
        "ext_mid": (170, 70, 0),
        "ext_base": (95, 30, 0),
    },
    "A": {
        "name": "Ruby Magenta",
        "highlight": (255, 225, 235),
        "face_top": (255, 45, 100),
        "face_bottom": (220, 10, 60),
        "bevel_shade": (180, 0, 40),
        "ext_top": (145, 0, 30),
        "ext_mid": (105, 0, 20),
        "ext_base": (55, 0, 10),
    },
    "R": {
        "name": "Emerald Mint",
        "highlight": (225, 255, 240),
        "face_top": (20, 235, 145),
        "face_bottom": (0, 190, 105),
        "bevel_shade": (0, 150, 75),
        "ext_top": (0, 115, 55),
        "ext_mid": (0, 85, 40),
        "ext_base": (0, 45, 20),
    },
    "T": {
        "name": "Tangerine Orange",
        "highlight": (255, 238, 215),
        "face_top": (255, 125, 20),
        "face_bottom": (235, 75, 0),
        "bevel_shade": (200, 50, 0),
        "ext_top": (165, 35, 0),
        "ext_mid": (125, 20, 0),
        "ext_base": (70, 10, 0),
    },
    "Y": {
        "name": "Azure Sky Blue",
        "highlight": (225, 248, 255),
        "face_top": (30, 190, 255),
        "face_bottom": (0, 140, 235),
        "bevel_shade": (0, 110, 190),
        "ext_top": (0, 80, 155),
        "ext_mid": (0, 55, 115),
        "ext_base": (0, 25, 65),
    },
}

def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return (
        int(c1[0] + (c2[0] - c1[0]) * t),
        int(c1[1] + (c2[1] - c1[1]) * t),
        int(c1[2] + (c2[2] - c1[2]) * t),
    )

def render_gradient_vertical(w, h, c_top, c_bottom):
    grad = Image.new("RGBA", (w, h))
    pixels = grad.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = lerp_color(c_top, c_bottom, t)
        for x in range(w):
            pixels[x, y] = (c[0], c[1], c[2], 255)
    return grad

def create_letter_image(char_key, font_size=200, stroke_w=8, depth=26):
    """
    Renders an individual letter with:
    - 3D extrusion with directional light & occlusion base
    - Front face vertical gradient
    - Crisp inner bevel rim & shadow
    - Candy pill specular gloss
    """
    pal = LETTER_PALETTES[char_key]
    char = pal.get("char", char_key)
    font = ImageFont.truetype(FONT_PATH, font_size)

    bbox = font.getbbox(char)
    gw = bbox[2] - bbox[0] + stroke_w * 2 + 10
    gh = bbox[3] - bbox[1] + stroke_w * 2 + 10

    buf_w = gw + 60
    buf_h = gh + depth + 60
    origin_x = 30 - bbox[0] + stroke_w
    origin_y = 30 - bbox[1] + stroke_w

    letter_img = Image.new("RGBA", (buf_w, buf_h), (0, 0, 0, 0))

    # Base glyph mask (thick, rounded, bold)
    base_mask = Image.new("L", (buf_w, buf_h), 0)
    d_base = ImageDraw.Draw(base_mask)
    d_base.text((origin_x, origin_y), char, font=font, fill=255, stroke_width=stroke_w)

    # 1. 3D Extrusion (downward projection with depth)
    for step in range(depth, 0, -1):
        t = (depth - step) / float(depth)
        if t < 0.5:
            c = lerp_color(pal["ext_base"], pal["ext_mid"], t * 2.0)
        else:
            c = lerp_color(pal["ext_mid"], pal["ext_top"], (t - 0.5) * 2.0)

        step_img = Image.new("RGBA", (buf_w, buf_h), (0, 0, 0, 0))
        d_step = ImageDraw.Draw(step_img)
        d_step.text((origin_x, origin_y + step), char, font=font, fill=(c[0], c[1], c[2], 255), stroke_width=stroke_w)
        letter_img = Image.alpha_composite(letter_img, step_img)

    # 2. Crease shadow at bottom of front face (gives physical depth separation)
    crease_mask = ImageChops.subtract(
        ImageChops.offset(base_mask, 0, 3),
        base_mask
    )
    crease_img = Image.new("RGBA", (buf_w, buf_h), (0, 0, 0, 180))
    letter_img.paste(crease_img, (0, 0), mask=crease_mask)

    # 3. Front Face Gradient
    face_grad = render_gradient_vertical(buf_w, buf_h, pal["face_top"], pal["face_bottom"])
    face_img = Image.new("RGBA", (buf_w, buf_h), (0, 0, 0, 0))
    face_img.paste(face_grad, (0, 0), mask=base_mask)

    # 4. Inner Bevel Highlight (sunlit rim at top-left)
    shifted_mask = ImageChops.offset(base_mask, 0, 3)
    rim_top_mask = ImageChops.subtract(base_mask, shifted_mask)
    rim_img = Image.new("RGBA", (buf_w, buf_h), (pal["highlight"][0], pal["highlight"][1], pal["highlight"][2], 200))
    face_img.paste(rim_img, (0, 0), mask=rim_top_mask)

    # 5. Inner Bevel Shade (rim shadow at bottom-right)
    shifted_up_mask = ImageChops.offset(base_mask, 0, -3)
    rim_btm_mask = ImageChops.subtract(base_mask, shifted_up_mask)
    shade_img = Image.new("RGBA", (buf_w, buf_h), (pal["bevel_shade"][0], pal["bevel_shade"][1], pal["bevel_shade"][2], 175))
    face_img.paste(shade_img, (0, 0), mask=rim_btm_mask)

    # 6. Candy Pill Specular Gloss (curved upper highlight)
    gloss_mask = Image.new("L", (buf_w, buf_h), 0)
    d_gloss = ImageDraw.Draw(gloss_mask)
    gloss_rect = (origin_x - 12, origin_y - 12, origin_x + gw + 12, origin_y + int(gh * 0.42))
    d_gloss.ellipse(gloss_rect, fill=180)
    gloss_mask = ImageChops.multiply(gloss_mask, base_mask)

    # Vertical gloss fade
    for y in range(buf_h):
        fade = max(0, 1.0 - (y - origin_y) / float(gh * 0.42))
        for x in range(buf_w):
            val = gloss_mask.getpixel((x, y))
            if val > 0:
                gloss_mask.putpixel((x, y), int(val * fade * 0.8))

    gloss_color = Image.new("RGBA", (buf_w, buf_h), (255, 255, 255, 255))
    face_img.paste(gloss_color, (0, 0), mask=gloss_mask)

    # Composite front face on extrusion
    letter_img = Image.alpha_composite(letter_img, face_img)

    return letter_img, base_mask, (gw, gh, depth)

def draw_diamond_sparkle(img, cx, cy, radius=22, color=(255, 255, 255, 255)):
    # Render sparkle with soft blurred aura and crisp 4-point star flare
    sparkle_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d_aura = ImageDraw.Draw(sparkle_layer)
    glow_r = int(radius * 0.6)
    d_aura.ellipse((cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r), fill=(color[0], color[1], color[2], 120))
    sparkle_layer = sparkle_layer.filter(ImageFilter.GaussianBlur(3))

    star_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d_star = ImageDraw.Draw(star_layer)
    points = [
        (cx, cy - radius),
        (cx + radius * 0.20, cy - radius * 0.20),
        (cx + radius, cy),
        (cx + radius * 0.20, cy + radius * 0.20),
        (cx, cy + radius),
        (cx - radius * 0.20, cy + radius * 0.20),
        (cx - radius, cy),
        (cx - radius * 0.20, cy - radius * 0.20),
    ]
    d_star.polygon(points, fill=color)
    core_r = int(radius * 0.22)
    d_star.ellipse((cx - core_r, cy - core_r, cx + core_r, cy + core_r), fill=(255, 255, 255, 255))

    img.alpha_composite(sparkle_layer)
    img.alpha_composite(star_layer)

def generate_logo():
    print("=== GENERATING 3D CASUAL GAME TITLE LOGO: BUS PARTY ===")

    # Layout configuration
    # 2 lines: Line 1 = BUS (3 letters), Line 2 = PARTY (5 letters)
    # Forms an exquisitely balanced, candy-glossed casual badge
    lines_def = [
        # Line 1: BUS
        {
            "keys": ["B", "U", "S"],
            "font_size": 250,
            "stroke_w": 9,
            "depth": 28,
            "y_pos": 140,
            "spacing": -16, # snug overlap
            "angles": [-2.0, 0.0, 2.0],
            "y_offsets": [3, -3, 3]
        },
        # Line 2: PARTY
        {
            "keys": ["P", "A", "R", "T", "Y"],
            "font_size": 215,
            "stroke_w": 8,
            "depth": 26,
            "y_pos": 375,
            "spacing": -14, # snug overlap
            "angles": [-2.5, -1.2, 0.0, 1.2, 2.5],
            "y_offsets": [2, -2, 0, -2, 2]
        }
    ]

    rendered_letters = []
    
    for line in lines_def:
        f_sz = line["font_size"]
        st_w = line["stroke_w"]
        dp = line["depth"]
        spacing = line["spacing"]
        
        line_items = []
        total_w = 0
        
        for idx, k in enumerate(line["keys"]):
            lim, lmask, dims = create_letter_image(k, font_size=f_sz, stroke_w=st_w, depth=dp)
            # Crop to actual bounding box so spacing controls true letter overlap
            lbbox = lim.getbbox()
            if lbbox:
                lim = lim.crop(lbbox)
                lmask = lmask.crop(lbbox)

            angle = line["angles"][idx]
            y_off = line["y_offsets"][idx]
            
            if abs(angle) > 0.01:
                lim = lim.rotate(angle, resample=Image.BICUBIC, expand=True)
                lmask = lmask.rotate(angle, resample=Image.BICUBIC, expand=True)
                lbbox = lim.getbbox()
                if lbbox:
                    lim = lim.crop(lbbox)
                    lmask = lmask.crop(lbbox)
                
            line_items.append({
                "key": k,
                "img": lim,
                "mask": lmask,
                "w": lim.width,
                "h": lim.height,
                "y_off": y_off
            })
            total_w += lim.width + spacing
        
        total_w -= spacing
        start_x = CENTER_X - (total_w // 2)
        curr_x = start_x
        
        for item in line_items:
            item["pos_x"] = curr_x
            item["pos_y"] = line["y_pos"] + item["y_off"]
            rendered_letters.append(item)
            curr_x += item["w"] + spacing

    final_canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))

    # Combined Silhouette Mask
    combined_mask = Image.new("L", (CANVAS_W, CANVAS_H), 0)
    for l in rendered_letters:
        letter_alpha = l["img"].split()[3]
        combined_mask.paste(letter_alpha, (l["pos_x"], l["pos_y"]), mask=letter_alpha)

    # 1. Soft Ambient Drop Shadow
    shadow_mask = combined_mask.filter(ImageFilter.MaxFilter(17))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(18))
    shadow_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (8, 12, 30, 130))
    final_canvas.paste(shadow_layer, (0, 26), mask=shadow_mask)

    # 2. Deep Indigo/Navy Backing Hull (Balanced outline)
    hull_mask = combined_mask.filter(ImageFilter.MaxFilter(17))
    hull_grad = render_gradient_vertical(CANVAS_W, CANVAS_H, (24, 32, 64), (10, 14, 32))
    hull_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    hull_layer.paste(hull_grad, (0, 0), mask=hull_mask)
    
    # 3D bottom bevel on hull
    hull_bottom_mask = ImageChops.subtract(
        ImageChops.offset(hull_mask, 0, 6),
        hull_mask
    )
    hull_bottom_dark = Image.new("RGBA", (CANVAS_W, CANVAS_H), (4, 6, 16, 255))
    final_canvas = Image.alpha_composite(final_canvas, hull_layer)
    final_canvas.paste(hull_bottom_dark, (0, 0), mask=hull_bottom_mask)

    # 3. Thin, Crisp White Sticker Border (MaxFilter 5 = ~2.5px crisp highlight rim)
    border_mask = combined_mask.filter(ImageFilter.MaxFilter(5))
    border_grad = render_gradient_vertical(CANVAS_W, CANVAS_H, (255, 255, 255), (235, 242, 252))
    border_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    border_layer.paste(border_grad, (0, 0), mask=border_mask)
    final_canvas = Image.alpha_composite(final_canvas, border_layer)

    # 4. Individual 3D Letters (rendered in sequence with letter-on-letter soft cast shadows)
    for l in rendered_letters:
        # Cast soft shadow from this letter onto previous letters
        l_alpha = l["img"].split()[3]
        l_shadow_mask = l_alpha.filter(ImageFilter.GaussianBlur(5))
        l_shadow = Image.new("RGBA", (l["w"], l["h"]), (0, 0, 0, 80))
        final_canvas.paste(l_shadow, (l["pos_x"] + 3, l["pos_y"] + 5), mask=l_shadow_mask)

        # Composite the letter
        final_canvas.alpha_composite(l["img"], (l["pos_x"], l["pos_y"]))

    # 5. Diamond Star Sparkles (Placed across BUS PARTY letters)
    sparkles = [
        (rendered_letters[0]["pos_x"] + 50, rendered_letters[0]["pos_y"] + 45, 22, (255, 255, 225, 255)),  # B
        (rendered_letters[2]["pos_x"] + 120, rendered_letters[2]["pos_y"] + 70, 20, (255, 235, 235, 255)), # S
        (rendered_letters[3]["pos_x"] + 45, rendered_letters[3]["pos_y"] + 45, 22, (255, 255, 210, 255)),  # P
        (rendered_letters[5]["pos_x"] + 50, rendered_letters[5]["pos_y"] + 40, 18, (225, 255, 240, 255)),  # R
        (rendered_letters[7]["pos_x"] + 100, rendered_letters[7]["pos_y"] + 45, 24, (225, 250, 255, 255)), # Y
    ]
    for sp in sparkles:
        draw_diamond_sparkle(final_canvas, sp[0], sp[1], sp[2], sp[3])

    # Crop tightly with padding
    bbox = final_canvas.getbbox()
    pad = 25
    crop_box = (
        max(0, bbox[0] - pad),
        max(0, bbox[1] - pad),
        min(CANVAS_W, bbox[2] + pad),
        min(CANVAS_H, bbox[3] + pad)
    )
    cropped = final_canvas.crop(crop_box)
    os.makedirs(os.path.dirname(OUTPUT_PNG), exist_ok=True)
    cropped.save(OUTPUT_PNG, "PNG", optimize=True)
    print(f"SUCCESS! Rendered 3D logo saved to {OUTPUT_PNG} ({cropped.width}x{cropped.height} px)")
    
    # Also save to legacy path for backward compatibility
    cropped.save(LEGACY_OUTPUT_PNG, "PNG", optimize=True)
    print(f"Saved copy to legacy path {LEGACY_OUTPUT_PNG}")

if __name__ == "__main__":
    generate_logo()
