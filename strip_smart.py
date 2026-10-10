from PIL import Image

def strip_bg(in_f, out_f):
    img = Image.open(in_f).convert("RGBA")
    pixels = img.load()
    w, h = img.size
    
    # We want to remove the blue button background.
    # The blue background is roughly R < 100, G > 100, B > 180
    # Also remove dark blue shadow R < 50, G < 100, B < 150 (if it's the edge shadow)
    # Let's use a flood fill from the edges!
    
    visited = set()
    stack = []
    
    for x in range(w):
        stack.append((x, 0))
        stack.append((x, h-1))
    for y in range(h):
        stack.append((0, y))
        stack.append((w-1, y))
        
    while stack:
        x, y = stack.pop()
        if (x, y) in visited: continue
        visited.add((x, y))
        
        r, g, b, a = pixels[x, y]
        if a == 0:
            # Propagate to neighbors
            for dx, dy in [(0,1), (0,-1), (1,0), (-1,0)]:
                nx, ny = x+dx, y+dy
                if 0 <= nx < w and 0 <= ny < h:
                    stack.append((nx, ny))
            continue
            
        # If it's a blue background color, remove it and propagate
        # Glossy blue ranges: (10..60, 100..200, 200..255)
        # Shadow blue ranges: (0..40, 10..80, 50..120)
        # Let's just say if B > R * 1.5 and B > G
        if b > r * 1.2 and b > g * 1.05 and b > 50:
            pixels[x, y] = (0, 0, 0, 0)
            for dx, dy in [(0,1), (0,-1), (1,0), (-1,0)]:
                nx, ny = x+dx, y+dy
                if 0 <= nx < w and 0 <= ny < h:
                    stack.append((nx, ny))
                    
    img.save(out_f)
    print(f"Stripped {in_f} -> {out_f}")

strip_bg('assets/booster_vip.png', 'assets/ui/gameplay_buttons/icon_vip.png')
strip_bg('assets/booster_arrange.png', 'assets/ui/gameplay_buttons/icon_arrange.png')
strip_bg('assets/booster_jumble.png', 'assets/ui/gameplay_buttons/icon_jumble.png')
