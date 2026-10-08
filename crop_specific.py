from PIL import Image
import os

img_path = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c/.user_uploaded/media_1791443621518_e7d34d45.jpg"
out_dir = "assets/ui_raw"
os.makedirs(out_dir, exist_ok=True)

img = Image.open(img_path).convert("RGBA")

def save_crop(box, name):
    crop = img.crop(box)
    data = crop.getdata()
    new_data = []
    for item in data:
        # If it's very dark (almost black background), make it transparent
        if item[0] < 25 and item[1] < 25 and item[2] < 25:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(item)
    crop.putdata(new_data)
    crop.save(os.path.join(out_dir, f"{name}.png"))

# Coordinates estimated from looking at the sprite sheet layout
# 1024x1024 typical size? Let's check image size
print("Image size:", img.size)

# I will just write a script that saves the whole image with black background removed, 
# then I can use Godot's AtlasTexture to slice it!
data = img.getdata()
new_data = []
for item in data:
    if item[0] < 25 and item[1] < 25 and item[2] < 25:
        new_data.append((0, 0, 0, 0))
    else:
        new_data.append(item)
img.putdata(new_data)
img.save("assets/ui_sheet_transparent.png")
print("Saved transparent sheet.")
