from PIL import Image, ImageDraw, ImageFilter

def create_feathered_crop(in_path, out_path, size, center_offset=(0,0)):
    img = Image.open(in_path).convert("RGBA")
    
    # We want a circular crop from the center
    # The image is ~ 130x140. Center is ~ (65, 70).
    cx = img.width // 2 + center_offset[0]
    cy = img.height // 2 + center_offset[1]
    
    # Radius of the bus/ball
    r = size // 2
    
    # Create a radial mask
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    
    # Blur the mask to feather edges
    mask = mask.filter(ImageFilter.GaussianBlur(10))
    
    # Apply mask
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    
    # Crop to bounding box of the mask
    crop_box = (cx - r - 15, cy - r - 15, cx + r + 15, cy + r + 15)
    out = out.crop(crop_box)
    
    out.save(out_path)

# Sizes for the bus/ball:
# VIP: Center is fine. Radius ~ 45
create_feathered_crop("assets/btn_vip.png", "assets/ui/gameplay_buttons/icon_vip.png", 80, center_offset=(-5, -5))
create_feathered_crop("assets/btn_arrange.png", "assets/ui/gameplay_buttons/icon_arrange.png", 80, center_offset=(-5, -5))
create_feathered_crop("assets/btn_jumble.png", "assets/ui/gameplay_buttons/icon_jumble.png", 80, center_offset=(-5, -5))
print("Processed icons")
