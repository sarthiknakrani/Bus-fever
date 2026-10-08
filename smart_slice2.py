from PIL import Image

img_path = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c/.user_uploaded/media_1791444849730_9202030b.png"
img = Image.open(img_path).convert("RGBA")
pixels = img.load()
w, h = img.size

# We want to remove the black background perfectly.
# Any pixel with max(R,G,B) < 60 becomes transparent.
# Any pixel with max(R,G,B) between 60 and 120 gets partial transparency if it's near the edge.

for x in range(w):
    for y in range(h):
        r, g, b, a = pixels[x, y]
        m = max(r, g, b)
        if m < 40:
            pixels[x, y] = (0, 0, 0, 0)
        elif m < 90:
            # Scale alpha
            new_a = int((m - 40) / 50 * 255)
            pixels[x, y] = (r, g, b, new_a)

w_third = w // 3

def save_part(x0, x1, name):
    crop = img.crop((x0, 0, x1, h))
    bb = crop.getbbox()
    if bb:
        crop = crop.crop(bb)
    crop.save(f"assets/{name}.png")
    print(f"Saved {name}.png")

save_part(0, w_third, "icon_ball_clean")
save_part(w_third, w_third*2, "icon_car_clean")
save_part(w_third*2, w, "icon_bus_clean")
