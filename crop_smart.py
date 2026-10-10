from PIL import Image, ImageDraw

def process(in_p, out_p, crop_box):
    img = Image.open(in_p).convert("RGBA")
    
    # Create a new image to hold just the cropped icon
    icon = img.crop(crop_box)
    
    # We also want to feather the edges so it blends into the blue background
    # But wait! If the user wants a CLEAN separation, feathering a teal background into a blue background looks like a glowing teal aura.
    # What if we change the HUE of the teal background to match the blue SVG?
    # Then the whole image matches!
    icon.save(out_p)

process("assets/btn_vip.png", "assets/ui/gameplay_buttons/test_vip.png", (10, 15, 95, 105))
