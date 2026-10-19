extends Node
class_name VehicleDepartureController

var vehicle: Node2D
var controller: Node
var vehicle_id: int
var slot_id: int
var token: int
var slot_pos: Vector2

var state := 0
var bay_cleared := false
var reverse_target_y: float
var curve: Curve2D
var curve_offset := 0.0
var curve_len := 0.0
var speed := 0.0
var front_native: Vector2

var t_start: float = 0.0
var t_cleared: float = 0.0
var t_corridor_enter: float = 0.0

# White departure trail: rendered behind the bus as a fading Line2D.
# Lives in the bus's parent so it can outlast this controller and complete its fade tween.
var _trail: Line2D = null
const TRAIL_WIDTH: float = 8.0
const TRAIL_COLOR := Color(0.96, 0.97, 1.0, 0.7)
const TRAIL_FADE_DURATION: float = 0.9

static var active: Array[Node] = []

func _ready():
	active.append(self)
	t_start = Time.get_ticks_msec() / 1000.0
	print("[QA] Bus %d DEPARTURE START at %.2f" % [vehicle_id, t_start])

	# Initialize white departure trail parented to the bus's container so it survives
	# past this controller's queue_free (we fade it after the bus leaves the screen).
	if vehicle != null and is_instance_valid(vehicle):
		var bus_parent := vehicle.get_parent()
		if bus_parent != null:
			_trail = Line2D.new()
			_trail.name = "DepartureTrail_Bus%d" % vehicle_id
			_trail.width = TRAIL_WIDTH
			_trail.default_color = TRAIL_COLOR
			_trail.modulate = Color(1.0, 1.0, 1.0, 1.0)
			_trail.z_index = -1
			_trail.joint_mode = Line2D.LINE_JOINT_ROUND
			_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
			_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
			_trail.add_point(vehicle.position)
			bus_parent.add_child(_trail)

func _exit_tree():
	active.erase(self)
	var t_exit = Time.get_ticks_msec() / 1000.0
	print("[QA] Bus %d EXIT CORRIDOR LEAVE at %.2f (Total time: %.2fs)" % [vehicle_id, t_exit, t_exit - t_start])

func _process(delta: float):
	if not is_instance_valid(vehicle):
		queue_free()
		return

	# Extend trail each frame while the bus is still visible to the camera.
	if _trail != null and is_instance_valid(_trail) and vehicle.visible:
		_trail.add_point(vehicle.position)

	if state == 0:
		# Faster reversing
		speed = move_toward(speed, 750.0, 1800.0 * delta)
		vehicle.position.y += speed * delta
		
		# Release slot once visually clear
		if not bay_cleared and vehicle.position.y > (slot_pos.y + 115.0):
			bay_cleared = true
			t_cleared = Time.get_ticks_msec() / 1000.0
			print("[QA] Bus %d BAY RELEASED at %.2f (Reverse time: %.2fs)" % [vehicle_id, t_cleared, t_cleared - t_start])
			controller.on_vehicle_cleared_slot(vehicle_id, slot_id, token)
			
		if vehicle.position.y >= reverse_target_y:
			vehicle.position.y = reverse_target_y
			state = 1
			speed = 0.0
			t_corridor_enter = Time.get_ticks_msec() / 1000.0
			print("[QA] Bus %d CORRIDOR ENTER at %.2f" % [vehicle_id, t_corridor_enter])
			
	elif state == 1 or state == 2:
		var can_move = true
		var safe_gap = 190.0
		var blocking_id = -1
		var min_dist = 9999.0
		
		for other in active:
			if other == self or not is_instance_valid(other.vehicle): continue
			if other.state >= 1:
				var dist_x = other.vehicle.position.x - vehicle.position.x
				
				# other is ahead of us (to our right)
				if dist_x > 0 and dist_x < safe_gap:
					can_move = false
					blocking_id = other.vehicle_id
					min_dist = dist_x
				
				# other is behind us (to our left), approaching fast, and we are just merging
				if state == 1 and dist_x < 0 and dist_x > -safe_gap:
					if other.state == 2: # they are already driving straight
                        # Yield!
						can_move = false
						blocking_id = other.vehicle_id
						min_dist = dist_x
		
		if can_move:
			speed = move_toward(speed, 800.0, 1600.0 * delta)
		else:
			speed = move_toward(speed, 0.0, 3000.0 * delta) # Hard brake
			if speed < 10.0:
				print("[QA] Bus %d BLOCKED by Bus %d (Dist: %.1f, Safe: %.1f)" % [vehicle_id, blocking_id, min_dist, safe_gap])
			
		if speed > 0:
			if state == 1:
				curve_offset += speed * delta
				if curve_offset >= curve_len:
					curve_offset = curve_len
					state = 2
					
				var pos = curve.sample_baked(curve_offset)
				vehicle.position = pos
				
				var offset_ahead = min(curve_len, curve_offset + 5.0)
				var pos_ahead = curve.sample_baked(offset_ahead)
				if pos.distance_to(pos_ahead) > 0.1:
					var dir = (pos_ahead - pos).normalized()
					vehicle.rotation = dir.angle() - front_native.angle()
			elif state == 2:
				vehicle.position.x += speed * delta
				# keep straight rotation
				vehicle.rotation = Vector2.RIGHT.angle() - front_native.angle()
				
				var vp_rect = vehicle.get_viewport_rect()
				var global_right_x = (vp_rect.size.x / 2.0) + 400.0
				var exit_global = Vector2(global_right_x, 0)
				var exit_local = vehicle.get_parent().get_global_transform().affine_inverse() * exit_global
				
				if vehicle.position.x > exit_local.x:
					vehicle.visible = false
					if vehicle.get_parent() != null:
						vehicle.get_parent().remove_child(vehicle)
					vehicle.queue_free()
					controller.on_vehicle_departed_from_slot(vehicle_id, slot_id, token)

					# Fade the white departure trail, then free it independently of the controller.
					if _trail != null and is_instance_valid(_trail):
						var fade := _trail.create_tween()
						fade.tween_property(_trail, "modulate:a", 0.0, TRAIL_FADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
						fade.tween_callback(_trail.queue_free)
					_trail = null

					queue_free()
