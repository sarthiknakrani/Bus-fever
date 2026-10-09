extends Node2D
class_name PassengerView

var _color_id: String = "red"
var _visual_node: Node2D

var _leg_l: Sprite2D
var _leg_r: Sprite2D
var _arm_l: Sprite2D
var _arm_r: Sprite2D
var _body: Sprite2D
var _head: Sprite2D
var _shadow: Sprite2D

var _anim_time: float = 0.0
var _is_boarding: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _facing_right: bool = true

func setup(p_col_id: String) -> void:
	_color_id = p_col_id
	
	_visual_node = Node2D.new()
	add_child(_visual_node)
	
	# Load layered premium components
	var t_head = _load_interim_sprite("res://assets/sprites/premium_passengers/head_" + _color_id + ".png")
	var t_body = _load_interim_sprite("res://assets/sprites/premium_passengers/body_" + _color_id + ".png")
	var t_arm  = _load_interim_sprite("res://assets/sprites/premium_passengers/arm_" + _color_id + ".png")
	var t_leg  = _load_interim_sprite("res://assets/sprites/premium_passengers/leg_" + _color_id + ".png")
	var t_shadow = _load_interim_sprite("res://assets/sprites/premium_passengers/passenger_shadow.png")
	
	# Soft shadow
	_shadow = Sprite2D.new()
	if t_shadow: _shadow.texture = t_shadow
	_shadow.position = Vector2(0, 16)
	add_child(_shadow) # Shadow stays un-flipped on the ground
	
	# Right Arm (Back)
	_arm_r = _create_limb(t_arm, Vector2(12, -18), Vector2(0, 10), -1)
	_arm_r.modulate = Color(0.6, 0.6, 0.6) # Darken back arm
	
	# Right Leg (Back)
	_leg_r = _create_limb(t_leg, Vector2(8, -8), Vector2(0, 12), -1)
	_leg_r.modulate = Color(0.6, 0.6, 0.6) # Darken back leg
	
	# Left Leg (Front)
	_leg_l = _create_limb(t_leg, Vector2(-8, -8), Vector2(0, 12), 1)
	
	# Body
	_body = Sprite2D.new()
	if t_body: _body.texture = t_body
	_body.position = Vector2(0, -20)
	_body.z_index = 2
	_visual_node.add_child(_body)
	
	# Left Arm (Front)
	_arm_l = _create_limb(t_arm, Vector2(-14, -16), Vector2(0, 10), 3)
	
	# Head
	_head = Sprite2D.new()
	if t_head: _head.texture = t_head
	_head.position = Vector2(0, -42)
	_head.z_index = 4
	_visual_node.add_child(_head)
	
	# Global scale tweak
	_visual_node.scale = Vector2(0.85, 0.85)
	if _shadow: _shadow.scale = Vector2(0.85, 0.85)
	
	_anim_time = randf() * 1.0

func _create_limb(tex: Texture2D, pos: Vector2, offset: Vector2, z: int) -> Sprite2D:
	var pivot = Node2D.new()
	pivot.position = pos
	pivot.z_index = z
	_visual_node.add_child(pivot)
	
	var spr = Sprite2D.new()
	if tex: spr.texture = tex
	spr.position = offset # offset visual so rotation is from joint
	pivot.add_child(spr)
	return spr

func _process(delta: float) -> void:
	if not _is_boarding:
		_anim_time += delta * 12.0 # Walk cycle speed
		
		var leg_swing = sin(_anim_time) * 0.8
		
		# Animate limbs (pivot is the parent of the sprite)
		_leg_l.get_parent().rotation = leg_swing
		_leg_r.get_parent().rotation = -leg_swing
		_arm_l.get_parent().rotation = -leg_swing * 0.4
		_arm_r.get_parent().rotation = leg_swing * 0.4
		
		# Body bounce
		var bounce = abs(sin(_anim_time)) * 3.0
		_body.position.y = -20 - bounce
		_head.position.y = -42 - bounce
		
		# Head bob
		_head.rotation = sin(_anim_time * 0.5) * 0.05
		
		# Handle natural 2D orientation
		var current_pos = global_position
		if _last_pos != Vector2.ZERO:
			var dx = current_pos.x - _last_pos.x
			if dx > 0.5 and not _facing_right:
				_facing_right = true
				_visual_node.scale.x = abs(_visual_node.scale.x)
			elif dx < -0.5 and _facing_right:
				_facing_right = false
				_visual_node.scale.x = -abs(_visual_node.scale.x)
		_last_pos = current_pos

func animate_jump(delay: float) -> void:
	if not is_inside_tree(): return
	_is_boarding = true
	
	# Reset walking rotations
	_leg_l.get_parent().rotation = 0
	_leg_r.get_parent().rotation = 0
	_arm_l.get_parent().rotation = -0.5 # Arms up for jump!
	_arm_r.get_parent().rotation = 0.5
	_head.rotation = 0
	
	var tw = create_tween()
	tw.tween_interval(delay)
	var orig_y = _visual_node.position.y
	# Nice boarding leap animation
	tw.tween_property(_visual_node, "position:y", orig_y - 25.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual_node, "position:y", orig_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var tw2 = create_tween()
	tw2.tween_interval(delay)
	var base_scale = _visual_node.scale
	tw2.tween_property(_visual_node, "scale", Vector2(base_scale.x * 0.8, base_scale.y * 1.2), 0.15)
	tw2.tween_property(_visual_node, "scale", base_scale, 0.15)

func _load_interim_sprite(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null
