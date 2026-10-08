from PIL import Image

# Coin counter
coin = Image.open("/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c/.user_uploaded/media_1791444071314_2ae4ec81.png")
# Mask out the black background
def make_transparent(img):
    img = img.convert("RGBA")
    data = img.getdata()
    new_data = []
    for item in data:
        if item[0] < 20 and item[1] < 20 and item[2] < 20:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(item)
    img.putdata(new_data)
    return img

coin = make_transparent(coin)
# Crop bounding box
bb = coin.getbbox()
if bb:
    coin = coin.crop(bb)
coin.save("assets/coin_counter_full.png")

# Boosters
boosters = Image.open("/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c/.user_uploaded/media_1791444091042_e811b0b2.png")
boosters = make_transparent(boosters)

w, h = boosters.size
w_third = w // 3

vip = boosters.crop((0, 0, w_third, h))
bb = vip.getbbox()
if bb: vip = vip.crop(bb)
vip.save("assets/booster_vip.png")

arrange = boosters.crop((w_third, 0, w_third*2, h))
bb = arrange.getbbox()
if bb: arrange = arrange.crop(bb)
arrange.save("assets/booster_arrange.png")

jumble = boosters.crop((w_third*2, 0, w, h))
bb = jumble.getbbox()
if bb: jumble = jumble.crop(bb)
jumble.save("assets/booster_jumble.png")

print("Sliced successfully.")
