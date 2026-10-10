from PIL import Image
from collections import Counter

img = Image.open('assets/btn_vip.png').convert('RGBA')
pixels = img.getdata()

# count opaque colors
colors = Counter([p for p in pixels if p[3] > 200])
for c, count in colors.most_common(10):
    print(c, count)
