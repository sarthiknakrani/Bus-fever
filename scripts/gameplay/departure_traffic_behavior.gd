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

static var active: Array[Node] = []

func _ready():
	active.append(self)
	t_start = Time.get_ticks_msec() / 1000.0
	print("[QA] Bus %d DEPARTURE START at %.2f" % [vehicle_id, t_start])

func _exit_tree():
	active.erase(self)
	var t_exit = Time.get_ticks_msec() / 1000.0
	print("[QA] Bus %d EXIT CORRIDOR LEAVE at %.2f (Total time: %.2fs)" % [vehicle_id, t_exit, t_exit - t_start])

func _process(delta: float):
	if not is_instance_valid(vehicle):
		queue_free()
		return
		
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
					controller.on_vehicle_departed_from_slot(vehicle_id, slot_id, token)
					queue_free()
