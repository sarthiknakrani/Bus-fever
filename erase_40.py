from PIL import Image

img = Image.open("assets/pure_coin.png").convert("RGBA")
w, h = img.size
pixels = img.load()

# Let's find the actual rightmost boundary of the coin / plus.
# The coin/plus pixels are either yellow (high R, G, low B) or green (high G, low R, B).
# The "40" is dark blue (low R, G, high B).
# The sliver of white pill is white (high R, G, B).

for x in range(w):
    for y in range(h):
        r, g, b, a = pixels[x, y]
        if a == 0: continue
        
        # If it's dark blue (the "40")
        if b > r and b > g and r < 100 and g < 150:
            pixels[x, y] = (0,0,0,0)
            
        # If it's white/gray (the pill sliver or outline)
        # We must not erase the white plus inside the green circle!
        # The white plus is around x=80-90. Let's just erase everything to the right of x=100!
        if x > 105:
            pixels[x, y] = (0,0,0,0)
            
        # Erase thin black/gray outlines from the pill if they're too far right
        if x > 95:
            # If it's not yellow and not green, erase it.
            # Yellow: r>150, g>100
            # Green: g>150
            if not (r > 150 and g > 100) and not (g > 150):
                pixels[x, y] = (0,0,0,0)

img.save("assets/pure_coin.png")
print("Saved pure_coin.png without 40")
