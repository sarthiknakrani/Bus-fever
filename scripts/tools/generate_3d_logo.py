#!/usr/bin/env python3
"""
BUS PARTY — High-End 3D Casual Mobile Game Logo Generator
Generates a studio-quality 3D-extruded, candy-glossed, multicolor game logo
with per-letter vibrant hues, unified badge silhouette, road banner, and rich lighting.
"""

import math, os
from PIL import Image, ImageFont, ImageDraw, ImageFilter, ImageChops

FONT_PATH = "assets/fonts/arial_rounded_bold.ttf"
OUTPUT_PNG = "assets/ui/logo/bus_party_logo.png"
BADGE_PNG = "assets/ui/logo/bus_party_logo_badge.png"
LEGACY_PNG = "assets/ui/logo/bus_fever_party_logo.png"

CANVAS_W = 1200
CANVAS_H = 1000
CENTER_X = CANVAS_W // 2

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

    base_mask = Image.new("L", (buf_w, buf_h), 0)
    d_base = ImageDraw.Draw(base_mask)
    d_base.text((origin_x, origin_y), char, font=font, fill=255, stroke_width=stroke_w)

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

    crease_mask = ImageChops.subtract(ImageChops.offset(base_mask, 0, 3), base_mask)
    crease_img = Image.new("RGBA", (buf_w, buf_h), (0, 0, 0, 180))
    letter_img.paste(crease_img, (0, 0), mask=crease_mask)

    face_grad = render_gradient_vertical(buf_w, buf_h, pal["face_top"], pal["face_bottom"])
    face_img = Image.new("RGBA", (buf_w, buf_h), (0, 0, 0, 0))
    face_img.paste(face_grad, (0, 0), mask=base_mask)

    shifted_mask = ImageChops.offset(base_mask, 0, 3)
    rim_top_mask = ImageChops.subtract(base_mask, shifted_mask)
    rim_img = Image.new("RGBA", (buf_w, buf_h), (pal["highlight"][0], pal["highlight"][1], pal["highlight"][2], 200))
    face_img.paste(rim_img, (0, 0), mask=rim_top_mask)

    shifted_up_mask = ImageChops.offset(base_mask, 0, -3)
    rim_btm_mask = ImageChops.subtract(base_mask, shifted_up_mask)
    shade_img = Image.new("RGBA", (buf_w, buf_h), (pal["bevel_shade"][0], pal["bevel_shade"][1], pal["bevel_shade"][2], 175))
    face_img.paste(shade_img, (0, 0), mask=rim_btm_mask)

    gloss_mask = Image.new("L", (buf_w, buf_h), 0)
    d_gloss = ImageDraw.Draw(gloss_mask)
    gloss_rect = (origin_x - 12, origin_y - 12, origin_x + gw + 12, origin_y + int(gh * 0.42))
    d_gloss.ellipse(gloss_rect, fill=180)
    gloss_mask = ImageChops.multiply(gloss_mask, base_mask)

    for y in range(buf_h):
        fade = max(0, 1.0 - (y - origin_y) / float(gh * 0.42))
        for x in range(buf_w):
            val = gloss_mask.getpixel((x, y))
            if val > 0:
                gloss_mask.putpixel((x, y), int(val * fade * 0.8))

    gloss_color = Image.new("RGBA", (buf_w, buf_h), (255, 255, 255, 255))
    face_img.paste(gloss_color, (0, 0), mask=gloss_mask)

    letter_img = Image.alpha_composite(letter_img, face_img)
    return letter_img, base_mask, (gw, gh, depth)

def draw_palm_frond(img, cx, cy, angle_deg, scale=1.0, flip=False):
    frond_layer = Image.new("RGBA", (650, 550), (0, 0, 0, 0))
    base_x, base_y = 325, 460

    leaflets = [
        (-42, 190, 52, (140, 230, 20), (45, 140, 10)),
        (-18, 235, 58, (160, 245, 25), (55, 160, 10)),
        (14, 225, 56, (145, 235, 20), (50, 145, 10)),
        (42, 185, 48, (130, 220, 15), (40, 130, 10)),
    ]

    for a_off, length, width, c_top, c_btm in leaflets:
        rad = math.radians(a_off - 90)
        tip_x = base_x + int(math.cos(rad) * length)
        tip_y = base_y + int(math.sin(rad) * length)
        
        mid_x = (base_x + tip_x) // 2
        mid_y = (base_y + tip_y) // 2
        nx = int(-math.sin(rad) * width * 0.5)
        ny = int(math.cos(rad) * width * 0.5)
        
        poly = [
            (base_x, base_y),
            (mid_x + nx, mid_y + ny),
            (tip_x + int(nx * 0.4), tip_y + int(ny * 0.4)),
            (tip_x, tip_y),
            (tip_x - int(nx * 0.4), tip_y - int(ny * 0.4)),
            (mid_x - nx, mid_y - ny),
        ]
        
        mask = Image.new("L", (650, 550), 0)
        d_m = ImageDraw.Draw(mask)
        d_m.polygon(poly, fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(3.5))
        lut = [int(min(255, max(0, (i - 40) * (255 / 170)))) for i in range(256)]
        mask = mask.point(lut)
        
        grad = render_gradient_vertical(650, 550, c_top, c_btm)
        leaf_img = Image.new("RGBA", (650, 550), (0, 0, 0, 0))
        leaf_img.paste(grad, (0, 0), mask=mask)
        
        d_sp = ImageDraw.Draw(leaf_img)
        d_sp.line([(base_x, base_y), (tip_x, tip_y)], fill=(225, 255, 180, 200), width=4)
        
        frond_layer = Image.alpha_composite(frond_layer, leaf_img)

    if flip:
        frond_layer = frond_layer.transpose(Image.FLIP_LEFT_RIGHT)
    if abs(angle_deg) > 0.1:
        frond_layer = frond_layer.rotate(angle_deg, resample=Image.BICUBIC, expand=True)

    frond_w = int(frond_layer.width * scale)
    frond_h = int(frond_layer.height * scale)
    frond_layer = frond_layer.resize((frond_w, frond_h), Image.Resampling.LANCZOS)

    img.alpha_composite(frond_layer, (cx - frond_w // 2, cy - frond_h // 2))

def draw_road_banner(w, h, top_y=505, road_thickness=68):
    banner = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx = w // 2
    
    angles = [math.radians(deg) for deg in range(65, 116)]
    r_outer = 440
    r_inner = r_outer - road_thickness
    center_y = top_y - 280
    
    outer_pts = [(cx + int(math.cos(a) * r_outer), center_y + int(math.sin(a) * r_outer)) for a in angles]
    inner_pts = [(cx + int(math.cos(a) * r_inner), center_y + int(math.sin(a) * r_inner)) for a in reversed(angles)]
    road_poly = outer_pts + inner_pts

    road_mask = Image.new("L", (w, h), 0)
    d_rm = ImageDraw.Draw(road_mask)
    d_rm.polygon(road_poly, fill=255)

    road_grad = render_gradient_vertical(w, h, (40, 48, 72), (20, 24, 38))
    road_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    road_layer.paste(road_grad, (0, 0), mask=road_mask)

    r_mid = (r_outer + r_inner) // 2
    dash_deg = [(72, 76), (79, 83), (86, 90), (93, 97), (100, 104), (107, 111)]
    d_dash = ImageDraw.Draw(road_layer)
    for a1, a2 in dash_deg:
        pts = []
        for deg in range(a1, a2 + 1):
            a = math.radians(deg)
            pts.append((cx + int(math.cos(a) * r_mid), center_y + int(math.sin(a) * r_mid)))
        if len(pts) >= 2:
            d_dash.line(pts, fill=(255, 215, 20, 255), width=7)

    return road_layer, road_mask

def draw_diamond_sparkle(img, cx, cy, radius=22, color=(255, 255, 255, 255)):
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
    print("=== GENERATING BUS PARTY MASTERPIECE BADGE LOGO ===")
    Y_OFFSET = 120
    lines_def = [
        {
            "keys": ["B", "U", "S"],
            "font_size": 240,
            "stroke_w": 9,
            "depth": 28,
            "y_pos": 160 + Y_OFFSET,
            "spacing": -16,
            "angles": [-2.0, 0.0, 2.0],
            "y_offsets": [3, -3, 3]
        },
        {
            "keys": ["P", "A", "R", "T", "Y"],
            "font_size": 205,
            "stroke_w": 8,
            "depth": 26,
            "y_pos": 385 + Y_OFFSET,
            "spacing": -14,
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

    letter_mask = Image.new("L", (CANVAS_W, CANVAS_H), 0)
    for l in rendered_letters:
        letter_alpha = l["img"].split()[3]
        letter_mask.paste(letter_alpha, (l["pos_x"], l["pos_y"]), mask=letter_alpha)

    road_layer, road_mask = draw_road_banner(CANVAS_W, CANVAS_H, top_y=505 + Y_OFFSET, road_thickness=68)
    badge_mask = ImageChops.lighter(letter_mask, road_mask)

    final_canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))

    # Palm fronds
    draw_palm_frond(final_canvas, CENTER_X - 220, 125 + Y_OFFSET, angle_deg=-25, scale=0.95, flip=False)
    draw_palm_frond(final_canvas, CENTER_X + 220, 125 + Y_OFFSET, angle_deg=25, scale=0.95, flip=True)

    # Ambient drop shadow
    shadow_mask = badge_mask.filter(ImageFilter.MaxFilter(17))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(18))
    shadow_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (8, 12, 30, 140))
    final_canvas.paste(shadow_layer, (0, 26), mask=shadow_mask)

    # Backing hull
    hull_mask = badge_mask.filter(ImageFilter.MaxFilter(17))
    hull_grad = render_gradient_vertical(CANVAS_W, CANVAS_H, (24, 32, 64), (10, 14, 32))
    hull_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    hull_layer.paste(hull_grad, (0, 0), mask=hull_mask)
    
    hull_bottom_mask = ImageChops.subtract(ImageChops.offset(hull_mask, 0, 6), hull_mask)
    hull_bottom_dark = Image.new("RGBA", (CANVAS_W, CANVAS_H), (4, 6, 16, 255))
    final_canvas = Image.alpha_composite(final_canvas, hull_layer)
    final_canvas.paste(hull_bottom_dark, (0, 0), mask=hull_bottom_mask)

    # White sticker border
    border_mask = badge_mask.filter(ImageFilter.MaxFilter(5))
    border_grad = render_gradient_vertical(CANVAS_W, CANVAS_H, (255, 255, 255), (235, 242, 252))
    border_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    border_layer.paste(border_grad, (0, 0), mask=border_mask)
    final_canvas = Image.alpha_composite(final_canvas, border_layer)

    # Road banner
    final_canvas.alpha_composite(road_layer)

    # 3D Letters
    for l in rendered_letters:
        l_alpha = l["img"].split()[3]
        l_shadow_mask = l_alpha.filter(ImageFilter.GaussianBlur(5))
        l_shadow = Image.new("RGBA", (l["w"], l["h"]), (0, 0, 0, 80))
        final_canvas.paste(l_shadow, (l["pos_x"] + 3, l["pos_y"] + 5), mask=l_shadow_mask)
        final_canvas.alpha_composite(l["img"], (l["pos_x"], l["pos_y"]))

    # Sparkles
    sparkles = [
        (rendered_letters[0]["pos_x"] + 50, rendered_letters[0]["pos_y"] + 45, 22, (255, 255, 225, 255)),  # B
        (rendered_letters[2]["pos_x"] + 120, rendered_letters[2]["pos_y"] + 70, 20, (255, 235, 235, 255)), # S
        (rendered_letters[3]["pos_x"] + 45, rendered_letters[3]["pos_y"] + 45, 22, (255, 255, 210, 255)),  # P
        (rendered_letters[5]["pos_x"] + 50, rendered_letters[5]["pos_y"] + 40, 18, (225, 255, 240, 255)),  # R
        (rendered_letters[7]["pos_x"] + 100, rendered_letters[7]["pos_y"] + 45, 24, (225, 250, 255, 255)), # Y
    ]
    for sp in sparkles:
        draw_diamond_sparkle(final_canvas, sp[0], sp[1], sp[2], sp[3])

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
    cropped.save(BADGE_PNG, "PNG", optimize=True)
    cropped.save(LEGACY_PNG, "PNG", optimize=True)
    print(f"SUCCESS! Rendered Badge Logo saved to {OUTPUT_PNG} ({cropped.width}x{cropped.height} px)")

if __name__ == "__main__":
    generate_logo()
