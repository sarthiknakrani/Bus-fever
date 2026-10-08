extends Node2D
class_name PassengerView

var _color_id: String = "red"
var _color: Color = Color.RED
var _visual_node: Node2D
var _sprite_body: Sprite2D
var _sprite_head: Sprite2D

func setup(p_col_id: String) -> void:
	_color_id = p_col_id
	_color = CarJamVehicleData.color_to_rgb(p_col_id)
	
	_visual_node = Node2D.new()
	add_child(_visual_node)
	
	# Modular production sprites
	var tex_head = _load_interim_sprite("res://assets/sprites/interim/passenger_head.png")
	var tex_body = _load_interim_sprite("res://assets/sprites/interim/passenger_body.png")
	var tex_shadow = _load_interim_sprite("res://assets/sprites/interim/passenger_head.png") # reusing round shape
	
	# Shadow
	var s_shadow = Sprite2D.new()
	s_shadow.texture = tex_shadow
	s_shadow.modulate = Color(0,0,0,0.3)
	s_shadow.scale = Vector2(0.6, 0.2)
	s_shadow.position = Vector2(0, 16)
	_visual_node.add_child(s_shadow)
	
	# Body
	_sprite_body = Sprite2D.new()
	_sprite_body.texture = tex_body
	_sprite_body.modulate = _color
	_sprite_body.scale = Vector2(0.4, 0.4)
	_sprite_body.position = Vector2(0, 0)
	_visual_node.add_child(_sprite_body)
	
	# Head
	_sprite_head = Sprite2D.new()
	_sprite_head.texture = tex_head
	_sprite_head.modulate = _color.lightened(0.2) # Optional skin tone or just matched color
	_sprite_head.scale = Vector2(0.4, 0.4)
	_sprite_head.position = Vector2(0, -18)
	_visual_node.add_child(_sprite_head)

func animate_jump(delay: float) -> void:
	if not is_inside_tree(): return
	var tw = create_tween()
	tw.tween_interval(delay)
	var orig_y = _visual_node.position.y
	tw.tween_property(_visual_node, "position:y", orig_y - 12.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual_node, "position:y", orig_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _load_interim_sprite(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	# Fallback to direct image load if not imported
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null
