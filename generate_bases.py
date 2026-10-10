import os

os.makedirs('assets/ui/gameplay_buttons', exist_ok=True)

sq_normal = """<svg width="120" height="120" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="8" width="108" height="108" rx="24" fill="#000000" fill-opacity="0.25" />
    <rect x="6" y="6" width="108" height="108" rx="24" fill="#1e3a8a" />
    <rect x="6" y="2" width="108" height="104" rx="24" fill="#3b82f6" />
    <path d="M30 4 H90 A22 22 0 0 1 112 26 V36 A90 15 0 0 0 8 36 V26 A22 22 0 0 1 30 4 Z" fill="#ffffff" fill-opacity="0.25" />
    <rect x="16" y="96" width="88" height="6" rx="3" fill="#2563eb" />
</svg>"""

sq_pressed = """<svg width="120" height="120" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="8" width="108" height="108" rx="24" fill="#000000" fill-opacity="0.15" />
    <rect x="6" y="10" width="108" height="104" rx="24" fill="#1e3a8a" />
    <rect x="6" y="8" width="108" height="104" rx="24" fill="#3b82f6" />
    <path d="M30 10 H90 A22 22 0 0 1 112 32 V42 A90 15 0 0 0 8 42 V32 A22 22 0 0 1 30 10 Z" fill="#ffffff" fill-opacity="0.25" />
    <rect x="16" y="102" width="88" height="6" rx="3" fill="#2563eb" />
</svg>"""

with open('assets/ui/gameplay_buttons/base_square_normal.svg', 'w') as f: f.write(sq_normal)
with open('assets/ui/gameplay_buttons/base_square_pressed.svg', 'w') as f: f.write(sq_pressed)
print("Created base SVGs")
