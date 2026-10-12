#!/usr/bin/env python3
import os
import subprocess
import io
from PIL import Image

def normalize_all_bus_assets():
    colors = ['red', 'blue', 'yellow', 'green', 'orange', 'purple', 'pink']
    dirs = ['up', 'down', 'left', 'right']
    
    src_dir = 'assets/sprites/premium_buses'
    fallback_dir = 'assets/buses'
    
    # Target canonical dimensions preserving native proportional aspect ratios
    # Vertical original: 68x145 (aspect ratio 2.1324) -> Proportional body: 48x102 (aspect ratio 2.125, <0.35% delta)
    # Horizontal original: 144x65 (aspect ratio 2.2154) -> Proportional body: 102x46 (aspect ratio 2.217, <0.10% delta)
    CANONICAL_CANVAS_V = (62, 110)
    CANONICAL_CANVAS_H = (110, 62)
    
    TARGET_BODY_V = (48, 102)
    TARGET_BODY_H = (102, 46)
    
    PASTE_OFFSET_V = (7, 4) # BBox: (7, 4, 55, 106) -> 7px sides, 4px top/bottom
    PASTE_OFFSET_H = (4, 8) # BBox: (4, 8, 106, 54) -> 4px ends, 8px sides
    
    print("=== PROPORTIONAL BUS ASSET NORMALIZATION & PRESERVATION ===")
    print(f"Vertical Body:   {TARGET_BODY_V[0]}x{TARGET_BODY_V[1]} (Canvas: {CANONICAL_CANVAS_V[0]}x{CANONICAL_CANVAS_V[1]})")
    print(f"Horizontal Body: {TARGET_BODY_H[0]}x{TARGET_BODY_H[1]} (Canvas: {CANONICAL_CANVAS_H[0]}x{CANONICAL_CANVAS_H[1]})")
    print("-" * 75)
    
    # 1. Restore genuine long-bus source assets from Git history (commit f603b81)
    print("1. Restoring genuine long-bus assets from Git baseline f603b81...")
    restored_long = 0
    for c in colors:
        for d in dirs:
            p_prem = f"assets/sprites/premium_buses/bus_long_{c}_{d}.png"
            p_fall = f"assets/buses/long_{c}_{d}.png"
            
            for p in [p_prem, p_fall]:
                res = subprocess.run(["git", "show", f"f603b81:{p}"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                if res.returncode == 0:
                    with open(p, "wb") as f:
                        f.write(res.stdout)
                    restored_long += 1
    print(f"   [RESTORED] {restored_long} long-bus assets preserved without modification.")
    
    # 2. Normalize short-bus assets using proportional art scaling from f603b81 baseline
    print("\n2. Normalizing 28 short-bus assets with proportional aspect-ratio preservation...")
    count = 0
    for c in colors:
        for d in dirs:
            fn = f"bus_short_{c}_{d}.png"
            fp = os.path.join(src_dir, fn)
            
            # Read original asset from f603b81 baseline
            res = subprocess.run(["git", "show", f"f603b81:{fp}"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if res.returncode == 0:
                img = Image.open(io.BytesIO(res.stdout))
            else:
                img = Image.open(fp)
                
            bbox = img.getbbox()
            body = img.crop(bbox)
            
            if d in ['up', 'down']:
                b_norm = body.resize(TARGET_BODY_V, Image.Resampling.LANCZOS)
                canvas = Image.new('RGBA', CANONICAL_CANVAS_V, (0, 0, 0, 0))
                canvas.paste(b_norm, PASTE_OFFSET_V)
                exp_bbox = (PASTE_OFFSET_V[0], PASTE_OFFSET_V[1], PASTE_OFFSET_V[0] + TARGET_BODY_V[0], PASTE_OFFSET_V[1] + TARGET_BODY_V[1])
            else:
                b_norm = body.resize(TARGET_BODY_H, Image.Resampling.LANCZOS)
                canvas = Image.new('RGBA', CANONICAL_CANVAS_H, (0, 0, 0, 0))
                canvas.paste(b_norm, PASTE_OFFSET_H)
                exp_bbox = (PASTE_OFFSET_H[0], PASTE_OFFSET_H[1], PASTE_OFFSET_H[0] + TARGET_BODY_H[0], PASTE_OFFSET_H[1] + TARGET_BODY_H[1])
                
            actual_bbox = canvas.getbbox()
            assert actual_bbox == exp_bbox, f"Normalization error for {fn}: {actual_bbox} != {exp_bbox}"
            
            # Save to primary destination
            canvas.save(fp, format='PNG')
            
            # Sync ONLY to short fallback variants (DO NOT TOUCH long variants!)
            alt_paths = [
                os.path.join(fallback_dir, f"short_{c}_{d}.png"),
                os.path.join(fallback_dir, f"{c}_{d}.png"),
            ]
            for ap in alt_paths:
                canvas.save(ap, format='PNG')
            
            count += 1
            print(f"   Normalized {fn:<26} -> Canvas: {canvas.size}, Body: {actual_bbox[2]-actual_bbox[0]}x{actual_bbox[3]-actual_bbox[1]}")

    print("-" * 75)
    print(f"Proportional normalization complete: {count}/28 short bus assets updated.")
    print("Long bus assets 100% preserved in original state.")

if __name__ == "__main__":
    normalize_all_bus_assets()
