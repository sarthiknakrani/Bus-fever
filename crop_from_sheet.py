from PIL import Image

sheet = Image.open("assets/ui_sheet_transparent.png")
# The 3 icons are at the bottom of the original image? No, wait. 
# They were in the middle right!
# Let's crop the exact user image from the sheet!
