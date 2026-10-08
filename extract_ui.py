import cv2
import numpy as np
import os

img_path = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c/.user_uploaded/media_1791443621518_e7d34d45.jpg"
out_dir = "assets/ui"
os.makedirs(out_dir, exist_ok=True)

img = cv2.imread(img_path)
if img is None:
    print("Failed to load image")
    exit(1)

# Convert to grayscale for thresholding
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
# Threshold: black background becomes 0, everything else > 0
_, thresh = cv2.threshold(gray, 15, 255, cv2.THRESH_BINARY)

# Find contours
contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

print(f"Found {len(contours)} contours.")

count = 0
for i, c in enumerate(contours):
    x, y, w, h = cv2.boundingRect(c)
    # Filter small noise and large text sections
    if w > 30 and h > 30:
        # Extract the region
        roi = img[y:y+h, x:x+w]
        
        # Create an alpha channel based on the threshold
        alpha = thresh[y:y+h, x:x+w]
        
        # Smooth the alpha slightly for anti-aliasing
        alpha = cv2.GaussianBlur(alpha, (3, 3), 0)
        
        # Add alpha channel to ROI
        b, g, r = cv2.split(roi)
        rgba = cv2.merge([b, g, r, alpha])
        
        out_path = os.path.join(out_dir, f"element_{count}.png")
        cv2.imwrite(out_path, rgba)
        print(f"Saved {out_path} (x={x}, y={y}, w={w}, h={h})")
        count += 1
