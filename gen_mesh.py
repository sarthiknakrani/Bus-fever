import math

def gen_rounded_box(width, height, depth, radius, segments, filename):
    vertices = []
    normals = []
    faces = []
    
    # We will build the top and bottom faces, and connect them.
    # To make a bevel, we can add an extra edge loop.
    
    # Let's do a simpler approach: 2D rounded rectangle extruded.
    # If we want a bevel, we need top points, bevel points, edge points, bottom points.
    
    # Profile:
    # 0: center top (w, h, z=depth/2)
    # 1: bevel start (w - bevel, h - bevel, z=depth/2) -> wait, bevel is on Z and XY
    
    # Let's keep it simple: A 2D rounded outline extruded along Z.
    outline = []
    # 4 corners
    # top right
    for i in range(segments + 1):
        ang = math.pi/2 * i / segments
        x = width/2 - radius + math.cos(ang) * radius
        y = height/2 - radius + math.sin(ang) * radius
        outline.append((x, y))
    # top left
    for i in range(segments + 1):
        ang = math.pi/2 + math.pi/2 * i / segments
        x = -width/2 + radius + math.cos(ang) * radius
        y = height/2 - radius + math.sin(ang) * radius
        outline.append((x, y))
    # bottom left
    for i in range(segments + 1):
        ang = math.pi + math.pi/2 * i / segments
        x = -width/2 + radius + math.cos(ang) * radius
        y = -height/2 + radius + math.sin(ang) * radius
        outline.append((x, y))
    # bottom right
    for i in range(segments + 1):
        ang = 3*math.pi/2 + math.pi/2 * i / segments
        x = width/2 - radius + math.cos(ang) * radius
        y = -height/2 + radius + math.sin(ang) * radius
        outline.append((x, y))
        
    # Extrude outline to create:
    # Z = depth/2 (top face)
    # Z = -depth/2 (bottom face)
    # To add a bevel, let's add an inner outline at Z = depth/2
    # and the outer outline at Z = depth/2 - bevel_size
    
    bevel_size = min(radius / 2, depth / 4)
    
    # Actually, a smooth bevel:
    z_profile = [
        (depth/2, -bevel_size), # Inner top (flat part)
        (depth/2 - bevel_size * 0.2, -bevel_size * 0.8),
        (depth/2 - bevel_size * 0.7, -bevel_size * 0.3),
        (depth/2 - bevel_size, 0.0), # Outer top edge
        (-depth/2 + bevel_size, 0.0), # Outer bottom edge
        (-depth/2, -bevel_size), # Bottom flat
    ]
    
    # We will just write a simple script that outputs OBJ
    # For UI, maybe it's easier to just use Godot's BoxMesh and rely on smooth shading / normal mapping?
    # No, true rounded corners are requested.
    pass

# For Godot, we can use an ArrayMesh or CSGPolygon3D!
# Yes! CSGPolygon3D can sweep a 2D polygon!
# Even better: Godot's script can generate an ArrayMesh dynamically, OR we can just use CSGPolygon with `mode = CSGPolygon3D.MODE_DEPTH`.
# With CSGPolygon3D, you can't easily bevel the Z edges in MODE_DEPTH.
