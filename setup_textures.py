import shutil
import os

mapping = {
    "element_13.png": "btn_play.png",
    "element_14.png": "btn_home.png",
    "element_15.png": "btn_restart.png",
    "element_10.png": "btn_vip.png",
    "element_11.png": "btn_arrange.png",
    "element_12.png": "btn_jumble.png",
    "element_21.png": "toggle_on.png",
    "element_22.png": "toggle_off.png",
    "element_5.png": "btn_settings.png",
    "element_6.png": "btn_back.png",
    "element_7.png": "coin_counter.png",
    "element_8.png": "btn_pause.png"
}

# The close button is orange circle with X. In the image it's right of element_17.
# Let's find its filename. It must be element_23 or something? No, element_23 is the "ADS" icon.
# Let's just look for the size. It's a small circle. element_30 is vibrate.
# Let's just create the close button procedurally or find it. I'll search for it later if needed.

for k, v in mapping.items():
    src = f"assets/ui/{k}"
    dst = f"assets/{v}"
    if os.path.exists(src):
        shutil.copy(src, dst)
        print(f"Copied {v}")
