import math

# We can draw 3 faces: Top, Left, Right
def get_iso_cube(w, l, h):
    # Base isometric vectors
    vx = [0.866, 0.5]
    vy = [-0.866, 0.5]
    vz = [0, -1]
    # ...
