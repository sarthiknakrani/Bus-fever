from PIL import Image

img = Image.open("assets/pure_coin.png").convert("RGBA")
w, h = img.size
pixels = img.load()

# Let's print the colors at y = 80 and y = 100
for y in [80, 90, 100]:
    print(f"--- y={y} ---")
    for x in range(60, 150, 2):
        if pixels[x, y][3] > 0:
            print(f"x={x:3d}: {pixels[x, y]}")
