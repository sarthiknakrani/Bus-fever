restart_normal = """<svg width="80" height="80" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#000000" fill-opacity="0.25" />
    <rect x="6" y="6" width="68" height="68" rx="16" fill="#1e3a8a" />
    <rect x="6" y="2" width="68" height="68" rx="16" fill="#3b82f6" />
    <path d="M22 2 H58 A16 16 0 0 1 74 18 V26 A50 10 0 0 0 6 26 V18 A16 16 0 0 1 22 2 Z" fill="#ffffff" fill-opacity="0.25" />
    <!-- Center is (40, 36) -->
    <!-- Circular Arrow, nicely padded -->
    <path d="M 40 22 C 32 22 26 28 26 36 L 22 36 L 28 44 L 34 36 L 30 36 C 30 30 34 26 40 26 C 46 26 50 30 50 36 C 50 42 46 46 40 46 L 40 50 C 48 50 54 44 54 36 C 54 28 48 22 40 22 Z" fill="#ffffff" />
</svg>"""

restart_pressed = """<svg width="80" height="80" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#000000" fill-opacity="0.15" />
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#1e3a8a" />
    <rect x="6" y="6" width="68" height="68" rx="16" fill="#3b82f6" />
    <path d="M22 6 H58 A16 16 0 0 1 74 22 V30 A50 10 0 0 0 6 30 V22 A16 16 0 0 1 22 6 Z" fill="#ffffff" fill-opacity="0.25" />
    <!-- Center is (40, 40) -->
    <path d="M 40 26 C 32 26 26 32 26 40 L 22 40 L 28 48 L 34 40 L 30 40 C 30 34 34 30 40 30 C 46 30 50 34 50 40 C 50 46 46 50 40 50 L 40 54 C 48 54 54 48 54 40 C 54 32 48 26 40 26 Z" fill="#ffffff" />
</svg>"""

pause_normal = """<svg width="80" height="80" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#000000" fill-opacity="0.25" />
    <rect x="6" y="6" width="68" height="68" rx="16" fill="#1e3a8a" />
    <rect x="6" y="2" width="68" height="68" rx="16" fill="#3b82f6" />
    <path d="M22 2 H58 A16 16 0 0 1 74 18 V26 A50 10 0 0 0 6 26 V18 A16 16 0 0 1 22 2 Z" fill="#ffffff" fill-opacity="0.25" />
    <rect x="30" y="24" width="6" height="24" rx="2" fill="#ffffff" />
    <rect x="44" y="24" width="6" height="24" rx="2" fill="#ffffff" />
</svg>"""

pause_pressed = """<svg width="80" height="80" xmlns="http://www.w3.org/2000/svg">
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#000000" fill-opacity="0.15" />
    <rect x="6" y="8" width="68" height="68" rx="16" fill="#1e3a8a" />
    <rect x="6" y="6" width="68" height="68" rx="16" fill="#3b82f6" />
    <path d="M22 6 H58 A16 16 0 0 1 74 22 V30 A50 10 0 0 0 6 30 V22 A16 16 0 0 1 22 6 Z" fill="#ffffff" fill-opacity="0.25" />
    <rect x="30" y="28" width="6" height="24" rx="2" fill="#ffffff" />
    <rect x="44" y="28" width="6" height="24" rx="2" fill="#ffffff" />
</svg>"""

with open('assets/ui/gameplay_buttons/restart_normal.svg', 'w') as f: f.write(restart_normal)
with open('assets/ui/gameplay_buttons/restart_pressed.svg', 'w') as f: f.write(restart_pressed)
with open('assets/ui/gameplay_buttons/pause_normal.svg', 'w') as f: f.write(pause_normal)
with open('assets/ui/gameplay_buttons/pause_pressed.svg', 'w') as f: f.write(pause_pressed)
print("Restart and Pause fixed")
