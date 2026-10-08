from PIL import Image
import shutil
import os

files = os.listdir("assets/ui")
for f in files:
    if f.endswith('.png'):
        path = f"assets/ui/{f}"
        img = Image.open(path)
        w, h = img.size
        print(f"{f}: {w}x{h}")
        # Look for specific sizes
        if w == 296 and h == 102:
            shutil.copy(path, "assets/coin_counter.png")
            print("Found Coin Counter!")
        elif w == 107 and h == 108:
            shutil.copy(path, "assets/ball_icon.png")
            print("Found Ball!")
        elif w == 129 and h == 63:
            # Maybe this is the car?
            pass
