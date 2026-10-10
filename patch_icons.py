import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# Update the booster array paths
content = content.replace('"icon": "res://assets/ui/gameplay_buttons/icon_vip.png"', '"icon": "res://assets/ui/booster_icons/vip_icon.png"')
content = content.replace('"icon": "res://assets/ui/gameplay_buttons/icon_arrange.png"', '"icon": "res://assets/ui/booster_icons/arrange_icon.png"')
content = content.replace('"icon": "res://assets/ui/gameplay_buttons/icon_jumble.png"', '"icon": "res://assets/ui/booster_icons/jumble_icon.png"')

# Update padding to be approx 65-75%
old_padding = r'''		icon_rect\.offset_left = 6
		icon_rect\.offset_right = -6
		icon_rect\.offset_top = 6
		icon_rect\.offset_bottom = -12'''

new_padding = r'''		icon_rect.offset_left = 10
		icon_rect.offset_right = -10
		icon_rect.offset_top = 8
		icon_rect.offset_bottom = -14'''

content = re.sub(old_padding, new_padding, content)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("Icons patched successfully.")
