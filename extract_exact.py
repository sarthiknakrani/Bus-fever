from PIL import Image

img = Image.open("assets/ui_sheet_transparent.png")

def extract(x0, y0, x1, y1, name):
    crop = img.crop((x0, y0, x1, y1))
    bb = crop.getbbox()
    if bb:
        final_crop = img.crop((x0 + bb[0], y0 + bb[1], x0 + bb[2], y0 + bb[3]))
        final_crop.save(f"assets/{name}.png")
        print(f"Saved {name}.png")

extract(0, 0, 320, 150, "coin_counter")
extract(500, 500, 680, 660, "icon_car")
extract(680, 500, 850, 660, "icon_bus")
extract(280, 500, 480, 660, "icon_ball")
