from PIL import Image
img = Image.open('assets/booster_vip.png').convert('RGBA').resize((40,20))
pixels = img.load()
for y in range(20):
    line = ""
    for x in range(40):
        if pixels[x,y][3] < 128: line += " "
        else: line += "#"
    print(line)
