import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

# I will just verify the Label settings are robust.
print("Label settings found in main.gd:")
for line in content.split("\n"):
    if "p_lbl" in line or "ls_play" in line:
        print(line)
