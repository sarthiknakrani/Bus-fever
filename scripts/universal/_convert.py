#!/usr/bin/env python3
"""Convert problematic `var X := Variant` patterns to `var X = Variant`."""
import re
import sys

files = [
    "scripts/universal/wave_generator.gd",
    "scripts/universal/solvability_validator.gd",
    "scripts/universal/level_integration.gd",
    "scripts/universal/wave_plan.gd",
    "scripts/universal/passenger_sequence.gd",
    "scripts/universal/passenger_demand.gd",
]

for f in files:
    path = f
    content = open(path).read()
    lines = content.split("\n")
    out = []
    # Patterns for RHS that are safe with :=
    safe_prefixes = (
        "int(", "float(", "String(", "Array(", "Dictionary(", "bool(",
        "Vector2(", "Vector3(", "Color(",
        "\"", "'", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "[]", "{}", "Color.", "Vector",
    )

    for line in lines:
        m = re.match(r"^(\s*)var\s+(\w+)\s*:=\s*(.+)$", line)
        if not m:
            out.append(line)
            continue
        indent_str, name, rhs = m.group(1), m.group(2), m.group(3)
        rhs_strip = rhs.strip()
        # Safe patterns: typed literal constructors and numeric/string literals
        is_safe = False
        for p in safe_prefixes:
            if rhs_strip.startswith(p):
                is_safe = True
                break
        if rhs_strip in ("true", "false", "null", "self"):
            is_safe = True
        # "rng := RandomNumberGenerator.new()" has a typed RHS but we want to be safe
        # If RHS is a `X.method()` chained or contains a call result, prefer =
        if "(" in rhs_strip and "config" not in rhs_strip[:20]:
            # Function call result is Variant when types are unknown.
            # Convert to = to avoid Variant inference.
            is_safe = False
        if is_safe:
            out.append(line)
        else:
            out.append(f"{indent_str}var {name} = {rhs}")
    open(path, "w").write("\n".join(out))
    print("Updated", path)
