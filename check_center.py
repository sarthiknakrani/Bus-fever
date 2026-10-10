from PIL import Image
img = Image.open('assets/btn_vip.png').convert('RGBA')
print(img.getpixel((img.size[0]//2, img.size[1]//2)))
