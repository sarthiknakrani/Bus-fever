from PIL import Image
from collections import Counter
for f in ["assets/btn_arrange.png", "assets/btn_jumble.png"]:
    img = Image.open(f).convert('RGBA')
    colors = Counter([p for p in img.getdata() if p[3] > 200])
    print(f"--- {f} ---")
    for c, count in colors.most_common(3):
        print(c, count)
