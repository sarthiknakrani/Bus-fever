extends Node2D
class_name PassengerView

var _color_id: String = "red"
var _visual_node: Node2D
var _sprite: Sprite2D
var _shadow: Sprite2D

var _anim_time: float = 0.0
var _is_boarding: bool = false
var _last_pos: Vector2 = Vector2.ZERO

func setup(p_col_id: String) -> void:
	_color_id = p_col_id
	
	_visual_node = Node2D.new()
	add_child(_visual_node)
	
	# Modular premium sprites (Placeholders ready for final artist assets)
	var tex_shadow = _load_interim_sprite("res://assets/sprites/premium_passengers/passenger_shadow.png")
	var tex_walk = _load_interim_sprite("res://assets/sprites/premium_passengers/passenger_" + _color_id + "_walk.png")
	
	# Soft shadow beneath character
	_shadow = Sprite2D.new()
	if tex_shadow:
		_shadow.texture = tex_shadow
	_shadow.position = Vector2(0, 16)
	_visual_node.add_child(_shadow)
	
	# Character Body (4-frame walk cycle)
	_sprite = Sprite2D.new()
	if tex_walk:
		_sprite.texture = tex_walk
		_sprite.hframes = 4
	_sprite.scale = Vector2(0.6, 0.6)
	_sprite.position = Vector2(0, -20)
	_visual_node.add_child(_sprite)
	
	# Add slight random offset to animation so they don't walk perfectly in sync
	_anim_time = randf() * 1.0

func _process(delta: float) -> void:
	if not _is_boarding:
		# Play walking animation
		_anim_time += delta * 6.0 # 6 FPS
		if _sprite and _sprite.texture:
			_sprite.frame = int(_anim_time) % _sprite.hframes
			
		# Handle natural 2D orientation (flip horizontal based on movement direction)
		var current_pos = global_position
		if _last_pos != Vector2.ZERO:
			var dx = current_pos.x - _last_pos.x
			# Use a small threshold to prevent jittering when standing still
			if dx > 0.5:
				_sprite.flip_h = false
			elif dx < -0.5:
				_sprite.flip_h = true
		_last_pos = current_pos

func animate_jump(delay: float) -> void:
	if not is_inside_tree(): return
	_is_boarding = true
	# Reset frame to standing/jumping frame (frame 0)
	if _sprite: _sprite.frame = 0
	
	var tw = create_tween()
	tw.tween_interval(delay)
	var orig_y = _visual_node.position.y
	# Nice boarding leap animation
	tw.tween_property(_visual_node, "position:y", orig_y - 20.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual_node, "position:y", orig_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Also squash and stretch slightly
	var tw2 = create_tween()
	tw2.tween_interval(delay)
	tw2.tween_property(_sprite, "scale", Vector2(0.5, 0.7), 0.15)
	tw2.tween_property(_sprite, "scale", Vector2(0.6, 0.6), 0.15)

func _load_interim_sprite(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null
