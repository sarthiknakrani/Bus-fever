with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# Update booster icon paths
content = content.replace('"icon": "res://assets/btn_vip.png"', '"icon": "res://assets/ui/gameplay_buttons/icon_vip.png"')
content = content.replace('"icon": "res://assets/btn_arrange.png"', '"icon": "res://assets/ui/gameplay_buttons/icon_arrange.png"')
content = content.replace('"icon": "res://assets/btn_jumble.png"', '"icon": "res://assets/ui/gameplay_buttons/icon_jumble.png"')

# The plus badge size is mentioned as "oversized". Wait, in my original code was it 24x24? Let's check what it is in the file.
