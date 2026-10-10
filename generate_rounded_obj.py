import math

def gen_obj(filename, width, height, depth, corner_radius, segments=8, bevel=2.0):
    vertices = []
    normals = []
    faces = []
    
    # We will generate a profile of 3 layers:
    # 0: bottom face (z = -depth/2)
    # 1: bottom bevel (z = -depth/2 + bevel, expanded slightly)
    # 2: top bevel (z = depth/2 - bevel)
    # 3: top face (z = depth/2)
    
    # Actually, simpler: A rounded rectangle.
    # Center points for the 4 corners:
    cx = width/2 - corner_radius
    cy = height/2 - corner_radius
    
    def get_corner_pts(z, r_offset):
        r = corner_radius + r_offset
        pts = []
        # top right
        for i in range(segments + 1):
            ang = math.pi/2 * i / segments
            pts.append((cx + r*math.cos(ang), cy + r*math.sin(ang), z))
        # top left
        for i in range(segments + 1):
            ang = math.pi/2 + math.pi/2 * i / segments
            pts.append((-cx + r*math.cos(ang), cy + r*math.sin(ang), z))
        # bottom left
        for i in range(segments + 1):
            ang = math.pi + math.pi/2 * i / segments
            pts.append((-cx + r*math.cos(ang), -cy + r*math.sin(ang), z))
        # bottom right
        for i in range(segments + 1):
            ang = 3*math.pi/2 + math.pi/2 * i / segments
            pts.append((cx + r*math.cos(ang), -cy + r*math.sin(ang), z))
        return pts

    # Layer 0: Flat bottom
    L0 = get_corner_pts(-depth/2, -bevel)
    # Layer 1: Bottom bevel curve
    L1 = get_corner_pts(-depth/2 + bevel, 0)
    # Layer 2: Top bevel curve
    L2 = get_corner_pts(depth/2 - bevel, 0)
    # Layer 3: Flat top
    L3 = get_corner_pts(depth/2, -bevel)
    
    # Add vertices
    # Center top
    v_top_center = len(vertices) + 1
    vertices.append((0, 0, depth/2))
    # Center bottom
    v_bot_center = len(vertices) + 1
    vertices.append((0, 0, -depth/2))
    
    layers = [L0, L1, L2, L3]
    layer_start = []
    
    for L in layers:
        layer_start.append(len(vertices) + 1)
        for p in L:
            vertices.append(p)
            
    n_pts = len(L0)
    
    # Faces:
    # 1. Top cap (Center to L3)
    for i in range(n_pts):
        nxt = (i + 1) % n_pts
        faces.append((v_top_center, layer_start[3] + i, layer_start[3] + nxt))
        
    # 2. Bottom cap (Center to L0)
    for i in range(n_pts):
        nxt = (i + 1) % n_pts
        faces.append((v_bot_center, layer_start[0] + nxt, layer_start[0] + i))
        
    # 3. Sides
    for l_idx in range(3):
        for i in range(n_pts):
            nxt = (i + 1) % n_pts
            v0 = layer_start[l_idx] + i
            v1 = layer_start[l_idx] + nxt
            v2 = layer_start[l_idx+1] + nxt
            v3 = layer_start[l_idx+1] + i
            faces.append((v0, v1, v2))
            faces.append((v0, v2, v3))
            
    with open(filename, 'w') as f:
        for v in vertices:
            f.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
        # Generate smooth normals (auto-handled by Godot if imported correctly)
        for face in faces:
            f.write(f"f {face[0]} {face[1]} {face[2]}\n")
            
    print(f"Generated {filename}")

import os
os.makedirs("assets/models", exist_ok=True)
gen_obj("assets/models/rounded_button.obj", width=120, height=120, depth=20, corner_radius=24, bevel=4)
gen_obj("assets/models/btn_320x80.obj", width=320, height=80, depth=20, corner_radius=24, bevel=4)
gen_obj("assets/models/btn_64x64.obj", width=64, height=64, depth=16, corner_radius=16, bevel=3)
gen_obj("assets/models/btn_56x56.obj", width=56, height=56, depth=14, corner_radius=12, bevel=2)
gen_obj("assets/models/btn_160x60.obj", width=160, height=60, depth=16, corner_radius=16, bevel=3)
gen_obj("assets/models/btn_50x50.obj", width=50, height=50, depth=12, corner_radius=12, bevel=2)
gen_obj("assets/models/btn_180x56.obj", width=180, height=56, depth=14, corner_radius=12, bevel=2)
