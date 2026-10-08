from PIL import Image

img_path = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c/.user_uploaded/media_1791444849730_9202030b.png"
img = Image.open(img_path).convert("RGBA")

w, h = img.size
w_third = w // 3

def get_transparent_icon(x0, y0, x1, y1, name):
    crop = img.crop((x0, y0, x1, y1))
    data = crop.getdata()
    new_data = []
    for p in data:
        if p[0] < 20 and p[1] < 20 and p[2] < 20:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(p)
    crop.putdata(new_data)
    
    bb = crop.getbbox()
    if bb:
        crop = crop.crop(bb)
    crop.save(f"assets/{name}.png")
    print(f"Saved {name}.png")

get_transparent_icon(0, 0, w_third, h, "icon_ball_clean")
get_transparent_icon(w_third, 0, w_third*2, h, "icon_car_clean")
get_transparent_icon(w_third*2, 0, w, h, "icon_bus_clean")

