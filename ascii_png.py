from PIL import Image

def ascii_art(path):
    print(f"--- {path} ---")
    try:
        img = Image.open(path).convert('RGBA')
        img = img.resize((40, 20))
        pixels = img.load()
        for y in range(20):
            line = ""
            for x in range(40):
                r, g, b, a = pixels[x, y]
                if a < 128:
                    line += " "
                else:
                    if r > 200 and g < 100 and b < 100: line += "R"
                    elif g > 200 and r < 100 and b < 100: line += "G"
                    elif b > 200 and r < 100 and g < 100: line += "B"
                    else: line += "#"
            print(line)
    except Exception as e:
        print(f"Error on {path}: {e}")

ascii_art("assets/btn_vip.png")
ascii_art("assets/btn_pause.png")
