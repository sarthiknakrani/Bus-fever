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
var _idle_time: float = 0.0
var _phase_offset: float = 0.0
var _is_animated: bool = false
var _is_boarding: bool = false
var _is_waiting: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _facing_right: bool = true
var _smoothed_speed: float = 0.0

const BASE_SCALE := 0.42
const IDLE_FRAME := 6
const RUN_FRAMES := 6
const TOTAL_FRAMES := 8

func set_movement_direction(tangent: Vector2) -> void:
	if absf(tangent.x) > 0.2:
		_facing_right = (tangent.x > 0.0)

func set_waiting(waiting: bool) -> void:
	_is_waiting = waiting
	if _is_waiting:
		_smoothed_speed = 0.0
		if _is_animated and _char_sprite != null:
			_char_sprite.frame = IDLE_FRAME
			_char_sprite.rotation = 0.0
			_char_sprite.position.y = 0.0

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
	_shadow.scale = Vector2(BASE_SCALE * 1.5, BASE_SCALE * 0.75)
	_shadow.modulate = Color(0, 0, 0, 0.45)
	_shadow.z_index = -1
	add_child(_shadow)
	
	# Load authentic 8-frame running spritesheet, falling back to static sprite if unavailable
	var tex_sheet := _load_interim_sprite("res://assets/sprites/passengers/anim/passenger_%s_sheet.png" % _color_id)
	var tex_char: Texture2D = tex_sheet
	if tex_char == null:
		var tex_paths := [
			"res://assets/sprites/passengers/passenger_%s.png" % _color_id,
			"res://assets/sprites/passenger_references/original_character_art/passenger_%s_reference.png" % _color_id
		]
		for p in tex_paths:
			tex_char = _load_interim_sprite(p)
			if tex_char != null:
				break
				
	if tex_char == null:
		push_warning("PassengerView: Missing authentic sprite for color '%s', falling back to blue" % _color_id)
		tex_char = _load_interim_sprite("res://assets/sprites/passengers/anim/passenger_blue_sheet.png")
		if tex_char == null:
			tex_char = _load_interim_sprite("res://assets/sprites/passengers/passenger_blue.png")
		
	_char_sprite = Sprite2D.new()
	_char_sprite.name = "CharacterSprite"
	_char_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if tex_char != null:
		_char_sprite.texture = tex_char
		if tex_char.get_width() >= 192 * 6:
			_char_sprite.hframes = TOTAL_FRAMES
			_char_sprite.vframes = 1
			_char_sprite.frame = IDLE_FRAME
			_is_animated = true
		else:
			_is_animated = false
	
	# In our 192x192 canvas, ground contact is at y = 180 (84px below center 96)
	# Setting offset to Vector2(0, -84) aligns feet precisely at (0, 0) in local space
	_char_sprite.offset = Vector2(0, -84)
	_visual_node.add_child(_char_sprite)
	
	_visual_node.scale = Vector2(BASE_SCALE, BASE_SCALE)
	# Organic per-passenger phase desynchronization across crowd
	if p_id != 0 or p_lane != 0:
		_phase_offset = float((p_id * 17 + p_lane * 23) % 100) / 100.0
		_idle_time = float((p_id * 31 + p_lane * 13) % 100) / 100.0 * 2.0
	else:
		_phase_offset = randf()
		_idle_time = randf() * 2.0

func _process(delta: float) -> void:
	if not _is_boarding:
		var current_pos := global_position
		var moved_dist := 0.0
		if _last_pos != Vector2.ZERO:
			moved_dist = current_pos.distance_to(_last_pos)
			var dx := current_pos.x - _last_pos.x
			if absf(dx) > 1.0:
				_facing_right = (dx > 0.0)
		_last_pos = current_pos

		if delta > 0.0:
			var inst_speed = moved_dist / delta
			_smoothed_speed = lerpf(_smoothed_speed, inst_speed, minf(1.0, 16.0 * delta))

		var facing_sign: float = 1.0 if _facing_right else -1.0

		if _is_waiting or _smoothed_speed < 12.0:
			# Immediately snap to idle frame when stopped or waiting in queue
			if _is_animated and _char_sprite != null:
				_char_sprite.frame = IDLE_FRAME
			if _char_sprite != null:
				_char_sprite.position = Vector2.ZERO
				_char_sprite.rotation = 0.0
				_char_sprite.scale = Vector2(facing_sign, 1.0)
			if _shadow != null:
				_shadow.scale = Vector2(BASE_SCALE * 1.5, BASE_SCALE * 0.75)
				_shadow.modulate.a = 0.45
		else:
			# Real Running Cycle synchronized directly with movement distance
			# Frame changes smoothly across all 8 running frames with actual travel speed (stride ~ 36px)
			_anim_time += moved_dist / 36.0
			if _is_animated and _char_sprite != null:
				var norm_t: float = wrapf(_anim_time + _phase_offset, 0.0, 1.0)
				var run_frame: int = clampi(int(floor(norm_t * float(RUN_FRAMES))), 0, RUN_FRAMES - 1)
				_char_sprite.frame = run_frame
			
			if _char_sprite != null:
				# Stable omnidirectional 3D circle running without up/down bobbing or tilting
				_char_sprite.rotation = 0.0
				_char_sprite.position = Vector2.ZERO
				_char_sprite.scale = Vector2(facing_sign, 1.0)
			
			if _shadow != null:
				_shadow.scale = Vector2(BASE_SCALE * 1.5, BASE_SCALE * 0.75)
				_shadow.modulate.a = 0.45

func animate_jump(delay: float) -> void:
	if not is_inside_tree(): return
	_is_boarding = true
	
	# Reset running pose
	_char_sprite.rotation = 0.0
	_char_sprite.position.y = 0.0
	if _is_animated:
		_char_sprite.frame = 1 # Dynamic jump/push pose
	
	var facing_sign := 1.0 if _facing_right else -1.0
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		
	# Boarding leap arc
	tw.tween_property(_char_sprite, "position:y", -18.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_char_sprite, "position:y", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var tw2 := create_tween()
	if delay > 0.0:
		tw2.tween_interval(delay)
	tw2.tween_property(_char_sprite, "scale", Vector2(0.85, 1.2), 0.08)
	tw2.tween_property(_char_sprite, "scale", Vector2.ONE, 0.08)
	
	if _shadow != null:
		var tw_s := create_tween()
		if delay > 0.0:
			tw_s.tween_interval(delay)
		tw_s.tween_property(_shadow, "scale", Vector2(0.18, 0.095), 0.08)
		tw_s.tween_property(_shadow, "scale", Vector2(0.36, 0.19), 0.08)

func _load_interim_sprite(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null
