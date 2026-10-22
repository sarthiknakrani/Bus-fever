class_name ClayStyle
extends RefCounted

## ClayStyle: Procedural Claymorphism UI Library for Bus Fever Party.
##
## Produces puffy 3D tactile shapes with dual inner highlights,
## thick bottom clay depth rims, soft diffused floating drop shadows,
## matte candy/pastel palettes, and bouncy squish physics.

# --- Palette Constants ---
const CLAY_CREAM := Color("fffdf7")
const CLAY_CREAM_RIM := Color("e6d8c3")

const CLAY_DARK_PLUM := Color("1e1b2e")
const CLAY_DARK_PLUM_RIM := Color("ef4444")

const CLAY_ORANGE := Color("fb923c")
const CLAY_ORANGE_LIP := Color("c2410c")
const CLAY_ORANGE_OUTLINE := Color("7c2d12")

const CLAY_GREEN := Color("22c55e")
const CLAY_GREEN_LIP := Color("15803d")
const CLAY_GREEN_OUTLINE := Color("14532d")

const CLAY_BLUE := Color("38bdf8")
const CLAY_BLUE_LIP := Color("0284c7")
const CLAY_BLUE_OUTLINE := Color("0369a1")

const CLAY_GOLD := Color("fef3c7")
const CLAY_GOLD_LIP := Color("f59e0b")
const CLAY_GOLD_OUTLINE := Color("78350f")

const CLAY_WHITE := Color("ffffff")
const CLAY_WHITE_LIP := Color("cbd5e1")

const TEXT_DARK_BROWN := Color("4a2810")
const TEXT_CHOCOLATE := Color("5c3d2e")
const TEXT_SLATE := Color("334155")


## Creates a puffy clay panel style (for dialog modals, cards, containers).
static func create_clay_panel(
		bg_color: Color = CLAY_CREAM,
		rim_color: Color = CLAY_CREAM_RIM,
		radius: int = 28,
		depth: int = 6,
		shadow_size: int = 20,
		shadow_y: int = 7,
		shadow_color: Color = Color(0, 0, 0, 0.22)
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 16
	sb.border_width_top = 0
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_bottom = depth
	sb.border_color = rim_color
	sb.border_blend = false
	sb.shadow_color = shadow_color
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(0, shadow_y)
	return sb


## Creates a clay button base style.
static func create_clay_button_style(
		face_color: Color,
		lip_color: Color,
		radius: int = 22,
		depth: int = 5,
		shadow_size: int = 14,
		shadow_y: int = 5,
		shadow_alpha: float = 0.25
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face_color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 16
	sb.border_width_top = 0
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_bottom = depth
	sb.border_color = lip_color
	sb.border_blend = false
	# Tinted shadow matching bottom lip for realistic colored ambient bounce
	var sh_col := lip_color
	sh_col.a = shadow_alpha
	sb.shadow_color = sh_col
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(0, shadow_y)
	return sb


## Creates an inflated highlight overlay style (gives upper rounded specular reflection).
static func create_clay_highlight_style(radius: int = 22, highlight_alpha: float = 0.25) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, highlight_alpha)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.corner_detail = 16
	return sb


## Creates a full pill-shaped clay style (for banners, badges, pill buttons).
static func create_clay_pill(
		face_color: Color,
		lip_color: Color,
		depth: int = 4,
		shadow_size: int = 12,
		shadow_y: int = 4,
		shadow_alpha: float = 0.20
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face_color
	sb.set_corner_radius_all(999)
	sb.corner_detail = 16
	sb.border_width_top = 0
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_bottom = depth
	sb.border_color = lip_color
	var sh_col := lip_color
	sh_col.a = shadow_alpha
	sb.shadow_color = sh_col
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(0, shadow_y)
	return sb


## Attaches tactile clay squish animation to any Control button or node.
## Animates purely via scale squash & stretch centered on pivot_offset.
## Never alters position, preventing displacement bugs across viewports and containers.
static func apply_clay_squish(
		ctrl: Control,
		_unused_offset_y: float = 0.0,
		scale_down: float = 0.93,
		target_to_animate: Control = null
) -> void:
	var anim_target: Control = target_to_animate if target_to_animate != null else ctrl
	
	# Keep pivot centered dynamically whenever size changes
	var update_pivot = func():
		if is_instance_valid(anim_target) and anim_target.size.x > 0.0 and anim_target.size.y > 0.0:
			anim_target.pivot_offset = anim_target.size * 0.5
	
	if not anim_target.resized.is_connected(update_pivot):
		anim_target.resized.connect(update_pivot)
	update_pivot.call()

	var active_tween: Array = [null]

	var on_down = func():
		if not is_instance_valid(anim_target):
			return
		update_pivot.call()
		if active_tween[0] != null and is_instance_valid(active_tween[0]) and active_tween[0].is_valid():
			active_tween[0].kill()
		var tw := anim_target.create_tween()
		active_tween[0] = tw
		# Clay squash & stretch: compressed height with gentle horizontal bulge
		var squash_scale := Vector2(scale_down * 1.02, scale_down * 0.94)
		tw.tween_property(anim_target, "scale", squash_scale, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var on_up = func():
		if not is_instance_valid(anim_target):
			return
		update_pivot.call()
		if active_tween[0] != null and is_instance_valid(active_tween[0]) and active_tween[0].is_valid():
			active_tween[0].kill()
		var tw := anim_target.create_tween()
		active_tween[0] = tw
		# Springy elastic bounce back to natural rest
		tw.tween_property(anim_target, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if ctrl is BaseButton:
		ctrl.button_down.connect(on_down)
		ctrl.button_up.connect(on_up)


## Builds a complete claymorphic button widget with tactile squish.
static func create_clay_button(
		text: String,
		face_color: Color,
		lip_color: Color,
		on_click: Callable,
		min_size: Vector2 = Vector2(160, 52),
		font_size: int = 18,
		radius: int = 24,
		depth: int = 5,
		outline_color: Color = Color.TRANSPARENT,
		outline_size: int = 0
) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = min_size
	wrapper.size = min_size
	wrapper.pivot_offset = min_size / 2.0

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_style := create_clay_button_style(face_color, lip_color, radius, depth)
	panel.add_theme_stylebox_override("panel", p_style)
	wrapper.add_child(panel)

	# Gloss upper sheen
	var gloss := Panel.new()
	gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gloss.anchor_bottom = 0.48
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.add_theme_stylebox_override("panel", create_clay_highlight_style(radius, 0.25))
	wrapper.add_child(gloss)

	# Label
	var lbl := Label.new()
	lbl.name = "ButtonLabel"
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	if outline_size > 0:
		lbl.add_theme_color_override("font_outline_color", outline_color)
		lbl.add_theme_constant_override("outline_size", outline_size)
	lbl.offset_top = -2
	lbl.offset_bottom = -2
	wrapper.add_child(lbl)

	# Button hit area
	var btn := Button.new()
	btn.name = "HitButton"
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.modulate = Color(1, 1, 1, 0.0)
	wrapper.add_child(btn)

	if on_click.is_valid():
		btn.pressed.connect(on_click)

	apply_clay_squish(btn, 3.0, 0.94, wrapper)

	return wrapper


## Builds a circular clay close button ("✕").
static func create_clay_close_button(on_click: Callable, diameter: float = 40.0) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(diameter, diameter)
	wrapper.size = Vector2(diameter, diameter)
	wrapper.pivot_offset = Vector2(diameter / 2.0, diameter / 2.0)

	var radius := int(diameter / 2.0)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_style := create_clay_button_style(Color("ffffff"), Color("d1d5db"), radius, 3, 8, 3, 0.20)
	panel.add_theme_stylebox_override("panel", p_style)
	wrapper.add_child(panel)

	var gloss := Panel.new()
	gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gloss.anchor_bottom = 0.5
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.add_theme_stylebox_override("panel", create_clay_highlight_style(radius, 0.35))
	wrapper.add_child(gloss)

	var lbl := Label.new()
	lbl.text = "✕"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", int(diameter * 0.45))
	lbl.add_theme_color_override("font_color", Color("475569"))
	lbl.offset_top = -1
	wrapper.add_child(lbl)

	var btn := Button.new()
	btn.name = "HitButton"
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.modulate = Color(1, 1, 1, 0.0)
	wrapper.add_child(btn)

	if on_click.is_valid():
		btn.pressed.connect(on_click)

	apply_clay_squish(btn, 2.0, 0.90, wrapper)

	return wrapper


# --- Backward Compatibility Helper ---
static func make_extruded_style(top_color: Color, side_color: Color,
		corner_radius: int, extrude: int, shadow_y: int = 4,
		text_pad: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = top_color
	sb.border_width_top = 4
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_bottom = extrude
	sb.border_color = side_color
	sb.set_corner_radius_all(corner_radius)
	sb.corner_detail = 12
	if shadow_y > 0:
		sb.shadow_color = Color(0, 0, 0, 0.18)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, shadow_y)
	if text_pad > 0:
		sb.content_margin_top = text_pad
	return sb

const TITLE_FRONT := Color("1e3a8a")
const TITLE_SHADOW := Color("0c1f5c")
