from PIL import Image

img = Image.open("assets/ui_sheet_transparent.png")
def get_bb(x0, y0, x1, y1):
    crop = img.crop((x0, y0, x1, y1))
    bb = crop.getbbox()
    if bb:
        w = bb[2] - bb[0]
        h = bb[3] - bb[1]
        
        # Save it for verification
        final_crop = img.crop((x0 + bb[0], y0 + bb[1], x0 + bb[2], y0 + bb[3]))
        final_crop.save(f"assets/crop_{x0}_{y0}.png")
        
        return (x0 + bb[0], y0 + bb[1], w, h)
    return None

# Looking at the original image:
# Top Bar: Coin Counter, Settings, Back, Pause
# Shop Item Icons at bottom: No Ads, Coins, Ball, Car, Bus
# So Car is ~65%, Bus is ~80%, Ball is ~50%
print("Coin:", get_bb(0, 50, 400, 200))
print("Ball:", get_bb(280, 500, 480, 680))
print("Car:", get_bb(500, 500, 680, 680))
print("Bus:", get_bb(680, 500, 850, 680))

