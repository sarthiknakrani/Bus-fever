import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

# The block to remove:
old_coin = """
	# Top coin badge anchored to top-left
	var top_coins := Label.new()
	top_coins.text = "🪙 %d" % SaveManager.get_coins()
	top_coins.add_theme_font_size_override("font_size", 24)
	top_coins.add_theme_color_override("font_color", Color("ffd700"))
	top_coins.anchor_left = 0.0
	top_coins.anchor_top = 0.0
	top_coins.offset_left = 28.0
	top_coins.offset_top = 28.0
	top_coins.offset_right = 240.0
	top_coins.offset_bottom = 68.0
	root.add_child(top_coins)
"""

code = code.replace(old_coin.strip('\n') + '\n', "")

with open("scripts/main.gd", "w") as f:
    f.write(code)
print("Removed old coin UI.")
