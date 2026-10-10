from PIL import Image

img = Image.open('assets/btn_vip.png').convert('RGBA')
w, h = img.size
pixels = img.load()

# Let's sample a few pixels to see if the background is blue or transparent
print("Corner 0,0:", pixels[0, 0])
print("Center 0, h/2:", pixels[0, h//2])
print("Center w/2, 0:", pixels[w//2, 0])
print("Center w/2, h/2:", pixels[w//2, h//2])
print("Center w/4, h/4:", pixels[w//4, h//4])
