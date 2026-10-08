from PIL import Image

img = Image.open("assets/ui_sheet_transparent.png")
crop1 = img.crop((0, 0, 400, 200))
crop1.save("assets/test_coin.png")

crop2 = img.crop((0, 450, 1024, 682))
crop2.save("assets/test_bottom.png")
