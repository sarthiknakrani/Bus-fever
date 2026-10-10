import os

os.makedirs('assets/ui/gameplay_buttons', exist_ok=True)

# 1. Restart Button (Top Left)
restart_normal = """<svg width="80" height="80" xmlns="http://www.w3.org/2000/svg">
    <!-- Drop Shadow -->
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#000000" fill-opacity="0.25" />
    <!-- 3D Extrusion -->
    <rect x="6" y="6" width="68" height="68" rx="16" fill="#1e3a8a" />
    <!-- Main Face -->
    <rect x="6" y="2" width="68" height="68" rx="16" fill="#3b82f6" />
    <!-- Highlight -->
    <path d="M22 2 H58 A16 16 0 0 1 74 18 V26 A50 10 0 0 0 6 26 V18 A16 16 0 0 1 22 2 Z" fill="#ffffff" fill-opacity="0.25" />
    <!-- Restart Circular Arrow Icon -->
    <path d="M 40 18 A 18 18 0 1 0 54 26 L 46 26 L 58 40 L 70 26 L 62 26 A 26 26 0 1 1 22 18" fill="#ffffff" />
</svg>"""

restart_pressed = """<svg width="80" height="80" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#000000" fill-opacity="0.15" />
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#1e3a8a" />
    <rect x="6" y="6" width="68" height="68" rx="16" fill="#3b82f6" />
    <path d="M22 6 H58 A16 16 0 0 1 74 22 V30 A50 10 0 0 0 6 30 V22 A16 16 0 0 1 22 6 Z" fill="#ffffff" fill-opacity="0.25" />
    <path d="M 40 22 A 18 18 0 1 0 54 30 L 46 30 L 58 44 L 70 30 L 62 30 A 26 26 0 1 1 22 22" fill="#ffffff" />
</svg>"""

# 2. Pause Button (Top Right)
pause_normal = """<svg width="80" height="80" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#000000" fill-opacity="0.25" />
    <rect x="6" y="6" width="68" height="68" rx="16" fill="#1e3a8a" />
    <rect x="6" y="2" width="68" height="68" rx="16" fill="#3b82f6" />
    <path d="M22 2 H58 A16 16 0 0 1 74 18 V26 A50 10 0 0 0 6 26 V18 A16 16 0 0 1 22 2 Z" fill="#ffffff" fill-opacity="0.25" />
    <!-- Pause Bars -->
    <rect x="28" y="22" width="8" height="28" rx="2" fill="#ffffff" />
    <rect x="44" y="22" width="8" height="28" rx="2" fill="#ffffff" />
</svg>"""

pause_pressed = """<svg width="80" height="80" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#000000" fill-opacity="0.15" />
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#1e3a8a" />
    <rect x="6" y="6" width="68" height="68" rx="16" fill="#3b82f6" />
    <path d="M22 6 H58 A16 16 0 0 1 74 22 V30 A50 10 0 0 0 6 30 V22 A16 16 0 0 1 22 6 Z" fill="#ffffff" fill-opacity="0.25" />
    <rect x="28" y="26" width="8" height="28" rx="2" fill="#ffffff" />
    <rect x="44" y="26" width="8" height="28" rx="2" fill="#ffffff" />
</svg>"""

# 3. Booster Base
base_booster_normal = """<svg width="120" height="120" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="10" width="108" height="106" rx="24" fill="#000000" fill-opacity="0.25" />
    <rect x="6" y="8" width="108" height="106" rx="24" fill="#1e3a8a" />
    <rect x="6" y="2" width="108" height="106" rx="24" fill="#3b82f6" />
    <path d="M30 2 H90 A24 24 0 0 1 114 26 V36 A90 15 0 0 0 6 36 V26 A24 24 0 0 1 30 2 Z" fill="#ffffff" fill-opacity="0.25" />
</svg>"""

base_booster_pressed = """<svg width="120" height="120" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="10" width="108" height="106" rx="24" fill="#000000" fill-opacity="0.15" />
    <rect x="6" y="10" width="108" height="106" rx="24" fill="#1e3a8a" />
    <rect x="6" y="6" width="108" height="106" rx="24" fill="#3b82f6" />
    <path d="M30 6 H90 A24 24 0 0 1 114 30 V40 A90 15 0 0 0 6 40 V30 A24 24 0 0 1 30 6 Z" fill="#ffffff" fill-opacity="0.25" />
</svg>"""

with open('assets/ui/gameplay_buttons/restart_normal.svg', 'w') as f: f.write(restart_normal)
with open('assets/ui/gameplay_buttons/restart_pressed.svg', 'w') as f: f.write(restart_pressed)
with open('assets/ui/gameplay_buttons/pause_normal.svg', 'w') as f: f.write(pause_normal)
with open('assets/ui/gameplay_buttons/pause_pressed.svg', 'w') as f: f.write(pause_pressed)
with open('assets/ui/gameplay_buttons/base_booster_normal.svg', 'w') as f: f.write(base_booster_normal)
with open('assets/ui/gameplay_buttons/base_booster_pressed.svg', 'w') as f: f.write(base_booster_pressed)
print("SVGs generated successfully.")
