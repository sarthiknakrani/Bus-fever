with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    for i, line in enumerate(f):
        if "arrow" in line.lower():
            print(f"{i+1}: {line.strip()}")
