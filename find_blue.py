from PIL import Image

img = Image.open("assets/pure_coin.png").convert("RGBA")
w, h = img.size
pixels = img.load()

for y in range(60, 110, 5):
    blue_xs = []
    for x in range(0, w):
        r, g, b, a = pixels[x, y]
        if a > 0 and b > r + 30 and b > g + 30:
            blue_xs.append(x)
    if blue_xs:
        print(f"y={y}: blue text at x={min(blue_xs)} to {max(blue_xs)}")
