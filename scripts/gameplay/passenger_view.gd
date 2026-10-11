extends Node2D
class_name PassengerView

## Authentic User-Supplied Passenger Art View
## Renders authentic glossy 3D toy chibi characters (yellow, blue, red, green, purple, orange, pink, brown)
## with natural path-following orientation, rhythmic running bounce/lean, and boarding jump.

var _color_id: String = "red"
var _visual_node: Node2D
var _char_sprite: Sprite2D
var _shadow: Sprite2D

var _anim_time: float = 0.0
var _is_boarding: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _facing_right: bool = true

const BASE_SCALE := 0.27

func setup(p_col_id: String, p_id: int = 0, p_lane: int = 0) -> void:
	_color_id = p_col_id.to_lower()
	
	_visual_node = Node2D.new()
	_visual_node.name = "VisualNode"
	add_child(_visual_node)
	
	# Authentic ground contact shadow
	var t_shadow := _load_interim_sprite("res://assets/sprites/premium_passengers/passenger_shadow.png")
	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"
	if t_shadow != null:
		_shadow.texture = t_shadow
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_shadow.position = Vector2(0, 0)
	_shadow.scale = Vector2(0.26, 0.14)
	_shadow.modulate = Color(0, 0, 0, 0.45)
	_shadow.z_index = -1
	add_child(_shadow)
	
	# Load authentic 3D toy character sprite
	var tex_paths := [
		"res://assets/sprites/passengers/passenger_%s.png" % _color_id,
		"res://assets/sprites/passenger_references/original_character_art/passenger_%s_reference.png" % _color_id
	]
	var tex_char: Texture2D = null
	for p in tex_paths:
		tex_char = _load_interim_sprite(p)
		if tex_char != null:
			break
			
	if tex_char == null:
		push_warning("PassengerView: Missing authentic sprite for color '%s', falling back to blue" % _color_id)
		tex_char = _load_interim_sprite("res://assets/sprites/passengers/passenger_blue.png")
		
	_char_sprite = Sprite2D.new()
	_char_sprite.name = "CharacterSprite"
	_char_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if tex_char != null:
		_char_sprite.texture = tex_char
	
	# In our 192x192 canvas, the ground contact is at y = 180 (84px below center 96)
	# Setting offset to Vector2(0, -84) aligns the feet precisely at (0, 0) in local space
	_char_sprite.offset = Vector2(0, -84)
	_visual_node.add_child(_char_sprite)
	
	_visual_node.scale = Vector2(BASE_SCALE, BASE_SCALE)
	# Organic per-passenger phase desynchronization
	if p_id != 0 or p_lane != 0:
		_anim_time = float((p_id * 17 + p_lane * 23) % 100) / 100.0 * TAU
	else:
		_anim_time = randf() * TAU

func _process(delta: float) -> void:
	if not _is_boarding:
		# Handle natural 2D orientation along the track with hysteresis to prevent flutter
		var current_pos = global_position
		if _last_pos != Vector2.ZERO:
			var dx = current_pos.x - _last_pos.x
			if dx > 0.6 and not _facing_right:
				_facing_right = true
			elif dx < -0.6 and _facing_right:
				_facing_right = false
		_last_pos = current_pos

		_anim_time += delta * 18.0 # Running cadence matching 660 px/s track pace
		
		# Grounded running bounce with stance/flight phases
		var bounce: float = sin(_anim_time)
		var bob: float = maxf(0.0, bounce) * 2.8
		var squash: float = 1.0 - maxf(0.0, -bounce) * 0.04 + maxf(0.0, bounce) * 0.025
		var stretch: float = 1.0 + maxf(0.0, bounce) * 0.035 - maxf(0.0, -bounce) * 0.02
		
		var facing_sign: float = 1.0 if _facing_right else -1.0
		_char_sprite.position.y = -bob
		_char_sprite.scale = Vector2(facing_sign * squash, stretch)
		
		# Subtle running tilt in motion direction
		_char_sprite.rotation = facing_sign * deg_to_rad(3.0) * (1.0 + 0.25 * bounce)
		
		# Shadow reacts to ground contact
		if _shadow != null:
			var shadow_factor: float = 1.0 - (bob / 2.8) * 0.16 + maxf(0.0, -bounce) * 0.06
			_shadow.scale = Vector2(0.26 * shadow_factor, 0.14 * shadow_factor)
			_shadow.modulate.a = 0.45 * shadow_factor

func animate_jump(delay: float) -> void:
	if not is_inside_tree(): return
	_is_boarding = true
	
	# Reset running pose
	_char_sprite.rotation = 0.0
	_char_sprite.position.y = 0.0
	
	var facing_sign := 1.0 if _facing_right else -1.0
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		
	# Boarding leap arc
	tw.tween_property(_char_sprite, "position:y", -24.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_char_sprite, "position:y", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var tw2 := create_tween()
	if delay > 0.0:
		tw2.tween_interval(delay)
	tw2.tween_property(_char_sprite, "scale", Vector2(facing_sign * 0.85, 1.2), 0.08)
	tw2.tween_property(_char_sprite, "scale", Vector2(facing_sign, 1.0), 0.08)
	
	if _shadow != null:
		var tw_s := create_tween()
		if delay > 0.0:
			tw_s.tween_interval(delay)
		tw_s.tween_property(_shadow, "scale", Vector2(0.13, 0.07), 0.08)
		tw_s.tween_property(_shadow, "scale", Vector2(0.26, 0.14), 0.08)

func _load_interim_sprite(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null
