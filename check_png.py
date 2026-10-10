from PIL import Image

def analyze(path):
    try:
        img = Image.open(path).convert('RGBA')
        w, h = img.size
        # Check corners and edges for transparency
        edges = []
        for x in range(w):
            edges.append(img.getpixel((x, 0))[3])
            edges.append(img.getpixel((x, h-1))[3])
        for y in range(h):
            edges.append(img.getpixel((0, y))[3])
            edges.append(img.getpixel((w-1, y))[3])
        
        # Count opaque pixels
        opaque = 0
        for x in range(w):
            for y in range(h):
                if img.getpixel((x, y))[3] > 128:
                    opaque += 1
                    
        print(f"{path}: {w}x{h}, opaque pixels: {opaque}/{w*h} ({opaque/(w*h)*100:.1f}%)")
    except Exception as e:
        print(f"Error on {path}: {e}")

analyze("assets/btn_vip.png")
analyze("assets/btn_restart.png")
