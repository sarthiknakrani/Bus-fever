#!/usr/bin/env python3
"""
Setup and integrate all platform app icons into the Godot project.
"""

import os
import shutil
import subprocess
from PIL import Image, ImageFilter
from collections import deque

ZIP_SRC = "scratch/app_icon_pack"
ASSETS_DIR = "assets/app_icons"

os.makedirs(f"{ASSETS_DIR}/ios", exist_ok=True)
os.makedirs(f"{ASSETS_DIR}/android", exist_ok=True)
os.makedirs(f"{ASSETS_DIR}/mac", exist_ok=True)
os.makedirs(f"{ASSETS_DIR}/web", exist_ok=True)
os.makedirs(f"{ASSETS_DIR}/stores", exist_ok=True)

# 1. Master Icon Processing
raw_1024 = Image.open(f"{ZIP_SRC}/appstore.png").convert("RGBA")
w, h = raw_1024.size
pixels = raw_1024.load()

# Mask out corner black pixels for squircle transparency
visited = set()
queue = deque([(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)])
while queue:
    x, y = queue.popleft()
    if (x, y) in visited:
        continue
    visited.add((x, y))
    r, g, b, a = pixels[x, y]
    if r <= 6 and g <= 6 and b <= 6:
        for nx, ny in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]:
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                queue.append((nx, ny))

mask = Image.new("L", (w, h), 255)
mpix = mask.load()
for (x, y) in visited:
    mpix[x, y] = 0
mask = mask.filter(ImageFilter.GaussianBlur(1.0))

master_transparent = raw_1024.copy()
master_transparent.putalpha(mask)

# Save root project icon
master_transparent.save("icon.png", "PNG", optimize=True)
master_transparent.save(f"{ASSETS_DIR}/mac/icon_1024.png", "PNG", optimize=True)

# 2. Store Icons
raw_1024.save(f"{ASSETS_DIR}/stores/appstore_1024_fullbleed.png", "PNG", optimize=True)
master_transparent.save(f"{ASSETS_DIR}/stores/appstore_1024.png", "PNG", optimize=True)

playstore_512 = raw_1024.resize((512, 512), Image.Resampling.LANCZOS)
playstore_512.save(f"{ASSETS_DIR}/stores/playstore_512.png", "PNG", optimize=True)

# 3. iOS Assets
dest_xcassets = f"{ASSETS_DIR}/ios/AppIcon.appiconset"
if os.path.exists(dest_xcassets):
    shutil.rmtree(dest_xcassets)
shutil.copytree(f"{ZIP_SRC}/Assets.xcassets/AppIcon.appiconset", dest_xcassets)

dest_icon = f"{ASSETS_DIR}/ios/AppIcon.icon"
if os.path.exists(dest_icon):
    shutil.rmtree(dest_icon)
if os.path.exists(f"{ZIP_SRC}/AppIcon.icon"):
    shutil.copytree(f"{ZIP_SRC}/AppIcon.icon", dest_icon)

# 4. Android Assets
for mipmap in ["mipmap-mdpi", "mipmap-hdpi", "mipmap-xhdpi", "mipmap-xxhdpi", "mipmap-xxxhdpi"]:
    src_dir = f"{ZIP_SRC}/android/{mipmap}"
    dst_dir = f"{ASSETS_DIR}/android/{mipmap}"
    os.makedirs(dst_dir, exist_ok=True)
    if os.path.exists(src_dir):
        for f in os.listdir(src_dir):
            shutil.copy(f"{src_dir}/{f}", f"{dst_dir}/{f}")

# Godot Android Adaptive Icons (432x432)
# Foreground: icon centered on 432x432 canvas with comfortable padding
fg_canvas = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
fg_size = 288
fg_icon = master_transparent.resize((fg_size, fg_size), Image.Resampling.LANCZOS)
fg_offset = ((432 - fg_size) // 2, (432 - fg_size) // 2)
fg_canvas.alpha_composite(fg_icon, fg_offset)
fg_canvas.save(f"{ASSETS_DIR}/android/adaptive_foreground_432x432.png", "PNG", optimize=True)

# Background: vibrant sky cyan matching the icon
bg_canvas = Image.new("RGBA", (432, 432), (56, 175, 255, 255))
bg_canvas.save(f"{ASSETS_DIR}/android/adaptive_background_432x432.png", "PNG", optimize=True)

# Main launcher 192x192
launcher_192 = master_transparent.resize((192, 192), Image.Resampling.LANCZOS)
launcher_192.save(f"{ASSETS_DIR}/android/launcher_192x192.png", "PNG", optimize=True)

# 5. Web Icons
web_144 = master_transparent.resize((144, 144), Image.Resampling.LANCZOS)
web_144.save(f"{ASSETS_DIR}/web/icon_144x144.png", "PNG", optimize=True)

web_180 = master_transparent.resize((180, 180), Image.Resampling.LANCZOS)
web_180.save(f"{ASSETS_DIR}/web/icon_180x180.png", "PNG", optimize=True)

web_512 = master_transparent.resize((512, 512), Image.Resampling.LANCZOS)
web_512.save(f"{ASSETS_DIR}/web/icon_512x512.png", "PNG", optimize=True)

web_32 = master_transparent.resize((32, 32), Image.Resampling.LANCZOS)
web_32.save(f"{ASSETS_DIR}/web/favicon.png", "PNG", optimize=True)

# Update existing web build icons if present
if os.path.exists("build/web"):
    web_180.save("build/web/index.apple-touch-icon.png", "PNG", optimize=True)
    web_180.save("build/web/index.icon.png", "PNG", optimize=True)

# 6. macOS .icns generation
iconset_dir = "scratch/AppIcon.iconset"
if os.path.exists(iconset_dir):
    shutil.rmtree(iconset_dir)
os.makedirs(iconset_dir, exist_ok=True)

icon_sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for filename, sz in icon_sizes:
    resized = master_transparent.resize((sz, sz), Image.Resampling.LANCZOS)
    resized.save(f"{iconset_dir}/{filename}", "PNG")

icns_path = f"{ASSETS_DIR}/mac/icon.icns"
subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
print(f"Generated macOS icns: {icns_path}")

# Update existing Mac build app bundle if present
mac_app_res = "build/mac/Bus Fever Party.app/Contents/Resources/icon.icns"
if os.path.exists(os.path.dirname(mac_app_res)):
    shutil.copy(icns_path, mac_app_res)
    print(f"Updated {mac_app_res}")

print("=== ALL APP ICONS PROCESSED AND ORGANIZED SUCCESSFULLY ===")
