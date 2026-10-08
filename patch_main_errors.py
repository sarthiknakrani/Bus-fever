import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

# Fix stretch mode
code = code.replace("TextureRect.STRETCH_KEEP_ASPECT_COVER", "TextureRect.STRETCH_KEEP_ASPECT_COVERED")

# Remove decorative mini bus icons entirely
code = re.sub(r'\t# Decorative Mini Bus Icons centered on the road[\s\S]*?bus_hbox\.add_child\(bus_box\)', '', code)

with open("scripts/main.gd", "w") as f:
    f.write(code)

print("Fixed main.gd errors")
