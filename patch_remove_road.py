import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

# Remove road band
code = re.sub(r'\t# Middle section: Decorative colored road band[\s\S]*?root\.add_child\(road_band\)', '', code)

with open("scripts/main.gd", "w") as f:
    f.write(code)

print("Removed road band")
