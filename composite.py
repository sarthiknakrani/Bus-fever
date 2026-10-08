from PIL import Image, ImageDraw, ImageFont
import os

images = []
for f in sorted(os.listdir('assets/ui')):
    if not f.endswith('.png'): continue
    img = Image.open(f"assets/ui/{f}")
    images.append((f, img))

# Create a large canvas
canvas_w = 1200
canvas_h = 1200
canvas = Image.new("RGBA", (canvas_w, canvas_h), (50, 50, 50, 255))
draw = ImageDraw.Draw(canvas)

x = y = 10
row_h = 0
for name, img in images:
    w, h = img.size
    if x + w > canvas_w:
        x = 10
        y += row_h + 30
        row_h = 0
    
    canvas.paste(img, (x, y), img)
    draw.text((x, y + h + 5), name, fill="white")
    
    x += w + 20
    row_h = max(row_h, h)

canvas.save("assets/composite.png")
print("Saved composite.png")
