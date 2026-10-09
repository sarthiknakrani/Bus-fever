class_name SimpleStyle
extends RefCounted

## Shared procedural "simple 3D" button/text helpers used by both
## the home menu (main.gd) and in-game UI (car_jam_level.gd).
## Single offset shadow + chunky bottom-border extrusion = the look.

# Build a simple 3D-extruded StyleBoxFlat. Solid top color, dark colored
# "lip" via border_width_bottom for the extrusion. Optional text_pad shrinks
# height on press for a press-down feel.
static func make_extruded_style(top_color: Color, side_color: Color,
		corner_radius: int, extrude: int, shadow_y: int = 4,
		text_pad: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = top_color
	# Chunky lip = the depth. Side bevels are thin so the lip dominates.
	sb.border_width_top = 4
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_bottom = extrude
	sb.border_color = side_color
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	if shadow_y > 0:
		sb.shadow_color = Color(0, 0, 0, 0.18)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, shadow_y)
	if text_pad > 0:
		sb.content_margin_top = text_pad
	return sb

# Convenience: title color constants for the home/level heading look.
const TITLE_FRONT := Color("1e3a8a")
const TITLE_SHADOW := Color("0c1f5c")
