with open("scripts/autoload/save_manager.gd", "r") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "func _ready() -> void:" in line:
        lines.insert(i+3, "\tset_value(KEY_COINS, 0)\n")
        break

with open("scripts/autoload/save_manager.gd", "w") as f:
    f.writelines(lines)

print("Forced coins to 0 on launch.")
