from PIL import Image
import shutil

img = Image.open("assets/ui_sheet_transparent.png")
def save_crop(x0, y0, w, h, name):
    crop = img.crop((x0, y0, x0+w, y0+h))
    bb = crop.getbbox()
    if bb:
        crop = crop.crop(bb)
    crop.save(f"assets/{name}.png")
    print(f"Saved {name}")

# Let's use the element_*.png files I generated earlier using flood fill! They are clean!
import os
for f in os.listdir("assets/ui"):
    if not f.endswith(".png"): continue
    path = f"assets/ui/{f}"
    w, h = Image.open(path).size
    if w == 298 and h == 175:
        shutil.copy(path, "assets/btn_play.png")
        print("btn_play")
    elif w == 264 and h == 118:
        shutil.copy(path, "assets/btn_home.png")
        print("btn_home")
    elif w == 296 and h == 102:
        shutil.copy(path, "assets/btn_restart.png")
        print("btn_restart")
    elif w == 130 and h == 142:
        shutil.copy(path, "assets/btn_arrange.png")
    elif w == 129 and h == 140:
        shutil.copy(path, "assets/btn_vip.png")
    elif w == 131 and h == 144:
        shutil.copy(path, "assets/btn_jumble.png")
    elif w == 80 and h == 81:
        shutil.copy(path, "assets/btn_pause.png")
    elif w == 77 and h == 81:
        shutil.copy(path, "assets/btn_settings.png")
    elif w == 107 and h == 75:
        shutil.copy(path, "assets/toggle_on.png")
    elif w == 101 and h == 74:
        shutil.copy(path, "assets/toggle_off.png")
    elif w == 153 and h == 118:
        shutil.copy(path, "assets/btn_red.png") # Maybe Close button?
        
