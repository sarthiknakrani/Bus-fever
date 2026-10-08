with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

highlight_injection = """
	bst_style.border_width_top = 8
	bst_style.border_blend = true
"""

# Find where bst_style is defined
if "bst_style.shadow_offset" in code and "bst_style.border_blend" not in code:
    code = code.replace('bst_style.shadow_offset = Vector2(0, 12)', 'bst_style.shadow_offset = Vector2(0, 12)\n' + highlight_injection)
    with open("scripts/gameplay/car_jam_level.gd", "w") as f:
        f.write(code)
    print("Added highlight to bst_style.")
