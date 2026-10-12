#!/usr/bin/env python3
import os
from PIL import Image

def normalize_all_bus_assets():
    colors = ['red', 'blue', 'yellow', 'green', 'orange', 'purple', 'pink']
    dirs = ['up', 'down', 'left', 'right']
    
    src_dir = 'assets/sprites/premium_buses'
    fallback_dir = 'assets/buses'
    
    # Target canonical body dimensions
    CANONICAL_BODY_W = 54
    CANONICAL_BODY_L = 102
    
    CANONICAL_CANVAS_V = (62, 110)
    CANONICAL_CANVAS_H = (110, 62)
    
    print("=== NORMALIZING ALL 28 SHORT BUS ASSETS ===")
    print(f"Canonical Parked Body Target: {CANONICAL_BODY_W} x {CANONICAL_BODY_L} world units")
    print(f"Canonical Vertical Canvas:   {CANONICAL_CANVAS_V[0]} x {CANONICAL_CANVAS_V[1]} (Margins: 4px all around)")
    print(f"Canonical Horizontal Canvas: {CANONICAL_CANVAS_H[0]} x {CANONICAL_CANVAS_H[1]} (Margins: 4px all around)")
    print("-" * 70)
    
    count = 0
    for c in colors:
        for d in dirs:
            fn = f"bus_short_{c}_{d}.png"
            fp = os.path.join(src_dir, fn)
            if not os.path.exists(fp):
                print(f"Warning: Missing file {fp}")
                continue
            
            img = Image.open(fp)
            bbox = img.getbbox()
            body = img.crop(bbox)
            
            if d in ['up', 'down']:
                b_norm = body.resize((CANONICAL_BODY_W, CANONICAL_BODY_L), Image.Resampling.LANCZOS)
                canvas = Image.new('RGBA', CANONICAL_CANVAS_V, (0, 0, 0, 0))
                canvas.paste(b_norm, (4, 4))
                exp_bbox = (4, 4, 58, 106)
            else:
                b_norm = body.resize((CANONICAL_BODY_L, CANONICAL_BODY_W), Image.Resampling.LANCZOS)
                canvas = Image.new('RGBA', CANONICAL_CANVAS_H, (0, 0, 0, 0))
                canvas.paste(b_norm, (4, 4))
                exp_bbox = (4, 4, 106, 58)
                
            actual_bbox = canvas.getbbox()
            assert actual_bbox == exp_bbox, f"Normalization error for {fn}: {actual_bbox} != {exp_bbox}"
            
            # Save to primary destination
            canvas.save(fp, format='PNG')
            
            # Also sync to fallback and long variants
            alt_paths = [
                os.path.join(src_dir, f"bus_long_{c}_{d}.png"),
                os.path.join(fallback_dir, f"short_{c}_{d}.png"),
                os.path.join(fallback_dir, f"{c}_{d}.png"),
                os.path.join(fallback_dir, f"long_{c}_{d}.png"),
            ]
            for ap in alt_paths:
                if os.path.exists(os.path.dirname(ap)):
                    canvas.save(ap, format='PNG')
            
            count += 1
            print(f"Normalized {fn:<26} -> Canvas: {canvas.size}, BBox: {actual_bbox}, Visible Body: {actual_bbox[2]-actual_bbox[0]}x{actual_bbox[3]-actual_bbox[1]}")

    print("-" * 70)
    print(f"Total normalized assets: {count}/28. All 100% compliant with canonical dimensions!")

if __name__ == "__main__":
    normalize_all_bus_assets()
